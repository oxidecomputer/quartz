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
use work.flash_channel_pkg.all;

entity response_processor is
    port (
        clk   : in    std_logic;
        reset : in    std_logic;

        clear_tx_crc   : out   std_logic;
        regs_if        : in    resp_reg_if;
        command_header : in    espi_cmd_header;
        data_to_host   : view st_source;
        response_done  : out   boolean;
        live_status    : in    status_t;
        response_crc   : in    std_logic_vector(7 downto 0);

        -- flash channel responses
        flash_resp : view flash_chan_resp_sink;


        alert_needed : out   boolean
    );
end entity;

architecture rtl of response_processor is

    type response_state_t is (
        IDLE,
        RESPONSE_CODE,
        SEND_CONFIG,
        RESPONSE_HEADER,
        RESPONSE_PAYLOAD,
        STATUS,
        CRC
    );

    type reg_type is record
        state         : response_state_t;
        status_idx    : std_logic;
        status        : status_t;
        resp_idx      : integer range 0 to 255;
        cur_data      : std_logic_vector(7 downto 0);
        reg_data      : std_logic_vector(31 downto 0);
        response_done : boolean;
        has_responded : boolean;
    end record;

    type response_hdr_t is record
        cycle_type : std_logic_vector(7 downto 0);
        tag        : std_logic_vector(3 downto 0);
        length     : std_logic_vector(11 downto 0);
    end record;

    signal r, rin : reg_type;

    signal response_chan_mux : response_hdr_t;

begin

    response_chan_mux.cycle_type <= flash_resp.cycle_type;
    response_chan_mux.tag <= flash_resp.tag;
    response_chan_mux.length <= flash_resp.length;

    flash_resp.ready <= '1' when data_to_host.ready = '1' and r.state = RESPONSE_PAYLOAD else '0';

    response_done <= r.response_done;

    -- We need to issue alterts when the live status does not match the last-sent
    -- status
    alert_needed <= true when r.has_responded and live_status /= r.status else false;
    -- Response classes:
    -- Get Stats -> response, status, crc
    -- Set Config -> response, status, crc
    -- get config -> response, data, status, crc

    -- We're going to set up response processing before we know if the
    -- CRC is good. This will help direct the data
    response_processor_comb: process(all)
        variable v : reg_type;
    begin
        v := r;

        v.response_done := false;
        -- latch any current data here
        if regs_if.rdata_valid then
            v.reg_data := regs_if.rdata;
        end if;
        case r.state is
            when IDLE =>
                -- TODO: figure out a better mask here to deal with the valid response
                -- or manange processing
                if command_header.valid and not r.response_done then
                    v.state := RESPONSE_CODE;
                end if;
            when RESPONSE_CODE =>
                v.cur_data := accept_code;
                v.resp_idx := 0;
                if data_to_host.ready then
                    case command_header.opcode.value is
                        when opcode_get_status =>
                            v.state := STATUS;
                            v.status := live_status;
                        when opcode_set_configuration =>
                            v.state := STATUS;
                            v.status := live_status;
                        when opcode_get_configuration =>
                            v.state := send_config;
                        when opcode_put_flash_np =>
                            v.cur_data := defer_code;
                            v.state := STATUS;
                            v.status := live_status;
                        when opcode_get_flash_c =>
                            v.state := RESPONSE_HEADER;
                            v.status := live_status;
                        when others =>
                            assert false
                                report "Not implemented yet"
                                severity FAILURE;
                    end case;
                end if;
            when send_config =>
                -- This needs to be LSB first
                v.cur_data := v.reg_data(7 + r.resp_idx * 8 downto r.resp_idx * 8);
                if data_to_host.ready then
                    v.resp_idx := r.resp_idx + 1;
                    if r.resp_idx = 3 then
                        v.state := STATUS;
                    end if;
                end if;
            when RESPONSE_HEADER =>
                case r.resp_idx is
                    when 0 =>
                        v.cur_data := response_chan_mux.cycle_type;
                    when 1 =>
                        v.cur_data := response_chan_mux.tag & response_chan_mux.length(11 downto 8);
                    when 2 =>
                        v.cur_data := response_chan_mux.length(7 downto 0);
                    when others =>
                        null;  -- not expected
                end case;
                if data_to_host.ready then
                    v.resp_idx := r.resp_idx + 1;
                    if r.resp_idx = 2 then
                        v.state := RESPONSE_PAYLOAD;
                    end if;
                end if;
            when RESPONSE_PAYLOAD =>
                if data_to_host.ready then
                    v.cur_data := flash_resp.data;
                    v.resp_idx := r.resp_idx + 1;
                    if r.resp_idx = 255 then
                        v.state := STATUS;
                    end if;
                end if;
                null;
            when STATUS =>
                if data_to_host.ready then
                    if r.status_idx = '0' then
                        v.status_idx := '1';
                    elsif r.status_idx = '1' then
                        v.status_idx := '0';
                        v.state := CRC;
                    end if;
                end if;
            when CRC =>
                if data_to_host.ready then
                    v.response_done := true;
                    v.state := IDLE;
                end if;
                v.has_responded := true;
        end case;
        -- Status words
        if r.state = STATUS and r.status_idx = '0' then
            v.cur_data := pack(r.status)(7 downto 0);
        elsif r.state = STATUS then
            v.cur_data := pack(r.status)(15 downto 8);
        end if;
        -- CRC
        if r.state = CRC then
            v.cur_data := response_crc;
        end if;
        rin <= v;
    end process;

    response_processor_reg: process(clk, reset)
    begin
        if reset then
            r <= (IDLE, '0', rec_reset, 0, (others => '0'), (others => '0'), false, false);
        elsif rising_edge(clk) then
            r <= rin;
        end if;
    end process;

    clear_tx_crc       <= '1' when r.state = IDLE else '0';
    data_to_host.data  <= r.cur_data;
    data_to_host.valid <= '1' when r.state /= IDLE else '0';

end rtl;
