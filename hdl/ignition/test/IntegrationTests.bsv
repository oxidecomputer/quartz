package IntegrationTests;

import Assert::*;
import StmtFSM::*;

import TestUtils::*;

import IgnitionController::*;
import IgnitionControllerAndTargetBench::*;
import IgnitionControllerRegisters::*;
import IgnitionProtocol::*;
import IgnitionTarget::*;
import IgnitionTransceiver::*;
import IgnitionTestHelpers::*;


IgnitionProtocol::Parameters protocol_parameters =
    IgnitionProtocol::Parameters {
        version: 1,
        status_interval: 3,
        hello_interval: 3};

IgnitionControllerAndTargetBench::Parameters parameters =
    Parameters {
        controller: IgnitionController::Parameters {
            protocol: protocol_parameters},
        target: IgnitionTarget::Parameters{
            external_reset: True,
            invert_leds: False,
            mirror_link0_rx_as_link1_tx: False,
            system_type: tagged Valid target_system_type,
            button_behavior: ResetButton,
            system_power_toggle_cool_down: 2,
            system_power_fault_monitor_enable: True,
            system_power_fault_monitor_start_delay: 2,
            system_power_hotswap_controller_restart: True,
            protocol: protocol_parameters},
        invert_link_polarity: False};

module mkControllerTargetPresentTest (Empty);
    IgnitionControllerAndTargetBench bench <-
        mkIgnitionControllerAndTargetBench(
            parameters,
            10 * max(protocol_parameters.hello_interval,
                    protocol_parameters.status_interval));

    let controller_state = bench.controller.registers.controller_state;
    let target_system_status = bench.controller.registers.target_system_status;

    mkAutoFSM(seq
        action
            bench.controller_to_target.set_state(Connected);
            bench.target_to_controller.set_state(Connected);
        endaction
        par
            await_set(controller_state.target_present);
            await_set(target_system_status.controller0_detected);
        endpar

        assert_set(
            bench.target.leds[0],
            "expected Target status LED set");
        assert_set(
            bench.target.leds[1],
            "expected system power status LED set");
    endseq);
endmodule

module mkTargetRoTFaultTest (Empty);
    IgnitionControllerAndTargetBench bench <-
        mkIgnitionControllerAndTargetBench(
            parameters,
            10 * max(protocol_parameters.hello_interval,
                    protocol_parameters.status_interval));

    let controller_state = bench.controller.registers.controller_state;
    let target_system_status = bench.controller.registers.target_system_status;
    let target_system_faults = bench.controller.registers.target_system_faults;

    mkAutoFSM(seq
        action
            bench.controller_to_target.set_state(Connected);
            bench.target_to_controller.set_state(Connected);
        endaction
        par
            await_set(controller_state.target_present);
            await_set(target_system_status.controller0_detected);
        endpar

        // Assert no target system faults and set an RoT fault.
        assert_eq(
            target_system_faults,
            defaultValue,
            "expected no target system faults");
        bench.set_target_system_faults(system_faults_rot);

        // Assert the fault is observed by the Controller.
        await_set(target_system_faults.rot_fault);
        assert_set(target_system_faults.rot_fault, "expected RoT fault");

        // Resolve the RoT fault.
        bench.set_target_system_faults(system_faults_none);

        // Assert the RoT fault cleared.
        await_not_set(target_system_faults.rot_fault);
        assert_eq(
            target_system_faults,
            defaultValue,
            "expected no target system faults");
    endseq);
endmodule

