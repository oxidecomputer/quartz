-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2025 Oxide Computer Company

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.sequencer_io_pkg.all;

entity seq_sync is
    port (
        clk : in std_logic;
        reset : in std_logic;

        -- pins (unsync'd) interface
        early_power_pins : view early_power_at_fpga;
        ddr_bulk_pins: view ddr_bulk_power_at_fpga;
        group_a_pins : view group_a_power_at_fpga;
        group_b_pins : view group_b_power_at_fpga;
        group_c_pins : view group_c_power_at_fpga;
        sp5_seq_pins : view sp5_seq_at_fpga;
        nic_rails_pins : view nic_power_at_fpga;
        nic_seq_pins: view nic_seq_at_fpga;
        -- internal, synchronized interfaces
        early_power : view early_power_on_board;
        ddr_bulk: view ddr_bulk_at_reg;
        group_a : view group_a_power_at_reg;
        group_b : view group_b_power_at_reg;
        group_c : view group_c_power_at_reg;
        sp5_seq : view sp5_seq_at_sp5;
        nic_rails : view nic_power_at_reg;
        nic_seq: view nic_seq_at_nic
    );
    end entity;

architecture rtl of seq_sync is
   signal  nic_sync_5v_hsc_pg_l : std_logic;
   signal nic_sync_12v_hsc_pg_l : std_logic;
begin

    -- Early power sync stuff
    early_power_pins.fan_central_hsc_disable <= early_power.fan_central_hsc_disable;
    early_power_pins.fan_east_hsc_disable <= early_power.fan_east_hsc_disable;
    early_power_pins.fan_west_hsc_disable <= early_power.fan_west_hsc_disable;
    fan_cent_pg: entity work.meta_sync
     port map(
        async_input => early_power_pins.fan_central_hsc_pg,
        clk => clk,
        sycnd_output => early_power.fan_central_hsc_pg
    );
    fan_east_pg: entity work.meta_sync
    port map(
       async_input => early_power_pins.fan_east_hsc_pg,
       clk => clk,
       sycnd_output => early_power.fan_east_hsc_pg
    );
    fan_west_pg: entity work.meta_sync
    port map(
       async_input => early_power_pins.fan_west_hsc_pg,
       clk => clk,
       sycnd_output => early_power.fan_west_hsc_pg
    );
    fan_fail: entity work.meta_sync
    port map(
       async_input => early_power_pins.fan_fail,
       clk => clk,
       sycnd_output => early_power.fan_fail
    );

    -- ddr bulk sync stuff
    ddr_bulk_pins.abcdef_hsc.enable <=  ddr_bulk.abcdef_hsc.enable;
    ddr_bulk_pins.ghijkl_hsc.enable <=  ddr_bulk.ghijkl_hsc.enable;
    abcdef_hsc_pg: entity work.meta_sync
    port map(
       async_input => ddr_bulk_pins.abcdef_hsc.pg,
       clk => clk,
       sycnd_output => ddr_bulk.abcdef_hsc.pg
    );
    ghijkl_hsc_pg: entity work.meta_sync
    port map(
       async_input => ddr_bulk_pins.ghijkl_hsc.pg,
       clk => clk,
       sycnd_output => ddr_bulk.ghijkl_hsc.pg
    );

    -- group a sync stuff
    group_a_pins.pwr_v1p5_rtc.enable <= group_a.pwr_v1p5_rtc.enable;
    group_a_pins.v3p3_sp5_a1.enable <= group_a.v3p3_sp5_a1.enable;
    group_a_pins.v1p8_sp5_a1.enable <= group_a.v1p8_sp5_a1.enable;
    pwr_v1p5_rtc_pg: entity work.meta_sync
    port map(
       async_input => group_a_pins.pwr_v1p5_rtc.pg,
       clk => clk,
       sycnd_output => group_a.pwr_v1p5_rtc.pg
    );
    v3p3_sp5_a1_pg: entity work.meta_sync
    port map(
       async_input => group_a_pins.v3p3_sp5_a1.pg,
       clk => clk,
       sycnd_output => group_a.v3p3_sp5_a1.pg
    );
    v1p8_sp5_a1_pg: entity work.meta_sync
    port map(
       async_input => group_a_pins.v1p8_sp5_a1.pg,
       clk => clk,
       sycnd_output => group_a.v1p8_sp5_a1.pg
    );

    -- group b sync stuff
    group_b_pins.v1p1_sp5.enable <= group_b.v1p1_sp5.enable;
    v1p1_sp5_pg: entity work.meta_sync
    port map(
       async_input => group_b_pins.v1p1_sp5.pg,
       clk => clk,
       sycnd_output => group_b.v1p1_sp5.pg
    );

    -- group c sync stuff
    group_c_pins.vddio_sp5_a0.enable <= group_c.vddio_sp5_a0.enable;
    group_c_pins.vddcr_cpu1.enable <= group_c.vddcr_cpu1.enable;
    group_c_pins.vddcr_cpu0.enable <= group_c.vddcr_cpu0.enable;
    group_c_pins.vddcr_soc.enable <= group_c.vddcr_soc.enable;
    vddio_sp5_a0_pg: entity work.meta_sync
    port map(
       async_input => group_c_pins.vddio_sp5_a0.pg,
       clk => clk,
       sycnd_output => group_c.vddio_sp5_a0.pg
    );
    vddcr_cpu1_pg: entity work.meta_sync
    port map(
       async_input => group_c_pins.vddcr_cpu1.pg,
       clk => clk,
       sycnd_output => group_c.vddcr_cpu1.pg
    );
    vddcr_cpu0_pg: entity work.meta_sync
    port map(
       async_input => group_c_pins.vddcr_cpu0.pg,
       clk => clk,
       sycnd_output => group_c.vddcr_cpu0.pg
    );
    vddcr_soc_pg: entity work.meta_sync
    port map(
       async_input => group_c_pins.vddcr_soc.pg,
       clk => clk,
       sycnd_output => group_c.vddcr_soc.pg
    );

    -- SP5 seq stuff
    sp5_seq_pins.rsmrst_l <= sp5_seq.rsmrst_l;
    sp5_seq_pins.pwr_btn_l <= sp5_seq.pwr_btn_l;
    sp5_seq_pins.pwr_good <= sp5_seq.pwr_good;
    sp5_seq_pins.is_cosmo <= sp5_seq.is_cosmo;
    thermtrip_l_sync: entity work.meta_sync
    port map(
       async_input => sp5_seq_pins.thermtrip_l,
       clk => clk,
       sycnd_output => sp5_seq.thermtrip_l
    );
   smerr_l_sync: entity work.meta_sync
      port map(
         async_input => sp5_seq_pins.smerr_l,
         clk => clk,
         sycnd_output => sp5_seq.smerr_l
   );
    reset_l_sync: entity work.meta_sync
    port map(
       async_input => sp5_seq_pins.reset_l,
       clk => clk,
       sycnd_output => sp5_seq.reset_l
    );
    pwr_ok_sync: entity work.meta_sync
    port map(
       async_input => sp5_seq_pins.pwr_ok,
       clk => clk,
       sycnd_output => sp5_seq.pwr_ok
    );
    slp_s3_l_sync: entity work.meta_sync
    port map(
       async_input => sp5_seq_pins.slp_s3_l,
       clk => clk,
       sycnd_output => sp5_seq.slp_s3_l
    );
    slp_s5_l_sync: entity work.meta_sync
    port map(
       async_input => sp5_seq_pins.slp_s5_l,
       clk => clk,
       sycnd_output => sp5_seq.slp_s5_l
    );
    pwrgd_out_sync: entity work.meta_sync
    port map(
       async_input => sp5_seq_pins.pwrgd_out,
       clk => clk,
       sycnd_output => sp5_seq.pwrgd_out
    );

    -- nic rails sync stuff
    nic_rails_pins.nic_hsc_12v.enable <= nic_rails.nic_hsc_12v.enable;
    v1p5_nic_a0hp: entity work.meta_sync
    port map(
       async_input => nic_rails_pins.v1p5_nic_a0hp.pg,
       clk => clk,
       sycnd_output => nic_rails.v1p5_nic_a0hp.pg
    );
    v1p2_nic_pcie_a0hp: entity work.meta_sync
    port map(
       async_input => nic_rails_pins.v1p2_nic_pcie_a0hp.pg,
       clk => clk,
       sycnd_output => nic_rails.v1p2_nic_pcie_a0hp.pg
    );
    v1p2_nic_enet_a0hp: entity work.meta_sync
    port map(
       async_input => nic_rails_pins.v1p2_nic_enet_a0hp.pg,
       clk => clk,
       sycnd_output => nic_rails.v1p2_nic_enet_a0hp.pg
    );
    v3p3_nic_a0hp: entity work.meta_sync
    port map(
       async_input => nic_rails_pins.v3p3_nic_a0hp.pg,
       clk => clk,
       sycnd_output => nic_rails.v3p3_nic_a0hp.pg
    );
    v1p1_nic_a0hp: entity work.meta_sync
    port map(
       async_input => nic_rails_pins.v1p1_nic_a0hp.pg,
       clk => clk,
       sycnd_output => nic_rails.v1p1_nic_a0hp.pg
    );
    v0p96_nic_vdd_a0hp: entity work.meta_sync
    port map(
       async_input => nic_rails_pins.v0p96_nic_vdd_a0hp.pg,
       clk => clk,
       sycnd_output => nic_rails.v0p96_nic_vdd_a0hp.pg
    );
    nic_hsc_12v: entity work.meta_sync
    port map(
       async_input => nic_rails_pins.nic_hsc_12v.pg,
       clk => clk,
       sycnd_output => nic_sync_12v_hsc_pg_l
    );
    nic_hsc_5v: entity work.meta_sync
    port map(
       async_input => nic_rails_pins.nic_hsc_5v.pg,
       clk => clk,
       sycnd_output => nic_sync_5v_hsc_pg_l
    );
    -- TODO: maybe clean up the PG_Ls here

    nic_rails.nic_hsc_5v.pg <= not nic_sync_5v_hsc_pg_l;
    nic_rails.nic_hsc_12v.pg  <= not nic_sync_12v_hsc_pg_l;
    -- nic sync-related stuff
    nic_seq_pins.cld_rst_l <= nic_seq.cld_rst_l;
    nic_seq_pins.perst_l <= nic_seq.perst_l;
    nic_seq_pins.eeprom_wp_l <= nic_seq.eeprom_wp_l;
    nic_seq_pins.eeprom_wp_buffer_oe_l <= nic_seq.eeprom_wp_buffer_oe_l;
    nic_seq_pins.flash_wp_l <= nic_seq.flash_wp_l;
    nic_seq_pins.nic_mfg_mode_l <= nic_seq.nic_mfg_mode_l;
    nic_seq_pins.nic_pcie_clk_buff_oe_l <= nic_seq.nic_pcie_clk_buff_oe_l;
    ext_rst_l_sync: entity work.meta_sync
    port map(
       async_input => nic_seq_pins.ext_rst_l,
       clk => clk,
       sycnd_output => nic_seq.ext_rst_l
    );
    sp5_mfg_mode_l_sync: entity work.meta_sync
    port map(
       async_input => nic_seq_pins.sp5_mfg_mode_l,
       clk => clk,
       sycnd_output => nic_seq.sp5_mfg_mode_l
    );

end rtl;
