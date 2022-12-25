package PCIeEndpointControllerTests;

import Assert::*;
import StmtFSM::*;

import TestUtils::*;

import PCIeEndpointController::*;
import SidecarMainboardControllerReg::*;


// This test demonstrates host control over PERST for a downstream peripheral
// when the `override_host_reset` flag is not set in the `ctrl` register.
module mkResetHostControlTest (Empty);
    PCIeEndpointController endpoint <- mkPCIeEndpointController();
    Reg#(Bool) reset_from_host <- mkReg(True);

    let ctrl = endpoint.registers.ctrl;
    let status = endpoint.registers.status;

    (* fire_when_enabled *)
    rule do_reset;
        endpoint.pins.reset(reset_from_host);
    endrule

    mkAutoFSM(seq
        dynamicAssert(
            ctrl.override_host_reset == 0,
            "expected no software override of PERST from host");
        dynamicAssert(
            status.host_reset == 1,
            "expected host to assert PERST");
        dynamicAssert(
            endpoint.reset_peripheral(),
            "expected PCIe peripheral to be reset");

        // Deassert reset from the host and wait a cycle for the change to
        // propagate.
        reset_from_host <= False;
        noAction;

        dynamicAssert(
            status.host_reset == 0,
            "expected host not to assert PERST");
        dynamicAssert(
            !endpoint.reset_peripheral(),
            "expected PCIe peripheral to not be reset");
    endseq);

    mkTestWatchdog(20);
endmodule

// This test demonstrates software control over PERST for a downstream
// peripheral when the `override_host_reset` flag is not set in the `ctrl`
// register.
module mkResetSoftwareControlTest (Empty);
    PCIeEndpointController endpoint <- mkPCIeEndpointController();
    Reg#(Bool) reset_from_host <- mkReg(True);

    let ctrl = asReg(endpoint.registers.ctrl);
    let status = endpoint.registers.status;

    (* fire_when_enabled *)
    rule do_reset;
        endpoint.pins.reset(reset_from_host);
    endrule

    mkAutoFSM(seq
        dynamicAssert(
            ctrl.reset == 0,
            "expected reset not set by software");
        dynamicAssert(
            ctrl.override_host_reset == 0,
            "expected no software override of PERST from host");
        dynamicAssert(
            endpoint.reset_peripheral(),
            "expected PCIe peripheral to be reset by host");

        ctrl.override_host_reset <= 1;
        dynamicAssert(
            !endpoint.reset_peripheral(),
            "expected PCIe peripheral to not be reset by host");

        ctrl.reset <= 1;
        dynamicAssert(
            endpoint.reset_peripheral(),
            "expected PCIe peripheral to be reset by software");
    endseq);

    mkTestWatchdog(20);
endmodule

endpackage