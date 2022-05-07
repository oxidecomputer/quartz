package A0Block;

// BSV imports
import Assert::*;
import BuildVector::*;
import Clocks::*;
import ClientServer::*;
import Connectable::*;
import ConfigReg::*;
import DReg::*;
import GetPut::*;
import StmtFSM::*;
import Vector::*;

// cobalt imports
import TestUtils::*;

// Local imports
import GimletSeqFpgaRegs::*;
import PowerRail::*;

    interface A0Regs;
        method Action a0_en(Bool value);  // SM enable pin
        method Action ignore_sp(Bool value);
        method A0StateType state();
        method A0OutStatus1 status1;
        method A0OutStatus2 status2;
        method GroupbPg b_pgs;
        method GroupcPg c_pgs;
        // method A0OutStatus output_readbacks();
        // method A0Readbacks input_readbacks();
    endinterface

    interface A0RegsReverse;
        // method Action dbg_ctrl(A1DbgOut value); // Output control
        // method Action dbg_en(Bool value);    // Debug enable pin
        method Bool a0_en();  // SM enable pin
        method Bool ignore_sp();
        method Action state (A0StateType value);
        method Action status1 (A0OutStatus1 value);
        method Action status2 (A0OutStatus2 value);
        method Action b_pgs (GroupbPg value);
        method Action c_pgs (GroupcPg value);
        // method Action output_readbacks (A0OutStatus value);
        // method Action input_readbacks (A0Readbacks value);
    endinterface

    // Allow our output pin source to connect to our output pin sink
    instance Connectable#(A0Regs, A0RegsReverse);
        module mkConnection#(A0Regs source, A0RegsReverse sink) (Empty);
            mkConnection(source.a0_en, sink.a0_en);
            mkConnection(source.ignore_sp, sink.ignore_sp);
            mkConnection(source.state, sink.state);
            mkConnection(source.status1, sink.status1);
            mkConnection(source.status2, sink.status2);
            mkConnection(source.b_pgs, sink.b_pgs);
            mkConnection(source.c_pgs, sink.c_pgs);
        endmodule
    endinstance

    interface FpgaSP3;
        // From SP3
        method Action sp3_to_seq_pwrgd_out(Bit#(1) value);
        method Action sp3_to_seq_slp_s3_l(Bit#(1) value);
        method Action sp3_to_seq_slp_s5_l(Bit#(1) value);
        method Action sp3_to_seq_pwrok_v3p3(Bit#(1) value);
        method Action sp3_to_seq_reset_v3p3_l(Bit#(1) value);
        method Action sp3_to_seq_thermtrip_l(Bit#(1) value);
        // To SP3
        method Bit#(1) seq_to_sp3_sys_rst_l();
        method Bit#(1) seq_to_sp3_pwr_btn_l();
        method Bit#(1) seq_to_sp3_pwr_good();
    endinterface

    interface SP3;
        // From SP3
        method Bit#(1) sp3_to_seq_pwrgd_out();
        method Bit#(1) sp3_to_seq_slp_s3_l();
        method Bit#(1) sp3_to_seq_slp_s5_l();
        method Bit#(1) sp3_to_seq_pwrok_v3p3();
        method Bit#(1) sp3_to_seq_reset_v3p3_l();
        method Bit#(1) sp3_to_seq_thermtrip_l();
        // To SP3
        method Action seq_to_sp3_sys_rst_l(Bit#(1) value);
        method Action seq_to_sp3_pwr_btn_l(Bit#(1) value);
        method Action seq_to_sp3_pwr_good(Bit#(1) value);
    endinterface

    instance Connectable#(FpgaSP3, SP3);
        module mkConnection#(FpgaSP3 source, SP3 sink) (Empty);
            mkConnection(source.sp3_to_seq_pwrgd_out, sink.sp3_to_seq_pwrgd_out);
            mkConnection(source.sp3_to_seq_slp_s3_l, sink.sp3_to_seq_slp_s3_l);
            mkConnection(source.sp3_to_seq_slp_s5_l, sink.sp3_to_seq_slp_s5_l);
            mkConnection(source.sp3_to_seq_pwrok_v3p3, sink.sp3_to_seq_pwrok_v3p3);
            mkConnection(source.sp3_to_seq_reset_v3p3_l, sink.sp3_to_seq_reset_v3p3_l);
            mkConnection(source.sp3_to_seq_thermtrip_l, sink.sp3_to_seq_thermtrip_l);
            mkConnection(source.seq_to_sp3_sys_rst_l, sink.seq_to_sp3_sys_rst_l);
            mkConnection(source.seq_to_sp3_pwr_btn_l, sink.seq_to_sp3_pwr_btn_l);
            mkConnection(source.seq_to_sp3_pwr_good, sink.seq_to_sp3_pwr_good);
        endmodule
    endinstance
    

     // A1 block interfaces
    interface A0Pins;
        interface FpgaSP3 sp3;
        interface PowerRail::Pins vpp_abcd;
        interface PowerRail::Pins vpp_efgh;
        interface PowerRail::Pins v3p3_sys;
        interface PowerRail::Pins v1p8_sp3;
        interface PowerRail::Pins vdd_mem_abcd;
        interface PowerRail::Pins vdd_mem_efgh;
        interface PowerRail::Pins vtt_ab;
        interface PowerRail::Pins vtt_cd;
        interface PowerRail::Pins vtt_ef;
        interface PowerRail::Pins vtt_gh;

        method Bit#(1) pwr_cont1_sp3_pwrok;
        method Bit#(1) pwr_cont2_sp3_pwrok;
        method Action pwr_cont1_sp3_pg0(Bit#(1) value);
        method Action pwr_cont2_sp3_pg0(Bit#(1) value);
    endinterface

    interface A0BlockTop;
        interface A0Pins pins;
        method Action hp_idle(Bool value);
        method Action a1_ok(Bool value);
        method Bool a0_idle;
        method Bool a0_ok;
        interface A0Regs reg_if;
    endinterface

    typedef enum {
        IDLE = 'h00,
        PBTN = 'h01,           // 0x01
        WAITSLP = 'h02,        // 0x02
        GROUPB1_EN = 'h03,     // 0x03
        GROUPB1_PG = 'h04,     // 0x04
        GROUPB2_EN = 'h05,     // 0x05
        GROUPB2_PG = 'h06,     // 0x06
        GROUPC_PG = 'h07,      // 0x07
        DELAY_1MS = 'h08,      // 0x08
        ASSERT_PG = 'h09,      // 0x09
        WAIT_PWROK = 'h0a,     // 0x0a
        WAIT_RESET_L = 'h0b,   // 0x0b
        DONE = 'h0c,           // 0x0c
        SAFE_DISABLE = 'h0d    // 0x0d
   
    } A0StateType deriving (Eq, Bits);



module mkA0BlockSeq#(Integer one_ms_counts)(A0BlockTop);
    Integer two_ms = 2 * one_ms_counts;
    Integer five_ms = 5 * one_ms_counts;
    Integer ten_ms = 10 * one_ms_counts;
    Integer pbtn_low_ms = 20 * one_ms_counts;
    Integer onehundred_ms = 100 * one_ms_counts;
    Integer startup_delay = ten_ms;
    
    Reg#(A0StateType) state <- mkReg(IDLE);

    Reg#(UInt#(24)) ticks_count <- mkReg(0);
    RWire#(UInt#(24)) ticks_count_next <- mkRWire();
    Reg#(Bool)    ok <- mkReg(False);
    Reg#(Bool) abort <- mkDReg(False);
    Reg#(Bool) faulted <- mkReg(False);
    Reg#(Bool) enable_last <- mkReg(False);
    Reg#(Bool) enable <- mkReg(False);
    Reg#(Bool) ignore_sp <- mkReg(False);
    Reg#(Bool) downstream_idle <- mkDReg(True);
    Reg#(Bool) upstream_ok <- mkDReg(False);
    Reg#(Bool) regulator_pwrok <- mkReg(False);
    
    Wire#(Bool) b1_pg <- mkDWire(False);
    Wire#(Bool) b2_pg <- mkDWire(False);
    Wire#(Bool) c_pg <- mkDWire(False);
    
    Wire#(Bool) aggregate_pg <- mkDWire(False);
    Wire#(Bool) aggregate_fault <- mkDWire(False);

    ConfigReg#(A0OutStatus1) status1 <- mkConfigRegU();
    ConfigReg#(A0OutStatus2) status2 <- mkConfigRegU();
    ConfigReg#(GroupbPg) b_pgs <- mkConfigRegU();
    ConfigReg#(GroupcPg) c_pgs <- mkConfigRegU();

    // Power rails here
    // Group B1:
    PowerRail vpp_abcd <- mkPowerRail(ten_ms, False);
    PowerRail vpp_efgh <- mkPowerRail(ten_ms, False);
    PowerRail v3p3_sys <- mkPowerRail(ten_ms, False);
    PowerRail v1p8_vdd_18 <- mkPowerRail(ten_ms, False);
    // Group B2:
    PowerRail vdd_mem_abcd <- mkPowerRail(ten_ms, False);
    PowerRail vdd_mem_efgh <- mkPowerRail(ten_ms, False);
    PowerRail vtt_ab <- mkPowerRail(ten_ms, False);
    PowerRail vtt_cd <- mkPowerRail(ten_ms, False);
    PowerRail vtt_ef <- mkPowerRail(ten_ms, False);
    PowerRail vtt_gh <- mkPowerRail(ten_ms, False);
    // Group C:
    
    // Pin references
    Wire#(Bit#(1)) sp3_to_seq_pwrgd_out <- mkDWire(0);
    Wire#(Bit#(1)) sp3_to_seq_slp_s3_l <- mkDWire(0);
    Wire#(Bit#(1)) sp3_to_seq_slp_s5_l <- mkDWire(0);
    Wire#(Bit#(1)) sp3_to_seq_pwrok_v3p3 <- mkDWire(0);
    Wire#(Bit#(1)) sp3_to_seq_reset_v3p3_l <- mkDWire(0);
    Wire#(Bit#(1)) pwr_cont1_sp3_pg0 <- mkDWire(0);
    Wire#(Bit#(1)) pwr_cont2_sp3_pg0 <- mkDWire(0);
    Wire#(Bit#(1)) sp3_to_seq_thermtrip_l <- mkDWire(1);

    // Output registers
    Reg#(Bit#(1)) seq_to_sp3_sys_rst_l <- mkReg(1);  // In practice we don't use this
    Reg#(Bit#(1)) seq_to_sp3_pwr_btn_l <- mkReg(1);
    Reg#(Bit#(1)) seq_to_sp3_pwr_good <- mkReg(0);

    Vector#(4, PowerRail) b1_rails =
        vec(vpp_abcd, vpp_efgh, v3p3_sys, v1p8_vdd_18);
    
    Vector#(6, PowerRail) b2_rails =
        vec(vdd_mem_abcd, vdd_mem_efgh, vtt_ab, vtt_cd,
            vtt_ef, vtt_gh);

    function Action enable_rails(Vector#(n, PowerRail) rails, A0StateType step) =
        action
            state <= step;
            for (int i = 0; i < fromInteger(valueof(n)); i=i+1)
                rails[i].set_enabled(True);
        endaction;
    
    function Action disable_rails(Vector#(n, PowerRail) rails, A0StateType step) =
            action
                state <= step;
                for (int i = 0; i < fromInteger(valueof(n)); i=i+1)
                    rails[i].set_enabled(False);
            endaction;

    function Stmt delay(Integer d, A0StateType step) =
        seq
            action
                state <= step;
                ticks_count_next.wset(fromInteger(d + 1));
            endaction
            await(ticks_count == 0);
        endseq;
    function bool_or(a, b) = a || b;
    function bool_and(a, b) = a && b;


    //
    // Basic down counter -- pre-load
    //
    (* fire_when_enabled *)
    rule do_set_ticks_count (ticks_count_next.wget matches tagged Valid .value);
        ticks_count <= value;
    endrule

    //
    // Basic down counter -- counts
    //
    (* fire_when_enabled *)
    rule do_count_ticks (!isValid(ticks_count_next.wget));
        ticks_count <= satMinus(Sat_Zero, ticks_count, 1);
    endrule

    (* fire_when_enabled *)
    rule do_pgs;
        b1_pg <= foldr(bool_and, True, map(PowerRail::good, b1_rails));
        b2_pg <= foldr(bool_and, True, map(PowerRail::good, b2_rails));
        c_pg <= (pwr_cont2_sp3_pg0 == 1) && (pwr_cont1_sp3_pg0 == 1);
    endrule

    (* fire_when_enabled *)
    rule do_ps_faults;
        aggregate_fault <= foldr(bool_or, False, map(PowerRail::fault, b1_rails)) ||
                           foldr(bool_or, False, map(PowerRail::fault, b2_rails)) ||
                           (!c_pg && pack(state) >=pack(DELAY_1MS));
    endrule

    FSM a0_power_up_seq <- mkFSMWithPred(seq
        // Want an initial delay
        delay(startup_delay, IDLE);
        // Assert PWR_BTN_L (timing rules = 15ms minimum, per AMD 55441
        action
            state <= PBTN;
            seq_to_sp3_pwr_btn_l <= 0;
        endaction
        delay(pbtn_low_ms, WAITSLP);
        // De-assert PWR_BTN
        action
            seq_to_sp3_pwr_btn_l <= 1;
        endaction
        // Wait for slp_x_l signals to de-assert from SP3
        await(ignore_sp || (sp3_to_seq_slp_s3_l == 1 && sp3_to_seq_slp_s5_l == 1));
        //
        // GroupB1 enable
        //
        enable_rails(b1_rails, GROUPB1_EN);
        // Wait for groupB1 PGs
        action
            state <= GROUPB1_PG;
        endaction
        await(b1_pg);
        //
        // GroupB2 enable
        //
        enable_rails(b2_rails, GROUPB2_EN);
        action
            state <= GROUPB2_PG;
        endaction
        await(b2_pg);
        //
        // GroupC PGs (SMBus enabled so we just wait)
        //
        action
            state <= GROUPC_PG;
        endaction
        await(c_pg);
        // Delay 1 ms before asserting PG
        delay(one_ms_counts, DELAY_1MS);
        // Assert PowerGood to AMD
        action
            state <= ASSERT_PG;
            seq_to_sp3_pwr_good <= 1;
        endaction
        action
            state <= WAIT_PWROK;
        endaction
        // Wait for AMD's power OK handshake
        await(ignore_sp || (sp3_to_seq_pwrok_v3p3 == 1));
        // Wait for AMD's RESET_L de-assert
        action
            state <= WAIT_RESET_L;
        endaction
        await(ignore_sp || (sp3_to_seq_reset_v3p3_l == 1));
        // We're done
        action
            state <= DONE;
        endaction
    endseq, enable && !faulted && !abort && upstream_ok);

    //
    // This is normal power down sequence where we take away
    // PWR_GOOD and delay before taking away the rails from
    // the AMD
    //
    FSM a0_normal_power_down_seq <- mkFSMWithPred(seq
        // TODO: can we skip this if we're already off?
        action
            seq_to_sp3_pwr_good <= 0;
        endaction
        // Wait a bit
        delay(ten_ms, SAFE_DISABLE);
        // disable rails
        disable_rails(b2_rails, SAFE_DISABLE);
        disable_rails(b1_rails, SAFE_DISABLE);
        action
            seq_to_sp3_pwr_btn_l <= 1;           
            state <= IDLE;
        endaction
    endseq, !enable && !faulted && upstream_ok);

    //
    // This is the faulted power down sequence with no
    // delays, just immediate power off.
    //
    FSM a0_fault_power_down_seq <- mkFSMWithPred(seq
        action
            seq_to_sp3_pwr_good <= 0;
        endaction
        // disable rails
        disable_rails(b2_rails, SAFE_DISABLE);
        disable_rails(b1_rails, SAFE_DISABLE);
        action
            seq_to_sp3_pwr_btn_l <= 1;           
            state <= IDLE;
        endaction
    endseq, faulted || !upstream_ok);

    (* fire_when_enabled *)
    rule do_enable;
        enable_last <= enable;
        if (state != IDLE && faulted) begin
            // In a fault case, we're going to immediately power off
            // regardless of the rest of the system state.
            a0_fault_power_down_seq.start();
        end else if (state == IDLE && enable && upstream_ok) begin
            // When we're enabled, IDLE and the previous power-stage is ok
            // we can start the normal power-up sequence
            a0_power_up_seq.start();
        end else if (!enable && state != IDLE && downstream_idle) begin
            // Even if we clear the enable, we can't start the
            // power-down until the down-stream logic has finished
            // powering off.
            a0_fault_power_down_seq.start();
        end
    endrule

    (* fire_when_enabled *)
    rule raa_power_ok;
        if (pack(state) >= pack(WAIT_PWROK)) begin
            regulator_pwrok <= (sp3_to_seq_pwrok_v3p3 == 1);
        end else begin
            regulator_pwrok <= False;
        end
    endrule

    (* fire_when_enabled *)
    rule do_fault_mon;
        // Thermtrip rails only valid after V3P3_SYS_A0 is up.
        if (v3p3_sys.good && sp3_to_seq_thermtrip_l == 0) begin
            faulted <= True;
        // If an enabled rail faults, set the faulted flag
        end else if (aggregate_fault) begin
            faulted <= True;
        // Faulted prevents us from re-starting unless the block has
        // been disabled, preventing failure loops without software
        // involvement.
        end else if (!enable) begin
            faulted <= False;
        end
    endrule

    (* fire_when_enabled *)
    rule do_readbacks;
        status1 <= A0OutStatus1 {
                vtt_efgh_en    : vtt_ef.pins.en,
                vtt_abcd_en    : vtt_ab.pins.en,
                vdd_mem_efgh_en: vdd_mem_efgh.pins.en,
                vdd_mem_abcd_en: vdd_mem_abcd.pins.en,
                v1p8_sp3_vdd_en: v1p8_vdd_18.pins.en,
                v3p3_sys_en    : v3p3_sys.pins.en,
                vpp_efgh_en    : vpp_efgh.pins.en,
                vpp_abcd_en    : vpp_abcd.pins.en

        };

        b_pgs <= GroupbPg {
                v3p3_sys_pg    : pack(v3p3_sys.good),
                v1p8_sp3_pg    : pack(v1p8_vdd_18.good),
                vtt_efgh_pg    : pack(vtt_ef.good && vtt_gh.good),
                vtt_abcd_pg    : pack(vtt_ab.good && vtt_cd.good),
                vdd_mem_efgh_pg: pack(vdd_mem_efgh.good),
                vdd_mem_abcd_pg: pack(vdd_mem_abcd.good),
                vpp_efgh_pg    : pack(vpp_efgh.good),
                vpp_abcd_pg    : pack(vpp_abcd.good)
        };
        c_pgs <= GroupcPg{
            vdd_vcore: pwr_cont1_sp3_pg0,
            vddcr_soc_pg: pwr_cont2_sp3_pg0
        };
    endrule

    interface A0Pins pins;
        interface FpgaSP3 sp3;
            // From SP3
            method sp3_to_seq_pwrgd_out = sp3_to_seq_pwrgd_out._write;
            method sp3_to_seq_slp_s3_l = sp3_to_seq_slp_s3_l._write;
            method sp3_to_seq_slp_s5_l = sp3_to_seq_slp_s5_l._write;
            method sp3_to_seq_pwrok_v3p3 = sp3_to_seq_pwrok_v3p3._write;
            method sp3_to_seq_reset_v3p3_l = sp3_to_seq_reset_v3p3_l._write;
            method sp3_to_seq_thermtrip_l = sp3_to_seq_thermtrip_l._write;
            // To SP3
            method seq_to_sp3_sys_rst_l = seq_to_sp3_sys_rst_l._read;
            method seq_to_sp3_pwr_btn_l = seq_to_sp3_pwr_btn_l._read;
            method seq_to_sp3_pwr_good = seq_to_sp3_pwr_good._read;
        endinterface
        interface PowerRail::Pins vpp_abcd = vpp_abcd.pins;
        interface PowerRail::Pins vpp_efgh = vpp_efgh.pins;
        interface PowerRail::Pins v3p3_sys = v3p3_sys.pins;
        interface PowerRail::Pins v1p8_sp3 = v1p8_vdd_18.pins;
        interface PowerRail::Pins vdd_mem_abcd = vdd_mem_abcd.pins;
        interface PowerRail::Pins vdd_mem_efgh = vdd_mem_efgh.pins;
        interface PowerRail::Pins vtt_ab = vtt_ab.pins;
        interface PowerRail::Pins vtt_cd = vtt_cd.pins;
        interface PowerRail::Pins vtt_ef = vtt_ef.pins;
        interface PowerRail::Pins vtt_gh = vtt_gh.pins;
        method pwr_cont1_sp3_pg0 = pwr_cont1_sp3_pg0._write;
        method pwr_cont2_sp3_pg0 = pwr_cont2_sp3_pg0._write;
        method Bit#(1) pwr_cont1_sp3_pwrok;
            return pack(regulator_pwrok);
        endmethod
        method Bit#(1) pwr_cont2_sp3_pwrok;
            return pack(regulator_pwrok);
        endmethod
    endinterface
    method hp_idle = downstream_idle._write;
    method a1_ok = upstream_ok._write;
    method Bool a0_idle;
        return (state == IDLE);
    endmethod
    method Bool a0_ok;
        return (state == DONE);
    endmethod
    interface A0Regs reg_if;
        method a0_en = enable._write;
        method ignore_sp = ignore_sp._write;
        method state = state._read;
        method status1 = status1._read;
        method status2 = status2._read;
        method b_pgs = b_pgs._read;
        method c_pgs = c_pgs._read;
    endinterface

endmodule


interface Bench;
    interface PowerRailModel vpp_abcd;
    interface PowerRailModel vpp_efgh;
    interface PowerRailModel v3p3_sys;
    interface PowerRailModel v1p8_sp3;
    interface PowerRailModel vdd_mem_abcd;
    interface PowerRailModel vdd_mem_efgh;
    interface PowerRailModel vtt_ab;
    interface PowerRailModel vtt_cd;
    interface PowerRailModel vtt_ef;
    interface PowerRailModel vtt_gh;

    method A0StateType dut_state();
    method Action sp3_disable(Bool value);
    method Action pmbus_on();
    method Action pmbus_off();
    method Action power_up();
    method Action power_down();
    method Action downstream_busy();
    method Action downstream_idle();

endinterface

module mkBench(Bench);

    PowerRailModel vpp_abcd_rail <- mkPowerRailModel("vpp_abcd");
    PowerRailModel vpp_efgh_rail <- mkPowerRailModel("vpp_efgh");
    PowerRailModel v3p3_sys_rail <- mkPowerRailModel("v3p3_sys");
    PowerRailModel v1p8_vdd_18_rail <- mkPowerRailModel("v1p8_vdd_18");
    PowerRailModel vdd_mem_abcd_rail <- mkPowerRailModel("vdd_mem_abcd");
    PowerRailModel vdd_mem_efgh_rail <- mkPowerRailModel("vdd_mem_efgh");
    PowerRailModel vtt_ab_rail <- mkPowerRailModel("vtt_ab");
    PowerRailModel vtt_cd_rail <- mkPowerRailModel("vtt_cd");
    PowerRailModel vtt_ef_rail <- mkPowerRailModel("vtt_ef");
    PowerRailModel vtt_gh_rail <- mkPowerRailModel("vtt_gh");

    A0BlockTop dut <- mkA0BlockSeq(100);

    SP3Model sp3 <- mkSP3Model();

    mkConnection(dut.pins.sp3, sp3.pins);
    mkConnection(vtt_ab_rail.pins, dut.pins.vtt_ab);
    mkConnection(vtt_cd_rail.pins, dut.pins.vtt_cd);
    mkConnection(vtt_ef_rail.pins, dut.pins.vtt_ef);
    mkConnection(vtt_gh_rail.pins, dut.pins.vtt_gh);
    mkConnection(vpp_abcd_rail.pins, dut.pins.vpp_abcd);
    mkConnection(vpp_efgh_rail.pins, dut.pins.vpp_efgh);
    mkConnection(v1p8_vdd_18_rail.pins, dut.pins.v1p8_sp3);
    mkConnection(vdd_mem_abcd_rail.pins, dut.pins.vdd_mem_abcd);
    mkConnection(vdd_mem_efgh_rail.pins, dut.pins.vdd_mem_efgh);
    mkConnection(v3p3_sys_rail.pins, dut.pins.v3p3_sys);
   
    Reg#(Bool) ignore_sp <- mkReg(False);
    Reg#(Bool) upstream_ok <- mkReg(True);
    Reg#(Bool) downstream_idle_ <- mkReg(True);
    Reg#(Bool) pmbus_enabled <- mkReg(False);
    mkConnection(dut.a1_ok, upstream_ok);
    mkConnection(downstream_idle_, dut.hp_idle);
    mkConnection(dut.reg_if.ignore_sp, ignore_sp);

    Reg#(Bit#(1)) pwr_cont1_sp3_pg0 <- mkReg(0);
    Reg#(Bit#(1)) pwr_cont2_sp3_pg0 <- mkReg(0);
    mkConnection(pwr_cont1_sp3_pg0, dut.pins.pwr_cont1_sp3_pg0);
    mkConnection(pwr_cont2_sp3_pg0, dut.pins.pwr_cont2_sp3_pg0);

    interface  vpp_abcd = vpp_abcd_rail;
    interface  vpp_efgh = vpp_efgh_rail;
    interface  v3p3_sys = v3p3_sys_rail;
    interface  v1p8_sp3 = v1p8_vdd_18_rail;
    interface  vdd_mem_abcd = vdd_mem_abcd_rail;
    interface  vdd_mem_efgh = vdd_mem_efgh_rail;
    interface  vtt_ab = vtt_ab_rail;
    interface  vtt_cd = vtt_cd_rail;
    interface  vtt_ef = vtt_ef_rail;
    interface  vtt_gh = vtt_gh_rail;

    method A0StateType dut_state();
        return dut.reg_if.state;
    endmethod
    method Action pmbus_on();
        pwr_cont1_sp3_pg0 <= 1;
        pwr_cont2_sp3_pg0 <= 1;
    endmethod
    method Action pmbus_off();
        pwr_cont1_sp3_pg0 <= 0;
        pwr_cont2_sp3_pg0 <= 0;
    endmethod
    method Action power_up();
        dut.reg_if.a0_en(True);
    endmethod
    method Action power_down();
        dut.reg_if.a0_en(False);
    endmethod
    method Action downstream_busy();
        downstream_idle_ <= False;
    endmethod
    method Action downstream_idle();
        downstream_idle_ <= True;
    endmethod
    method Action sp3_disable(Bool value);
        ignore_sp <= value;
        sp3.disabled(value);
    endmethod
endmodule

interface SP3Model;
    interface SP3 pins;
    method Action thermtrip(Bool value);
    method Action disabled(Bool value);
endinterface

typedef enum {
    OFF = 'h00,
    POWERING = 'h01,
    ON = 'h02
} SP3ModelStateType deriving (Eq, Bits);

module mkSP3Model(SP3Model);

    Integer startup_delay = 20;
    Reg#(UInt#(24)) ticks_count <- mkReg(0);
    RWire#(UInt#(24)) ticks_count_next <- mkRWire();
    Reg#(Bool) thermtrip_ <- mkReg(False);
    Reg#(Bool) disabled_ <- mkReg(False);

    // From SP3
    Reg#(Bit#(1)) sp3_to_seq_pwrgd_out <- mkReg(0);
    Reg#(Bit#(1)) sp3_to_seq_slp_s3_l <- mkReg(0);
    Reg#(Bit#(1)) sp3_to_seq_slp_s5_l <- mkReg(0);
    Reg#(Bit#(1)) sp3_to_seq_pwrok_v3p3 <- mkReg(0);
    Reg#(Bit#(1)) sp3_to_seq_reset_v3p3_l <- mkReg(0);
    Reg#(Bit#(1)) sp3_to_seq_thermtrip_l <- mkReg(1);
    // To SP3
    Wire#(Bit#(1)) seq_to_sp3_sys_rst_l <- mkDWire(1);
    Wire#(Bit#(1)) seq_to_sp3_pwr_btn_l <- mkDWire(1);
    Wire#(Bit#(1)) seq_to_sp3_pwr_good <- mkDWire(0);

    Reg#(Bit#(1)) last_pwr_btn_l <- mkReg(1);
    Reg#(Bit#(1)) last_pwr_good <- mkReg(0);
    Reg#(SP3ModelStateType) state <- mkReg(OFF);
    Reg#(Bool) abort <- mkReg(False);
    Reg#(Bool) run <- mkReg(False);


    //
    // Basic down counter -- pre-load
    //
    (* fire_when_enabled *)
    rule do_set_ticks_count (ticks_count_next.wget matches tagged Valid .value);
        ticks_count <= value;
    endrule

    //
    // Basic down counter -- counts
    //
    (* fire_when_enabled *)
    rule do_count_ticks (!isValid(ticks_count_next.wget));
        ticks_count <= satMinus(Sat_Zero, ticks_count, 1);
    endrule

     function Stmt delay(Integer d, SP3ModelStateType step) =
        seq
            action
                state <= step;
                ticks_count_next.wset(fromInteger(d + 1));
            endaction
            await(ticks_count == 0);
        endseq;


     // Very simplistic model here for now
    FSM sp3_power_up_seq <- mkFSMWithPred(seq
        // - Wait for rising edge pwr button + delay
        delay(startup_delay, POWERING);
        // - De-assert SLP signals
        action
            sp3_to_seq_slp_s5_l <= 1;
            sp3_to_seq_slp_s3_l <= 1;
        endaction
        await(seq_to_sp3_pwr_good == 1);
        // - Wait for Power Good
        delay(startup_delay, POWERING);
        // - Delay, assert Power Ok
        action
            sp3_to_seq_pwrok_v3p3 <= 1;
        endaction
        // - Delay, de-assert reset
        delay(startup_delay, POWERING);
        action
            sp3_to_seq_reset_v3p3_l <= 1;
            state <= ON;
        endaction
    endseq, !abort && run && !disabled_);

    FSM sp3_power_down_seq <- mkFSMWithPred(seq
        action
            sp3_to_seq_slp_s5_l <= 0;
            sp3_to_seq_slp_s3_l <= 0;
            sp3_to_seq_pwrok_v3p3 <= 0;
             sp3_to_seq_reset_v3p3_l <= 0;
            state <= OFF;
        endaction
    endseq, !abort && !run && !disabled_);

    rule do_pwr_btn ;
        last_pwr_btn_l <= seq_to_sp3_pwr_btn_l;
        last_pwr_good <= seq_to_sp3_pwr_good;
        if (last_pwr_btn_l == 0 && seq_to_sp3_pwr_btn_l == 1) begin
            run <= True;
            sp3_power_up_seq.start();
        end else if (last_pwr_good == 1 && seq_to_sp3_pwr_good == 0) begin
            run <= False;
            sp3_power_down_seq.start();
        end
    endrule

    interface SP3 pins;
        method sp3_to_seq_pwrgd_out = sp3_to_seq_pwrgd_out._read;
        method sp3_to_seq_slp_s3_l = sp3_to_seq_slp_s3_l._read;
        method sp3_to_seq_slp_s5_l = sp3_to_seq_slp_s5_l._read;
        method sp3_to_seq_pwrok_v3p3 = sp3_to_seq_pwrok_v3p3._read;
        method sp3_to_seq_reset_v3p3_l = sp3_to_seq_reset_v3p3_l._read;
        method sp3_to_seq_thermtrip_l = sp3_to_seq_thermtrip_l._read;
        // To SP3
        method seq_to_sp3_sys_rst_l = seq_to_sp3_sys_rst_l._write;
        method seq_to_sp3_pwr_btn_l = seq_to_sp3_pwr_btn_l._write;
        method seq_to_sp3_pwr_good = seq_to_sp3_pwr_good._write;
    endinterface
    method thermtrip = thermtrip_._write;
    method disabled = disabled_._write;
endmodule

(* synthesize *)
module mkA0PowerUpTest(Empty);
    Bench bench <- mkBench();
    
    mkAutoFSM(seq
        // TODO: check pre-conditions
        action
            $display("Power Up");
        endaction
        bench.power_up();
        action
            $display("Waiting groupC");
        endaction
        await(bench.dut_state == GROUPC_PG);
        bench.pmbus_on();
        action
            $display("Waiting Done");
        endaction
        await(bench.dut_state == DONE);
        delay(300);
    endseq);
endmodule

(* synthesize *)
module mkA0FakeSP3Test(Empty);
    Bench bench <- mkBench();
    
    mkAutoFSM(seq
        // TODO: check pre-conditions
        bench.sp3_disable(True);
        action
            $display("Power Up");
        endaction
        bench.power_up();
        action
            $display("Waiting groupC");
        endaction
        await(bench.dut_state == GROUPC_PG);
        bench.pmbus_on();
        action
            $display("Waiting Done");
        endaction
        await(bench.dut_state == DONE);
        delay(300);
    endseq);
endmodule

(* synthesize *)
module mkA0MAPOTest(Empty);
    Bench bench <- mkBench();
    
    mkAutoFSM(seq

        action
            $display("Power Up");
        endaction
        bench.power_up();
        action
            $display("Waiting groupC");
        endaction
        await(bench.dut_state == GROUPC_PG);
        bench.pmbus_on();
        action
            $display("Waiting Done");
        endaction
        await(bench.dut_state == DONE);
        delay(300);
        // Issue fault a power rail
        bench.v3p3_sys.force_disable(True);
        delay(100);
        await(bench.dut_state == IDLE);
        delay(300);
        // Un-fault power rail
        bench.v3p3_sys.force_disable(False);
        // Try to power up again without clearing enable (which clears faults).
        bench.power_up();
        delay(300);
        dynamicAssert(bench.dut_state == IDLE, "State was not IDLE");
        bench.power_down();
        delay(300);
        dynamicAssert(bench.dut_state == IDLE, "State was not IDLE");
        bench.power_up();
        delay(2000);
        await(bench.dut_state == GROUPC_PG);
        bench.pmbus_on();
        action
            $display("Waiting Done");
        endaction
        await(bench.dut_state == DONE);
    endseq);
endmodule

//
// Group B1 rails:
//  RevA: pwr_cont_dimm_abcd_en0 for VPP_ABCD_A0, FPGA pin R16
//        pwr_cont_dimm_efgh_en0 for VPP_EFGH_A0, FPGA pin J16
//        pwr_cont_dimm_abcd_en1 for V3P3_SYS_A0, FPGA pin L1 
//        seq_to_sp3_v1p8_en for V1P8_SP3_VDD_18_A0, FPGA pin R15
//  RevB: pwr_cont_dimm_en0 for VPP_ABCD_A0, FPGA pin R16
//        pwr_cont_dimm_en1 for VPP_EFGH_A0, FPGA pin R15
//        seq_to_sp3_v1p8_en for V1P8_SP3_VDD_18_A0, FPGA pin L1
//        seq_to_v3p3_sys_en for V3P3_SYS_A0, FPGA pin L12

//
// Group B2 rails:
//  RevA: pwr_cont1_sp3_en for VDD_MEM_ABCD_A0 (pg1)
//        pwr_cont2_sp3_en for VDD_MEM_EFGH_A0 (pg1)
//        seq_to_vtt_abcd_a0_en for VTT_ABCD_A0
//        seq_to_vtt_efgh_en for VTT_EFGH_A0
//  RevB: pwr_cont1_sp3_en for VDD_MEM_ABCD_A0
//        pwr_cont2_sp3_en for VDD_MEM_EFGH_A0
//        seq_to_vtt_abcd_en for VTT_ABCD_A0 but 2 power goods
//        seq_to_vtt_efgh_en for VTT_EFGH_A0 but 2 power goods

//
// Group C rails:
// Enabled by PMBUS
//  RevX: pwr_cont1_sp3_pg0 for SP3_VDD_VCORE_A0
//        pwr_cont2_sp3_pg0 for SP3_VDDCR_SoC
endpackage