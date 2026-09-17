-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.axil8x32_pkg;

use work.sp5_power_pkg.all;
use work.sequencer_io_pkg.all;
use work.sequencer_regs_pkg.all;

-- This block provides the power control on an SP5-based sled including
-- state machines and registers for software.
-- It assumes all inputs are *not* synchronized to the clock domain
-- and provides registers for out outputs that are destined for off-chip
-- devices.  It provides no tri-state logic so tri-stating must be done
-- at the chip top if needed/desired.
--
-- The SP5 half is the same on every board. The NIC half is picked by
-- NIC_KIND: cosmo's T6 or metro's Versal. Both NICs' pin records are ports so
-- that the entity is the same on both boards; a board ties the records for
-- the NIC it does not have to the *_absent constants in sequencer_io_pkg
-- and leaves that NIC's outputs open. The register map is the union of both
-- (see sequencer_regs.rdl), so the registers for the absent NIC read zero.
entity sp5_sequencer is
    generic (
        CNTS_P_MS: integer;
        NIC_KIND : nic_kind_t := NIC_T6
    );
    port (
        clk : in std_logic;
        reset : in std_logic;

        axi_if : view axil8x32_pkg.axil_target;
        irq_l_out : out std_logic;
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
        allow_backplane_pcie_clk : out std_logic;
        -- What the NIC sequencer offers the debug header
        nic_dbg_pins : view nic_debug_seq_ss;
        -- regulator alerts
        reg_alert_l_pins : view power_alert_at_fpga;

        -- From SP5 hotplug: the NIC slot's PERST, which follows the slot power
        -- enable. A Versal has two slots; the T6 uses only the first.
        sp5_nic_perst_l : in std_logic;
        sp5_nic_chb_perst_l : in std_logic := '1';
        sp5_nic_faulted : out std_logic;

        ignition_mux_sel : out std_logic;
        ignition_creset : out std_logic;

        -- T6 NIC (NIC_KIND = NIC_T6)
        nic_rails_pins : view nic_power_at_fpga;
        nic_seq_pins: view nic_seq_at_fpga;

        -- Versal NIC (NIC_KIND = NIC_VERSAL)
        versal_rails_pins : view versal_power_at_fpga;
        versal_boot_pins : view versal_boot_at_fpga;
        versal_pcie_pins : view versal_pcie_at_fpga;
        -- True while POR_B is held low and will stay so, gating the SP's
        -- request for the Versal boot-flash mux
        versal_held_in_reset : out std_logic;
        -- True while the sequencer wants the boot flash on the FPGA side
        flash_owned_by_seq : out std_logic;
        -- Hash engine hardware request for the pre-boot measurement
        hash_req : out std_logic;
        hash_ack : in std_logic := '0';
        hash_err : in std_logic := '0';
        -- FPGA1_VERSION_ID board straps, reported straight through
        version_id : in std_logic_vector(1 downto 0) := "00"
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
    signal rail_masks : rails_type;
    
    signal fans_power_ok : std_logic;
    signal nic_power_ok : std_logic;
    -- a0_ok is an output port and this architecture needs to read it
    signal a0_ok_int : std_logic;
    -- We have the following states for the sequencing block
    -- power ok means we're up and happy
    -- power idle means we're down and idle
    -- power not idle could mean we're in the middle of a sequence up or down
    signal nic_idle : std_logic;
    signal therm_trip : std_logic;
    signal early_power : early_power_t;
    signal ddr_bulk : ddr_bulk_power_t;
    signal group_a : group_a_power_t;
    signal group_b : group_b_power_t;
    signal group_c : group_c_power_t;
    signal sp5_seq : sp5_seq_pins_t;
    signal early_power_ctrl : early_power_ctrl_type;
    signal early_power_rdbks : early_power_rdbks_type;
    signal sp5_readbacks : sp5_readbacks_type;
    signal debug_enables : debug_enables_type;
    signal nic_overrides : nic_overrides_type;
    signal smerr_assert : std_logic;
    signal a0_faulted : std_logic;
    signal nic_faulted : std_logic;
    signal reg_alert_l : seq_power_alert_pins_t;
    signal sp5_seq_test_mask : sp5_seq_test_mask_type;

    -- T6 side
    signal nic_rails : nic_power_t;
    signal nic_seq : nic_seq_pins_t;
    signal nic_readbacks : nic_readbacks_type;
    -- Versal side
    signal versal_rails : versal_power_t;
    signal versal_boot : versal_boot_t;
    signal versal_pcie : versal_pcie_t;
    signal versal_readbacks : versal_readbacks_type;
    signal versal_overrides : versal_overrides_type;
    signal versal_boot_ctrl : versal_boot_ctrl_type;
    signal versal_hash_done : std_logic;
    signal versal_hash_failed : std_logic;
    signal board_version : board_version_type;

begin

    sp5_nic_faulted <= nic_faulted;
    a0_ok <= a0_ok_int;
    board_version.version_id <= version_id;

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
        early_power => early_power,
        ddr_bulk => ddr_bulk,
        rail_masks => rail_masks,
        sp5_seq_test_mask => sp5_seq_test_mask,
        group_a => group_a,
        group_b => group_b,
        group_c => group_c,
        sp5_seq => sp5_seq,
        reg_alert_l_pins => reg_alert_l_pins,
        reg_alert_l => reg_alert_l
    );

    regs: entity work.sequencer_regs
     port map(
        clk => clk,
        reset => reset,
        axi_if => axi_if,
        allow_backplane_pcie_clk => allow_backplane_pcie_clk,
        early_power_ctrl => early_power_ctrl,
        early_power_rdbks => early_power_rdbks,
        power_ctrl => power_ctrl,
        therm_trip => therm_trip,
        smerr_assert => smerr_assert,
        seq_api_status => seq_api_status,
        seq_raw_status => seq_raw_status,
        nic_api_status => nic_api_status,
        nic_raw_status => nic_raw_status,
        rail_masks => rail_masks,
        sp5_seq_test_mask => sp5_seq_test_mask,
        debug_enables => debug_enables,
        nic_overrides => nic_overrides,
        a0_faulted => a0_faulted,
        nic_faulted => nic_faulted,
        rails_en_rdbk => rails_en_rdbk,
        rails_pg_rdbk => rails_pg_rdbk,
        sp5_readbacks => sp5_readbacks,
        nic_readbacks => nic_readbacks,
        fans_power_ok => fans_power_ok,
        a0_ok => a0_ok_int,
        nic_power_ok => nic_power_ok,
        nic_done => versal_boot.done,
        versal_error_out => versal_boot.error_out,
        nic_hash_done => versal_hash_done,
        nic_hash_err => versal_hash_failed,
        versal_readbacks => versal_readbacks,
        versal_overrides => versal_overrides,
        versal_boot_ctrl => versal_boot_ctrl,
        board_version => board_version,
        ignition_mux_sel => ignition_mux_sel,
        ignition_creset => ignition_creset,
        irq_l_out => irq_l_out,
        reg_alert_l => reg_alert_l
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
    -- SP5 rails
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
    sp5_readbacks.pwrgd_out <= sp5_seq.pwrgd_out;

    fans_power_ok <= early_power_rdbks.fan_hsc_west_pg and 
                     early_power_rdbks.fan_hsc_central_pg and 
                     early_power_rdbks.fan_hsc_east_pg;
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
        a0_ok => a0_ok_int,
        a0_idle => a0_idle,
        a0_faulted => a0_faulted,
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

    -----------------------------------------------------------------------
    -- T6 NIC
    -----------------------------------------------------------------------
    t6: if NIC_KIND = NIC_T6 generate
        t6_sync_inst: entity work.t6_sync
         port map(
            clk => clk,
            reset => reset,
            nic_rails_pins => nic_rails_pins,
            nic_seq_pins => nic_seq_pins,
            nic_rails => nic_rails,
            nic_seq => nic_seq
        );

        nic_seq_inst: entity work.nic_seq
         generic map(
            CNTS_P_MS => CNTS_P_MS
        )
         port map(
            clk => clk,
            reset => reset,
            nic_idle => nic_idle,
            nic_faulted => nic_faulted,
            sw_enable => power_ctrl.a0_en,
            raw_state => nic_raw_status,
            api_state => nic_api_status,
            upstream_ok => a0_ok_int,
            nic_overrides_reg => nic_overrides,
            debug_enables => debug_enables,
            sp5_t6_perst_l => sp5_nic_perst_l,
            nic_dbg_pins => nic_dbg_pins,
            nic_rails => nic_rails,
            nic_seq_pins => nic_seq
        );

        -- NIC rails all cascade enabled from 12V rail
        rails_en_rdbk.v0p96_nic_vdd_a0hp <= nic_rails.nic_hsc_12v.enable;
        rails_en_rdbk.v1p1_nic_a0hp <= nic_rails.nic_hsc_12v.enable;
        rails_en_rdbk.v1p4_nic_a0hp <= nic_rails.nic_hsc_12v.enable;
        rails_en_rdbk.v3p3_nic_a0hp <= nic_rails.nic_hsc_12v.enable;
        rails_en_rdbk.v1p2_nic_enet_a0hp <= nic_rails.nic_hsc_12v.enable;
        rails_en_rdbk.v1p2_nic_pcie_a0hp <= nic_rails.nic_hsc_12v.enable;
        rails_en_rdbk.v1p5_nic_a0hp <= nic_rails.nic_hsc_12v.enable;
        rails_en_rdbk.nic_hsc_5v <= nic_rails.nic_hsc_12v.enable;
        rails_en_rdbk.nic_hsc_12v <= nic_rails.nic_hsc_12v.enable;
        rails_pg_rdbk.v0p96_nic_vdd_a0hp <= nic_rails.v0p96_nic_vdd_a0hp.pg;
        rails_pg_rdbk.v1p1_nic_a0hp <= nic_rails.v1p1_nic_a0hp.pg;
        rails_pg_rdbk.v1p4_nic_a0hp <= nic_rails.v1p4_nic_a0hp.pg;
        rails_pg_rdbk.v3p3_nic_a0hp <= nic_rails.v3p3_nic_a0hp.pg;
        rails_pg_rdbk.v1p2_nic_enet_a0hp <= nic_rails.v1p2_nic_enet_a0hp.pg;
        rails_pg_rdbk.v1p2_nic_pcie_a0hp <= nic_rails.v1p2_nic_pcie_a0hp.pg;
        rails_pg_rdbk.v1p5_nic_a0hp <= nic_rails.v1p5_nic_a0hp.pg;
        rails_pg_rdbk.nic_hsc_5v <= nic_rails.nic_hsc_5v.pg;
        rails_pg_rdbk.nic_hsc_12v <= nic_rails.nic_hsc_12v.pg;
        -- the Versal bits are not this board's
        rails_en_rdbk.versal_v0p8_vccint <= '0';
        rails_en_rdbk.versal_v0p88 <= '0';
        rails_en_rdbk.versal_v0p92_avcc <= '0';
        rails_en_rdbk.versal_v1p1 <= '0';
        rails_en_rdbk.versal_v1p2_avtt <= '0';
        rails_en_rdbk.versal_v1p4 <= '0';
        rails_en_rdbk.versal_v1p5 <= '0';
        rails_en_rdbk.versal_v1p5_avccaux <= '0';
        rails_en_rdbk.versal_v1p8 <= '0';
        rails_en_rdbk.versal_v3p3 <= '0';
        rails_pg_rdbk.versal_v0p8_vccint <= '0';
        rails_pg_rdbk.versal_v0p88 <= '0';
        rails_pg_rdbk.versal_v0p92_avcc <= '0';
        rails_pg_rdbk.versal_v1p1 <= '0';
        rails_pg_rdbk.versal_v1p2_avtt <= '0';
        rails_pg_rdbk.versal_v1p4 <= '0';
        rails_pg_rdbk.versal_v1p5 <= '0';
        rails_pg_rdbk.versal_v1p5_avccaux <= '0';
        rails_pg_rdbk.versal_v1p8 <= '0';
        rails_pg_rdbk.versal_v3p3 <= '0';

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
        nic_readbacks.sp5_perst_l <= sp5_nic_perst_l;
        nic_power_ok <= '1' when is_power_good(nic_rails) else '0';

        -- Nothing Versal on this board
        versal_rails <= versal_power_absent;
        versal_boot <= versal_boot_absent;
        versal_pcie <= versal_pcie_absent;
        versal_readbacks <= (mode => (others => '0'), others => '0');
        versal_hash_done <= '0';
        versal_hash_failed <= '0';
        versal_held_in_reset <= '0';
        flash_owned_by_seq <= '0';
        hash_req <= '0';
    end generate;

    -----------------------------------------------------------------------
    -- Versal NIC
    -----------------------------------------------------------------------
    versal: if NIC_KIND = NIC_VERSAL generate
        versal_sync_inst: entity work.versal_sync
         port map(
            clk => clk,
            reset => reset,
            versal_rails_pins => versal_rails_pins,
            versal_boot_pins => versal_boot_pins,
            versal_pcie_pins => versal_pcie_pins,
            rail_masks => rail_masks,
            versal_rails => versal_rails,
            versal_boot => versal_boot,
            versal_pcie => versal_pcie
        );

        versal_seq_inst: entity work.versal_seq
         generic map(
            CNTS_P_MS => CNTS_P_MS
        )
         port map(
            clk => clk,
            reset => reset,
            versal_idle => nic_idle,
            versal_faulted => nic_faulted,
            sw_enable => power_ctrl.a0_en,
            raw_state => nic_raw_status,
            api_state => nic_api_status,
            upstream_ok => a0_ok_int,
            versal_overrides_reg => versal_overrides,
            nic_test_mapo => nic_overrides.nic_test_mapo,
            boot_ctrl => versal_boot_ctrl,
            debug_enables => debug_enables,
            sp5_versal_cha_perst_l => sp5_nic_perst_l,
            sp5_versal_chb_perst_l => sp5_nic_chb_perst_l,
            versal_dbg_pins => nic_dbg_pins,
            versal_held_in_reset => versal_held_in_reset,
            flash_owned_by_seq => flash_owned_by_seq,
            hash_req => hash_req,
            hash_ack => hash_ack,
            hash_err => hash_err,
            hash_done => versal_hash_done,
            hash_failed => versal_hash_failed,
            versal_rails => versal_rails,
            versal_boot => versal_boot,
            versal_pcie => versal_pcie
        );

        -- Each Versal rail has its own enable, staged by versal_seq. The two
        -- transceiver rails cascade, so they read back their group's enable.
        -- The hotswaps share the nic_hsc_* bits with the T6.
        rails_en_rdbk.versal_v3p3 <= versal_rails.v3p3.enable;
        rails_en_rdbk.versal_v1p8 <= versal_rails.v1p8.enable;
        rails_en_rdbk.versal_v1p5_avccaux <= versal_rails.v1p5_avccaux.enable;
        rails_en_rdbk.versal_v1p5 <= versal_rails.v1p5.enable;
        rails_en_rdbk.versal_v1p4 <= versal_rails.v1p4.enable;
        rails_en_rdbk.versal_v1p2_avtt <= versal_rails.v1p5.enable;
        rails_en_rdbk.versal_v1p1 <= versal_rails.v1p1.enable;
        rails_en_rdbk.versal_v0p92_avcc <= versal_rails.v0p88.enable;
        rails_en_rdbk.versal_v0p88 <= versal_rails.v0p88.enable;
        rails_en_rdbk.versal_v0p8_vccint <= versal_rails.v0p8_vccint.enable;
        rails_en_rdbk.nic_hsc_5v <= versal_rails.hsc_12v.enable;
        rails_en_rdbk.nic_hsc_12v <= versal_rails.hsc_12v.enable;
        rails_pg_rdbk.versal_v3p3 <= versal_rails.v3p3.pg;
        rails_pg_rdbk.versal_v1p8 <= versal_rails.v1p8.pg;
        rails_pg_rdbk.versal_v1p5_avccaux <= versal_rails.v1p5_avccaux.pg;
        rails_pg_rdbk.versal_v1p5 <= versal_rails.v1p5.pg;
        rails_pg_rdbk.versal_v1p4 <= versal_rails.v1p4.pg;
        rails_pg_rdbk.versal_v1p2_avtt <= versal_rails.v1p2_avtt.pg;
        rails_pg_rdbk.versal_v1p1 <= versal_rails.v1p1.pg;
        rails_pg_rdbk.versal_v0p92_avcc <= versal_rails.v0p92_avcc.pg;
        rails_pg_rdbk.versal_v0p88 <= versal_rails.v0p88.pg;
        rails_pg_rdbk.versal_v0p8_vccint <= versal_rails.v0p8_vccint.pg;
        rails_pg_rdbk.nic_hsc_5v <= versal_rails.hsc_5v.pg;
        rails_pg_rdbk.nic_hsc_12v <= versal_rails.hsc_12v.pg;
        -- the T6 bits are not this board's
        rails_en_rdbk.v0p96_nic_vdd_a0hp <= '0';
        rails_en_rdbk.v1p1_nic_a0hp <= '0';
        rails_en_rdbk.v1p4_nic_a0hp <= '0';
        rails_en_rdbk.v3p3_nic_a0hp <= '0';
        rails_en_rdbk.v1p2_nic_enet_a0hp <= '0';
        rails_en_rdbk.v1p2_nic_pcie_a0hp <= '0';
        rails_en_rdbk.v1p5_nic_a0hp <= '0';
        rails_pg_rdbk.v0p96_nic_vdd_a0hp <= '0';
        rails_pg_rdbk.v1p1_nic_a0hp <= '0';
        rails_pg_rdbk.v1p4_nic_a0hp <= '0';
        rails_pg_rdbk.v3p3_nic_a0hp <= '0';
        rails_pg_rdbk.v1p2_nic_enet_a0hp <= '0';
        rails_pg_rdbk.v1p2_nic_pcie_a0hp <= '0';
        rails_pg_rdbk.v1p5_nic_a0hp <= '0';

        -- Versal sequencing readbacks
        versal_readbacks.por_b <= versal_boot.por_b;
        versal_readbacks.mode <= versal_boot.mode;
        versal_readbacks.mode_buffer_en_l <= versal_boot.mode_buffer_en_l;
        versal_readbacks.err_done_buff_en <= versal_boot.err_done_buff_en;
        versal_readbacks.done <= versal_boot.done;
        versal_readbacks.error_out <= versal_boot.error_out;
        versal_readbacks.cha_perst_l <= versal_pcie.cha.perst_l;
        versal_readbacks.cha_prsnt_l <= versal_pcie.cha.prsnt_l;
        versal_readbacks.cha_pwren_l <= versal_pcie.cha.pwren_l;
        versal_readbacks.cha_clk_buff_oe_l <= versal_pcie.cha.clk_buff_oe_l;
        versal_readbacks.chb_perst_l <= versal_pcie.chb.perst_l;
        versal_readbacks.chb_prsnt_l <= versal_pcie.chb.prsnt_l;
        versal_readbacks.chb_pwren_l <= versal_pcie.chb.pwren_l;
        versal_readbacks.chb_clk_buff_oe_l <= versal_pcie.chb.clk_buff_oe_l;
        versal_readbacks.sp5_cha_perst_l <= sp5_nic_perst_l;
        versal_readbacks.sp5_chb_perst_l <= sp5_nic_chb_perst_l;
        nic_power_ok <= '1' when is_power_good(versal_rails) else '0';

        -- Nothing T6 on this board
        nic_rails <= nic_power_absent;
        nic_seq <= nic_seq_pins_absent;
        nic_readbacks <= (others => '0');
    end generate;

end rtl;
