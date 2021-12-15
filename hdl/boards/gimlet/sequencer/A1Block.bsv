package A1Block;

import Clocks::*;
import ClientServer::*;
import Connectable::*;
import GetPut::*;
import GimletSeqFpgaRegs::*;

    // Interface for output pins
    interface A1OutputSource;
        method Bit#(1) seq_to_sp3_v3p3_s5_en;
        method Bit#(1) seq_to_sp3_v1p5_rtc_en;
        method Bit#(1) seq_to_sp3_v1p8_s5_en;
        method Bit#(1) seq_to_sp3_v0p9_s5_en;
        method Bit#(1) seq_to_sp3_rsmrst_v3p3_l;
    endinterface

    // Sinking output pins interface (for testbenches etc)
    interface A1OutputSink;
        method Action seq_to_sp3_v3p3_s5_en(Bit#(1) value);
        method Action seq_to_sp3_v1p5_rtc_en(Bit#(1) value);
        method Action seq_to_sp3_v1p8_s5_en(Bit#(1) value);
        method Action seq_to_sp3_v0p9_s5_en(Bit#(1) value);
        method Action seq_to_sp3_rsmrst_v3p3_l(Bit#(1) value);
    endinterface

    // Allow our output pin source to connect to our output pin sink
    instance Connectable#(A1OutputSource, A1OutputSink);
        module mkConnection#(A1OutputSource source, A1OutputSink sink) (Empty);
            mkConnection(source.seq_to_sp3_v3p3_s5_en, sink.seq_to_sp3_v3p3_s5_en);
            mkConnection(source.seq_to_sp3_v1p5_rtc_en, sink.seq_to_sp3_v1p5_rtc_en);
            mkConnection(source.seq_to_sp3_v1p8_s5_en, sink.seq_to_sp3_v1p8_s5_en);
            mkConnection(source.seq_to_sp3_v0p9_s5_en, sink.seq_to_sp3_v0p9_s5_en);
            mkConnection(source.seq_to_sp3_rsmrst_v3p3_l, sink.seq_to_sp3_rsmrst_v3p3_l);
        endmodule
    endinstance

    // Interface for input pins
    interface A1InputPinsRawSink;
        (* prefix = "" *)
        method Action sp3_to_seq_v1p8_s5_pg((*port = "sp3_to_seq_v1p8_s5_pg" *) Bit#(1) value);
        (* prefix = "" *)
        method Action sp3_to_seq_rtc_v1p5_en((*port = "sp3_to_seq_rtc_v1p5_en" *) Bit#(1) value);
        (* prefix = "" *)
        method Action sp3_to_seq_v3p3_s5_pg((*port = "sp3_to_seq_v3p3_s5_pg" *) Bit#(1) value);
        (* prefix = "" *)
        method Action sp3_to_seq_v0p9_vdd_soc_s5_pg((*port = "sp3_to_seq_v0p9_vdd_soc_s5_pg" *) Bit#(1) value);
    endinterface
    // Sourcing input pins (for testbenches etc)
    interface A1InputPinsRawSource;
        method Bit#(1) sp3_to_seq_v1p8_s5_pg;
        method Bit#(1) sp3_to_seq_rtc_v1p5_en;
        method Bit#(1) sp3_to_seq_v3p3_s5_pg;
        method Bit#(1) sp3_to_seq_v0p9_vdd_soc_s5_pg;
    endinterface
    // Allow our input pin source to connect to our input pin sink
    instance Connectable#(A1InputPinsRawSource, A1InputPinsRawSink);
        module mkConnection#(A1InputPinsRawSource source, A1InputPinsRawSink sink) (Empty);
            mkConnection(source.sp3_to_seq_v1p8_s5_pg, sink.sp3_to_seq_v1p8_s5_pg);
            mkConnection(source.sp3_to_seq_rtc_v1p5_en, sink.sp3_to_seq_rtc_v1p5_en);
            mkConnection(source.sp3_to_seq_v3p3_s5_pg, sink.sp3_to_seq_v3p3_s5_pg);
            mkConnection(source.sp3_to_seq_v0p9_vdd_soc_s5_pg, sink.sp3_to_seq_v0p9_vdd_soc_s5_pg);
        endmodule
    endinstance
    // Synchronizer interface, pins in, syncd_pins struct out
    interface A1InputSyncBlock;
        interface A1InputPinsRawSink in_pins;
        method A1Readbacks syncd_pins;
    endinterface

    // Interface at this block to the register block
    interface A1Regs;
        // Normalized pin readbacks to registers
        method A1Readbacks input_readbacks; // Input sampling
        method A1OutStatus output_readbacks; // Output sampling
        method A1StateType state;
        method Action dbg_ctrl(A1DbgOut value); // Output control
        method Action dbg_en(Bit#(1) value);    // Debug enable pin
        method Action a1_en(Bit#(1) value);  // SM enable pin
    endinterface

    // "Reverse" Interface at register block
    interface A1RegsReverse;
        // Normalized pin readbacks to registers
        method Action input_readbacks(A1Readbacks value); // Input sampling
        method Action output_readbacks(A1OutStatus value); // Output sampling
        method Action state(A1StateType value);
        method A1DbgOut dbg_ctrl; // Output control
        method Bit#(1) dbg_en;    // Debug enable pin
        method Bit#(1) a1_en;    // SM enable pin
    endinterface

    // Allow register block interfaces to connect
    instance Connectable#(A1Regs, A1RegsReverse);
        module mkConnection#(A1Regs source, A1RegsReverse sink) (Empty);
            mkConnection(source.input_readbacks, sink.input_readbacks);
            mkConnection(source.output_readbacks, sink.output_readbacks);
            mkConnection(source.dbg_ctrl, sink.dbg_ctrl);
            mkConnection(source.state, sink.state);
            mkConnection(source.dbg_en, sink.dbg_en);
            mkConnection(source.a1_en, sink.a1_en);
        endmodule
    endinstance

    // Interface for Block top (syncd pins in, pins out, register if)
    interface A1BlockTop;
        method Action syncd_pins(A1Readbacks value);
        method Action a0_idle(Bool value);
        method Bool a1_ok;
        interface A1Regs reg_if;
        interface A1OutputSource out_pins;
    endinterface

    // Input synchronization module (pins -> syncs -> structs)
    module mkA1Sync(A1InputSyncBlock);
        Clock clk_sys <- exposeCurrentClock();
        Reset rst_sys <- exposeCurrentReset();

        // Synchronizers
        SyncBitIfc#(Bit#(1)) sp3_to_seq_v1p8_s5_pg <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
        SyncBitIfc#(Bit#(1)) sp3_to_seq_rtc_v1p5_en <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
        SyncBitIfc#(Bit#(1)) sp3_to_seq_v3p3_s5_pg <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
        SyncBitIfc#(Bit#(1)) sp3_to_seq_v0p9_vdd_soc_s5_pg <- mkSyncBit1(clk_sys, rst_sys, clk_sys);

        // Output combo
        Wire#(A1Readbacks) cur_syncd_pins <- mkDWire(unpack(0));

        // Put sync'd bits into a combo structure to make passing it around easier
        rule do_structurize;
            cur_syncd_pins <= A1Readbacks {
                v0p9_vdd_soc_s5_pg: sp3_to_seq_v0p9_vdd_soc_s5_pg.read(),
                v1p8_s5_pg: sp3_to_seq_v1p8_s5_pg.read(),
                v3p3_s5_pg: sp3_to_seq_v3p3_s5_pg.read(),
                v1p5_rtc_pg: sp3_to_seq_rtc_v1p5_en.read()
            };
        endrule

        interface A1InputPinsRawSink in_pins;
            method sp3_to_seq_v1p8_s5_pg = sp3_to_seq_v1p8_s5_pg.send;
            method sp3_to_seq_rtc_v1p5_en = sp3_to_seq_rtc_v1p5_en.send;
            method sp3_to_seq_v3p3_s5_pg = sp3_to_seq_v3p3_s5_pg.send;
            method sp3_to_seq_v0p9_vdd_soc_s5_pg = sp3_to_seq_v0p9_vdd_soc_s5_pg.send;
        endinterface
        
        method syncd_pins = cur_syncd_pins._read;
    endmodule
    
    typedef enum {
        IDLE,   // 0x00
        ENABLE, // 0x01
        WAITPG, // 0x02
        DELAY,  // 0x03
        DONE_DELAY, // 0x04
        DONE,    // 0x05
        SAFE_DISABLE // 0x06
    } A1StateType deriving (Eq, Bits);
    

    // Block top module
    module mkA1Block(A1BlockTop);
        Integer one_ms_counts = 50000;  // 1ms
        Integer delay_counts = 200 * one_ms_counts;  //50 * one_ms_counts;

        // State register
        Reg#(A1StateType) state <- mkReg(IDLE);
        Reg#(UInt#(24)) delay_counter <- mkReg(fromInteger(delay_counts));  // 10ms @50MHz TODO: make this a constant
        // Output registers
        Reg#(Bit#(1)) seq_to_sp3_v3p3_s5_en <- mkReg(0);
        Reg#(Bit#(1)) seq_to_sp3_v1p5_rtc_en <- mkReg(0);
        Reg#(Bit#(1)) seq_to_sp3_v1p8_s5_en <- mkReg(0);
        Reg#(Bit#(1)) seq_to_sp3_v0p9_s5_en <- mkReg(0);
        Reg#(Bit#(1)) seq_to_sp3_rsmrst_v3p3_l <- mkReg(1);
        Reg#(A1Readbacks) expected_pgs <- mkReg(unpack(0));
        // Combo output readback
        Wire#(A1OutStatus) cur_out_pins <- mkDWire(unpack(0));

        // Combo input wires
        Wire#(A1Readbacks) cur_syncd_pins <- mkDWire(unpack(0));
        Wire#(Bool) cur_a0_idle <- mkDWire(False);
        Wire#(A1DbgOut) dbg_out_pins <- mkDWire(unpack(0));
        Wire#(Bit#(1)) dbg_en   <- mkDWire(0);
        Wire#(Bit#(1)) a1_en <- mkDWire(0);
        Wire#(Bool) pg_fault    <- mkDWire(False);

       
        
        rule do_pack_output_readbacks;
            cur_out_pins <= A1OutStatus {
                rsmrst : ~seq_to_sp3_rsmrst_v3p3_l,
                v0p9_s5_en : seq_to_sp3_v0p9_s5_en,
                v1p8_s5_en : seq_to_sp3_v1p8_s5_en,
                v1p5_rtc_en: seq_to_sp3_v1p5_rtc_en,
                v3p3_s5_en : seq_to_sp3_v3p3_s5_en
            };
        endrule

        // part of mutually-assured-power-off (MAPO) for this domain.
        // State machine below will update expected_pgs when appropriate
        // if we're missing expected PGs we set pg_fault which will cause the state machine to
        // transition back to IDLE (and disable all domain supplies) due to the error.
        rule monitor_expected;
            let masked_pgs = unpack(pack(cur_syncd_pins) & pack(expected_pgs));
            if (a1_en == 0) begin  // Clear flag when enable 0'd
                pg_fault <= False;
            end else begin
                pg_fault <= masked_pgs != expected_pgs;
            end
        endrule

        rule do_sm_idle (state == IDLE && dbg_en == 0);
            delay_counter <= fromInteger(delay_counts);
            expected_pgs <= unpack(0);
            seq_to_sp3_v3p3_s5_en <= 0;
            seq_to_sp3_v1p5_rtc_en <= 1;
            seq_to_sp3_v1p8_s5_en <= 0;
            seq_to_sp3_v0p9_s5_en <= 0;
            seq_to_sp3_rsmrst_v3p3_l <= 0;
            if (a1_en == 1 && !pg_fault) begin
                state <= ENABLE;
            end 
        endrule
        // Enable all rails in parallel
        rule do_enable (state == ENABLE && dbg_en == 0);
            seq_to_sp3_v3p3_s5_en <= 1;
            seq_to_sp3_v1p5_rtc_en <= 1;
            seq_to_sp3_v1p8_s5_en <= 1;
            seq_to_sp3_v0p9_s5_en <= 1;
            if (a1_en == 0 || pg_fault) begin
                state <= IDLE;
            end else begin
                state <= WAITPG;
            end
        endrule
        // Wait for all PGs (Group A Stable)
        rule do_enable_pg (state == WAITPG && dbg_en == 0);
            let all_pg_good = A1Readbacks {
                v0p9_vdd_soc_s5_pg: 1,
                v1p8_s5_pg: 1,
                v3p3_s5_pg: 1,
                v1p5_rtc_pg: 1
            };
            if (a1_en == 0 || pg_fault) begin
                state <= IDLE;
            end else begin
                if (cur_syncd_pins == all_pg_good) begin
                    state <= DELAY;
                    expected_pgs <= all_pg_good;
                end
            end

        endrule
        // delay 
        rule do_delay (state == DELAY && dbg_en == 0);
            if (a1_en == 0 || pg_fault) begin
                state <= IDLE;
            end else begin
                if (delay_counter == 1) begin
                    delay_counter <= fromInteger(delay_counts);
                    state <= DONE_DELAY;
                end else begin
                    delay_counter <= delay_counter - 1;
                end
            end
        endrule
        // RSMRST_L deasserted.
        rule do_done_delay (state == DONE_DELAY && dbg_en == 0);
            seq_to_sp3_rsmrst_v3p3_l <= 1;
            if (a1_en == 0 || pg_fault) begin
                state <= IDLE;
            end else begin
                state <= DONE;
            end
        endrule
        // Done state
        rule do_done (state == DONE && dbg_en == 0);
            if (a1_en == 0 || pg_fault) begin
                state <= SAFE_DISABLE;
            end
        endrule
        //Going down state
        rule do_stafe_disable (state == SAFE_DISABLE);
            if (cur_a0_idle) begin
                state <= IDLE;
            end
        endrule

        rule do_output_pins (dbg_en == 1);
            seq_to_sp3_v3p3_s5_en <= dbg_out_pins.v3p3_s5_en;
            seq_to_sp3_v1p5_rtc_en <= dbg_out_pins.v1p5_rtc_en;
            seq_to_sp3_v1p8_s5_en <= dbg_out_pins.v1p8_s5_en;
            seq_to_sp3_v0p9_s5_en <= dbg_out_pins.v0p9_s5_en;
            seq_to_sp3_rsmrst_v3p3_l <= ~dbg_out_pins.rsmrst;
        endrule

        method syncd_pins = cur_syncd_pins._write;
        method Bool a1_ok();
            return (state == DONE || state == SAFE_DISABLE);
        endmethod
        method a0_idle = cur_a0_idle._write;
        interface A1Regs reg_if;
            method input_readbacks = cur_syncd_pins._read; // Input sampling
            method output_readbacks = cur_out_pins._read; // Output sampling
            method state = state._read;
            method dbg_ctrl = dbg_out_pins._write; // Output control
            method dbg_en = dbg_en._write;    // Debug enable pin
            method a1_en = a1_en._write;
        endinterface
        interface A1OutputSource out_pins;
            method seq_to_sp3_rsmrst_v3p3_l = seq_to_sp3_rsmrst_v3p3_l._read;
            method seq_to_sp3_v3p3_s5_en = seq_to_sp3_v3p3_s5_en._read;
            method seq_to_sp3_v1p5_rtc_en = seq_to_sp3_v1p5_rtc_en._read;
            method seq_to_sp3_v1p8_s5_en = seq_to_sp3_v1p8_s5_en._read;
            method seq_to_sp3_v0p9_s5_en = seq_to_sp3_v0p9_s5_en._read;
        endinterface
    endmodule
    
    interface TBTestA1PinsSource;
        interface Client#(Bit#(8), Bool) bfm;
        interface A1OutputSink tb_pins_sink;
        interface A1InputPinsRawSource tb_pins_src;
    endinterface

    // This is a nominal bus-functional model for A1 power signals.  Currently deals with sunny-day sequencing scenarios and has no out-of-band control
    module mkTestA1PinsSource(TBTestA1PinsSource);
        Reg#(Bit#(1)) seq_to_sp3_v3p3_s5_en <- mkReg(0);
        Reg#(Bit#(1)) seq_to_sp3_v1p5_rtc_en <- mkReg(0);
        Reg#(Bit#(1)) seq_to_sp3_v1p8_s5_en <- mkReg(0);
        Reg#(Bit#(1)) seq_to_sp3_v0p9_s5_en <- mkReg(0);
        Reg#(Bit#(1)) seq_to_sp3_rsmrst_v3p3_l <- mkReg(0);
        

        Reg#(Bit#(1)) sp3_to_seq_v1p8_s5_pg <- mkReg(0);
        Reg#(Bit#(1)) sp3_to_seq_rtc_v1p5_en <- mkReg(0);
        Reg#(Bit#(1)) sp3_to_seq_v3p3_s5_pg <- mkReg(0);
        Reg#(Bit#(1)) sp3_to_seq_v0p9_vdd_soc_s5_pg <- mkReg(0);

        // Currently a dumb rule that wraps enables back to PG
        rule do_enable_to_pg;
            sp3_to_seq_v1p8_s5_pg <= seq_to_sp3_v1p8_s5_en;
            sp3_to_seq_rtc_v1p5_en <= sp3_to_seq_rtc_v1p5_en;
            sp3_to_seq_v3p3_s5_pg <= seq_to_sp3_v3p3_s5_en;
            sp3_to_seq_v0p9_vdd_soc_s5_pg <= seq_to_sp3_v0p9_s5_en;
        endrule

        interface A1OutputSink tb_pins_sink;
            method seq_to_sp3_v3p3_s5_en = seq_to_sp3_v3p3_s5_en._write;
            method seq_to_sp3_v1p5_rtc_en = seq_to_sp3_v1p5_rtc_en._write;
            method seq_to_sp3_v1p8_s5_en = seq_to_sp3_v1p8_s5_en._write;
            method seq_to_sp3_v0p9_s5_en = seq_to_sp3_v0p9_s5_en._write;
            method seq_to_sp3_rsmrst_v3p3_l = seq_to_sp3_rsmrst_v3p3_l._write;
        endinterface
        interface A1InputPinsRawSource tb_pins_src;
            method sp3_to_seq_v1p8_s5_pg = sp3_to_seq_v1p8_s5_pg._read;
            method sp3_to_seq_rtc_v1p5_en = sp3_to_seq_rtc_v1p5_en._read;
            method sp3_to_seq_v3p3_s5_pg = sp3_to_seq_v3p3_s5_pg._read;
            method sp3_to_seq_v0p9_vdd_soc_s5_pg = sp3_to_seq_v0p9_vdd_soc_s5_pg._read;
        endinterface
        interface Client bfm;
            interface Get request;
            endinterface
            interface Put response;
            endinterface
        endinterface
    endmodule
endpackage