package CRCTests;

import StmtFSM::*;

import SettableCRC::*;
import TestUtils::*;

import IgnitionProtocol::*;


// These tests implement the CRC results table found in
// https://www.autosar.org/fileadmin/user_upload/standards/classic/4-3/AUTOSAR_SWS_CRCLibrary.pdf,
// 7.2.1.2, p. 23.

function Action add(CRC#(8) crc, Bit#(8) v) =
    action
        $display(fshow(crc.result));
        crc.add(v);
    endaction;

(* synthesize *)
module mkPattern1Test (Empty);
    CRC#(8) crc <- mkIgnitionCRC();

    mkAutoFSM(seq
        add(crc, 'h00);
        add(crc, 'h00);
        add(crc, 'h00);
        add(crc, 'h00);
        assert_av_eq_display(crc.complete, 'h12, "CRC mismatch");
    endseq);
endmodule

(* synthesize *)
module mkPattern2Test (Empty);
    CRC#(8) crc <- mkIgnitionCRC();

    mkAutoFSM(seq
        add(crc, 'hf2);
        add(crc, 'h01);
        add(crc, 'h83);
        assert_av_eq_display(crc.complete, 'hc2, "CRC mismatch");
    endseq);
endmodule

(* synthesize *)
module mkPattern3Test (Empty);
    CRC#(8) crc <- mkIgnitionCRC();

    mkAutoFSM(seq
        add(crc, 'h0f);
        add(crc, 'haa);
        add(crc, 'h00);
        add(crc, 'h55);
        assert_av_eq_display(crc.complete, 'hc6, "CRC mismatch");
    endseq);
endmodule

(* synthesize *)
module mkPattern4Test (Empty);
    CRC#(8) crc <- mkIgnitionCRC();

    mkAutoFSM(seq
        add(crc, 'h00);
        add(crc, 'hff);
        add(crc, 'h55);
        add(crc, 'h11);
        assert_av_eq_display(crc.complete, 'h77, "CRC mismatch");
    endseq);
endmodule

(* synthesize *)
module mkPattern5Test (Empty);
    CRC#(8) crc <- mkIgnitionCRC();

    mkAutoFSM(seq
        add(crc, 'h33);
        add(crc, 'h22);
        add(crc, 'h55);
        add(crc, 'haa);
        add(crc, 'hbb);
        add(crc, 'hcc);
        add(crc, 'hdd);
        add(crc, 'hee);
        add(crc, 'hff);
        assert_av_eq_display(crc.complete, 'h11, "CRC mismatch");
    endseq);
endmodule

(* synthesize *)
module mkPattern6Test (Empty);
    CRC#(8) crc <- mkIgnitionCRC();

    mkAutoFSM(seq
        add(crc, 'h92);
        add(crc, 'h6b);
        add(crc, 'h55);
        assert_av_eq_display(crc.complete, 'h33, "CRC mismatch");
    endseq);
endmodule

(* synthesize *)
module mkPattern7Test (Empty);
    CRC#(8) crc <- mkIgnitionCRC();

    mkAutoFSM(seq
        add(crc, 'hff);
        add(crc, 'hff);
        add(crc, 'hff);
        add(crc, 'hff);
        assert_av_eq_display(crc.complete, 'h6c, "CRC mismatch");
    endseq);
endmodule

(* synthesize *)
module mkHelloTest (Empty);
    CRC#(8) crc <- mkIgnitionCRC();

    mkAutoFSM(seq
        add(crc, 'h01);
        add(crc, 'h02);
        action
            $display(fshow(crc.result));
            assert_av_eq_display(crc.complete, 'hf0, "CRC mismatch");
        endaction
    endseq);
endmodule

(* synthesize *)
module mkSystemPowerOffRequestTest (Empty);
    CRC#(8) crc <- mkIgnitionCRC();

    mkAutoFSM(seq
        add(crc, 'h01);
        add(crc, 'h03);
        add(crc, 'h01);
        assert_av_eq_display(crc.complete, 'ha3, "CRC mismatch");
    endseq);
endmodule

(* synthesize *)
module mkSystemPowerOnRequestTest (Empty);
    CRC#(8) crc <- mkIgnitionCRC();

    mkAutoFSM(seq
        add(crc, 'h01);
        add(crc, 'h03);
        add(crc, 'h02);
        assert_av_eq_display(crc.complete, 'hd2, "CRC mismatch");
    endseq);
endmodule

(* synthesize *)
module mkSystemResetRequestTest (Empty);
    CRC#(8) crc <- mkIgnitionCRC();

    mkAutoFSM(seq
        add(crc, 'h01);
        add(crc, 'h03);
        add(crc, 'h03);
        assert_av_eq_display(crc.complete, 'hfd, "CRC mismatch");
    endseq);
endmodule

endpackage
