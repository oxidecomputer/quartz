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

interface GimletRegIF;
    interface Server#(RegRequest#(16, 8), RegResp#(8)) decoder_if;
     interface NicRegsReverse nic_block;
    // interface EarlyRegsReverse early_block;
    interface A1RegsReverse a1_block;
    interface A0RegsReverse a0_block;
    // interface MiscRegsReverse misc_block;
    method Bit#(1) seq_to_sp_interrupt;
endinterface

module mkGimletRegs(GimletRegIF);
    // Registers
    ConfigReg#(Scrtchpad) scratchpad <- mkReg(unpack('h0));
    ConfigReg#(DbgCtrl) dbgCtrl_reg <- mkReg(unpack(0)); // Debug mux control register
    // Main control registers
    ConfigReg#(Pwrctrl) power_control <- mkReg(unpack(0));
    //  NIC domain signals
    ConfigReg#(NicStatus) nic_status <- mkRegU();  // RO register for inputs
    ConfigReg#(OutStatusNic1) nic1_out_status <- mkRegU(); // RO register for outputs
    ConfigReg#(OutStatusNic2) nic2_out_status <- mkRegU(); // RO register for outputs
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
    ConfigReg#(A0OutStatus1) a0_status1 <- mkReg(unpack(0)); // a0OutStatus1Offset
    ConfigReg#(A0OutStatus2) a0_status2 <- mkReg(unpack(0)); // a0OutStatus2Offset
    ConfigReg#(A0DbgOut1) a0_dbg_out1 <- mkReg(unpack(0)); // a0DbgOut1Offset
    ConfigReg#(A0DbgOut2) a0_dbg_out2 <- mkReg(unpack(0)); // a0DbgOut1Offset
    ConfigReg#(AmdA0) a0_amd_rdbks <- mkReg(unpack(0)); // amdA0Offset
    ConfigReg#(GroupbPg) a0_groupB_pg <- mkReg(unpack(0)); // groupbPgOffset
    ConfigReg#(GroupbUnused) a0_groupB_unused <- mkReg(unpack(0)); //groupbUnusedOffset
    ConfigReg#(GroupbcFlts) a0_groupC_faults <-mkReg(unpack(0)); //groupbcFltsOffset
    ConfigReg#(GroupcPg) a0_groupC_pg <- mkReg(unpack(0)); // groupcPgOffset
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
    RWire#(OutStatusNic2) cur_nic2_out_status <- mkRWire();
    RWire#(EarlyPwrStatus) cur_early_outputs <- mkRWire();
    RWire#(EarlyRbks) cur_early_inputs <- mkRWire();

    Wire#(A1StateType) a1_state <- mkDWire(IDLE);
    // RWire#(A0StateType) a0_state <- mkRWire();
    ConfigReg#(NicStateType) nic_sm <- mkConfigRegU();
    
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
            fromInteger(ierOffset) : readdata <= tagged Valid (pack(irq_en_reg));
            fromInteger(ifrOffset) : readdata <= tagged Valid (pack(irq_block.cause_reg));
            fromInteger(pwrctrlOffset): readdata <= tagged Valid (pack(power_control));
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
        // NIC registers
        // nic_status      <= fromMaybe(nic_status, cur_nic_pins.wget());  // Always update from pins, no writing from sw.
        // nic1_out_status <= fromMaybe(nic1_out_status, cur_nic1_out_status.wget()); // Always update from pins, no writing from sw.
        // nic2_out_status <= fromMaybe(nic2_out_status, cur_nic2_out_status.wget()); // Always update from pins, no writing from sw.
        // dbg_nic1_out    <= reg_update(dbg_nic1_out, dbg_nic1_out, address, dbgOutNic1Offset, operation, writedata); // Normal sw register
        // dbg_nic2_out    <= reg_update(dbg_nic2_out, dbg_nic2_out, address, dbgOutNic2Offset, operation, writedata); // Normal sw register

        // // Early registers
        // early_inputs    <= fromMaybe(early_inputs, cur_early_inputs.wget());
        // early_output_rdbks <= fromMaybe(early_output_rdbks, cur_early_outputs.wget());
        // early_ctrl      <= reg_update(early_ctrl, early_ctrl, address, earlyPowerCtrlOffset, operation, writedata);

        // A1 registers
                // a1_output_readbacks <= fromMaybe(a1_output_readbacks, cur_a1_outputs.wget());
        a1_dbg <= reg_update(a1_dbg, a1_dbg, address, a1DbgOutOffset, operation, writedata);
        // a1_sm <= unpack(zeroExtend(pack(fromMaybe(?, a1_state.wget()))));
        // // A0 registers
        // let cur_a0_inputs_wget = fromMaybe(?, cur_a0_inputs.wget());  // This should always be a real value
        // let cur_a0_outputs_wget = fromMaybe(?, cur_a0_outputs.wget()); // This should always be a real value
        // // Misc registers
        // let cur_misc_ins = fromMaybe(?, cur_misc_inputs.wget());
        // let cur_misc_outs = fromMaybe(?, cur_misc_outputs.wget());
        // // TODO: should really write a function to do this
        // a0_sm <= unpack(zeroExtend(pack(fromMaybe(?, a0_state.wget()))));
        // a0_status1 <= A0OutStatus1 {
        //     efgh_en2: cur_a0_outputs_wget.pwr_cont_dimm_efgh_en2,
        //     abcd_en2: cur_a0_outputs_wget.pwr_cont_dimm_abcd_en2,
        //     efgh_en1: cur_a0_outputs_wget.pwr_cont_dimm_efgh_en1,
        //     v3p3_sys_en: cur_a0_outputs_wget.pwr_cont_dimm_abcd_en1,
        //     vtt_efgh_en: cur_a0_outputs_wget.seq_to_vtt_efgh_en,
        //     vtt_abcd_en: cur_a0_outputs_wget.seq_to_vtt_abcd_a0_en,
        //     vpp_efgh_en: cur_a0_outputs_wget.pwr_cont_dimm_efgh_en0,
        //     vpp_abcd_en: cur_a0_outputs_wget.pwr_cont_dimm_abcd_en0
        // };
        // a0_status2 <= A0OutStatus2 {
        //     pwr_good: cur_a0_outputs_wget.seq_to_sp3_pwr_good,
        //     pwr_btn: cur_a0_outputs_wget.sp_to_sp3_pwr_btn,
        //     cont2_en: cur_a0_outputs_wget.pwr_cont2_sp3_en,
        //     cont1_en: cur_a0_outputs_wget.pwr_cont1_sp3_en,
        //     v1p8_sp3_en: cur_a0_outputs_wget.seq_to_sp3_v1p8_en,
        //     u351_pwrok: cur_a0_outputs_wget.pwr_cont2_sp3_pwrok,
        //     u350_pwrok: cur_a0_outputs_wget.pwr_cont1_sp3_pwrok
        // };
        // dbg_a0_outputs <= A0OutPinsStruct {
        //     seq_to_sp3_sys_rst: amd_dbg_out.sys_reset,
        //     pwr_cont_dimm_abcd_en1: a0_dbg_out1.v3p3_sys_en,
        //     pwr_cont_dimm_efgh_en0: a0_dbg_out1.vpp_efgh_en,
        //     pwr_cont_dimm_efgh_en2: a0_dbg_out1.efgh_en2,
        //     pwr_cont2_sp3_pwrok: a0_dbg_out2.u351_pwrok,
        //     seq_to_sp3_v1p8_en: a0_dbg_out2.v1p8_sp3_en,
        //     pwr_cont1_sp3_pwrok: a0_dbg_out2.u350_pwrok,
        //     pwr_cont2_sp3_en: a0_dbg_out2.cont2_en,
        //     pwr_cont1_sp3_en: a0_dbg_out2.cont1_en,
        //     pwr_cont_dimm_abcd_en2: a0_dbg_out1.abcd_en2,
        //     pwr_cont_dimm_abcd_en0: a0_dbg_out1.vpp_abcd_en,
        //     pwr_cont_dimm_efgh_en1: a0_dbg_out1.efgh_en1,
        //     sp_to_sp3_pwr_btn: a0_dbg_out2.pwr_btn,
        //     seq_to_vtt_efgh_en: a0_dbg_out1.vtt_efgh_en,
        //     seq_to_sp3_pwr_good: a0_dbg_out2.pwr_good,
        //     seq_to_vtt_abcd_a0_en: a0_dbg_out1.vtt_efgh_en
        // };
        // a0_dbg_out1 <= reg_update(a0_dbg_out1, a0_dbg_out1, address, a0DbgOut1Offset, operation, writedata); // Normal sw register
        // a0_dbg_out2 <= reg_update(a0_dbg_out2, a0_dbg_out2, address, a0DbgOut2Offset, operation, writedata); // Normal sw register
        // a0_amd_rdbks <=  AmdA0 {
        //     reset: cur_a0_inputs_wget.sp3_to_seq_reset_v3p3,
        //     pwrok: cur_a0_inputs_wget.sp3_to_seq_pwrok_v3p3,
        //     slp_s5: cur_a0_inputs_wget.sp3_to_sp_slp_s5,
        //     slp_s3: cur_a0_inputs_wget.sp3_to_sp_slp_s3
        // };

        // a0_groupB_pg <= GroupbPg {
        //     v3p3_sys_pg: cur_a0_inputs_wget.pwr_cont_dimm_abcd_pg1,
        //     v1p8_sp3_pg: cur_a0_inputs_wget.seq_v1p8_sp3_vdd_pg,
        //     vtt_efgh_pg: cur_a0_inputs_wget.vtt_efgh_a0_to_seq_pg,
        //     vtt_abcd_pg: cur_a0_inputs_wget.vtt_abcd_a0_to_seq_pg,
        //     vdd_mem_efgh_pg: cur_a0_inputs_wget.pwr_cont2_sp3_pg1,
        //     vdd_mem_abcd_pg: cur_a0_inputs_wget.pwr_cont1_sp3_pg1,
        //     vpp_efgh_pg: cur_a0_inputs_wget.pwr_cont_dimm_efgh_pg0,
        //     vpp_abcd_pg: cur_a0_inputs_wget.pwr_cont_dimm_abcd_pg0
        // };

        // a0_groupB_unused <= GroupbUnused {
        //     efgh_pg2: cur_a0_inputs_wget.pwr_cont_dimm_efgh_pg2,
        //     efgh_pg1: cur_a0_inputs_wget.pwr_cont_dimm_efgh_pg1,
        //     abcd_pg2: cur_a0_inputs_wget.pwr_cont_dimm_abcd_pg2
        // };

        // a0_groupC_faults <= GroupbcFlts {
        //     cont2_cfp: cur_a0_inputs_wget.pwr_cont2_sp3_cfp,
        //     cont2_nvrhot: cur_a0_inputs_wget.pwr_cont2_sp3_nvrhot,
        //     efgh_cfp: cur_a0_inputs_wget.pwr_cont_dimm_efgh_cfp,
        //     efgh_nvrhot: cur_a0_inputs_wget.pwr_cont_dimm_efgh_nvrhot,
        //     abcd_cfp: cur_a0_inputs_wget.pwr_cont_dimm_abcd_cfp,
        //     abcd_nvrhot: cur_a0_inputs_wget.pwr_cont_dimm_abcd_nvrhot,
        //     cont1_cfp: cur_a0_inputs_wget.pwr_cont1_sp3_cfp,
        //     cont1_nvrhot: cur_a0_inputs_wget.pwr_cont1_sp3_nvrhot
        // };

        // a0_groupC_pg <= GroupcPg {
        //     vdd_vcore: cur_a0_inputs_wget.pwr_cont1_sp3_pg0,
        //     vddcr_soc_pg: cur_a0_inputs_wget.pwr_cont2_sp3_pg0
        // };

        // clkgen_out_status <= ClkgenOutStatus {
        //     seq_nmr: cur_misc_outs.clk_to_seq_nmr
        // };
        // clkgen_dbg_out <= reg_update(clkgen_dbg_out, clkgen_dbg_out, address, clkgenDbgOutOffset, operation, writedata); // Normal sw register

        // amd_out_status <= AmdOutStatus {
        //     sys_reset: cur_a0_outputs_wget.seq_to_sp3_sys_rst
        // };
        // amd_dbg_out <= reg_update(amd_dbg_out, amd_dbg_out, address, amdDbgOutOffset, operation, writedata); // Normal sw register
        
        // dbg_misc_outputs <= MiscOutPinsStruct {
        //     clk_to_seq_nmr: clkgen_dbg_out.seq_nmr
        //  };

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
    endinterface
    interface NicRegsReverse nic_block;
        method Bool en;
            return power_control.nicpwren == 1;
        endmethod
        method Action state(NicStateType value);
            nic_sm <= unpack({'0, pack(value)});
        endmethod
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

    method seq_to_sp_interrupt = irq_block.irq_pin;

endmodule

endpackage