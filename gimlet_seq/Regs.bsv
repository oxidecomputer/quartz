package Regs;

import GetPut::*;
import ClientServer::*;
import ConfigReg::*;
import Reserved::*;
import StmtFSM::*;

import RegCommon::*;

typedef struct {
    ReservedZero#(7) zeros0; // bit 7..1
    Bit#(1)          led;  // bit 0
} LEDReg deriving (Bits, Eq);

typedef struct {
    Bit#(8)     scratchpad;  // bit 7..0
} SPad deriving (Bits, Eq);

interface RegIF;
    interface Server#(RegRequest#(16, 8), RegResp#(8)) decoder_if;
    method Bit#(1) led;
endinterface

module mkRegResponder(RegIF);
    // Combo stuff that makes simulation easier
    PulseWire do_read <- mkPulseWire();
    PulseWire do_write <- mkPulseWire();
    PulseWire do_bitset <- mkPulseWire();
    PulseWire do_bitclear <- mkPulseWire();
    PulseWire do_nothing <- mkPulseWire();

    // Combo stuff for decode
    PulseWire spad_selected <- mkPulseWire();
    PulseWire led_selected <- mkPulseWire();

    // Combo inputs/outputs to/from the interface
    Wire#(Bit#(8)) writedata <- mkDWire(0);
    Wire#(Bit#(16)) address <- mkDWire(0);
    Wire#(RegOps) operation <- mkDWire(READ);

    // Registers
    Reg#(Maybe#(Bit#(8))) readdata <- mkReg(tagged Invalid);
    ConfigReg#(SPad) spad_reg <- mkConfigReg(unpack('hAA));
    ConfigReg#(LEDReg) led_reg <- mkConfigReg(unpack(1));

    // Addr decode logic
    rule addr_decode;
        case (address)
            0 : spad_selected.send();
            1 : led_selected.send();
            default: noAction;
        endcase
    endrule
    
    // Register read logic
    rule do_reg_read (do_read);
        if (spad_selected) begin
            readdata <= tagged Valid (pack(spad_reg));
        end else if (led_selected) begin
            readdata <= tagged Valid (pack(led_reg));
        end
    endrule

    // Register update logic
    rule do_regs_update;
        if (spad_selected && operation == WRITE) begin
            spad_reg <= unpack(writedata);
        end else if (spad_selected && operation == BITSET) begin
            spad_reg <= unpack(writedata | pack(spad_reg));
        end else if (spad_selected && operation == BITCLEAR) begin
            spad_reg <= unpack(~writedata & pack(spad_reg));
        end
        if (led_selected && operation == WRITE) begin
            led_reg <= unpack(writedata);
        end else if (led_selected && operation == BITSET) begin
            led_reg <= unpack(writedata | pack(led_reg));
        end else if (led_selected && operation == BITCLEAR) begin
            led_reg <= unpack(~writedata & pack(led_reg));
        end

    endrule

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
            method ActionValue#(RegResp#(8)) get() if (isValid(readdata) && !do_read);
                let rdata = fromMaybe(?, readdata);
                readdata <= tagged Invalid;
                return RegResp {readdata: rdata};
            endmethod
        endinterface
    endinterface
    method Bit#(1) led;
        return led_reg.led;
    endmethod
endmodule

(* synthesize *)
module mkTestBenchSimpleReg(Empty);
    RegIF regs <- mkRegResponder();

    mkAutoFSM(
        seq
            // Write to LED reg
            action
                let req =  RegRequest {
                    address: 1, 
                    wdata: 'hFF,
                    op: WRITE
                };
                regs.decoder_if.request.put(req);
            endaction
            delay(2);
            // Read CMD from LED reg
            action
                let req =  RegRequest {
                    address: 1, 
                    wdata: 'hFF,
                    op: READ
                };
                regs.decoder_if.request.put(req);
            endaction

            action
                let resp = regs.decoder_if.response.get();
                $display(resp);
            endaction
        endseq
    );
endmodule


endpackage