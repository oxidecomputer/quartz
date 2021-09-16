// Copyright 2021 Oxide Computer Company

package MetaSync;


// This block provides a Reg interface and makes a 2 deep metastability
// pipeline for input registers.
module mkMetaSync(Reg#(a_type))
    provisos (Bits#(a_type, sizea));

    Reg#(a_type) d0 <- mkRegU;
    Reg#(a_type) d1 <- mkRegU;

    rule do_sync;
        d1 <= d0;
    endrule

    method _write = d0._write;
    method _read = d1._read;

endmodule

(* synthesize *)
module mkMetaSyncTest(Empty);
    Reg#(Bit#(1)) meta <- mkMetaSync();
    Reg#(UInt#(4)) cnts <- mkReg(0);

    rule do_test;
        meta <= pack(cnts)[0];
        cnts <= cnts + 1;
    endrule
endmodule

endpackage