package A0Block;

import Clocks::*;
import ClientServer::*;
import Connectable::*;
import GetPut::*;
import GimletSeqFpgaRegs::*;

    // Interface for output pins
    interface A0OutputSource;
        method Bit#(1) pwr_cont_dimm_abcd_en1;
        method Bit#(1) pwr_cont_dimm_efgh_en0;
        method Bit#(1) pwr_cont_dimm_efgh_en2;
        method Bit#(1) pwr_cont2_sp3_pwrok;
        method Bit#(1) seq_to_sp3_v1p8_en;
        method Bit#(1) pwr_cont1_sp3_pwrok;
        method Bit#(1) pwr_cont2_sp3_en;
        method Bit#(1) pwr_cont1_sp3_en;
        method Bit#(1) pwr_cont_dimm_abcd_en2;
        method Bit#(1) pwr_cont_dimm_abcd_en0;
        method Bit#(1) pwr_cont_dimm_efgh_en1;
        method Bit#(1) sp_to_sp3_pwr_btn_l;
        method Bit#(1) seq_to_vtt_efgh_en;
        method Bit#(1) seq_to_sp3_pwr_good;
        method Bit#(1) seq_to_sp3_rsmrst_v3p3_l;
        method Bit#(1) seq_to_vtt_abcd_a0_en;
    endinterface
    
    // Interface for input pins
    interface A0InputPinsRawSink;
        (* prefix = "" *)
        method Action pwr_cont_dimm_efgh_cfp((*port = "pwr_cont_dimm_efgh_cfp" *) Bit#(1) value);
        (* prefix = "" *)
        method Action pwr_cont1_sp3_nvrhot((*port = "pwr_cont1_sp3_nvrhot" *) Bit#(1) value);
        (* prefix = "" *)
        method Action pwr_cont_dimm_efgh_pg0((*port = "pwr_cont_dimm_efgh_pg0" *) Bit#(1) value);
        (* prefix = "" *)
        method Action pwr_cont1_sp3_cfp((*port = "pwr_cont1_sp3_cfp" *) Bit#(1) value);
        (* prefix = "" *)
        method Action pwr_cont2_sp3_pg1((*port = "pwr_cont2_sp3_pg1" *) Bit#(1) value);
        (* prefix = "" *)
        method Action pwr_cont_dimm_abcd_pg2((*port = "pwr_cont_dimm_abcd_pg2" *) Bit#(1) value);
        (* prefix = "" *)
        method Action pwr_cont_dimm_abcd_cfp((*port = "pwr_cont_dimm_abcd_cfp" *) Bit#(1) value);
        (* prefix = "" *)
        method Action pwr_cont_dimm_efgh_pg1((*port = "pwr_cont_dimm_efgh_pg1" *) Bit#(1) value);
        (* prefix = "" *)
        method Action pwr_cont_dimm_abcd_pg0((*port = "pwr_cont_dimm_abcd_pg0" *) Bit#(1) value);
        (* prefix = "" *)
        method Action sp3_to_sp_slp_s3_l((*port = "sp3_to_sp_slp_s3_l" *) Bit#(1) value);
        (* prefix = "" *)
        method Action pwr_cont2_sp3_pg0((*port = "pwr_cont2_sp3_pg0" *) Bit#(1) value);
        (* prefix = "" *)
        method Action sp3_to_sp_slp_s5_l((*port = "sp3_to_sp_slp_s5_l" *) Bit#(1) value);
        (* prefix = "" *)
        method Action vtt_efgh_a0_to_seq_pg_l((*port = "vtt_efgh_a0_to_seq_pg_l" *) Bit#(1) value);
        (* prefix = "" *)
        method Action pwr_cont1_sp3_pg1((*port = "pwr_cont1_sp3_pg1" *) Bit#(1) value);
        (* prefix = "" *)
        method Action pwr_cont2_sp3_nvrhot((*port = "pwr_cont2_sp3_nvrhot" *) Bit#(1) value);
        (* prefix = "" *)
        method Action pwr_cont_dimm_efgh_pg2((*port = "pwr_cont_dimm_efgh_pg2" *) Bit#(1) value);
        (* prefix = "" *)
        method Action pwr_cont1_sp3_pg0((*port = "pwr_cont1_sp3_pg0" *) Bit#(1) value);
        (* prefix = "" *)
        method Action pwr_cont_dimm_abcd_pg1((*port = "pwr_cont_dimm_abcd_pg1" *) Bit#(1) value);
        (* prefix = "" *)
        method Action pwr_cont2_sp3_cfp((*port = "pwr_cont2_sp3_cfp" *) Bit#(1) value);
        (* prefix = "" *)
        method Action seq_v1p8_sp3_vdd_pg_l((*port = "seq_v1p8_sp3_vdd_pg_l" *) Bit#(1) value);
        (* prefix = "" *)
        method Action sp3_to_seq_pwrok_v3p3((*port = "sp3_to_seq_pwrok_v3p3" *) Bit#(1) value);
        (* prefix = "" *)
        method Action pwr_cont_dimm_efgh_nvrhot((*port = "pwr_cont_dimm_efgh_nvrhot" *) Bit#(1) value);
        (* prefix = "" *)
        method Action sp3_to_seq_reset_v3p3_l((*port = "sp3_to_seq_reset_v3p3_l" *) Bit#(1) value);
        (* prefix = "" *)
        method Action pwr_cont_dimm_abcd_nvrhot((*port = "pwr_cont_dimm_abcd_nvrhot" *) Bit#(1) value);
        (* prefix = "" *)
        method Action vtt_abcd_a0_to_seq_pg_l((*port = "vtt_abcd_a0_to_seq_pg_l" *) Bit#(1) value);
    endinterface

    // Sourcing input pins (for testbenches etc)
    interface A0InputPinsRawSource;
        method Bit#(1) pwr_cont_dimm_efgh_cfp;
        method Bit#(1) pwr_cont1_sp3_nvrhot;
        method Bit#(1) pwr_cont_dimm_efgh_pg0;
        method Bit#(1) pwr_cont1_sp3_cfp;
        method Bit#(1) pwr_cont2_sp3_pg1;
        method Bit#(1) pwr_cont_dimm_abcd_pg2;
        method Bit#(1) pwr_cont_dimm_abcd_cfp;
        method Bit#(1) pwr_cont_dimm_efgh_pg1;
        method Bit#(1) pwr_cont_dimm_abcd_pg0;
        method Bit#(1) sp3_to_sp_slp_s3_l;
        method Bit#(1) pwr_cont2_sp3_pg0;
        method Bit#(1) sp3_to_sp_slp_s5_l;
        method Bit#(1) vtt_efgh_a0_to_seq_pg_l;
        method Bit#(1) pwr_cont1_sp3_pg1;
        method Bit#(1) pwr_cont2_sp3_nvrhot;
        method Bit#(1) pwr_cont_dimm_efgh_pg2;
        method Bit#(1) pwr_cont1_sp3_pg0;
        method Bit#(1) pwr_cont_dimm_abcd_pg1;
        method Bit#(1) pwr_cont2_sp3_cfp;
        method Bit#(1) seq_v1p8_sp3_vdd_pg_l;
        method Bit#(1) sp3_to_seq_pwrok_v3p3;
        method Bit#(1) pwr_cont_dimm_efgh_nvrhot;
        method Bit#(1) sp3_to_seq_reset_v3p3_l;
        method Bit#(1) pwr_cont_dimm_abcd_nvrhot;
        method Bit#(1) vtt_abcd_a0_to_seq_pg_l;
    endinterface
    typedef struct {
        Bit#(1) pwr_cont_dimm_efgh_cfp;
        Bit#(1) pwr_cont1_sp3_nvrhot;
        Bit#(1) pwr_cont_dimm_efgh_pg0;
        Bit#(1) pwr_cont1_sp3_cfp;
        Bit#(1) pwr_cont2_sp3_pg1;
        Bit#(1) pwr_cont_dimm_abcd_pg2;
        Bit#(1) pwr_cont_dimm_abcd_cfp;
        Bit#(1) pwr_cont_dimm_efgh_pg1;
        Bit#(1) pwr_cont_dimm_abcd_pg0;
        Bit#(1) sp3_to_sp_slp_s3;
        Bit#(1) pwr_cont2_sp3_pg0;
        Bit#(1) sp3_to_sp_slp_s5;
        Bit#(1) vtt_efgh_a0_to_seq_pg;
        Bit#(1) pwr_cont1_sp3_pg1;
        Bit#(1) pwr_cont2_sp3_nvrhot;
        Bit#(1) pwr_cont_dimm_efgh_pg2;
        Bit#(1) pwr_cont1_sp3_pg0;
        Bit#(1) pwr_cont_dimm_abcd_pg1;
        Bit#(1) pwr_cont2_sp3_cfp;
        Bit#(1) seq_v1p8_sp3_vdd_pg;
        Bit#(1) sp3_to_seq_pwrok_v3p3;
        Bit#(1) pwr_cont_dimm_efgh_nvrhot;
        Bit#(1) sp3_to_seq_reset_v3p3;
        Bit#(1) pwr_cont_dimm_abcd_nvrhot;
        Bit#(1) vtt_abcd_a0_to_seq_pg;
    } A0InPinsStruct deriving (Bits);

    typedef struct {
        Bit#(1) pwr_cont_dimm_abcd_en1;
        Bit#(1) pwr_cont_dimm_efgh_en0;
        Bit#(1) pwr_cont_dimm_efgh_en2;
        Bit#(1) pwr_cont2_sp3_pwrok;
        Bit#(1) seq_to_sp3_v1p8_en;
        Bit#(1) pwr_cont1_sp3_pwrok;
        Bit#(1) pwr_cont2_sp3_en;
        Bit#(1) pwr_cont1_sp3_en;
        Bit#(1) pwr_cont_dimm_abcd_en2;
        Bit#(1) pwr_cont_dimm_abcd_en0;
        Bit#(1) pwr_cont_dimm_efgh_en1;
        Bit#(1) sp_to_sp3_pwr_btn;
        Bit#(1) seq_to_vtt_efgh_en;
        Bit#(1) seq_to_sp3_pwr_good;
        Bit#(1) seq_to_sp3_rsmrst_v3p3;
        Bit#(1) seq_to_vtt_abcd_a0_en;
    } A0OutPinsStruct deriving (Bits);

    // Allow our input pin source to connect to our input pin sink
    instance Connectable#(A0InputPinsRawSource, A0InputPinsRawSink);
        module mkConnection#(A0InputPinsRawSource source, A0InputPinsRawSink sink) (Empty);
            mkConnection(source.pwr_cont_dimm_efgh_cfp, sink.pwr_cont_dimm_efgh_cfp);
            mkConnection(source.pwr_cont1_sp3_nvrhot, sink.pwr_cont1_sp3_nvrhot);
            mkConnection(source.pwr_cont_dimm_efgh_pg0, sink.pwr_cont_dimm_efgh_pg0);
            mkConnection(source.pwr_cont1_sp3_cfp, sink.pwr_cont1_sp3_cfp);
            mkConnection(source.pwr_cont2_sp3_pg1, sink.pwr_cont2_sp3_pg1);
            mkConnection(source.pwr_cont_dimm_abcd_pg2, sink.pwr_cont_dimm_abcd_pg2);
            mkConnection(source.pwr_cont_dimm_abcd_cfp, sink.pwr_cont_dimm_abcd_cfp);
            mkConnection(source.pwr_cont_dimm_efgh_pg1, sink.pwr_cont_dimm_efgh_pg1);
            mkConnection(source.pwr_cont_dimm_abcd_pg0, sink.pwr_cont_dimm_abcd_pg0);
            mkConnection(source.sp3_to_sp_slp_s3_l, sink.sp3_to_sp_slp_s3_l);
            mkConnection(source.pwr_cont2_sp3_pg0, sink.pwr_cont2_sp3_pg0);
            mkConnection(source.sp3_to_sp_slp_s5_l, sink.sp3_to_sp_slp_s5_l);
            mkConnection(source.vtt_efgh_a0_to_seq_pg_l, sink.vtt_efgh_a0_to_seq_pg_l);
            mkConnection(source.pwr_cont1_sp3_pg1, sink.pwr_cont1_sp3_pg1);
            mkConnection(source.pwr_cont2_sp3_nvrhot, sink.pwr_cont2_sp3_nvrhot);
            mkConnection(source.pwr_cont_dimm_efgh_pg2, sink.pwr_cont_dimm_efgh_pg2);
            mkConnection(source.pwr_cont1_sp3_pg0, sink.pwr_cont1_sp3_pg0);
            mkConnection(source.pwr_cont_dimm_abcd_pg1, sink.pwr_cont_dimm_abcd_pg1);
            mkConnection(source.pwr_cont2_sp3_cfp, sink.pwr_cont2_sp3_cfp);
            mkConnection(source.seq_v1p8_sp3_vdd_pg_l, sink.seq_v1p8_sp3_vdd_pg_l);
            mkConnection(source.sp3_to_seq_pwrok_v3p3, sink.sp3_to_seq_pwrok_v3p3);
            mkConnection(source.pwr_cont_dimm_efgh_nvrhot, sink.pwr_cont_dimm_efgh_nvrhot);
            mkConnection(source.sp3_to_seq_reset_v3p3_l, sink.sp3_to_seq_reset_v3p3_l);
            mkConnection(source.pwr_cont_dimm_abcd_nvrhot, sink.pwr_cont_dimm_abcd_nvrhot);
            mkConnection(source.vtt_abcd_a0_to_seq_pg_l, sink.vtt_abcd_a0_to_seq_pg_l);
        endmodule
    endinstance
    // Synchronizer interface, pins in, syncd_pins struct out
    interface A0InputSyncBlock;
        interface A0InputPinsRawSink in_pins;
        method A0InPinsStruct syncd_pins;
    endinterface
    // Interface at this block to the register block
    interface A0Regs;
        // Normalized pin readbacks to registers
        method A0InPinsStruct input_readbacks; // Input sampling  TODO: want a function to return register types
        method A0OutPinsStruct output_readbacks; // Output sampling
        method Action dbg_ctrl(A0OutPinsStruct value); // Output control
        method Action dbg_en(Bit#(1) value);    // Debug enable pin
    endinterface
    // "Reverse" Interface at register block
    interface A0RegsReverse;
        // Normalized pin readbacks to registers
        method Action input_readbacks(A0InPinsStruct value); // Input sampling
        method Action output_readbacks(A0OutPinsStruct value); // Output sampling
        method A0OutPinsStruct dbg_ctrl; // Output control
        method Bit#(1) dbg_en;    // Debug enable pin
    endinterface

    // Allow register block interfaces to connect
    instance Connectable#(A0Regs, A0RegsReverse);
        module mkConnection#(A0Regs source, A0RegsReverse sink) (Empty);
            mkConnection(source.input_readbacks, sink.input_readbacks);
            mkConnection(source.output_readbacks, sink.output_readbacks);
            mkConnection(source.dbg_ctrl, sink.dbg_ctrl);
            mkConnection(source.dbg_en, sink.dbg_en);
        endmodule
    endinstance

    // Block top (syncd pins in, pins out, register if)
    interface A0BlockTop;
        method Action syncd_pins(A0InPinsStruct value);
        interface A0Regs reg_if;
        interface A0OutputSource out_pins;
    endinterface

    // Input synchronization module (pins -> syncs -> structs)
    module mkA0Sync(A0InputSyncBlock);
        Clock clk_sys <- exposeCurrentClock();
        Reset rst_sys <- exposeCurrentReset();

        // Synchronizers
        SyncBitIfc#(Bit#(1)) pwr_cont_dimm_efgh_cfp <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
        SyncBitIfc#(Bit#(1)) pwr_cont1_sp3_nvrhot <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
        SyncBitIfc#(Bit#(1)) pwr_cont_dimm_efgh_pg0 <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
        SyncBitIfc#(Bit#(1)) pwr_cont1_sp3_cfp <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
        SyncBitIfc#(Bit#(1)) pwr_cont2_sp3_pg1 <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
        SyncBitIfc#(Bit#(1)) pwr_cont_dimm_abcd_pg2 <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
        SyncBitIfc#(Bit#(1)) pwr_cont_dimm_abcd_cfp <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
        SyncBitIfc#(Bit#(1)) pwr_cont_dimm_efgh_pg1 <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
        SyncBitIfc#(Bit#(1)) pwr_cont_dimm_abcd_pg0 <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
        SyncBitIfc#(Bit#(1)) sp3_to_sp_slp_s3_l <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
        SyncBitIfc#(Bit#(1)) pwr_cont2_sp3_pg0 <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
        SyncBitIfc#(Bit#(1)) sp3_to_sp_slp_s5_l <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
        SyncBitIfc#(Bit#(1)) vtt_efgh_a0_to_seq_pg_l <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
        SyncBitIfc#(Bit#(1)) pwr_cont1_sp3_pg1 <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
        SyncBitIfc#(Bit#(1)) pwr_cont2_sp3_nvrhot <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
        SyncBitIfc#(Bit#(1)) pwr_cont_dimm_efgh_pg2 <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
        SyncBitIfc#(Bit#(1)) pwr_cont1_sp3_pg0 <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
        SyncBitIfc#(Bit#(1)) pwr_cont_dimm_abcd_pg1 <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
        SyncBitIfc#(Bit#(1)) pwr_cont2_sp3_cfp <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
        SyncBitIfc#(Bit#(1)) seq_v1p8_sp3_vdd_pg_l <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
        SyncBitIfc#(Bit#(1)) sp3_to_seq_pwrok_v3p3 <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
        SyncBitIfc#(Bit#(1)) pwr_cont_dimm_efgh_nvrhot <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
        SyncBitIfc#(Bit#(1)) sp3_to_seq_reset_v3p3_l <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
        SyncBitIfc#(Bit#(1)) pwr_cont_dimm_abcd_nvrhot <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
        SyncBitIfc#(Bit#(1)) vtt_abcd_a0_to_seq_pg_l <- mkSyncBit1(clk_sys, rst_sys, clk_sys);

        // Output combo
        Wire#(A0InPinsStruct) cur_syncd_pins <- mkDWire(unpack(0));

        // Put sync'd bits into a combo structure to make passing it around easier
        rule do_structurize;
            cur_syncd_pins <= A0InPinsStruct {
                pwr_cont_dimm_efgh_cfp: pwr_cont_dimm_efgh_cfp.read(),
                pwr_cont1_sp3_nvrhot: pwr_cont1_sp3_nvrhot.read(),
                pwr_cont_dimm_efgh_pg0: pwr_cont_dimm_efgh_pg0.read(),
                pwr_cont1_sp3_cfp: pwr_cont1_sp3_cfp.read(),
                pwr_cont2_sp3_pg1: pwr_cont2_sp3_pg1.read(),
                pwr_cont_dimm_abcd_pg2: pwr_cont_dimm_abcd_pg2.read(),
                pwr_cont_dimm_abcd_cfp: pwr_cont_dimm_abcd_cfp.read(),
                pwr_cont_dimm_efgh_pg1: pwr_cont_dimm_efgh_pg1.read(),
                pwr_cont_dimm_abcd_pg0: pwr_cont_dimm_abcd_pg0.read(),
                sp3_to_sp_slp_s3: ~sp3_to_sp_slp_s3_l.read(),
                pwr_cont2_sp3_pg0: pwr_cont2_sp3_pg0.read(),
                sp3_to_sp_slp_s5: ~sp3_to_sp_slp_s5_l.read(),
                vtt_efgh_a0_to_seq_pg: ~vtt_efgh_a0_to_seq_pg_l.read(),
                pwr_cont1_sp3_pg1: pwr_cont1_sp3_pg1.read(),
                pwr_cont2_sp3_nvrhot: pwr_cont2_sp3_nvrhot.read(),
                pwr_cont_dimm_efgh_pg2: pwr_cont_dimm_efgh_pg2.read(),
                pwr_cont1_sp3_pg0: pwr_cont1_sp3_pg0.read(),
                pwr_cont_dimm_abcd_pg1: pwr_cont_dimm_abcd_pg1.read(),
                pwr_cont2_sp3_cfp: pwr_cont2_sp3_cfp.read(),
                seq_v1p8_sp3_vdd_pg: ~seq_v1p8_sp3_vdd_pg_l.read(),
                sp3_to_seq_pwrok_v3p3: sp3_to_seq_pwrok_v3p3.read(),
                pwr_cont_dimm_efgh_nvrhot: pwr_cont_dimm_efgh_nvrhot.read(),
                sp3_to_seq_reset_v3p3: ~sp3_to_seq_reset_v3p3_l.read(),
                pwr_cont_dimm_abcd_nvrhot: pwr_cont_dimm_abcd_nvrhot.read(),
                vtt_abcd_a0_to_seq_pg: ~vtt_abcd_a0_to_seq_pg_l.read()
            };
        endrule

        interface A0InputPinsRawSink in_pins;
            method pwr_cont_dimm_efgh_cfp = pwr_cont_dimm_efgh_cfp.send;
            method pwr_cont1_sp3_nvrhot = pwr_cont1_sp3_nvrhot.send;
            method pwr_cont_dimm_efgh_pg0 = pwr_cont_dimm_efgh_pg0.send;
            method pwr_cont1_sp3_cfp = pwr_cont1_sp3_cfp.send;
            method pwr_cont2_sp3_pg1 = pwr_cont2_sp3_pg1.send;
            method pwr_cont_dimm_abcd_pg2 = pwr_cont_dimm_abcd_pg2.send;
            method pwr_cont_dimm_abcd_cfp = pwr_cont_dimm_abcd_cfp.send;
            method pwr_cont_dimm_efgh_pg1 = pwr_cont_dimm_efgh_pg1.send;
            method pwr_cont_dimm_abcd_pg0 = pwr_cont_dimm_abcd_pg0.send;
            method sp3_to_sp_slp_s3_l = sp3_to_sp_slp_s3_l.send;
            method pwr_cont2_sp3_pg0 = pwr_cont2_sp3_pg0.send;
            method sp3_to_sp_slp_s5_l = sp3_to_sp_slp_s5_l.send;
            method vtt_efgh_a0_to_seq_pg_l = vtt_efgh_a0_to_seq_pg_l.send;
            method pwr_cont1_sp3_pg1 = pwr_cont1_sp3_pg1.send;
            method pwr_cont2_sp3_nvrhot = pwr_cont2_sp3_nvrhot.send;
            method pwr_cont_dimm_efgh_pg2 = pwr_cont_dimm_efgh_pg2.send;
            method pwr_cont1_sp3_pg0 = pwr_cont1_sp3_pg0.send;
            method pwr_cont_dimm_abcd_pg1 = pwr_cont_dimm_abcd_pg1.send;
            method pwr_cont2_sp3_cfp = pwr_cont2_sp3_cfp.send;
            method seq_v1p8_sp3_vdd_pg_l = seq_v1p8_sp3_vdd_pg_l.send;
            method sp3_to_seq_pwrok_v3p3 = sp3_to_seq_pwrok_v3p3.send;
            method pwr_cont_dimm_efgh_nvrhot = pwr_cont_dimm_efgh_nvrhot.send;
            method sp3_to_seq_reset_v3p3_l = sp3_to_seq_reset_v3p3_l.send;
            method pwr_cont_dimm_abcd_nvrhot = pwr_cont_dimm_abcd_nvrhot.send;
            method vtt_abcd_a0_to_seq_pg_l = vtt_abcd_a0_to_seq_pg_l.send;
        endinterface
        
        method syncd_pins = cur_syncd_pins._read;
    endmodule

    // Block top module
    module mkA0Block(A0BlockTop);

        // Output registers
        Reg#(Bit#(1)) pwr_cont_dimm_abcd_en1 <- mkReg(0);
        Reg#(Bit#(1)) pwr_cont_dimm_efgh_en0 <- mkReg(0);
        Reg#(Bit#(1)) pwr_cont_dimm_efgh_en2 <- mkReg(0);
        Reg#(Bit#(1)) pwr_cont2_sp3_pwrok <- mkReg(0);
        Reg#(Bit#(1)) seq_to_sp3_v1p8_en <- mkReg(0);
        Reg#(Bit#(1)) pwr_cont1_sp3_pwrok <- mkReg(0);
        Reg#(Bit#(1)) pwr_cont2_sp3_en <- mkReg(0);
        Reg#(Bit#(1)) pwr_cont1_sp3_en <- mkReg(0);
        Reg#(Bit#(1)) pwr_cont_dimm_abcd_en2 <- mkReg(0);
        Reg#(Bit#(1)) pwr_cont_dimm_abcd_en0 <- mkReg(0);
        Reg#(Bit#(1)) pwr_cont_dimm_efgh_en1 <- mkReg(0);
        Reg#(Bit#(1)) sp_to_sp3_pwr_btn_l <- mkReg(1);
        Reg#(Bit#(1)) seq_to_vtt_efgh_en <- mkReg(0);
        Reg#(Bit#(1)) seq_to_sp3_pwr_good <- mkReg(0);
        Reg#(Bit#(1)) seq_to_sp3_rsmrst_v3p3_l <- mkReg(1);
        Reg#(Bit#(1)) seq_to_vtt_abcd_a0_en <- mkReg(0);

        // Combo output readbacks
        Wire#(A0OutPinsStruct) cur_out_pins <- mkDWire(unpack(0));
        // Combo input wires
        Wire#(A0InPinsStruct) cur_syncd_pins <- mkDWire(unpack(0));
        Wire#(A0OutPinsStruct) dbg_out_pins <- mkDWire(unpack(0));
        Wire#(Bit#(1)) dbg_en   <- mkDWire(0);

        rule do_pack_output_readbacks;
            cur_out_pins <= A0OutPinsStruct {
                pwr_cont_dimm_abcd_en1: pwr_cont_dimm_abcd_en1,
                pwr_cont_dimm_efgh_en0: pwr_cont_dimm_efgh_en0,
                pwr_cont_dimm_efgh_en2: pwr_cont_dimm_efgh_en2,
                pwr_cont2_sp3_pwrok: pwr_cont2_sp3_pwrok,
                seq_to_sp3_v1p8_en: seq_to_sp3_v1p8_en,
                pwr_cont1_sp3_pwrok: pwr_cont1_sp3_pwrok,
                pwr_cont2_sp3_en: pwr_cont2_sp3_en,
                pwr_cont1_sp3_en: pwr_cont1_sp3_en,
                pwr_cont_dimm_abcd_en2: pwr_cont_dimm_abcd_en2,
                pwr_cont_dimm_abcd_en0: pwr_cont_dimm_abcd_en0,
                pwr_cont_dimm_efgh_en1: pwr_cont_dimm_efgh_en1,
                sp_to_sp3_pwr_btn: ~sp_to_sp3_pwr_btn_l,
                seq_to_vtt_efgh_en: seq_to_vtt_efgh_en,
                seq_to_sp3_pwr_good: seq_to_sp3_pwr_good,
                seq_to_sp3_rsmrst_v3p3: ~seq_to_sp3_rsmrst_v3p3_l,
                seq_to_vtt_abcd_a0_en: seq_to_vtt_abcd_a0_en
            };
        endrule

        rule do_output_pins;
            pwr_cont_dimm_abcd_en1 <= dbg_out_pins.pwr_cont_dimm_abcd_en1;
            pwr_cont_dimm_efgh_en0 <= dbg_out_pins.pwr_cont_dimm_efgh_en0;
            pwr_cont_dimm_efgh_en2 <= dbg_out_pins.pwr_cont_dimm_efgh_en2;
            pwr_cont2_sp3_pwrok <= dbg_out_pins.pwr_cont2_sp3_pwrok;
            seq_to_sp3_v1p8_en <= dbg_out_pins.seq_to_sp3_v1p8_en;
            pwr_cont1_sp3_pwrok <= dbg_out_pins.pwr_cont1_sp3_pwrok;
            pwr_cont2_sp3_en <= dbg_out_pins.pwr_cont2_sp3_en;
            pwr_cont1_sp3_en <= dbg_out_pins.pwr_cont1_sp3_en;
            pwr_cont_dimm_abcd_en2 <= dbg_out_pins.pwr_cont_dimm_abcd_en2;
            pwr_cont_dimm_abcd_en0 <= dbg_out_pins.pwr_cont_dimm_abcd_en0;
            pwr_cont_dimm_efgh_en1 <= dbg_out_pins.pwr_cont_dimm_efgh_en1;
            sp_to_sp3_pwr_btn_l <= ~dbg_out_pins.sp_to_sp3_pwr_btn;
            seq_to_vtt_efgh_en <= dbg_out_pins.seq_to_vtt_efgh_en;
            seq_to_sp3_pwr_good <= dbg_out_pins.seq_to_sp3_pwr_good;
            seq_to_sp3_rsmrst_v3p3_l <= ~dbg_out_pins.seq_to_sp3_rsmrst_v3p3;
            seq_to_vtt_abcd_a0_en <= dbg_out_pins.seq_to_vtt_abcd_a0_en;
        endrule

        method syncd_pins = cur_syncd_pins._write;
        interface A0Regs reg_if;
            method input_readbacks = cur_syncd_pins._read;
            method output_readbacks = cur_out_pins._read; // Output sampling
            method dbg_ctrl = dbg_out_pins._write; // Output control
            method dbg_en = dbg_en._write;    // Debug enable pin
        endinterface
        interface A0OutputSource out_pins;
            method pwr_cont_dimm_abcd_en1 = pwr_cont_dimm_abcd_en1._read;
            method pwr_cont_dimm_efgh_en0 = pwr_cont_dimm_efgh_en0._read;
            method pwr_cont_dimm_efgh_en2 = pwr_cont_dimm_efgh_en2._read;
            method pwr_cont2_sp3_pwrok = pwr_cont2_sp3_pwrok._read;
            method seq_to_sp3_v1p8_en = seq_to_sp3_v1p8_en._read;
            method pwr_cont1_sp3_pwrok = pwr_cont1_sp3_pwrok._read;
            method pwr_cont2_sp3_en = pwr_cont2_sp3_en._read;
            method pwr_cont1_sp3_en = pwr_cont1_sp3_en._read;
            method pwr_cont_dimm_abcd_en2 = pwr_cont_dimm_abcd_en2._read;
            method pwr_cont_dimm_abcd_en0 = pwr_cont_dimm_abcd_en0._read;
            method pwr_cont_dimm_efgh_en1 = pwr_cont_dimm_efgh_en1._read;
            method sp_to_sp3_pwr_btn_l = sp_to_sp3_pwr_btn_l._read;
            method seq_to_vtt_efgh_en = seq_to_vtt_efgh_en._read;
            method seq_to_sp3_pwr_good = seq_to_sp3_pwr_good._read;
            method seq_to_sp3_rsmrst_v3p3_l = seq_to_sp3_rsmrst_v3p3_l._read;
            method seq_to_vtt_abcd_a0_en = seq_to_vtt_abcd_a0_en._read;
        endinterface
    endmodule

    interface TBTestA0PinsSource;
        interface Client#(Bit#(8), Bool) bfm;
        interface A0InputPinsRawSource pins;
    endinterface

    module mkTestA0PinsSource(TBTestA0PinsSource);
        Reg#(Bit#(1)) pwr_cont_dimm_efgh_cfp <- mkReg(0);
        Reg#(Bit#(1)) pwr_cont1_sp3_nvrhot <- mkReg(0);
        Reg#(Bit#(1)) pwr_cont_dimm_efgh_pg0 <- mkReg(0);
        Reg#(Bit#(1)) pwr_cont1_sp3_cfp <- mkReg(0);
        Reg#(Bit#(1)) pwr_cont2_sp3_pg1 <- mkReg(0);
        Reg#(Bit#(1)) pwr_cont_dimm_abcd_pg2 <- mkReg(0);
        Reg#(Bit#(1)) pwr_cont_dimm_abcd_cfp <- mkReg(0);
        Reg#(Bit#(1)) pwr_cont_dimm_efgh_pg1 <- mkReg(0);
        Reg#(Bit#(1)) pwr_cont_dimm_abcd_pg0 <- mkReg(0);
        Reg#(Bit#(1)) sp3_to_sp_slp_s3_l <- mkReg(0);
        Reg#(Bit#(1)) pwr_cont2_sp3_pg0 <- mkReg(0);
        Reg#(Bit#(1)) sp3_to_sp_slp_s5_l <- mkReg(0);
        Reg#(Bit#(1)) vtt_efgh_a0_to_seq_pg_l <- mkReg(0);
        Reg#(Bit#(1)) pwr_cont1_sp3_pg1 <- mkReg(0);
        Reg#(Bit#(1)) pwr_cont2_sp3_nvrhot <- mkReg(0);
        Reg#(Bit#(1)) pwr_cont_dimm_efgh_pg2 <- mkReg(0);
        Reg#(Bit#(1)) pwr_cont1_sp3_pg0 <- mkReg(0);
        Reg#(Bit#(1)) pwr_cont_dimm_abcd_pg1 <- mkReg(0);
        Reg#(Bit#(1)) pwr_cont2_sp3_cfp <- mkReg(0);
        Reg#(Bit#(1)) seq_v1p8_sp3_vdd_pg_l <- mkReg(0);
        Reg#(Bit#(1)) sp3_to_seq_pwrok_v3p3 <- mkReg(0);
        Reg#(Bit#(1)) pwr_cont_dimm_efgh_nvrhot <- mkReg(0);
        Reg#(Bit#(1)) sp3_to_seq_reset_v3p3_l <- mkReg(0);
        Reg#(Bit#(1)) pwr_cont_dimm_abcd_nvrhot <- mkReg(0);
        Reg#(Bit#(1)) vtt_abcd_a0_to_seq_pg_l <- mkReg(0);


        interface A0InputPinsRawSource pins;
            method pwr_cont_dimm_efgh_cfp = pwr_cont_dimm_efgh_cfp._read;
            method pwr_cont1_sp3_nvrhot = pwr_cont1_sp3_nvrhot._read;
            method pwr_cont_dimm_efgh_pg0 = pwr_cont_dimm_efgh_pg0._read;
            method pwr_cont1_sp3_cfp = pwr_cont1_sp3_cfp._read;
            method pwr_cont2_sp3_pg1 = pwr_cont2_sp3_pg1._read;
            method pwr_cont_dimm_abcd_pg2 = pwr_cont_dimm_abcd_pg2._read;
            method pwr_cont_dimm_abcd_cfp = pwr_cont_dimm_abcd_cfp._read;
            method pwr_cont_dimm_efgh_pg1 = pwr_cont_dimm_efgh_pg1._read;
            method pwr_cont_dimm_abcd_pg0 = pwr_cont_dimm_abcd_pg0._read;
            method sp3_to_sp_slp_s3_l = sp3_to_sp_slp_s3_l._read;
            method pwr_cont2_sp3_pg0 = pwr_cont2_sp3_pg0._read;
            method sp3_to_sp_slp_s5_l = sp3_to_sp_slp_s5_l._read;
            method vtt_efgh_a0_to_seq_pg_l = vtt_efgh_a0_to_seq_pg_l._read;
            method pwr_cont1_sp3_pg1 = pwr_cont1_sp3_pg1._read;
            method pwr_cont2_sp3_nvrhot = pwr_cont2_sp3_nvrhot._read;
            method pwr_cont_dimm_efgh_pg2 = pwr_cont_dimm_efgh_pg2._read;
            method pwr_cont1_sp3_pg0 = pwr_cont1_sp3_pg0._read;
            method pwr_cont_dimm_abcd_pg1 = pwr_cont_dimm_abcd_pg1._read;
            method pwr_cont2_sp3_cfp = pwr_cont2_sp3_cfp._read;
            method seq_v1p8_sp3_vdd_pg_l = seq_v1p8_sp3_vdd_pg_l._read;
            method sp3_to_seq_pwrok_v3p3 = sp3_to_seq_pwrok_v3p3._read;
            method pwr_cont_dimm_efgh_nvrhot = pwr_cont_dimm_efgh_nvrhot._read;
            method sp3_to_seq_reset_v3p3_l = sp3_to_seq_reset_v3p3_l._read;
            method pwr_cont_dimm_abcd_nvrhot = pwr_cont_dimm_abcd_nvrhot._read;
            method vtt_abcd_a0_to_seq_pg_l = vtt_abcd_a0_to_seq_pg_l._read;
        endinterface
        interface Client bfm;
            interface Get request;
            endinterface
            interface Put response;
            endinterface
        endinterface
    endmodule

endpackage