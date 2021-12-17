package SidecarCtrlRegs;
// BSV imports
import DReg::*;
import GetPut::*;
import Connectable::*;
import ClientServer::*;
import ConfigReg::*;
import StmtFSM::*;

// Oxide imports
import RegCommon::*;
import SidecarSeqRegs::*;

interface SidecarRegIF;
    interface Server#(RegRequest#(16, 8), RegResp#(8)) decoder_if;
    method Action set_tf2_seq_state(Bit#(8) state);
    method Action set_tf2_seq_error(Bit#(8) error);
    method Action set_tf2_power_enables(TofinoPowerEnables ens);
    method Action set_tf2_power_goods(TofinoPowerGoods pgs);
    method Action set_tf2_vid(Bit#(4) vid);
    method TofinoEn tofino_en_reg;
endinterface

module mkSidecarRegs(SidecarRegIF);
    // Registers
    ConfigReg#(Id0) id0 <- mkReg(unpack('h01));
    ConfigReg#(Id1) id1 <- mkReg(unpack('hde));
    ConfigReg#(Id2) id2 <- mkReg(unpack('hAA));
    ConfigReg#(Id3) id3 <- mkReg(unpack('h55));
    ConfigReg#(Scratchpad) scratchpad <- mkReg(unpack('h0));
    ConfigReg#(TofinoEn) tf_en <- mkReg(unpack('h0));
    ConfigReg#(TofinoSeqState) tf_seq_state <- mkReg(unpack('h0));
    ConfigReg#(TofinoSeqState) tf_seq_state_next <- mkReg(unpack('h0));
    ConfigReg#(TofinoSeqError) tf_seq_error <- mkReg(unpack('h0));
    ConfigReg#(TofinoSeqError) tf_seq_error_next <- mkReg(unpack('h0));
    ConfigReg#(TofinoPowerEnables) tf_ens <- mkReg(unpack('h0));
    ConfigReg#(TofinoPowerEnables) tf_ens_next <- mkReg(unpack('h0));
    ConfigReg#(TofinoPowerGoods) tf_pgs <- mkReg(unpack('h0));
    ConfigReg#(TofinoPowerGoods) tf_pgs_next <- mkReg(unpack('h0));
    ConfigReg#(TofinoVid) tf_vid <- mkReg(unpack('h0));
    ConfigReg#(TofinoVid) tf_vid_next <- mkReg(unpack('h0));

    PulseWire do_read <- mkPulseWire();
    PulseWire do_write <- mkPulseWire();
    PulseWire do_bitset <- mkPulseWire();
    PulseWire do_bitclear <- mkPulseWire();
    Reg#(Maybe#(Bit#(8))) readdata <- mkReg(tagged Invalid);
     // Combo inputs/outputs to/from the interface
    Wire#(Bit#(8)) writedata <- mkDWire(0);
    Wire#(Bit#(16)) address <- mkDWire(0);
    Wire#(RegOps) operation <- mkDWire(NOOP);

    // SW readbacks
    (* fire_when_enabled, no_implicit_conditions *)
    rule do_reg_read (do_read && !isValid(readdata));
        case (address)
            fromInteger(id0Offset) : readdata <= tagged Valid (pack(id0));
            fromInteger(id1Offset) : readdata <= tagged Valid (pack(id1));
            fromInteger(id2Offset) : readdata <= tagged Valid (pack(id2));
            fromInteger(id3Offset) : readdata <= tagged Valid (pack(id3));
            fromInteger(scratchpadOffset) : readdata <= tagged Valid (pack(scratchpad));
            fromInteger(tofinoEnOffset) : readdata <= tagged Valid (pack(tf_en));
            fromInteger(tofinoSeqStateOffset) : readdata <= tagged Valid (pack(tf_seq_state));
            fromInteger(tofinoSeqErrorOffset) : readdata <= tagged Valid (pack(tf_seq_error));
            fromInteger(tofinoPowerEnablesOffset) : readdata <= tagged Valid (pack(tf_ens));
            fromInteger(tofinoPowerGoodsOffset) : readdata <= tagged Valid (pack(tf_pgs));
            fromInteger(tofinoVidOffset) : readdata <= tagged Valid (pack(tf_vid));
            default : readdata <= tagged Valid ('hff);
        endcase
    endrule

    // Register updates, note software writes take precedence for same-clock cycle hw and software updates on read/write registers
    (* fire_when_enabled, no_implicit_conditions *)
    rule do_reg_updates;
        scratchpad <= reg_update(scratchpad, scratchpad, address, scratchpadOffset, operation, writedata);
        tf_en <= reg_update(tf_en, tf_en, address, tofinoEnOffset, operation, writedata);
        tf_seq_state <= reg_update(tf_seq_state, tf_seq_state_next, address, tofinoSeqStateOffset, operation, writedata);
        tf_seq_error <= reg_update(tf_seq_error, tf_seq_error_next, address, tofinoSeqErrorOffset, operation, writedata);
        tf_ens <= reg_update(tf_ens, tf_ens_next, address, tofinoPowerEnablesOffset, operation, writedata);
        tf_pgs <= reg_update(tf_pgs, tf_pgs_next, address, tofinoPowerGoodsOffset, operation, writedata);
        tf_vid <= reg_update(tf_vid, tf_vid_next, address, tofinoVidOffset, operation, writedata);
    endrule

    method Action set_tf2_seq_state(Bit#(8) state);
        tf_seq_state_next.state <= state;
    endmethod

    method Action set_tf2_seq_error(Bit#(8) error);
        tf_seq_error_next.error <= error;
    endmethod

    method Action set_tf2_vid(Bit#(4) vid);
        tf_vid.vid <= vid;
    endmethod

    method Action set_tf2_power_enables(TofinoPowerEnables ens);
        tf_ens_next <= ens;
    endmethod

    method Action set_tf2_power_goods(TofinoPowerGoods pgs);
        tf_pgs_next <= pgs;
    endmethod

    method tofino_en_reg = tf_en;

    interface Server decoder_if;
        interface Put request;
            method Action put(request);
                writedata <= request.wdata;
                address <= request.address;
                operation <= request.op;

                if (request.op == WRITE) begin
                    do_write.send();
                end else if (request.op == BITSET) begin
                    do_bitset.send();
                end else if (request.op == BITCLEAR) begin
                    do_bitclear.send();
                end else if (request.op == READ) begin
                    do_read.send();
                end
            endmethod
        endinterface
        interface Get response;
            method ActionValue#(RegResp#(8)) get() if (isValid(readdata));
                let rdata = fromMaybe(?, readdata);
                readdata <= tagged Invalid;
                return RegResp {readdata: rdata};
            endmethod
        endinterface
    endinterface
endmodule
endpackage