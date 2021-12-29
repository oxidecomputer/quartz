package ControllerTests;

import Assert::*;
import Connectable::*;
import DefaultValue::*;
import GetPut::*;
import StmtFSM::*;

import Strobe::*;
import TestUtils::*;

import BenchTransceiver::*;
import ControllerBench::*;
import IgnitionController::*;
import IgnitionControllerRegisters::*;
import IgnitionProtocol::*;
import IgnitionTestHelpers::*;


IgnitionController::Parameters parameters = defaultValue;

(* synthesize *)
module mkPeriodicHelloTest (Empty);
    ControllerBench bench <-
        mkControllerBench(
            parameters,
            4 * parameters.protocol.hello_interval);
    let controller = bench.controller;
    let rx = tpl_1(bench.link.message);

    mkAutoFSM(seq
        action
            bench.link.set_connected(True, True);
            // Reset Hello sent count.
            reset_count(controller.registers.controller_hello_sent_count);
        endaction

        action
            assert_get_eq(rx, tagged Hello, "expected Hello message");
            // Reset the ticks elapsed counter to determine the interval between
            // Hello messages.
            bench.reset_ticks_elapsed();
        endaction

        repeat(3) action // This only fires twice, still not sure why.
            // Expect the next Hello message ..
            assert_get_eq(rx, tagged Hello, "expected Hello message");

            // .. and test the interval between it and the previous message.
            // Note that the expired timer for Hello messages fires one tick
            // early, to allow for some slack between send/receive and the
            // timout on the Target side.
            assert_eq(
                bench.ticks_elapsed,
                fromInteger(parameters.protocol.hello_interval - 1),
                "expected the configured number of ticks between Hello messages");

            bench.reset_ticks_elapsed();
        endaction

        assert_count(
            controller.registers.controller_hello_sent_count, 3,
            "expected 3 Hello messages sent");
    endseq);
endmodule

(* synthesize *)
module mkTargetPresentTest (Empty);
    ControllerBench bench <-
        mkControllerBench(
            parameters,
            5 * parameters.protocol.status_interval);
    let controller = bench.controller;
    let tx = tpl_2(bench.link.message);

    mkAutoFSM(seq
        action
            bench.link.set_connected(True, True);
            reset_count(controller.registers.controller_status_received_count);
        endaction

        repeat(3) tx.put(message_status_system_powered_on_link0_connected);

        action
            await(controller.registers.controller_status.target_present == 1);
            bench.reset_ticks_elapsed();

            assert_count(
                controller.registers.controller_status_received_count, 3,
                "expected Status received count to be 3");
        endaction

        await(controller.registers.controller_status.target_present == 0);
    endseq);
endmodule

(* synthesize *)
module mkTargetStateValidIfPresentTest (Empty);
    ControllerBench bench <-
        mkControllerBench(
            parameters,
            parameters.protocol.status_interval);
    let controller = bench.controller;
    let tx = tpl_2(bench.link.message);

    // Shortcuts to registers.
    let controller_status = bench.controller.registers.controller_status;
    let target_system_type = bench.controller.registers.target_system_type;
    let target_system_status = bench.controller.registers.target_system_status;

    mkAutoFSM(seq
        bench.link.set_connected(True, True);

        action
            bench.await_tick();
            tx.put(message_status_system_powered_on_link0_connected);
        endaction

        action
            // Target presence is not yet valid after one Status message.
            bench.await_tick();
            assert_not_set(controller_status.target_present,
                "expected Target not present");
            assert_eq(
                target_system_type,
                defaultValue,
                "expected Target system type not set");
            assert_eq(
                target_system_status,
                defaultValue,
                "expected Target system status not set");
        endaction

        // Send additional Status messages.
        repeat(3) action
            bench.await_tick();
            tx.put(message_status_system_powered_on_link0_connected);
        endaction

        action
            bench.await_tick();
            assert_set(
                controller_status.target_present,
                "expected Target present");
            assert_eq(
                target_system_type.system_type,
                pack(IgnitionTestHelpers::target_system_type.id),
                "expected Target system type 5");
            assert_eq(
                target_system_status,
                unpack(extend(pack(system_status_system_power_enabled))),
                "expected (only) system power enabled bit set");
        endaction
    endseq);
endmodule

(* synthesize *)
module mkTargetLinkStatusTest (Empty);
    ControllerBench bench <-
        mkControllerBench(
            parameters,
            parameters.protocol.status_interval);
    let controller = bench.controller;
    let tx = tpl_2(bench.link.message);

    // Shortcuts to registers.
    let controller_status = bench.controller.registers.controller_status;
    let link0_status = bench.controller.registers.target_link0_status;
    let link1_status = bench.controller.registers.target_link1_status;

    mkAutoFSM(seq
        bench.link.set_connected(True, True);

        // Send Status messages.
        repeat(4) action
            bench.await_tick();
            tx.put(message_status_system_powered_on_controller0_present);
        endaction

        // Expect the Target to be present.
        action
            bench.await_tick();
            assert_set(
                controller_status.target_present,
                "expected Target present");

            // Test the Link 0 Status registers.
            assert_set(
                link0_status.receiver_aligned,
                "expected link 0 receiver aligned");
            assert_set(
                link0_status.receiver_locked,
                "expected link 0 receiver locked");
            assert_not_set(
                link0_status.polarity_inverted,
                "expected no link 0 polarity inversion");

            assert_not_eq(link0_status, link1_status,
                "expected link status registers to not be equal");
        endaction
    endseq);
endmodule