module mkTargetSystemResetTest (Empty);
    IgnitionControllerAndTargetBench bench <-
        mkIgnitionControllerAndTargetBench(
            parameters,
            10 * max(protocol_parameters.hello_interval,
                    protocol_parameters.status_interval));

    let controller_state = bench.controller.registers.controller_state;
    let target_system_status = bench.controller.registers.target_system_status;
    let target_request = asReg(bench.controller.registers.target_request);
    let target_request_status = bench.controller.registers.target_request_status;

    mkAutoFSM(seq
        action
            bench.controller_to_target.set_state(Connected);
            bench.target_to_controller.set_state(Connected);
        endaction
        par
            await_set(controller_state.target_present);
            await_set(target_system_status.controller0_detected);
        endpar

        // Await Target system power on to complete.
        await(target_request_status == defaultValue);
        assert_set(
            target_system_status.system_power_enabled,
            "expected Target system power enabled");

        // Request a target system reset.
        assert_eq(target_request, defaultValue, "expected no request queued");
        target_request <= TargetRequest {pending: 1, kind: 3};

        // Await the request to be initiated on the Target.
        await(target_request == defaultValue);
        await(target_request_status != defaultValue);
        assert_set(
            target_request_status.system_reset_in_progress,
            "expected system reset in progress");
        assert_set(
            target_request_status.power_off_in_progress,
            "expected power off in progress");
        assert_not_set(
            target_system_status.system_power_enabled,
            "expected target system power off");

        // Await the system to be powering on.
        await_not_set(target_request_status.power_off_in_progress);
        assert_set(
            target_request_status.system_reset_in_progress,
            "expected system reset in progress");
        assert_set(
            target_request_status.power_on_in_progress,
            "expected power off in progress");
        assert_set(
            target_system_status.system_power_enabled,
            "expected target system power on");

        // Await the system reset request to complete.
        await(target_request_status == defaultValue);
    endseq);
endmodule

module mkTargetLinkEventsTest (Empty);
    IgnitionControllerAndTargetBench bench <-
        mkIgnitionControllerAndTargetBench(
            parameters,
            10 * max(protocol_parameters.hello_interval,
                    protocol_parameters.status_interval));

    let controller_state = bench.controller.registers.controller_state;
    let target_system_status = bench.controller.registers.target_system_status;
    let target_link0_status = bench.controller.registers.target_link0_status;
    let target_link0_events =
            asReg(bench.controller.registers.target_link0_counters.summary);
    let target_link1_events =
            asReg(bench.controller.registers.target_link1_counters.summary);

    mkAutoFSM(seq
        action
            bench.controller_to_target.set_state(Connected);
            bench.target_to_controller.set_state(Connected);
        endaction
        par
            await_set(controller_state.target_present);
            await_set(target_system_status.controller0_detected);
        endpar

        // Reset the event summary for both target links and assert no events on
        // link 0 afterwards.
        action
            target_link0_events <= unpack('1);
            target_link1_events <= unpack('1);
        endaction
        assert_eq(
            target_link0_events, unpack('0),
            "expected no events for link 0");

        // Disturb the channel between the Controller transmitter and Target
        // link 0 receiver, causing link events.
        bench.controller_to_target.set_state(Disconnected);

        // Wait for the receiver to reset due to the errors.
        await_not_set(target_link0_status.receiver_aligned);

        assert_set(
            target_link0_events.decoding_error,
            "expected decoding error on link 0");
        assert_set(
            target_link0_events.decoding_error,
            "expected ordered_set_invalid on link 0");
        assert_eq(
            target_link1_events, unpack('0),
            "expected no events for link 1");
    endseq);
endmodule

// Verify that the Controller transmitter output enable override allows the
// Controller to start transmitting Hello messages before detecting the presence
// of a Target.
module mkControllerAlwaysTransmitOverrideTest (Empty);
    IgnitionControllerAndTargetBench bench <-
        mkIgnitionControllerAndTargetBench(
            parameters,
            10 * max(protocol_parameters.hello_interval,
                    protocol_parameters.status_interval));

    let controller_state = asReg(bench.controller.registers.controller_state);
    let controller_link_status = bench.controller.registers.controller_link_status;

    mkAutoFSM(seq
        // Connect only the Controller->Target direction. This will keep the
        // Controller from transmitting because it will not detect a Target to
        // be present.
        bench.controller_to_target.set_state(Connected);

        // Set the Controller to always transmit and await for the Target to
        // detect the controller.
        controller_state <= unpack('h02);

        // Assume the Controller has started sending Hello messages. Wait for
        // the Controller to be marked present.
        await(bench.target.controller0_present);

        // Assert the Controller has still not heard from the Target.
        assert_not_set(
            controller_link_status.receiver_aligned,
            "expected receiver not aligned");
        assert_not_set(
            controller_link_status.receiver_locked,
            "expected receiver not locked");
        assert_not_set(
            controller_state.target_present,
            "expected no Target present");
    endseq);
endmodule

//
// Helpers
//

function Action await_set(one_bit_type v)
        provisos (Bits#(one_bit_type, 1)) =
    await(pack(v) == 1);

function Action await_not_set(one_bit_type v)
        provisos (Bits#(one_bit_type, 1)) =
    await(pack(v) == 0);

endpackage
