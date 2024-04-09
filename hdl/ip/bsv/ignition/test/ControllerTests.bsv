package ControllerTests;

import Assert::*;
import ClientServer::*;
import Connectable::*;
import DefaultValue::*;
import GetPut::*;
import StmtFSM::*;

import CounterRAM::*;
import Strobe::*;
import TestUtils::*;

import BenchTransceiver::*;
import ControllerBench::*;
import IgnitionController::*;
import IgnitionControllerRegisters::*;
import IgnitionProtocol::*;
import IgnitionTestHelpers::*;

import IgnitionReceiver::*;
import IgnitionTransceiver::*;
import IgnitionTransmitter::*;

IgnitionController::Parameters parameters = defaultValue;

module mkPeriodicHelloTest (Empty);
    ControllerBench bench <-
        mkControllerBench(
            parameters,
            4 * parameters.protocol.hello_interval);
    Reg#(Bool) first_hello_interval <- mkReg(True);

    mkAutoFSM(seq
        // Reset HelloSent count.
        bench.clear_counter(0, HelloSent);
        bench.clear_counter(1, HelloSent);
        bench.clear_counter(2, HelloSent);
        bench.clear_counter(3, HelloSent);

        repeat(4) seq
            // Expect the next Hello messages ..
            bench.assert_controller_message_eq(
                0, tagged Hello,
                "expected Hello from Controller 0");
            bench.assert_controller_message_eq(
                1, tagged Hello,
                "expected Hello from Controller 1");
            bench.assert_controller_message_eq(
                2, tagged Hello,
                "expected Hello from Controller 2");
            bench.assert_controller_message_eq(
                3, tagged Hello,
                "expected Hello from Controller 3");

            // .. and test the interval between this set and the previous
            // messages.
            action
                if (first_hello_interval) begin
                    first_hello_interval <= False;
                    assert_eq(
                        bench.ticks_elapsed, 0,
                        "expected Hello messages during the first tick");
                end
                else begin
                    assert_eq(
                        bench.ticks_elapsed,
                        fromInteger(parameters.protocol.hello_interval + 1),
                        "expected the configured number of ticks between Hello messages");

                    bench.reset_ticks_elapsed();
                end
            endaction
        endseq

        bench.assert_counter_eq(
            0, HelloSent, 3,
            "expected HelloSent count of 3 for Controller 0");
        bench.assert_counter_eq(
            1, HelloSent, 3,
            "expected HelloSent count of 3 for Controller 1");
        bench.assert_counter_eq(
            2, HelloSent, 3,
            "expected HelloSent count of 3 for Controller 2");
        bench.assert_counter_eq(
            3, HelloSent, 3,
            "expected HelloSent count of 3 for Controller 3");

        bench.assert_counter_eq(
            0, HelloSent, 0,
            "expected HelloSent count to have cleared");
    endseq);
endmodule

module mkTargetPresentTest (Empty);
    ControllerBench bench <-
        mkControllerBench(
            parameters,
            5 * parameters.protocol.status_interval);

    mkDiscardTx(bench.controller);
    mkAutoFSM(seq
        // Reset StatusReceived count.
        bench.clear_counter(0, StatusReceived);
        bench.clear_counter(1, StatusReceived);
        bench.clear_counter(2, StatusReceived);
        bench.clear_counter(3, StatusReceived);

        bench.clear_counter(0, TargetPresent);
        bench.clear_counter(1, TargetPresent);
        bench.clear_counter(2, TargetPresent);
        bench.clear_counter(3, TargetPresent);

        repeat(4) seq
            bench.receive_status_message(0,
                    message_status_system_powered_on_link0_connected);
            bench.receive_status_message(1,
                    message_status_system_powered_on_link0_connected);
            bench.receive_status_message(2,
                    message_status_system_powered_on_link0_connected);
            bench.receive_status_message(3,
                    message_status_system_powered_on_link0_connected);
        endseq

        bench.assert_target_present(0, "expected Target 0 present");
        bench.assert_target_present(1, "expected Target 1 present");
        bench.assert_target_present(2, "expected Target 2 present");
        bench.assert_target_present(3, "expected Target 3 present");

        bench.assert_counter_eq(
                0, StatusReceived, 3,
                "expected StatusReceived count of 3 for Controller 0");
        bench.assert_counter_eq(
                1, StatusReceived, 3,
                "expected StatusReceived count of 3 for Controller 1");
        bench.assert_counter_eq(
                2, StatusReceived, 3,
                "expected StatusReceived count of 3 for Controller 2");
        bench.assert_counter_eq(
                3, StatusReceived, 3,
                "expected StatusReceived count of 3 for Controller 3");

        bench.assert_counter_eq(
                0, TargetPresent, 1,
                "expected TargetPresent count of 1 for Controller 0");
        bench.assert_counter_eq(
                1, TargetPresent, 1,
                "expected TargetPresent count of 1 for Controller 1");
        bench.assert_counter_eq(
                2, TargetPresent, 1,
                "expected TargetPresent count of 1 for Controller 2");
        bench.assert_counter_eq(
                3, TargetPresent, 1,
                "expected TargetPresent count of 1 for Controller 3");

        bench.assert_counter_eq(
                0, StatusReceived, 0,
                "expected StatusReceived count to have cleared");
    endseq);
