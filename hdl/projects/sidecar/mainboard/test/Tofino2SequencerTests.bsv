// Copyright 2022 Oxide Computer Company
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package Tofino2SequencerTests;

import Assert::*;
import ConfigReg::*;
import Connectable::*;
import DefaultValue::*;
import StmtFSM::*;

import Strobe::*;
import TestUtils::*;

import PowerRail::*;
import SidecarMainboardControllerReg::*;
import Tofino2Sequencer::*;


// Allow scheduling events up to 32 ticks in the future.
typedef TLog#(32) MaxEventDelay;

//
// A bench which wraps the Tofino2Sequencer and exposes a mock PDN, allowing for
// reuse of the test infrastructure.
//
interface Bench;
    interface PowerRailModel#(MaxEventDelay) vdd18;
    interface PowerRailModel#(MaxEventDelay) vddcore;
    interface PowerRailModel#(MaxEventDelay) vddpcie;
    interface PowerRailModel#(MaxEventDelay) vddt;
    interface PowerRailModel#(MaxEventDelay) vdda15;
    interface PowerRailModel#(MaxEventDelay) vdda18;
    interface Registers sequencer;

    // Return the bench generated "tick", allowing a test to for example
    // `await(bench.tick)`.
    method Bool tick;
    method Action set_thermal_alert(Bool raise_alert);

    //
    // Sequencer actions, implemented by writing to the sequencer control
    // register or exposed methods.
    //
    method Action power_up();
    method Action power_down();
    method Action ack_vid();
    method Action pcie_reset();
    method Action clear_error();

    // Convenience methods, decoding data in various sequencer registers.
    method Bool in_a2();
    method Bool in_a0();
    method Bool package_in_reset();
    method Bool pcie_in_reset();
    method Bool error_occured();

    // Return the current value of the sequencer error register.
    method Error error();
    // Return the VID value from the VID register.
    method Maybe#(Bit#(4)) vid();
    // Return whether or not the sequencer has enabled the clocks.
    method Bool clocks_enable();

    // Asserts
    method Action assert_abort(State state, Step step, Error error, String msg);
    method Action assert_power_rail_enable_summary_eq(
        Bit#(6) expected_summary,
        String msg);

    // Await helpers.
    method Action await_sequencer_state(State s);
endinterface

typedef struct {
    // Power good delays (in bench "ticks") for the mock PDN.
    Integer default_power_good_delay;
    Integer vddpcie_power_good_delay;
    // The VID bits as if strapped by Tofino.
    Bit#(3) vid;
    // Sequencer parameters, allowing them to be tweaked for specific tests.
    Tofino2Sequencer::Parameters sequencer;
} Parameters;

instance DefaultValue#(Parameters);
    defaultValue = Parameters{
        default_power_good_delay: 10,
        vddpcie_power_good_delay: 8,
        vid: 'b110, // Non-symmetric bit pattern to catch possible bit reversals.
        sequencer:
            Tofino2Sequencer::Parameters {
                power_good_timeout: defaultValue.power_good_timeout,
                power_good_to_por_delay: defaultValue.power_good_to_por_delay,
                clocks_enable_to_por_delay: defaultValue.clocks_enable_to_por_delay,
                vid_valid_delay: defaultValue.vid_valid_delay,
                vid_ack_timeout: 50,
                por_to_pcie_delay: 201}};
endinstance

// Compute a reasonable timeout (in number of simulation cycles) for a test
// watchdog to complete the power up sequence based on the given bench
// configuration.
function Integer power_up_test_timeout(Parameters p) =
    (6 * p.default_power_good_delay +
    p.sequencer.power_good_to_por_delay +
    p.sequencer.por_to_pcie_delay +
    10) * 4;

// Compute a reasonable timeout (in number of simulation cycles) for a test
// watchdog to complete the power down sequence based on the given bench
// configuration.
Integer power_down_test_timeout = 10 * 4;

