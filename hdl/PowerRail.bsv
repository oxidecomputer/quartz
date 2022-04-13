package PowerRail;

import ConfigReg::*;
import Connectable::*;
import DReg::*;

import Strobe::*;


//
// PowerRail
//
// A set of basic interfaces to an abstract power rail, implemented by a voltage
// regulator. Unused pins can safely be left unconnected and the corresponding
// functionality will be disabled.
//

(* always_enabled *)
interface Pins;
    method Bool en();
    method Action pg(Bool val);
    method Action fault(Bool val);
    method Action vrhot(Bool val);
endinterface

interface PowerRail;
    interface Pins pins;

    method Bool enabled();
    method Action set_enabled(Bool en);
    method Bool good();
    method Bool fault();
    method Bool vrhot();

    // Compile time method which can be used by consuming modules to determine
    // an appropirate enable to good timeout.
    method Integer good_timeout();
endinterface

//
// Make `PowerRail` with the given enable to good timeout. This module expects
// methods in the `Pins` interface to be driven every cycle. The input pins are
// registered, so changes on a given pin are not reflected on the corresponding
// `good`, `fault`, or `vrhot` methods until the next cycle.
//
module mkPowerRail #(Integer good_timeout_) (PowerRail);
    ConfigReg#(Bool) enabled_r <- mkReg(False);
    // These could be DWires, but since these are presumably latched every cycle
    // a DReg is used to avoid sending module inputs straight to outputs.
    Reg#(Bool) good_r <- mkDReg(False);
    Reg#(Bool) fault_r <- mkDReg(False);
    Reg#(Bool) vrhot_r <- mkDReg(False);

    interface Pins pins;
        method en = enabled_r;
        method pg = good_r._write;
        method fault = fault_r._write;
        method vrhot = vrhot_r._write;
    endinterface

    method enabled = enabled_r;

    method Action set_enabled(Bool en);
        enabled_r <= en;
    endmethod

    method good = good_r;
    method fault = fault_r;
    method vrhot = vrhot_r;
    method good_timeout = good_timeout_;
endmodule

//
// Helper functions to facilitate higher order constructs, such as iterating
// over a `Vector` using `map` or `fold`.
//
function Bool enabled(PowerRail r) = r.enabled;
function Bool good(PowerRail r) = r.good;
function Bool fault(PowerRail r) = r.fault;
function Bool vrhot(PowerRail r) = r.vrhot;
function Integer good_timeout(PowerRail r) = r.good_timeout;

//
// PowerRailModel
//
// A set of interfaces and modules implementing a mock PowerRail. This is
// primarily intended to be used in test benches but can be synthesized for use
// in a board emulator running alongside the design under test.
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
        Integer power_good_delay)
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

    Strobe#(delay_sz) good_event <- mkPowerTwoStrobe(1, 0);

    (* fire_when_enabled *)
    rule do_power_good_countdown (enabled && !good && tick);
        good_event.send();
    endrule

    //
    // Fault event
    //

    RWire#(UInt#(delay_sz)) schedule_fault_request <- mkRWire();
    ConfigReg#(Bool) fault_scheduled <- mkConfigReg(False);
    Strobe#(delay_sz) fault_event <- mkPowerTwoStrobe(1, 0);

    (* fire_when_enabled *)
    rule do_fault_event_countdown (enabled && fault_scheduled && tick);
        fault_event.send;
    endrule

    //
    // VR Hot event
    //

    RWire#(UInt#(delay_sz)) schedule_vrhot_request <- mkRWire();
    ConfigReg#(Bool) vrhot_scheduled <- mkConfigReg(False);
    Strobe#(delay_sz) vrhot_event <- mkPowerTwoStrobe(1, 0);

    (* fire_when_enabled *)
    rule do_vrhot_event_countdown (enabled && vrhot_scheduled && tick);
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
            good_event <= maxBound - fromInteger(power_good_delay);
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

        // Adjust whether or not a fault is scheduled.
        if (schedule_fault_request.wget matches tagged Valid .delay) begin
            fault_event <= maxBound - delay;
        end

        fault_scheduled <=
            isValid(schedule_fault_request.wget) ||
            // Not scheduled once a fault or vrhot event occurs.
            (fault_scheduled && !(enabled && (fault_event || vrhot_event)));

        // Set VR Hot
        if (enabled && vrhot_event) begin
            vrhot <= True;
            $display(name, " hot");
        end
        else if (clear_faults_requested) begin
            vrhot <= False;
        end

        // Adjust whether or not a fault is scheduled.
        if (schedule_vrhot_request.wget matches tagged Valid .delay) begin
            vrhot_event <= maxBound - delay;
        end

        vrhot_scheduled <=
            isValid(schedule_vrhot_request.wget) ||
            // Not scheduled once a vrhot event occurs.
            (vrhot_scheduled && !(enabled && vrhot_event));
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