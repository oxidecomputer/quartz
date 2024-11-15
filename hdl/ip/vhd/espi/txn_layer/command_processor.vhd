-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2024 Oxide Computer Company

-- Main command parser and processing for the eSPI transaction layer.
-- Pulls from a FIFO from the link layer or debug layer and processes
-- the commands, issuing insructions to the different layers as required

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;
use work.espi_base_types_pkg.all;
use work.espi_protocol_pkg.all;
use work.flash_channel_pkg.all;
use work.uart_channel_pkg.all;
use work.link_layer_pkg.all;

entity command_processor is
    port (
        clk   : in    std_logic;
        reset : in    std_logic;

        -- register layer connections
        running_crc    : in    std_logic_vector(7 downto 0);
        clear_rx_crc   : out   std_logic;
        regs_if        : view bus_side;
        vwire_if       : view vwire_cmd_side;
        command_header : out   espi_cmd_header;
        response_done  : in    boolean;
        aborted_due_to_bad_crc : out boolean;
        -- flash channel requests
        flash_req : view flash_chan_req_source;
        -- uart channel put interface here
        host_to_sp_espi : view uart_data_source;

        -- Link-layer connections
        is_rx_crc_byte     : out   boolean;
        chip_sel_active : in    std_logic;
        -- "Streaming" data to serialize and transmit
        data_from_host : view byte_sink
    );
end entity;

architecture rtl of command_processor is

    attribute mark_debug : string;

    type   pkt_state_t is (
        idle,
        opcode,
        parse_common_cycle_header,
        parse_addr_header,
        parse_data,
        parse_get_cfg_hdr,
        parse_set_cfg_hdr,
        parse_msg_header,
        parse_vwire_put,
        parse_iowr_put,
        reset_word1,
        crc,
        response
    );

    type reg_type is record
        state          : pkt_state_t;
        crc_good       : boolean;
        crc_bad        : boolean;
        cmd_header     : espi_cmd_header;
        ch_addr        : std_logic_vector(31 downto 0);
        cfg_addr       : std_logic_vector(15 downto 0);
        cfg_data       : std_logic_vector(31 downto 0);
        vwire_idx       : std_logic_vector(7 downto 0);
        vwire_dat       : std_logic_vector(7 downto 0);
        vwire_active    : boolean;
        vwire_wstrobe   : std_logic;
        valid_redge    : boolean;
        reset_strobe   : std_logic;
        hdr_idx        : integer range 0 to 11;
        rem_addr_bytes : integer range 0 to 7;
        rem_data_bytes : integer range 0 to 2048;
    end record;

    constant reg_reset : reg_type := (
        idle, 
        false, 
        false, 
        rec_reset, 
        (others => '0'),
        (others => '0'),
        (others => '0'),
        (others => '0'),
        (others => '0'),
        false,
        '0',
        false, 
        '0',
        0, 
        0, 
        0
    );

    type parse_info_t is record
        next_state        : pkt_state_t;
        cmd_addr_bytes    : natural range 0 to 7;
        cmd_payload_bytes : natural range 0 to 1023;
    end record;

    function next_hdr_state_by_put_header (
        header: espi_cmd_header
    ) return parse_info_t is

        variable next_state : parse_info_t := (parse_addr_header, 4, 0);

    begin
        -- Only need to enumerate non 32bit address cases and anything with a payload
        -- otherwise the default goes
        -- We should only be calling this function on put* kinds of opcodes
        case header.opcode.value is
            when opcode_put_flash_np =>
                case header.cycle_kind is
                    when flash_write =>
                        -- Note that while we'll rx this payload, we will not
                        -- act upon it, as we do not allow flash writes over eSPI
                        next_state.next_state := parse_addr_header;
                        next_state.cmd_payload_bytes := to_integer(header.length);
                    when flash_erase =>
                        -- Note that while we'll rx this payload, we will not
                        -- act upon it, as we do not allow flash writes over eSPI
                    when others =>
                        null;
                end case;
            when opcode_put_pc =>
                case header.cycle_kind is
                    when message_with_data =>
                        next_state.next_state := parse_msg_header;
                        next_state.cmd_addr_bytes := 0;
                        next_state.cmd_payload_bytes := to_integer(header.length);
                    when others =>
                        null;
                end case;
            when opcode_put_oob =>
                next_state.next_state := parse_data;
                next_state.cmd_addr_bytes := 0;
                next_state.cmd_payload_bytes := to_integer(header.length);
            when others =>
                null;
        end case;
        return next_state;
    end;

    signal r, rin : reg_type;

    attribute mark_debug of r        : signal is "TRUE";

