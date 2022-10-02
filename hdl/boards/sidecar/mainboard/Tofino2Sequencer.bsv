// Copyright 2022 Oxide Computer Company
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package Tofino2Sequencer;

export Parameters(..), State(..), SequencingStep(..), Error(..);
export Tofino2Resets(..), Pins(..), Registers(..);
export Tofino2Sequencer(..), mkTofino2Sequencer;

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
            power_good_timeout: 10,
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
} SequencingStep deriving (Eq, Bits, FShow);

typedef enum {
    None                    = 0,
    PowerGoodTimeout        = 1,
    PowerFault              = 2,
    PowerVrHot              = 3,
    PowerInvalidState       = 4,
    UserAbort               = 5,
    VidAckTimeout           = 6,
    ThermalAlert            = 7
} Error deriving (Eq, Bits, FShow);

interface Registers;
    interface Reg#(TofinoSeqCtrl) ctrl;
    interface ReadOnly#(TofinoSeqState) state;
    interface ReadOnly#(TofinoSeqStep) step;
    interface ReadOnly#(TofinoSeqError) error;
    interface ReadOnly#(TofinoPowerEnable) power_enable;
    interface ReadOnly#(TofinoPowerGood) power_good;
    interface ReadOnly#(TofinoPowerFault) power_fault;
    interface ReadOnly#(TofinoPowerVrhot) power_vrhot;
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

// Typedef for a PowerRail with a timeout duration of up to 15 ticks.
typedef PowerRail::PowerRail#(4) PowerRail;

