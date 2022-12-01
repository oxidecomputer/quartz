// Copyright 2022 Oxide Computer Company
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package Tofino2Sequencer;

export Parameters(..);
export State(..);
export Step(..);
export Error(..);
export Tofino2Resets(..);
export Pins(..);
export Registers(..);
export Tofino2Sequencer(..);
export mkTofino2Sequencer;

import Assert::*;
import BuildVector::*;
import ConfigReg::*;
import Connectable::*;
import DefaultValue::*;
import DReg::*;
import StmtFSM::*;
import Vector::*;

import Countdown::*;
import PowerRail::*;
import SidecarMainboardControllerReg::*;

//
// Parameters controlling various timing aspects of the sequencer. The units for
// these delays are in "ticks". The sequencer is designed to receive these ticks
// every 1 ms, so these delays are assumed to be in ms.
//
typedef struct {
    // Max time a supply has to assert PG.
    Integer power_good_timeout;
    // Min time to wait after PG of VDDA18 and the release of pwron reset.
    Integer power_good_to_por_delay;
    // Min time to wait after clocks are enabled and the release of pwron reset.
    Integer clocks_enable_to_por_delay;
    // Delay after VDD1P8 is stable before VID bits should be sampled.
    Integer vid_valid_delay;
    // Timeout value for software to acknowledge the VID and adjust the VDDCORE
    // voltage before the power up sequence is aborted.
    Integer vid_ack_timeout;
    // Delay between the release of pwron_rst and pcie_rst_l.
    Integer por_to_pcie_delay;
} Parameters;

//
// Default parameters for the sequencer. Given a 1 ms tick for the sequencer,
// these values are in ms.
//
instance DefaultValue#(Parameters);
    defaultValue =
        Parameters {
            // The rails driven by this sequencer have an order requirement but
            // no maximum time between rails being turned on, so this timeout
            // does not need to be aggressive. The measured time from EN high to
            // PG high for these power rails is 5-10ms, so a timeout of 25ms
            // seems like a safe limit.
            power_good_timeout: 24,
            power_good_to_por_delay: 10,
            clocks_enable_to_por_delay: 10,
            vid_valid_delay: 15,
            vid_ack_timeout: 190,
            por_to_pcie_delay: 250};
endinstance

typedef enum {
    Init                    = 0,
    A2                      = 1,
    A0                      = 2,
    InPowerUp               = 3,
    InPowerDown             = 4
} State deriving (Eq, Bits, FShow);

typedef enum {
    Init                    = 0,
    AwaitPowerUp            = 1,
    AwaitVdd18PowerGood     = 2,
    AwaitVddCorePowerGood   = 3,
    AwaitVddPCIePowerGood   = 4,
    AwaitVddtPowerGood      = 5,
    AwaitVdda15PowerGood    = 6,
    AwaitVdda18PowerGood    = 7,
    AwaitPoR                = 8,
    AwaitVidValid           = 9,
    AwaitVidAck             = 10,
    AwaitPowerUpComplete    = 11,
    AwaitPowerDown          = 12,
    AwaitPowerDownComplete  = 13
} Step deriving (Eq, Bits, FShow);

typedef enum {
    None                    = 0,
    PowerGoodTimeout        = 1,
    PowerFault              = 2,
    PowerVrHot              = 3,
    PowerAbort              = 4,
    SoftwareAbort           = 5,
    VidAckTimeout           = 6,
    ThermalAlert            = 7
} Error deriving (Eq, Bits, FShow);

interface Registers;
    interface Reg#(TofinoSeqCtrl) ctrl;
    interface ReadOnly#(TofinoSeqState) state;
    interface ReadOnly#(TofinoSeqStep) step;
    interface ReadOnly#(TofinoSeqError) error;
    interface ReadOnly#(TofinoSeqErrorState) error_state;
    interface ReadOnly#(TofinoSeqErrorStep) error_step;
    interface ReadOnly#(PowerRailState) vdd18;
    interface ReadOnly#(PowerRailState) vddcore;
    interface ReadOnly#(PowerRailState) vddpcie;
    interface ReadOnly#(PowerRailState) vddt;
    interface ReadOnly#(PowerRailState) vdda15;
    interface ReadOnly#(PowerRailState) vdda18;
    interface ReadOnly#(TofinoPowerVid) vid;
    interface ReadOnly#(TofinoReset) tofino_reset;
    interface ReadOnly#(TofinoMisc) misc;
