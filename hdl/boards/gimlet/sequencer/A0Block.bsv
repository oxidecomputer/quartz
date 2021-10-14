package A0Block;

import Clocks::*;
import ClientServer::*;
import Connectable::*;
import GetPut::*;
import GimletSeqFpgaRegs::*;

    // Interface for output pins
    interface A0OutputSource;
        method Bit#(1) seq_to_sp3_sys_rst_l;
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
        method Bit#(1) seq_to_vtt_abcd_a0_en;
    endinterface
    
    // Interface for input pins
    interface A0InputPinsRawSink;
        (* prefix = "" *)
        method Action sp3_to_seq_pwrgd_out((* port = "sp3_to_seq_pwrgd_out" *) Bit#(1) value);
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
        method Bit#(1) sp3_to_seq_pwrgd_out;
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
        Bit#(1) sp3_to_seq_pwrgd_out;
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
        Bit#(1) seq_to_sp3_sys_rst;
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
        Bit#(1) seq_to_vtt_abcd_a0_en;
    } A0OutPinsStruct deriving (Bits);

    // Allow our input pin source to connect to our input pin sink
    instance Connectable#(A0InputPinsRawSource, A0InputPinsRawSink);
        module mkConnection#(A0InputPinsRawSource source, A0InputPinsRawSink sink) (Empty);
            mkConnection(source.sp3_to_seq_pwrgd_out, sink.sp3_to_seq_pwrgd_out);
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
        method A0StateType state;
        method Action dbg_en(Bit#(1) value);    // Debug enable pin
        method Action ignore_sp(Bit#(1) value);
        method Action a0_en(Bit#(1) value);  // SM enable pin
    endinterface
    // "Reverse" Interface at register block
    interface A0RegsReverse;
        // Normalized pin readbacks to registers
        method Action input_readbacks(A0InPinsStruct value); // Input sampling
        method Action output_readbacks(A0OutPinsStruct value); // Output sampling
        method Action state(A0StateType value);
        method A0OutPinsStruct dbg_ctrl; // Output control
        method Bit#(1) dbg_en;    // Debug enable pin
        method Bit#(1) ignore_sp;
        method Bit#(1) a0_en;    // SM enable pin
    endinterface

    // Allow register block interfaces to connect
    instance Connectable#(A0Regs, A0RegsReverse);
        module mkConnection#(A0Regs source, A0RegsReverse sink) (Empty);
            mkConnection(source.input_readbacks, sink.input_readbacks);
            mkConnection(source.output_readbacks, sink.output_readbacks);
            mkConnection(source.dbg_ctrl, sink.dbg_ctrl);
            mkConnection(source.dbg_en, sink.dbg_en);
            mkConnection(source.ignore_sp, sink.ignore_sp);
            mkConnection(source.state, sink.state);
            mkConnection(source.a0_en, sink.a0_en);
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
        SyncBitIfc#(Bit#(1)) sp3_to_seq_pwrgd_out <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
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
                sp3_to_seq_pwrgd_out: sp3_to_seq_pwrgd_out.read(),
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
            method sp3_to_seq_pwrgd_out = sp3_to_seq_pwrgd_out.send;
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

    typedef enum {
        IDLE, 
        PBTN, 
        WAITSLP, 
        GROUPB1_EN, 
        GROUPB1_PG, 
        GROUPB2_EN, 
        GROUPB2_PG,
        GROUPC_PG,
        DELAY_1MS,
        ASSERT_PG,
        WAIT_PWROK,
        WAIT_RESET_L,
        DONE
   
    } A0StateType deriving (Eq, Bits);

    // Block top module
    module mkA0Block(A0BlockTop);

        // State registers
        Reg#(UInt#(24)) delay_counter <- mkReg(fromInteger(500000));  // up to 25ms @50MHz TODO: make this a constant
        Reg#(A0StateType) state <- mkReg(IDLE);
        // Output registers
        Reg#(Bit#(1)) seq_to_sp3_sys_rst_l <- mkReg(1);
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
        Reg#(Bit#(1)) seq_to_vtt_abcd_a0_en <- mkReg(0);

        // Combo output readbacks
        Wire#(A0OutPinsStruct) cur_out_pins <- mkDWire(unpack(0));
        // Combo input wires
        Wire#(A0InPinsStruct) cur_syncd_pins <- mkDWire(unpack(0));
        Wire#(A0OutPinsStruct) dbg_out_pins <- mkDWire(unpack(0));
        Wire#(Bit#(1)) ignore_sp <- mkDWire(0);
        Wire#(Bit#(1)) dbg_en   <- mkDWire(0);
        Wire#(Bit#(1)) a0_en    <- mkDWire(0);

        //  Wait for SP to check power good and say go
        rule do_idle (state == IDLE && dbg_en == 0);
            delay_counter <= fromInteger(500000);  // Want 20ms
            pwr_cont_dimm_abcd_en1 <= 0;
            pwr_cont_dimm_efgh_en0 <= 0;
            pwr_cont_dimm_efgh_en2 <= 0;
            pwr_cont2_sp3_pwrok <= 1;
            seq_to_sp3_v1p8_en <= 0;
            pwr_cont1_sp3_pwrok <= 1;
            pwr_cont2_sp3_en <= 0;
            pwr_cont1_sp3_en <= 0;
            pwr_cont_dimm_abcd_en2 <=0;
            pwr_cont_dimm_abcd_en0 <= 0;
            pwr_cont_dimm_efgh_en1 <= 0;
            sp_to_sp3_pwr_btn_l <= 1;
            seq_to_vtt_efgh_en <= 0;
            seq_to_sp3_pwr_good <= 0;
            seq_to_vtt_abcd_a0_en <= 0;
            if (a0_en == 1) begin
                state <= PBTN;
            end
        endrule
        //  PWR_BTN_L asserted (timing rules = 15ms minimum, per AMD 55441.  go for 20)
        rule do_pwrbtn (state == PBTN && dbg_en == 0);
             sp_to_sp3_pwr_btn_l <= 0;
                if (a0_en == 0) begin
                    state <= IDLE;
                end else begin
                    if (delay_counter == 0) begin
                        state <= WAITSLP;
                    end else begin
                        delay_counter <= delay_counter - 1;
                    end
                end
        endrule
        //  SLP_S5_L and SLP_S3_L asserted (timing rules = 14ms minimum, 17ms maximum from pwrbtn-L)
        rule do_wait_for_slp (state == WAITSLP && dbg_en == 0);
            sp_to_sp3_pwr_btn_l <= 1;
            if (a0_en == 0) begin
                state <= IDLE;
            end else begin
                if ((cur_syncd_pins.sp3_to_sp_slp_s3 == 1 && cur_syncd_pins.sp3_to_sp_slp_s5 == 1) || ignore_sp == 1) begin
                    state <= GROUPB1_EN;
                end
            end
        endrule
        //  GroupB stage1 EN
        rule do_groupb1_en (state == GROUPB1_EN && dbg_en == 0);
            pwr_cont_dimm_abcd_en1 <= 1;
            pwr_cont_dimm_abcd_en0 <= 1;
            seq_to_sp3_v1p8_en <= 1;
            pwr_cont_dimm_efgh_en0 <= 1;
            if (a0_en == 0) begin
                state <= IDLE;
            end else begin
                state <= GROUPB1_PG;
            end
        endrule
        //  GroupB stage1 PG
        rule do_wait_groupb1_pg  (state == GROUPB1_PG && dbg_en == 0);
            if (a0_en == 0) begin
                state <= IDLE;
            end else begin
                if (cur_syncd_pins.pwr_cont_dimm_abcd_pg0 == 1 && cur_syncd_pins.pwr_cont_dimm_efgh_pg0 == 1) begin
                    state <= GROUPB2_EN;
                end
            end
        endrule
        //  GroupB stage 2 EN
        rule do_groupb2_en (state == GROUPB2_EN && dbg_en == 0);
            if (a0_en == 0) begin
                state <= IDLE;
            end else begin
                pwr_cont1_sp3_en <= 1;
                seq_to_vtt_abcd_a0_en <= 1;
                seq_to_vtt_efgh_en <= 1;
                pwr_cont2_sp3_en <= 1;
            end
        endrule
        //  GroupB stage 2 PG.  TODO: would like an interrupt exiting this case!
        rule do_wait_groupb2_pg  (state == GROUPB2_PG && dbg_en == 0);
        
            let stage1_ok = cur_syncd_pins.pwr_cont_dimm_abcd_pg0 == 1 && cur_syncd_pins.pwr_cont_dimm_efgh_pg0 == 1;
            let stage2_ok = cur_syncd_pins.pwr_cont1_sp3_pg0 == 1 && cur_syncd_pins.pwr_cont2_sp3_pg0 == 1 && cur_syncd_pins.vtt_abcd_a0_to_seq_pg == 1 && cur_syncd_pins.vtt_efgh_a0_to_seq_pg == 1;
            let unstaged_ok = cur_syncd_pins.pwr_cont_dimm_abcd_pg1 == 1 && cur_syncd_pins.seq_v1p8_sp3_vdd_pg == 1; 
            if (a0_en == 0) begin
                state <= IDLE;
            end else begin
                if (stage1_ok && stage2_ok && unstaged_ok) begin
                    state <= GROUPC_PG;
                end
            end

        endrule
        // //  GroupB checkpoint this stuff not currently used, depends on how power sequencing goes.
        // rule do_groupb_checkpoint;
        // endrule
        //  SP does RA229618 things via SMBUS
        // rule do_group_c_enable;
        // endrule
        //  GroupC STABLE, Current plan is to have the SP enable the RAA2219xx's
        // via SMBUS but we just fall through to wait for the PG. ST wants a timeout here.
        rule do_wait_groupc_pg (state == GROUPC_PG && dbg_en == 0);
            if (a0_en == 0) begin
                state <= IDLE;
            end else begin
                if (cur_syncd_pins.pwr_cont2_sp3_pg1 == 1 && cur_syncd_pins.pwr_cont2_sp3_pg1 == 1) begin
                    delay_counter <= fromInteger(50000);
                    state <= DELAY_1MS;
                end
            end
        endrule
        //  min 1 ms delay
        rule do_1ms_delay (state == DELAY_1MS && dbg_en == 0);
            if (a0_en == 0) begin
                state <= IDLE;
            end else begin
                if (delay_counter == 0) begin
                    state <= ASSERT_PG;
                end else begin
                    delay_counter <= delay_counter - 1;
                end
            end
        endrule
        // Assert power good.  We have min 10.2ms max 26.8ms to assert clks. 
        rule do_assert_power_good (state == ASSERT_PG && dbg_en == 0);
            seq_to_sp3_pwr_good <= 1;
            state <= WAIT_PWROK;
        endrule
        // AMD asserts PWROK (min 15ms max 20.4 ms from power good) 
        rule do_wait_amd_pwrok (state == WAIT_PWROK && dbg_en == 0);
            if (a0_en == 0) begin
                    state <= IDLE;
            end else begin
                if (cur_syncd_pins.sp3_to_seq_pwrok_v3p3 == 1) begin // AMD Power-ok
                    state <= WAIT_RESET_L;
                end
            end
        endrule
        // AMD de-asserts RESET_L (min 20.2 ms to 28.6ms max from power good)
        rule do_wait_amd_reset_l (state == WAIT_RESET_L && dbg_en == 0);
            if (a0_en == 0) begin
                    state <= IDLE;
            end else begin
                if (seq_to_sp3_sys_rst_l == 0) begin // AMD RESET_L
                    state <= DONE;
                end
            end
        endrule
        // A0 OK
        rule do_done (state == DONE && dbg_en == 0);
            if (a0_en == 0) begin
                state <= IDLE;
            end
        endrule

        rule do_pack_output_readbacks;
            cur_out_pins <= A0OutPinsStruct {
                seq_to_sp3_sys_rst: ~seq_to_sp3_sys_rst_l,
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
                seq_to_vtt_abcd_a0_en: seq_to_vtt_abcd_a0_en
            };
        endrule

        rule do_output_pins (dbg_en == 1);
            seq_to_sp3_sys_rst_l <= ~dbg_out_pins.seq_to_sp3_sys_rst;
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
            seq_to_vtt_abcd_a0_en <= dbg_out_pins.seq_to_vtt_abcd_a0_en;
        endrule

        method syncd_pins = cur_syncd_pins._write;
        interface A0Regs reg_if;
            method input_readbacks = cur_syncd_pins._read;
            method output_readbacks = cur_out_pins._read; // Output sampling
            method state = state._read;
            method dbg_ctrl = dbg_out_pins._write; // Output control
            method dbg_en = dbg_en._write;    // Debug enable pin
            method ignore_sp = ignore_sp._write;
            method a0_en = a0_en._write;
        endinterface
        interface A0OutputSource out_pins;
            method seq_to_sp3_sys_rst_l = seq_to_sp3_sys_rst_l._read;
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
            method seq_to_vtt_abcd_a0_en = seq_to_vtt_abcd_a0_en._read;
        endinterface
    endmodule

    interface TBTestA0PinsSource;
        interface Client#(Bit#(8), Bool) bfm;
        interface A0InputPinsRawSource pins;
    endinterface

    module mkTestA0PinsSource(TBTestA0PinsSource);
        Reg#(Bit#(1)) sp3_to_seq_pwrgd_out <- mkReg(0);
        Reg#(Bit#(1)) seq_to_sp3_sys_rst_l <- mkReg(0);
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
            method sp3_to_seq_pwrgd_out = sp3_to_seq_pwrgd_out._read;
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