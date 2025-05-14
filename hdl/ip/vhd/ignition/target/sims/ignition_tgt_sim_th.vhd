-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2025 Oxide Computer Company

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
    context vunit_lib.vunit_context;
    context vunit_lib.com_context;
    context vunit_lib.vc_context;

use work.basic_stream_pkg.all;
use work.ignition_sim_pkg.all;

entity ignition_tgt_sim_th is
end entity;

architecture th of ignition_tgt_sim_th is

    signal clk   : std_logic := '0';
    signal reset : std_logic := '1';
    signal serial_in : std_logic;
    signal serial_out : std_logic;

begin

    -- set up a fastish clock for the sim env
    -- and release reset after a bit of time
    clk   <= not clk after 10 ns;
    reset <= '0' after 200 ns;


    ignition_controller_model_inst: entity work.ignition_controller_model
     generic map(
        source => source
    )
     port map(
        clk => clk,
        reset => reset,
        serial_in => serial_in,
        serial_out => serial_out
    );

    ignition_target_common_inst: entity work.ignition_target_common
     port map(
        clk => clk,
        reset => reset,
        sw0_serial_in => serial_out,
        sw0_serial_out => open,
        sw1_serial_in => '0',
        sw1_serial_out => open,
        ignit_to_ibc_pwren => open,
        hotswap_restart_l => open,
        ignit_led_l => open,
        a3_pwr_fault_l => '1',
        a2_pg => '1',
        sp_fault_l => '1',
        rot_fault_l => '1',
        push_btn_l => '1',
        ignition_id => (others => '0')
    );
end th;