module mkBench #(Parameters parameters) (Bench);
    // Reduce the time of the 1 kHz tick to 1/4th sim time. This provides a
    // reasonable balance between long sim times and seeing comperable behavior
    // of various timed components.
    Strobe#(2) tick_1khz <- mkPowerTwoStrobe(1, 0);
    mkFreeRunningStrobe(tick_1khz);

    function mkDefaultPowerRailModel(name) =
        mkPowerRailModel(
            name,
            tick_1khz,
            parameters.default_power_good_delay);

    PowerRailModel#(MaxEventDelay) vdd18_rail <- mkDefaultPowerRailModel("VDD18");
    PowerRailModel#(MaxEventDelay) vddcore_rail <- mkDefaultPowerRailModel("VDDCORE");
    PowerRailModel#(MaxEventDelay) vddpcie_rail <-
        mkPowerRailModel(
            "VDDPCIe",
            tick_1khz,
            parameters.vddpcie_power_good_delay);
    PowerRailModel#(MaxEventDelay) vddt_rail <- mkDefaultPowerRailModel("VDDt");
    PowerRailModel#(MaxEventDelay) vdda15_rail <- mkDefaultPowerRailModel("VDDA15");
    PowerRailModel#(MaxEventDelay) vdda18_rail <- mkDefaultPowerRailModel("VDDA18");

    ConfigReg#(Bool) thermal_alert <- mkConfigReg(False);

    Tofino2Sequencer dut <- mkTofino2Sequencer(parameters.sequencer);

    (* fire_when_enabled *)
    rule do_set_vid;
        dut.pins.vid(parameters.vid);
    endrule

    mkConnection(vdd18_rail.pins, dut.pins.vdd18);
    mkConnection(vddcore_rail.pins, dut.pins.vddcore);
    mkConnection(vddpcie_rail.pins, dut.pins.vddpcie);
    mkConnection(vddt_rail.pins, dut.pins.vddt);
    mkConnection(vdda15_rail.pins, dut.pins.vdda15);
    mkConnection(vdda18_rail.pins, dut.pins.vdda18);
    mkConnection(asIfc(tick_1khz), asIfc(dut.tick_1ms));

    mkConnection(thermal_alert._read, dut.pins.thermal_alert);

    // Bit vectors containing a summary of the enable and good signals of the
    // power rail status registers.
    Bit#(6) power_rail_enable_summary = {
        dut.registers.vdda18.enable,
        dut.registers.vdda15.enable,
        dut.registers.vddt.enable,
        dut.registers.vddpcie.enable,
        dut.registers.vddcore.enable,
        dut.registers.vdd18.enable};

    Bit#(6) power_rail_good_summary = {
        dut.registers.vdda18.good,
        dut.registers.vdda15.good,
        dut.registers.vddt.good,
        dut.registers.vddpcie.good,
        dut.registers.vddcore.good,
        dut.registers.vdd18.good};

    interface PowerRailModel vdd18 = vdd18_rail;
    interface PowerRailModel vddcore = vddcore_rail;
    interface PowerRailModel vddpcie = vddpcie_rail;
    interface PowerRailModel vddt = vddt_rail;
    interface PowerRailModel vdda15 = vdda15_rail;
    interface PowerRailModel vdda18 = vdda18_rail;
    interface Registers sequencer = dut.registers;

    method Action power_up() if (dut.registers.ctrl.en == 0);
        dut.registers.ctrl.en <= 1;
    endmethod

    method Action power_down() if (dut.registers.ctrl.en == 1);
        dut.registers.ctrl.en <= 0;
    endmethod

    method Action ack_vid() if (dut.registers.vid.vid_valid == 1);
        dut.registers.ctrl.ack_vid <= 1;
    endmethod

    method Action pcie_reset = dut.pcie_reset;

    method Action clear_error();
        dut.registers.ctrl.clear_error <= 1;
    endmethod

    method tick = tick_1khz;
    method error = unpack(dut.registers.error.error);
    method Maybe#(Bit#(4)) vid() =
        (dut.registers.vid.vid_valid == 1 ?
            tagged Valid (dut.registers.vid.vid) :
            tagged Invalid);

    method clocks_enable = dut.pins.clocks_enable;

    method set_thermal_alert = thermal_alert._write;

    method in_a2() = (dut.registers.state.state == 1);
    method in_a0() = (dut.registers.state.state == 2);
    method package_in_reset() = (dut.registers.tofino_reset.pwron == 1);
    method pcie_in_reset() = (dut.registers.tofino_reset.pcie == 1);
    method error_occured = (dut.registers.error.error != 0);

    method Action assert_abort(
            State expected_state,
            Step expected_step,
            Error expected_error,
            String msg);
        action
            Error error = unpack(dut.registers.error.error);
            State state = unpack(dut.registers.error_state.state);
            Step step = unpack(dut.registers.error_step.step);
            assert_eq(state, expected_state, msg);
            assert_eq(step, expected_step, msg);
            assert_eq(error, expected_error, msg);
        endaction
    endmethod

    method Action assert_power_rail_enable_summary_eq(
            Bit#(6) expected_summary,
            String msg);
        action
            $display("\tPower Rail EN: 0b%06b", power_rail_enable_summary);
            assert_eq(power_rail_enable_summary, expected_summary, msg);
        endaction
    endmethod

    method Action await_sequencer_state(State s) =
        await(unpack(dut.registers.state.state) == s);
