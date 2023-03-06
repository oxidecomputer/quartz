package TransceiverTests;

import Assert::*;
import Connectable::*;
import GetPut::*;
import StmtFSM::*;
import Vector::*;

import IgnitionProtocol::*;
import IgnitionTestHelpers::*;
import IgnitionTransceiver::*;

import TestUtils::*;


interface LoopbackTransceiver;
    interface Get#(Message) rx;
    interface PutS#(Message) tx;
    method LinkStatus status();
    method LinkEvents events();
    method Action set_connected(Bool connected);
endinterface

module mkStartUpTest (Empty);
    LoopbackTransceiver txr <- mkLoopbackTransceiver(
        False, // Polarity not inverted
        default_disconnect_pattern,
        ten_characters_timeout);

    mkAutoFSM(
        await_receiver_locked(txr,
            False, "expected no polarity inversion detected on link"));
endmodule

module mkStartUpPolarityInvertedTest (Empty);
    LoopbackTransceiver txr <- mkLoopbackTransceiver(
        True, // Polarity inverted
        default_disconnect_pattern,
        3 * ten_characters_timeout);

    mkAutoFSM(
        await_receiver_locked(txr,
            True, "expected polarity inversion detected on link"));
endmodule

module mkReceiveHelloTest (Empty);
    LoopbackTransceiver txr <- mkLoopbackTransceiver(
        False, // Polarity not inverted
        default_disconnect_pattern,
        5 * one_hundred_characters_timeout);

    (* fire_when_enabled *)
    rule do_send_hello; // (txr.status.receiver_locked);
        txr.tx.offer(tagged Hello);
    endrule

    mkAutoFSM(seq
        await_receiver_locked(txr,
            False, "expected no polarity inversion detected on link");

        repeat(8) assert_get_eq_display(txr.rx, tagged Hello, "expected Hello");
    endseq);
endmodule

module mkRestartTest #(Bit#(20) disconnect_pattern) (Empty);
    LoopbackTransceiver txr <- mkLoopbackTransceiver(
        False, // Polarity not inverted,
        default_disconnect_pattern,
        one_hundred_characters_timeout);

    mkAutoFSM(seq
        await_receiver_locked(txr,
            False, "expected no polarity inversion detected on link");

        // Disconnect the loopback and wait for the receiver to reset.
        txr.set_connected(False);
        await(!txr.status.receiver_aligned);
        // Let the disconnect pattern go for a few characters.
        repeat(40) noAction;

        txr.set_connected(True);
        await_receiver_locked(txr,
            False, "expected no polarity inversion detected on link");
    endseq);
endmodule

module mkRestartFromIdleLowTest (Empty);
    (* hide *) Empty _test <- mkRestartTest('0);
    return _test;
endmodule

module mkRestartFromIdleHighTest (Empty);
    (* hide *) Empty _test <- mkRestartTest('1);
    return _test;
endmodule

module mkRestartFromAlmostCommaPatternTest (Empty);
    (* hide *) Empty _test <- mkRestartTest(almost_comma_disconnect_pattern);
    return _test;
endmodule

module mkLoopbackTransceiver #(
        Bool polarity_inverted,
        Bit#(20) disconnect_pattern,
        Integer n_characters_watchdog)
            (LoopbackTransceiver);
    (* hide *) Transceiver _txr <- mkTransceiver();
    Loopback loopback <-
        mkLoopback(_txr, polarity_inverted, disconnect_pattern);

    (* fire_when_enabled *)
    rule do_display_link_events (_txr.events != link_events_none);
        $display(fshow(_txr.events));
    endrule

    mkTestWatchdog((10 * n_characters_watchdog) + 10);

    interface Get rx;
        method ActionValue#(Message) get();
            _txr.to_client.deq;
            return _txr.to_client.first;
        endmethod
    endinterface

    interface PutS tx = _txr.from_client;

    method status = _txr.status;
    method events = _txr.events;

    method set_connected = loopback.set_connected;
endmodule

//
// Helpers
//

Integer ten_characters_timeout = 10;
Integer one_hundred_characters_timeout = 100;

function Stmt await_receiver_locked(
        LoopbackTransceiver txr,
        Bool expected_polarity_inverted,
        String msg) =
    seq
        action
            await(txr.status.receiver_locked);
            assert_eq(
                txr.status.polarity_inverted,
                expected_polarity_inverted,
                msg);
            $display(fshow(txr.status));
        endaction
    endseq;

endpackage
