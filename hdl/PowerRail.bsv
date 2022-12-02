// Copyright 2022 Oxide Computer Company
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package PowerRail;

import ConfigReg::*;
import Connectable::*;
import DefaultValue::*;
import DReg::*;

import Countdown::*;
import Strobe::*;


//
// PowerRail
//
// A set of basic interfaces to control and monitor a power rail, implemented by
// a voltage regulator. Unused pins can safely be left unconnected and the
// corresponding functionality will be disabled.
//

(* always_enabled *)
interface Pins;
    method Bool en();
    method Action pg(Bool val);
    method Action fault(Bool val);
    method Action vrhot(Bool val);
endinterface

typedef enum {
    Disabled = 0,
    RampingUp = 1,
    TimedOut = 2,
    Aborted = 3,
    Enabled = 4
} State deriving (Bits, Eq, FShow);

typedef struct {
    Bool enable;
    Bool good;
    Bool fault;
    Bool vrhot;
} PinState deriving (Bits, Eq, FShow);

instance DefaultValue#(State);
    defaultValue = Disabled;
endinstance

interface PowerRail #(numeric type timeout_sz);
    interface Pins pins;

    // Read the decoded state of the power rail based on the state of the pins
    // and internal timeout counter.
    method State state();
    // Read the raw pin state.
    method PinState pin_state();

    // Set the enable pin for the power rail.
    method Action set_enable(Bool en);
    // Clear the Timeout or Aborted state and disable the power rail.
    method Action clear();

    // Periodic tick used to determine if the power good timed out. This is a
    // no-op if the power rail is not enabled or the power good signal is
    // received, and thus can be driven contineously.
    method Action send();

    // State query methods. This is syntactic sugar over the `state` method.
    method Bool disabled();
    method Bool ramping_up();
    method Bool timed_out();
    method Bool aborted();
    method Bool enabled();

    // Strobe indicating a power good timeout occured.
    method Bool good_timeout();

    // Compile time method which can be used by consuming modules to determine
    // the configured timeout duration.
    method Integer timeout_duration();
endinterface

