package NicBlock;

import Clocks::*;
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

    instance Connectable#(NicOutputPinsRawSource, NicOutputPinsRawSink);
        module mkConnection#(NicOutputPinsRawSource source, NicOutputPinsRawSink sink) (Empty);
            mkConnection(source.seq_to_nic_v1p2_enet_en, sink.seq_to_nic_v1p2_enet_en);
            mkConnection(source.seq_to_nic_comb_pg, sink.seq_to_nic_comb_pg);
            mkConnection(source.pwr_cont_nic_en1, sink.pwr_cont_nic_en1);
            mkConnection(source.pwr_cont_nic_en0, sink.pwr_cont_nic_en0);
            mkConnection(source.seq_to_nic_cld_rst_l, sink.seq_to_nic_cld_rst_l);
            mkConnection(source.seq_to_nic_v1p5a_en, sink.seq_to_nic_v1p5a_en);
            mkConnection(source.seq_to_nic_v1p5d_en, sink.seq_to_nic_v1p5d_en);
            mkConnection(source.seq_to_nic_v1p2_en, sink.seq_to_nic_v1p2_en);
            mkConnection(source.seq_to_nic_v1p1_en, sink.seq_to_nic_v1p1_en);
            mkConnection(source.seq_to_nic_ldo_v3p3_en, sink.seq_to_nic_ldo_v3p3_en);
            mkConnection(source.nic_to_sp3_pwrflt_l, sink.nic_to_sp3_pwrflt_l);
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

    interface NicInputSync;
    interface NicInputPinsRawSink sink;
    interface NicInputPinsNormalizedSource source;
endinterface