endmodule

module mkTargetStateValidIfPresentTest (Empty);
    ControllerBench bench <-
        mkControllerBench(
            parameters,
            5 * parameters.protocol.status_interval);

    mkDiscardTx(bench.controller);
    mkAutoFSM(seq
        assert_controller_register_eq(
                bench.controller, 0,
                TargetSystemType, SystemType'(defaultValue),
                "Target system type set");

        // Announce the Target.
        bench.receive_status_message(0,
                message_status_system_powered_on_link0_connected);
        await(bench.controller.idle);

        assert_controller_register_eq(
                bench.controller, 0,
                TargetSystemType, IgnitionTestHelpers::target_system_type,
                "Target system type not set");

        // Let the Target time out.
        await(!bench.controller.presence_summary[0]);

        assert_controller_register_eq(
                bench.controller, 0,
                TargetSystemType, SystemType'(defaultValue),
                "Target system type set");
    endseq);
endmodule

module mkTargetLinkStatusTest (Empty);
    ControllerBench bench <-
        mkControllerBench(
            parameters,
            5 * parameters.protocol.status_interval);

    mkDiscardTx(bench.controller);
    mkAutoFSM(seq
        // Reset Target link 0 status counters.
        bench.clear_counter(0, TargetLink0ReceiverReset);
        bench.clear_counter(0, TargetLink0ReceiverAligned);
        bench.clear_counter(0, TargetLink0ReceiverLocked);
        bench.clear_counter(0, TargetLink0ReceiverPolarityInverted);

        repeat(4) seq
            bench.receive_status_message(
                    0, message_status_system_powered_on_link0_connected);
        endseq
        await(bench.controller.idle);

        assert_controller_register_eq(
                bench.controller, 0,
                TargetLink0Status,
                IgnitionControllerRegisters::LinkStatus {
                    receiver_aligned: 1,
                    receiver_locked: 1,
                    receiver_polarity_inverted: 0},
                "Target link 0 not connected");

        bench.assert_counter_eq(
                0, TargetLink0ReceiverReset, 0,
                "receiver reset count for Target link 0");
        bench.assert_counter_eq(
                0, TargetLink0ReceiverAligned, 1,
                "receiver aligned count for Target link 0");
        bench.assert_counter_eq(
                0, TargetLink0ReceiverLocked, 1,
                "receiver locked count for Target link 0");
        bench.assert_counter_eq(
                0, TargetLink0ReceiverPolarityInverted, 0,
                "receiver polarity inverted count for Target link 0");

        // Send a Status update which has link 0 disconnected, causing this to
        // be counted as a receiver reset.
        bench.receive_status_message(
                0, message_status_system_powered_on_link0_disconnected);
        await(bench.controller.idle);

        assert_controller_register_eq(
                bench.controller, 0,
                TargetLink0Status,
                IgnitionControllerRegisters::LinkStatus {
                    receiver_aligned: 0,
                    receiver_locked: 0,
                    receiver_polarity_inverted: 0},
                "Target link 0 not disconnected");

        bench.assert_counter_eq(0,
                TargetLink0ReceiverReset, 1,
                "receiver reset count for Target link 0");
        bench.assert_counter_eq(0,
                TargetLink0ReceiverAligned, 0,
                "receiver aligned count for Target link 0");
        bench.assert_counter_eq(0,
                TargetLink0ReceiverLocked, 0,
                "receiver locked count for Target link 0");
        bench.assert_counter_eq(0,
                TargetLink0ReceiverPolarityInverted, 0,
                "receiver polarity inverted count for Target link 0");
    endseq);
endmodule

