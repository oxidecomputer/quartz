// Copyright 2025 Oxide Computer Company
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package MinibarPcie;

// BSV
import DefaultValue::*;

// Oxide
import CommonFunctions::*;
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
    method Action sled_perst(Bit#(1) val);
    method Bit#(1) sled_prsnt;
    method Bit#(1) sled_attached;
    method Bit#(1) sled_pwrflt;
    method Bit#(1) sled_i2c_buffer_en;
    // FPGA to CEM interface
    method Bit#(1) cem_perst;
    method Action cem_prsnt(Bit#(1) val);
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
    method Action tick_1ms(Bool val);
endinterface

module mkMinibarPcie #(Integer pg_timeout_ms) (MinibarPcie);
    Wire#(Bool) tick_1ms_   <- mkWire();

    // Registers for input pins
    Reg#(Bit#(1)) perst <- mkReg(0);
    Reg#(Bit#(1)) prsnt <- mkReg(0);

    // Software controllable registers
    Reg#(PciePowerCtrl) power_control   <- mkReg(defaultValue);
    Reg#(PcieRefclkCtrl) refclk_ctrl    <- mkReg(defaultValue);
    Reg#(PcieCtrl) pcie_ctrl            <- mkReg(defaultValue);

    PowerRail#(8) v12_rail  <- mkPowerRailDisableOnAbort(pg_timeout_ms);
    PowerRail#(8) v3p3_rail <- mkPowerRailDisableOnAbort(pg_timeout_ms);
    // Register the enable state to work around some inellegance in the PowerRail module
    Reg#(Bool) v12_en_r     <- mkReg(False);
    Reg#(Bool) v3p3_en_r    <- mkReg(False);

    (* fire_when_enabled *)
    rule do_power_rail_ticks (tick_1ms_);
        v12_rail.send();
        v3p3_rail.send();
    endrule

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

    method tick_1ms = tick_1ms_._write;

    interface Pins pins;
            method refclk_buffer_oe0 = refclk_ctrl.oe0;
            method refclk_buffer_oe1 = refclk_ctrl.oe1;
            method refclk_buffer_pd = refclk_ctrl.pd;
            method refclk_buffer_bw_sel_o = refclk_bw_sel_o;
            method refclk_buffer_bw_sel_oe = refclk_bw_sel_oe;
            method sled_perst = perst._write;
            method sled_prsnt = prsnt;
            method sled_pwrflt = pcie_ctrl.sled_pwrflt;
            method cem_perst = perst;
            method cem_prsnt = prsnt._write;
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
                cem_prsnt: prsnt,
                cem_perst: perst,
                sled_prsnt: prsnt,
                sled_perst: perst
            });
    endinterface
endmodule

endpackage: MinibarPcie