package GimletRegs;
// BSV imports
import GetPut::*;
import ClientServer::*;
import ConfigReg::*;
import StmtFSM::*;
// Oxide imports
import RegCommon::*;
import GimletSeqFpgaRegs::*;
import NicBlock::*;
import EarlyPowerBlock::*;
import A1Block::*;

interface GimletRegIF;
    interface Server#(RegRequest#(16, 8), RegResp#(8)) decoder_if;
    interface NicRegPinInputs nic_in_pins;
    interface EarlyRegsReverse early_block;
    interface A1RegsReverse a1_block;
endinterface

module mkGimletRegs(GimletRegIF);
    // Registers
    ConfigReg#(DbgCtrl) dbgCtrl_reg <- mkReg(unpack(0)); // Debug mux control register
    //  NIC domain signals
    ConfigReg#(NicStatus) nic_status <- mkRegU();  // RO register for inputs
    ConfigReg#(OutStatusNic1) nic1_out_status <- mkRegU(); // RO register for outputs
    ConfigReg#(OutStatusNic2) nic2_out_status <- mkRegU(); // RO register for outputs
    ConfigReg#(DbgOutNic1) dbg_nic1_out       <- mkReg(unpack(0));
    ConfigReg#(DbgOutNic2) dbg_nic2_out       <- mkReg(unpack(0));
    // Early output signals
    ConfigReg#(EarlyPwrStatus) early_output_rdbks  <- mkRegU();
    ConfigReg#(EarlyRbks) early_inputs  <- mkRegU();
    ConfigReg#(EarlyPowerCtrl) early_ctrl  <- mkReg(unpack(0));
    // A1 registers
    ConfigReg#(A1DbgOut) a1_dbg <- mkReg(unpack(0));
    ConfigReg#(A1OutStatus) a1_output_readbacks <- mkRegU();
    ConfigReg#(A1Readbacks) a1_inputs <- mkRegU();
    

    Reg#(Maybe#(Bit#(8))) readdata <- mkReg(tagged Invalid);

     // Combo inputs/outputs to/from the interface
    Wire#(Bit#(8)) writedata <- mkDWire(0);
    Wire#(Bit#(16)) address <- mkDWire(0);
    Wire#(RegOps) operation <- mkDWire(NOOP);
    RWire#(NicStatus) cur_nic_pins <- mkRWire();
    RWire#(OutStatusNic1) cur_nic1_out_status <- mkRWire();
    RWire#(OutStatusNic2) cur_nic2_out_status <- mkRWire();
    RWire#(EarlyPwrStatus) cur_early_outputs <- mkRWire();
    RWire#(EarlyRbks) cur_early_inputs <- mkRWire();

    RWire#(A1OutStatus) cur_a1_outputs <- mkRWire();
    RWire#(A1Readbacks) cur_a1_inputs <- mkRWire();

    // SW readbacks
    rule do_reg_read (operation == READ && !isValid(readdata));
        case (address)
            fromInteger(dbgCtrlOffset) : readdata <= tagged Valid (pack(dbgCtrl_reg));
            fromInteger(nicStatusOffset) : readdata <= tagged Valid (pack(nic_status));
            fromInteger(outStatusNic1Offset) : readdata <= tagged Valid (pack(nic1_out_status));
            fromInteger(outStatusNic2Offset) : readdata <= tagged Valid (pack(nic2_out_status));
            fromInteger(dbgOutNic1Offset) : readdata <= tagged Valid (pack(dbg_nic1_out));
            fromInteger(dbgOutNic2Offset) : readdata <= tagged Valid (pack(dbg_nic2_out));
            fromInteger(earlyRbksOffset) : readdata <= tagged Valid (pack(early_inputs));
            fromInteger(earlyPwrStatusOffset) : readdata <= tagged Valid (pack(early_output_rdbks));
            fromInteger(earlyPowerCtrlOffset) : readdata <= tagged Valid (pack(early_ctrl));
            fromInteger(a1DbgOutOffset) : readdata <= tagged Valid (pack(a1_dbg));
            fromInteger(a1OutStatusOffset) : readdata <= tagged Valid (pack(a1_output_readbacks));
            fromInteger(a1ReadbacksOffset) : readdata <= tagged Valid (pack(a1_inputs));
            default : readdata <= tagged Valid (0);
        endcase
    endrule

    // Register updates, note software writes take precedence for same-clock cycle hw and software updates on read/write registers
    rule do_reg_updates; 
        dbgCtrl_reg <= reg_update(dbgCtrl_reg, dbgCtrl_reg, address, dbgCtrlOffset, operation, writedata); // Normal sw register
        // NIC registers
        nic_status      <= fromMaybe(nic_status, cur_nic_pins.wget());  // Always update from pins, no writing from sw.
        nic1_out_status <= fromMaybe(nic1_out_status, cur_nic1_out_status.wget()); // Always update from pins, no writing from sw.
        nic2_out_status <= fromMaybe(nic2_out_status, cur_nic2_out_status.wget()); // Always update from pins, no writing from sw.
        dbg_nic1_out    <= reg_update(dbg_nic1_out, dbg_nic1_out, address, dbgOutNic1Offset, operation, writedata); // Normal sw register
        dbg_nic2_out    <= reg_update(dbg_nic2_out, dbg_nic2_out, address, dbgOutNic2Offset, operation, writedata); // Normal sw register

        // Early registers
        early_inputs    <= fromMaybe(early_inputs, cur_early_inputs.wget());
        early_output_rdbks <= fromMaybe(early_output_rdbks, cur_early_outputs.wget());
        early_ctrl      <= reg_update(early_ctrl, early_ctrl, address, earlyPowerCtrlOffset, operation, writedata);

        // A1 registers
        a1_inputs   <= fromMaybe(a1_inputs, cur_a1_inputs.wget());
        a1_output_readbacks <= fromMaybe(a1_output_readbacks, cur_a1_outputs.wget());
        a1_dbg <= reg_update(a1_dbg, a1_dbg, address, a1DbgOutOffset, operation, writedata);
        //nic2_out_status <= reg_update(nic2_out_status, fromMaybe(nic2_out_status, cur_nic2_out_status.wget()), address, outStatusNic2Offset, operation, writedata);
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
        method nic1_out_status = cur_nic1_out_status.wset;
        method nic2_out_status = cur_nic2_out_status.wset;
        method Bit#(1) dbg_en;
            return dbgCtrl_reg.reg_ctrl_en;
        endmethod
        method dbg_nic1 = dbg_nic1_out._read;
        method dbg_nic2 = dbg_nic2_out._read;
    endinterface

    interface EarlyRegsReverse early_block;
        method input_readbacks = cur_early_inputs.wset; // Input sampling
        method output_readbacks = cur_early_outputs.wset; // Output sampling
        method output_ctrl = early_ctrl._read;
    endinterface

    interface A1RegsReverse a1_block;
        // Normalized pin readbacks to registers
        method input_readbacks = cur_a1_inputs.wset; // Input sampling
        method output_readbacks = cur_a1_outputs.wset; // Output sampling
        method A1DbgOut dbg_ctrl =  a1_dbg._read; // Output control
        method Bit#(1) dbg_en;
            return dbgCtrl_reg.reg_ctrl_en;
        endmethod
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