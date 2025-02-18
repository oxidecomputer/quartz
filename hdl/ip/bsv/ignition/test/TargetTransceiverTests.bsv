package TargetTransceiverTests;

import Assert::*;
import BuildVector::*;
import ConfigReg::*;
import Connectable::*;
import GetPut::*;
import Probe::*;
import StmtFSM::*;
import Vector::*;

import SerialIO::*;
import Strobe::*;
import TestUtils::*;

import IgnitionProtocol::*;
import IgnitionTestHelpers::*;
import IgnitionTransceiver::*;


interface Loopback;
    interface Get#(TaggedMessage) rx;
    interface PutS#(Message) tx;
    method Vector#(2, LinkStatus) status();
    method Vector#(2, LinkEvents) events();
    method Action set_connected(LinkId link_id, Bool connected);
endinterface

module mkStartUpLink0Test (Empty);
    Loopback link <- mkLoopbackTransceiver(
        False, // Invert polarity link 0
        False, // Invert polarity link 1
        default_disconnect_pattern,
        ten_characters_timeout);

    mkAutoFSM(
        connect_and_await_receiver_locked(
            link, 0,
            False, "expected no polarity inversion detected on link"));
endmodule

module mkStartUpLink0PolarityInvertedTest (Empty);
    Loopback link <- mkLoopbackTransceiver(
        True,  // Invert polarity link 0
        False, // Invert polarity link 1
        default_disconnect_pattern,
        ten_characters_timeout);

    mkAutoFSM(
        connect_and_await_receiver_locked(
            link, 0,
            True, "expected polarity inversion detected on link"));
endmodule

module mkStartUpLink1Test (Empty);
    Loopback link <- mkLoopbackTransceiver(
        False, // Invert polarity link 0
        False, // Invert polarity link 1
        default_disconnect_pattern,
        ten_characters_timeout);

    mkAutoFSM(
        connect_and_await_receiver_locked(
            link, 1,
            False, "expected no polarity inversion detected on link"));
endmodule

module mkStartUpLink1PolarityInvertedTest (Empty);
    Loopback link <- mkLoopbackTransceiver(
        False, // Invert polarity link 0
        True,  // Invert polarity link 1
        default_disconnect_pattern,
        ten_characters_timeout);

    mkAutoFSM(
        connect_and_await_receiver_locked(
            link, 1,
            True, "expected polarity inversion detected on link"));
endmodule

module mkStartUpLink0Link1Test (Empty);
    Loopback link <- mkLoopbackTransceiver(
        False, // Invert polarity link 0
        False, // Invert polarity link 1
        default_disconnect_pattern,
        ten_characters_timeout);

    mkAutoFSM(seq
        par
            connect_and_await_receiver_locked(
                link, 0,
                False, "expected no polarity inversion detected on link 0");
            connect_and_await_receiver_locked(
                link, 1,
                False, "expected no polarity inversion detected on link 1");
        endpar
    endseq);
endmodule

module mkStartUpLink0PolarityInvertedLink1Test (Empty);
    Loopback link <- mkLoopbackTransceiver(
        True,  // Invert polarity link 0
        False, // Invert polarity link 1
        default_disconnect_pattern,
        ten_characters_timeout);

    mkAutoFSM(seq
        par
            connect_and_await_receiver_locked(
                link, 0,
                True, "expected polarity inversion detected on link 0");
            connect_and_await_receiver_locked(
                link, 1,
                False, "expected no polarity inversion detected on link 1");
        endpar
    endseq);
endmodule

module mkStartUpLink0Link1PolarityInvertedTest (Empty);
    Loopback link <- mkLoopbackTransceiver(
        False, // Invert polarity link 0
        True,  // Invert polarity link 1
        default_disconnect_pattern,
        ten_characters_timeout);

    mkAutoFSM(seq
        par
            connect_and_await_receiver_locked(
                link, 0,
                False, "expected no polarity inversion detected on link 0");
            connect_and_await_receiver_locked(
                link, 1,
                True, "expected polarity inversion detected on link 1");
        endpar
    endseq);
endmodule

module mkStartUpLink0PolarityInvertedLink1PolarityInvertedTest (Empty);
    Loopback link <- mkLoopbackTransceiver(
        True,  // Invert polarity link 0
        True,  // Invert polarity link 1
        default_disconnect_pattern,
        ten_characters_timeout);

    mkAutoFSM(seq
        par
            connect_and_await_receiver_locked(
                link, 0,
                True, "expected polarity inversion detected on link 0");
            connect_and_await_receiver_locked(
                link, 1,
                True, "expected polarity inversion detected on link 1");
        endpar
    endseq);
endmodule

module mkReceiveHelloLink0Test (Empty);
    Loopback link <- mkLoopbackTransceiver(
        False, // Invert polarity link 0
        False, // Invert polarity link 1
        default_disconnect_pattern,
        one_hundred_characters_timeout);

    (* fire_when_enabled *)
    rule do_send_hello (link.status[0].receiver_locked);
        link.tx.offer(tagged Hello);
    endrule

    mkAutoFSM(seq
        connect_and_await_receiver_locked(
            link, 0,
            False, "expected no polarity inversion detected on link 0");

        repeat(4) assert_get_eq_display(
            link.rx,
            TaggedMessage {
                sender: 0,
                message: tagged Hello},
            "expected Hello from link 0");
    endseq);
endmodule

