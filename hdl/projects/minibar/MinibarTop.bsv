// Copyright 2025 Oxide Computer Company
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
package MinibarTop;

// BSV Core
import Clocks::*;
import Connectable::*;
import TriState::*;
import Vector::*;

// Oxide
import Blinky::*;
import IgnitionController::*;
import IgnitionTransceiver::*;
import IOSync::*;
import PowerRail::*;
import SerialIO::*;
import SPI::*;
import Strobe::*;

// Minibar
import MinibarMiscRegs::*;
import MinibarPcie::*;
import MinibarController::*;

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

    // CEM PCIe
    (* prefix = "" *) method Action pcie_aux_cem_to_fpga_prsnt_l(Bit#(1) pcie_aux_cem_to_fpga_prsnt_l);
    method Bit#(1) fpga_to_pcie_cem_i2c_buffer_en;
    method Bit#(1) pcie_aux_fpga_to_cem_perst_l;

    // PCIe refclk
    method Bit#(1) fpga_to_pcie_aux_refclk_buffer_oe0_l;
    method Bit#(1) fpga_to_pcie_aux_refclk_buffer_oe1_l;
    method Bit#(1) fpga_to_pcie_aux_refclk_buffer_pd_l;
    // This has to be an inout type so we can tristate it
    interface Inout#(Bit#(1)) fpga_to_pcie_aux_refclk_buffer_bw_sel;

    // VSC7448
    method Bit#(1) fpga_to_vsc7448_reset_l;

    // VSC8504
    method Bit#(1) fpga_to_vsc8504_reset_l_v3p3;

    // Status LED
    method Bit#(1) fpga_status_led_en_l;

    // Power
    method Bool fpga_to_v12_pcie_efuse_en;
    (* prefix = "" *) method Action v12_pcie_pg(Bool v12_pcie_pg);
    method Bool fpga_to_v3p3_pcie_efuse_en;
    (* prefix = "" *) method Action v3p3_pcie_pg(Bool v3p3_pcie_pg);
    method Bool fpga_to_vbus_sled_hsc_en;
    (* prefix = "" *) method Action vbus_sled_pg(Bool vbus_sled_pg);
    (* prefix = "" *) method Action vbus_sys_hsc_to_fpga_fault_l(Bit#(1) vbus_sys_hsc_to_fpga_fault_l);
    method Bit#(1) fpga_to_vbus_sys_hsc_restart;
    (* prefix = "" *) method Action vbus_sled_hsc_to_fpga_fault_l(Bool vbus_sled_hsc_to_fpga_fault_l);
    method Bit#(1) fpga_to_vbus_sled_hsc_restart;

    // Debug
    method Bit#(8) fpga_to_debug_spare_io;

    // Hardware Compatability Version
    (* prefix = "" *) method Action hcv_code(Bit#(3) hcv_code);

    // Chassis features
    (* prefix = "" *) method Action power_button_to_fpga(Bit#(1) power_button_to_fpga);
    method Bit#(1) fpga_to_power_led_en;

    // SP
    method Bit#(3) fpga_to_sp_irq_l;
    (* prefix = "" *) method Action spi_sp_to_fpga_user_cs_l(Bit#(1) spi_sp_to_fpga_user_cs_l);
    (* prefix = "" *) method Action spi_sp_to_fpga_sck(Bit#(1) spi_sp_to_fpga_sck);
    (* prefix = "" *) method Action spi_sp_sdo_to_fpga_sdi(Bit#(1) spi_sp_sdo_to_fpga_sdi);
    method Bit#(1) spi_fpga_sdo_to_sp_sdi_r();

    // Ignition
    (* prefix = "" *) method Action lvds_sled_to_fpga_link0_dc_p(Bit#(1) lvds_sled_to_fpga_link0_dc_p);
    interface Inout#(Bit#(1)) lvds_fpga_to_sled_link0_dc_p;
    (* prefix = "" *) method Action lvds_sled_to_fpga_link1_dc_p(Bit#(1) lvds_sled_to_fpga_link1_dc_p);
    interface Inout#(Bit#(1)) lvds_fpga_to_sled_link1_dc_p;

    // Pin Compatibility
    method Bit#(1) led_at_c23_l;
    method Bit#(1) led_at_c24_l;
    method Bit#(1) led_at_c25_l;
    method Bit#(1) led_at_c26_l;

endinterface

typedef SampledSerialIOTxInout#(5) IgnitionIO;
module mkIgnitionIOs #(
        Vector#(n, IgnitionController::Controller) controllers)
            (Vector#(n, IgnitionIO));
    Strobe#(3) tx_strobe <- mkLimitStrobe(1, 5, 0);

    function to_serial(txr) = txr.serial;

    Transceivers#(n) txrs <- mkTransceivers();
    Vector#(n, IgnitionIO) io <- zipWithM(
        mkSampledSerialIOWithTxStrobeInout(tx_strobe),
        map(tx_enabled, controllers),
        map(to_serial, txrs.txrs));

    mkFreeRunningStrobe(tx_strobe);
    zipWithM(mkConnection, map(transceiver_client, controllers), txrs.txrs);

    // Create a registered copy of the first Controller tick to help P&R.
    Reg#(Bool) watchdog_tick <- mkRegU();

    (* fire_when_enabled *)
    rule do_receiver_watchdog;
        watchdog_tick <= controllers[0].tick_1khz;
        if (watchdog_tick) txrs.tick_1khz();
    endrule

    return io;
endmodule

(* default_clock_osc = "clk_50mhz_fpga",
    default_reset = "sp_to_fpga_design_reset_l" *)
module mkMinibarTop(MinibarTop);

    // Synchronize the default reset to the default clock.
    Clock clk_50mhz     <- exposeCurrentClock();
    Reset reset_synced  <- mkAsyncResetFromCR(2, clk_50mhz);

    // instantiate the logical controller so it can be wired out to physical pins
    MinibarController controller <- mkMinibarController(defaultValue, reset_by reset_synced);

    // Blinky
    ReadOnly#(Bit#(1)) blinky  <- mkOutputSyncFor(controller.blinky.led[0]);

    // SPI peripheral synchronization
    InputReg#(Bit#(1), 2) csn   <- mkInputSyncFor(controller.spi.csn);
    InputReg#(Bit#(1), 2) sclk  <- mkInputSyncFor(controller.spi.sclk);
    InputReg#(Bit#(1), 2) sdi   <- mkInputSyncFor(controller.spi.copi);
    ReadOnly#(Bit#(1)) sdo      <- mkOutputSyncFor(controller.spi.cipo);

    // Ignition controllers
    Vector#(2, IgnitionIO) ignition_io <- mkIgnitionIOs(controller.ignition_controllers, reset_by reset_synced);
    Vector#(2, Bit#(1)) ignition_link_leds;
    for (int i = 0; i < 2; i = i + 1) begin
        let c = controller.ignition_controllers[i];
        ignition_link_leds[i] = pack(c.status().target_present && c.status().receiver_locked);
    end

    Vector#(2, ReadOnly#(Bit#(1))) ignition_leds <- mapM(mkOutputSyncFor, ignition_link_leds);

    // Power rail synchronization
    ReadOnly#(Bool) vbus_sled_en        <- mkOutputSyncFor(controller.misc.vbus_sled.en);
    InputReg#(Bool, 2) vbus_sled_pg_    <- mkInputSyncFor(controller.misc.vbus_sled.pg);
    InputReg#(Bool, 2) vbus_sled_fault  <- mkInputSyncFor(controller.misc.vbus_sled.fault);
    InputReg#(Bit#(1), 2) power_button  <- mkInputSyncFor(controller.misc.power_button);
    ReadOnly#(Bit#(1)) power_led        <- mkOutputSyncFor(controller.misc.vbus_en_led);

    // Miscellaneous pins which we expose to software for control or readback
    InputReg#(Bit#(1), 2) vbus_sys_fault    <- mkInputSyncFor(controller.misc.vbus_sys_fault);
    InputReg#(Bit#(3), 2) hcv               <- mkInputSyncFor(controller.misc.hcv_code);
    InputReg#(Bit#(1), 2) pcie_con_present  <- mkInputSyncFor(controller.misc.pcie_con_present);
    InputReg#(Bit#(1), 2) rsw0_con_present  <- mkInputSyncFor(controller.misc.rsw0_con_present);
    InputReg#(Bit#(1), 2) rsw1_con_present  <- mkInputSyncFor(controller.misc.rsw1_con_present);
    ReadOnly#(Bit#(1)) vbus_sled_restart    <- mkOutputSyncFor(controller.misc.vbus_sled_restart);
    ReadOnly#(Bit#(1)) vbus_sys_restart     <- mkOutputSyncFor(controller.misc.vbus_sys_restart);

    // PCIe
    // Rails
    ReadOnly#(Bool) v12_en     <- mkOutputSyncFor(controller.pcie.v12_pcie.en);
    InputReg#(Bool, 2) v12_pg  <- mkInputSyncFor(controller.pcie.v12_pcie.pg);
    ReadOnly#(Bool) v3p3_en    <- mkOutputSyncFor(controller.pcie.v3p3_pcie.en);
    InputReg#(Bool, 2) v3p3_pg <- mkInputSyncFor(controller.pcie.v3p3_pcie.pg);
    // Sled to FPGA
    InputReg#(Bit#(1), 2) sled_perst_l  <- mkInputSyncFor(controller.pcie.sled_perst_l);
    ReadOnly#(Bit#(1)) sled_prsnt_l     <- mkOutputSyncFor(controller.pcie.sled_prsnt_l);
    ReadOnly#(Bit#(1)) sled_attached    <- mkOutputSyncFor(controller.pcie.sled_attached);
    ReadOnly#(Bit#(1)) sled_pwrflt      <- mkOutputSyncFor(controller.pcie.sled_pwrflt);
    ReadOnly#(Bit#(1)) sled_i2c_en      <- mkOutputSyncFor(controller.pcie.sled_i2c_buffer_en);
    // FPGA to CEM
    ReadOnly#(Bit#(1)) cem_perst_l      <- mkOutputSyncFor(controller.pcie.cem_perst_l);
    InputReg#(Bit#(1), 2) cem_prsnt_l   <- mkInputSyncFor(controller.pcie.cem_prsnt_l);
    ReadOnly#(Bit#(1)) cem_i2c_en       <- mkOutputSyncFor(controller.pcie.cem_i2c_buffer_en);
    // Refclk
    ReadOnly#(Bit#(1)) pcie_refclk_oe0      <- mkOutputSyncFor(controller.pcie.refclk_buffer_oe0);
    ReadOnly#(Bit#(1)) pcie_refclk_oe1      <- mkOutputSyncFor(controller.pcie.refclk_buffer_oe1);
    ReadOnly#(Bit#(1)) pcie_refclk_pd       <- mkOutputSyncFor(controller.pcie.refclk_buffer_pd);
    ReadOnly#(Bit#(1)) pcie_refclk_bw_sel_o <- mkOutputSyncFor(controller.pcie.refclk_buffer_bw_sel_o);
    ReadOnly#(Bool) pcie_refclk_bw_sel_oe   <- mkOutputSyncFor(controller.pcie.refclk_buffer_bw_sel_oe);
    TriState#(Bit#(1)) pcie_refclk_bw_sel   <- mkTriState(pcie_refclk_bw_sel_oe, pcie_refclk_bw_sel_o);

    // Switch resets
    ReadOnly#(Bit#(1)) vsc7448_reset    <- mkOutputSyncFor(controller.misc.vsc7448_reset);
    ReadOnly#(Bit#(1)) vsc8504_reset    <- mkOutputSyncFor(controller.misc.vsc8504_reset);

    //
    // Pin Compatibility Layer
    //
    Wire#(Bit#(1)) c23_led_l <- mkBypassWire();
    Wire#(Bit#(1)) c24_led_l <- mkBypassWire();
    Wire#(Bit#(1)) c25_led_l <- mkBypassWire();
    Wire#(Bit#(1)) c26_led_l <- mkBypassWire();
    Wire#(Bit#(1)) sys_hsc_restart <- mkBypassWire();
    Wire#(Bit#(1)) sled_hsc_restart <- mkBypassWire();

    (* fire_when_enabled *)
    rule do_compat;
        if (hcv == 0) begin
            c25_led_l <= ~ignition_leds[0];
            c26_led_l <= ~ignition_leds[1];
            sys_hsc_restart <= ~vbus_sys_restart;
            sled_hsc_restart <= ~vbus_sled_restart;
            // unused
            c23_led_l <= 1;
            c24_led_l <= 1;
        end else begin
            c23_led_l <= ~ignition_leds[0];
            c24_led_l <= ~ignition_leds[1];
            c25_led_l <= blinky;
            c26_led_l <= 1;
            sys_hsc_restart <= vbus_sys_restart;
            sled_hsc_restart <= vbus_sled_restart;
        end
    endrule

    //
    // Physical pin connections
    //

    // Compatibility
    method led_at_c23_l = c23_led_l;
    method led_at_c24_l = c24_led_l;
    method led_at_c25_l = c25_led_l;
    method led_at_c26_l = c26_led_l;
    method fpga_to_vbus_sled_hsc_restart = sled_hsc_restart;
    method fpga_to_vbus_sys_hsc_restart = sys_hsc_restart;

    method Bit#(1) fpga_status_led_en_l = blinky;

    // SPI pins to syncrhonizers
    method spi_sp_to_fpga_user_cs_l = sync(csn);
    method spi_sp_to_fpga_sck       = sync(sclk);
    method spi_sp_sdo_to_fpga_sdi   = sync(sdi);
    method spi_fpga_sdo_to_sp_sdi_r = sdo;

    // Ignition
    method lvds_sled_to_fpga_link0_dc_p = ignition_io[0].rx;
    method lvds_fpga_to_sled_link0_dc_p = ignition_io[0].tx;
    method lvds_sled_to_fpga_link1_dc_p = ignition_io[1].rx;
    method lvds_fpga_to_sled_link1_dc_p = ignition_io[1].tx;

    // Power rails
    method fpga_to_vbus_sled_hsc_en = vbus_sled_en;
    method vbus_sled_pg = sync(vbus_sled_pg_);
    method vbus_sled_hsc_to_fpga_fault_l = sync_inverted(vbus_sled_fault);
    // PCIe power rails
    method fpga_to_v12_pcie_efuse_en = v12_en;
    method v12_pcie_pg = sync(v12_pg);
    method fpga_to_v3p3_pcie_efuse_en = v3p3_en;
    method v3p3_pcie_pg = sync(v3p3_pg);

    // The VBUS_SYS rail automatically enables when power is applied to the board.
    // Given if any of the subsequent SYS rails are not up, the SP/FPGA will not be up, we don't
    // bother running the PG pin back to the FPGA.
    method vbus_sys_hsc_to_fpga_fault_l = sync_inverted(vbus_sys_fault);

    // The power button and LED are part of the Minibar chassis.
    method power_button_to_fpga = sync(power_button);
    method fpga_to_power_led_en = power_led;

    // Hardware Compatibility Version
    method hcv_code = sync(hcv);

    // Sled Connector Presence
    method pcie_examax_to_fpga_sled_present_l = sync_inverted(pcie_con_present);
    method rsw0_examax_to_fpga_sled_present_l = sync_inverted(rsw0_con_present);
    method rsw1_examax_to_fpga_sled_present_l = sync_inverted(rsw1_con_present);

    // PCIe
    // Sled to FPGA
    method pcie_aux_sled_to_fpga_perst_l = sync(sled_perst_l);
    method fpga_to_pcie_sled_i2c_buffer_en = sled_i2c_en;
    method fpga_to_sled_pcie_attached_l = ~sled_attached;
    method pcie_aux_fpga_to_sled_pwrflt_l = ~sled_pwrflt;
    method pcie_aux_fpga_to_sled_prsnt_l = sled_prsnt_l;
    // FPGA to CEM
    method pcie_aux_cem_to_fpga_prsnt_l = sync(cem_prsnt_l);
    method fpga_to_pcie_cem_i2c_buffer_en = ~cem_i2c_en;
    method pcie_aux_fpga_to_cem_perst_l = cem_perst_l;
    // Refclk
    method fpga_to_pcie_aux_refclk_buffer_oe0_l = ~pcie_refclk_oe0;
    method fpga_to_pcie_aux_refclk_buffer_oe1_l = ~pcie_refclk_oe1;
    method fpga_to_pcie_aux_refclk_buffer_pd_l = ~pcie_refclk_pd;
    interface fpga_to_pcie_aux_refclk_buffer_bw_sel = pcie_refclk_bw_sel.io;

    // Switch resets
    method fpga_to_vsc7448_reset_l = ~vsc7448_reset;
    method fpga_to_vsc8504_reset_l_v3p3 = ~vsc8504_reset;

    // These can be wired to things to be helpful later (J8)
    method Bit#(8) fpga_to_debug_spare_io = {
        1'b0, // pin 10
        1'b0, // pin 9
        1'b0, // pin 8
        1'b0, // pin 7
        1'b0, // pin 4
        1'b0, // pin 3
        1'b0, // pin 2
        1'b0  // pin 1
    };

    // We do not have any IRQs yet
    method fpga_to_sp_irq_l = 1;

endmodule

endpackage: MinibarTop