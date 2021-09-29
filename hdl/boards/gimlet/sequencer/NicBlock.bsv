package NicBlock;


import ClientServer::*;
import Connectable::*;
import GetPut::*;
import GimletSeqFpgaRegs::*;

    // Chip periphery pin signal names for outputs
    interface NicOutputPinsRawSource;
        method Bit#(1) seq_to_nic_v1p2_enet_en;
        method Bit#(1) seq_to_nic_comb_pg;
        method Bit#(1) pwr_cont_nic_en1;
        method Bit#(1) pwr_cont_nic_en0;
        method Bit#(1) seq_to_nic_cld_rst_l;
        method Bit#(1) seq_to_nic_v1p5a_en;
        method Bit#(1) seq_to_nic_v1p5d_en;
        method Bit#(1) seq_to_nic_v1p2_en;
        method Bit#(1) seq_to_nic_v1p1_en;
        method Bit#(1) seq_to_nic_ldo_v3p3_en;
        method Bit#(1) nic_to_sp3_pwrflt_l;
    endinterface
    interface NicOutputPinsRawSink;
        method Action seq_to_nic_v1p2_enet_en(Bit#(1) value);
        method Action seq_to_nic_comb_pg(Bit#(1) value);
        method Action pwr_cont_nic_en1(Bit#(1) value);
        method Action pwr_cont_nic_en0(Bit#(1) value);
        method Action seq_to_nic_cld_rst_l(Bit#(1) value);
        method Action seq_to_nic_v1p5a_en(Bit#(1) value);
        method Action seq_to_nic_v1p5d_en(Bit#(1) value);
        method Action seq_to_nic_v1p2_en(Bit#(1) value);
        method Action seq_to_nic_v1p1_en(Bit#(1) value);
        method Action seq_to_nic_ldo_v3p3_en(Bit#(1) value);
        method Action nic_to_sp3_pwrflt_l(Bit#(1) value);
    endinterface

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


    instance Connectable#(NicInputPinsRawSource, NicInputPinsRawSink);
        module mkConnection#(NicInputPinsRawSource source, NicInputPinsRawSink sink) (Empty);
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

    instance Connectable#(NicInputPinsNormalizedSource, NicInputPinsNormalizedSink);
        module mkConnection#(NicInputPinsNormalizedSource source, NicInputPinsNormalizedSink sink) (Empty);
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

    interface NicRegs;
        // Normalized pin readbacks to registers
        method NicStatus nic_status;
        // Debug outputs from registers
        //interface NicOutputPinsRawSink dbg_out;
        //  TODO: sm control
        //  TODO: debug control
    endinterface

    interface NicRegPinInputs;  // Register input interface
        method Action nic_pins(NicStatus value);
    endinterface

    interface NicTop;
        interface NicRegs reg_if;
        interface NicInputPinsNormalizedSink syncd_pins;
    endinterface

     instance Connectable#(NicRegs, NicRegPinInputs);
        module mkConnection#(NicRegs source, NicRegPinInputs sink) (Empty);
            mkConnection(source.nic_status, sink.nic_pins);
        endmodule
    endinstance

    module mkNicBlock(NicTop);
        // Output Registers
        Reg#(Bit#(1)) seq_to_nic_v1p2_enet_en <- mkReg(0);
        Reg#(Bit#(1)) seq_to_nic_comb_pg <- mkReg(0);
        Reg#(Bit#(1)) pwr_cont_nic_en1 <- mkReg(0);
        Reg#(Bit#(1)) pwr_cont_nic_en0 <- mkReg(0);
        Reg#(Bit#(1)) seq_to_nic_cld_rst_l <- mkReg(0);
        Reg#(Bit#(1)) seq_to_nic_v1p5a_en <- mkReg(0);
        Reg#(Bit#(1)) seq_to_nic_v1p5d_en <- mkReg(0);
        Reg#(Bit#(1)) seq_to_nic_v1p2_en <- mkReg(0);
        Reg#(Bit#(1)) seq_to_nic_v1p1_en <- mkReg(0);
        Reg#(Bit#(1)) seq_to_nic_ldo_v3p3_en <- mkReg(0);
        Reg#(Bit#(1)) nic_to_sp3_pwrflt_l <- mkReg(0);

        // Comb Inputs
        Wire#(Bit#(1)) pwr_cont_nic_pg0 <- mkDWire(0);
        Wire#(Bit#(1)) pwr_cont_nic_nvrhot <- mkDWire(0);
        Wire#(Bit#(1)) pwr_cont_nic_cfp <- mkDWire(0);
        Wire#(Bit#(1)) nic_to_seq_v1p5a_pg <- mkDWire(0);
        Wire#(Bit#(1)) nic_to_seq_v1p5d_pg <- mkDWire(0);
        Wire#(Bit#(1)) nic_to_seq_v1p2_pg <- mkDWire(0);
        Wire#(Bit#(1)) nic_to_seq_v1p1_pg <- mkDWire(0);
        Wire#(Bit#(1)) pwr_cont_nic_pg1 <- mkDWire(0);

        // Comb Outputs
        Wire#(NicStatus) cur_nic_status <- mkDWire(unpack(0));


        // Put all of the inputs into a NicStatus struct.
        // This is not registered but pushed over to the register block.
        rule do_nic_status;
            cur_nic_status <= NicStatus {
                nic_cfp: pwr_cont_nic_cfp,
                nic_nvrhot: pwr_cont_nic_nvrhot,
                nic_v1p8_pg: pwr_cont_nic_pg1,
                nic_v1p5_pg: nic_to_seq_v1p5d_pg,
                nic_av1p5_pg: nic_to_seq_v1p5a_pg,
                nic_v1p2_pg: nic_to_seq_v1p2_pg,
                nic_v1p1_pg: nic_to_seq_v1p1_pg,
                nic_v0p96_pg: pwr_cont_nic_pg0
            };
        endrule

        interface NicInputPinsNormalizedSink syncd_pins;
            method pwr_cont_nic_pg0 = pwr_cont_nic_pg0._write;
            method pwr_cont_nic_nvrhot = pwr_cont_nic_nvrhot._write;
            method pwr_cont_nic_cfp = pwr_cont_nic_cfp._write;
            method nic_to_seq_v1p5a_pg = nic_to_seq_v1p5a_pg._write;
            method nic_to_seq_v1p5d_pg = nic_to_seq_v1p5d_pg._write;
            method nic_to_seq_v1p2_pg = nic_to_seq_v1p2_pg._write;
            method nic_to_seq_v1p1_pg = nic_to_seq_v1p1_pg._write;
            method pwr_cont_nic_pg1 = pwr_cont_nic_pg1._write;
        endinterface

        interface NicRegs reg_if;
            method nic_status = cur_nic_status._read;
        endinterface

    endmodule

endpackage