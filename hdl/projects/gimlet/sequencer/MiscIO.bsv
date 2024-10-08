package MiscIO;

import Clocks::*;
import ClientServer::*;
import Connectable::*;
import GetPut::*;
import GimletSeqFpgaRegs::*;

    // Interface for output pins
    interface MiscOutputSource;
        method Bit#(1) clk_to_seq_nmr_l;
        method Bit#(1) testpoint;
    endinterface
    typedef struct {
        Bit#(1) clk_to_seq_nmr;
    } MiscOutPinsStruct deriving(Bits);
    // Interface for input pins
    interface MiscInputPinsRawSink;
        (* prefix = "" *)
        method Action sp3_to_seq_thermtrip_l((* port = "sp3_to_seq_thermtrip_l" *) Bit#(1) value);
        (* prefix = "" *)
        method Action sp3_to_seq_fsr_req_l((* port = "sp3_to_seq_fsr_req_l" *) Bit#(1) value);
        (* prefix = "" *)
        method Action seq_to_clk_gpio3((* port = "seq_to_clk_gpio3" *) Bit#(1) value);
        (* prefix = "" *)
        method Action seq_to_clk_gpio9((* port = "seq_to_clk_gpio9" *) Bit#(1) value);
        (* prefix = "" *)
        method Action seq_to_clk_gpio8((* port = "seq_to_clk_gpio8" *) Bit#(1) value);
        (* prefix = "" *)
        method Action seq_to_clk_gpio2((* port = "seq_to_clk_gpio2" *) Bit#(1) value);
        (* prefix = "" *)
        method Action seq_to_clk_gpio1((* port = "seq_to_clk_gpio1" *) Bit#(1) value);
        (* prefix = "" *)
        method Action seq_to_clk_gpio5((* port = "seq_to_clk_gpio5" *) Bit#(1) value);
        (* prefix = "" *)
        method Action seq_to_clk_gpio4((* port = "seq_to_clk_gpio4" *) Bit#(1) value);
    endinterface
    // Sourcing input pins (for testbenches etc)
    interface MiscInputPinsRawSource;
        method Bit#(1) sp3_to_seq_thermtrip_l;
        method Bit#(1) sp3_to_seq_fsr_req_l;
        method Bit#(1) seq_to_clk_gpio3;
        method Bit#(1) seq_to_clk_gpio9;
        method Bit#(1) seq_to_clk_gpio8;
        method Bit#(1) seq_to_clk_gpio2;
        method Bit#(1) seq_to_clk_gpio1;
        method Bit#(1) seq_to_clk_gpio5;
        method Bit#(1) seq_to_clk_gpio4;
    endinterface
    typedef struct {
        Bit#(1) sp3_to_seq_thermtrip;
        Bit#(1) sp3_to_seq_fsr_req;
        Bit#(1) seq_to_clk_gpio3;
        Bit#(1) seq_to_clk_gpio9;
        Bit#(1) seq_to_clk_gpio8;
        Bit#(1) seq_to_clk_gpio2;
        Bit#(1) seq_to_clk_gpio1;
        Bit#(1) seq_to_clk_gpio5;
        Bit#(1) seq_to_clk_gpio4;
    } MiscInPinsStruct deriving (Bits);
    typedef struct {
        Bit#(1) sp3_to_seq_thermtrip_l;
        Bit#(1) sp3_to_seq_fsr_req_l;
        Bit#(1) seq_to_clk_gpio3;
        Bit#(1) seq_to_clk_gpio9;
        Bit#(1) seq_to_clk_gpio8;
        Bit#(1) seq_to_clk_gpio2;
        Bit#(1) seq_to_clk_gpio1;
        Bit#(1) seq_to_clk_gpio5;
        Bit#(1) seq_to_clk_gpio4;
    } MiscInPinsRawStruct deriving (Bits);
    // Allow our input pin source to connect to our input pin sink
    instance Connectable#(MiscInputPinsRawSource, MiscInputPinsRawSink);
        module mkConnection#(MiscInputPinsRawSource source, MiscInputPinsRawSink sink) (Empty);
            mkConnection(source.sp3_to_seq_thermtrip_l, sink.sp3_to_seq_thermtrip_l);
            mkConnection(source.sp3_to_seq_fsr_req_l, sink.sp3_to_seq_fsr_req_l);
            mkConnection(source.seq_to_clk_gpio3, sink.seq_to_clk_gpio3);
            mkConnection(source.seq_to_clk_gpio9, sink.seq_to_clk_gpio9);
            mkConnection(source.seq_to_clk_gpio8, sink.seq_to_clk_gpio8);
            mkConnection(source.seq_to_clk_gpio2, sink.seq_to_clk_gpio2);
            mkConnection(source.seq_to_clk_gpio1, sink.seq_to_clk_gpio1);
            mkConnection(source.seq_to_clk_gpio5, sink.seq_to_clk_gpio5);
            mkConnection(source.seq_to_clk_gpio4, sink.seq_to_clk_gpio4);
        endmodule
    endinstance

    // Synchronizer interface, pins in, syncd_pins struct out
     interface MiscInputSyncBlock;
        interface MiscInputPinsRawSink in_pins;
        method MiscInPinsStruct syncd_pins;
    endinterface
    // Interface at this block to the register block
    interface MiscRegs;
        // Normalized pin readbacks to registers
        method MiscInPinsStruct input_readbacks; // Input sampling  TODO: want a function to return register types
        method MiscOutPinsStruct output_readbacks; // Output sampling
        method Action dbg_ctrl(MiscOutPinsStruct value); // Output control
        method Action dbg_en(Bit#(1) value);    // Debug enable pin
    endinterface
    // "Reverse" Interface at register block
    interface MiscRegsReverse;
        // Normalized pin readbacks to registers
        method Action input_readbacks(MiscInPinsStruct value); // Input sampling
        method Action output_readbacks(MiscOutPinsStruct value); // Output sampling
        method MiscOutPinsStruct dbg_ctrl; // Output control
        method Bit#(1) dbg_en;    // Debug enable pin
    endinterface
    // Allow register block interfaces to connect
    instance Connectable#(MiscRegs, MiscRegsReverse);
        module mkConnection#(MiscRegs source, MiscRegsReverse sink) (Empty);
            mkConnection(source.input_readbacks, sink.input_readbacks);
            mkConnection(source.output_readbacks, sink.output_readbacks);
            mkConnection(source.dbg_ctrl, sink.dbg_ctrl);
            mkConnection(source.dbg_en, sink.dbg_en);
        endmodule
    endinstance
    // Block top (syncd pins in, pins out, register if)
    interface MiscBlockTop;
        method Action syncd_pins(MiscInPinsStruct value);
        interface MiscRegs reg_if;
        interface MiscOutputSource out_pins;
        method Bool thermtrip;
    endinterface
    // Input synchronization module (pins -> syncs -> structs)
    module mkMiscSync(MiscInputSyncBlock);
        Clock clk_sys <- exposeCurrentClock();
        Reset rst_sys <- exposeCurrentReset();

        // Synchronizers
        SyncBitIfc#(Bit#(1)) sp3_to_seq_thermtrip_l <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
        SyncBitIfc#(Bit#(1)) sp3_to_seq_fsr_req_l <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
        SyncBitIfc#(Bit#(1)) seq_to_clk_gpio3 <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
        SyncBitIfc#(Bit#(1)) seq_to_clk_gpio9 <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
        SyncBitIfc#(Bit#(1)) seq_to_clk_gpio8 <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
        SyncBitIfc#(Bit#(1)) seq_to_clk_gpio2 <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
        SyncBitIfc#(Bit#(1)) seq_to_clk_gpio1 <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
        SyncBitIfc#(Bit#(1)) seq_to_clk_gpio5 <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
        SyncBitIfc#(Bit#(1)) seq_to_clk_gpio4 <- mkSyncBit1(clk_sys, rst_sys, clk_sys);

        // Output combo
        Wire#(MiscInPinsStruct) cur_syncd_pins <- mkDWire(unpack(0));
            
        // Put sync'd bits into a combo structure to make passing it around easier
        rule do_structurize;
            cur_syncd_pins <= MiscInPinsStruct {
                sp3_to_seq_thermtrip: ~sp3_to_seq_thermtrip_l.read(),
                sp3_to_seq_fsr_req: ~sp3_to_seq_fsr_req_l.read(),
                seq_to_clk_gpio3: seq_to_clk_gpio3.read(),
                seq_to_clk_gpio9: seq_to_clk_gpio9.read(),
                seq_to_clk_gpio8: seq_to_clk_gpio8.read(),
                seq_to_clk_gpio2: seq_to_clk_gpio2.read(),
                seq_to_clk_gpio1: seq_to_clk_gpio1.read(),
                seq_to_clk_gpio5: seq_to_clk_gpio5.read(),
                seq_to_clk_gpio4: seq_to_clk_gpio4.read()
            };
        endrule

        interface MiscInputPinsRawSink in_pins;
            method sp3_to_seq_thermtrip_l = sp3_to_seq_thermtrip_l.send;
            method sp3_to_seq_fsr_req_l = sp3_to_seq_fsr_req_l.send;
            method seq_to_clk_gpio3 = seq_to_clk_gpio3.send;
            method seq_to_clk_gpio9 = seq_to_clk_gpio9.send;
            method seq_to_clk_gpio8 = seq_to_clk_gpio8.send;
            method seq_to_clk_gpio2 = seq_to_clk_gpio2.send;
            method seq_to_clk_gpio1 = seq_to_clk_gpio1.send;
            method seq_to_clk_gpio5 = seq_to_clk_gpio5.send;
            method seq_to_clk_gpio4 = seq_to_clk_gpio4.send;
        endinterface

        method syncd_pins = cur_syncd_pins._read;
    endmodule
    // Block top module
    module mkMiscBlock(MiscBlockTop);

        Reg#(UInt#(6)) clk_rst_time <- mkReg(50);
        Reg#(Bit#(1)) testpoint <- mkReg(1);

        // Output registers
        Reg#(Bit#(1)) clk_to_seq_nmr_l <- mkReg(0);

        // Combo output readbacks
        Wire#(MiscOutPinsStruct) cur_out_pins <- mkDWire(unpack(0));
        // Combo input wires
        Wire#(MiscInPinsStruct) cur_syncd_pins <- mkDWire(unpack(0));
        Wire#(MiscOutPinsStruct) dbg_out_pins <- mkDWire(unpack(0));
        Wire#(Bit#(1)) dbg_en   <- mkDWire(0);
        Wire#(Bool) cur_thermtrip <- mkDWire(False);

        rule do_thermtrip;
            cur_thermtrip <= (cur_syncd_pins.sp3_to_seq_thermtrip == 1); 
        endrule


        rule do_reset_oneshot;
            if (clk_rst_time != 0) begin
                clk_rst_time <= clk_rst_time - 1;
            end
        endrule


        rule do_pack_output_readbacks;
            cur_out_pins <= MiscOutPinsStruct {
                clk_to_seq_nmr: ~clk_to_seq_nmr_l
            };
        endrule
        rule do_output_pins;
            clk_to_seq_nmr_l <= ~dbg_out_pins.clk_to_seq_nmr & (clk_rst_time == 0 ? 'b1 : 'b0);
        endrule
        method syncd_pins = cur_syncd_pins._write;
        method thermtrip = cur_thermtrip._read;
        interface MiscRegs reg_if;
            method input_readbacks = cur_syncd_pins._read;
            method output_readbacks = cur_out_pins._read; // Output sampling
            method dbg_ctrl = dbg_out_pins._write; // Output control
            method dbg_en = dbg_en._write;    // Debug enable pin
        endinterface       
        interface MiscOutputSource out_pins;
            method clk_to_seq_nmr_l = clk_to_seq_nmr_l._read;
            method testpoint = testpoint._read;
        endinterface
    endmodule

     interface TBTestMiscPinsSource;
        interface Server#(MiscInPinsRawStruct, Bool) bfm;
        interface MiscInputPinsRawSource pins;
    endinterface

    module mkTestMiscPinsSource(TBTestMiscPinsSource);
        Reg#(Bit#(1)) sp3_to_seq_thermtrip_l <- mkReg(1);
        Reg#(Bit#(1)) sp3_to_seq_fsr_req_l <- mkReg(0);
        Reg#(Bit#(1)) seq_to_clk_gpio3 <- mkReg(0);
        Reg#(Bit#(1)) seq_to_clk_gpio9 <- mkReg(0);
        Reg#(Bit#(1)) seq_to_clk_gpio8 <- mkReg(0);
        Reg#(Bit#(1)) seq_to_clk_gpio2 <- mkReg(0);
        Reg#(Bit#(1)) seq_to_clk_gpio1 <- mkReg(0);
        Reg#(Bit#(1)) seq_to_clk_gpio5 <- mkReg(0);
        Reg#(Bit#(1)) seq_to_clk_gpio4 <- mkReg(0);
        
        interface MiscInputPinsRawSource pins;
            method sp3_to_seq_thermtrip_l = sp3_to_seq_thermtrip_l._read;
            method sp3_to_seq_fsr_req_l = sp3_to_seq_fsr_req_l._read;
            method seq_to_clk_gpio9 = seq_to_clk_gpio9._read;
            method seq_to_clk_gpio8 = seq_to_clk_gpio8._read;
            method seq_to_clk_gpio2 = seq_to_clk_gpio2._read;
            method seq_to_clk_gpio1 = seq_to_clk_gpio1._read;
            method seq_to_clk_gpio5 = seq_to_clk_gpio5._read;
            method seq_to_clk_gpio4 = seq_to_clk_gpio4._read;
        endinterface
        interface Server bfm;
            interface Put request;
                method Action put(request);
                    sp3_to_seq_thermtrip_l <= request.sp3_to_seq_thermtrip_l;
                    sp3_to_seq_fsr_req_l <= request.sp3_to_seq_fsr_req_l;
                    seq_to_clk_gpio3 <= request.seq_to_clk_gpio3;
                    seq_to_clk_gpio9 <= request.seq_to_clk_gpio9;
                    seq_to_clk_gpio8 <= request.seq_to_clk_gpio8;
                    seq_to_clk_gpio2 <= request.seq_to_clk_gpio2;
                    seq_to_clk_gpio1 <= request.seq_to_clk_gpio1;
                    seq_to_clk_gpio5 <= request.seq_to_clk_gpio5;
                    seq_to_clk_gpio4 <= request.seq_to_clk_gpio4;
                endmethod
            endinterface
            interface Get response;
            endinterface
        endinterface
    endmodule

endpackage