//
// mkTofino2Sequencer
//
// Implementation of a power, clock and reset sequencer for Tofino 2, which with
// appropriate `Parameters` executes the power up sequence as specified in
// TF2-DS2-003EA, Figure 1. The sole purpose of this module is to, with the help
// of an external thermal sensor, various PDN components and the SP, maintain a
// safe operating envelop for Tofino 2. It does so by monitoring temperature and
// power related fault signals and maintaining the required timing constraints
// as various events happen. In practice in most cases it will quickly shut down
// Tofino and its power rails as to reduce the risk of permanent damage to the
// device.
//
// High level theory of operation:
//
// Upon initial reset of the design the sequencer will transition from its
// initial Invalid state into the A2 state. At this point the sequencer will
// forever remain in one of four states; A2, InPowerUp, A0 or InPowerDown.
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
// of a power rail not going high with the set time, the sequence is aborted and
// the sequencer immediately transitions to InPowerDown.
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

    staticAssert(parameters.power_good_to_por_delay > 1, "PG2POR should be > 1ms");
    staticAssert(parameters.vid_ack_timeout < 200,
        "vid_ack_timeout > 200ms, risking damage to Tofino2 in fault situation");
    staticAssert(parameters.por_to_pcie_delay > 200,
        "POR2PCIe delay should be > 200ms");

    PowerRail vdd18 <- mkPowerRail(parameters.power_good_timeout);
    PowerRail vddcore <- mkPowerRail(parameters.power_good_timeout);
    PowerRail vddpcie <- mkPowerRail(parameters.power_good_timeout);
    PowerRail vddt <- mkPowerRail(parameters.power_good_timeout);
    PowerRail vdda15 <- mkPowerRail(parameters.power_good_timeout);
    PowerRail vdda18 <- mkPowerRail(parameters.power_good_timeout);

    // Add power rails to a vector for easy aggreation of enabled, good, fault
    // and vrhot signals.
    Vector#(6, PowerRail) power_rails =
        vec(vdd18, vddcore, vddpcie, vddt, vdda15, vdda18);

    // Timing state.
    PulseWire tick <- mkPulseWire();
    Countdown#(8) delay <- mkCountdownBy1();

    mkConnection(asIfc(tick), asIfc(delay));

    // FSM state.
    ConfigReg#(State) state <- mkConfigReg(Init);
    ConfigReg#(SequencingStep) step <- mkConfigReg(Init);
    ConfigReg#(Error) error <- mkConfigRegU();

    ConfigReg#(Tofino2Resets) tofino_resets <- mkConfigRegU();
    ConfigReg#(Bool) tofino_clocks_enable <- mkConfigRegU();
    ConfigReg#(Maybe#(UInt#(4))) tofino_vid <- mkConfigRegU();

    // Abort flags
    Reg#(Bool) thermal_alert <- mkDReg(False);
    Reg#(Bool) power_good_timeout <- mkDReg(False);
    Reg#(Bool) power_rail_invalid_state <- mkDReg(False);
    Reg#(Bool) fault <- mkDReg(False);
    Reg#(Bool) vrhot <- mkDReg(False);
    Reg#(Bool) abort <- mkDReg(False);
    Reg#(Bool) vid_ack_timeout <- mkDReg(False);

    // Control state
    ConfigReg#(TofinoSeqCtrl) ctrl <- mkConfigRegU(); // Reset during init.
    ConfigReg#(TofinoSeqCtrl) ctrl_one_shot <- mkDReg(unpack('0));

    // PulseWires used to signal/chain rules within in the same cycle.
    PulseWire abort_request <- mkPulseWire();
    PulseWire pcie_reset_request <- mkPulseWire();

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

    function Action enable_rail(PowerRail rail, SequencingStep s) =
        action
            step <= s;
            rail.set_enabled(True);
        endaction;

    function Action disable_rail(PowerRail rail) =
        action
            rail.set_enabled(False);
        endaction;

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
            tofino_resets <= Tofino2Resets{pwron: False, pcie: True};
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
        ctrl <= unpack('0);

        tofino_resets <= Tofino2Resets{pwron: True, pcie: True};
        tofino_vid <= tagged Invalid;
    endrule

    FSM tofino2_power_up_seq <- mkFSMWithPred(seq
        enable_rail(vdd18, AwaitVdd18PowerGood);
        await(vdd18.good);
        enable_rail(vddcore, AwaitVddCorePowerGood);
        await(vddcore.good);
        enable_rail(vddpcie, AwaitVddPCIePowerGood);
        await(vddpcie.good);
        enable_rail(vddt, AwaitVddtPowerGood);
        await(vddt.good);
        enable_rail(vdda15, AwaitVdda15PowerGood);
        await(vdda15.good);
        enable_rail(vdda18, AwaitVdda18PowerGood);
        await(vdda18.good);
        tofino_clocks_enable <= True;
        await_por();
        power_on_reset();
        await_vid_valid();
        await_vid_ack();
        await_power_up_complete();
        action
            state <= A0;
            step <= AwaitPowerDown;
        endaction
    endseq, state == InPowerUp && !abort);

    FSM tofino2_power_down_seq <- mkFSMWithPred(seq
        action
            tofino_resets <= Tofino2Resets{pwron: True, pcie: True};
            tofino_clocks_enable <= False;
            tofino_vid <= tagged Invalid;
            step <= AwaitPowerDownComplete;
        endaction
        disable_rail(vdda18);
        disable_rail(vdda15);
        disable_rail(vddt);
        disable_rail(vddpcie);
        disable_rail(vddcore);
        disable_rail(vdd18);
        action
            state <= A2;
            step <= AwaitPowerUp;
        endaction
    endseq, state == InPowerDown && tick);

    (* fire_when_enabled *)
    rule do_detect_power_rail_in_invalid_state (state == InPowerUp || state == A0);
        // The intend of this rule is to detect any discrepencies between the
        // enable/power good state of each power rail. Once a power rail has
        // been enabled it is expected to be in transition during its sequencing
        // step. Once pas that sequencing step its power good signal should
        // match the enable signal.

        let rails_expected_good = map(PowerRail::enabled, power_rails);
        let rails_good = map(PowerRail::good, power_rails);
        let rails_in_transition =
            case (step)
                AwaitVdd18PowerGood:    vec(True, False, False, False, False, False);
                AwaitVddCorePowerGood:  vec(False, True, False, False, False, False);
                AwaitVddPCIePowerGood:  vec(False, False, True, False, False, False);
                AwaitVddtPowerGood:     vec(False, False, False, True, False, False);
                AwaitVdda15PowerGood:   vec(False, False, False, False, True, False);
                AwaitVdda18PowerGood:   vec(False, False, False, False, False, True);
                default:                vec(False, False, False, False, False, False);
            endcase;

        // For each rail, generate a (expected_good, is_good, in_transition) tuple.
        let rails_states = zip3(rails_expected_good, rails_good, rails_in_transition);

        function determine_rail_state_as_expected(rail_state, previous_rails_as_expected);
            match {.expected_good, .is_good, .in_transition} = rail_state;
            return previous_rails_as_expected &&
                    (in_transition || (expected_good == is_good));
        endfunction

        // Fold the rails_states vector, determining if for each rail their
        // enabled and good signals are as expected. If the result of this
        // action is False it means a rail not intended to be enabled has its
        // power good signal high, or a rail which marked as enabled and is
        // supposed to signal power good does not. Both these situations may
        // occur if for example an entity other than the sequencer can
        // enable/disable power rails, say through PMBus.
        power_rail_invalid_state <=
            !foldr(determine_rail_state_as_expected, True, rails_states);
    endrule

    function bool_or(a, b) = a || b;
    function bool_and(a, b) = a && b;

    (* fire_when_enabled *)
    rule do_power_good_timeout_aggregation (state == InPowerUp);
        power_good_timeout <=
            foldr(bool_or, False, map(PowerRail::good_timeout, power_rails));
    endrule

    (* fire_when_enabled *)
    rule do_fault_aggregation;
        fault <= foldr(bool_or, False, map(PowerRail::fault, power_rails));
    endrule

    (* fire_when_enabled *)
    rule do_vrhot_aggregation;
        vrhot <= foldr(bool_or, False, map(PowerRail::vrhot, power_rails));
    endrule

    (* fire_when_enabled *)
    rule do_vid_ack_timeout (
            state == InPowerUp &&
            step == AwaitVidAck &&
            delay.count ==
                fromInteger(
                    parameters.por_to_pcie_delay -
                    parameters.vid_ack_timeout));
        vid_ack_timeout <= True;
    endrule

    (* fire_when_enabled *)
    rule do_monitor_abort_conditions (
            state != Init &&
            error == None &&
            (abort_request ||
                power_good_timeout ||
                power_rail_invalid_state ||
                fault ||
                vrhot ||
                vid_ack_timeout ||
                thermal_alert));
        abort <= True;

        if (thermal_alert) begin
            error <= ThermalAlert;
        end else if (vrhot) begin
            error <= PowerVrHot;
        end else if (fault) begin
            error <= PowerFault;
        end else if (power_rail_invalid_state) begin
            error <= PowerInvalidState;
        end else if (power_good_timeout) begin
            error <= PowerGoodTimeout;
        end else if (vid_ack_timeout) begin
            error <= VidAckTimeout;
        end else if (abort_request) begin
            error <= UserAbort;
        end
    endrule

    (* fire_when_enabled *)
    rule do_abort ((state == InPowerUp || state == A0) && abort);
        $display("Tofino2 in power down");
        state <= InPowerDown;

        if (state == InPowerUp) begin
            tofino2_power_up_seq.abort();
        end

        ctrl.en <= 0;
        tofino2_power_down_seq.start();
    endrule

    //
    // Actions as a result of CTRL writes.
    //

    (* fire_when_enabled *)
    rule do_power_up (
            !abort &&
            state == A2 &&
            error == None &&
            ctrl.en == 1);
        $display("Tofino2 in power up");
        state <= InPowerUp;
        tofino2_power_up_seq.start();
    endrule

    (* fire_when_enabled *)
    rule do_power_down (
            !abort &&
            state == A0 &&
            ctrl.en == 0);
        $display("Tofino2 in power down");
        state <= InPowerDown;
        tofino2_power_down_seq.start();
    endrule

    (* fire_when_enabled *)
    rule do_abort_request (state == InPowerUp && ctrl.en == 0);
        $display("Power up abort requested");
        abort_request.send();
    endrule

    (* fire_when_enabled *)
    rule do_clear_error (
            state != Init &&
            error != None &&
            ctrl_one_shot.clear_error == 1);
        $display("Clearing error");
        error <= None;
    endrule

    (* fire_when_enabled *)
    rule do_acknowledge_vid (
            !abort &&
            state == InPowerUp &&
            ctrl_one_shot.ack_vid == 1);
        $display("VID acknowledged");
    endrule

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

        interface PowerRailPins vdd18 = vdd18.pins;
        interface PowerRailPins vddcore = vddcore.pins;
        interface PowerRailPins vddpcie = vddpcie.pins;
        interface PowerRailPins vddt = vddt.pins;
        interface PowerRailPins vdda15 = vdda15.pins;
        interface PowerRailPins vdda18 = vdda18.pins;
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
        interface ReadOnly power_enable = mapPowerRailsToReg(PowerRail::enabled);
        interface ReadOnly power_good = mapPowerRailsToReg(PowerRail::good);
        interface ReadOnly power_fault = mapPowerRailsToReg(PowerRail::fault);
        interface ReadOnly power_vrhot = mapPowerRailsToReg(PowerRail::vrhot);
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

endpackage
