-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2024 Oxide Computer Company

-- In the fast domain, before we've done full packet parsing, we need
-- some basic parsing to determine the size of the packet and when the
-- turnaround time is. This block does the minimal parsing required to
-- determine the size of the incomming packet.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

use work.espi_protocol_pkg.all;
use work.link_layer_pkg.all;

entity cmd_sizer is
    port (
        clk   : in    std_logic;
        reset : in    std_logic;

        cs_n  : in   std_logic;
        cmd   : view byte_stream_snooper_sink;

        size_info: out size_info_t;
        espi_reset: out std_logic

    );
end entity;

architecture rtl of cmd_sizer is
    type state_t is (idle, opcode, cycle_type, tag_len, len, inband_reset, size_known, invalid);

    type reg_type is record
        espi_reset: std_logic;
        state : state_t;
        hdr: hdr_t;
        size_info: size_info_t;
    end record;

    constant rec_reset: reg_type := (
        '0',
        idle,
        rec_reset,
        rec_reset
    );

    signal r, rin: reg_type;
begin

    size_info <= r.size_info;
    espi_reset <= r.espi_reset;

    sm: process(all)
        variable v : reg_type;
        variable byte_transfer: std_logic;
    begin
        v := r;
        byte_transfer := cmd.valid and cmd.ready;
        -- single cycle flag:
        v.espi_reset := '0';

        case r.state is
            when idle =>
                v.size_info.valid := '0';
                if byte_transfer then
                    v.state := opcode;
                    v.hdr.opcode := cmd.data;
                end if;

            when opcode =>
                if r.hdr.opcode = opcode_reset then
                    v.state := inband_reset;
                    
                elsif known_size_by_opcode(r.hdr) then
                    v.state := size_known;
                    v.size_info.size := size_by_header(r.hdr);
                elsif byte_transfer then
                    v.state := cycle_type;
                    v.hdr.cycle_type := cmd.data;
                end if;
                if cs_n = '1' then
                    v.size_info.valid := '0';
                    v.state := idle;
                end if;

            when cycle_type =>
                if known_size_by_cycle_type(r.hdr) then
                    v.state := size_known;
                    v.size_info.size := size_by_header(r.hdr);
                elsif byte_transfer then
                    v.state := tag_len;
                    v.hdr.len(11 downto 8) := cmd.data(3 downto 0);
                end if;
                if cs_n = '1' then
                    v.size_info.valid := '0';
                    v.state := idle;
                end if;

            when tag_len =>
                if byte_transfer then
                    v.state := len;
                    v.hdr.len(7 downto 0) := cmd.data(7 downto 0);
                    v.state := len;
                end if;
                if cs_n = '1' then
                    v.size_info.valid := '0';
                    v.state := idle;
                end if;

            when len =>
                if known_size_by_length(r.hdr) then
                    v.state := size_known;
                    v.size_info.size := size_by_header(r.hdr);
                elsif byte_transfer then
                    v.state := invalid;
                end if;
                if cs_n = '1' then
                    v.size_info.valid := '0';
                    v.state := idle;
                end if;
                    
            when size_known =>
                v.size_info.valid := '1';
                if cs_n = '1' then
                    v.size_info.valid := '0';
                    v.state := idle;
                end if;
                if cs_n = '1' then
                    v.size_info.valid := '0';
                    v.state := idle;
                end if;

            when invalid =>
                v.size_info.invalid := '1';
                if cs_n = '1' then
                    v.size_info.invalid := '0';
                    v.state := idle;
                end if;

            when inband_reset =>
                -- 2nd byte of reset also opcode_reset
                if byte_transfer = '1' and cmd.data = opcode_reset then
                    v.espi_reset := '1';
                end if;
                if cs_n = '1' then
                    v.size_info.valid := '0';
                    v.state := idle;
                end if;
        end case;

        rin <= v;

    end process;

    reg: process(clk, reset)
    begin
        if reset then
            r <= rec_reset;
        elsif rising_edge(clk) then
            r <= rin;
        end if;
    end process;

end architecture;