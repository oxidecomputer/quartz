package GimletRegs;
// BSV imports
import DReg::*;
import DefaultValue::*;
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
    ConfigReg#(Id0) id0 <- mkReg(defaultValue);
    ConfigReg#(Id1) id1 <- mkReg(defaultValue);
    ConfigReg#(Scrtchpad) scratchpad <- mkReg(defaultValue);
    ConfigReg#(Cs0) fpga_cs0 <- mkReg(defaultValue);
    ConfigReg#(Cs1) fpga_cs1 <- mkReg(defaultValue);
    ConfigReg#(Cs2) fpga_cs2 <- mkReg(defaultValue);
    ConfigReg#(Cs3) fpga_cs3 <- mkReg(defaultValue);
    ConfigReg#(Status) status <- mkConfigRegU();
    ConfigReg#(DbgCtrl) dbgCtrl_reg <- mkReg(defaultValue);
    // Main control registers
    ConfigReg#(PwrCtrl) power_control <- mkReg(defaultValue);
    ConfigReg#(NicCtrl) nic_control <- mkReg(defaultValue);

    // Early output signals
    ConfigReg#(EarlyPower) early_output_rdbks  <- mkRegU();  // TODO: FIX ME
    ConfigReg#(EarlyRbks) early_inputs  <- mkRegU(); // TODO: FIX ME

    // TODO: want to set default to non-zero here
    ConfigReg#(EarlyPower) early_ctrl  <- mkReg(unpack('h06));  // want to force the 2V5 on due to level translator issue on gimlet.
    // A1 registers
    ConfigReg#(A1OutputType) a1_output_readbacks <- mkRegU();
    ConfigReg#(A1Readbacks) a1_inputs <- mkRegU();
    ConfigReg#(A1smstatus) a1_sm <- mkRegU();
    
    ConfigReg#(A0smstatus) a0_sm <- mkConfigRegU();
    // Misc IO registers
    ConfigReg#(ClkgenStatus) clkgen_out_status <- mkReg(unpack(0)); // TODO: FIX ME clkgenOutStatusOffset

    ConfigReg#(IrqType) irq_en_reg <- mkReg(unpack(0));
    ConfigReg#(IrqType) irq_cause_reg <- mkReg(unpack(0));
    ConfigReg#(IrqType) irq_dbg_flags <- mkDReg(unpack(0));
    ConfigReg#(IrqType) irq_clr_flags <- mkDReg(unpack(0));
    ConfigReg#(IrqType) irq_cause_raw <- mkDReg(unpack(0));

    ConfigReg#(UInt#(8)) amd_rstn_cnts <- mkConfigReg(0);
    ConfigReg#(UInt#(8)) amd_pwrokn_cnts <- mkConfigReg(0);

    PulseWire do_read <- mkPulseWire();
    PulseWire do_write <- mkPulseWire();
    PulseWire do_bitset <- mkPulseWire();
    PulseWire do_bitclear <- mkPulseWire();

    PulseWire amd_rstn_write <- mkPulseWire();
    PulseWire amd_pwrokn_write <- mkPulseWire();
    PulseWire amd_rstn_fedge <- mkPulseWire();
    PulseWire amd_pwrokn_fedge <- mkPulseWire();

    Reg#(Maybe#(Bit#(8))) readdata <- mkReg(tagged Invalid);

     // Combo inputs/outputs to/from the interface
    Wire#(Bit#(8)) writedata <- mkDWire(0);
    Wire#(Bit#(16)) address <- mkDWire(0);
    Wire#(RegOps) operation <- mkDWire(NOOP);
    // RWire#(NicStatus) cur_nic_pins <- mkRWire();
    RWire#(EarlyPower) cur_early_outputs <- mkRWire();
    RWire#(EarlyRbks) cur_early_inputs <- mkRWire();

    Wire#(A1smstatusA1sm) a1_state <- mkDWire(IDLE);
    Wire#(A0Output1Type) a0_status1 <- mkDWire(unpack(0));
    Wire#(A0Output2Type) a0_status2 <- mkDWire(unpack(0));
    Wire#(AmdA0) amd_a0 <- mkDWire(unpack(0));
    Wire#(AmdStatus) amd_status <- mkDWire(unpack(0));
    Wire#(GroupbPg) a0_groupB_pg <- mkDWire(unpack(0));
    Wire#(GroupcPg) a0_groupC_pg <- mkDWire(unpack(0));
    Wire#(NicStatus) nic_status <- mkDWire(unpack(0));
    Wire#(Nicsmstatus) nic_state <- mkDWire(unpack(0));
    Wire#(BoardRev) brd_rev <- mkDWire(unpack(0));
    Wire#(GroupbcFlts) bc_flts <- mkDWire(unpack(0));
    Wire#(Bit#(1)) a0_ok <- mkDWire(0);
    Wire#(Bit#(1)) a1_ok <- mkDWire(0);
    Wire#(Bit#(1)) nic_ok <- mkDWire(0);
    Wire#(Bit#(1)) fan_ok <- mkDWire(1);
    Wire#(Bool) nic_mapo <- mkDWire(False);
    Wire#(Bool) a0_mapo <- mkDWire(False);
    Wire#(Bool) a1_mapo <- mkDWire(False);
    Wire#(Bool) thermtrip <- mkDWire(False);
    Wire#(Bool) fanfault <- mkDWire(False);
    Wire#(NicOutput2Type) nic2_out_status <- mkDWire(unpack(0));
    Wire#(NicOutput1Type) nic1_out_status <- mkDWire(unpack(0));
    Wire#(NicCtrl) nic_ctrl_next <- mkDWire(defaultValue);

    IRQBlock#(IrqType) irq_block <- mkIRQBlock();

    mkConnection(irq_en_reg, irq_block.enables);
    mkConnection(irq_dbg_flags, irq_block.debug);
    mkConnection(irq_clr_flags, irq_block.clear);
    mkConnection(irq_cause_raw, irq_block.cause_raw);

    rule do_amd_cnts;
        // Register writes take precedence and reset the counter.
        if (amd_rstn_write) begin
            amd_rstn_cnts <= 0;
        // Saturating counter
        end else if (amd_rstn_fedge && amd_rstn_cnts < 255) begin
            amd_rstn_cnts <= amd_rstn_cnts + 1;
        end
        // Register writes take precedence and reset the counter.
        if (amd_rstn_write) begin
            amd_pwrokn_cnts <= 0;
         // Saturating counter
        end else if (amd_pwrokn_fedge && amd_pwrokn_cnts < 255) begin
            amd_pwrokn_cnts <= amd_pwrokn_cnts + 1;
        end
    endrule

    rule do_status;
        status <= Status {
            int_pend: irq_block.irq_pin,
            nicpwrok: nic_ok,
            a0pwrok: a0_ok,
            a1pwrok: a1_ok,
            fanpwrok: 1
        };
    endrule

    rule do_irqs;
        irq_cause_raw <= IrqType {
            amd_rstn_fedge: pack(amd_rstn_cnts != 0),
            amd_pwrok_fedge: pack(amd_pwrokn_cnts != 0),
            nicmapo: pack(nic_mapo),
            a0mapo: pack(a0_mapo),
            a1mapo: pack(a1_mapo),
            thermtrip: pack(thermtrip),
            fanfault: pack(fanfault)
        };
    endrule

    // SW readbacks
    (* fire_when_enabled, no_implicit_conditions *)
    rule do_reg_read (do_read && !isValid(readdata));
        case (address)
            fromInteger(id0Offset) : readdata <= tagged Valid (pack(id0));
            fromInteger(id1Offset) : readdata <= tagged Valid (pack(id1));
            fromInteger(ver0Offset) : readdata <= tagged Valid (version[0]);
            fromInteger(ver1Offset) : readdata <= tagged Valid (version[1]);
            fromInteger(ver2Offset) : readdata <= tagged Valid (version[2]);
            fromInteger(ver3Offset) : readdata <= tagged Valid (version[3]);
            fromInteger(sha0Offset) : readdata <= tagged Valid (sha[0]);
            fromInteger(sha1Offset) : readdata <= tagged Valid (sha[1]);
            fromInteger(sha2Offset) : readdata <= tagged Valid (sha[2]);
            fromInteger(sha3Offset) : readdata <= tagged Valid (sha[3]);
            fromInteger(cs0Offset) : readdata <= tagged Valid (pack(fpga_cs0));
            fromInteger(cs1Offset) : readdata <= tagged Valid (pack(fpga_cs1));
            fromInteger(cs2Offset) : readdata <= tagged Valid (pack(fpga_cs2));
            fromInteger(cs3Offset) : readdata <= tagged Valid (pack(fpga_cs3));
            fromInteger(scrtchpadOffset) : readdata <= tagged Valid (pack(scratchpad));
            fromInteger(ifrOffset) : readdata <= tagged Valid (pack(irq_block.cause_reg));
            fromInteger(ierOffset) : readdata <= tagged Valid (pack(irq_en_reg));
            fromInteger(statusOffset) : readdata <= tagged Valid (pack(status));
            fromInteger(earlyPowerCtrlOffset) : readdata <= tagged Valid (pack(early_ctrl));
            fromInteger(pwrCtrlOffset): readdata <= tagged Valid (pack(power_control));
            fromInteger(nicCtrlOffset): readdata <= tagged Valid (pack(nic_control));
            fromInteger(a1smstatusOffset) : readdata <= tagged Valid (pack(a1_sm));
            fromInteger(a0smstatusOffset) : readdata <= tagged Valid (pack(a0_sm));
            fromInteger(nicsmstatusOffset) : readdata <= tagged Valid (pack(nic_state));
            fromInteger(boardRevOffset): readdata <= tagged Valid (pack(brd_rev));
            fromInteger(earlyRbksOffset) : readdata <= tagged Valid (pack(early_inputs));
            fromInteger(a1ReadbacksOffset) : readdata <= tagged Valid (pack(a1_inputs));
            fromInteger(amdA0Offset) : readdata <= tagged Valid (pack(amd_a0));
            fromInteger(groupbPgOffset) : readdata <= tagged Valid (pack(a0_groupB_pg));
            fromInteger(groupbcFltsOffset) : readdata <= tagged Valid (pack(bc_flts));
            fromInteger(groupcPgOffset) : readdata <= tagged Valid (pack(a0_groupC_pg));
            fromInteger(nicStatusOffset) : readdata <= tagged Valid (pack(nic_status));
            // clock gen status
            fromInteger(amdStatusOffset) : readdata <= tagged Valid (pack(amd_status));
            // fanoutstatus
            fromInteger(earlyPwrStatusOffset) : readdata <= tagged Valid (pack(early_output_rdbks));
            fromInteger(a1OutStatusOffset) : readdata <= tagged Valid (pack(a1_output_readbacks));
            fromInteger(a0OutStatus1Offset) : readdata <= tagged Valid (pack(a0_status1));
            fromInteger(a0OutStatus2Offset) : readdata <= tagged Valid (pack(a0_status2));
            fromInteger(outStatusNic1Offset) : readdata <= tagged Valid (pack(nic1_out_status));
            fromInteger(outStatusNic2Offset) : readdata <= tagged Valid (pack(nic2_out_status));
            //fromInteger(clkgenOutStatusOffset) : readdata <= tagged Valid (pack(clkgen_out_status));
            fromInteger(dbgCtrlOffset) : readdata <= tagged Valid (pack(dbgCtrl_reg));
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
        fpga_cs0 <= reg_update(fpga_cs0, fpga_cs0, address, cs0Offset, operation, writedata);
        fpga_cs1 <= reg_update(fpga_cs1, fpga_cs1, address, cs1Offset, operation, writedata);
        fpga_cs2 <= reg_update(fpga_cs2, fpga_cs2, address, cs2Offset, operation, writedata);
        fpga_cs3 <= reg_update(fpga_cs3, fpga_cs3, address, cs3Offset, operation, writedata);
        dbgCtrl_reg <= reg_update(dbgCtrl_reg, dbgCtrl_reg, address, dbgCtrlOffset, operation, writedata); // Normal sw register
        power_control <= reg_update(power_control, power_control, address, pwrCtrlOffset, operation, writedata);
        
        // This is a super ugly hack to synthesize a write of the reset value when A0_ok goes bad
        // There has to be a better way of doing this!!!
        if (a0_ok == 1) begin
            nic_control <= reg_update(nic_control, nic_control, address, nicCtrlOffset, operation, writedata);
        end else begin
            nic_control <= reg_update(nic_control, nic_control, fromInteger(nicCtrlOffset), nicCtrlOffset, WRITE, pack(nic_ctrl_next));
        end

        // Deal with register writes making clear signals
        // if (do_write && address == fromInteger()) begin
        //     amd_rstn_write.send();
        // end
        // if (do_write && address == fromInteger()) begin
        //     amd_pwrokn_write.send();
        // end
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

    interface A1RegsReverse a1_block;
        method Bool a1_en();
            return power_control.a1pwren == 1;
        endmethod
        method Action ok(Bool value);
            a1_ok <= pack(value);
        endmethod
        method Action state(A1smstatusA1sm value);
            a1_sm <= unpack({'0, pack(value)});
        endmethod
        method output_readbacks = a1_output_readbacks._write;
        method input_readbacks = a1_inputs._write;
        method mapo = a1_mapo._write;
    endinterface
    interface A0RegsReverse a0_block;
        method Bool a0_en();  // SM enable pin
            return power_control.a0a_en == 1;
        endmethod
        method Bool ignore_sp();
            return dbgCtrl_reg.ignore_sp == 1;
        endmethod 
        method Action state (A0smstatusA0sm value);
            a0_sm <= unpack({'0, pack(value)});
        endmethod
        method Action ok(Bool value);
            a0_ok <= pack(value);
        endmethod
        method status1 = a0_status1._write;
        method status2 = a0_status2._write;
        method amd_status = amd_status._write;
        method amd_a0 = amd_a0._write;
        method b_pgs = a0_groupB_pg._write;
        method c_pgs = a0_groupC_pg._write;
        method bc_flts = bc_flts._write;
        method thermtrip = thermtrip._write;
        method mapo = a0_mapo._write;
        method Action amd_reset_fedge(Bool value);
            if (value) begin
                amd_rstn_fedge.send();
            end
        endmethod
        method Action amd_pwrok_fedge(Bool value);
            if (value) begin
                amd_pwrokn_fedge.send();
            end
        endmethod
    endinterface
    interface NicRegsReverse nic_block;
        method Bool en;
            return power_control.a0a_en == 1;
        endmethod
        method Bool sw_reset;
            return nic_control.cld_rst == 1;
        endmethod
        method Bool cld_rst_override;
            return dbgCtrl_reg.nic_cld_rst_override == 1;
        endmethod
        method Bool perst_override;
            return dbgCtrl_reg.nic_perst_override == 1;
        endmethod
        method Bool perst_solo;
            return dbgCtrl_reg.nic_perst_solo == 1;
        endmethod
        method Action ok(Bool value);
            nic_ok <= pack(value);
        endmethod
        method Action state(NicStateType value);
            nic_state <= unpack({'0, pack(value)});
        endmethod
        method pgs = nic_status._write;
        method nic_outs = nic2_out_status._write;
        method nic_ens = nic1_out_status._write;
        method mapo = nic_mapo._write;
    endinterface

    interface RegPins pins;
        method seq_to_sp_interrupt = irq_block.irq_pin;
        method brd_rev = brd_rev._write;
    endinterface

endmodule

endpackage