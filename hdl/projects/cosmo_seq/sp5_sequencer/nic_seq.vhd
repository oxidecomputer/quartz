-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2025 Oxide Computer Company

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.sequencer_io_pkg.all;

-- A0HP sequencing for the T6 NIC used on the SP5 cosmo sled
entity nic_seq is
    generic(
        CNTS_P_MS: integer
    );
    port(
        clk : in std_logic;
        reset : in std_logic;

        sw_enable : in std_logic;
        upstream_ok : in std_logic;

        sp5_to_nic_mfg_mode_l : in std_logic;
        fpga1_to_nic_mfg_mode_l : in std_logic;

        nic_rails: view nic_power_at_fpga;



    );
end entity;

architecture rtl of nic_seq is
    constant ONE_MS : integer := 1 * CNTS_P_MS;
    constant THIRTY_MS : integer := 30 * ONE_MS;
    constant TWENTY_MS : integer := 20 * ONE_MS;
    constant FORTY_MS : integer := 40 * ONE_MS;

    type state_t is ( IDLE, PWR_EN, WAIT_FOR_PGS, EARLY_CLD_RST, EARLY_PERST, DONE );

    type nic_r_t is record
        state : state_t;
        cnts  : unsigned(31 downto 0);
        nic_power_en : std_logic;
        nic_perst_l : std_logic;
        nic_cld_rst_l : std_logic;
    end record;

    constant nic_r_reset : nic_r_t := (
        state => IDLE,
        (others => '0'),
        '0',
        '0',
        '0'
    );
    signal nic_r, nic_rin : nic_r_t;

begin

    nic_sm:process(all)
        variable v : nic_r_t;
    begin

        v := nic_r;

        case nic_r.state is
            when IDLE =>
                v.nic_perst_l := '0';
                v.nic_cld_rst_l := '0';
                v.cnts := (others => '0');
                if sw_enable and upstream_ok then
                    v.state := PWR_EN;
                end if;

            when PWR_EN =>
                v.nic_power_en := '1';
                v.state := WAIT_FOR_PGS;

            when WAIT_FOR_PGS =>
                v.cnts := (others => '0');
                if is_power_good(nic_rails) then
                    v.cnts := nic_r.cnts + 1;
                end if;
                -- Hang here for 30ms to meet the minimum and then another
                -- 20ms before cld_rst_l release
                if nic_r.cnts = THIRTY_MS + TWENTY_MS then
                    v.state := EARLY_CLD_RST;
                    v.cnts := (others => '0');
                end if;

            when EARLY_CLD_RST =>
                -- We release reset "early" 
                v.nic_cld_rst_l := '1';
                if nic_r.cnts = TWENTY_MS then
                    v.state := EARLY_PERST;
                    v.cnts := (others => '0');
                end if;
        
            when EARLY_PERST =>
                -- We release reset "early" 
                v.state := DONE;
                v.nic_perst_l := '0';

            when DONE =>
                -- nothing downstream to worry about
                if sw_enable = '0' then
                    v.nic_power_en := '1';
                    v.state := IDLE;
                end if;

        end case;


        -- TODO: deal with faults


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