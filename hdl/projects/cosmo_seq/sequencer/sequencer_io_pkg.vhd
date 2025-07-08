-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2025 Oxide Computer Company

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package sequencer_io_pkg is

    -- Generic record type for the common enable/pg feedback.
    -- we'll treat this as both active high internally so
    -- the outer-most blocks need to invert if required.
    type power_rail_t is record
        enable : std_logic;
        pg : std_logic;
    end record;
    -- FPGA's view of the world as the controller and recipient of
    -- the feedback
    view power_rail_at_fpga of power_rail_t is
        enable : out;
        pg : in;
    end view;
    alias power_rail_at_reg is power_rail_at_fpga'converse;
    -- a cascade power rail only has a PG, the enable came from some
    -- other supply
    type cascade_power_rail_t is record
        pg : std_logic;
    end record;
    view cascade_power_rail_at_fpga of cascade_power_rail_t is
        pg : in;
    end view;
    alias cascade_power_rail_at_reg is cascade_power_rail_at_fpga'converse;

    -- Sequencing-related SP5 control/feedback pins
    type sp5_seq_pins_t is record
        thermtrip_l : std_logic;
        reset_l : std_logic;
        pwr_ok : std_logic;
        slp_s3_l : std_logic;
        slp_s5_l : std_logic;
        rsmrst_l : std_logic;
        pwr_btn_l : std_logic;
        pwr_good : std_logic;
        smerr_l : std_logic;
        is_cosmo : std_logic; -- uses SP5_TO_FPGA1_DEBUG1 high at power up to indicate cosmo
    end record;
    -- FPGA's view of the world as the controller and recipient of
    -- the feedback
    view sp5_seq_at_fpga of sp5_seq_pins_t is
        thermtrip_l : in;
        reset_l : in;
        pwr_ok : in;
        slp_s3_l : in;
        slp_s5_l : in;
        smerr_l : in;
        rsmrst_l : out;
        pwr_btn_l : out;
        pwr_good : out;
        is_cosmo : out;
    end view;
    alias sp5_seq_at_sp5 is sp5_seq_at_fpga'converse;

    -- Nic sequencing-related control/feedback pins
    type nic_seq_pins_t is record
        cld_rst_l : std_logic;
        perst_l : std_logic;
        eeprom_wp_l : std_logic;
        eeprom_wp_buffer_oe_l : std_logic;
        flash_wp_l : std_logic;
        nic_mfg_mode_l : std_logic;
        ext_rst_l : std_logic;
        nic_pcie_clk_buff_oe_l : std_logic;
        sp5_mfg_mode_l : std_logic;
    end record;
    view nic_seq_at_fpga of nic_seq_pins_t is
        cld_rst_l : out;
        perst_l : out;
        eeprom_wp_l : out;
        eeprom_wp_buffer_oe_l : out;
        flash_wp_l : out;
        nic_mfg_mode_l : out;
        ext_rst_l : in;
        nic_pcie_clk_buff_oe_l : out;
        sp5_mfg_mode_l : in;
    end view;
    alias nic_seq_at_nic is nic_seq_at_fpga'converse;

    type t6_debug_if is record
        cld_rst_l : std_logic; -- T6 cld reset (FPGA output)
        ext_rst_l : std_logic; -- T6 external reset (FPGA input)
        rails_en : std_logic; -- T6 power rails enable (FPGA output combined)
        rails_pg : std_logic; -- T6 power rails power good (FPGA input combined)
        nic_mfg_mode_l : std_logic; -- T6 NIC manufacturing mode (FPGA output)
        sp5_mfg_mode_l : std_logic; -- T6 SP5 manufacturing mode (FPGA input)
        perst_l : std_logic; -- T6 PCIe reset (FPGA output)
    end record;
    view t6_debug_seq_ss of t6_debug_if is
        cld_rst_l : out;
        ext_rst_l : out;
        rails_en : out;
        rails_pg : out;
        nic_mfg_mode_l : out;
        sp5_mfg_mode_l : out;
        perst_l : out;
    end view;
    alias t6_debug_dbg is t6_debug_seq_ss'converse;

    type early_power_t is record
        fan_central_hsc_pg : std_logic;
        fan_east_hsc_pg : std_logic;
        fan_fail : std_logic;
        fan_west_hsc_pg : std_logic;
        fan_central_hsc_disable : std_logic;
        fan_east_hsc_disable : std_logic;
        fan_west_hsc_disable : std_logic;
    end record;
    view early_power_at_fpga of early_power_t is
        fan_central_hsc_pg : in;
        fan_east_hsc_pg : in;
        fan_west_hsc_pg : in;
        fan_fail : in;
        fan_central_hsc_disable : out;
        fan_east_hsc_disable : out;
        fan_west_hsc_disable : out;
    end view;
    alias early_power_on_board is early_power_at_fpga'converse;

    -- DDR 12V bulk power rail
    type ddr_bulk_power_t is record
       abcdef_hsc : power_rail_t;
       ghijkl_hsc : power_rail_t;
    end record;
    function is_power_good(power_group: ddr_bulk_power_t) return boolean;
    -- FPGA's view of the world as the controller and recipient of
    -- the feedback
    view ddr_bulk_power_at_fpga of ddr_bulk_power_t is
        abcdef_hsc : view power_rail_at_fpga;
        ghijkl_hsc : view power_rail_at_fpga;
    end view;
    alias ddr_bulk_at_reg is ddr_bulk_power_at_fpga'converse;

    -- SP5 group a rails
    --A (G3/S5): VDDBT_RTC_G, VDD_18_S5,VDD_33_S5, VDDIO_AUDIO (shared as 1V8)
    type group_a_power_t is record
        pwr_v1p5_rtc : power_rail_t;
        v3p3_sp5_a1 : power_rail_t;
        v1p8_sp5_a1 : power_rail_t;
    end record;
    function is_power_good(power_group: group_a_power_t) return boolean;
    view group_a_power_at_fpga of group_a_power_t is
        pwr_v1p5_rtc : view power_rail_at_fpga;
        v3p3_sp5_a1 : view power_rail_at_fpga;
        v1p8_sp5_a1 : view power_rail_at_fpga;
    end view;
    alias group_a_power_at_reg is group_a_power_at_fpga'converse;

    -- B (S3): VDD_11_S3
    type group_b_power_t is record
        v1p1_sp5 : power_rail_t;
    end record;
    function is_power_good(power_group: group_b_power_t) return boolean;
    view group_b_power_at_fpga of group_b_power_t is
        v1p1_sp5 : view power_rail_at_fpga;
    end view;
    alias group_b_power_at_reg is group_b_power_at_fpga'converse;


    -- C (S0): VDDIO, VDDCR_SOC,VDDCR_CPU0, VDDCR_CPU1
    type group_c_power_t is record
        vddio_sp5_a0 : power_rail_t;
        vddcr_cpu1 : power_rail_t;
        vddcr_cpu0 : power_rail_t;
        vddcr_soc : power_rail_t;
    end record;
    function is_power_good(power_group: group_c_power_t) return boolean;
    view group_c_power_at_fpga of group_c_power_t is
        vddio_sp5_a0 : view power_rail_at_fpga;
        vddcr_cpu1 : view power_rail_at_fpga;
        vddcr_cpu0 : view power_rail_at_fpga;
        vddcr_soc : view power_rail_at_fpga;
    end view;
    alias group_c_power_at_reg is group_c_power_at_fpga'converse;

    -- effectively one enable fires all of this due to the 
    -- hardware design.n
    type nic_power_t is record
        v1p5_nic_a0hp : cascade_power_rail_t;  -- cascade enabled in hw from V5P0_NIC_A0HP
        v1p2_nic_pcie_a0hp : cascade_power_rail_t; -- cascade enabled in hw from V5P0_NIC_A0HP
        v1p2_nic_enet_a0hp : cascade_power_rail_t; -- cascade enabled in hw from V5P0_NIC_A0HP
        v3p3_nic_a0hp : cascade_power_rail_t; -- cascade enabled in hw from V5P0_NIC_A0HP
        v1p1_nic_a0hp : cascade_power_rail_t; -- cascade enabled in hw from V5P0_NIC_A0HP
        -- TODO missing readback on v1p4_nic_a0hp -- cascade enabled in hw from V5P0_NIC_A0HP
        v0p96_nic_vdd_a0hp : cascade_power_rail_t; -- cascade enabled in hw from V12P0_NIC_A0HP
        nic_hsc_12v : power_rail_t;  -- two rails are bonded together for enable
        nic_hsc_5v : cascade_power_rail_t;  -- but have separate readbacks
    end record;
    function is_power_good(power_group: nic_power_t) return boolean;
    view nic_power_at_fpga of nic_power_t is
        v1p5_nic_a0hp : view cascade_power_rail_at_fpga;  
        v1p2_nic_pcie_a0hp : view cascade_power_rail_at_fpga;
        v1p2_nic_enet_a0hp : view cascade_power_rail_at_fpga;
        v3p3_nic_a0hp : view cascade_power_rail_at_fpga;
        v1p1_nic_a0hp : view cascade_power_rail_at_fpga;
        v0p96_nic_vdd_a0hp : view cascade_power_rail_at_fpga;
        nic_hsc_12v : view power_rail_at_fpga; 
        nic_hsc_5v : view cascade_power_rail_at_fpga;
    end view;
    alias nic_power_at_reg is nic_power_at_fpga'converse;

