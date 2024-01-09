package BOCdr;


module sampler;

endmmodule;

interface Decision;
    method Action bit_edge(Bit#(5) value);
    method Action sample(Bool value);
    method Bool edge_match;
endinterface

module decision(Decision);
    Reg#(Vector#(5, Bit#(1))) w <- mkReg(0);
    Wire#(Bool) do_sample <- mkDWire(False);
    Wire#(Bit#(5)) cur_edges <- mkDWire(0);

    // Assume bit_edge[0] is me

    rule do_store(do_sample);
        if (cur_edges[4:1] != 0) begin
            // other blocks have edges clear the pipeline
            w <= pack(0);
        end else if (cur_edges[0] == 1) begin
            //  This is an Ccnt algo, shift only when we see an edge on this phase
            w <= shiftInAtN(4, w, 1);
    endrule

    
    interface Decision;
        method bit_edge = cur_edges._write;
        method Bool edge_match;
            return w[0] == 1;
        endmethod
    endinterface

endmodule


module mkBitSampler4 #(Strobe#(any_sz) strobe) (BitSampler#(4));
    Reg#(Vector#(5, Bit#(1))) samples <- mkRegU();
    Reg#(Vector#(5, Bit#(1))) last_samples <- mkRegU();

    



endpackage;