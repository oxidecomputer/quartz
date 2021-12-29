package ReceiverTests;

import Assert::*;
import Connectable::*;
import FIFO::*;
import GetPut::*;
import StmtFSM::*;
import Vector::*;

import Deserializer8b10b::*;
import Encoding8b10b::*;
import Encoding8b10bReference::*;
import Strobe::*;
import TestUtils::*;

import IgnitionProtocol::*;
import IgnitionProtocolParser::*;
import IgnitionReceiver::*;
import IgnitionTransceiver::*;


interface MockTransmitter;
    method Action transmit_character(Character c);
    method Action transmit_value(Value v);
    method Action invalid_character();
endinterface

(* synthesize *)
module mkStartUpFromIdleTest (Empty);
    MessageParser parser <- mkMessageParser();
    Receiver#(1, Message) rx <- mkReceiver(parser);
    MockTransmitter tx <- mkMockTransmitter(rx, RunningNegative, False);

    let status = rx.status[0];

    continuousAssert(
        rx.events[0] == link_events_none,
        "expected no link events during startup");

    mkAutoFSM(seq
        assert_false(status.receiver_aligned, "expected receiver not aligned");
        assert_false(status.receiver_locked, "expected receiver not locked");

        while (!status.receiver_locked) seq
            tx.transmit_value(comma);
            tx.transmit_value(idle1);
            tx.transmit_value(comma);
            tx.transmit_value(idle2);
        endseq

        assert_false(
            status.polarity_inverted,
            "expected no polarity inversion detected by receiver");
    endseq);

    mkTestWatchdog(50);
endmodule

(* synthesize *)
module mkStartUpFromIdlePolarityInvertedTest (Empty);
    MessageParser parser <- mkMessageParser();
    Receiver#(1, Message) rx <- mkReceiver(parser);
    MockTransmitter tx <- mkMockTransmitter(rx, RunningNegative, True);

    let status = rx.status[0];

    continuousAssert(
        rx.events[0] == link_events_none,
        "expected no link events during startup");

    mkAutoFSM(seq
        assert_false(status.receiver_aligned, "expected receiver not aligned");
        assert_false(status.receiver_locked, "expected receiver not locked");

        while (!status.receiver_locked) seq
            tx.transmit_value(comma);
            tx.transmit_value(idle1);
            tx.transmit_value(comma);
            tx.transmit_value(idle2);
        endseq

        assert_true(
            status.polarity_inverted,
            "expected polarity inversion detected by receiver");
    endseq);

    mkTestWatchdog(50);
endmodule

// This test attempts to capture a scenario caused by a bug in logic
// interpreting the 8B10B decoder results, which resulted in the link getting
// stuck when running on actual hardware. The sequence of events goes something
// like this:
//
// - The receiver receives a valid comma character and marks the link as aligned
// - Subsequent characters may be valid but the decoder has the wrong disparity
// - If the `character valid` history is not updated correctly no reset is
//   triggered, causing the link to get stuck
//
(* synthesize *)
module mkResetAfterInvalidCommaLikeCharacter (Empty);
    MessageParser parser <- mkMessageParser();
    Receiver#(1, Message) rx <- mkReceiver(parser);
    MockTransmitter tx <- mkMockTransmitter(rx, RunningNegative, True);

    let status = rx.status[0];

    continuousAssert(
        rx.events[0] == link_events_none,
        "expected no link events during startup");

    mkAutoFSM(seq
        assert_false(status.receiver_aligned, "expected receiver not aligned");
        assert_false(status.receiver_locked, "expected receiver not locked");

        // Something which looks like a comma with incorrect disparity.
        tx.transmit_character(mk_c('b110000_0111));

        // The following is a sequence of legal 8B10B characters as a result of
        // bit errors during link start-up.
        repeat(5) seq
            tx.transmit_character('h315);
            tx.transmit_character('h297);
            tx.transmit_character('h0ea);
            tx.transmit_character('h0e8);
        endseq

        assert_false(status.receiver_aligned, "expected receiver not aligned");
        assert_false(status.receiver_locked, "expected receiver not lockec");
    endseq);

    mkTestWatchdog(100);
endmodule

module mkMockTransmitter #(
        Receiver#(1, Message) rx,
        RunningDisparity rd_,
        Bool polarity_inverted)
            (MockTransmitter);
    Reg#(RunningDisparity) rd <- mkReg(rd_);
    Reg#(Maybe#(DeserializedCharacter)) out <- mkReg(tagged Invalid);
    Reg#(Vector#(2, Bool)) cooldown <- mkReg(replicate(False));

    Wire#(Character) in <- mkWire();

    (* fire_when_enabled *)
    rule do_transmit (!isValid(out) && !any(id, cooldown));
        let comma = (pack(in)[6:0] == 7'b1111100) || (pack(in)[6:0] == 7'b0000011);

        if (rx.status[0].receiver_aligned ||
                (!rx.status[0].receiver_aligned && comma))
            out <= tagged Valid
                DeserializedCharacter {
                    comma: comma,
                    c: in};
    endrule

    (* fire_when_enabled *)
    rule do_offer_character (out matches tagged Valid .character);
        // Invert the character bit if the link is configured inverted and the
        // receiver has not requested the bits to be inverted or vice versa.
        let invert_character =
                (polarity_inverted != rx.status[0].polarity_inverted);
        let c_ = invert_character ?
                Encoding8b10b::invert_character(character.c) :
                character.c;

        rx.character[0].offer(
            DeserializedCharacter {
                comma: character.comma,
                c: c_});
    endrule

    (* fire_when_enabled *)
    rule deq_character (isValid(out) && rx.character[0].accepted);
        out <= tagged Invalid;
        cooldown <= replicate(True);
    endrule

    (* fire_when_enabled *)
    rule do_cooldown (any(id, cooldown) && !rx.character[0].accepted);
        cooldown <= shiftInAtN(cooldown, False);
    endrule

    method Action transmit_character(Character c)
            if (!isValid(out) && !any(id, cooldown));
        in <= c;
    endmethod

    method Action transmit_value(Value v)
            if (!isValid(out) && !any(id, cooldown));
        let result = Encoding8b10bReference::encode(v, rd);

        case (result.character) matches
            tagged Invalid .*: assert_fail("invalid K");
            tagged Valid .c: begin
                rd <= result.rd;
                in <= c;
            end
        endcase
    endmethod

    method Action invalid_character() if (!isValid(out) && !any(id, cooldown));
        // Inject an invalid character into the receiver.
        in <= 0;
    endmethod
endmodule

endpackage