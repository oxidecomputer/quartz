package Tofino2SequencerTests;

// Copyright 2022 Oxide Computer Company

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


typedef 16 DelaySize;

interface Bench;
    interface PowerRailModel#(DelaySize) vdd18;
    interface PowerRailModel#(DelaySize) vddcore;
    interface PowerRailModel#(DelaySize) vddpcie;
    interface PowerRailModel#(DelaySize) vddt;
    interface PowerRailModel#(DelaySize) vdda15;
    interface PowerRailModel#(DelaySize) vdda18;
    interface Registers sequencer;

    // Convenience methods.
    method Bool tick;
    method UInt#(8) error();
    method Maybe#(Bit#(4)) vid();
    method Bool clocks_enable();
    method Action set_thermal_alert(Bool raise_alert);

    method Action power_up();
    method Action power_down();
    method Action ack_vid();
    method Action pcie_reset();

    method Bool in_a2();
    method Bool in_a0();
    method Bool package_in_reset();
    method Bool pcie_in_reset();
    method Bool error_occured();

    // Asserts
    method Action assertError(Bit#(8) expected_error, String msg);
    method Action assertPowerEnable(Bit#(8) expected_enabled, String msg);
endinterface

typedef struct {
    Integer default_power_good_delay;
    Integer vddpcie_power_good_delay;
    Bit#(3) vid;
    Tofino2Sequencer::Parameters tofino_sequencer;
} Parameters;

instance DefaultValue#(Parameters);
    defaultValue = Parameters{
        default_power_good_delay: 4,
        vddpcie_power_good_delay: 8,
        vid: 'b110,
        tofino_sequencer:
            Tofino2Sequencer::Parameters{
                power_good_timeout: defaultValue.power_good_timeout,
                power_good_to_por_delay: defaultValue.power_good_to_por_delay,
                clocks_enable_to_por_delay: defaultValue.clocks_enable_to_por_delay,
                vid_valid_delay: defaultValue.vid_valid_delay,
                vid_ack_timeout: 50,
                por_to_pcie_delay: 201}};
endinstance

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

    PowerRailModel#(DelaySize) vdd18_rail <- mkDefaultPowerRailModel("VDD18");
    PowerRailModel#(DelaySize) vddcore_rail <- mkDefaultPowerRailModel("VDDCORE");
    PowerRailModel#(DelaySize) vddpcie_rail <-
        mkPowerRailModel(
            "VDDPCIe",
            tick_1khz,
            parameters.vddpcie_power_good_delay);
    PowerRailModel#(DelaySize) vddt_rail <- mkDefaultPowerRailModel("VDDt");
    PowerRailModel#(DelaySize) vdda15_rail <- mkDefaultPowerRailModel("VDDA15");
    PowerRailModel#(DelaySize) vdda18_rail <- mkDefaultPowerRailModel("VDDA18");

    ConfigReg#(Bool) thermal_alert <- mkConfigReg(False);

    Tofino2Sequencer dut <-
        mkTofino2Sequencer(parameters.tofino_sequencer);

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

    interface PowerRailModel vdd18 = vdd18_rail;
    interface PowerRailModel vddcore = vddcore_rail;
    interface PowerRailModel vddpcie = vddpcie_rail;
    interface PowerRailModel vddt = vddt_rail;
    interface PowerRailModel vdda15 = vdda15_rail;
    interface PowerRailModel vdda18 = vdda18_rail;
    interface Registers sequencer = dut.registers;

    method Action power_up() if (dut.registers.ctrl.en == 0);
        let ctrl = dut.registers.ctrl;
        ctrl.en = 1;
        dut.registers.ctrl <= ctrl;
    endmethod

    method Action power_down() if (dut.registers.ctrl.en == 1);
        let ctrl = dut.registers.ctrl;
        ctrl.en = 0;
        dut.registers.ctrl <= ctrl;
    endmethod

    method Action ack_vid() if (dut.registers.vid.vid_valid == 1);
        let ctrl = dut.registers.ctrl;
        ctrl.ack_vid = 1;
        dut.registers.ctrl <= ctrl;
    endmethod

    method Action pcie_reset = dut.pcie_reset;

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

    method Action assertError(Bit#(8) expected_error, String msg);
        action
            Error e = unpack(truncate(pack(dut.registers.error.error)));
            $display("\tError: %d, ", dut.registers.error.error, fshow(e));
            dynamicAssert(dut.registers.error.error == expected_error, msg);
        endaction
    endmethod

    method Action assertPowerEnable(Bit#(8) expected_enable, String msg);
        action
            $display("\tPower EN: 0x%02x", pack(dut.registers.power_enable));
            dynamicAssert(
                pack(dut.registers.power_enable) == expected_enable,
                msg);
        endaction
    endmethod
endmodule

(* synthesize *)
module mkPowerUpTest (Empty);
    Parameters parameters = defaultValue;
    Bench bench <- mkBench(parameters);

    Bit#(4) expected_vid = {1, parameters.vid};

    mkAutoFSM(seq
        dynamicAssert(bench.in_a2, "Expected sequencer in A2");
        bench.assertPowerEnable('h00, "Expected no power rails enabled");
        dynamicAssert(bench.sequencer.tofino_reset.pwron == 1, "Expected package in reset");
        dynamicAssert(bench.sequencer.tofino_reset.pcie == 1, "Expected PCIe in reset");
        bench.power_up();

        // Expect power rails to be enabled in order
        await(bench.vdd18.state.enabled);
        bench.assertPowerEnable('h01, "Expected VDD18 enabled");
        await(bench.vddcore.state.enabled);
        bench.assertPowerEnable('h03, "Expected VDD18, VDDCORE enabled");
        await(bench.vddpcie.state.enabled);
        bench.assertPowerEnable('h07, "Expected VDD18, VDDCORE, VDDPCIE enabled");
        await(bench.vddt.state.enabled);
        bench.assertPowerEnable('h0f, "Expected VDD18, VDDCORE, VDDPCIE, VDDt enabled");
        await(bench.vdda15.state.enabled);
        bench.assertPowerEnable('h1f, "Expected VDD18, VDDCORE, VDDPCIE, VDDt, VDDA15 enabled");
        await(bench.vdda18.state.enabled);
        bench.assertPowerEnable('h3f, "Expected VDD18, VDDCORE, VDDPCIE, VDDt, VDDA15, VDDA18 enabled");

        // Wait for clocks to be enabled
        await(bench.clocks_enable);

        // Wait for PoR
        await(bench.sequencer.tofino_reset.pwron == 0);
        dynamicAssert(bench.sequencer.tofino_reset.pcie == 1, "Expected PCIe still in reset");

        // Expect the VID to become valid
        await(isValid(bench.vid));
        $display("\tVID: ", fshow(bench.vid));
        dynamicAssert(fromMaybe(0, bench.vid) == expected_vid, "Unexpected VID");

        bench.ack_vid();
        await(bench.in_a0);

        $display("Tofino2 PCIe reset: ", fshow(bench.pcie_in_reset));
        dynamicAssert(!bench.pcie_in_reset, "Expected PCIe out of reset");

        $display("Tofino2 in A0");

        // Wait another 100 cycles to make sure nothing triggers an emergency
        // power down.
        repeat(100) noAction;
        dynamicAssert(bench.in_a0, "Expected Tofino2 still in A0");
    endseq);

    mkTestWatchdog(500 + (4 * parameters.tofino_sequencer.por_to_pcie_delay));
endmodule

(* synthesize *)
module mkPowerDownTest (Empty);
    Parameters parameters = defaultValue;
    Bench bench <- mkBench(parameters);

    mkAutoFSM(seq
        dynamicAssert(bench.in_a2, "Expected sequencer in A2");
        bench.power_up();
        bench.ack_vid();
        await(bench.in_a0);
        dynamicAssert(!bench.error_occured, "Expected no error during power up");
        $display("Tofino2 in A0");

        bench.assertPowerEnable('h3f, "Expected all power rails enabled");
        bench.power_down();

        // Expect the VID to have become invalid.
        await(!isValid(bench.vid));
        $display("\tVID: ", fshow(bench.vid));

        // Expect resets to be asserted and clocks to be disabled.
        await(bench.pcie_in_reset || bench.package_in_reset);
        action
            dynamicAssert(bench.package_in_reset, "Expected package in reset");
            dynamicAssert(bench.pcie_in_reset, "Expected PCIe in reset");
            dynamicAssert(!bench.clocks_enable, "Expected clocks disabled");
        endaction

        // Expect power rails to be disabled in reverse.
        await(!bench.vdda18.state.enabled);
        bench.assertPowerEnable('h1f, "Expected VDD18, VDDCORE, VDDPCIE, VDDt, VDDA15 enabled");
        await(!bench.vdda15.state.enabled);
        bench.assertPowerEnable('h0f, "Expected VDD18, VDDCORE, VDDPCIE, VDDt enabled");
        await(!bench.vddt.state.enabled);
        bench.assertPowerEnable('h07, "Expected VDD18, VDDCORE, VDDPCIE enabled");
        await(!bench.vddpcie.state.enabled);
        bench.assertPowerEnable('h03, "Expected VDD18, VDDCORE enabled");
        await(!bench.vddcore.state.enabled);
        bench.assertPowerEnable('h01, "Expected VDD18 enabled");
        await(!bench.vdd18.state.enabled);
        bench.assertPowerEnable('h00, "Expected no power rails enabled");

        await(bench.tick);
        dynamicAssert(bench.in_a2, "Expected sequencer in A2");
        $display("Tofino2 in A2");
    endseq);

    mkTestWatchdog(500 + (4 * parameters.tofino_sequencer.por_to_pcie_delay));
endmodule

(* synthesize *)
module mkPowerUpAbortTest (Empty);
    Parameters parameters = defaultValue;
    Bench bench <- mkBench(parameters);

    mkAutoFSM(seq
        dynamicAssert(bench.in_a2, "Expected sequencer in A2");
        bench.power_up();
        await(bench.vdd18.state.enabled);

        bench.power_down();
        await(bench.error_occured);
        bench.assertError(5, "Expected UserAbort error");

        await(bench.in_a2);
        $display("Tofino2 power up aborted");
    endseq);
endmodule

(* synthesize *)
module mkPowerGoodTimeoutTest (Empty);
    Parameters parameters = defaultValue;
    parameters.vddpcie_power_good_delay = 12;
    Bench bench <- mkBench(parameters);

    mkAutoFSM(seq
        dynamicAssert(bench.in_a2, "Expected sequencer in A2");
        bench.power_up();

        await(bench.error_occured);
        bench.assertError(1, "Expected PowerGoodTimeout error");

        await(bench.in_a2);
        $display("Tofino2 power up aborted");
    endseq);

    mkTestWatchdog(500);
endmodule

(* synthesize *)
module mkAckVidTimeoutTest (Empty);
    Parameters parameters = defaultValue;
    Bench bench <- mkBench(parameters);

    mkAutoFSM(seq
        dynamicAssert(bench.in_a2, "Expected sequencer in A2");
        bench.power_up();

        await(!bench.in_a2);
        $display("Await AckVidTimeout");
        await(bench.error_occured);
        bench.assertError(6, "Expected AckVidTimeout error");

        await(bench.in_a2);
        $display("Tofino2 power up aborted");
    endseq);

    mkTestWatchdog(500);
endmodule

(* synthesize *)
module mkPowerDisabledDuringPowerUpTest (Empty);
    Parameters parameters = defaultValue;
    Bench bench <- mkBench(parameters);

    mkAutoFSM(seq
        dynamicAssert(bench.in_a2, "Expected sequencer in A2");
        bench.power_up();

        await(bench.vddpcie.state.good);

        // Force a shutdown of VDDCORE as if the rail was shutdown by a PMBus
        // command.
        bench.vddcore.set_enable_override(tagged Valid False);

        await(bench.error_occured);
        bench.assertError(4, "Expected PowerInvalidState error");

        await(bench.in_a2);
        $display("Tofino2 power up aborted");
    endseq);

    mkTestWatchdog(500);
endmodule

(* synthesize *)
module mkPowerDisabledInA0Test (Empty);
    Parameters parameters = defaultValue;
    Bench bench <- mkBench(parameters);

    mkAutoFSM(seq
        dynamicAssert(bench.in_a2, "Expected sequencer in A2");
        bench.power_up();
        bench.ack_vid();
        await(bench.in_a0);
        dynamicAssert(!bench.error_occured, "Expected no error during power up");
        $display("Tofino2 in A0");

        bench.vddcore.set_enable_override(tagged Valid False);

        await(bench.error_occured);
        bench.assertError(4, "Expected PowerInvalidState error");

        await(bench.in_a2);
        $display("Tofino2 powered down");
    endseq);

    mkTestWatchdog(500 + (4 * parameters.tofino_sequencer.por_to_pcie_delay));
endmodule

(* synthesize *)
module mkPowerFaultDuringPowerUpTest (Empty);
    Parameters parameters = defaultValue;
    Bench bench <- mkBench(parameters);

    mkAutoFSM(seq
        dynamicAssert(bench.in_a2, "Expected sequencer in A2");
        bench.power_up();
        // Schedule a fault 10 ticks after VDDCORE has been enabled.
        bench.vddcore.schedule_fault(10);

        await(bench.error_occured);
        bench.assertError(2, "Expected PowerFault error");

        await(bench.in_a2);
        $display("Tofino2 power up aborted");
    endseq);

    mkTestWatchdog(500);
endmodule

(* synthesize *)
module mkVrHotDuringPowerUpTest (Empty);
    Parameters parameters = defaultValue;
    Bench bench <- mkBench(parameters);

    mkAutoFSM(seq
        dynamicAssert(bench.in_a2, "Expected sequencer in A2");
        bench.power_up();
        // Schedule a vrhot event 10 ticks after VDDCORE has been enabled.
        bench.vddcore.schedule_vrhot(10);

        await(bench.error_occured);
        bench.assertError(3, "Expected PowerVrHot error");

        await(bench.in_a2);
        $display("Tofino2 power up aborted");
    endseq);

    mkTestWatchdog(500);
endmodule

(* synthesize *)
module mkPowerFaultInA0Test (Empty);
    Parameters parameters = defaultValue;
    Bench bench <- mkBench(parameters);

    mkAutoFSM(seq
        dynamicAssert(bench.in_a2, "Expected sequencer in A2");
        bench.power_up();
        bench.ack_vid();
        await(bench.in_a0);
        dynamicAssert(!bench.error_occured, "Expected no error during power up");
        $display("Tofino2 in A0");

        bench.vddcore.schedule_fault(10);

        await(bench.error_occured);
        bench.assertError(2, "Expected PowerFault");

        await(bench.in_a2);
        $display("Tofino2 powered down");
    endseq);

    mkTestWatchdog(500 + (4 * parameters.tofino_sequencer.por_to_pcie_delay));
endmodule

(* synthesize *)
module mkVrHotInA0Test (Empty);
    Parameters parameters = defaultValue;
    Bench bench <- mkBench(parameters);

    mkAutoFSM(seq
        dynamicAssert(bench.in_a2, "Expected sequencer in A2");
        bench.power_up();
        bench.ack_vid();
        await(bench.in_a0);
        dynamicAssert(!bench.error_occured, "Expected no error during power up");
        $display("Tofino2 in A0");

        bench.vddcore.schedule_vrhot(10);

        await(bench.error_occured);
        bench.assertError(3, "Expected PowerVrHot");

        await(bench.in_a2);
        $display("Tofino2 powered down");
    endseq);

    mkTestWatchdog(500 + (4 * parameters.tofino_sequencer.por_to_pcie_delay));
endmodule

(* synthesize *)
module mkPCIeResetHeldOnPowerUpTest (Empty);
    Parameters parameters = defaultValue;
    Bench bench <- mkBench(parameters);

    mkAutoFSM(seq
        dynamicAssert(bench.in_a2, "Expected sequencer in A2");
        bench.sequencer.ctrl.pcie_reset <= 1;
        bench.power_up();
        bench.ack_vid();
        await(bench.in_a0);
        dynamicAssert(!bench.error_occured, "Expected no error during power up");
        $display("Tofino2 in A0");

        $display("Tofino2 PCIe reset: ", fshow(bench.pcie_in_reset));
        dynamicAssert(bench.pcie_in_reset, "Expected PCIe still in reset");
    endseq);

    mkTestWatchdog(500 + (4 * parameters.tofino_sequencer.por_to_pcie_delay));
endmodule

(* synthesize *)
module mkPCIeResetBySoftwareInA0Test (Empty);
    Parameters parameters = defaultValue;
    Bench bench <- mkBench(parameters);

    mkAutoFSM(seq
        dynamicAssert(bench.in_a2, "Expected sequencer in A2");
        bench.power_up();
        bench.ack_vid();
        await(bench.in_a0);
        dynamicAssert(!bench.error_occured, "Expected no error during power up");
        $display("Tofino2 in A0");

        repeat(100) noAction;

        dynamicAssert(!bench.pcie_in_reset, "Expected PCIe not in reset");
        bench.sequencer.ctrl.pcie_reset <= 1;
        await(bench.pcie_in_reset);
        $display("Tofino2 PCIe reset: ", fshow(bench.pcie_in_reset));

        bench.sequencer.ctrl.pcie_reset <= 0;
        await(!bench.pcie_in_reset);
        $display("Tofino2 PCIe reset: ", fshow(bench.pcie_in_reset));

        dynamicAssert(!bench.pcie_in_reset, "Expected PCIe not in reset");
    endseq);

    mkTestWatchdog(500 + (4 * parameters.tofino_sequencer.por_to_pcie_delay));
endmodule

(* synthesize *)
module mkPCIeResetExternalInA0Test (Empty);
    Parameters parameters = defaultValue;
    Bench bench <- mkBench(parameters);

    FSM pcie_reset <- mkFSM(seq
        repeat(10) bench.pcie_reset();
    endseq);

    mkAutoFSM(seq
        dynamicAssert(bench.in_a2, "Expected sequencer in A2");
        bench.power_up();
        bench.ack_vid();
        await(bench.in_a0);
        dynamicAssert(!bench.error_occured, "Expected no error during power up");
        $display("Tofino2 in A0");

        repeat(10) noAction;
        dynamicAssert(!bench.pcie_in_reset, "Expected PCIe not in reset");

        pcie_reset.start();
        await(bench.pcie_in_reset);
        $display("Tofino2 PCIe reset: ", fshow(bench.pcie_in_reset));

        await(!bench.pcie_in_reset);
        $display("Tofino2 PCIe reset: ", fshow(bench.pcie_in_reset));

        dynamicAssert(!bench.pcie_in_reset, "Expected PCIe not in reset");
    endseq);

    mkTestWatchdog(500 + (4 * parameters.tofino_sequencer.por_to_pcie_delay));
endmodule

(* synthesize *)
module mkThermalAlertDuringPowerUpTest (Empty);
    Parameters parameters = defaultValue;
    Bench bench <- mkBench(parameters);

    mkAutoFSM(seq
        dynamicAssert(bench.in_a2, "Expected sequencer in A2");
        bench.power_up();
        await(bench.vdd18.state.enabled);

        bench.set_thermal_alert(True);

        await(bench.error_occured);
        bench.assertError(7, "Expected ThermalAlert error");

        await(bench.in_a2);
        $display("Tofino2 power up aborted");
    endseq);
endmodule

(* synthesize *)
module mkThermalAlertInA0Test (Empty);
    Parameters parameters = defaultValue;
    Bench bench <- mkBench(parameters);

    mkAutoFSM(seq
        dynamicAssert(bench.in_a2, "Expected sequencer in A2");
        bench.power_up();
        bench.ack_vid();
        await(bench.in_a0);
        dynamicAssert(!bench.error_occured, "Expected no error during power up");
        $display("Tofino2 in A0");

        bench.set_thermal_alert(True);

        await(bench.error_occured);
        bench.assertError(7, "Expected ThermalAlert error");

        await(bench.in_a2);
        $display("Tofino2 powered down");
    endseq);

    mkTestWatchdog(500 + (4 * parameters.tofino_sequencer.por_to_pcie_delay));
endmodule

endpackage