-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2025 Oxide Computer Company

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- A0HP sequencing for the T6 NIC used on the SP5 cosmo sled
entity nic_seq is
    port(
        clk : in std_logic;
        reset : in std_logic;

        sw_enable : in std_logic;
        upstream_ok : in std_logic;

        sp5_to_nic_mfg_mode_l : in std_logic;
        fpga1_to_nic_mfg_mode_l : in std_logic;

    );
end entity;

architecture rtl of nic_seq is
    type state_t is ( IDLE, PWR_EN, WAIT_FOR_PGS, EARLY_RESET, DONE );

    type nic_r_t is record
        state : state_t;
        nic_perst_l : std_logic;
        nic_cld_rst_l : std_logic;
    end record;

    constant nic_r_reset : nic_r_t := (
        state => IDLE
    );
    signal nic_r, nic_rin : nic_r_t;

begin

    nic_sm:process(all)
        variable v : nic_r_t;
    begin

        v := nic_r;

        case nic_r.state is
            when IDLE =>
                if sw_enable = '1' then
                    v.state := PWR_EN;
                end if;

            when PWR_EN =>
                v.state := WAIT_FOR_PGS;

            when WAIT_FOR_PGS =>
                v.state := EARLY_RESET;

            when EARLY_RESET =>
                v.state := DONE;

            when DONE =>
                v.state := IDLE;

        end case;


        nic_rin <= v;

    end process;


    reg: process(clk, reset)
    begin
        if reset then
            nic_r <= nic_r_reset;
        elsif rising_edge(clk) then
            nic_r <= nic_rin;
        end if;
    end process;


end rtl;