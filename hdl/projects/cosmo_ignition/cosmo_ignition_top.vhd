-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2025 Oxide Computer Company

-- Cosmo Front Hot-plug FPGA targeting an ice40 HX8k


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.ignition_pkg.all;


entity cosmo_ignition_top is
    port (
        clk_50mhz_ign_trgt_fpga : in std_logic;
        ign_trgt_fpga_design_reset_l : in std_logic;
        ign_trgt_fpga_debug_led : out std_logic_vector(3 downto 0);
        ign_trgt_fpga_spare_v3p3 : out std_logic_vector(7 downto 0);
        ign_trgt_id : in std_logic_vector(7 downto 0);
        ign_trgt_fpga_lvds_status_led_en_l : out std_logic;
        ign_trgt_fpga_pushbutton_reset_l : in std_logic;
        lvds_rsw0_to_ign_trgt_fpga_p : inout std_logic;
        lvds_ign_trgt_fpga_to_rsw0_p : inout std_logic;
        lvds_ign_trgt_fpga_to_rsw0_n : inout std_logic;
        lvds_rsw1_to_ign_trgt_fpga_p : inout std_logic;
        lvds_ign_trgt_fpga_to_rsw1_p : inout std_logic;
        lvds_ign_trgt_fpga_to_rsw1_n : inout std_logic;
        v3p3_fpga2_a2_pg : in std_logic;
        v1p2_fpga2_a2_pg : in std_logic;
        v2p5_fpga2_a2_pg : in std_logic;
        main_hsc_restart : out std_logic;
        ibc_en : out std_logic;
        v5p0_sys_a2_pg : in std_logic;
        v3p3_sys_a2_pg : in std_logic;
        v1p8_sys_a2_pg : in std_logic;
        v1p0_mgmt_a2_pg : in std_logic;
        v2p5_mgmt_a2_pg : in std_logic;
        v12_sys_a2_pg_l : in std_logic;
        main_hsc_pg : in std_logic;
        sp_fault_l : in std_logic;
        rot_fault_l : in std_logic

    );
end entity;

architecture rtl of cosmo_ignition_top is
    signal sw0_serial_in : std_logic;
    signal sw0_serial_out : std_logic;
    signal sw1_serial_in : std_logic := '0';
    signal sw1_serial_out : std_logic;
    signal hotswap_restart_l : std_logic;
    signal led_counter : unsigned(24 downto 0) := (others => '0');
    signal reset_sync1 : std_logic;
    signal reset_syncd : std_logic;
   
begin
    rst_sync: process(clk_50mhz_ign_trgt_fpga, ign_trgt_fpga_design_reset_l)
    begin
        if ign_trgt_fpga_design_reset_l = '0' then
            reset_sync1 <= '1';
            reset_syncd <= '1';
        elsif rising_edge(clk_50mhz_ign_trgt_fpga) then
            -- flipping to active high here and providing a 2 clock sync
            reset_sync1 <= '0';
            reset_syncd <= reset_sync1;
        end if;
    end process;

     -- Blink an LED at some rate
    led: process(clk_50mhz_ign_trgt_fpga, reset_syncd)
    begin
        if reset_syncd = '1' then
            led_counter <= (others => '0');
        elsif rising_edge(clk_50mhz_ign_trgt_fpga) then
            led_counter <= led_counter + 1;
        end if;
    end process;
    ign_trgt_fpga_lvds_status_led_en_l <= led_counter(23);


    ignition_target_common_inst: entity work.ignition_target_common
     generic map(
        NUM_LEDS => 4,
        NUM_BITS_IGNITION_ID => 8
    )
     port map(
        clk => clk_50mhz_ign_trgt_fpga,
        reset => reset_syncd,
        sw0_serial_in => sw0_serial_in,
        sw0_serial_out => sw0_serial_out,
        sw1_serial_in => sw1_serial_in,
        sw1_serial_out => sw1_serial_out,
        ignit_to_ibc_pwren => ibc_en,
        hotswap_restart_l => hotswap_restart_l,
        ignit_led_l => ign_trgt_fpga_debug_led,
        a3_pwr_fault_l => '1',
        a2_pg => '1',
        sp_fault_l => sp_fault_l,
        rot_fault_l => rot_fault_l,
        push_btn_l => '1',
        ignition_id => COMPUTE_SLED,
        dbg => ign_trgt_fpga_spare_v3p3(4 downto 2)
    );

    main_hsc_restart <= not hotswap_restart_l;
    
    ignition_io_inst: entity work.ignition_io
     port map(
        clk => clk_50mhz_ign_trgt_fpga,
        sw0_serial_in => sw0_serial_in,
        sw0_serial_out => sw0_serial_out,
        sw1_serial_in => sw1_serial_in,
        sw1_serial_out => sw1_serial_out,
        rsw0_serial_in_p => lvds_rsw0_to_ign_trgt_fpga_p,
        rsw0_serial_out_p => lvds_ign_trgt_fpga_to_rsw0_p,
        rsw0_serial_out_n => lvds_ign_trgt_fpga_to_rsw0_n,
        rsw1_serial_in_p => lvds_rsw1_to_ign_trgt_fpga_p,
        rsw1_serial_out_p => lvds_ign_trgt_fpga_to_rsw1_p,
        rsw1_serial_out_n => lvds_ign_trgt_fpga_to_rsw1_n
    );

    ign_trgt_fpga_spare_v3p3(0) <= not sw0_serial_in;
    ign_trgt_fpga_spare_v3p3(1) <= sw0_serial_out;
end rtl;