(* synthesize *)
module mkTargetLinkEventsTest (Empty);
    ControllerBench bench <-
        mkControllerBench(
            parameters,
            parameters.protocol.status_interval);
    let controller = bench.controller;
    let tx = tpl_2(bench.link.message);

    // Shortcuts to registers.
    let controller_status = bench.controller.registers.controller_status;
    let target_link0_counters = bench.controller.registers.target_link0_counters;
    let target_link1_counters = bench.controller.registers.target_link1_counters;
    let link_events =
            link_events_message_checksum_invalid |
            link_events_message_version_invalid |
            link_events_decoding_error;

    let counters_expected_not_zero =
            IgnitionControllerRegisters::LinkEvents {
                encoding_error: 0,
                decoding_error: 1,
                ordered_set_invalid: 0,
                message_version_invalid: 1,
                message_type_invalid: 0,
                message_checksum_invalid: 1};

    mkAutoFSM(seq
        action
            bench.link.set_connected(True, True);

            // Clear all Target link event counters.
            target_link0_counters.summary <= ~defaultValue;
            target_link1_counters.summary <= ~defaultValue;
        endaction

        // Send Status messages.
        repeat(4) action
            bench.await_tick();
            tx.put(message_status_with_link0_events(
                message_status_system_powered_on_controller0_present,
                link_events));
        endaction

        action
            // Test link counter summary registers.
            assert_eq(
                target_link0_counters.summary,
                counters_expected_not_zero,
                "expected summary bits set");
            assert_eq(
                target_link1_counters.summary,
                defaultValue,
                "expected summary bits unset");

            // Test the counters.
            assert_count(
                target_link0_counters.decoding_error, 3,
                "expected 3 decoding_error events");
            assert_count(
                target_link0_counters.message_version_invalid, 3,
                "expected 3 message_version_invalid events");
            assert_count(
                target_link0_counters.message_checksum_invalid, 3,
                "expected 3 message_checksum_invalid events");

            // Test a link 1 counter to make sure no accidental sharing is
            // happening.
            assert_count(
                target_link1_counters.decoding_error, 0,
                "expected no decoding_error events on link 1");
        endaction

        assert_eq(
            target_link0_counters.summary,
            defaultValue,
            "expected summary cleared");
    endseq);
endmodule

module mkSendRequestTest #(Request r, String msg) (Empty);
    ControllerBench bench <-
        mkControllerBench(
            parameters,
            2 * parameters.protocol.status_interval);

    let controller = bench.controller;
    let rx = tpl_1(bench.link.message);
    let tx = tpl_2(bench.link.message);

    mkAutoFSM(seq
        action
            bench.link.set_connected(True, True);
            reset_count(controller.registers.controller_request_sent_count);
        endaction

        // Send Status messages.
        repeat(4) action
            bench.await_tick();
            tx.put(message_status_system_powered_on_controller0_present);
        endaction

        action
            bench.await_tick();
            controller.registers.target_request <=
                TargetRequest {
                    pending: 0,
                    kind: pack(r)};
        endaction

        // The request should be sent in the next two cycles.
        assert_set(
            controller.registers.target_request.pending,
            "expected request pending");
        assert_not_set(
            controller.registers.target_request.pending,
            "expected request sent");

        assert_get_eq(rx, tagged Request r, msg);

        assert_count(
            controller.registers.controller_request_sent_count, 1,
            "expected 1 request sent");
    endseq);
endmodule

(* synthesize *)
module mkSendSystemPowerOffRequestTest (Empty);
    (* hide *) Empty _test <-
        mkSendRequestTest(SystemPowerOff, "expected SystemPowerOff Request");
    return _test;
endmodule

(* synthesize *)
module mkSendSystemPowerOnRequestTest (Empty);
    (* hide *) Empty _test <-
        mkSendRequestTest(SystemPowerOn, "expected SystemPowerOn Request");
    return _test;
endmodule

(* synthesize *)
module mkSendSystemResetRequestTest (Empty);
    (* hide *) Empty _test <-
        mkSendRequestTest(SystemReset, "expected SystemReset Request");
    return _test;
endmodule

(* synthesize *)
module mkDropHelloTest (Empty);
    ControllerBench bench <-
        mkControllerBench(
            parameters,
            parameters.protocol.status_interval);

    let controller = bench.controller;
    let tx = tpl_2(bench.link.message);

    mkAutoFSM(seq
        action
            bench.link.set_connected(True, True);
            reset_count(controller.registers.controller_message_dropped_count);
        endaction

        // Send Hello messages.
        repeat(11) action
            bench.await_tick();
            tx.put(tagged Hello);
        endaction

        bench.await_tick();
        assert_count(
            controller.registers.controller_message_dropped_count, 10,
            "expected 10 dropped messages counted");
    endseq);
endmodule

(* synthesize *)
module mkDropRequestTest (Empty);
    ControllerBench bench <-
        mkControllerBench(
            parameters,
            parameters.protocol.status_interval);

    let controller = bench.controller;
    let tx = tpl_2(bench.link.message);

    mkAutoFSM(seq
        action
            bench.link.set_connected(True, True);
            reset_count(controller.registers.controller_message_dropped_count);
        endaction

        // Send Request messages.
        repeat(11) action
            bench.await_tick();
            tx.put(tagged Request SystemReset);
        endaction

        bench.await_tick();
        assert_count(
            controller.registers.controller_message_dropped_count, 10,
            "expected 10 dropped messages counted");
    endseq);
endmodule

//
// Helpers
//

function Action reset_count(
        ActionValue#(IgnitionControllerRegisters::Counter) r) =
    action
        let _ <- r;
    endaction;

function Action assert_count(
        ActionValue#(IgnitionControllerRegisters::Counter) r,
        Bit#(8) expected_count,
        String msg) =
            assert_av_eq(r, unpack(expected_count), msg);

endpackage