endmodule

//
// mkPowerUpTest
//
// A test which covers the happy path when powering up a Tofino 2. The test
// starts with the sequencer in A2, testing each major step as it transitions to
// A0. The intended outcome is the sequencer to dwell in A0 for 50 sim ticks.
//
module mkPowerUpTest (Empty);
    Parameters parameters = defaultValue;
    Bench bench <- mkBench(parameters);

    Bit#(4) expected_vid = {1, parameters.vid};

    mkAutoFSM(seq
        assert_true(bench.in_a2, "Expected sequencer in A2");
        bench.assert_power_rail_enable_summary_eq('h00, "Expected no power rails enabled");
        assert_set(bench.sequencer.tofino_reset.pwron, "Expected package in reset");
        assert_set(bench.sequencer.tofino_reset.pcie, "Expected PCIe in reset");
        bench.power_up();

        // Expect power rails to be enabled in order
        await(bench.vdd18.state.enabled);
        bench.assert_power_rail_enable_summary_eq('h01, "Expected VDD18 enabled");
        await(bench.vddcore.state.enabled);
        bench.assert_power_rail_enable_summary_eq('h03, "Expected VDD18, VDDCORE enabled");
        await(bench.vddpcie.state.enabled);
        bench.assert_power_rail_enable_summary_eq('h07, "Expected VDD18, VDDCORE, VDDPCIE enabled");
        await(bench.vddt.state.enabled);
        bench.assert_power_rail_enable_summary_eq('h0f, "Expected VDD18, VDDCORE, VDDPCIE, VDDt enabled");
        await(bench.vdda15.state.enabled);
        bench.assert_power_rail_enable_summary_eq('h1f, "Expected VDD18, VDDCORE, VDDPCIE, VDDt, VDDA15 enabled");
        await(bench.vdda18.state.enabled);
        bench.assert_power_rail_enable_summary_eq('h3f, "Expected VDD18, VDDCORE, VDDPCIE, VDDt, VDDA15, VDDA18 enabled");

        // Wait for clocks to be enabled
        await(bench.clocks_enable);

        // Wait for PoR
        await(bench.sequencer.tofino_reset.pwron == 0);
        assert_set(bench.sequencer.tofino_reset.pcie, "Expected PCIe still in reset");

        // Expect the VID to become valid
        await(isValid(bench.vid));
        $display("\tVID: ", fshow(bench.vid));
        assert_eq(fromMaybe(0, bench.vid), expected_vid, "Unexpected VID");

        bench.ack_vid();
        await(bench.in_a0);

        $display("Tofino2 PCIe reset: ", fshow(bench.pcie_in_reset));
        assert_false(bench.pcie_in_reset, "Expected PCIe out of reset");

        // Wait another 50 ticks to make sure nothing triggers a delayed
        // emergency power down.
        repeat(50) await(bench.tick);
        assert_true(bench.in_a0, "Expected Tofino2 still in A0");
    endseq);

    mkTestWatchdog(2 * power_up_test_timeout(parameters));
endmodule

//
// mkPowerDownTest
//
// A test which covers the happy path when powering down a Tofino 2. The test
// starts with the sequencer in A2, quickly transitions to A0, and proceeds
// back, testing each major step as it transitions to A2. The intended outcome
// is the sequencer to dwell go from A0 -> A2 -> A0 without errors or
// exceptions.
//
module mkPowerDownTest (Empty);
    Parameters parameters = defaultValue;
    Bench bench <- mkBench(parameters);

    mkAutoFSM(seq
        assert_true(bench.in_a2, "Expected sequencer in A2");
        bench.power_up();
        bench.ack_vid();

        await(bench.in_a0);
        assert_false(bench.error_occured, "Expected no error during power up");
        bench.assert_power_rail_enable_summary_eq('h3f, "Expected all power rails enabled");

        bench.power_down();
        // Expect the VID to have become invalid.
        await(!isValid(bench.vid));
        $display("\tVID: ", fshow(bench.vid));

        // Expect resets to be asserted and clocks to be disabled.
        await(bench.pcie_in_reset || bench.package_in_reset);
        action
            assert_true(bench.package_in_reset, "Expected package in reset");
            assert_true(bench.pcie_in_reset, "Expected PCIe in reset");
            assert_true(!bench.clocks_enable, "Expected clocks disabled");
        endaction

        // Expect power rails to be disabled in reverse.
        await(!bench.vdda18.state.enabled);
        bench.assert_power_rail_enable_summary_eq('h1f, "Expected VDD18, VDDCORE, VDDPCIE, VDDt, VDDA15 enabled");
        await(!bench.vdda15.state.enabled);
        bench.assert_power_rail_enable_summary_eq('h0f, "Expected VDD18, VDDCORE, VDDPCIE, VDDt enabled");
        await(!bench.vddt.state.enabled);
        bench.assert_power_rail_enable_summary_eq('h07, "Expected VDD18, VDDCORE, VDDPCIE enabled");
        await(!bench.vddpcie.state.enabled);
        bench.assert_power_rail_enable_summary_eq('h03, "Expected VDD18, VDDCORE enabled");
        await(!bench.vddcore.state.enabled);
        bench.assert_power_rail_enable_summary_eq('h01, "Expected VDD18 enabled");
        await(!bench.vdd18.state.enabled);
        bench.assert_power_rail_enable_summary_eq('h00, "Expected no power rails enabled");

        repeat(2) await(bench.tick);
        assert_true(bench.in_a2, "Expected sequencer in A2");
    endseq);

    mkTestWatchdog(power_up_test_timeout(parameters) + power_down_test_timeout);
endmodule

//
// mkSoftwareAbortDuringPowerUpTest
//
// A test which covers a software initiated abort, by clearing the `EN` bit in
// `TOFINO_SEQ_CTRL` while the sequencer is InPowerUp. The intended outcome is
// the sequencer back in A2 and the error register set to SoftwareAbort.
//
module mkSoftwareAbortDuringPowerUpTest (Empty);
    Parameters parameters = defaultValue;
    Bench bench <- mkBench(parameters);

    mkAutoFSM(seq
        assert_true(bench.in_a2, "Expected sequencer in A2");
        bench.power_up();
        await(bench.vdd18.state.enabled);

        bench.power_down();

        await(bench.error_occured);
        await(bench.in_a2);
        bench.assert_abort(InPowerUp, AwaitVdd18PowerGood, SoftwareAbort, "Unexpected abort");
    endseq);

    mkTestWatchdog(power_up_test_timeout(parameters));
endmodule

//
// mkPowerGoodTimeoutTest
//
// A test which covers a power rail not signalling power good within the
// configured timeout period. The intended outcome is the sequencer back in A2
// and the error register set to PowerGoodTimeout.
//
module mkPowerGoodTimeoutTest (Empty);
    Parameters parameters = defaultValue;
    // Extend the EN to PG delay past timemout limit.
    parameters.vddpcie_power_good_delay = 30;
    Bench bench <- mkBench(parameters);

    mkAutoFSM(seq
        assert_true(bench.in_a2, "Expected sequencer in A2");
        bench.power_up();

        await(bench.error_occured);
        await(bench.in_a2);
        bench.assert_abort(InPowerUp, AwaitVddPCIePowerGood, PowerGoodTimeout, "Unexpected abort");
    endseq);

    mkTestWatchdog(power_up_test_timeout(parameters));
endmodule

//
// mkAckVidTimeoutTest
//
// A test which covers software not acknowledging the VDDCORE Vout has been
// adjusted to match the voltage level requested through the VID bits. This is
// intended to guard against software restarting after initiating power up but
// before adjusting VDDCORE Vout, leaving Tofino exposed to a too high voltage
// level.
//
// The intended outcome is an abort of the power up sequence and the error
// register set to AckVidTimeout.
//
module mkAckVidTimeoutTest (Empty);
    Parameters parameters = defaultValue;
    Bench bench <- mkBench(parameters);

    mkAutoFSM(seq
        assert_true(bench.in_a2, "Expected sequencer in A2");
        bench.power_up();

        await(bench.error_occured);
        await(bench.in_a2);
        bench.assert_abort(InPowerUp, AwaitVidAck, VidAckTimeout, "Unexpected abort");
    endseq);

    mkTestWatchdog(power_up_test_timeout(parameters));
endmodule

//
// mkPowerDisabledDuringPowerUpTest
//
// A test which covers a power rail previously enabled and signaling to be good
// suddenly to be disabled. This is intended to guard against a third party
// (accidentally) enabling or disabling a power rail through an alternate
// interface such as PMBus.
//
// The intended outcome is an abort of the power up sequence and the error
// register set to PowerAbort.
//
module mkPowerDisabledDuringPowerUpTest (Empty);
    Parameters parameters = defaultValue;
    Bench bench <- mkBench(parameters);

    mkAutoFSM(seq
        assert_true(bench.in_a2, "Expected sequencer in A2");
        bench.power_up();

        await(bench.vddpcie.state.good);

        // Force a shutdown of VDDCORE as if the rail was shutdown by a PMBus
        // command.
        bench.vddcore.set_enable_override(tagged Valid False);

        await(bench.error_occured);
        await(bench.in_a2);
        bench.assert_abort(InPowerUp, AwaitVddtPowerGood, PowerAbort, "Unexpected abort");
        bench.assert_power_rail_enable_summary_eq('h02, "Expected VDDCORE still enabled");
    endseq);

    mkTestWatchdog(power_up_test_timeout(parameters));
endmodule

//
// mkPowerDisabledInA0Test
//
// A test similar to `mkPowerDisabledDuringPowerUpTest`, but the change in state
// occuring while dwelling in A0. The intended outcome is the sequencer
// transitioning to A2 and the error register set to PowerAbort.
//
module mkPowerDisabledInA0Test (Empty);
    Parameters parameters = defaultValue;
    Bench bench <- mkBench(parameters);

    mkAutoFSM(seq
        assert_true(bench.in_a2, "Expected sequencer in A2");
        bench.power_up();
        bench.ack_vid();

        await(bench.in_a0);
        assert_false(bench.error_occured, "Expected no error during power up");

        bench.vddcore.set_enable_override(tagged Valid False);

        await(bench.error_occured);
        await(bench.in_a2);
        bench.assert_abort(A0, AwaitPowerDown, PowerAbort, "Unexpected abort");
        bench.assert_power_rail_enable_summary_eq('h02, "Expected VDDCORE still enabled");
    endseq);

    mkTestWatchdog(power_up_test_timeout(parameters) + power_down_test_timeout);
endmodule

//
// mkPowerFaultDuringPowerUpTest
//
// A test which covers a power rail raising its fault indicator during power up.
// The intended outcome is an abort of the power up sequence and the error
// register set to PowerFault.
//
module mkPowerFaultDuringPowerUpTest (Empty);
    Parameters parameters = defaultValue;
    Bench bench <- mkBench(parameters);

    mkAutoFSM(seq
        assert_true(bench.in_a2, "Expected sequencer in A2");
        bench.power_up();

        // Schedule a fault 10 ticks after VDDCORE has been enabled.
        await(bench.vddcore.state.enabled);
        bench.vddcore.schedule_fault(10);

        await(bench.error_occured);
        assert_power_rail_state_eq(bench.sequencer.vddcore, Aborted, "Expected VDDCORE aborted");

        await(bench.in_a2);
        bench.assert_abort(InPowerUp, AwaitVddPCIePowerGood, PowerFault, "Unexpected abort");
        bench.assert_power_rail_enable_summary_eq('h02, "Expected VDDCORE still enabled");
        assert_set(bench.sequencer.vddcore.fault, "Expected VDDCORE fault set");
    endseq);

    mkTestWatchdog(power_up_test_timeout(parameters));
endmodule

//
// mkPowerFaultInA0Test
//
// A test which covers a power rail raising its fault indicator while in A0. The
// intended outcome is a power down transition and the error register set to
// PowerFault.
//
module mkPowerFaultInA0Test (Empty);
    Parameters parameters = defaultValue;
    Bench bench <- mkBench(parameters);

    mkAutoFSM(seq
        assert_true(bench.in_a2, "Expected sequencer in A2");
        bench.power_up();
        bench.ack_vid();

        await(bench.in_a0);
        assert_false(bench.error_occured, "Expected no error during power up");

        bench.vddcore.schedule_fault(3);

        await(bench.error_occured);
        assert_power_rail_state_eq(bench.sequencer.vddcore, Aborted, "Expected VDDCORE aborted");

        await(bench.in_a2);
        bench.assert_abort(A0, AwaitPowerDown, PowerFault, "Unexpected abort");
        bench.assert_power_rail_enable_summary_eq('h02, "Expected VDDCORE still enabled");
        assert_set(bench.sequencer.vddcore.fault, "Expected VDDCORE fault set");
    endseq);

    mkTestWatchdog(
        power_up_test_timeout(parameters) +
        power_down_test_timeout +
        10);
endmodule

//
// mkVrHotDuringPowerUpTest
//
// A test which covers a power rail raising its vrhot indicator during power up.
// The intended outcome is an abort of the power up sequence and the error
// register set to PowerVrHot.
//
// Note that a voltage regulator will probably also raise its fault indicator.
// Since VR Hot is probably a more rare occurance, the error should reflect this
// appropriately.
//
module mkVrHotDuringPowerUpTest (Empty);
    Parameters parameters = defaultValue;
    Bench bench <- mkBench(parameters);

    mkAutoFSM(seq
        assert_true(bench.in_a2, "Expected sequencer in A2");
        bench.power_up();

        // Schedule a vrhot event 10 ticks after VDDCORE has been enabled.
        await(bench.vddcore.state.enabled);
        bench.vddcore.schedule_vrhot(10);

        await(bench.error_occured);
        await(bench.in_a2);
        bench.assert_abort(InPowerUp, AwaitVddPCIePowerGood, PowerVrHot, "Unexpected abort");
        bench.assert_power_rail_enable_summary_eq('h02, "Expected VDDCORE still enabled");
        assert_set(bench.sequencer.vddcore.vrhot, "Expected VDDCORE vrhot set");
    endseq);

    mkTestWatchdog(power_up_test_timeout(parameters));
endmodule

//
// mkVrHotInA0Test
//
// A test which covers a power rail raising its vrhot indicator while in A0. The
// intended outcome is a power down transition and the error register set to
// PowerVrHot.
//
// Note that a voltage regulator will probably also raise its fault indicator.
// Since VR Hot is probably a more rare occurance, the error should reflect this
// appropriately.
//
module mkVrHotInA0Test (Empty);
    Parameters parameters = defaultValue;
    Bench bench <- mkBench(parameters);

    mkAutoFSM(seq
        assert_true(bench.in_a2, "Expected sequencer in A2");
        bench.power_up();
        bench.ack_vid();

        await(bench.in_a0);
        assert_false(bench.error_occured, "Expected no error during power up");

        // Schedule a vrhot event in 3 ticks.
        bench.vddcore.schedule_vrhot(3);

        await(bench.error_occured);
        await(bench.in_a2);
        bench.assert_abort(A0, AwaitPowerDown, PowerVrHot, "Unexpected abort");
        bench.assert_power_rail_enable_summary_eq('h02, "Expected VDDCORE still enabled");
        assert_set(bench.sequencer.vddcore.vrhot, "Expected VDDCORE vrhot set");
    endseq);

    mkTestWatchdog(
        power_up_test_timeout(parameters) +
        power_down_test_timeout +
        10);
endmodule

//
// mkPCIeResetHeldOnPowerUpTest
//
// A test which covers the ability for software to keep PCIe in reset on power
// up. This would be used to inspect (and/or program) the PCIe configuration in
// EEPROM after power up, but before allowing link up.
//
// The intended outcome is for the PCIe reset signal to remain asserted after
// power up.
//
module mkPCIeResetHeldOnPowerUpTest (Empty);
    Parameters parameters = defaultValue;
    Bench bench <- mkBench(parameters);

    Reg#(Bool) pcie_reset_released <- mkReg(False);

    (* fire_when_enabled *)
    rule do_pcie_reset;
        bench.pcie_reset();
    endrule

    (* fire_when_enabled *)
    rule do_pcie_reset_monitor (!bench.pcie_in_reset);
        pcie_reset_released <= True;
    endrule

    mkAutoFSM(seq
        assert_true(bench.in_a2, "Expected sequencer in A2");
        bench.power_up();
        bench.ack_vid();

        await(bench.in_a0);
        assert_false(bench.error_occured, "Expected no error during power up");

        $display("Tofino2 PCIe reset: ", fshow(bench.pcie_in_reset));
        assert_true(bench.pcie_in_reset, "Expected PCIe still in reset");
        assert_false(
            pcie_reset_released,
            "Expected PCIe reset not released during power up");
    endseq);

    mkTestWatchdog(power_up_test_timeout(parameters));
endmodule

//
// mkPCIeResetInA0Test
//
// A test which covers the ability for the attached host to reset PCIe by
// asserting PERST. The intended outcome is for the PCIe reset signal to follow
// the state of `Tofino2Sequencer.pcie_reset()`.
//
module mkPCIeResetInA0Test (Empty);
    Parameters parameters = defaultValue;
    Bench bench <- mkBench(parameters);

    FSM pcie_reset <- mkFSM(seq
        repeat(10) bench.pcie_reset();
    endseq);

    mkAutoFSM(seq
        assert_true(bench.in_a2, "Expected sequencer in A2");
        bench.power_up();
        bench.ack_vid();

        await(bench.in_a0);
        assert_false(bench.error_occured, "Expected no error during power up");

        repeat(10) noAction;
        assert_false(bench.pcie_in_reset, "Expected PCIe not in reset");

        pcie_reset.start();
        await(bench.pcie_in_reset);
        $display("Tofino2 PCIe reset: ", fshow(bench.pcie_in_reset));

        await(!bench.pcie_in_reset);
        $display("Tofino2 PCIe reset: ", fshow(bench.pcie_in_reset));

        assert_false(bench.pcie_in_reset, "Expected PCIe not in reset");
    endseq);

    mkTestWatchdog(
        power_up_test_timeout(parameters) +
        power_down_test_timeout);
endmodule

//
// mkThermalAlertDuringPowerUpTest
//
// A test which covers a thermal alert occuring during power up. This could
// happen if the heatsink does not make sufficient contact with the Tofino die.
// The intended outcome is an abort of the power up sequence and the error
// register set to ThermalAlert.
//
module mkThermalAlertDuringPowerUpTest (Empty);
    Parameters parameters = defaultValue;
    Bench bench <- mkBench(parameters);

    mkAutoFSM(seq
        assert_true(bench.in_a2, "Expected sequencer in A2");
        bench.power_up();
        await(bench.vdd18.state.enabled);

        bench.set_thermal_alert(True);

        await(bench.error_occured);
        await(bench.in_a2);
        bench.assert_abort(InPowerUp, AwaitVdd18PowerGood, ThermalAlert, "Unexpected abort");
    endseq);

    mkTestWatchdog(power_up_test_timeout(parameters));
endmodule

//
// mkThermalAlertInA0Test
//
// A test which covers a thermal alert occuring while dwelling in A0. This could
// happen if a sudden increase in ambient air temperature occurs and the thermal
// loop can not respond fast enough. The intended outcome is a power down
// sequence and the error register set to ThermalAlert.
//
module mkThermalAlertInA0Test (Empty);
    Parameters parameters = defaultValue;
    Bench bench <- mkBench(parameters);

    mkAutoFSM(seq
        assert_true(bench.in_a2, "Expected sequencer in A2");
        bench.power_up();
        bench.ack_vid();

        await(bench.in_a0);
        assert_false(bench.error_occured, "Expected no error during power up");

        bench.set_thermal_alert(True);

        await(bench.error_occured);
        await(bench.in_a2);
        bench.assert_abort(A0, AwaitPowerDown, ThermalAlert, "Unexpected abort");
    endseq);

    mkTestWatchdog(power_up_test_timeout(parameters) + power_down_test_timeout);
endmodule

//
// mkCtrlEnUnsetAfterClearError
//
// When a fault occurs, the `EN` bit in the `CTRL` register should be ignored
// until the error is cleared. Upon clearing the error the bit should be unset
// to avoid the sequencer restarting without an explicit request to do so.
//
module mkCtrlEnNotSetAfterClearError (Empty);
    Parameters parameters = defaultValue;
    Bench bench <- mkBench(parameters);

    mkAutoFSM(seq
        assert_true(bench.in_a2, "Expected sequencer in A2");
        bench.power_up();
        assert_set(bench.sequencer.ctrl.en, "Expected CTRL.EN set");

        // The VID is not acknowledged causing a VID Ack timeout after some
        // number of ticks.
        await(bench.error_occured);
        await(bench.in_a2);
        assert_set(bench.sequencer.ctrl.en, "Expected CTRL.EN set");

        await(bench.tick);

        // Clearing the error forces the sequencer through the Init state. Wait
        // for this to complete and test the CTRL.EN bit.
        bench.clear_error();
        bench.await_sequencer_state(Init);
        bench.await_sequencer_state(A2);
        assert_not_set(bench.sequencer.ctrl.en, "Expected CTRL.EN not set");
    endseq);

    mkTestWatchdog(power_up_test_timeout(parameters) + power_down_test_timeout);
endmodule

//
// mkVddPcieDisabledOnFaultDuringPowerUpTest
//
// The voltage regulator used to implement VDDPCIE may restart the rail after a
// fault condition clears. This regulator has no way for software to analyze the
// fault state so the sequencer should disable the rail when a fault occurs to
// avoid it restarting out of sequence after the power down sequence.
//
// The intended outcome is an abort of the power up sequence, the error
// register set to PowerAbort, and the vddpcie EN pin low.
//
module mkVddPcieDisabledOnFaultDuringPowerUpTest (Empty);
    Parameters parameters = defaultValue;
    Bench bench <- mkBench(parameters);

    mkAutoFSM(seq
        assert_true(bench.in_a2, "Expected sequencer in A2");
        bench.power_up();

        await(bench.vddpcie.state.good);

        // Simulate a fault by forcing a shutdown of VDDPCIE, causing the good
        // signal to go low. This regulator does not have a seperate fault pin.
        bench.vddpcie.set_enable_override(tagged Valid False);

        await(bench.error_occured);
        assert_power_rail_state_eq(bench.sequencer.vddpcie, Aborted, "Expected VDDPCIE aborted");

        await(bench.in_a2);
        bench.assert_abort(InPowerUp, AwaitVddtPowerGood, PowerAbort, "Unexpected abort");
        bench.assert_power_rail_enable_summary_eq('h00, "Expected no power rails enabled");
    endseq);

    mkTestWatchdog(power_up_test_timeout(parameters));
endmodule

//
// mkVddPcieDisabledOnFaultInA0Test
//
// The voltage regulator used to implement VDDPCIE may restart the rail after a
// fault condition clears. This regulator has no way for software to analyze the
// fault state so the sequencer should disable the rail when a fault occurs to
// avoid it restarting out of sequence after the power down sequence.
//
// The intended outcome is an abort of the power up sequence, the error
// register set to PowerAbort, and the VDDPCIE EN pin low.
//
module mkVddPcieDisabledOnFaultInA0Test (Empty);
    Parameters parameters = defaultValue;
    Bench bench <- mkBench(parameters);

    mkAutoFSM(seq
        assert_true(bench.in_a2, "Expected sequencer in A2");
        bench.power_up();
        bench.ack_vid();

        await(bench.in_a0);
        assert_false(bench.error_occured, "Expected no error during power up");

        // Simulate a fault by forcing a shutdown of VDDPCIE, causing the good
        // signal to go low. This regulator does not have a seperate fault pin.
        bench.vddpcie.set_enable_override(tagged Valid False);

        await(bench.error_occured);
        assert_power_rail_state_eq(bench.sequencer.vddpcie, Aborted, "Expected VDDPCIE aborted");

        await(bench.in_a2);
        bench.assert_abort(A0, AwaitPowerDown, PowerAbort, "Unexpected abort");
        bench.assert_power_rail_enable_summary_eq('h00, "Expected no power rails enabled");
    endseq);

    mkTestWatchdog(power_up_test_timeout(parameters) + power_down_test_timeout);
endmodule

function Action assert_power_rail_state_eq(
        PowerRailState rail,
        PowerRail::State expected_state,
        String msg) =
    assert_eq(unpack(truncate(rail.state)), expected_state, msg);

endpackage
