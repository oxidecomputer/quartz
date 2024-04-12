package IntegrationTests;

import Assert::*;
import ClientServer::*;
import GetPut::*;
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
            tick_period: 400,
            protocol: protocol_parameters},
        target: IgnitionTarget::Parameters{
            external_reset: True,
            invert_leds: False,
            mirror_link0_rx_as_link1_tx: False,
            system_type: tagged Valid target_system_type,
            button_behavior: ResetButton,
            // It takes a bit of time for Status updates to be applied in the
            // Controller. This cool down controls how quickly the Target
            // transitions from power off to power on during a system power
            // reset and setting this too short may not give enough time to the
            // bench to assert on the system power state. A value of 2 or less
            // may produce falls negatives in the tests.
            system_power_toggle_cool_down: 3,
            system_power_fault_monitor_enable: True,
            system_power_fault_monitor_start_delay: 2,
            system_power_hotswap_controller_restart: True,
            receiver_watchdog_enable: True,
            protocol: protocol_parameters},
        invert_link_polarity: False};

module mkControllerTargetPresentTest (Empty);
    IgnitionControllerAndTargetBench bench <-
        mkIgnitionControllerAndTargetBench(
            parameters,
            10 * max(protocol_parameters.hello_interval,
                    protocol_parameters.status_interval));

    mkAutoFSM(seq
        action
            bench.controller_to_target.set_state(Connected);
            bench.target_to_controller.set_state(Connected);
        endaction
        par
            await(bench.controller.presence_summary[0]);
            await_set(bench.target.controller0_present);
        endpar

        assert_controller_register_eq(
                bench.controller, 0, TransceiverState,
                link_status_connected,
                "expected receiver aligned and locked");

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

    // let controller_state = bench.controller.registers.controller_state;
    // let target_system_status = bench.controller.registers.target_system_status;
    // let target_system_faults = bench.controller.registers.target_system_faults;

    mkAutoFSM(seq
        // action
        //     bench.controller_to_target.set_state(Connected);
        //     bench.target_to_controller.set_state(Connected);
        // endaction
        // par
        //     await_set(controller_state.target_present);
        //     await_set(target_system_status.controller0_detected);
        // endpar

        // // Assert no target system faults and set an RoT fault.
        // assert_eq(
        //     target_system_faults,
        //     defaultValue,
        //     "expected no target system faults");
        // bench.set_target_system_faults(system_faults_rot);

        // // Assert the fault is observed by the Controller.
        // await_set(target_system_faults.rot_fault);
        // assert_set(target_system_faults.rot_fault, "expected RoT fault");

        // // Resolve the RoT fault.
        // bench.set_target_system_faults(system_faults_none);

        // // Assert the RoT fault cleared.
        // await_not_set(target_system_faults.rot_fault);
        // assert_eq(
        //     target_system_faults,
        //     defaultValue,
        //     "expected no target system faults");
    endseq);
endmodule

module mkTargetSystemPowerResetTest (Empty);
    IgnitionControllerAndTargetBench bench <-
        mkIgnitionControllerAndTargetBench(
            parameters,
            10 * max(protocol_parameters.hello_interval,
                    protocol_parameters.status_interval));

    Reg#(IgnitionProtocol::SystemStatus) target_system_status <- mkReg(defaultValue);
    Reg#(IgnitionProtocol::RequestStatus) target_system_power_request_status <- mkReg(defaultValue);

    function read_controller_0_register_into(id, d) =
            read_controller_register_into(bench.controller, 0, id, asIfc(d));

    function read_controller_0_registers_while(predicate) =
        seq
            while (predicate) seq
                read_controller_0_register_into(
                        TargetSystemStatus,
                        target_system_status);
                read_controller_0_register_into(
                        TargetSystemPowerRequestStatus,
                        target_system_power_request_status);
                // Avoid a tight loop reading the registers otherwise the
                // Controller will not make progress due to this interface
                // having the highest priority.
                repeat(3) bench.await_tick();
            endseq
        endseq;

    mkAutoFSM(seq
        action
            bench.controller_to_target.set_state(Connected);
            bench.target_to_controller.set_state(Connected);
        endaction
        par
            await(bench.controller.presence_summary[0]);
            await_set(bench.target.controller0_present);
        endpar

        // Make sure all components agree Target system power is on and no
        // system power requests are in progress.
        par
            await(bench.target_system_power_on);

            read_controller_0_registers_while(
                    !target_system_status.system_power_enabled ||
                    target_system_power_request_status != request_status_none);
        endpar

        // Request a Target system power reset.
        bench.controller.registers.request.put(
                RegisterRequest {
                    op: tagged Write ({extend(pack(SystemPowerReset)), 4'b0}),
                    id: 0,
                    register: TargetSystemPowerRequestStatus});

        // Observe the request being accepted by the Target and the system
        // powering off.
        read_controller_0_registers_while(
                target_system_status.system_power_enabled ||
                target_system_power_request_status == request_status_none);

        assert_true(
                bench.target_system_power_off,
                "expected Target system power off");

        // Observe system power bening enabled and the requested completed.
        read_controller_0_registers_while(
                !target_system_status.system_power_enabled ||
                target_system_power_request_status != request_status_none);

        assert_true(
                bench.target_system_power_on,
                "expected Target system power on");
    endseq);
endmodule

module mkTargetLinkErrorEventsTest (Empty);
    IgnitionControllerAndTargetBench bench <-
        mkIgnitionControllerAndTargetBench(
            parameters,
            10 * max(protocol_parameters.hello_interval,
                    protocol_parameters.status_interval));

    Reg#(SystemStatus) target_system_status <- mkReg(defaultValue);
    Reg#(LinkStatus) target_link0_status <- mkReg(defaultValue);

    Reg#(UInt#(8)) link0_decoding_errors <- mkReg(0);
    Reg#(UInt#(8)) link1_decoding_errors <- mkReg(0);

    function read_controller_0_register_into(id, d) =
            read_controller_register_into(bench.controller, 0, id, asIfc(d));

    function read_controller_0_registers_while(predicate) =
            seq
                while(predicate) seq
                    read_controller_0_register_into(
                            TargetSystemStatus,
                            target_system_status);
                    read_controller_0_register_into(
                            TargetLink0Status,
                            target_link0_status);
                    // Avoid a tight loop reading the registers otherwise the
                    // Controller will not make progress due to this interface
                    // having the highest priority.
                    repeat(3) bench.await_tick();
                endseq
            endseq;

    function clear_controller_0_counter(id) =
            clear_controller_counter(bench.controller, 0, id);

    function assert_controller_0_counter_eq(id, expected_value, msg) =
            assert_controller_counter_eq(
                bench.controller,
                0, id,
                expected_value,
                msg);

    mkAutoFSM(seq
        action
            bench.controller_to_target.set_state(Connected);
            bench.target_to_controller.set_state(Connected);
        endaction
        // Wait for the Target to report Controller presence through a Status
        // message.
        par
            await(bench.controller.presence_summary[0]);
            read_controller_0_registers_while(
                    !target_system_status.controller0_present);
        endpar

        // Clear Target link event counters.
        clear_controller_0_counter(TargetLink0DecodingError);
        clear_controller_0_counter(TargetLink1DecodingError);

        // Disturb the channel between Controller and Target, causing link error
        // events and a receiver reset.
        bench.controller_to_target.set_state(Disconnected);

        // Wait for the Controller to have observed the Target link 0 state
        // change before reading the event counters. This implicitly proves the
        // Target receiver was reset as this will clear the link status bits.
        read_controller_0_registers_while(
                target_link0_status != link_status_disconnected);

        assert_controller_0_counter_eq(
                TargetLink0DecodingError, 2,
                "link 0 decoding errors");

        assert_controller_0_counter_eq(
                TargetLink1DecodingError, 0,
                "link 1 decoding errors");
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

    // let controller_state = asReg(bench.controller.registers.controller_state);
    // let controller_link_status = bench.controller.registers.controller_link_status;

    mkAutoFSM(seq
        // Connect only the Controller->Target direction. This will keep the
        // Controller from transmitting because it will not detect a Target to
        // be present.
        //bench.controller_to_target.set_state(Connected);

        // Set the Controller to always transmit and await for the Target to
        // detect the controller.
        //controller_state <= unpack('h02);

        // Assume the Controller has started sending Hello messages. Wait for
        // the Controller to be marked present.
        //await(bench.target.controller0_present);

        // Assert the Controller has still not heard from the Target.
        //action
            //let _controller_link_status <- controller_link_status;

            // assert_not_set(
            //     _controller_link_status.receiver_aligned,
            //     "expected receiver not aligned");
            // assert_not_set(
            //     _controller_link_status.receiver_locked,
            //     "expected receiver not locked");
        //endaction

        // assert_not_set(
        //         controller_state.target_present,
        //         "expected no Target present");
    endseq);
endmodule

// Verify that both the Controller and Target receivers are reset due to a
// locked timeout. A previous version of this test would only wait for a single
// timeout and failed to catch a case where the timeout would fire but the
// receiver did not actually reset (unsetting the locked_timeout flag in the
// process). The test now verifies repeated timeout/reset behavior.
module mkReceiversLockedTimeoutTest (Empty);
    IgnitionControllerAndTargetBench bench <-
        mkIgnitionControllerAndTargetBench(parameters, 1000);

    mkAutoFSM(seq
        // The link between Controller and Target is not connected, causing both
        // receivers never to reach locked state.

        // Reset the controller link status register, clearing any events.
        // action
        //     let _ <- bench.controller.registers.controller_link_status;
        // endaction

        par
            // repeat(4) seq
            //     await(bench.controller_receiver_locked_timeout);

            //     // Wait for the receiver reset event bit to be set in the link
            //     // status register.
            //     // action
            //     //     let link_status <-
            //     //             bench.controller.registers.controller_link_status;

            //     //     await_set(link_status.receiver_reset_event);
            //     // endaction
            // endseq

            repeat(4) await(bench.target_receiver_locked_timeout[0]);
            repeat(4) await(bench.target_receiver_locked_timeout[1]);
        endpar
    endseq);
endmodule

// Verify that once locked both the Controller and Target link 0 receivers can
// operate for multiple timeout periods without being interrupted. In additing
// this test demonstrates the receiver for Target link 1 to be reset three times
// during the test.
module mkNoLockedTimeoutIfReceiversLockedTest (Empty);
    IgnitionControllerAndTargetBench bench <-
        mkIgnitionControllerAndTargetBench(parameters, 1100);

    Reg#(int) txr_watchdog_ticks <- mkReg(0);

    (* fire_when_enabled *)
    rule do_count_txr_watchdog_ticks;
        bench.await_tick();
        txr_watchdog_ticks <= txr_watchdog_ticks + 1;
    endrule

    continuousAssert(
        !bench.controller_receiver_locked_timeout,
        "expected no Controller receiver locked timeout");

    continuousAssert(
        !bench.target_receiver_locked_timeout[0],
        "expected no receiver locked timeout for Target link 0");

    mkAutoFSM(seq
        action
            bench.controller_to_target.set_state(Connected);
            bench.target_to_controller.set_state(Connected);
        endaction

        par
            // Both the Controller and Target link 0 should go for 1000 ticks
            // without a receiver timeout.
            await(txr_watchdog_ticks > 1000);

            // Target link 1 should time out three times during this period.
            repeat(4) await(bench.target_receiver_locked_timeout[1]);
        endpar
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

function Stmt clear_controller_counter(
        Controller#(n) controller,
        ControllerId#(n) controller_id,
        CounterId counter_id) =
    seq
        controller.counters.request.put(
                CounterAddress {
                    controller: controller_id,
                    counter: counter_id});
        assert_get_any(controller.counters.response);
    endseq;

endpackage
