package OneOffTests;

import Assert::*;
import ClientServer::*;
import FIFO::*;
import GetPut::*;
import StmtFSM::*;

import Decoder8b10b::*;
import Encoder8b10b::*;
import Encoding8b10b::*;
import TestUtils::*;

import IgnitionProtocol::*;
import IgnitionTestHelpers::*;


module mkSystemTypeEncodingBug (Test);
    //Deparser deparser <- mkDeparser();
    StatelessEncoder#(void) encoder <- mkStatelessEncoder();
    Reg#(Maybe#(RunningDisparity)) encoder_rd <- mkReg(tagged Valid RunningNegative);
    Decoder decoder <- mkDecoder();

    FIFO#(Value) next_value <- mkFIFO();
    Reg#(Character) c <- mkRegU();

    let target_state =
        TargetState {system_type: 3, status: status_controller_present};
    let frame = mk_status_frame(target_state);

    (* fire_when_enabled *)
    rule do_encode (encoder_rd matches tagged Valid .rd);
        encoder.request.put(
            EncodingRequest {value: next_value.first, rd: rd, tag: ?});
        encoder_rd <= tagged Invalid;
        next_value.deq();
    endrule

    (* fire_when_enabled *)
    rule do_decode (encoder_rd matches tagged Invalid);
        let response <- encoder.response.get;

        $display("%b", mk_c(character_result_bits(response.result)), ", ", fshow(response.rd_next));

        dynamicAssert(
            result_valid(response.result),
            "expected valid encoder response");

        decoder.request.put(character_result_bits(response.result));
        encoder_rd <= tagged Valid response.rd_next;
    endrule

    (* fire_when_enabled *)
    rule do_get_decoder_result;
        let result <- decoder.response.get;
        $display(fshow(result));
    endrule

    Reg#(UInt#(4)) i <- mkRegU();

    mkAutoFSM(seq
        repeat (1) next_value.enq(mk_k(28, 5));
        for (i <= 0; i < 10; i <= i + 1) next_value.enq(frame[i]);
    endseq);
endmodule

endpackage
