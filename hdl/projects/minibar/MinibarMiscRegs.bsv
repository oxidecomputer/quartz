// Copyright 2025 Oxide Computer Company
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package MinibarMiscRegs;

// BSV
import ConfigReg::*;
import Connectable::*;
import DefaultValue::*;

// Oxide
import CommonFunctions::*;
import Debouncer::*;
import PowerRail::*;

// Minibar
import MinibarRegsPkg::*;

// This interface takes signals that for various reasons do not make sense to
// wire directly into any modules but need to make it into registers for SW
interface Pins;
    method Action vbus_sys_fault(Bit#(1) val);
    method Action hcv_code(Bit#(3) val);
    method Action power_button(Bit#(1) val);
    method Action pcie_con_present(Bit#(1) val);
    method Action rsw0_con_present(Bit#(1) val);
    method Action rsw1_con_present(Bit#(1) val);
    method Bit#(1) vbus_en_led;
    method Bit#(1) vbus_sys_restart;
    method Bit#(1) vbus_sled_restart;
    method Bit#(1) vsc7448_reset;
    method Bit#(1) vsc8504_reset;
    interface PowerRail::Pins vbus_sled;
endinterface

interface Registers;
    interface ReadOnly#(Hcv) hcv;
    interface ReadOnly#(SledPresence) sled_presence;
    interface ReadOnly#(VbusSysRdbk) vbus_sys_rdbk;
    interface Reg#(PowerCtrl) power_ctrl;
    interface ReadOnly#(PowerRailState) vbus_sled;
    interface Reg#(SwitchResetCtrl) switch_reset_ctrl;
    interface ReadOnly#(IgnitionTargetsPresent) ignition_targets_present;
endinterface

interface MinibarMiscRegs;
    interface Registers registers;
    interface Pins pins;
    method Action ignition_target0_present(Bool val);
    method Action ignition_target1_present(Bool val);
    method Action tick_1ms(Bool val);
endinterface

module mkMinibarMiscRegs #(Integer pg_timeout_ms) (MinibarMiscRegs);
    Wire#(Bool) tick_1ms_   <- mkWire();
    // Registers to wrap up and expose
    Reg#(Bit#(1)) vbus_sys_fault_r  <- mkReg(0);
    Reg#(Bit#(3)) hcv_code_r        <- mkReg(0);
    Reg#(Bool) ignt_tgt0_present    <- mkReg(False);
    Reg#(Bool) ignt_tgt1_present    <- mkReg(False);
    Reg#(Bit#(1)) pcie_con_present  <- mkReg(0);
    Reg#(Bit#(1)) rsw0_con_present  <- mkReg(0);
    Reg#(Bit#(1)) rsw1_con_present  <- mkReg(0);

    // Software controllable registers
    Reg#(PowerCtrl) power_control           <- mkReg(defaultValue);
    Reg#(SwitchResetCtrl) switch_reset_ctrl <- mkReg(defaultValue);

    // Apply a 100ms debouncer to the button presses
    Debouncer#(100, 100, Bit#(1)) power_button  <- mkDebouncer(0);
    mkConnection(asIfc(tick_1ms_), asIfc(power_button));

    // VBUS rail under FPGA control
    PowerRail#(8) vbus_rail <- mkPowerRailDisableOnAbort(pg_timeout_ms);
    // Register the enable state to work around some inellegance in the PowerRail module
    Reg#(Bool) vbus_en_r    <- mkReg(False);

    (* fire_when_enabled *)
    rule do_power_rail_ticks (tick_1ms_);
        vbus_rail.send();
    endrule

    (* fire_when_enabled *)
    rule do_power_control;
        let toggle_power = power_button.rising_edge();
        let disable_power = power_control.vbus_sled_en == 0
                            || vbus_rail.timed_out()
                            || vbus_rail.aborted()
                            || (toggle_power && vbus_en_r);
        let enable_power = !vbus_en_r && (power_control.vbus_sled_en == 1 || toggle_power);
    
        if (disable_power) begin
            vbus_rail.set_enable(False);
            vbus_en_r <= False;
        end else if (enable_power) begin
            vbus_rail.set_enable(True);
            vbus_en_r <= True;
        end
    endrule

    method ignition_target0_present = ignt_tgt0_present._write;
    method ignition_target1_present = ignt_tgt1_present._write; 

    method tick_1ms = tick_1ms_._write;

    interface Pins pins;
        method vbus_sys_fault = vbus_sys_fault_r._write;
        method hcv_code = hcv_code_r._write;
        method power_button = power_button._write;
        method pcie_con_present = pcie_con_present._write;
        method rsw0_con_present = rsw0_con_present._write;
        method rsw1_con_present = rsw1_con_present._write;
        method vbus_en_led = pack(vbus_en_r);
        method vbus_sys_restart = power_control.vbus_sys_restart;
        method vbus_sled_restart = power_control.vbus_sled_restart;
        method vsc7448_reset = switch_reset_ctrl.vsc7448_reset;
        method vsc8504_reset = switch_reset_ctrl.vsc8504_reset;
        interface PowerRail::Pins vbus_sled = vbus_rail.pins;
    endinterface

    interface Registers registers;
        interface hcv = valueToReadOnly(
            Hcv {
                code: hcv_code_r
            });
        interface sled_presence = valueToReadOnly(
            SledPresence {
                pcie_present: pcie_con_present,
                rsw1_present: rsw1_con_present,
                rsw0_present: rsw0_con_present
            });
        interface vbus_sys_rdbk = valueToReadOnly(
            VbusSysRdbk {
                fault: vbus_sys_fault_r
            });
        interface power_ctrl = power_control;
        interface vbus_sled = valueToReadOnly(
            PowerRailState {
                enable_pin: pack(vbus_rail.pin_state().enable),
                pg_pin: pack(vbus_rail.pin_state().good),
                fault_pin: pack(vbus_rail.pin_state().fault),
                state: pack(vbus_rail.state())
            });
        interface switch_reset_ctrl = switch_reset_ctrl;
        interface ignition_targets_present = valueToReadOnly(
            IgnitionTargetsPresent {
                target1_present: pack(ignt_tgt1_present),
                target0_present: pack(ignt_tgt0_present)
            });
    endinterface

endmodule

endpackage: MinibarMiscRegs