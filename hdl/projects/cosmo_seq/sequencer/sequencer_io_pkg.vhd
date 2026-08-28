-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.sp5_power_pkg.all;

-- Cosmo-specific sequencer I/O types. The generic rail records and the SP5
-- rail groups they build on live in sp5_power_pkg.
package sequencer_io_pkg is

    type seq_power_alert_pins_t is record
        smbus_fan_central_hsc_to_fpga1_alert_l : std_logic;
        smbus_fan_east_hsc_to_fpga1_alert_l : std_logic;
        smbus_fan_west_hsc_to_fpga1_alert_l : std_logic;
        smbus_ibc_to_fpga1_alert_l : std_logic;
        smbus_m2_hsc_to_fpga1_alert_l : std_logic;
        smbus_nic_hsc_to_fpga1_alert_l : std_logic;
        smbus_v12_ddr5_abcdef_hsc_to_fpga1_alert : std_logic;
        smbus_v12_ddr5_ghijkl_hsc_to_fpga1_alert : std_logic;
        smbus_v12_mcio_a0hp_hsc_to_fpga1_alert_l : std_logic;
        main_hsc_to_fpga1_alert_l : std_logic;
        vr_v1p8_sys_to_fpga1_alert_l : std_logic;
        vr_v3p3_sys_to_fpga1_alert_l : std_logic;
        vr_v5p0_sys_to_fpga1_alert_l : std_logic;
        pwr_cont1_to_fpga1_alert_l : std_logic;
        v0p96_nic_to_fpga1_alert_l : std_logic;
        pwr_cont2_to_fpga1_alert_l : std_logic;
        pwr_cont3_to_fpga1_alert_l : std_logic;
    end record;
    view power_alert_at_fpga of seq_power_alert_pins_t is
        smbus_fan_central_hsc_to_fpga1_alert_l : in;
        smbus_fan_east_hsc_to_fpga1_alert_l : in;
        smbus_fan_west_hsc_to_fpga1_alert_l : in;
        smbus_ibc_to_fpga1_alert_l : in;
        smbus_m2_hsc_to_fpga1_alert_l : in;
        smbus_nic_hsc_to_fpga1_alert_l : in;
        smbus_v12_ddr5_abcdef_hsc_to_fpga1_alert : in;
        smbus_v12_ddr5_ghijkl_hsc_to_fpga1_alert : in;
        smbus_v12_mcio_a0hp_hsc_to_fpga1_alert_l : in;
        main_hsc_to_fpga1_alert_l : in;
        vr_v1p8_sys_to_fpga1_alert_l : in;
        vr_v3p3_sys_to_fpga1_alert_l : in;
        vr_v5p0_sys_to_fpga1_alert_l : in;
        pwr_cont1_to_fpga1_alert_l : in;
        v0p96_nic_to_fpga1_alert_l : in;
        pwr_cont2_to_fpga1_alert_l : in;
        pwr_cont3_to_fpga1_alert_l : in;
    end view;
    alias power_alert_at_reg is power_alert_at_fpga'converse;

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

    -- effectively one enable fires all of this due to the
    -- hardware design.
    type nic_power_t is record
        v1p5_nic_a0hp : cascade_power_rail_t;  -- cascade enabled in hw from V5P0_NIC_A0HP
        v1p2_nic_pcie_a0hp : cascade_power_rail_t; -- cascade enabled in hw from V5P0_NIC_A0HP
        v1p2_nic_enet_a0hp : cascade_power_rail_t; -- cascade enabled in hw from V5P0_NIC_A0HP
        v3p3_nic_a0hp : cascade_power_rail_t; -- cascade enabled in hw from V5P0_NIC_A0HP
        v1p1_nic_a0hp : cascade_power_rail_t; -- cascade enabled in hw from V5P0_NIC_A0HP
        v1p4_nic_a0hp : cascade_power_rail_t; -- cascade enabled in hw from V5P0_NIC_A0HP (rev2+ only)
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
        v1p4_nic_a0hp : view cascade_power_rail_at_fpga;
        v0p96_nic_vdd_a0hp : view cascade_power_rail_at_fpga;
        nic_hsc_12v : view power_rail_at_fpga;
        nic_hsc_5v : view cascade_power_rail_at_fpga;
    end view;
    alias nic_power_at_reg is nic_power_at_fpga'converse;

end package;

package body sequencer_io_pkg is

    function is_power_good(power_group: nic_power_t) return boolean is
    begin
        return (
            power_group.v1p5_nic_a0hp.pg and
            power_group.v1p2_nic_pcie_a0hp.pg and
            power_group.v1p2_nic_enet_a0hp.pg and
            power_group.v3p3_nic_a0hp.pg and
            power_group.v1p1_nic_a0hp.pg and
            power_group.v1p4_nic_a0hp.pg and
            power_group.v0p96_nic_vdd_a0hp.pg and
            power_group.nic_hsc_12v.pg and
            power_group.nic_hsc_5v.pg
        ) = '1';
    end function;

end package body;
