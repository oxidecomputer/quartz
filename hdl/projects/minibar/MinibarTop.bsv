// Copyright 2025 Oxide Computer Company
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
package MinibarTop;

// BSV Core
import Clocks::*;
import TriState::*;

import Blinky::*;

(* always_enabled *)
interface MinibarTop;

    // Presence
    (* prefix = "" *) method Action rsw0_examax_to_fpga_sled_present_l(Bit#(1) rsw0_examax_to_fpga_sled_present_l);
    (* prefix = "" *) method Action rsw1_examax_to_fpga_sled_present_l(Bit#(1) rsw1_examax_to_fpga_sled_present_l);
    (* prefix = "" *) method Action pcie_examax_to_fpga_sled_present_l(Bit#(1) pcie_examax_to_fpga_sled_present_l);

    // Sled PCIe
    (* prefix = "" *) method Action pcie_aux_sled_to_fpga_perst_l(Bit#(1) pcie_aux_sled_to_fpga_perst_l);
    method Bit#(1) fpga_to_pcie_sled_i2c_buffer_en;
    method Bit#(1) fpga_to_sled_pcie_attached_l;
    method Bit#(1) pcie_aux_fpga_to_sled_pwrflt_l;
    method Bit#(1) pcie_aux_fpga_to_sled_prsnt_l;
    // interface Inout#(Bit#(1)) smbus_pcie_aux_sled_to_fpga_scl;
    // interface Inout#(Bit#(1)) smbus_pcie_aux_sled_to_fpga_sda;

    // CEM PCIe
    (* prefix = "" *) method Action pcie_aux_fpga_to_cem_perst_l(Bit#(1) pcie_aux_fpga_to_cem_perst_l);
    method Bit#(1) fpga_to_pcie_cem_i2c_buffer_en;
    method Bit#(1) pcie_aux_cem_to_fpga_prsnt_l;
    // interface Inout#(Bit#(1)) smbus_pcie_aux_fpga_to_cem_scl;
    // interface Inout#(Bit#(1)) smbus_pcie_aux_fpga_to_cem_sda;

    // PCIe refclk
    method Bit#(1) fpga_to_pcie_aux_refclk_buffer_oe0_l;
    method Bit#(1) fpga_to_pcie_aux_refclk_buffer_oe1_l;
    method Bit#(1) fpga_to_pcie_aux_refclk_buffer_pd_l;
    method Bit#(1) fpga_to_pcie_aux_refclk_buffer_bw_sel;

    // VSC7448
    method Bit#(1) fpga_to_vsc7448_reset_l;

    // VSC8504
    method Bit#(1) fpga_to_vsc8504_reset_l_v3p3;

    // LEDs
    method Bit#(1) fpga_ign_lvds_link0_led_en_l;
    method Bit#(1) fpga_ign_lvds_link1_led_en_l;
    method Bit#(1) fpga_status_led_en_l;

    // Power
    method Bit#(1) fpga_to_v12_pcie_efuse_en;
    (* prefix = "" *) method Action v12_pcie_pg(Bit#(1) v12_pcie_pg);
    method Bit#(1) fpga_to_v3p3_pcie_efuse_en;
    (* prefix = "" *) method Action v3p3_pcie_pg(Bit#(1) v3p3_pcie_pg);
    method Bit#(1) fpga_to_vbus_sled_hsc_en;
    (* prefix = "" *) method Action vbus_sled_pg(Bit#(1) vbus_sled_pg);
    (* prefix = "" *) method Action vbus_sys_hsc_to_fpga_fault_l(Bit#(1) vbus_sys_hsc_to_fpga_fault_l);
    method Bit#(1) fpga_to_vbus_sys_hsc_restart_l;
    (* prefix = "" *) method Action vbus_sled_hsc_to_fpga_fault_l(Bit#(1) vbus_sled_hsc_to_fpga_fault_l);
    method Bit#(1) fpga_to_vbus_sled_hsc_restart_l;

    // Debug
    method Bit#(8) fpga_to_debug_spare_io;

    // Hardware Compatability Version
    (* prefix = "" *) method Action hcv_code(Bit#(3) hcv_code);

    // Chassis features
    (* prefix = "" *) method Action power_button_to_fpga_l(Bit#(1) power_button_to_fpga_l);
    method Bit#(1) fpga_to_power_led_en;

    // SP
    method Bit#(3) fpga_to_sp_irq_l;
    (* prefix = "" *) method Action spi_sp_to_fpga_user_cs_l(Bit#(1) spi_sp_to_fpga_user_cs_l);
    (* prefix = "" *) method Action spi_sp_to_fpga_sck(Bit#(1) spi_sp_to_fpga_sck);
    (* prefix = "" *) method Action spi_sp_sdo_to_fpga_sdi(Bit#(1) spi_sp_sdo_to_fpga_sdi);
    method Bit#(1) spi_fpga_sdo_to_sp_sdi_r();

    // Ignition LVDS
    (* prefix = "" *) method Action lvds_sled_to_fpga_link0_dc_p(Bit#(1) lvds_sled_to_fpga_link0_dc_p);
    // interface Inout#(Bit#(1)) lvds_fpga_to_sled_link0_dc_p;
    (* prefix = "" *) method Action lvds_sled_to_fpga_link1_dc_p(Bit#(1) lvds_sled_to_fpga_link1_dc_p);
    // interface Inout#(Bit#(1)) lvds_fpga_to_sled_link1_dc_p;

endinterface

(* default_clock_osc = "clk_50mhz_fpga",
    default_reset = "sp_to_fpga_design_reset_l" *)
module mkMinibarTop(MinibarTop);

    // Synchronize the default reset to the default clock.
    Clock clk_50mhz <- exposeCurrentClock();
    Reset reset_sync <- mkAsyncResetFromCR(2, clk_50mhz);

    //
    // Blinky to show sign of life
    //
    Blinky#(50_000_000) blinky_inst <- Blinky::mkBlinky();
    method Bit#(1) fpga_status_led_en_l = blinky_inst.led[0];

    // Deassert VSC7448 reset
    method fpga_to_vsc7448_reset_l = 1;

    // Deassert VSC8504 reset
    method fpga_to_vsc8504_reset_l_v3p3 = 1;

    // Enable PCIe power
    method fpga_to_v12_pcie_efuse_en = 1;
    method fpga_to_v3p3_pcie_efuse_en = 1;

    // Setup refclk buffer output enables
    method fpga_to_pcie_aux_refclk_buffer_oe0_l = 1;
    method fpga_to_pcie_aux_refclk_buffer_oe1_l = 1;
    // Keep clock buffer in in power down mode
    method fpga_to_pcie_aux_refclk_buffer_pd_l = 0;
    // Put clock buffer in "PLL with Low Bandwidth"
    method fpga_to_pcie_aux_refclk_buffer_bw_sel = 0;

    // Do not restart the HSCs
    method fpga_to_vbus_sys_hsc_restart_l = 1;
    method fpga_to_vbus_sled_hsc_restart_l = 1;

    // Disable the main HSC
    method fpga_to_vbus_sled_hsc_en = 0;

    // Turn on the Power LED
    method fpga_to_power_led_en = 1;

endmodule

endpackage: MinibarTop