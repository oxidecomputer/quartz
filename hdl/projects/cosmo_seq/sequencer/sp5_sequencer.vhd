-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2025 Oxide Computer Company

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.axil8x32_pkg;

use work.sequencer_io_pkg.all;
use work.sequencer_regs_pkg.all;

-- This block provides the power control on an SP5-based sled including
-- state machines and registers for software.
-- It assumes all inputs are *not* synchronized to the clock domain
-- and provides registers for out outputs that are destined for off-chip
-- devices.  It provides no tri-state logic so tri-stating must be done
-- at the chip top if needed/desired.
entity sp5_sequencer is
    generic (
        CNTS_P_MS: integer
    );
    port (
        clk : in std_logic;
        reset : in std_logic;

        axi_if : view axil8x32_pkg.axil_target;
        -- These signals are useful throughout the design for dealing with
        -- buffers, a0-domain "reset" kinds of things etc
        a0_ok : out std_logic;
        a0_idle: out std_logic;
        -- Early power stuff
        early_power_pins : view early_power_at_fpga;
        -- DDR Hotswap
        ddr_bulk_pins: view ddr_bulk_power_at_fpga;
        -- group A supplies
        group_a_pins: view group_a_power_at_fpga;
        -- group b supplies
        group_b_pins : view group_b_power_at_fpga;
        -- group c supplies
        group_c_pins : view group_c_power_at_fpga;
        -- SP5 sequencing I/O
        sp5_seq_pins : view sp5_seq_at_fpga;
        -- nic supplies
        nic_rails_pins : view nic_power_at_fpga;
        -- nic sequencing I/O
        nic_seq_pins: view nic_seq_at_fpga;

        sp5_t6_power_en : in std_logic;
        sp5_t6_perst_l : in std_logic;


    );
end entity;

architecture rtl of sp5_sequencer is
    signal power_ctrl : power_ctrl_type;
    signal seq_api_status : seq_api_status_type;
    signal seq_raw_status : seq_raw_status_type;
    signal nic_api_status : nic_api_status_type;
    signal nic_raw_status : nic_raw_status_type;
    signal rails_en_rdbk : rails_type;
    signal rails_pg_rdbk : rails_type;
    
    signal fans_power_ok : std_logic;
    -- We have the following states for the sequencing block
    -- power ok means we're up and happy
    -- power idle means we're down and idle
    -- power not idle could mean we're in the middle of a sequence up or down
    signal nic_ok : std_logic;
    signal nic_idle : std_logic;
    signal therm_trip : std_logic;
    signal early_power : early_power_t;
    signal ddr_bulk : ddr_bulk_power_t;
    signal group_a : group_a_power_t;
    signal group_b : group_b_power_t;
    signal group_c : group_c_power_t;
    signal sp5_seq : sp5_seq_pins_t;
    signal nic_rails : nic_power_t;
    signal nic_seq : nic_seq_pins_t;
    signal early_power_ctrl : early_power_ctrl_type;
    signal early_power_rdbks : early_power_rdbks_type;
    signal sp5_readbacks : sp5_readbacks_type;
    signal nic_readbacks : nic_readbacks_type;
    signal nic_overrides : nic_overrides_type;
    signal debug_enables : debug_enables_type;
    signal smerr_assert : std_logic;
    