//
// Make `PowerRail` with the given enable to good timeout. A value of zero
// disables the timeout and allows a power rail to be in ramp up indefinite.
//
// This module expects methods in the `Pins` interface to be synchronized to the
// current clock and driven every cycle.
//
// The module assumes a voltage regulator to deassert the good signal when it
// experiences a fault and output regulation can not be maintained. Depending on
// the `disable_on_abort` parameter the module will in response disable the
// power rail by changing the state of the enable pin or leave this pin
// untouched. This latter behavior is useful when controlling voltage regulators
// with a PMBus interface which provides additional fault data but automatically
// clear this data when the power rail is disabled.
//
// Note that when using this module as part of a PDN sequencer and chosing not
// to disable the power rail when a fault is observed, the regulator should
// probably be configured not to automatically restart and instead let this be
// handled by the sequencer.
//
module mkPowerRail #(
        Bool disable_on_abort,
        Integer timeout_ticks)
            (PowerRail#(timeout_sz));
    // State of the rail enable pin.
    ConfigReg#(Bool) enabled_r <- mkConfigReg(False);
    // State of the power rail, derived from the state of the pins.
    ConfigReg#(State) state_r <- mkConfigReg(defaultValue);
    // Countdown used to detect a power good timeout.
    Countdown#(timeout_sz) timeout <- mkCountdownBy1();

    // Pin State.
    Wire#(Bool) good <- mkDWire(False);
    Wire#(Bool) fault <- mkDWire(False);
    Wire#(Bool) vrhot <- mkDWire(False);

    RWire#(Bool) enabled_request <- mkRWire();
    PulseWire clear_w <- mkPulseWire();

    let start = (enabled_request.wget == tagged Valid True);
    let stop = (enabled_request.wget == tagged Valid False);

    (* fire_when_enabled *)
    rule do_update;
        if (clear_w) begin
            enabled_r <= False;
            state_r <= Disabled;
        end

        // If the regulator aborts by deasserting good after it was observed
        // good since the rail was enabled, set the rail as aborted and wait for
        // an explicit clear. Depending on the `disable_on_abort` parameter the
        // `enabled` signal is left as is since toggling it may reset the rail
        // and automatically discard recorded fault information.
        else if (state_r == Enabled && !good) begin
            if (disable_on_abort) begin
                enabled_r <= False;
            end

            state_r <= Aborted;
        end

        // If a timeout occurs during ramp up, disable the rail and wait for an
        // explicit clear.
        else if (state_r == RampingUp && timeout) begin
            enabled_r <= False;
            state_r <= TimedOut;
        end

        // Set rail enabled if the good signal is observed before a timeout
        // occured. The timeout event will still fire in the future but is
        // ignored.
        else if (state_r == RampingUp && good) begin
            state_r <= Enabled;
        end

        // Turn the power rail on/off when requested. The timeout event may
        // still fire in the future but is ignored.
        else if ((state_r == Enabled || state_r == RampingUp) && stop) begin
            enabled_r <= False;
            state_r <= Disabled;
        end
        else if (!enabled_r && start) begin
            enabled_r <= True;
            state_r <= RampingUp;
            timeout <= fromInteger(timeout_ticks);
        end
    endrule

    interface Pins pins;
        method en = enabled_r;
        method pg = good._write;
        method fault = fault._write;
        method vrhot = vrhot._write;
    endinterface

    method state = state_r;
    method pin_state =
        PinState {
            enable: enabled_r,
            good: good,
            fault: fault,
            vrhot: vrhot};

    method set_enable = enabled_request.wset;
    method clear = clear_w.send;
    method Action send() = timeout.send;

    method Bool disabled = (state_r == Disabled);
    method Bool ramping_up = (state_r == RampingUp);
    method Bool timed_out = (state_r == TimedOut);
    method Bool aborted = (state_r == Aborted);
    method Bool enabled = (state_r == Enabled);

    method Bool good_timeout = (state_r == RampingUp && timeout);

    method timeout_duration = timeout_ticks;
endmodule

// A `PowerRail` which is disabled when an abort condition occurs. This is
// intended for use when the voltage regulator would normally automatically
// restart the rail when the fault condition occurs, allowing for explicit
// control over fault analysis and sequencing.
function module#(PowerRail#(timeout_sz))
    mkPowerRailDisableOnAbort(Integer timemout_ticks) =
        mkPowerRail(True, timemout_ticks);

// A `PowerRail` which stays enabled when an abort condition occurs. On some
// regulators this keeps fault information available for analysis. This is
// intended to be used when the voltage regulator does not automatically restart
// the power rail once the fault condition clears.
function module#(PowerRail#(timeout_sz))
    mkPowerRailLeaveEnabledOnAbort(Integer timemout_ticks) =
        mkPowerRail(False, timemout_ticks);

instance Connectable#(PulseWire, PowerRail#(timeout_sz));
    module mkConnection #(PulseWire w, PowerRail#(timeout_sz) r) (Empty);
        (* fire_when_enabled *)
        rule do_tick (w);
            r.send();
        endrule
    endmodule
endinstance

instance Connectable#(Strobe#(strobe_sz), PowerRail#(timeout_sz));
    module mkConnection #(Strobe#(strobe_sz) s, PowerRail#(timeout_sz) r) (Empty);
        mkConnection(asPulseWire(s), r);
    endmodule
endinstance

//
// Helper functions to facilitate higher order constructs, such as iterating
// over a `Vector` using `map`.
//
function Bool disabled(PowerRail#(timeout_sz) r) = r.disabled;
function Bool ramping_up(PowerRail#(timeout_sz) r) = r.ramping_up;
function Bool timed_out(PowerRail#(timeout_sz) r) = r.timed_out;
function Bool aborted(PowerRail#(timeout_sz) r) = r.aborted;
function Bool enabled(PowerRail#(timeout_sz) r) = r.enabled;
function Bool good_timeout(PowerRail#(timeout_sz) r) = r.good_timeout;

function Bool enable(PowerRail#(timeout) r) = r.pin_state.enable;
function Bool good(PowerRail#(timeout) r) = r.pin_state.good;
function Bool fault(PowerRail#(timeout) r) = r.pin_state.fault;
function Bool vrhot(PowerRail#(timeout) r) = r.pin_state.vrhot;
function Integer timeout_duration(PowerRail#(timeout) r) = r.timeout_duration;

//
// PowerRailModel
//
// A set of interfaces and modules implementing a mock PowerRail. This is
// primarily intended to be used in test benches but can be synthesized for use
// in a board emulator running alongside a PDN sequencer.
//
(* always_enabled *)
interface ModelPins;
    method Action en(Bool val);
    method Bool pg();
    method Bool fault();
    method Bool vrhot();
endinterface

interface ModelState;
    method Bool enabled();
    method Bool good();
    method Bool fault();
    method Bool vrhot();
endinterface

instance Connectable#(ModelPins, Pins);
    module mkConnection #(ModelPins a, Pins b) (Empty);
        mkConnection(a.en, b.en);
        mkConnection(a.pg, b.pg);
        mkConnection(a.fault, b.fault);
        mkConnection(a.vrhot, b.vrhot);
    endmodule
endinstance

interface PowerRailModel #(numeric type delay_sz);
    interface ModelPins pins;
    interface ModelState state;

    // Force the enable state of the regulator, emulating for example a PMBus
    // interface which overrides the state of the enable pin.
    method Action set_enable_override(Maybe#(Bool) en);
    // Schedule fault or vrhot event given number of ticks or cycles after the
    // rail is enabled.
    method Action schedule_fault(UInt#(delay_sz) delay);
    method Action schedule_vrhot(UInt#(delay_sz) delay);
    method Action clear_faults();
endinterface

module mkPowerRailModel #(
        String name,
        Strobe#(tick_sz) tick,
        Integer enable_to_good_delay)
            (PowerRailModel#(delay_sz));
    ConfigReg#(Bool) enabled <- mkConfigReg(False);
    ConfigReg#(Maybe#(Bool)) enable_override <- mkConfigReg(tagged Invalid);
    ConfigReg#(Bool) good <- mkConfigReg(False);
    ConfigReg#(Bool) fault <- mkConfigReg(False);
    ConfigReg#(Bool) vrhot <- mkConfigReg(False);

    Wire#(Bool) enable <- mkWire();
    PulseWire clear_faults_requested <- mkPulseWire();

    //
    // Power Good event
    //

    Countdown#(delay_sz) good_event <- mkCountdownBy1();

    (* fire_when_enabled *)
    rule do_power_good_countdown (enabled && !good && tick);
        good_event.send();
    endrule

    //
    // Fault event
    //

    RWire#(UInt#(delay_sz)) schedule_fault_request <- mkRWire();
    Countdown#(delay_sz) fault_event <- mkCountdownBy1();

    (* fire_when_enabled *)
    rule do_fault_event_countdown (enabled && tick);
        fault_event.send;
    endrule

    //
    // VR Hot event
    //

    RWire#(UInt#(delay_sz)) schedule_vrhot_request <- mkRWire();
    Countdown#(delay_sz) vrhot_event <- mkCountdownBy1();

    (* fire_when_enabled *)
    rule do_vrhot_event_countdown (enabled && tick);
        vrhot_event.send;
    endrule

    (* fire_when_enabled *)
    rule do_update_state;
        let start_requested =
            (!enabled && fromMaybe(True, enable_override) && enable);

        let shutdown_requested =
            (enabled &&
                (!fromMaybe(True, enable_override) ||
                (!enable && !fromMaybe(False, enable_override))));

        // Set Enabled
        if (start_requested) begin
            good_event <= fromInteger(enable_to_good_delay);
            enabled <= True;
        end
        else if (shutdown_requested) begin
            enabled <= False;
        end

        // Set Power Good.
        if (shutdown_requested || vrhot_event || fault_event) begin
            good <= False;
        end
        else if (enabled && good_event) begin
            good <= True;
        end

        // Set Fault
        if (enabled && (fault_event || vrhot_event)) begin
            fault <= True;
            $display(name, " fault");
        end
        else if (clear_faults_requested) begin
            fault <= False;
        end

        // Adjust the fault event countdown.
        if (schedule_fault_request.wget matches tagged Valid .delay) begin
            fault_event <= delay + 1;
        end
        else if (start_requested) begin
            fault_event <= 0;
        end

        // Set VR Hot
        if (enabled && vrhot_event) begin
            vrhot <= True;
            $display(name, " hot");
        end
        else if (clear_faults_requested) begin
            vrhot <= False;
        end

        // Adjust the vrhot event countdown.
        if (schedule_vrhot_request.wget matches tagged Valid .delay) begin
            vrhot_event <= delay + 1;
        end
        else if (start_requested) begin
            vrhot_event <= 0;
        end
    endrule

    //
    // Interfaces
    //

    interface ModelPins pins;
        method en = enable._write;
        method pg = good;
        method fault = fault;
        method vrhot = vrhot;
    endinterface

    interface ModelState state;
        method enabled = enabled;
        method good = good;
        method fault = fault;
        method vrhot = vrhot;
    endinterface

    method set_enable_override = enable_override._write;
    method schedule_fault = schedule_fault_request.wset;
    method schedule_vrhot = schedule_vrhot_request.wset;
    method clear_faults = clear_faults_requested.send;
endmodule

endpackage