end package;


package body sequencer_io_pkg is

     -- Functions for DDR bulk
    function is_power_good(power_group: ddr_bulk_power_t) return boolean is
    begin
        return (power_group.abcdef_hsc.pg and  power_group.ghijkl_hsc.pg) = '1';
    end function;

    -- Functions for groupA
    function is_power_good(power_group: group_a_power_t) return boolean is
    begin
        return (power_group.pwr_v1p5_rtc.pg and  power_group.v3p3_sp5_a1.pg and power_group.v1p8_sp5_a1.pg) = '1';
    end function;
    
    -- Functions for groupB
    function is_power_good(power_group: group_b_power_t) return boolean is
    begin
        return power_group.v1p1_sp5.pg = '1';
    end function;

    -- Functions for groupc
    function is_power_good(power_group: group_c_power_t) return boolean is
    begin
        return (power_group.vddio_sp5_a0.pg and 
            power_group.vddcr_cpu1.pg and
            power_group.vddcr_cpu0.pg and
            power_group.vddcr_soc.pg
            ) = '1';
    end function;
    function is_power_good(power_group: nic_power_t) return boolean is
    begin
        return (
            power_group.v1p5_nic_a0hp.pg and
            power_group.v1p2_nic_pcie_a0hp.pg and
            power_group.v1p2_nic_enet_a0hp.pg and
            power_group.v3p3_nic_a0hp.pg and
            power_group.v1p1_nic_a0hp.pg and
            power_group.v0p96_nic_vdd_a0hp.pg and
            power_group.nic_hsc_12v.pg and
            power_group.nic_hsc_5v.pg
        ) = '1';
    end function;

end package body;