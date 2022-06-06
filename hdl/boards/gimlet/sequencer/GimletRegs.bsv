package GimletRegs;
// BSV imports
import DReg::*;
import GetPut::*;
import Connectable::*;
import ClientServer::*;
import ConfigReg::*;
import StmtFSM::*;

// Oxide imports
import IrqBlock::*;
import RegCommon::*;
import git_version::*;
import GimletSeqFpgaRegs::*;
import NicBlock::*;
// import EarlyPowerBlock::*;
import A1Block::*;
import A0Block::*;
// import MiscIO::*;

interface RegPins;
    method Bit#(1) seq_to_sp_interrupt;
    method Action brd_rev(BoardRev value);
endinterface

interface GimletRegIF;
    
    interface Server#(RegRequest#(16, 8), RegResp#(8)) decoder_if;
    interface NicRegsReverse nic_block;
    // interface EarlyRegsReverse early_block;
    interface A1RegsReverse a1_block;
    interface A0RegsReverse a0_block;
    // interface MiscRegsReverse misc_block;
    interface RegPins pins;
endinterface

module mkGimletRegs(GimletRegIF);
    // Registers
    ConfigReg#(Scrtchpad) scratchpad <- mkReg(unpack('h0));
    ConfigReg#(Status) status <- mkConfigRegU();
    ConfigReg#(DbgCtrl) dbgCtrl_reg <- mkReg(
        DbgCtrl {
            nic_perst_override : 1,
            nic_cld_rst_override: 1,
            reg_ctrl_en: 0,
            ignore_sp: 0
        });
    // Main control registers
    ConfigReg#(Pwrctrl) power_control <- mkReg(unpack(0));
    //  NIC domain signals
    ConfigReg#(OutStatusNic1) nic1_out_status <- mkRegU(); // RO register for outputs
    
    ConfigReg#(DbgOutNic1) dbg_nic1_out       <- mkReg(unpack(0));
    ConfigReg#(DbgOutNic2) dbg_nic2_out       <- mkReg(unpack(0));
    // Early output signals
    ConfigReg#(EarlyPwrStatus) early_output_rdbks  <- mkRegU();
    ConfigReg#(EarlyRbks) early_inputs  <- mkRegU();
    ConfigReg#(EarlyPowerCtrl) early_ctrl  <- mkReg(unpack('h06));  // want to force the 2V5 on due to level translator issue on gimlet.
    // A1 registers
    ConfigReg#(A1DbgOut) a1_dbg <- mkReg(unpack(0));
    ConfigReg#(A1OutStatus) a1_output_readbacks <- mkRegU();
    ConfigReg#(A1Readbacks) a1_inputs <- mkRegU();
    ConfigReg#(A1smstatus) a1_sm <- mkRegU();
    // A0 registers
    //ConfigReg#(A0OutStatus1) a0_status1 <- mkReg(unpack(0)); // a0OutStatus1Offset
    //ConfigReg#(A0OutStatus2) a0_status2 <- mkReg(unpack(0)); // a0OutStatus2Offset
    ConfigReg#(A0DbgOut1) a0_dbg_out1 <- mkReg(unpack(0)); // a0DbgOut1Offset
    ConfigReg#(A0DbgOut2) a0_dbg_out2 <- mkReg(unpack(0)); // a0DbgOut1Offset
    ConfigReg#(AmdA0) a0_amd_rdbks <- mkReg(unpack(0)); // amdA0Offset
   
    ConfigReg#(GroupbUnused) a0_groupB_unused <- mkReg(unpack(0)); //groupbUnusedOffset
    ConfigReg#(GroupbcFlts) a0_groupC_faults <-mkReg(unpack(0)); //groupbcFltsOffset
    
    ConfigReg#(A0smstatus) a0_sm <- mkRegU();
    // Misc IO registers
    ConfigReg#(ClkgenOutStatus) clkgen_out_status <- mkReg(unpack(0)); // clkgenOutStatusOffset
    ConfigReg#(ClkgenDbgOut) clkgen_dbg_out <- mkReg(unpack(0)); // clkgenDbgOutOffset

    ConfigReg#(AmdOutStatus) amd_out_status <- mkReg(unpack(0)); // amdOutStatusOffset
    ConfigReg#(AmdDbgOut) amd_dbg_out <- mkReg(unpack(0)); // amdDbgOutOffset

    ConfigReg#(Ifr) irq_en_reg <- mkReg(unpack(0));
    ConfigReg#(Ifr) irq_cause_reg <- mkReg(unpack(0));
    ConfigReg#(Ifr) irq_dbg_flags <- mkDReg(unpack(0));
    ConfigReg#(Ifr) irq_clr_flags <- mkDReg(unpack(0));
    ConfigReg#(Ifr) irq_cause_raw <- mkDReg(unpack(0));

    PulseWire do_read <- mkPulseWire();
    PulseWire do_write <- mkPulseWire();
    PulseWire do_bitset <- mkPulseWire();
    PulseWire do_bitclear <- mkPulseWire();

    Reg#(Maybe#(Bit#(8))) readdata <- mkReg(tagged Invalid);

     // Combo inputs/outputs to/from the interface
    Wire#(Bit#(8)) writedata <- mkDWire(0);
    Wire#(Bit#(16)) address <- mkDWire(0);
    Wire#(RegOps) operation <- mkDWire(NOOP);
    // RWire#(NicStatus) cur_nic_pins <- mkRWire();
    RWire#(OutStatusNic1) cur_nic1_out_status <- mkRWire();
    RWire#(EarlyPwrStatus) cur_early_outputs <- mkRWire();
    RWire#(EarlyRbks) cur_early_inputs <- mkRWire();

    Wire#(A1StateType) a1_state <- mkDWire(IDLE);
    Wire#(A0OutStatus1) a0_status1 <- mkDWire(unpack(0));
    Wire#(A0OutStatus2) a0_status2 <- mkDWire(unpack(0));
    Wire#(GroupbPg) a0_groupB_pg <- mkDWire(unpack(0));
    Wire#(GroupcPg) a0_groupC_pg <- mkDWire(unpack(0));
    Wire#(NicStatus) nic_status <- mkDWire(unpack(0));
    Wire#(Nicsmstatus) nic_state <- mkDWire(unpack(0));
    Wire#(BoardRev) brd_rev <- mkDWire(unpack(0));
    Wire#(Bit#(1)) a0_ok <- mkDWire(0);
    Wire#(Bit#(1)) a1_ok <- mkDWire(0);
    Wire#(Bit#(1)) nic_ok <- mkDWire(0);
    Wire#(Bit#(1)) fan_ok <- mkDWire(1);
    Wire#(OutStatusNic2) nic2_out_status <- mkDWire(unpack(0));
    // RWire#(A0StateType) a0_state <- mkRWire();
    //ConfigReg#(NicStateType) nic_sm <- mkConfigRegU();
    
    // RWire#(A0InPinsStruct) cur_a0_inputs <- mkRWire();
    // RWire#(A0OutPinsStruct) cur_a0_outputs <- mkRWire();
    // Wire#(A0OutPinsStruct) dbg_a0_outputs <- mkDWire(unpack(0));

    // RWire#(MiscInPinsStruct) cur_misc_inputs <- mkRWire();
    // Wire#(MiscOutPinsStruct) dbg_misc_outputs <- mkDWire(unpack(0));
    // RWire#(MiscOutPinsStruct) cur_misc_outputs <- mkRWire();

    IRQBlock#(Ifr) irq_block <- mkIRQBlock();

    mkConnection(irq_en_reg, irq_block.enables);
    mkConnection(irq_dbg_flags, irq_block.debug);
    mkConnection(irq_clr_flags, irq_block.clear);
    mkConnection(irq_cause_raw, irq_block.cause_raw);

    rule do_status;
        status <= Status {
            int_pend: 0,
            nicpwrok: nic_ok,
            a0pwrok: a0_ok,
            a1pwrok: a1_ok,
            fanpwrok: 1
        };
    endrule

    // SW readbacks
    (* fire_when_enabled, no_implicit_conditions *)
    rule do_reg_read (do_read && !isValid(readdata));
        case (address)
            fromInteger(id0Offset) : readdata <= tagged Valid ('h01);
            fromInteger(id1Offset) : readdata <= tagged Valid ('hde);
            fromInteger(ver0Offset) : readdata <= tagged Valid (version[0]);
            fromInteger(ver1Offset) : readdata <= tagged Valid (version[1]);
            fromInteger(ver2Offset) : readdata <= tagged Valid (version[2]);
            fromInteger(ver3Offset) : readdata <= tagged Valid (version[3]);
            fromInteger(sha0Offset) : readdata <= tagged Valid (sha[0]);
            fromInteger(sha1Offset) : readdata <= tagged Valid (sha[1]);
            fromInteger(sha2Offset) : readdata <= tagged Valid (sha[2]);
            fromInteger(sha3Offset) : readdata <= tagged Valid (sha[3]);
            fromInteger(scrtchpadOffset) : readdata <= tagged Valid (pack(scratchpad));
            fromInteger(statusOffset) : readdata <= tagged Valid (pack(status));
            fromInteger(ierOffset) : readdata <= tagged Valid (pack(irq_en_reg));
            fromInteger(ifrOffset) : readdata <= tagged Valid (pack(irq_block.cause_reg));
            fromInteger(pwrctrlOffset): readdata <= tagged Valid (pack(power_control));
            fromInteger(boardRevOffset): readdata <= tagged Valid (pack(brd_rev));
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
            fromInteger(a1smstatusOffset) : readdata <= tagged Valid (pack(a1_sm));
            fromInteger(a0OutStatus1Offset) : readdata <= tagged Valid (pack(a0_status1));
            fromInteger(a0OutStatus2Offset) : readdata <= tagged Valid (pack(a0_status2));
            fromInteger(a0smstatusOffset) : readdata <= tagged Valid (pack(a0_sm));
            fromInteger(a0DbgOut1Offset) : readdata <= tagged Valid (pack(a0_dbg_out1));
            fromInteger(a0DbgOut2Offset) : readdata <= tagged Valid (pack(a0_dbg_out2));
            fromInteger(nicsmstatusOffset) : readdata <= tagged Valid (pack(nic_state));
            fromInteger(amdA0Offset) : readdata <= tagged Valid (pack(a0_amd_rdbks));
            fromInteger(groupbPgOffset) : readdata <= tagged Valid (pack(a0_groupB_pg));
            fromInteger(groupbUnusedOffset) : readdata <= tagged Valid (pack(a0_groupB_unused));
            fromInteger(groupbcFltsOffset) : readdata <= tagged Valid (pack(a0_groupC_faults));
            fromInteger(groupcPgOffset) : readdata <= tagged Valid (pack(a0_groupC_pg));
            fromInteger(clkgenOutStatusOffset) : readdata <= tagged Valid (pack(clkgen_out_status));
            fromInteger(clkgenDbgOutOffset) : readdata <= tagged Valid (pack(clkgen_dbg_out));
            fromInteger(amdOutStatusOffset) : readdata <= tagged Valid (pack(amd_out_status));
            fromInteger(amdDbgOutOffset) : readdata <= tagged Valid (pack(amd_dbg_out));
            default : readdata <= tagged Valid ('hff);
        endcase
    endrule

    // Register updates, note software writes take precedence for same-clock cycle hw and software updates on read/write registers
    (* fire_when_enabled, no_implicit_conditions *)
    rule do_reg_updates; 
        // IRQ Enable works like a normal register
        irq_en_reg <= reg_update(irq_en_reg, irq_en_reg, address, ierOffset, operation, writedata);
        // IRQ Cause does some special things:
        if (address == fromInteger(ifrOffset)) begin
            // Normal does nothing?
            // Bitset sets debug registers
            if (operation == BITSET) begin
                irq_dbg_flags <= unpack(writedata);
            // Bitclear clears bits as expected
            end else if  (operation == BITCLEAR) begin
                irq_clr_flags <= unpack(writedata);
            end
        end

        scratchpad <= reg_update(scratchpad, scratchpad, address, scrtchpadOffset, operation, writedata);
        dbgCtrl_reg <= reg_update(dbgCtrl_reg, dbgCtrl_reg, address, dbgCtrlOffset, operation, writedata); // Normal sw register
        power_control <= reg_update(power_control, power_control, address, pwrctrlOffset, operation, writedata);
      
        a1_dbg <= reg_update(a1_dbg, a1_dbg, address, a1DbgOutOffset, operation, writedata);

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
            method ActionValue#(RegResp#(8)) get() if (isValid(readdata));
                let rdata = fromMaybe(?, readdata);
                readdata <= tagged Invalid;
                return RegResp {readdata: rdata};
            endmethod
        endinterface
    endinterface

    // interface NicRegsReverse nic_block;
    //     method nic_status = cur_nic_pins.wset;
    //     method nic1_out_status = cur_nic1_out_status.wset;
    //     method nic2_out_status = cur_nic2_out_status.wset;
    //     method state = nic_state.wset;
    //     method Bit#(1) nic_go;
    //         return power_control.nicpwren;
    //     endmethod
    //     method Bit#(1) nic_en;
    //         return power_control.a0a_en;  // Enable in A0
    //     endmethod
    //     method Bit#(1) dbg_en;
    //         return dbgCtrl_reg.reg_ctrl_en | dbgCtrl_reg.nic_ctrl_en;
    //     endmethod
    //     method Bool ignore_sp;
    //         return (dbgCtrl_reg.ignore_sp  == 1);
    //     endmethod
    //     method dbg_nic1 = dbg_nic1_out._read;
    //     method dbg_nic2 = dbg_nic2_out._read;
    // endinterface

    // interface EarlyRegsReverse early_block;
    //     method input_readbacks = cur_early_inputs.wset; // Input sampling
    //     method output_readbacks = cur_early_outputs.wset; // Output sampling
    //     method output_ctrl = early_ctrl._read;
    // endinterface

    interface A1RegsReverse a1_block;
        method Bool a1_en();
            return power_control.a1pwren == 1;
        endmethod
        method Action ok(Bool value);
            a1_ok <= pack(value);
        endmethod
        method Action state(A1StateType value);
            a1_sm <= unpack({'0, pack(value)});
        endmethod
        method output_readbacks = a1_output_readbacks._write;
        method input_readbacks = a1_inputs._write;
    endinterface
    interface A0RegsReverse a0_block;
        method Bool a0_en();  // SM enable pin
            return power_control.a0a_en == 1;
        endmethod
        method Bool ignore_sp();
            return dbgCtrl_reg.ignore_sp == 1;
        endmethod 
        method Action state (A0StateType value);
            a0_sm <= unpack({'0, pack(value)});
        endmethod
        method Action ok(Bool value);
            a0_ok <= pack(value);
        endmethod
        method status1 = a0_status1._write;
        method status2 = a0_status2._write;
        method b_pgs = a0_groupB_pg._write;
        method c_pgs = a0_groupC_pg._write;
    endinterface
    interface NicRegsReverse nic_block;
        method Bool en;
            return power_control.a0a_en == 1;
        endmethod
        method Bool cld_rst_override;
            return dbgCtrl_reg.nic_cld_rst_override == 1;
        endmethod
        method Bool perst_override;
            return dbgCtrl_reg.nic_perst_override == 1;
        endmethod
        method Action ok(Bool value);
            nic_ok <= pack(value);
        endmethod
        method Action state(NicStateType value);
            nic_state <= unpack({'0, pack(value)});
        endmethod
        method pgs = nic_status._write;
        method nic_outs = nic2_out_status._write;
    endinterface
    //     // Normalized pin readbacks to registers
    //     //method input_readbacks = cur_a0_inputs.wset; // Input sampling
    //     //method output_readbacks = cur_a0_outputs.wset; // Output sampling
    //     //method dbg_ctrl = dbg_a0_outputs._read; // Output control
    //     method state = a0_state.wset;
    //     method Bit#(1) dbg_en;    // Debug enable pin
    //         return dbgCtrl_reg.reg_ctrl_en;
    //     endmethod
    //     method Bit#(1) ignore_sp;
    //         return dbgCtrl_reg.ignore_sp;
    //     endmethod
    //      method Bool a0_en();
    //         return power_control.a0a_en;
    //     endmethod
    // endinterface
    // interface MiscRegsReverse misc_block;
    //     method input_readbacks = cur_misc_inputs.wset; // Input sampling
    //     method output_readbacks = cur_misc_outputs.wset; // Output sampling
    //     method dbg_ctrl = dbg_misc_outputs._read; // Output control
    //     method Bit#(1) dbg_en;    // Debug enable pin
    //         return dbgCtrl_reg.reg_ctrl_en;
    //     endmethod
    // endinterface
    interface RegPins pins;
        method seq_to_sp_interrupt = irq_block.irq_pin;
        method brd_rev = brd_rev._write;
    endinterface

endmodule

endpackage