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
use work.ignition_pkg.all;
use work.time_pkg.all;

entity ignition_tgt_sim_th is
end entity;

architecture th of ignition_tgt_sim_th is

    signal clk   : std_logic := '0';
    signal reset : std_logic := '1';
    signal serial_in : std_logic_vector(1 downto 0);
    signal serial_out : std_logic_vector(1 downto 0);
    signal ibc_en_pin : std_logic;

begin

    -- set up a fastish clock for the sim env
    -- and release reset after a bit of time
    clk   <= not clk after 10 ns;
    reset <= '0' after 200 ns;


    controller_ch0: entity work.ignition_controller_model
     generic map(
        source => source0
    )
     port map(
        clk => clk,
        reset => reset,
        serial_in => serial_in(0),
        serial_out => serial_out(0)
    );

    controller_ch1: entity work.ignition_controller_model
     generic map(
        source => source1
    )
     port map(
        clk => clk,
        reset => reset,
        serial_in => serial_in(1),
        serial_out => serial_out(1)
    );

    ignition_target_common_inst: entity work.ignition_target_common
     generic map(
        RESEND_CNTS => calc_ms(1, 20, 21),
        COOLDOWN_CNTS => calc_us(1, 2, 27),
        NUM_BITS_IGNITION_ID => 8
     )
     port map(
        clk => clk,
        reset => reset,
        sw0_serial_in => serial_out(0),
        sw0_serial_out => serial_in(0),
        sw1_serial_in => serial_out(1),
        sw1_serial_out => serial_in(1),
        ignit_to_ibc_pwren => ibc_en_pin,
        hotswap_restart_l => open,
        ignit_led_l => open,
        a3_pwr_fault_l => '1',
        a2_pg => '1',
        sp_fault_l => '1',
        rot_fault_l => '1',
        push_btn_l => '1',
        ignition_id => COMPUTE_SLED
    );
end th;