module mkTargetLinkEventsTest (Empty);
    ControllerBench bench <-
        mkControllerBench(
            parameters,
            2 * parameters.protocol.status_interval);

    mkDiscardTx(bench.controller);
    mkAutoFSM(seq
        bench.clear_counter(0, TargetLink0EncodingError);
        bench.clear_counter(0, TargetLink0DecodingError);
        bench.clear_counter(0, TargetLink0OrderedSetInvalid);
        bench.clear_counter(0, TargetLink0MessageVersionInvalid);
        bench.clear_counter(0, TargetLink0MessageTypeInvalid);
        bench.clear_counter(0, TargetLink0MessageChecksumInvalid);
        bench.clear_counter(0, TargetLink1EncodingError);
        bench.clear_counter(0, TargetLink1DecodingError);
        bench.clear_counter(0, TargetLink1OrderedSetInvalid);
        bench.clear_counter(0, TargetLink1MessageVersionInvalid);
        bench.clear_counter(0, TargetLink1MessageTypeInvalid);
        bench.clear_counter(0, TargetLink1MessageChecksumInvalid);

        repeat(3) seq
            bench.receive_status_message(0, message_status_with_link0_events(
                    message_status_system_powered_on_controller0_present,
                    // Add some link events.
                    link_events_message_checksum_invalid |
                        link_events_message_version_invalid |
                        link_events_decoding_error));
            bench.await_tick();
        endseq

        // Test link 0 counters
        bench.assert_counter_eq(0,
                TargetLink0EncodingError, 0,
                "link 0 encoding error count");
        bench.assert_counter_eq(0,
                TargetLink0DecodingError, 3,
                "link 0 decoding error count");
        bench.assert_counter_eq(0,
                TargetLink0OrderedSetInvalid, 0,
                "link 0 ordered set invalid count");
        bench.assert_counter_eq(0,
                TargetLink0MessageVersionInvalid, 3,
                "link 0 message version invalid count");
        bench.assert_counter_eq(0,
                TargetLink0MessageTypeInvalid, 0,
                "link 0 message type invalid count");
        bench.assert_counter_eq(0,
                TargetLink0MessageChecksumInvalid, 3,
                "link 0 message version invalid count");

        // Test link 1 counters, to assert no accidental sharing.
        bench.assert_counter_eq(0,
                TargetLink1EncodingError, 0,
                "link 1 encoding error count");
        bench.assert_counter_eq(0,
                TargetLink1DecodingError, 0,
                "link 1 decoding error count");
        bench.assert_counter_eq(0,
                TargetLink1OrderedSetInvalid, 0,
                "link 1 ordered set invalid count");
        bench.assert_counter_eq(0,
                TargetLink1MessageVersionInvalid, 0,
                "link 1 message version invalid count");
        bench.assert_counter_eq(0,
                TargetLink1MessageTypeInvalid, 0,
                "link 1 message type invalid count");
        bench.assert_counter_eq(0,
                TargetLink1MessageChecksumInvalid, 0,
                "link 1 message version invalid count");
    endseq);
endmodule

module mkSendRequestTest #(
        SystemPowerRequest expected_request,
        String msg) (Empty);
    ControllerBench bench <-
        mkControllerBench(
            parameters,
            2 * parameters.protocol.status_interval);

    Bit#(8) expected_request_value = {extend(pack(expected_request)), 4'b0};
    Reg#(Bool) system_power_request_received <- mkReg(False);

    mkAutoFSM(seq
            bench.clear_counter(0, SystemPowerRequestSent);

            repeat(4) seq
                bench.receive_status_message(
                        0, message_status_system_powered_on_controller0_present);
            endseq
            await(bench.controller.idle);
            bench.assert_target_present(0, "expected Target present");

            bench.controller.registers.request.put(
                    RegisterRequest {
                        id: 0,
                        register: TargetSystemPowerRequestStatus,
                        op: tagged Write expected_request_value});
            await(bench.controller.idle);

            // The transmit FIFO may contain a Hello message. Discard these and
            // wait for a system power request.
            while (!system_power_request_received) action
                let e <- bench.controller.txr.tx.get;

                if (e.id == 0 &&& e.ev matches tagged Message
                        {tagged Request .actual_request}) begin
                    system_power_request_received <= True;
                    assert_eq(actual_request, expected_request, msg);
                end
            endaction

            // Wait a few cycles for the event counter to be updated and assert
            // the count.
            bench.await_tick();
            bench.assert_counter_eq(0,
                    SystemPowerRequestSent, 1,
                    "system power request sent count");
    endseq);
