package PCIeEndpointControllerTests;

import Assert::*;
import ConfigReg::*;
import StmtFSM::*;

import CommonFunctions::*;
import TestUtils::*;

import PCIeEndpointController::*;
import SidecarMainboardControllerReg::*;
import Tofino2Sequencer::*;


// This test demonstrates host control over PERST for a downstream peripheral
// when the `override_host_reset` flag is not set in the `ctrl` register.
module mkResetHostControlTest (Empty);
    Tofino2Sequencer sequencer <- mkMockTofino2SequencerWithReset();
    PCIeEndpointController endpoint <- mkPCIeEndpointController(sequencer);
    Reg#(Bool) reset_from_host <- mkReg(True);

    let ctrl = endpoint.registers.ctrl;
    let status = endpoint.registers.status;

    (* fire_when_enabled *)
    rule do_reset;
        endpoint.pins.reset(reset_from_host);
    endrule

    mkAutoFSM(seq
        assert_not_set(
            ctrl.override_host_reset,
            "expected no software override of PERST from host");
        assert_set(
            status.host_reset,
            "expected host to assert PERST");
        assert_true(
            sequencer.pins.resets.pcie,
            "expected PCIe peripheral to be reset");

        // Deassert reset from the host and wait a cycle for the change to
        // propagate.
        reset_from_host <= False;
        noAction;

        assert_not_set(
            status.host_reset,
            "expected host not to assert PERST");
        assert_false(
            sequencer.pins.resets.pcie,
            "expected PCIe peripheral to not be reset");
    endseq);

    mkTestWatchdog(20);
endmodule

// This test demonstrates software control over PERST for a downstream
// peripheral when the `override_host_reset` flag is not set in the `ctrl`
// register.
module mkResetSoftwareControlTest (Empty);
    Tofino2Sequencer sequencer <- mkMockTofino2SequencerWithReset();
    PCIeEndpointController endpoint <- mkPCIeEndpointController(sequencer);
    Reg#(Bool) reset_from_host <- mkReg(True);

    let ctrl = asReg(endpoint.registers.ctrl);
    let status = endpoint.registers.status;

    (* fire_when_enabled *)
    rule do_reset;
        endpoint.pins.reset(reset_from_host);
    endrule

    mkAutoFSM(seq
        assert_not_set(
            ctrl.reset,
            "expected reset not set by software");
        assert_not_set(
            ctrl.override_host_reset,
            "expected no software override of PERST from host");
        assert_true(
            sequencer.pins.resets.pcie,
            "expected PCIe peripheral to be reset by host");

        ctrl.override_host_reset <= 1;
        assert_false(
            sequencer.pins.resets.pcie,
            "expected PCIe peripheral to not be reset by host");

        ctrl.reset <= 1;
        assert_true(
            sequencer.pins.resets.pcie,
            "expected PCIe peripheral to be reset by software");
    endseq);

    mkTestWatchdog(20);
endmodule

// This test demonstrates the PCIe Power Fault being set when the
// sequencer encounters an error.
module mkSequencerFaultTest (Empty);
    Tofino2Sequencer sequencer <- mkMockTofino2SequencerWithError();
    PCIeEndpointController endpoint <- mkPCIeEndpointController(sequencer);

    let ctrl = asReg(sequencer.registers.ctrl);
    let error = sequencer.registers.error.error;
    let status = endpoint.registers.status;

    continuousAssert(
        status.power_fault == pack(endpoint.pins.power_fault),
        "expected Status register bit to track power fault pin");

    mkAutoFSM(seq
        assert_not_set(
            status.power_fault,
            "expected Power Fault not set");

        endpoint.registers.ctrl.present <= 1;
        ctrl.en <= 1;

        await(error != 0);
        assert_set(status.power_fault, "expected Power Fault set");

        ctrl.clear_error <= 1;
        await(error == 0);
        assert_not_set(status.power_fault, "expected Power Fault not set");
    endseq);

    mkTestWatchdog(20);
endmodule

// This test demonstrates software control over PCIe Power Fault when the
// override bit is set in the control register.
module mkSequencerFaultSoftwareOverrideTest (Empty);
    Tofino2Sequencer sequencer <- mkMockTofino2SequencerWithError();
    PCIeEndpointController endpoint <- mkPCIeEndpointController(sequencer);

    let sequencer_ctrl = asReg(sequencer.registers.ctrl);
    let sequencer_error = sequencer.registers.error.error;
    let endpoint_ctrl = asReg(endpoint.registers.ctrl);
    let endpoint_status = endpoint.registers.status;

    continuousAssert(
        endpoint_status.power_fault == pack(endpoint.pins.power_fault),
        "expected Status register bit to track power fault pin");

    mkAutoFSM(seq
        assert_not_set(
            endpoint_status.power_fault,
            "expected Power Fault not set");

        // Override and set the power fault bit.
        endpoint_ctrl.present <= 1;
        endpoint_ctrl.override_seq_power_fault <= 1;
        endpoint_ctrl.power_fault <= 1;
        noAction; // Wait a cycle for state to propagate.
        assert_set(endpoint_status.power_fault, "expected Power Fault set");

        // Clear the override bit, making the power fault bit follow the
        // sequencer and clearing the power fault bit.
        endpoint_ctrl.override_seq_power_fault <= 0;
        noAction;
        assert_not_set(
            endpoint_status.power_fault,
            "expected Power Fault not set");

        // Enable the sequencer causing a fault and the power fault bit to
        // follow.
        sequencer_ctrl.en <= 1;
        await(sequencer_error != 0);
        assert_set(endpoint_status.power_fault, "expected Power Fault set");

        endpoint_ctrl.power_fault <= 0;
        noAction;
        assert_set(
            endpoint_status.power_fault,
            "expected Power Fault still set");
    endseq);

    mkTestWatchdog(20);
endmodule

module mkMockTofino2SequencerWithReset (Tofino2Sequencer);
    (* hide *) Tofino2Sequencer _mock <- mkTofino2Sequencer(defaultValue);
    PulseWire pcie_reset_request <- mkPulseWire();

    // Override the reset parts of the interface.
    _mock.pcie_reset = pcie_reset_request.send;
    _mock.pins.resets =
            Tofino2Resets {
                pwron: False,
                pcie: pcie_reset_request};

    return _mock;
endmodule

module mkMockTofino2SequencerWithError (Tofino2Sequencer);
    (* hide *) Tofino2Sequencer _mock <- mkTofino2Sequencer(defaultValue);
    ConfigReg#(TofinoSeqCtrl) ctrl <- mkConfigReg(defaultValue);
    ConfigReg#(Error) error <- mkConfigReg(None);

    RWire#(TofinoSeqCtrl) ctrl_next <- mkRWire();

    (* fire_when_enabled *)
    rule do_update_state;
        if (ctrl_next.wget matches tagged Valid .next) begin
            if (next.clear_error == 1) begin
                ctrl.en <= 0;
                error <= None;
            end else begin
                ctrl.en <= next.en;
            end

        // Fault when the sequencer is enabled.
        end else if (ctrl.en == 1 && error == None) begin
            error <= PowerFault;
        end
    endrule

    // Override control and error register behavior of the mock.
    _mock.registers.ctrl =
        (interface Reg
            method _read = ctrl;
            method _write = ctrl_next.wset;
        endinterface);

    _mock.registers.error = castToReadOnly(error);

    return _mock;
endmodule

endpackage
