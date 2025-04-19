-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2025 Oxide Computer Company

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.cem_hp_io_pkg.all;

entity cem_model is
    port (
        clk : in std_logic;
        reset : in std_logic;

        cem_to_fpga : out cem_to_fpga_io_t;
        fpga_to_cem : in fpga_to_cem_io_t;
        fpga_to_hp : in fpga_to_hp_io_t;
        hp_to_fpga : out hp_to_fpga_io_t
    );
end entity;

architecture model of cem_model is
    signal hp_present_l : std_logic;
    signal hp_pwrflt_l : std_logic;
    signal hp_atnsw_l : std_logic;
    signal hp_emils : std_logic;
    signal hp_atnled : std_logic := '0'; -- default to off
    signal hp_pwren_l : std_logic := '1'; -- default to off
    signal hp_emil : std_logic := '1'; -- default to on

begin
    -- Deal with the valid sharkfin case first:
    
    cem_to_fpga.sharkfin_present <= '1';
    cem_to_fpga.ifdet_l <= '0'; -- valid U.2
    cem_to_fpga.prsnt_l <= '0'; -- here
    cem_to_fpga.pwrflt_l <= '1'; -- no power fault
    cem_to_fpga.pg_l <= not fpga_to_cem.pwren; -- power good is driven by the FPGA

    hp_present_l <= fpga_to_hp.present_l;
    hp_pwrflt_l <= fpga_to_hp.pwrflt_l;
    hp_atnsw_l <= fpga_to_hp.atnsw_l;
    hp_emils <= fpga_to_hp.emils;

    hp_to_fpga.atnled <= hp_atnled;
    hp_to_fpga.pwren_l <= hp_pwren_l;
    hp_to_fpga.emil <= hp_emil;





end model;