module mkReceiveHelloLink1Test (Empty);
    Loopback link <- mkLoopbackTransceiver(
        False, // Invert polarity link 0
        False, // Invert polarity link 1
        default_disconnect_pattern,
        one_hundred_characters_timeout);

    (* fire_when_enabled *)
    rule do_send_hello (link.status[1].receiver_locked);
        link.tx.offer(tagged Hello);
    endrule

    mkAutoFSM(seq
        connect_and_await_receiver_locked(
            link, 1,
            False, "expected no polarity inversion detected on link 1");

        repeat(4) assert_get_eq_display(
            link.rx,
            TaggedMessage {
                sender: 1,
                message: tagged Hello},
            "expected Hello from link 1");
    endseq);
endmodule

module mkReceiveHelloLink0Link1Test (Empty);
    Loopback link <- mkLoopbackTransceiver(
        False, // Invert polarity link 0
        False, // Invert polarity link 1
        default_disconnect_pattern,
        one_hundred_characters_timeout);

    (* fire_when_enabled *)
    rule do_send_hello (
            link.status[0].receiver_locked &&
            link.status[1].receiver_locked);
        link.tx.offer(tagged Hello);
    endrule

    mkAutoFSM(seq
        par
            connect_and_await_receiver_locked(
                link, 0,
                False, "expected no polarity inversion detected on link 0");
            connect_and_await_receiver_locked(
                link, 1,
                False, "expected no polarity inversion detected on link 1");
        endpar

        repeat(4) seq
            assert_get_eq_display(
                link.rx,
                TaggedMessage {
                    sender: 0,
                    message: tagged Hello},
                "expected Hello from link 0");
            assert_get_eq_display(
                link.rx,
                TaggedMessage {
                    sender: 1,
                    message: tagged Hello},
                "expected Hello from link 1");
        endseq
    endseq);
endmodule

module mkRestartTest #(LinkId link_to_be_restarted) (Empty);
    Loopback txr <- mkLoopbackTransceiver(
        False, // Invert polarity link 0
        False, // Invert polarity link 1
        default_disconnect_pattern,
        one_hundred_characters_timeout);

    LinkId other_link = link_to_be_restarted + 1;
    ConfigReg#(Bool) restart_done <- mkConfigReg(False);

    mkAutoFSM(seq
        par
            seq
                connect_and_await_receiver_locked(
                    txr, link_to_be_restarted,
                    False, "expected no polarity inversion detected on link");

                // Disconnect the loopback and wait for the receiver to reset.
                txr.set_connected(link_to_be_restarted, False);
                await(!txr.status[link_to_be_restarted].receiver_aligned);
                // Let the disconnect pattern go for a few characters.
                repeat(40) noAction;

                // Connect the loopback and wait for the receiver to lock.
                connect_and_await_receiver_locked(
                    txr, link_to_be_restarted,
                    False, "expected no polarity inversion detected on link");

                // Mark the test done so the parallel sequence will complete.
                restart_done <= True;
            endseq

            seq
                connect_and_await_receiver_locked(
                    txr, other_link,
                    False, "expected no polarity inversion detected on link");

                // Assert the other link to remain locked for the duration of
                // the test.
                while (!restart_done)
                    assert_true(
                        txr.status[other_link].receiver_locked,
                        "expected receiver to remain locked");
            endseq
        endpar
    endseq);
endmodule

module mkRestartLink0FromIdleLowTest (Empty);
    (* hide *) Empty _test <- mkRestartTest(0);
    return _test;
endmodule

module mkRestartLink1FromIdleLowTest (Empty);
    (* hide *) Empty _test <- mkRestartTest(1);
    return _test;
endmodule

module mkLoopbackTransceiver #(
        Bool link0_polarity_inverted,
        Bool link1_polarity_inverted,
        Bit#(20) disconnect_pattern,
        Integer n_characters_watchdog)
            (Loopback);
    (* hide *) TargetTransceiver _txr <- mkTargetTransceiver(True);
    Vector#(2, Reg#(Bool)) connected <- replicateM(mkReg(False));

    Reg#(UInt#(5)) disconnect_bit_select <- mkReg(0);

    mkTestWatchdog((15 * n_characters_watchdog) + 10);

    (* fire_when_enabled *)
    rule do_transmit;
        let b <- _txr.to_link.get;
        let b0 = connected[0] ? b : disconnect_pattern[disconnect_bit_select];
        let b1 = connected[1] ? b : disconnect_pattern[disconnect_bit_select];

        _txr.from_link[0].put(link0_polarity_inverted ? ~b0 : b0);
        _txr.from_link[1].put(link1_polarity_inverted ? ~b1 : b1);

        // Select the next bit from the disconnect pattern.
        if (!connected[0] || !connected[1])
            disconnect_bit_select <= ((disconnect_bit_select + 1) % 20);
    endrule

    interface Get rx;
        method ActionValue#(TaggedMessage) get();
            _txr.to_client.deq;
            return _txr.to_client.first;
        endmethod
    endinterface

    interface PutS tx = _txr.from_client;

    method status = _txr.status;
    method events = _txr.events;

    method Action set_connected(LinkId link_id, Bool connected_);
        connected[link_id] <= connected_;
    endmethod
endmodule

//
// Helpers
//

Integer ten_characters_timeout = 10;
Integer one_hundred_characters_timeout = 100;

function Stmt connect_and_await_receiver_locked(
        Loopback link,
        LinkId link_id,
        Bool expected_polarity_inverted,
        String msg) =
    seq
        link.set_connected(link_id, True);
        action
            await(link.status[link_id].receiver_locked);
            assert_eq(
                link.status[link_id].polarity_inverted,
                expected_polarity_inverted,
                msg);
            $display("Link %1d: ", link_id, fshow(link.status[link_id]));
        endaction
    endseq;

endpackage
