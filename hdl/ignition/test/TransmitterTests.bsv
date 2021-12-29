package TransmitterTests;

import GetPut::*;
import StmtFSM::*;

import Encoding8b10b::*;
import TestUtils::*;

import IgnitionProtocol::*;
import IgnitionTestHelpers::*;
import IgnitionTransmitter::*;


function Stmt assert_idle1(Get#(Character) tx, String msg) =
    seq
        assert_character_rdn_get_display(tx, comma, msg);
        assert_character_rdp_get_display(tx, idle1, msg);
    endseq;

function Stmt assert_idle2(Get#(Character) tx, String msg) =
    seq
        assert_character_rdp_get_display(tx, comma, msg);
        assert_character_rdn_get_display(tx, idle2, msg);
    endseq;

function Stmt assert_hello(Get#(Character) tx, String msg) =
    seq
        assert_character_get_display(tx, start_of_message, msg);
        assert_character_get_display(tx, tagged D 1, msg);
        assert_character_get_display(tx, tagged D 2, msg);
        assert_character_get_display(tx, tagged D 'hf0, msg);
        assert_character_get_display(tx, end_of_message1, msg);

        // A Hello has an odd number of characters, so expect an end_of_message2
        // to align with the sequence boundary.
        assert_character_get_display(tx, end_of_message2, msg);
    endseq;

(* synthesize *)
module mkTransmitIdleTest (Empty);
    Transmitter tx <- mkTransmitter();

    mkAutoFSM(seq
        repeat(3) seq
            assert_idle1(tx.character, "expected Idle1 sequence");
            assert_idle2(tx.character, "expected Idle2 sequence");
        endseq
    endseq);

    mkTestWatchdog(20);
endmodule

(* synthesize *)
module mkTransmitIdle1HelloEndOfMessage2Idle1Test (Empty);
    Transmitter tx <- mkTransmitter();

    mkAutoFSM(seq
        par
            // Offer a Hello until the character sequence has been transmitted.
            while (!tx.message.accepted)
                tx.message.offer(tagged Hello);

            seq
                assert_idle1(tx.character, "expected Idle1 sequence");
                assert_hello(tx.character, "expected Hello sequence");

                // The link disparity is running positive after the Hello so
                // expect an Idle2.
                assert_idle2(tx.character, "expected Idle2 sequence");
            endseq
        endpar
    endseq);

    mkTestWatchdog(20);
endmodule

(* synthesize *)
module mkTransmitIdle1RequestIdle2Test (Empty);
    Transmitter tx <- mkTransmitter();

    let values = mk_request_sequence(SystemPowerOn);

    mkAutoFSM(seq
        par
            // Offer a Hello until the character sequence has been transmitted.
            while (!tx.message.accepted)
                tx.message.offer(tagged Request SystemPowerOn);

            seq
                assert_idle1(tx.character, "expected Idle1 sequence");

                // Expect the Hello character sequence.
                assert_character_get_display(tx.character, values[0], "expected start_of_message");
                assert_character_get_display(tx.character, values[1], "expected version");
                assert_character_get_display(tx.character, values[2], "expected message type");
                assert_character_get_display(tx.character, values[3], "expected SystemPowerOn");
                assert_character_get_display(tx.character, values[4], "expected checksum");
                assert_character_get_display(tx.character, values[5], "expected end_of_message1");

                // The link disparity is running negative after the Request so
                // expect an Idle1.
                assert_idle1(tx.character, "expected Idle1 sequence");
            endseq
        endpar
    endseq);

    mkTestWatchdog(20);
endmodule

(* synthesize *)
module mkTransmitIdleBetweenBackToBackHelloTest (Empty);
    Transmitter tx <- mkTransmitter();

    (* fire_when_enabled *)
    rule do_transmit_hello;
        tx.message.offer(tagged Hello);
    endrule

    mkAutoFSM(seq
        //assert_idle1(tx.character, "expected Idle1 sequence");
        assert_hello(tx.character, "expected Hello sequence");
        assert_idle1(tx.character, "expected Idle2 sequence");
        assert_hello(tx.character, "expected Hello sequence");
    endseq);
endmodule

endpackage
