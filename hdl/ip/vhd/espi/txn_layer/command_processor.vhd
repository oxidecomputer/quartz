-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2024 Oxide Computer Company

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;
use work.qspi_link_layer_pkg.all;
use work.espi_base_types_pkg.all;
use work.espi_protocol_pkg.all;

entity command_processor is
    port (
        clk   : in    std_logic;
        reset : in    std_logic;

        -- register layer connections
        running_crc    : in    std_logic_vector(7 downto 0);
        regs_if        : view bus_side;
        command_header : out   espi_cmd_header;
        response_done  : in    boolean;

        -- Link-layer connections
        is_crc_byte     : out   boolean;
        chip_sel_active : in    boolean;
        -- "Streaming" data to serialize and transmit
        data_from_host : view st_sink
    );
end entity;

architecture rtl of command_processor is

    type   pkt_state_t is (
        idle,
        opcode,
        parse_cycle_header,
        parse_get_cfg_hdr,
        parse_set_cfg_hdr,
        data,
        crc,
        response
    );
    signal clear_rx_crc : std_logic;

    type reg_type is record
        state      : pkt_state_t;
        crc_good   : boolean;
        crc_bad    : boolean;
        cmd_header : espi_cmd_header;
        cfg_addr   : std_logic_vector(15 downto 0);
        cfg_data   : std_logic_vector(31 downto 0);
        hdr_idx    : integer range 0 to 7;
    end record;

    signal r, rin : reg_type;

begin

    regs_if.write <= '1' when r.cmd_header.opcode.value = opcode_set_configuration and (r.crc_good or (r.crc_bad and (not regs_if.enforce_crcs))) else '0';
    regs_if.read  <= '1' when r.cmd_header.opcode.value = opcode_get_configuration and (r.crc_good or (r.crc_bad and (not regs_if.enforce_crcs))) else '0';
    regs_if.addr  <= r.cfg_addr;
    regs_if.wdata <= r.cfg_data;

    clear_rx_crc <= '1' when r.state = idle else '0';

    command_header <= r.cmd_header;

    command_processor_comb: process(all)
        variable v : reg_type;
    begin
        v := r;
        -- These are single cycle flags
        v.crc_good := false;
        v.crc_bad := false;
        case r.state is
            when idle =>
                if chip_sel_active then
                    v.state := opcode;
                end if;
            when opcode =>
                if data_from_host.valid then
                    v.cmd_header.opcode.value := data_from_host.data;
                    v.cmd_header.opcode.valid := '1';
                    v.hdr_idx := 0;
                    -- Now we need to decide where we're going
                    -- options are CRC or HEADER based on opcode
                    case v.cmd_header.opcode.value is
                        -- Opcodes with no additional data following
                        when opcode_get_status |
                             opcode_reset =>
                            v.state := crc;
                        when opcode_get_configuration =>
                            v.state := parse_get_cfg_hdr;
                        when opcode_set_configuration =>
                            v.state := parse_set_cfg_hdr;
                        when others =>
                            v.state := parse_cycle_header;
                    end case;
                end if;
            when parse_get_cfg_hdr =>
                -- GET CONFIGURATION has a 16bit address following it
                if data_from_host.valid then
                    v.hdr_idx := v.hdr_idx + 1;
                    by_byte_msb_first(v.cfg_addr, data_from_host.data, r.hdr_idx);
                    if r.hdr_idx = addr_low_idx then
                        v.hdr_idx := 0;
                        v.state := crc;
                    end if;
                end if;
            when parse_set_cfg_hdr =>
                -- SET CONFIGURATION has a 16bit address and a
                -- 32bit data word following it.
                if data_from_host.valid then
                    v.hdr_idx := v.hdr_idx + 1;
                    case r.hdr_idx is
                        when addr_high_idx to addr_low_idx =>
                            -- MSB first, addr phase
                            by_byte_msb_first(v.cfg_addr, data_from_host.data, r.hdr_idx);
                        when data_byte3_idx to data_byte0_idx =>
                            -- LSB First, data phase
                            by_byte_lsb_first(v.cfg_data, data_from_host.data, r.hdr_idx - 2);
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
            when parse_cycle_header =>
                -- Need to figure out by opcode when we know total length
                -- befdore CRC. Anything transferred here goes into the buffer
                -- and at CRC we'll mark the descriptor valid to start response
                -- processing.
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
                        when others =>
                            -- this should be unreachable given we transition
                            -- out by TBD, not yet implemented!!!
                            null;
                    end case;
                end if;
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
                    end if;
                    if v.crc_bad and regs_if.enforce_crcs then
                        v.state := idle;
                    else
                        v.state := response;
                        v.cmd_header.valid := true;
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
                end if;
            when others =>
                null;
        end case;
        is_crc_byte <= true when r.state = crc else false;
        rin <= v;
    end process;

    command_processor_reg: process(clk, reset)
    begin
        if reset then
            r <= (idle, false, false, rec_reset, (others => '0'), (others => '0'), 0);
        elsif rising_edge(clk) then
            r <= rin;
        end if;
    end process;

end rtl;
