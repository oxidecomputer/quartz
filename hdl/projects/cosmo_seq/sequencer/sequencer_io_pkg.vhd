-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.sp5_power_pkg.all;

-- Board-side sequencer I/O types for the SP5 boards. The generic rail records
-- and the SP5 rail groups they build on live in sp5_power_pkg; this package
-- holds the NIC-side records for both NIC flavours (cosmo's T6, metro's
-- Versal) and the alert-pin record, which is the union of both boards' pins.
package sequencer_io_pkg is

    -- Which NIC a board carries. Selects the NIC half of sp5_sequencer.
    type nic_kind_t is (NIC_T6, NIC_VERSAL);

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
        pwr_cont4_to_fpga1_alert_l : std_logic;  -- metro only; cosmo ties it high
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
        pwr_cont4_to_fpga1_alert_l : in;
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

    -- What the NIC sequencer offers the debug header: the combined rail
    -- enable and power good, plus six taps whose meaning is the NIC's to
    -- define. They land on header pins 5..0 in order; see nic_seq (T6) and
    -- versal_seq for what each board puts there.
    type nic_debug_if is record
        rails_en : std_logic; -- NIC power rails enable (FPGA output combined)
        rails_pg : std_logic; -- NIC power rails power good (FPGA input combined)
        taps : std_logic_vector(5 downto 0);
    end record;
    view nic_debug_seq_ss of nic_debug_if is
        rails_en : out;
        rails_pg : out;
        taps : out;
    end view;
    alias nic_debug_dbg is nic_debug_seq_ss'converse;

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

    -- Metro's Versal rail tree. Everything in here is active high; the
    -- synchroniser inverts the schematic's active-low 12V/5V power-good pins
    -- on the way in so this layer never has to think about pin polarity.
    --
    -- V0P92_NIC_AVCC and V1P2_NIC_AVTT have no FPGA enable -- they cascade off
    -- rails we do enable -- so they are readback only.
    type versal_power_t is record
        hsc_12v : power_rail_t;    -- FPGA1_TO_NIC_HSC_EN / V12P0_NIC_A0HP_PG_L
        hsc_5v : cascade_power_rail_t; -- cascades off the 12V hotswap
        v3p3 : power_rail_t;
        v1p8 : power_rail_t;
        v1p5 : power_rail_t;
        v1p5_avccaux : power_rail_t;
        v1p4 : power_rail_t;
        v1p1 : power_rail_t;
        v0p88 : power_rail_t;
        v0p8_vccint : power_rail_t;
        v0p92_avcc : cascade_power_rail_t;
        v1p2_avtt : cascade_power_rail_t;
    end record;
    function is_power_good(power_group: versal_power_t) return boolean;
    view versal_power_at_fpga of versal_power_t is
        hsc_12v : view power_rail_at_fpga;
        hsc_5v : view cascade_power_rail_at_fpga;
        v3p3 : view power_rail_at_fpga;
        v1p8 : view power_rail_at_fpga;
        v1p5 : view power_rail_at_fpga;
        v1p5_avccaux : view power_rail_at_fpga;
        v1p4 : view power_rail_at_fpga;
        v1p1 : view power_rail_at_fpga;
        v0p88 : view power_rail_at_fpga;
        v0p8_vccint : view power_rail_at_fpga;
        v0p92_avcc : view cascade_power_rail_at_fpga;
        v1p2_avtt : view cascade_power_rail_at_fpga;
    end view;
    alias versal_power_at_reg is versal_power_at_fpga'converse;
    -- What a board without a Versal ties its versal_rails_pins to: nothing
    -- enabled, nothing good. Only ever looked at by versal_seq, which such a
    -- board does not generate.
    constant versal_power_absent : versal_power_t := (
        hsc_12v => (enable => '0', pg => '1'),  -- hotswap pg pins are active low
        hsc_5v => (pg => '1'),
        v3p3 => (enable => '0', pg => '0'),
        v1p8 => (enable => '0', pg => '0'),
        v1p5 => (enable => '0', pg => '0'),
        v1p5_avccaux => (enable => '0', pg => '0'),
        v1p4 => (enable => '0', pg => '0'),
        v1p1 => (enable => '0', pg => '0'),
        v0p88 => (enable => '0', pg => '0'),
        v0p8_vccint => (enable => '0', pg => '0'),
        v0p92_avcc => (pg => '0'),
        v1p2_avtt => (pg => '0')
    );

    -- Versal boot straps and status. mode is driven onto the VP1202's
    -- MODE[3:0] pins through a buffer we also enable, and por_b is the
    -- device's power-on reset.
    type versal_boot_t is record
        mode : std_logic_vector(3 downto 0);
        mode_buffer_en_l : std_logic;
        por_b : std_logic;
        err_done_buff_en : std_logic;
        done : std_logic;
        error_out : std_logic;
    end record;
    view versal_boot_at_fpga of versal_boot_t is
        mode : out;
        mode_buffer_en_l : out;
        por_b : out;
        err_done_buff_en : out;
        done : in;
        error_out : in;
    end view;
    alias versal_boot_at_versal is versal_boot_at_fpga'converse;
    constant versal_boot_absent : versal_boot_t := (
        mode => (others => '0'), mode_buffer_en_l => '1', por_b => '0',
        err_done_buff_en => '0', done => '0', error_out => '0'
    );

    -- One of the Versal's two PCIe channels to the host.
    type versal_pcie_chan_t is record
        perst_l : std_logic;
        prsnt_l : std_logic;
        pwren_l : std_logic;
        clk_buff_oe_l : std_logic;
    end record;
    view versal_pcie_chan_at_fpga of versal_pcie_chan_t is
        perst_l : out;
        prsnt_l : in;
        pwren_l : in;
        clk_buff_oe_l : out;
    end view;
    alias versal_pcie_chan_at_nic is versal_pcie_chan_at_fpga'converse;

    type versal_pcie_t is record
        cha : versal_pcie_chan_t;
        chb : versal_pcie_chan_t;
    end record;
    view versal_pcie_at_fpga of versal_pcie_t is
        cha : view versal_pcie_chan_at_fpga;
        chb : view versal_pcie_chan_at_fpga;
    end view;
    alias versal_pcie_at_nic is versal_pcie_at_fpga'converse;
    constant versal_pcie_absent : versal_pcie_t := (
        cha => (perst_l => '0', prsnt_l => '1', pwren_l => '1', clk_buff_oe_l => '1'),
        chb => (perst_l => '0', prsnt_l => '1', pwren_l => '1', clk_buff_oe_l => '1')
    );

    -- Likewise what a board without a T6 ties its T6 pins to.
    constant nic_power_absent : nic_power_t := (
        v1p5_nic_a0hp => (pg => '0'),
        v1p2_nic_pcie_a0hp => (pg => '0'),
        v1p2_nic_enet_a0hp => (pg => '0'),
        v3p3_nic_a0hp => (pg => '0'),
        v1p1_nic_a0hp => (pg => '0'),
        v1p4_nic_a0hp => (pg => '0'),
        v0p96_nic_vdd_a0hp => (pg => '0'),
        nic_hsc_12v => (enable => '0', pg => '1'),  -- hotswap pg pins are active low
        nic_hsc_5v => (pg => '1')
    );
    constant nic_seq_pins_absent : nic_seq_pins_t := (
        cld_rst_l => '0', perst_l => '0', eeprom_wp_l => '0',
        eeprom_wp_buffer_oe_l => '1', flash_wp_l => '0', nic_mfg_mode_l => '1',
        ext_rst_l => '1', nic_pcie_clk_buff_oe_l => '1', sp5_mfg_mode_l => '1'
    );

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

    function is_power_good(power_group: versal_power_t) return boolean is
    begin
        return (
            power_group.hsc_12v.pg and
            power_group.hsc_5v.pg and
            power_group.v3p3.pg and
            power_group.v1p8.pg and
            power_group.v1p5.pg and
            power_group.v1p5_avccaux.pg and
            power_group.v1p4.pg and
            power_group.v1p1.pg and
            power_group.v0p88.pg and
            power_group.v0p8_vccint.pg and
            power_group.v0p92_avcc.pg and
            power_group.v1p2_avtt.pg
        ) = '1';
    end function;

end package body;