endmodule

module mkSendSystemPowerOffRequestTest (Empty);
    (* hide *) Empty _test <-
        mkSendRequestTest(SystemPowerOff, "expected SystemPowerOff request");
    return _test;
endmodule

module mkSendSystemPowerOnRequestTest (Empty);
    (* hide *) Empty _test <-
        mkSendRequestTest(SystemPowerOn, "expected SystemPowerOn request");
    return _test;
endmodule

module mkSendSystemPowerResetRequestTest (Empty);
    (* hide *) Empty _test <-
        mkSendRequestTest(
                SystemPowerReset,
                "expected SystemPowerReset request");
    return _test;
endmodule

module mkReceiverResetEventTest (Empty);
    ControllerBench bench <-
        mkControllerBench(
            parameters,
            parameters.protocol.status_interval);

    mkDiscardTx(bench.controller);
    mkAutoFSM(seq
        bench.clear_counter(0, ControllerReceiverReset);

        repeat(4) bench.controller.txr.rx.put(
                ReceiverEvent {
                    id: 0,
                    ev: tagged ReceiverReset});

        // Wait a few ticks for the Controller to process the events and update
        // the counter.
        repeat(3) bench.await_tick();

        bench.assert_counter_eq(0,
                ControllerReceiverReset, 3,
                "receiver reset count");
    endseq);
endmodule

module mkReadTargetStatusRegisterTest #(
        Message status_message,
        RegisterId register,
        value_t expected_value,
        String msg)
            (Empty)
                provisos (
                    Bits#(value_t, value_t_sz),
                    Add#(value_t_sz, 0, 8),
                    Eq#(value_t),
                    FShow#(value_t));
    ControllerBench bench <-
            mkControllerBench(
                parameters,
                parameters.protocol.status_interval);

    mkDiscardTx(bench.controller);
    mkAutoFSM(seq
        bench.receive_status_message(0, status_message);
        await(bench.controller.idle);
        assert_controller_register_eq(
                bench.controller, 0,
                register, expected_value,
                msg);
    endseq);
endmodule

module mkReadTargetSystemTypeRegisterTest (Empty);
    (* hide *) Empty _test <- mkReadTargetStatusRegisterTest(
            message_status_system_powered_on_link0_connected,
            TargetSystemType,
            TargetSystemType {system_type: 5},
            "target system type");

    return _test;
endmodule

module mkReadTargetSystemStatusController0PresentTest (Empty);
    (* hide *) Empty _test <- mkReadTargetStatusRegisterTest(
            message_status_with_system_status(
                message_status_none,
                system_status_controller0_present),
            TargetSystemStatus,
            TargetSystemStatus {
                controller0_detected: 1,
                controller1_detected: 0,
                system_power_enabled: 0,
                system_power_abort: 0},
            "target system status");

    return _test;
endmodule

module mkReadTargetSystemStatusController1PresentTest (Empty);
    (* hide *) Empty _test <- mkReadTargetStatusRegisterTest(
            message_status_with_system_status(
                message_status_none,
                system_status_controller1_present),
            TargetSystemStatus,
            TargetSystemStatus {
                controller0_detected: 0,
                controller1_detected: 1,
                system_power_enabled: 0,
                system_power_abort: 0},
            "target system status");

    return _test;
endmodule

module mkReadTargetSystemStatusSystemPowerEnabledTest (Empty);
    (* hide *) Empty _test <- mkReadTargetStatusRegisterTest(
            message_status_with_system_status(
                message_status_none,
                system_status_system_power_enabled),
            TargetSystemStatus,
            TargetSystemStatus {
                controller0_detected: 0,
                controller1_detected: 0,
                system_power_enabled: 1,
                system_power_abort: 0},
            "target system status");

    return _test;
endmodule

module mkReadTargetSystemStatusSystemPowerAbortTest (Empty);
    (* hide *) Empty _test <- mkReadTargetStatusRegisterTest(
            message_status_with_system_status(
                message_status_none,
                system_status_system_power_abort),
            TargetSystemStatus,
            TargetSystemStatus {
                controller0_detected: 0,
                controller1_detected: 0,
                system_power_enabled: 0,
                system_power_abort: 1},
            "target system status");

    return _test;
endmodule

module mkDiscardTx #(Controller#(n) controller) (Empty);
    (* fire_when_enabled *)
    rule do_discard_tx;
        let _ <- controller.txr.tx.get;
    endrule
endmodule

endpackage