begin

    -- vwire interface
    vwire_if.idx <= to_integer(r.vwire_idx);
    vwire_if.dat <= r.vwire_dat;
    vwire_if.wstrobe <= r.vwire_wstrobe;

    host_to_sp_espi.data <= data_from_host.data;
    host_to_sp_espi.valid <= data_from_host.valid when r.cmd_header.opcode.value = opcode_put_pc and r.cmd_header.cycle_kind = message_with_data and r.state = parse_data else 
                             data_from_host.valid when r.cmd_header.opcode.value = opcode_put_oob and r.state = parse_data else '0';
    -- pass through the flash channel requests here
    flash_req.espi_hdr             <= r.cmd_header;
    flash_req.sp5_flash_address    <= r.ch_addr;
    flash_req.flash_np_enqueue_req <= true when r.valid_redge and r.cmd_header.opcode.value = opcode_put_flash_np and r.cmd_header.cycle_kind = flash_read else false;
    flash_req.flash_get_req        <= true when r.valid_redge and r.cmd_header.opcode.value = opcode_get_flash_c else false;

    regs_if.write <= '1' when r.cmd_header.opcode.value = opcode_set_configuration and (r.crc_good or (r.crc_bad and (not regs_if.enforce_crcs))) else '0';
    regs_if.read  <= '1' when r.cmd_header.opcode.value = opcode_get_configuration and (r.crc_good or (r.crc_bad and (not regs_if.enforce_crcs))) else '0';
    regs_if.addr  <= r.cfg_addr;
    regs_if.wdata <= r.cfg_data;
    data_from_host.ready <= '1';

    aborted_due_to_bad_crc <= r.crc_bad and regs_if.enforce_crcs;

    clear_rx_crc <= '1' when r.state = idle else '0';

    command_header <= r.cmd_header;

    command_processor_comb: process(all)
        variable v          : reg_type;
        variable parse_info : parse_info_t;
    begin
        v := r;
        -- These are single cycle flags
        v.crc_good := false;
        v.crc_bad := false;
        v.valid_redge := false;
        v.vwire_wstrobe := '0';

        -- Command parsing state machine
        case r.state is
            when idle =>
                if chip_sel_active then
                    v.state := opcode;
                end if;
            -- First byte up is the opcode! We can make some determinations
            -- based solely on the opcode, but for some opcodes will need
            -- further parsing to determine the complete next state.
            when opcode =>
                if data_from_host.valid then
                    v.cmd_header.opcode.value := data_from_host.data;
                    v.cmd_header.opcode.valid := '1';
                    v.hdr_idx := 0;
                    -- Now we need to decide where we're going
                    -- options are CRC or HEADER based on opcode
                    -- We're using case? (matching case) since some
                    -- of the opcode constants have been defined with
                    -- '-' (don't care) values.
                    case? v.cmd_header.opcode.value is
                        -- Opcodes with no additional data following, these
                        -- can just go immediately to the CRC phase
                        when opcode_get_status |
                             opcode_get_pc |
                             opcode_get_flash_c |
                             opcode_get_vwire =>
                            v.state := crc;
                        -- Config register opcodes, get and set
                        when opcode_get_configuration =>
                            v.state := parse_get_cfg_hdr;
                        when opcode_set_configuration =>
                            v.state := parse_set_cfg_hdr;
                        -- Opcodes with cycle type headers following
                        when opcode_reset =>
                            v.state := reset_word1;
                        when opcode_put_vwire =>
                            v.state := parse_vwire_put;
                        when opcode_put_iowr_short_mask =>
                            v.state := parse_iowr_put;
                        when others =>
                            v.state := parse_common_cycle_header;
                    end case?;
                end if;
            -- Special-cased the configuration registers as they don't follow
            -- the generic parsing pattern
            when parse_get_cfg_hdr =>
                -- GET CONFIGURATION has a 16bit address following it
                if data_from_host.valid then
                    v.hdr_idx := v.hdr_idx + 1;
                    v.cfg_addr := by_byte_msb_first(v.cfg_addr, data_from_host.data, r.hdr_idx);
                    -- Done, so move to CRC
                    if r.hdr_idx = addr_low_idx then
                        v.hdr_idx := 0;
                        v.state := crc;
                    end if;
                end if;
            when parse_set_cfg_hdr =>
                -- SET CONFIGURATION has a 16bit address (MSB first) and a
                -- 32bit data word (LSB first) following it.
                if data_from_host.valid then
                    v.hdr_idx := v.hdr_idx + 1;
                    case r.hdr_idx is
                        when addr_high_idx to addr_low_idx =>
                            -- MSB first, addr phase
                            v.cfg_addr := by_byte_msb_first(v.cfg_addr, data_from_host.data, r.hdr_idx);
                        when data_byte3_idx to data_byte0_idx =>
                            -- LSB First, data phase
                            v.cfg_data := by_byte_lsb_first(v.cfg_data, data_from_host.data, r.hdr_idx - 2);
                        when others =>
                            -- this should be unreachable given we transition
                            -- out by idx count below
                            null;
                    end case;
                    -- Done, so move to CRC
                    if r.hdr_idx = data_byte0_idx then
                        v.hdr_idx := 0;
                        v.state := crc;
                    end if;
                end if;
            -- The more fun command parsing. The first 3 bytes of these commands are
            -- always the same, cycle type (1 byte), tag/length[11:8] (1 byte), and
            -- length[7:0] (1 byte). The next bytes are opcode/type specific, with some
            -- having variable address byte lenths and some having data while some have
            -- no data and are just requests for data.
            when parse_common_cycle_header =>
                if data_from_host.valid then
                    v.hdr_idx := v.hdr_idx + 1;
                    case r.hdr_idx is
                        when cycle_type_idx =>
                            v.cmd_header.cycle_kind := data_from_host.data;
                        when tag_len_idx =>
                            v.cmd_header.tag := data_from_host.data(7 downto 4);
                            v.cmd_header.length(11 downto 8) := data_from_host.data(3 downto 0);
                        when len_low_idx =>
                            v.cmd_header.length(7 downto 0) := data_from_host.data;
                            -- Need to determine where to go next
                            parse_info := next_hdr_state_by_put_header(v.cmd_header);
                            v.state := parse_info.next_state;
                            v.rem_addr_bytes := parse_info.cmd_addr_bytes;
                            v.rem_data_bytes := parse_info.cmd_payload_bytes;
                        when others =>
                            -- we should never get here, but we didn't cover all the
                            -- cycle type cases so we need to have something here
                            null;
                    end case;
                end if;
            when parse_msg_header =>
                if data_from_host.valid then
                    v.hdr_idx := v.hdr_idx + 1;
                    if r.hdr_idx = 7 then
                        v.state := parse_data;
                    end if;
                end if;
            when parse_addr_header =>
                if data_from_host.valid then
                    v.hdr_idx := v.hdr_idx + 1;
                    v.rem_addr_bytes := r.rem_addr_bytes - 1;
                    -- todo we're skipping 64bit address support for now, it can be here
                    -- but nothing is stored. Do we need to store it?
                    if r.rem_addr_bytes <= 4 then
                        v.ch_addr := by_byte_msb_first(v.ch_addr, data_from_host.data, 4 - r.rem_addr_bytes);
                    end if;
                    if v.rem_addr_bytes = 0 then
                        if r.rem_data_bytes = 0 then
                            v.state := crc;
                        else
                            v.state := parse_data;
                        end if;
                    end if;
                end if;

            when parse_vwire_put =>
                -- vwire put look like this assuming 1 count:
                -- PUT_VWIRE => VWIRECOUNT, INDEX, DATA, CRC
                if data_from_host.valid then
                    v.hdr_idx := v.hdr_idx + 1;
                    if r.hdr_idx = 1 then
                        v.vwire_idx := data_from_host.data;
                    elsif r.hdr_idx = 2 then
                        v.vwire_dat := data_from_host.data;
                        v.state := crc;
                    end if;
                end if;
            --we accept this but don't do anything with it
            when parse_iowr_put =>
                if data_from_host.valid then
                    v.hdr_idx := v.hdr_idx + 1;
                    if r.hdr_idx = 5 then
                        v.state := crc;
                    end if;
                end if;
            -- not much to do here. In theory, we have already indicated that the
            -- appropriate channel has room so we sit here until the data phase has
            -- finished. Muxes elsewhere should direct this datat to appropriate buffers
            when parse_data =>
                v.hdr_idx := 0;
                if data_from_host.valid and data_from_host.ready then
                    v.rem_data_bytes := r.rem_data_bytes - 1;
                end if;
                if v.rem_data_bytes = 0 then
                    v.state := crc;
                end if;
            when reset_word1 =>
                v.reset_strobe := '0';
                if data_from_host.valid and data_from_host.ready then
                    if data_from_host.data = X"FF" then
                        v.reset_strobe := '1';
                    end if;
                end if;
                if not chip_sel_active then
                    v.state := idle;
                    v.cmd_header := rec_reset;
                end if;

            -- Yay! we made it to the last cmd byte, now we can check the CRC
            when crc =>
                if data_from_host.valid then
                    -- If we have a crc failure and we're
                    -- enforcing crc checking fail back to
                    -- IDLE and wait for the next transaction
                    if running_crc /= data_from_host.data then
                        v.crc_bad := true;
                    else
                        v.crc_good := true;
                        v.cmd_header.valid := true;
                        v.valid_redge := true;
                    end if;
                    if v.crc_bad and regs_if.enforce_crcs then
                        -- We go back to response and wait for the
                        -- chip sel to de-assert
                        v.state := response;
                        v.cmd_header.valid := false;
                    else
                        v.state := response;
                        v.cmd_header.valid := true;
                        v.valid_redge := true;
                    end if;
                end if;
            when response =>
                if response_done then
                    -- proccesed the response, invalidate header
                    v.cmd_header.valid := false;
                end if;
                if not chip_sel_active then
                    v.state := idle;
                    v.cmd_header := rec_reset;
                    v.vwire_wstrobe := '1' when r.cmd_header.valid and r.vwire_active else '0';
                    v.vwire_active := false;
                end if;
            when others =>
                null;
        end case;
        is_rx_crc_byte <= true when r.state = crc else false;
        rin <= v;
    end process;

    command_processor_reg: process(clk, reset)
    begin
        if reset then
            r <= reg_reset;
        elsif rising_edge(clk) then
            r <= rin;
        end if;
    end process;

end rtl;
