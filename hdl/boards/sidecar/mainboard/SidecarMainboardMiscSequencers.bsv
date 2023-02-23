// Copyright 2023 Oxide Computer Company
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package SidecarMainboardMiscSequencers;

// BSV
import Connectable::*;
import DefaultValue::*;

// Cobalt
import Debouncer::*;

// Quartz
import PowerRail::*;

import SidecarMainboardControllerReg::*;

(* always_enabled *)
interface VSC7448Pins;
    interface PowerRail::Pins v1p0;
    interface PowerRail::Pins v1p2;
    interface PowerRail::Pins v2p5;
    method Bool clocks_enable();
    method Bool reset();
    method Action thermal_alert(Bool alert);
endinterface

interface VSC7448Registers;
endinterface

interface VSC7448Sequencer;
    interface VSC7448Pins pins;
    interface VSC7448Registers registers;
    interface PulseWire tick_1ms;
endinterface

module mkVSC7448Sequencer #(Integer power_good_timeout) (VSC7448Sequencer);
    // Leaving the rails enabled on abort is not actually what we want, but it
    // emulates current behavior.
    //
    // TODO (arjen): Implement proper MAPO for Monorail.
    PowerRail#(4) v1p0 <- mkPowerRailLeaveEnabledOnAbort(power_good_timeout);
    PowerRail#(4) v1p2 <- mkPowerRailLeaveEnabledOnAbort(power_good_timeout);
    PowerRail#(4) v2p5 <- mkPowerRailLeaveEnabledOnAbort(power_good_timeout);

    Reg#(Bool) clocks_enabled <-mkReg(True);
    Reg#(Bool) in_reset <- mkReg(True);

    PulseWire tick <- mkPulseWire();

    (* fire_when_enabled *)
    rule do_power_enable;
        v1p0.set_enable(True);
        v1p2.set_enable(True);
        v2p5.set_enable(True);
    endrule

    (* fire_when_enabled *)
    rule do_release_reset (tick);
        in_reset <=
            !(v1p0.pin_state.good &&
            v1p2.pin_state.good &&
            v2p5.pin_state.good);
    endrule

    interface VSC7448Pins pins;
        interface PowerRail::Pins v1p0 = v1p0.pins;
        interface PowerRail::Pins v1p2 = v1p2.pins;
        interface PowerRail::Pins v2p5 = v2p5.pins;
        method clocks_enable = clocks_enabled;
        method reset = in_reset;
    endinterface

    interface PulseWire tick_1ms = tick;
endmodule

(* always_enabled *)
interface ClockGeneratorPins;
    interface PowerRail::Pins ldo;
    method Bool reset();
endinterface

interface ClockGeneratorRegisters;
endinterface

interface ClockGeneratorSequencer;
    interface ClockGeneratorPins pins;
    interface ClockGeneratorRegisters registers;
    interface PulseWire tick_1ms;
endinterface

module mkClockGeneratorSequencer #(Integer power_good_timeout) (ClockGeneratorSequencer);
    PowerRail#(4) ldo <- mkPowerRailLeaveEnabledOnAbort(power_good_timeout);
    Reg#(Bool) in_reset <- mkReg(True);
    PulseWire tick <- mkPulseWire();

    (* fire_when_enabled *)
    rule do_power_enable;
        ldo.set_enable(True);
    endrule

    (* fire_when_enabled *)
    rule do_release_reset (tick);
        in_reset <= !ldo.pin_state.good;
    endrule

    interface ClockGeneratorPins pins;
        interface PowerRail::Pins ldo = ldo.pins;
        method reset = in_reset;
    endinterface

    interface PulseWire tick_1ms = tick;
endmodule

interface FanModulePins;
    interface PowerRail::Pins hsc;
    method Action present(Bool present);
    method Bool led;
endinterface

interface FanModuleRegisters;
    interface Reg#(FanState) state;
endinterface

interface FanModuleSequencer;
    interface FanModulePins pins;
    interface FanModuleRegisters registers;
    interface PulseWire tick_1ms; 
endinterface

module mkFanModuleSequencer (FanModuleSequencer);

    // The device controlling the rail here is an ADM1272 hot swap controller.
    // Fault information is preserved until cleared via PMBUS OPERATION off or
    // CLEAR_FAULT, so this rail will disable on abort (losing PG during normal
    // operation). PG Timeout is 10 ms.
    PowerRail#(4) adm1272 <- mkPowerRailDisableOnAbort(10);

    // This represents the debounced fan presence signal. Presence will only be
    // asserted internally after being observed for 500ms on the pin while it
    // will be removed immediately internally after it is lost on the pin.
    Debouncer#(500, 0, Bool) fan_present <- mkDebouncer(False);
    PulseWire tick_1ms_ <- mkPulseWire();
    mkConnection(asIfc(tick_1ms_), asIfc(fan_present));

    Reg#(Bool) led <- mkReg(False);
    Reg#(Bool) enable <- mkReg(False);
    PulseWire sw_enable_request <- mkPulseWire();

    (* fire_when_enabled *)
    rule do_enable;
        if (!fan_present) begin
            enable <= False;
            adm1272.set_enable(False);
        end else if (fan_present && sw_enable_request) begin
            enable <= True;
            adm1272.set_enable(True);
        end
    endrule

    interface FanModulePins pins;
        interface PowerRail::Pins hsc = adm1272.pins;
        method present = fan_present._write;
        method led = led;
    endinterface

    interface FanModuleRegisters registers;
        interface Reg state;
            method _read = FanState {
                pg_timed_out: pack(adm1272.timed_out()),
                power_fault: pack(adm1272.aborted()),
                pg: pack(adm1272.pin_state.good),
                present: pack(fan_present),
                led: pack(led),
                enable: pack(enable)
            };
            method Action _write(FanState next);
                led <= unpack(next.led);
                if (next.enable == 1) begin
                    sw_enable_request.send();
                end
            endmethod
        endinterface
    endinterface

    method tick_1ms = tick_1ms_;
endmodule

function FanModulePins fan_pins(FanModuleSequencer m) = m.pins;
function FanModuleRegisters fan_registers(FanModuleSequencer m) = m.registers;

endpackage
