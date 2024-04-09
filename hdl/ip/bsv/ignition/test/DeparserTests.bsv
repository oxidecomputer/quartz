package DeparserTests;

import StmtFSM::*;
import Vector::*;

import TestUtils::*;

import IgnitionProtocol::*;
import IgnitionProtocolDeparser::*;
import IgnitionTestHelpers::*;


module mkDeparserTest #(
        Message m,
        Bit#(8) crc,
        ValueSequence#(n)
        expected_frame,
        String msg)
            (Empty);
    Reg#(ValueSequence#(n)) buffer <- mkReg(replicate(comma));
    Reg#(State) state <- mkReg(EmitStartOfMessage);

    mkAutoFSM(seq
            while (buffer[0] == comma) action
                match {.state_, .v} = deparse(state, m, crc);

                buffer <= shiftInAtN(buffer, v);
                state <= state_;
            endaction

            $display(fshow(buffer));
            assert_eq(buffer, expected_frame, msg);
        endseq);

    mkTestWatchdog(20);
endmodule

module mkDeparseHelloTest (Empty);
    (* hide *) Empty _test <- mkDeparserTest(
        tagged Hello, 'hf0,
        hello_sequence,
        "expected Hello frame");
endmodule

module mkDeparseSystemPowerOffRequestTest (Empty);
    (* hide *) Empty _test <- mkDeparserTest(
        tagged Request SystemPowerOff, 'ha3,
        mk_request_sequence(SystemPowerOff),
        "expected SystemPowerOff Request frame");
endmodule

module mkDeparseSystemPowerOnRequestTest (Empty);
    (* hide *) Empty _test <- mkDeparserTest(
        tagged Request SystemPowerOn, 'hd2,
        mk_request_sequence(SystemPowerOn),
        "expected SystemPowerOn Request frame");
endmodule

module mkDeparseSystemPowerResetRequestTest (Empty);
    (* hide *) Empty _test <- mkDeparserTest(
        tagged Request SystemPowerReset, 'hfd,
        mk_request_sequence(SystemPowerReset),
        "expected SystemPowerReset Request frame");
endmodule

module mkDeparseStatusTest (Empty);
    (* hide *) Empty _test <- mkDeparserTest(
        message_status_parse_deparse, 'h00,
        mk_status_sequence(message_status_parse_deparse),
        "expected parse/deparse Status frame");
endmodule

endpackage
