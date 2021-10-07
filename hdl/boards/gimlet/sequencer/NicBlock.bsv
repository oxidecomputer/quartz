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
        (* prefix = "" *)
        method Action seq_to_nic_v1p2_enet_en((* port = "seq_to_nic_v1p2_enet_en" *) Bit#(1) value);
        (* prefix = "" *)
        method Action seq_to_nic_comb_pg((* port = "seq_to_nic_comb_pg" *) Bit#(1) value);
        (* prefix = "" *)
        method Action pwr_cont_nic_en1((* port = "pwr_cont_nic_en1" *) Bit#(1) value);
        (* prefix = "" *)
        method Action pwr_cont_nic_en0((* port = "pwr_cont_nic_en0" *) Bit#(1) value);
        (* prefix = "" *)
        method Action seq_to_nic_cld_rst_l((* port = "seq_to_nic_cld_rst_l" *) Bit#(1) value);
        (* prefix = "" *)
        method Action seq_to_nic_v1p5a_en((* port = "seq_to_nic_v1p5a_en" *) Bit#(1) value);
        (* prefix = "" *)
        method Action seq_to_nic_v1p5d_en((* port = "seq_to_nic_v1p5d_en" *) Bit#(1) value);
        (* prefix = "" *)
        method Action seq_to_nic_v1p2_en((* port = "seq_to_nic_v1p2_en" *) Bit#(1) value);
        (* prefix = "" *)
        method Action seq_to_nic_v1p1_en((* port = "seq_to_nic_v1p1_en" *) Bit#(1) value);
        (* prefix = "" *)
        method Action seq_to_nic_ldo_v3p3_en((* port = "seq_to_nic_ldo_v3p3_en" *) Bit#(1) value);
        (* prefix = "" *)
        method Action nic_to_sp3_pwrflt_l((* port = "nic_to_sp3_pwrflt_l" *) Bit#(1) value);
    endinterface

    // Chip periphery pin signal names for inputs.
    interface NicInputPinsRawSink;
        (* prefix = "" *)
        method Action pwr_cont_nic_pg0((* port = "pwr_cont_nic_pg0" *) Bit#(1) value);
        (* prefix = "" *)
        method Action pwr_cont_nic_nvrhot((* port = "pwr_cont_nic_nvrhot" *) Bit#(1) value);
        (* prefix = "" *)
        method Action pwr_cont_nic_cfp((* port = "pwr_cont_nic_cfp" *) Bit#(1) value);
        (* prefix = "" *)
        method Action nic_to_seq_v1p5a_pg_l((* port = "nic_to_seq_v1p5a_pg_l" *) Bit#(1) value);
        (* prefix = "" *)
        method Action nic_to_seq_v1p5d_pg_l((* port = "nic_to_seq_v1p5d_pg_l" *) Bit#(1) value);
        (* prefix = "" *)
        method Action nic_to_seq_v1p2_pg_l((* port = "nic_to_seq_v1p2_pg_l" *) Bit#(1) value);
        (* prefix = "" *)
        method Action nic_to_seq_v1p1_pg_l((* port = "nic_to_seq_v1p1_pg_l" *) Bit#(1) value);
        (* prefix = "" *)
        method Action pwr_cont_nic_pg1((* port = "pwr_cont_nic_pg1" *) Bit#(1) value);
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

    interface ToNicRegs; // Interface at register block
        // Normalized pin readbacks to registers
        method NicStatus nic_status; 
        method OutStatusNic1 nic1_out_status;
        method OutStatusNic2 nic2_out_status;
        method Action dbg_en(Bit#(1) value);
        method Action dbg_nic1(DbgOutNic1 value);
        method Action dbg_nic2(DbgOutNic2 value);

        // Debug outputs from registers
        //interface NicOutputPinsRawSink dbg_out;
        //  TODO: sm control
        //  TODO: debug control
    endinterface

    interface NicRegPinInputs;  // Register input interface
        method Action nic_pins(NicStatus value);
        method Action nic1_out_status(OutStatusNic1 value);
        method Action nic2_out_status(OutStatusNic2 value);
        method Bit#(1) dbg_en;
        method DbgOutNic1 dbg_nic1;
        method DbgOutNic2 dbg_nic2;
    endinterface

    interface NicBlockTop;
        interface ToNicRegs reg_if;
        interface NicInputPinsNormalizedSink syncd_pins;
        interface NicOutputPinsRawSource out_pins;
    endinterface

     instance Connectable#(ToNicRegs, NicRegPinInputs);
        module mkConnection#(ToNicRegs source, NicRegPinInputs sink) (Empty);
            mkConnection(source.nic_status, sink.nic_pins);
            mkConnection(source.nic1_out_status, sink.nic1_out_status);
            mkConnection(source.nic2_out_status, sink.nic2_out_status);
            mkConnection(source.dbg_nic1, sink.dbg_nic1);
            mkConnection(source.dbg_nic2, sink.dbg_nic2);
            mkConnection(source.dbg_en, sink.dbg_en);
        endmodule
    endinstance

    module mkNicBlock(NicBlockTop);
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
        Wire#(OutStatusNic1) cur_nic1_out_status <- mkDWire(unpack(0));
        Wire#(OutStatusNic2) cur_nic2_out_status <- mkDWire(unpack(0));
        Wire#(Bit#(1)) dbg_en <- mkDWire(0);
        Wire#(DbgOutNic1) cur_dbg_nic1 <- mkDWire(unpack(0));
        Wire#(DbgOutNic2) cur_dbg_nic2 <- mkDWire(unpack(0));

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
            cur_nic1_out_status <= OutStatusNic1 {
                nic_v3p3: seq_to_nic_ldo_v3p3_en,
                nic_v1p1_en: seq_to_nic_v1p1_en,
                nic_v1p2_en: seq_to_nic_v1p2_en,
                nic_v1p5d_en: seq_to_nic_v1p5d_en,
                nic_v1p5a_en: seq_to_nic_v1p5a_en,
                nic_cont_en1: pwr_cont_nic_en1,
                nic_cont_en0: pwr_cont_nic_en0,
                nic_v1p2_eth_en: seq_to_nic_v1p2_enet_en
            };
            cur_nic2_out_status <= OutStatusNic2 {
                pwrflt: ~nic_to_sp3_pwrflt_l,
                nic_cld_rst: ~seq_to_nic_cld_rst_l,
                nic_comb_pg: seq_to_nic_comb_pg
            };
        endrule

        rule do_output_pins;
            // For now, there are no sm outputs so dbg status goes to pins.
            seq_to_nic_v1p2_enet_en <= cur_dbg_nic1.nic_v1p2_eth_en;
            seq_to_nic_comb_pg <= cur_dbg_nic2.nic_comb_pg;
            pwr_cont_nic_en1 <= cur_dbg_nic1.nic_cont_en1;
            pwr_cont_nic_en0 <= cur_dbg_nic1.nic_cont_en0;
            seq_to_nic_cld_rst_l <= ~cur_dbg_nic2.nic_cld_rst;
            seq_to_nic_v1p5a_en <= cur_dbg_nic1.nic_v1p5a_en;
            seq_to_nic_v1p5d_en <= cur_dbg_nic1.nic_v1p5d_en;
            seq_to_nic_v1p2_en <= cur_dbg_nic1.nic_v1p2_en;
            seq_to_nic_v1p1_en <= cur_dbg_nic1.nic_v1p1_en;
            seq_to_nic_ldo_v3p3_en <= cur_dbg_nic1.nic_v3p3;
            nic_to_sp3_pwrflt_l <= ~cur_dbg_nic2.pwrflt;

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

        interface ToNicRegs reg_if;
            method nic_status = cur_nic_status._read;
            method nic1_out_status = cur_nic1_out_status._read;
            method nic2_out_status = cur_nic2_out_status._read;
            method dbg_en = dbg_en._write;
            method dbg_nic1 = cur_dbg_nic1._write;
            method dbg_nic2 = cur_dbg_nic2._write;
        endinterface

        interface NicOutputPinsRawSource out_pins;
            method seq_to_nic_v1p2_enet_en = seq_to_nic_v1p2_enet_en._read;
            method seq_to_nic_comb_pg = seq_to_nic_comb_pg._read;
            method pwr_cont_nic_en1 = pwr_cont_nic_en1._read;
            method pwr_cont_nic_en0 = pwr_cont_nic_en0._read;
            method seq_to_nic_cld_rst_l = seq_to_nic_cld_rst_l._read;
            method seq_to_nic_v1p5a_en = seq_to_nic_v1p5a_en._read;
            method seq_to_nic_v1p5d_en = seq_to_nic_v1p5d_en._read;
            method seq_to_nic_v1p2_en = seq_to_nic_v1p2_en._read;
            method seq_to_nic_v1p1_en = seq_to_nic_v1p1_en._read;
            method seq_to_nic_ldo_v3p3_en = seq_to_nic_ldo_v3p3_en._read;
            method nic_to_sp3_pwrflt_l = nic_to_sp3_pwrflt_l._read;
        endinterface
    endmodule

endpackage