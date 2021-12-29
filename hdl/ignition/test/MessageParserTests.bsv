package MessageParserTests;

import BuildVector::*;
import StmtFSM::*;
import Vector::*;

import TestUtils::*;
import Encoding8b10b::*;

import IgnitionProtocol::*;
import IgnitionProtocolParser::*;
import IgnitionTestHelpers::*;


module mkParserTest #(
        ValueSequence#(n) values,
        Bit#(8) crc,
        Result#(Message) expected_result,
        String msg)
            (Empty);
    MessageParser parser <- mkMessageParser();
    Reg#(MessageParserState) state <- mkReg(defaultValue);
    Reg#(ValueSequence#(n)) buffer <- mkReg(values);

    mkAutoFSM(seq
        while (!parser.done(state)) action
            let state_ <- parser.parse(state, buffer[0], crc);

            state <= state_;
            buffer <= shiftInAtN(buffer, comma);

            $display(fshow(buffer[0]), " ", fshow(value_bits(buffer[0])));
        endaction

        assert_eq(parser.result(state).Valid, expected_result, msg);
    endseq);

    mkTestWatchdog(20);
endmodule

(* synthesize *)
module mkParseIdle1Test (Empty);
    (* hide *) Empty _test <-
        mkParserTest(
            vec(comma, idle1), 'h00,
            tagged Idle1 False,
            "expected Idle1");

    return _test;
endmodule

(* synthesize *)
module mkParseIdle1PolarityInvertedTest (Empty);
    (* hide *) Empty _test <-
        mkParserTest(
            vec(comma, idle1_inverted), 'h00,
            tagged Idle1 True,
            "expected Idle1, polarity inverted");

    return _test;
endmodule

(* synthesize *)
module mkParseIdle2Test (Empty);
    (* hide *) Empty _test <-
        mkParserTest(
            vec(comma, idle2), 'h00,
            tagged Idle2 False,
            "expected Idle2");

    return _test;
endmodule

(* synthesize *)
module mkParseIdle2PolarityInvertedTest (Empty);
    (* hide *) Empty _test <-
        mkParserTest(
            vec(comma, idle2_inverted), 'h00,
            tagged Idle2 True,
            "expected Idle2, polarity inverted");

    return _test;
endmodule

(* synthesize *)
module mkParseHelloTest (Empty);
    (* hide *) Empty _test <-
        mkParserTest(
            hello_sequence, 'hf0,
            tagged Message tagged Hello,
            "expected Hello");

    return _test;
endmodule

(* synthesize *)
module mkParseSystemPowerOnRequestTest (Empty);
    (* hide *) Empty _test <-
        mkParserTest(
            mk_request_sequence(SystemPowerOn), 'hd2,
            tagged Message tagged Request SystemPowerOn,
            "expected SystemPowerOn Request");

    return _test;
endmodule

(* synthesize *)
module mkParseSystemPowerOffRequestTest (Empty);
    (* hide *) Empty _test <-
        mkParserTest(
            mk_request_sequence(SystemPowerOff), 'ha3,
            tagged Message tagged Request SystemPowerOff,
            "expected SystemPowerOff Request");

    return _test;
endmodule

(* synthesize *)
module mkParseSystemResetRequestTest (Empty);
    (* hide *) Empty _test <-
        mkParserTest(
            mk_request_sequence(SystemReset), 'hfd,
            tagged Message tagged Request SystemReset,
            "expected SystemReset Request");

    return _test;
endmodule

(* synthesize *)
module mkParseStatusTest (Empty);
    (* hide *) Empty _test <-
        mkParserTest(
            mk_status_sequence(message_status_parse_deparse), 'h00,
            tagged Message message_status_parse_deparse,
            "expected parse/deparse Status");

    return _test;
endmodule

(* synthesize *)
module mkParseVersionInvalidTest (Empty);
    (* hide *) Empty _test <-
        mkParserTest(
            invalid_version_sequence, 'h00,
            tagged Error VersionInvalid,
            "expected VersionInvalid Error");

    return _test;
endmodule

(* synthesize *)
module mkParseMessageTypeInvalidTest (Empty);
    (* hide *) Empty _test <-
        mkParserTest(
            invalid_message_type_sequence, 'h00,
            tagged Error MessageTypeInvalid,
            "expected MessageTypeInvalid Error");

    return _test;
endmodule

(* synthesize *)
module mkParseRequestInvalidTest (Empty);
    (* hide *) Empty _test <-
        mkParserTest(
            mk_request_sequence(unpack('0)), 'h00,
            tagged Error RequestInvalid,
            "expected RequestInvalid Error");

    return _test;
endmodule

(* synthesize *)
module mkParseChecksumInvalidTest (Empty);
    (* hide *) Empty _test <-
        mkParserTest(
            invalid_checksum_sequence, 'h00,
            tagged Error ChecksumInvalid,
            "expected ChecksumInvalid Error");

    return _test;
endmodule

(* synthesize *)
module mkParseOrderedSetInvalidTest (Empty);
    (* hide *) Empty _test <-
        mkParserTest(
            invalid_ordered_set_sequence, 'h00,
            tagged Error OrderedSetInvalid,
            "expected OrderedSetInvalid Error");

    return _test;
endmodule

endpackage
