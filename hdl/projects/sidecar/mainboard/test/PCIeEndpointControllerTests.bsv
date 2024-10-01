package PCIeEndpointControllerTests;

import Assert::*;
import ConfigReg::*;
import Connectable::*;
import StmtFSM::*;

import Strobe::*;
import TestUtils::*;

import MockTofino2Sequencer::*;
import PCIeEndpointController::*;
import SidecarMainboardControllerReg::*;


// This test demonstrates host control over PERST for a downstream peripheral
// when the `override_host_reset` flag is not set in the `ctrl` register.
module mkResetHostControlTest (Empty);
    Tofino2Sequencer sequencer <- mkMockTofino2Sequencer();
    PCIeEndpointController endpoint <- mkPCIeEndpointController(sequencer);

    // fake strobe to speed up simulation, make 5 ticks = 1 us
    let pci_perst_tick_duration = 5;
    Strobe#(6) tick_1us <-  mkLimitStrobe(1, pci_perst_tick_duration, 0);
    mkFreeRunningStrobe(tick_1us);
    mkConnection(asIfc(tick_1us), asIfc(endpoint.tick_1us));

    Reg#(Bool) reset_from_host <- mkReg(True);

    let ctrl = endpoint.registers.ctrl;
    let status = endpoint.registers.status;

    (* fire_when_enabled *)
    rule do_reset;
        endpoint.pins.reset(reset_from_host);
    endrule

    mkAutoFSM(seq
        delay(pci_perst_tick_duration * 201); // there's a 200 us debounce
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
        delay(pci_perst_tick_duration * 201); // there's a 200 us debounce

        assert_not_set(
            status.host_reset,
            "expected host not to assert PERST");
        assert_false(
            sequencer.pins.resets.pcie,
            "expected PCIe peripheral to not be reset");
    endseq);

    mkTestWatchdog(2500);
endmodule

// This test demonstrates software control over PERST for a downstream
// peripheral when the `override_host_reset` flag is not set in the `ctrl`
// register.
module mkResetSoftwareControlTest (Empty);
    Tofino2Sequencer sequencer <- mkMockTofino2Sequencer();
    PCIeEndpointController endpoint <- mkPCIeEndpointController(sequencer);

    // fake strobe to speed up simulation, make 5 ticks = 1 us
    let pci_perst_tick_duration = 5;
    Strobe#(6) tick_1us <-  mkLimitStrobe(1, pci_perst_tick_duration, 0);
    mkFreeRunningStrobe(tick_1us);
    mkConnection(asIfc(tick_1us), asIfc(endpoint.tick_1us));

    Reg#(Bool) reset_from_host <- mkReg(True);

    let ctrl = asReg(endpoint.registers.ctrl);
    let status = endpoint.registers.status;

    (* fire_when_enabled *)
    rule do_reset;
        endpoint.pins.reset(reset_from_host);
    endrule

    mkAutoFSM(seq
        delay(pci_perst_tick_duration * 201); // there's a 200 us debounce
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

    mkTestWatchdog(1500);
endmodule

// This test demonstrates the PCIe Power Fault being set when the
// sequencer encounters an error.
module mkSequencerFaultTest (Empty);
    Tofino2Sequencer sequencer <- mkMockTofino2Sequencer();
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
    Tofino2Sequencer sequencer <- mkMockTofino2Sequencer();
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

endpackage
