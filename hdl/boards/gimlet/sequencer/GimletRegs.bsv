package GimletRegs;


import GetPut::*;
import ClientServer::*;
import ConfigReg::*;
import StmtFSM::*;

import RegCommon::*;
import GimletSeqFpgaRegs::*;
import NicBlock::*;


interface GimletRegIF;
    interface Server#(RegRequest#(16, 8), RegResp#(8)) decoder_if;
    interface NicRegPinInputs nic_in_pins;
endinterface




module mkGimletRegs(GimletRegIF);
    // Registers
    ConfigReg#(NicStatus) nic_status <- mkRegU();

    Reg#(Maybe#(Bit#(8))) readdata <- mkReg(tagged Invalid);

     // Combo inputs/outputs to/from the interface
    Wire#(Bit#(8)) writedata <- mkDWire(0);
    Wire#(Bit#(16)) address <- mkDWire(0);
    Wire#(RegOps) operation <- mkDWire(NOOP);
    RWire#(NicStatus) cur_nic_pins <- mkRWire();


    // SW readbacks
    rule do_reg_read (operation == READ && !isValid(readdata));
        case (address)
            fromInteger(nicStatusOffset) : readdata <= tagged Valid (pack(nic_status));
            default : readdata <= tagged Valid (0);
        endcase
    endrule

    // Register updates, note software writes take precedence for same-clock cycle hw and software updates on read/write registers
    rule do_reg_updates;
        // NIC status register
        nic_status <= reg_update(nic_status, fromMaybe(nic_status, cur_nic_pins.wget()), address, nicStatusOffset, operation, writedata);
    endrule

    interface Server decoder_if;
        interface Put request;
            method Action put(request);
                writedata <= request.wdata;
                address <= request.address;
                operation <= request.op;
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

    interface NicRegPinInputs nic_in_pins;
        method nic_pins = cur_nic_pins.wset;
    endinterface

endmodule

(* synthesize *)
module mkSimpleTest(Empty);
    GimletRegIF dut <- mkGimletRegs();
    Reg#(NicStatus) nic_stim <- mkReg(unpack('hAA));

    rule do_pins;
        dut.nic_in_pins.nic_pins(nic_stim);
    endrule

    mkAutoFSM(
        seq
            // // Write to LED reg
            // action
            //     let req =  RegRequest {
            //         address: 1, 
            //         wdata: 'hFF,
            //         op: READ
            //     };
            //     dut.decoder_if.request.put(req);
            // endaction
            // delay(2);
            // Read CMD from LED reg
            action
                let req =  RegRequest {
                    address: 1, 
                    wdata: 'hFF,
                    op: READ
                };
                dut.decoder_if.request.put(req);
            endaction

            action
                let resp = dut.decoder_if.response.get();
                $display(resp);
            endaction
            delay(2);
            action
                let req =  RegRequest {
                    address: 17, 
                    wdata: 'hFF,
                    op: READ
                };
                dut.decoder_if.request.put(req);
            endaction

            action
                let resp = dut.decoder_if.response.get();
                $display(resp);
            endaction
        endseq
    );
endmodule

endpackage