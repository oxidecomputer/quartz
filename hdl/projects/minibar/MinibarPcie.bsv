// Copyright 2025 Oxide Computer Company
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package MinibarPcie;

// BSV
import ConfigReg::*;
import DefaultValue::*;

// Oxide
import CommonFunctions::*;
import Countdown::*;
import Debouncer::*;
import PowerRail::*;

// Minibar
import MinibarRegsPkg::*;

interface Pins;
    // Refclk
    method Bit#(1) refclk_buffer_oe0;
    method Bit#(1) refclk_buffer_oe1;
    method Bit#(1) refclk_buffer_pd;
    // this is a virtual pin as we need to drive bw_sel high, low, and tristate. We can only
    // tristate at the top-level in BSV, so we will use this signal there.
    method Bool refclk_buffer_bw_sel_oe;
    method Bit#(1) refclk_buffer_bw_sel_o;
    // Sled to FPGA interface
    method Action sled_perst_l(Bit#(1) val);
    method Bit#(1) sled_prsnt_l;
    method Bit#(1) sled_attached;
    method Bit#(1) sled_pwrflt;
    method Bit#(1) sled_i2c_buffer_en;
    // FPGA to CEM interface
    method Bit#(1) cem_perst_l;
    method Action cem_prsnt_l(Bit#(1) val);
    method Bit#(1) cem_i2c_buffer_en;
    // Power
    interface PowerRail::Pins v12_pcie;
    interface PowerRail::Pins v3p3_pcie;
endinterface

interface Registers;
    interface Reg#(PciePowerCtrl) power_ctrl;
    interface ReadOnly#(PowerRailState) v12_pcie;
    interface ReadOnly#(PowerRailState) v3p3_pcie;
    interface Reg#(PcieRefclkCtrl) refclk_ctrl;
    interface Reg#(PcieCtrl) pcie_ctrl;
    interface ReadOnly#(PcieRdbk) pcie_rdbk;
endinterface

interface MinibarPcie;
    interface Pins pins;
    interface Registers registers;
    interface PulseWire tick_1ms;
    interface PulseWire tick_1us;
    method Action sled_present(Bool val);
endinterface

module mkMinibarPcie #(Integer pg_timeout_ms) (MinibarPcie);
    // Wire from the PCIe connector presence register that we use for sled presence
    Wire#(Bool) sled_present_ <- mkWire();

    // Debounced prsnt_l input. The 25 ms debouncing on both rising and falling is arbitrary.
    Debouncer#(25, 25, Bit#(1)) prsnt_l_in <- mkDebouncer(1);

    // This represents the debounced PCIe PERST signal from the sled. This signal is driven by
    // a buffer whose input comes from Gimlet. This signal will oscillate during
    // Gimlet reboot and thus we should lightly debounce it. We've chosen to
    // apply a 100us debounce to rising and falling edge as that is the minimum
    // pulse width for Tperst per PCIe spec. The default state will
    // be to assert reset (i.e. 0) until initial sampling has occurred.
    Debouncer#(100, 100, Bit#(1)) sled_perst_l_in   <- mkDebouncer(0);
    Reg#(Bit#(1)) perst_l_out                       <- mkReg(0);
    // We shouldn't assert PERST without making sure Tpvperl (100ms after power is stable) and
    // Tperst-clk (100us after clocks are valid). We don't have a way of knowing what the status
    // of the refclk is since it comes from the attached sled. We control power though, so we can
    // enforce Tpvperl.
    Countdown#(7) t_pvperl  <- mkCountdownBy1();
    ConfigReg#(Bool) t_pvperl_met <- mkConfigReg(False);

    // Software controllable registers
    Reg#(PciePowerCtrl) power_control   <- mkReg(defaultValue);
    Reg#(PcieRefclkCtrl) refclk_ctrl    <- mkReg(defaultValue);
    Reg#(PcieCtrl) pcie_ctrl            <- mkReg(defaultValue);

    // Power
    PowerRail#(8) v12_rail  <- mkPowerRailDisableOnAbort(pg_timeout_ms);
    PowerRail#(8) v3p3_rail <- mkPowerRailDisableOnAbort(pg_timeout_ms);
    // Register the enable state to work around some inellegance in the PowerRail module
    Reg#(Bool) v12_en_r     <- mkReg(False);
    Reg#(Bool) v3p3_en_r    <- mkReg(False);

    PulseWire tick_1ms_ <- mkPulseWire();

    (* fire_when_enabled *)
    rule do_power_control;
        if (power_control.v12_pcie_en == 0 || v12_rail.timed_out() || v12_rail.aborted()) begin
            v12_rail.set_enable(False);
            v12_en_r <= False;
        end else if (power_control.v12_pcie_en == 1 && !v12_en_r) begin
            v12_rail.set_enable(True);
            v12_en_r <= True;
        end

        if (power_control.v3p3_pcie_en == 0 || v3p3_rail.timed_out() || v3p3_rail.aborted()) begin
            v3p3_rail.set_enable(False);
            v3p3_en_r <= False;
        end else if (!v3p3_en_r && power_control.v3p3_pcie_en == 1) begin
            v3p3_rail.set_enable(True);
            v3p3_en_r <= True;
        end
    endrule

    (* fire_when_enabled *)
    rule do_tpvperl(!t_pvperl_met);
        if (v12_rail.enabled() && v3p3_rail.enabled()) begin
            t_pvperl.send();
        end else begin
            t_pvperl    <= fromInteger(100);
        end
    endrule

    (* fire_when_enabled *)
    rule do_tpvperl_reg;
        if (!v12_rail.enabled() || !v3p3_rail.enabled()) begin
            t_pvperl_met    <= False;
        end else if (!t_pvperl_met) begin
            t_pvperl_met <= t_pvperl;
        end
    endrule

    // There are a couple layers of PERST control between an attached sled and the PCIe slot.
    // First, if a sled is not present, we just assert PERST. This is because the refclk comes from
    // the sled, so without a sled there's no reason for the PCIe device to be out of reset. We also
    // assert PERST until t_pvperl timing has been met.
    // Next, we check if the bits have been set to provide control of PERST to software.
    // Finally, we just pass through the debounced PERST signal from the sled.
    (* fire_when_enabled *)
    rule do_perst;
        if (!sled_present_ || !t_pvperl_met) begin
            perst_l_out <= 0;
        end else if (pcie_ctrl.fpga_perst_override == 1) begin
            perst_l_out <= pcie_ctrl.fpga_perst_control;
        end else begin
            perst_l_out <= sled_perst_l_in;
        end
    endrule

    //
    // PCIe Refclk Buffer Bandwidth selection
    // See PLL Operating Mode Select Table of PI6CB33201 datasheet
    //
    Reg#(Bit#(1)) refclk_bw_sel_o  <- mkReg(0);
    Reg#(Bool) refclk_bw_sel_oe    <- mkReg(False);

    (* fire_when_enabled *)
    rule do_pcie_refclk_bw_sel;
        PcieRefclkCtrlBwSel bw_sel = unpack(refclk_ctrl.bw_sel);
        case (bw_sel)
            // Drive low
            PllLowBw: begin
                refclk_bw_sel_o    <= 0;
                refclk_bw_sel_oe   <= True;
            end

            // Drive high
            PllHighBw: begin
                refclk_bw_sel_o    <= 1;
                refclk_bw_sel_oe   <= True;
            end

            // Let the line float
            PllBypass: begin
                refclk_bw_sel_o    <= 0;
                refclk_bw_sel_oe   <= False;
            end
        endcase
    endrule

    interface Pins pins;
            method refclk_buffer_oe0 = refclk_ctrl.oe0;
            method refclk_buffer_oe1 = refclk_ctrl.oe1;
            method refclk_buffer_pd = refclk_ctrl.pd;
            method refclk_buffer_bw_sel_o = refclk_bw_sel_o;
            method refclk_buffer_bw_sel_oe = refclk_bw_sel_oe;
            method sled_perst_l = sled_perst_l_in._write;
            method sled_prsnt_l = prsnt_l_in;
            method sled_pwrflt = pcie_ctrl.sled_pwrflt;
            method cem_perst_l = perst_l_out;
            method cem_prsnt_l = prsnt_l_in._write;
            method sled_attached = pcie_ctrl.attached;
            method sled_i2c_buffer_en = pcie_ctrl.sled_i2c_en;
            method cem_i2c_buffer_en = pcie_ctrl.cem_i2c_en;
        interface PowerRail::Pins v12_pcie  = v12_rail.pins;
        interface PowerRail::Pins v3p3_pcie = v3p3_rail.pins;
    endinterface

    interface Registers registers;
        interface power_ctrl = power_control;
        interface v12_pcie = valueToReadOnly(
            PowerRailState {
                enable_pin: pack(v12_rail.pin_state().enable),
                pg_pin: pack(v12_rail.pin_state().good),
                fault_pin: pack(v12_rail.pin_state().fault),
                state: pack(v12_rail.state())
            });
        interface v3p3_pcie = valueToReadOnly(
            PowerRailState {
                enable_pin: pack(v3p3_rail.pin_state().enable),
                pg_pin: pack(v3p3_rail.pin_state().good),
                fault_pin: pack(v3p3_rail.pin_state().fault),
                state: pack(v3p3_rail.state())
            });
        interface refclk_ctrl = refclk_ctrl;
        interface pcie_ctrl = pcie_ctrl;
        interface pcie_rdbk = valueToReadOnly(
            PcieRdbk {
                sled_con: pack(sled_present_),
                cem_prsnt_l: prsnt_l_in,
                cem_perst_l: perst_l_out,
                sled_prsnt_l: prsnt_l_in,
                sled_perst_l: sled_perst_l_in
            });
    endinterface

    interface PulseWire tick_1ms;
        method _read = False;
        method Action send;
            tick_1ms_.send();
            v12_rail.send();
            v3p3_rail.send();
            prsnt_l_in.send();
        endmethod
    endinterface

    interface PulseWire tick_1us;
        method _read = False;
        method Action send;
            sled_perst_l_in.send();
        endmethod
    endinterface

    method sled_present = sled_present_._write;
endmodule

endpackage: MinibarPcie