endinterface

typedef struct {
    Bool pwron;
    Bool pcie;
} Tofino2Resets deriving (Bits, Eq, FShow);

(* always_enabled *)
interface Pins;
    interface PowerRail::Pins vdd18;
    interface PowerRail::Pins vddcore;
    interface PowerRail::Pins vddpcie;
    interface PowerRail::Pins vddt;
    interface PowerRail::Pins vdda15;
    interface PowerRail::Pins vdda18;
    method Tofino2Resets resets();
    method Action vid(Bit#(3) val);
    method Bool clocks_enable();
    method Action thermal_alert(Bool val);
endinterface

interface Tofino2Sequencer;
    interface Pins pins;
    interface Registers registers;
    interface PulseWire tick_1ms;
    method Action pcie_reset();
endinterface

// Typedef for a PowerRail with a timeout duration of up to 32 ticks.
typedef PowerRail::PowerRail#(TLog#(32)) PowerRail;

//
// mkTofino2Sequencer
//
// Implementation of a power, clock and reset sequencer for Tofino 2, which with
// appropriate `Parameters` executes the power up sequence as specified in
// TF2-DS2-003EA, Figure 1. The sole purpose of this module is to, with the help
// of an external thermal sensor, various PDN components and the SP, maintain a
// safe operating envelop for Tofino 2. It does so by monitoring temperature and
// power related fault signals and maintaining the required timing constraints
// as various events happen. In the event of operating conditions outside of the
// set envelope the sequencer will quickly shut down Tofino and its power rails
// as to reduce the risk of permanent damage to the device.
//
// High level theory of operation:
//
// Upon initial reset of the design the sequencer will transition from its Init
// state into the A2 state. From here the sequencer can transition to A0 through
// the InPowerUp state and from A0 back to A2 through the InPowerDown state.
// InPowerUp and InPowerDown are strictly transitional states to go from A2 to
// A0 and back and by design consist of a finite number of steps. Upon properly
// executing the steps managed by the InPowerUp and InPowerUp states, the
// sequencer (and by extension Tofino) can safely dwell indefinite in either of
// the A2 or A0 states.
//
// While in A2 the sequencer monitors fault conditions and waits for a power up
// command through the `TOFINO_SEQ_CTRL` register. If a fault condition occurs
// while in this state it is recorded and the error needs to be explicitly
// cleared by setting the `CLEAR_ERROR` bit in the `TOFINO_SEQ_CTRL` register
// before a power up can be attempted.
//
// While in A0 the sequencer similarly monitors possible fault conditions,
// transitioning to InPowerDown if such events occur. If no faults occur a power
// down can be requested by clearing the `EN` bit in `TOFINO_SEQ_CTRL`.
//
// If a fault occurs the `error`, `error_state` and `error_step` registers
// contain the details of what the sequencer was executing when it was
// interrupted. Once such an event occurs the `CLEAR_ERROR` bit in the
// `TOFINO_SEQ_CTRL` register needs to be set in order to clear this state. When
// this bit is set the sequencer is forced into the Init state, clearing the
// error and power rail state, and will transition into A2 on the next cycle.
//
// While in InPowerUp the sequencer executes a series of steps to transition
// from A2 to A0:
//
// - Enable each required power rail in sequence
// - Enable the clocks
// - Wait for power and clocks to be stable
// - Initiate the power on reset
// - Wait for confirmation that the VDDCORE Vout value has been adjusted
//   according to the VID value
// - Allow PCIe reset to be released
//
// These steps are implemented in the `tofino2_power_up_seq` FSM. If a fault
// occurs during the execution of this sequence, such as the power good signal
// of a power rail not going high within the set time, the sequence is aborted
// and the sequencer immediately transitions to InPowerDown.
//
// Finally the InPowerDown state executes a series of steps to safely get back
// into the A2 state:
//
// - Assert device resets, disable clocks
// - Disable the power rails in reverse order from InPowerUp
//
// These steps are implemented in `tofino2_power_down_seq` and by design this
// sequence is both simpler and shorter than the power up sequence. Once
// initiated it can not be interrupted and the sequencer will not consider any
// control inputs until the A2 state has been reached. At this point any errors
// can be cleared by the SP and another power up attempted.
//
// Notes:
//
// - The `tick_1ms` method is expected to be called every 1 ms and can be
//   directly connected to an appropriate `Strobe`
// - The `Registers` interface is implemented using ConfigRegs and can be
//   directly exposed in a register map
// - Calling `pcie_reset` will keep the Tofino 2 PCIe link in reset, with its
//   I/O pins in high-Z. This is intended to be connected to the PERST signal
//   coming from a host
//
module mkTofino2Sequencer #(Parameters parameters) (Tofino2Sequencer);
    staticAssert(parameters.vid_valid_delay < parameters.vid_ack_timeout,
        "vid_valid_delay should be less than vid_ack_timeout");
    staticAssert(parameters.vid_ack_timeout < parameters.por_to_pcie_delay,
        "vid_ack_timeout should be less than por_to_pcie_delay");

    staticAssert(parameters.power_good_to_por_delay > 1, "PG2POR should be >1ms");
    staticAssert(parameters.vid_ack_timeout < 200,
        "vid_ack_timeout >200ms, risking damage to Tofino2 in fault situation");
    staticAssert(parameters.por_to_pcie_delay > 200,
        "POR2PCIe delay should be >200ms");

    PowerRail vdd18 <- mkPowerRailLeaveEnabledOnAbort(parameters.power_good_timeout);
    PowerRail vddcore <- mkPowerRailLeaveEnabledOnAbort(parameters.power_good_timeout);
    PowerRail vddpcie <- mkPowerRailDisableOnAbort(parameters.power_good_timeout);
    PowerRail vddt <- mkPowerRailLeaveEnabledOnAbort(parameters.power_good_timeout);
    PowerRail vdda15 <- mkPowerRailLeaveEnabledOnAbort(parameters.power_good_timeout);
    PowerRail vdda18 <- mkPowerRailLeaveEnabledOnAbort(parameters.power_good_timeout);

    Vector#(6, PowerRail) power_rails =
        vec(vdd18, vddcore, vddpcie, vddt, vdda15, vdda18);

    // Timing state.
    PulseWire tick <- mkPulseWire();
    Countdown#(8) delay <- mkCountdownBy1();

    mkConnection(asIfc(tick), asIfc(delay));

    // FSM state.
    ConfigReg#(State) state <- mkConfigReg(Init);
    ConfigReg#(Step) step <- mkConfigReg(Init);
    ConfigReg#(Error) error <- mkConfigRegU();
    // Copies of the state and step registers which get set when an error occurs
    // so software can analyze these events.
    ConfigReg#(State) error_state <- mkConfigRegU();
    ConfigReg#(Step) error_step <- mkConfigRegU();

    ConfigReg#(Tofino2Resets) tofino_resets <- mkConfigRegU();
    ConfigReg#(Bool) tofino_clocks_enable <- mkConfigRegU();
    ConfigReg#(Maybe#(UInt#(4))) tofino_vid <- mkConfigRegU();

    // Abort events.
    Reg#(Bool) thermal_alert <- mkDReg(False);
    Reg#(Bool) power_good_timeout <- mkDReg(False);
    Reg#(Bool) power_abort <- mkDReg(False);
    Reg#(Bool) power_fault <- mkDReg(False);
    Reg#(Bool) power_vrhot <- mkDReg(False);
    Reg#(Bool) vid_ack_timeout <- mkDReg(False);
    Reg#(Bool) abort <- mkDReg(False);

    // Control state
    ConfigReg#(TofinoSeqCtrl) ctrl <- mkConfigRegU(); // Reset during init.
    ConfigReg#(TofinoSeqCtrl) ctrl_one_shot <- mkDReg(unpack('0));

    // PulseWires used to signal/chain rules within in the same cycle.
    PulseWire software_abort_request <- mkPulseWire();
    PulseWire pcie_reset_request <- mkPulseWire();
    PulseWire start_power_up <- mkPulseWire();
    PulseWire start_power_down <- mkPulseWire();

    // Connect the timeout pulse of the power rails.
    mkConnection(asIfc(tick), vdd18);
    mkConnection(asIfc(tick), vddcore);
    mkConnection(asIfc(tick), vddpcie);
    mkConnection(asIfc(tick), vddt);
    mkConnection(asIfc(tick), vdda15);
    mkConnection(asIfc(tick), vdda18);

    //
    // Helpers, implementing the details of sequencing steps.
    //

    function Stmt enable_rail(PowerRail rail, Step s) =
        seq
            // Set the enable pin and the sequencing step.
            action
                rail.set_enable(True);
                step <= s;
            endaction
            // Monitor the rail state for a power good timeout.
            while (!rail.enabled) action
                if (rail.timed_out) begin
                    power_good_timeout <= True;
                end
            endaction
        endseq;

    function Stmt await_por() =
        seq
            action
                step <= AwaitPoR;
                delay <= fromInteger(max(
                    parameters.power_good_to_por_delay,
                    parameters.clocks_enable_to_por_delay));
            endaction
            await(delay);
        endseq;

    function Action power_on_reset() =
        action
            step <= AwaitVidValid;
            tofino_resets <= Tofino2Resets {pwron: False, pcie: True};
            delay <= fromInteger(parameters.por_to_pcie_delay + 1);
        endaction;

    function Stmt await_vid_valid() =
        seq
            await(delay.count == fromInteger(
                parameters.por_to_pcie_delay -
                parameters.vid_valid_delay + 1));
            step <= AwaitVidAck;
        endseq;

    function Action await_vid_ack() = await(ctrl_one_shot.ack_vid == 1);

    function Stmt await_power_up_complete() =
        seq
            step <= AwaitPowerUpComplete;
            await(delay);
        endseq;

    //
    // Sequencer state machines.
    //

    (* fire_when_enabled *)
    rule do_reset_sequencer (state == Init);
        state <= A2;
        step <= AwaitPowerUp;
        error <= None;
        error_state <= Init;
        error_step <= Init;
        ctrl <= defaultValue;

        // Make sure all power rails are disabled and any faults are cleared.
        vdd18.clear();
        vddcore.clear();
        vddpcie.clear();
        vddt.clear();
        vdda15.clear();
        vdda18.clear();

        tofino_resets <= Tofino2Resets{pwron: True, pcie: True};
        tofino_vid <= tagged Invalid;
    endrule

    FSM tofino2_power_up_seq <- mkFSMWithPred(seq
        enable_rail(vdd18, AwaitVdd18PowerGood);
        enable_rail(vddcore, AwaitVddCorePowerGood);
        enable_rail(vddpcie, AwaitVddPCIePowerGood);
        enable_rail(vddt, AwaitVddtPowerGood);
        enable_rail(vdda15, AwaitVdda15PowerGood);
        enable_rail(vdda18, AwaitVdda18PowerGood);
        tofino_clocks_enable <= True;
        await_por();
        power_on_reset();
        await_vid_valid();
        await_vid_ack();
        await_power_up_complete();
        step <= AwaitPowerDown;
    endseq, state == InPowerUp && !abort);

    FSM tofino2_power_down_seq <- mkFSMWithPred(seq
        action
            tofino_resets <= Tofino2Resets{pwron: True, pcie: True};
            tofino_clocks_enable <= False;
            tofino_vid <= tagged Invalid;
            step <= AwaitPowerDownComplete;
        endaction
        // Disable the power rails. For any rails still disabled this is a
        // no-op. If a rail experienced a power good timeout the enable pin is
        // low but the state will remain in `Timeout`. For any rails with state
        // `Aborted` the enable pin will remain unchanged (in order to avoid a
        // reset and discarding the fault information) and the state will remain
        // unchanged.
        vdda18.set_enable(False);
        vdda15.set_enable(False);
        vddt.set_enable(False);
        vddpcie.set_enable(False);
        vddcore.set_enable(False);
        vdd18.set_enable(False);
        step <= AwaitPowerUp;
    endseq, state == InPowerDown && tick);

    (* fire_when_enabled *)
    rule do_monitor_fault_conditions (
            error == None &&
            (state == InPowerUp || state == A0));
        // Determine if the given condition occured for any of the power rails.
        // Note that these event flags are registered and not acted upon until
        // the next cycle.
        power_abort <= any(PowerRail::aborted, power_rails);
        power_fault <= any(PowerRail::fault, power_rails);
        power_vrhot <= any(PowerRail::vrhot, power_rails);

        // Generate VID ack timout when appropriate. This is done by monitoring
        // the PoR to PCIe delay counter which is running during the AwaitVidAck
        // step for the given limit. The static asserts at the beginning of this
        // module assure that this limit is valid.
        let vid_ack_timeout_count = fromInteger(
            parameters.por_to_pcie_delay - parameters.vid_ack_timeout);

        if (step == AwaitVidAck && delay.count == vid_ack_timeout_count) begin
            vid_ack_timeout <= True;
        end

        // Monitor all fault flags and initiate an abort if one goes high.
        if (thermal_alert ||
                power_vrhot ||
                power_fault ||
                power_abort ||
                power_good_timeout ||
                vid_ack_timeout ||
                software_abort_request) begin
            // Raise the abort flag and trigger a power down.
            abort <= True;

            // Save the sequencer state and step when the error was detected.
            error_state <= state;
            error_step <= step;

            // Some of these events could happen simultaneously. Report these in
            // the order of least likely to happen/most interesting to report.
            if (thermal_alert) begin
                error <= ThermalAlert;
            end else if (power_vrhot) begin
                error <= PowerVrHot;
            end else if (power_fault) begin
                error <= PowerFault;
            end else if (power_abort) begin
                error <= PowerAbort;
            end else if (power_good_timeout) begin
                error <= PowerGoodTimeout;
            end else if (vid_ack_timeout) begin
                error <= VidAckTimeout;
            end else if (software_abort_request) begin
                error <= SoftwareAbort;
            end
        end
    endrule

    (* fire_when_enabled *)
    rule do_sequence (state != Init);
        // Power down if an abort is requested by the fault monitor.
        if ((state == InPowerUp || state == A0) && abort) begin
            $display(
                fshow(error), " during ",
                fshow(error_state), " ", fshow(error_step));
            $display("Tofino2 in power down");
            state <= InPowerDown;

            if (state == InPowerUp) begin
                tofino2_power_up_seq.abort();
            end

            start_power_down.send();
        end

        // Handle control events while in A2.
        else if (state == A2) begin
            if (error == None && ctrl.en == 1) begin
                $display("Tofino2 in power up");
                state <= InPowerUp;
                start_power_up.send();
            end

            else if (error != None && ctrl_one_shot.clear_error == 1) begin
                $display("Clearing error");
                state <= Init;
            end
        end

        // Handle control events while in power up.
        else if (state == InPowerUp) begin
            if (ctrl.en == 0) begin
                $display("Power up abort requested");
                software_abort_request.send();
            end

            else if (tofino2_power_up_seq.done) begin
                $display("Tofino2 in A0");
                state <= A0;
            end

            // Display VID ack when simulating.
            if (ctrl_one_shot.ack_vid == 1) begin
                $display("VID ack");
            end
        end

        // Handle power down request while in A0.
        else if (state == A0 && ctrl.en == 0) begin
            $display("Tofino2 in power down");
            state <= InPowerDown;
            start_power_down.send();
        end

        // Handle power down complete.
        else if (state == InPowerDown && tofino2_power_down_seq.done) begin
            $display("Tofino2 in A2");
            state <= A2;
        end
    endrule

    // The sequence `start` methods are blocking. Running them as part of the
    // `do_sequence` rule would cause a scheduling loop and block the rule from
    // running. Call these in separate rules, triggered using pulse wires.
    (* fire_when_enabled *)
    rule do_start_power_up (start_power_up);
        tofino2_power_up_seq.start();
    endrule

    (* fire_when_enabled *)
    rule do_start_power_down (start_power_down);
        tofino2_power_down_seq.start();
    endrule

    // Allow the external control over PERST while Tofino is in A0.
    (* fire_when_enabled *)
    rule do_pcie_reset (state == A0 && !abort);
        tofino_resets <= Tofino2Resets{
            pwron: tofino_resets.pwron, // Sticky while in A0.
            pcie: pcie_reset_request};
    endrule

    //
    // Interface
    //

    // Call the given function on each power rail in the `power_rails` vector
    // and return the result as a register struct.
    function mapPowerRailsToReg(f) =
        valueToReadOnly(unpack(extend(pack(map(f, power_rails)))));

    interface Pins pins;
        method Tofino2Resets resets = tofino_resets;

        method Action vid(Bit#(3) val)
                if (state == InPowerUp && step == AwaitVidAck);
            tofino_vid <= tagged Valid(unpack({1'b1, val}));
        endmethod

        method clocks_enable = tofino_clocks_enable;
        method thermal_alert = thermal_alert._write;

        interface PowerRail::Pins vdd18 = vdd18.pins;
        interface PowerRail::Pins vddcore = vddcore.pins;
        interface PowerRail::Pins vddpcie = vddpcie.pins;
        interface PowerRail::Pins vddt = vddt.pins;
        interface PowerRail::Pins vdda15 = vdda15.pins;
        interface PowerRail::Pins vdda18 = vdda18.pins;
    endinterface

    interface Registers registers;
        interface Reg ctrl;
            method _read = ctrl;
            method Action _write(TofinoSeqCtrl next) if (!(state == Init || abort));
                // Split the write in sticky/non-sticky bits.
                ctrl <= TofinoSeqCtrl{
                    clear_error: 0,
                    en: next.en,
                    ack_vid: 0};

                ctrl_one_shot <= TofinoSeqCtrl{
                    clear_error: next.clear_error,
                    en: 0,
                    ack_vid: next.ack_vid};
            endmethod
        endinterface

        interface ReadOnly state = castToReadOnly(state);
        interface ReadOnly step = castToReadOnly(step);
        interface ReadOnly error = castToReadOnly(error);
        interface ReadOnly error_state = castToReadOnly(error_state);
        interface ReadOnly error_step = castToReadOnly(error_step);

        // Power rail state.
        interface ReadOnly vdd18 = powerRailToReadOnly(vdd18);
        interface ReadOnly vddcore = powerRailToReadOnly(vddcore);
        interface ReadOnly vddpcie = powerRailToReadOnly(vddpcie);
        interface ReadOnly vddt = powerRailToReadOnly(vddt);
        interface ReadOnly vdda15 = powerRailToReadOnly(vdda15);
        interface ReadOnly vdda18 = powerRailToReadOnly(vdda18);

        interface ReadOnly vid =
            valueToReadOnly(TofinoPowerVid{
                vid_valid: pack(isValid(tofino_vid)),
                reserved: 0,
                vid: pack(fromMaybe(0, tofino_vid))});
        interface ReadOnly tofino_reset =
            valueToReadOnly(TofinoReset{
                pwron: pack(tofino_resets.pwron),
                pcie: pack(tofino_resets.pcie)});
        interface ReadOnly misc =
            valueToReadOnly(TofinoMisc{
                clocks_en: pack(tofino_clocks_enable),
                thermal_alert: pack(thermal_alert)});
    endinterface

    interface PulseWire tick_1ms = tick;

    method pcie_reset = pcie_reset_request.send;
endmodule

// Helpers used to map values/internal registers onto the register interface.
function ReadOnly#(t) valueToReadOnly(t val);
    return (
        interface ReadOnly
            method _read = val;
        endinterface);
endfunction

function ReadOnly#(v) castToReadOnly(t val)
        provisos (Bits#(t, t_sz), Bits#(v, v_sz), Add#(t_sz, _, v_sz));
    return (
        interface ReadOnly
            method _read = unpack(zeroExtend(pack(val)));
        endinterface);
endfunction

function ReadOnly#(PowerRailState) powerRailToReadOnly(PowerRail rail);
    return (
        interface ReadOnly
            method _read =
                PowerRailState {
                    enable: pack(rail.pin_state.enable),
                    good: pack(rail.pin_state.good),
                    fault: pack(rail.pin_state.fault),
                    vrhot: pack(rail.pin_state.vrhot),
                    state: extend(pack(rail.state))};
        endinterface);
endfunction

endpackage
