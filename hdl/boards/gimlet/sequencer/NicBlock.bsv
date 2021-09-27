package NicBlock;


import ClientServer::*;
import Connectable::*;
import GetPut::*;

    // Chip periphery pin signal names for inputs.
    interface NicInputPinsRawSink;
        method Action pwr_cont_nic_pg0(Bit#(1) value);
        method Action pwr_cont_nic_nvrhot(Bit#(1) value);
        method Action pwr_cont_nic_cfp(Bit#(1) value);
        method Action nic_to_seq_v1p5a_pg_l(Bit#(1) value);
        method Action nic_to_seq_v1p5d_pg_l(Bit#(1) value);
        method Action nic_to_seq_v1p2_pg_l(Bit#(1) value);
        method Action nic_to_seq_v1p1_pg_l(Bit#(1) value);
        method Action pwr_cont_nic_pg1(Bit#(1) value);
    endinterface
    interface NicInputPinsRawSource;
        method Bit#(1) pwr_cont_nic_pg0;
        method Bit#(1) pwr_cont_nic_nvrhot;
        method Bit#(1) pwr_cont_nic_cfp;
        method Bit#(1) nic_to_seq_v1p5a_pg_l;
        method Bit#(1) nic_to_seq_v1p5d_pg_l;
        method Bit#(1) nic_to_seq_v1p2_pg_l;
        method Bit#(1) nic_to_seq_v1p1_pg_l;
        method Bit#(1) pwr_cont_nic_pg1;
    endinterface

    // Inputs (sink) after logical inversions normalized to active High
    interface NicInputPinsNormalizedSink;
        method Action pwr_cont_nic_pg0(Bit#(1) value);
        method Action pwr_cont_nic_nvrhot(Bit#(1) value);
        method Action pwr_cont_nic_cfp(Bit#(1) value);
        method Action nic_to_seq_v1p5a_pg(Bit#(1) value);
        method Action nic_to_seq_v1p5d_pg(Bit#(1) value);
        method Action nic_to_seq_v1p2_pg(Bit#(1) value);
        method Action nic_to_seq_v1p1_pg(Bit#(1) value);
        method Action pwr_cont_nic_pg1(Bit#(1) value);
    endinterface

    // Inputs (source) after logical inversions normalized to active High
    interface NicInputPinsNormalizedSource;
        method Bit#(1) pwr_cont_nic_pg0;
        method Bit#(1) pwr_cont_nic_nvrhot;
        method Bit#(1) pwr_cont_nic_cfp;
        method Bit#(1) nic_to_seq_v1p5a_pg;
        method Bit#(1) nic_to_seq_v1p5d_pg;
        method Bit#(1) nic_to_seq_v1p2_pg;
        method Bit#(1) nic_to_seq_v1p1_pg;
        method Bit#(1) pwr_cont_nic_pg1;
    endinterface

    instance Connectable#(NicInputPinsRawSink, NicInputPinsRawSource);
        module mkConnection#(NicInputPinsRawSink sink, NicInputPinsRawSource source) (Empty);
            mkConnection(source.pwr_cont_nic_pg0, sink.pwr_cont_nic_pg0);
            mkConnection(source.pwr_cont_nic_nvrhot, sink.pwr_cont_nic_nvrhot);
            mkConnection(source.pwr_cont_nic_cfp, sink.pwr_cont_nic_cfp);
            mkConnection(source.nic_to_seq_v1p5a_pg_l, sink.nic_to_seq_v1p5a_pg_l);
            mkConnection(source.nic_to_seq_v1p5d_pg_l, sink.nic_to_seq_v1p5d_pg_l);
            mkConnection(source.nic_to_seq_v1p2_pg_l, sink.nic_to_seq_v1p2_pg_l);
            mkConnection(source.nic_to_seq_v1p1_pg_l, sink.nic_to_seq_v1p1_pg_l);
            mkConnection(source.pwr_cont_nic_pg1, sink.pwr_cont_nic_pg1);
        endmodule
    endinstance

    instance Connectable#(NicInputPinsNormalizedSink, NicInputPinsNormalizedSource);
        module mkConnection#(NicInputPinsNormalizedSink sink, NicInputPinsNormalizedSource source) (Empty);
            mkConnection(source.pwr_cont_nic_pg0, sink.pwr_cont_nic_pg0);
            mkConnection(source.pwr_cont_nic_nvrhot, sink.pwr_cont_nic_nvrhot);
            mkConnection(source.pwr_cont_nic_cfp, sink.pwr_cont_nic_cfp);
            mkConnection(source.nic_to_seq_v1p5a_pg, sink.nic_to_seq_v1p5a_pg);
            mkConnection(source.nic_to_seq_v1p5d_pg, sink.nic_to_seq_v1p5d_pg);
            mkConnection(source.nic_to_seq_v1p2_pg, sink.nic_to_seq_v1p2_pg);
            mkConnection(source.nic_to_seq_v1p1_pg, sink.nic_to_seq_v1p1_pg);
            mkConnection(source.pwr_cont_nic_pg1, sink.pwr_cont_nic_pg1);
        endmodule
    endinstance

    interface TBTestRawNicPinsSource;
        interface Client#(Bit#(8), Bool) bfm;
        interface NicInputPinsRawSource pins;
    endinterface

    module mkTestNicRawPinsSource(TBTestRawNicPinsSource);
        Reg#(Bit#(1)) pwr_cont_nic_pg0 <- mkReg(0);
        Reg#(Bit#(1)) pwr_cont_nic_nvrhot <- mkReg(0);
        Reg#(Bit#(1)) pwr_cont_nic_cfp <- mkReg(0);
        Reg#(Bit#(1)) nic_to_seq_v1p5a_pg_l <- mkReg(0);
        Reg#(Bit#(1)) nic_to_seq_v1p5d_pg_l <- mkReg(0);
        Reg#(Bit#(1)) nic_to_seq_v1p2_pg_l <- mkReg(0);
        Reg#(Bit#(1)) nic_to_seq_v1p1_pg_l <- mkReg(0);
        Reg#(Bit#(1)) pwr_cont_nic_pg1 <- mkReg(0);


        interface NicInputPinsRawSource pins;
            method pwr_cont_nic_pg0 = pwr_cont_nic_pg0._read;
            method pwr_cont_nic_nvrhot = pwr_cont_nic_nvrhot._read;
            method pwr_cont_nic_cfp = pwr_cont_nic_cfp._read;
            method nic_to_seq_v1p5a_pg_l = nic_to_seq_v1p5a_pg_l._read;
            method nic_to_seq_v1p5d_pg_l = nic_to_seq_v1p5d_pg_l._read;
            method nic_to_seq_v1p2_pg_l = nic_to_seq_v1p2_pg_l._read;
            method nic_to_seq_v1p1_pg_l = nic_to_seq_v1p1_pg_l._read;
            method pwr_cont_nic_pg1 = pwr_cont_nic_pg1._read;
        endinterface
        interface Client bfm;
            interface Get request;
            endinterface
            interface Put response;
            endinterface
        endinterface
    endmodule

endpackage