begin

    sync: entity work.seq_sync
     port map(
        clk => clk,
        reset => reset,
        early_power_pins => early_power_pins,
        ddr_bulk_pins => ddr_bulk_pins,
        group_a_pins => group_a_pins,
        group_b_pins => group_b_pins,
        group_c_pins => group_c_pins,
        sp5_seq_pins => sp5_seq_pins,
        nic_rails_pins => nic_rails_pins,
        nic_seq_pins => nic_seq_pins,
        early_power => early_power,
        ddr_bulk => ddr_bulk,
        group_a => group_a,
        group_b => group_b,
        group_c => group_c,
        sp5_seq => sp5_seq,
        nic_rails => nic_rails,
        nic_seq => nic_seq
    );

    regs: entity work.sequencer_regs
     port map(
        clk => clk,
        reset => reset,
        axi_if => axi_if,
        early_power_ctrl => early_power_ctrl,
        early_power_rdbks => early_power_rdbks,
        power_ctrl => power_ctrl,
        therm_trip => therm_trip,
        smerr_assert => smerr_assert,
        seq_api_status => seq_api_status,
        seq_raw_status => seq_raw_status,
        nic_api_status => nic_api_status,
        nic_raw_status => nic_raw_status,
        debug_enables => debug_enables,
        nic_overrides => nic_overrides,
        rails_en_rdbk => rails_en_rdbk,
        rails_pg_rdbk => rails_pg_rdbk,
        sp5_readbacks => sp5_readbacks,
        nic_readbacks => nic_readbacks
    );

    -- control from hubris
    early_power.fan_central_hsc_disable <= early_power_ctrl.fan_hsc_central_disable;
    early_power.fan_east_hsc_disable <= early_power_ctrl.fan_hsc_east_disable;
    early_power.fan_west_hsc_disable <= early_power_ctrl.fan_hsc_west_disable;

    -- Readbacks to registers for Hubris
    -- early power
    early_power_rdbks.fan_hsc_west_disable <= early_power_ctrl.fan_hsc_west_disable;
    early_power_rdbks.fan_hsc_central_disable <= early_power_ctrl.fan_hsc_central_disable;
    early_power_rdbks.fan_hsc_east_disable <= early_power_ctrl.fan_hsc_east_disable;
    early_power_rdbks.fan_hsc_west_pg <= early_power.fan_west_hsc_pg;
    early_power_rdbks.fan_hsc_central_pg <= early_power.fan_central_hsc_pg;
    early_power_rdbks.fan_hsc_east_pg <= early_power.fan_east_hsc_pg;
    early_power_rdbks.fan_fail <= not early_power.fan_fail;
    -- rails
    -- NIC rails all cascade enabled from 12V rail
    rails_en_rdbk.v0p96_nic_vdd_a0hp <= nic_rails.nic_hsc_12v.enable;
    rails_en_rdbk.v1p1_nic_a0hp <= nic_rails.nic_hsc_12v.enable;
    rails_en_rdbk.v3p3_nic_a0hp <= nic_rails.nic_hsc_12v.enable;
    rails_en_rdbk.v1p2_nic_enet_a0hp <= nic_rails.nic_hsc_12v.enable;
    rails_en_rdbk.v1p2_nic_pcie_a0hp <= nic_rails.nic_hsc_12v.enable;
    rails_en_rdbk.v1p5_nic_a0hp <= nic_rails.nic_hsc_12v.enable;
    rails_en_rdbk.nic_hsc_5v <= nic_rails.nic_hsc_12v.enable;
    rails_en_rdbk.nic_hsc_12v <= nic_rails.nic_hsc_12v.enable;
    rails_en_rdbk.vddcr_soc <= group_c.vddcr_soc.enable;
    rails_en_rdbk.vddcr_cpu0 <= group_c.vddcr_cpu0.enable;
    rails_en_rdbk.vddcr_cpu1 <= group_c.vddcr_cpu1.enable;
    rails_en_rdbk.vddio_sp5 <= group_c.vddio_sp5_a0.enable;
    rails_en_rdbk.v1p1_sp5 <= group_b.v1p1_sp5.enable;
    rails_en_rdbk.v1p8_sp5 <= group_a.v1p8_sp5_a1.enable;
    rails_en_rdbk.v3p3_sp5 <= group_a.v3p3_sp5_a1.enable;
    rails_en_rdbk.v1p5_rtc <= group_a.pwr_v1p5_rtc.enable;
    rails_en_rdbk.ghijkl_hsc <= ddr_bulk.ghijkl_hsc.enable;
    rails_en_rdbk.abcdef_hsc <= ddr_bulk.abcdef_hsc.enable;
    -- PG readbacks
    rails_pg_rdbk.v0p96_nic_vdd_a0hp <= nic_rails.v0p96_nic_vdd_a0hp.pg;
    rails_pg_rdbk.v1p1_nic_a0hp <= nic_rails.v1p1_nic_a0hp.pg;
    rails_pg_rdbk.v3p3_nic_a0hp <= nic_rails.v3p3_nic_a0hp.pg;
    rails_pg_rdbk.v1p2_nic_enet_a0hp <= nic_rails.v1p2_nic_enet_a0hp.pg;
    rails_pg_rdbk.v1p2_nic_pcie_a0hp <= nic_rails.v1p2_nic_pcie_a0hp.pg;
    rails_pg_rdbk.v1p5_nic_a0hp <= nic_rails.v1p5_nic_a0hp.pg;
    rails_pg_rdbk.nic_hsc_5v <= nic_rails.nic_hsc_5v.pg;
    rails_pg_rdbk.nic_hsc_12v <= nic_rails.nic_hsc_12v.pg;
    rails_pg_rdbk.vddcr_soc <= group_c.vddcr_soc.pg;
    rails_pg_rdbk.vddcr_cpu0 <= group_c.vddcr_cpu0.pg;
    rails_pg_rdbk.vddcr_cpu1 <= group_c.vddcr_cpu1.pg;
    rails_pg_rdbk.vddio_sp5 <= group_c.vddio_sp5_a0.pg;
    rails_pg_rdbk.v1p1_sp5 <= group_b.v1p1_sp5.pg;
    rails_pg_rdbk.v1p8_sp5 <= group_a.v1p8_sp5_a1.pg;
    rails_pg_rdbk.v3p3_sp5 <= group_a.v3p3_sp5_a1.pg;
    rails_pg_rdbk.v1p5_rtc <= group_a.pwr_v1p5_rtc.pg;
    rails_pg_rdbk.ghijkl_hsc <= ddr_bulk.ghijkl_hsc.pg;
    rails_pg_rdbk.abcdef_hsc <= ddr_bulk.abcdef_hsc.pg;
    -- SP5 sequencing readbacks
    sp5_readbacks.pwr_good <= sp5_seq.pwr_good;
    sp5_readbacks.pwr_btn_l <= sp5_seq.pwr_btn_l;
    sp5_readbacks.rsmrst_l <= sp5_seq.rsmrst_l;
    sp5_readbacks.slp_s5_l <= sp5_seq.slp_s5_l;
    sp5_readbacks.slp_s3_l <= sp5_seq.slp_s3_l;
    sp5_readbacks.pwr_ok <= sp5_seq.pwr_ok;
    sp5_readbacks.reset_l <= sp5_seq.reset_l;
    sp5_readbacks.thermtrip_l <= sp5_seq.thermtrip_l;
    sp5_readbacks.smerr_l <= sp5_seq.smerr_l;
    -- NIC sequencing readbacks
    nic_readbacks.nic_pcie_clk_buff_oe_l <= nic_seq.nic_pcie_clk_buff_oe_l;
    nic_readbacks.flash_wp_l <= nic_seq.flash_wp_l;
    nic_readbacks.eeprom_wp_buffer_oe_l <= nic_seq.eeprom_wp_buffer_oe_l;
    nic_readbacks.eeprom_wp_l <= nic_seq.eeprom_wp_l;
    nic_readbacks.sp5_mfg_mode_l <= nic_seq.sp5_mfg_mode_l;
    nic_readbacks.nic_mfg_mode_l <= nic_seq.nic_mfg_mode_l;
    nic_readbacks.ext_rst_l <= nic_seq.ext_rst_l;
    nic_readbacks.perst_l <= nic_seq.perst_l;
    nic_readbacks.cld_rst_l <= nic_seq.cld_rst_l;

    fans_power_ok <= early_power.fan_west_hsc_pg and 
                     early_power.fan_central_hsc_pg and 
                     early_power.fan_east_hsc_pg;
    a1_a0_seq_inst: entity work.a1_a0_seq
     generic map(
        CNTS_P_MS => CNTS_P_MS
    )
     port map(
        clk => clk,
        reset => reset,
        upstream_ok => fans_power_ok,
        downstream_idle => nic_idle,
        therm_trip => therm_trip,
        smerr_assert => smerr_assert,
        a0_ok => a0_ok,
        a0_idle => a0_idle,
        a0_faulted => open,
        sw_enable => power_ctrl.a0_en,
        raw_state => seq_raw_status,
        api_state => seq_api_status,
        ignore_sp5 => debug_enables.ignore_sp5,
        ddr_bulk => ddr_bulk,
        group_a => group_a,
        group_b => group_b,
        group_c => group_c,
        sp5_seq_pins => sp5_seq
    );

    nic_seq_inst: entity work.nic_seq
     generic map(
        CNTS_P_MS => CNTS_P_MS
    )
     port map(
        clk => clk,
        reset => reset,
        nic_idle => nic_idle,
        sw_enable => power_ctrl.a0_en,
        raw_state => nic_raw_status,
        api_state => open,
        upstream_ok => a0_ok,
        nic_overrides_reg => nic_overrides,
        debug_enables => debug_enables,
        sp5_t6_power_en => sp5_t6_power_en,
        sp5_t6_perst_l => sp5_t6_perst_l,
        nic_rails => nic_rails,
        nic_seq_pins => nic_seq
    );

end rtl;