module mkNicInputSync(NicInputSync);
    Clock clk_sys <- exposeCurrentClock();
    Reset rst_sys <- exposeCurrentReset();

    // Synchronizers
    SyncBitIfc#(Bit#(1)) pwr_cont_nic_pg0_sync <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
    SyncBitIfc#(Bit#(1)) pwr_cont_nic_nvrhot_sync <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
    SyncBitIfc#(Bit#(1)) pwr_cont_nic_cfp_sync <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
    SyncBitIfc#(Bit#(1)) nic_to_seq_v1p5a_pg_l_sync <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
    SyncBitIfc#(Bit#(1)) nic_to_seq_v1p5d_pg_l_sync <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
    SyncBitIfc#(Bit#(1)) nic_to_seq_v1p2_pg_l_sync <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
    SyncBitIfc#(Bit#(1)) nic_to_seq_v1p1_pg_l_sync <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
    SyncBitIfc#(Bit#(1)) pwr_cont_nic_pg1_sync <- mkSyncBit1(clk_sys, rst_sys, clk_sys);

    interface NicInputPinsRawSink sink;
        method pwr_cont_nic_pg0 = pwr_cont_nic_pg0_sync.send;
        method pwr_cont_nic_nvrhot = pwr_cont_nic_nvrhot_sync.send;
        method pwr_cont_nic_cfp = pwr_cont_nic_cfp_sync.send;
        method nic_to_seq_v1p5a_pg_l = nic_to_seq_v1p5a_pg_l_sync.send;
        method nic_to_seq_v1p5d_pg_l = nic_to_seq_v1p5d_pg_l_sync.send;
        method nic_to_seq_v1p2_pg_l = nic_to_seq_v1p2_pg_l_sync.send;
        method nic_to_seq_v1p1_pg_l = nic_to_seq_v1p1_pg_l_sync.send;
        method pwr_cont_nic_pg1 = pwr_cont_nic_pg1_sync.send;
    endinterface

    interface NicInputPinsNormalizedSource source;
        method pwr_cont_nic_pg0 = pwr_cont_nic_pg0_sync.read;
        method pwr_cont_nic_nvrhot = pwr_cont_nic_nvrhot_sync.read;
        method pwr_cont_nic_cfp = pwr_cont_nic_cfp_sync.read;
        method pwr_cont_nic_pg1 = pwr_cont_nic_pg1_sync.read;
        method nic_to_seq_v1p5d_pg = nic_to_seq_v1p5d_pg_l_sync.read;  // not actually active low
        method nic_to_seq_v1p5a_pg = nic_to_seq_v1p5a_pg_l_sync.read; // not actually active low
        method nic_to_seq_v1p2_pg = nic_to_seq_v1p2_pg_l_sync.read;  // not actually active low
        method nic_to_seq_v1p1_pg = nic_to_seq_v1p1_pg_l_sync.read; // not actually active low
        // Invert the active low signals
        // method Bit#(1) nic_to_seq_v1p5a_pg;
        //     return ~nic_to_seq_v1p5a_pg_l_sync.read();
        // endmethod
        // method Bit#(1) nic_to_seq_v1p5d_pg;
        //     return ~nic_to_seq_v1p5d_pg_l_sync.read();
        // endmethod
        // method Bit#(1) nic_to_seq_v1p2_pg;
        //     return ~nic_to_seq_v1p2_pg_l_sync.read();
        // endmethod
        // method Bit#(1) nic_to_seq_v1p1_pg;
        //     return ~nic_to_seq_v1p1_pg_l_sync.read();
        // endmethod
    endinterface

    endmodule

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

    interface NicRegs; // Interface at register block
        // Normalized pin readbacks to registers
        method NicStatus nic_status; 
        method OutStatusNic1 nic1_out_status;
        method OutStatusNic2 nic2_out_status;
        method NicStateType state;
        method Action nic_en(Bit#(1) value);  // SM enable pin
        method Action dbg_en(Bit#(1) value);
        method Action ignore_sp(Bool value);
        method Action dbg_nic1(DbgOutNic1 value);
        method Action dbg_nic2(DbgOutNic2 value);
    endinterface
    
    // "Reverse" Interface at register block
    interface NicRegsReverse;
        method Action nic_status (NicStatus value);
        method Action nic1_out_status (OutStatusNic1 value);
        method Action nic2_out_status (OutStatusNic2 value);
        method Action state (NicStateType value);
        method Bit#(1) nic_en;
        method Bit#(1) dbg_en;
        method Bool ignore_sp;

        method DbgOutNic1 dbg_nic1;
        method DbgOutNic2 dbg_nic2;
    endinterface
    

    interface NicBlockTop;
        interface NicRegs reg_if;
        interface NicInputPinsNormalizedSink syncd_pins;
        interface NicOutputPinsRawSource out_pins;
        method Action upstream_ok(Bool value);
    endinterface

     instance Connectable#(NicRegs, NicRegsReverse);
        module mkConnection#(NicRegs source, NicRegsReverse sink) (Empty);
            mkConnection(source.nic_status, sink.nic_status);
            mkConnection(source.nic1_out_status, sink.nic1_out_status);
            mkConnection(source.nic2_out_status, sink.nic2_out_status);
            mkConnection(source.nic_en, sink.nic_en);
            mkConnection(source.state, sink.state);
            mkConnection(source.dbg_nic1, sink.dbg_nic1);
            mkConnection(source.dbg_nic2, sink.dbg_nic2);
            mkConnection(source.dbg_en, sink.dbg_en);
            mkConnection(source.ignore_sp, sink.ignore_sp);
        endmodule
    endinstance

    typedef enum {
        IDLE = 'h00,
        DELAY0 = 'h01,
        STAGE0 = 'h02,
        STAGE0_PG = 'h03,
        DELAY = 'h04,
        DONE = 'h05
   
    } NicStateType deriving (Eq, Bits);

    module mkNicBlock#(Integer one_ms_counts)(NicBlockTop);
        // Output Registers
        Integer ten_ms_counts = 10 * one_ms_counts;
        Integer three_ms_counts = 3 * one_ms_counts;
        Integer thirty_ms_counts = 30 * one_ms_counts;
        Reg#(Bit#(1)) seq_to_nic_v1p2_enet_en <- mkReg(0);
        Reg#(Bit#(1)) seq_to_nic_comb_pg <- mkReg(1);
        Reg#(Bit#(1)) pwr_cont_nic_en1 <- mkReg(0);
        Reg#(Bit#(1)) pwr_cont_nic_en0 <- mkReg(0);
        Reg#(Bit#(1)) seq_to_nic_cld_rst_l <- mkReg(0);
        Reg#(Bit#(1)) seq_to_nic_v1p5a_en <- mkReg(0);
        Reg#(Bit#(1)) seq_to_nic_v1p5d_en <- mkReg(0);
        Reg#(Bit#(1)) seq_to_nic_v1p2_en <- mkReg(0);
        Reg#(Bit#(1)) seq_to_nic_v1p1_en <- mkReg(0);
        Reg#(Bit#(1)) seq_to_nic_ldo_v3p3_en <- mkReg(0);
        Reg#(Bit#(1)) nic_to_sp3_pwrflt_l <- mkReg(0);
        Reg#(NicStateType) state <- mkReg(IDLE);
        Reg#(Bool) faulted <- mkReg(False);
        Reg#(UInt#(24)) delay_counter <- mkReg(fromInteger(ten_ms_counts));

        Wire#(Bit#(1)) nic_en    <- mkDWire(0);
        Wire#(Bool) cur_upstream_ok <- mkDWire(False);

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
        Wire#(Bool) ignore_sp <- mkDWire(False);
        Wire#(DbgOutNic1) cur_dbg_nic1 <- mkDWire(unpack(0));
        Wire#(DbgOutNic2) cur_dbg_nic2 <- mkDWire(unpack(0));

        // Put all of the inputs into a NicStatus struct.
        // This is not registered but pushed over to the register block.
        rule do_nic_status;
            cur_nic_status <= NicStatus {
                nic_cfp: pwr_cont_nic_cfp,
                nic_nvrhot: ~pwr_cont_nic_nvrhot,
                nic_v1p8_pg: pwr_cont_nic_pg1,
                nic_v1p5_pg: nic_to_seq_v1p5d_pg & seq_to_nic_v1p5d_en,
                nic_av1p5_pg: nic_to_seq_v1p5a_pg & seq_to_nic_v1p5a_en,
                nic_v1p2_pg: nic_to_seq_v1p2_pg & seq_to_nic_v1p2_en,
                nic_v1p1_pg: nic_to_seq_v1p1_pg & seq_to_nic_v1p1_en,
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
                nic_comb_pg: ~seq_to_nic_comb_pg
            };
        endrule

        rule do_nic_power_idle (state == IDLE && dbg_en == 0);
            // Need upstream power for MAPO or to go
            // everyone is off.
            seq_to_nic_v1p2_enet_en <= 0;
            seq_to_nic_cld_rst_l <= 0;
            pwr_cont_nic_en0 <= 0;
            pwr_cont_nic_en1 <= 0;
            seq_to_nic_v1p5a_en <= 0;
            seq_to_nic_v1p5d_en <= 0;
            seq_to_nic_v1p2_en  <= 0;
            seq_to_nic_v1p1_en  <= 0;
            seq_to_nic_ldo_v3p3_en <= 0;
            seq_to_nic_comb_pg <= 1;
            nic_to_sp3_pwrflt_l <= 0;

            if (nic_en == 1 && !faulted && (cur_upstream_ok || ignore_sp) ) begin
                delay_counter <= fromInteger(three_ms_counts);
                state <= DELAY0;
            end
        endrule

        rule do_nic_delay0 (state == DELAY0 && dbg_en == 0);
            seq_to_nic_ldo_v3p3_en <= 1;
            if (nic_en == 1 && !faulted && (cur_upstream_ok || ignore_sp)) begin
                if (delay_counter > 0) begin
                    delay_counter <= delay_counter - 1;
                end else begin
                    state <= STAGE0;
                end
            end else begin
                state <= IDLE;
            end
        endrule

        rule do_nic_stage0 (state == STAGE0 && dbg_en == 0);
        // ISL68224 Enabled
        // LT3072(1) enabled, LT3072(2) enabled
        seq_to_nic_v1p2_enet_en <= 1;
        pwr_cont_nic_en0 <= 1;
        pwr_cont_nic_en1 <= 1;
        seq_to_nic_v1p5a_en <= 1;
        seq_to_nic_v1p5d_en <= 1;
        seq_to_nic_v1p2_en  <= 1;
        seq_to_nic_v1p1_en  <= 1;
            if (nic_en == 1 && !faulted && (cur_upstream_ok || ignore_sp)) begin
                state <= STAGE0_PG;
            end
        endrule

        rule do_nic_stage0_pg (state == STAGE0_PG && dbg_en == 0);
            if (nic_en == 1 && !faulted && cur_upstream_ok) begin
                if (pwr_cont_nic_pg1 == 1 && nic_to_seq_v1p5d_pg == 1 &&
                    nic_to_seq_v1p5a_pg == 1 && nic_to_seq_v1p2_pg == 1 &&
                    nic_to_seq_v1p1_pg == 1 && pwr_cont_nic_pg0 == 1) begin
                    // TODO: need clock stable PIO here too!!
                    state <= DELAY;
                    delay_counter <= fromInteger(thirty_ms_counts);
                end
            end else begin
                state <= IDLE;
            end
        endrule

        rule do_nic_delay (state == DELAY && dbg_en == 0);
            seq_to_nic_comb_pg <= 0;
            if (nic_en == 1 && !faulted && (cur_upstream_ok || ignore_sp)) begin
                if (delay_counter > 0) begin
                    delay_counter <= delay_counter - 1;
                end else begin
                    state <= DONE;
                end
            end else begin
                state <= IDLE;
            end
        endrule

        rule do_nic_done (state == DONE && dbg_en == 0);
          seq_to_nic_cld_rst_l <= ~cur_dbg_nic2.nic_cld_rst;
            if (nic_en == 0 || faulted || !(cur_upstream_ok || ignore_sp)) begin
                state <= IDLE;
            end
        endrule

        rule do_dbg_output_pins(dbg_en == 1);
            // For now, there are no sm outputs so dbg status goes to pins.
            seq_to_nic_v1p2_enet_en <= cur_dbg_nic1.nic_v1p2_eth_en;
            seq_to_nic_comb_pg <= ~cur_dbg_nic2.nic_comb_pg;
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

        interface NicRegs reg_if;
            method nic_status = cur_nic_status._read;
            method nic1_out_status = cur_nic1_out_status._read;
            method nic2_out_status = cur_nic2_out_status._read;
            method dbg_en = dbg_en._write;
            method ignore_sp = ignore_sp._write;
            method state = state._read;
            method dbg_nic1 = cur_dbg_nic1._write;
            method dbg_nic2 = cur_dbg_nic2._write;
            method nic_en = nic_en._write;
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

        method upstream_ok = cur_upstream_ok._write;
    endmodule


     interface TBTestNicPinsSource;
        interface Client#(Bit#(8), Bool) bfm;
        interface NicInputPinsRawSource tb_pins_src;
        interface NicOutputPinsRawSink tb_pins_sink;
    endinterface

    module mkTestNicPinsSource(TBTestNicPinsSource);
        Reg#(Bit#(1)) seq_to_nic_v1p2_enet_en <- mkReg(0);
        Reg#(Bit#(1)) seq_to_nic_comb_pg <- mkReg(1);
        Reg#(Bit#(1)) pwr_cont_nic_en1 <- mkReg(0);
        Reg#(Bit#(1)) pwr_cont_nic_en0 <- mkReg(0);
        Reg#(Bit#(1)) seq_to_nic_cld_rst_l <- mkReg(0);
        Reg#(Bit#(1)) seq_to_nic_v1p5a_en <- mkReg(0);
        Reg#(Bit#(1)) seq_to_nic_v1p5d_en <- mkReg(0);
        Reg#(Bit#(1)) seq_to_nic_v1p2_en <- mkReg(0);
        Reg#(Bit#(1)) seq_to_nic_v1p1_en <- mkReg(0);
        Reg#(Bit#(1)) seq_to_nic_ldo_v3p3_en <- mkReg(0);
        Reg#(Bit#(1)) nic_to_sp3_pwrflt_l <- mkReg(0);

        Reg#(Bit#(1)) pwr_cont_nic_pg0 <- mkReg(0);
        Reg#(Bit#(1)) pwr_cont_nic_nvrhot <- mkReg(0);
        Reg#(Bit#(1)) pwr_cont_nic_cfp <- mkReg(0);
        Reg#(Bit#(1)) nic_to_seq_v1p5a_pg_l <- mkReg(0);
        Reg#(Bit#(1)) nic_to_seq_v1p5d_pg_l <- mkReg(0);
        Reg#(Bit#(1)) nic_to_seq_v1p2_pg_l <- mkReg(0);
        Reg#(Bit#(1)) nic_to_seq_v1p1_pg_l <- mkReg(0);
        Reg#(Bit#(1)) pwr_cont_nic_pg1 <- mkReg(0);

        rule do_sunny_day;
            pwr_cont_nic_pg0 <= pwr_cont_nic_en0;
            pwr_cont_nic_pg1 <= pwr_cont_nic_en1;
            nic_to_seq_v1p5a_pg_l <= seq_to_nic_v1p5a_en;
            nic_to_seq_v1p5d_pg_l <= seq_to_nic_v1p5d_en;
            nic_to_seq_v1p2_pg_l <= seq_to_nic_v1p2_en;
            nic_to_seq_v1p1_pg_l <= seq_to_nic_v1p1_en;
        endrule

        interface NicInputPinsRawSource tb_pins_src;
            method pwr_cont_nic_pg0 = pwr_cont_nic_pg0._read;
            method pwr_cont_nic_nvrhot = pwr_cont_nic_nvrhot._read;
            method pwr_cont_nic_cfp = pwr_cont_nic_cfp._read;
            method nic_to_seq_v1p5a_pg_l = nic_to_seq_v1p5a_pg_l._read;
            method nic_to_seq_v1p5d_pg_l = nic_to_seq_v1p5d_pg_l._read;
            method nic_to_seq_v1p2_pg_l = nic_to_seq_v1p2_pg_l._read;
            method nic_to_seq_v1p1_pg_l = nic_to_seq_v1p1_pg_l._read;
            method pwr_cont_nic_pg1 = pwr_cont_nic_pg1._read;
        endinterface
        interface NicOutputPinsRawSink tb_pins_sink;
            method seq_to_nic_v1p2_enet_en = seq_to_nic_v1p2_enet_en._write;
            method seq_to_nic_comb_pg = seq_to_nic_comb_pg._write;
            method pwr_cont_nic_en1 = pwr_cont_nic_en1._write;
            method pwr_cont_nic_en0 = pwr_cont_nic_en0._write;
            method seq_to_nic_cld_rst_l = seq_to_nic_cld_rst_l._write;
            method seq_to_nic_v1p5a_en = seq_to_nic_v1p5a_en._write;
            method seq_to_nic_v1p5d_en = seq_to_nic_v1p5d_en._write;
            method seq_to_nic_v1p2_en = seq_to_nic_v1p2_en._write;
            method seq_to_nic_v1p1_en = seq_to_nic_v1p1_en._write;
            method seq_to_nic_ldo_v3p3_en = seq_to_nic_ldo_v3p3_en._write;
            method nic_to_sp3_pwrflt_l = nic_to_sp3_pwrflt_l._write;
        endinterface
        interface Client bfm;
            interface Get request;
            endinterface
            interface Put response;
            endinterface
        endinterface
    endmodule

endpackage