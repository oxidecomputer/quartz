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
        method Bool ok;
        method A0smstatusA0sm state;
        method A0Output1Type status1;
        method A0Output2Type status2;
        method AmdA0 amd_a0;
        method AmdStatus amd_status;
        method GroupbPg b_pgs;
        method GroupcPg c_pgs;
        method GroupbcFlts bc_flts;
        method A0smstatusA0sm max_state;
        method A0smstatusA0sm flt_state;
        method GroupbPg flt_b_pgs;
        method GroupcPg flt_c_pgs;
        method GroupbPg max_b_pgs;
        method GroupcPg max_c_pgs;
        method Bool mapo;
        method Bool thermtrip;
        method Bool amd_reset_fedge;
        method Bool amd_pwrok_fedge;
        // method A0OutStatus output_readbacks();
        // method A0Readbacks input_readbacks();
    endinterface

    interface A0RegsReverse;
        // method Action dbg_ctrl(A1DbgOut value); // Output control
        // method Action dbg_en(Bool value);    // Debug enable pin
        method Bool a0_en();  // SM enable pin
        method Bool ignore_sp();
        method Action ok(Bool value);
        method Action state (A0smstatusA0sm value);
        method Action status1 (A0Output1Type value);
        method Action status2 (A0Output2Type value);
        method Action amd_status (AmdStatus value);
        method Action amd_a0 (AmdA0 value);
        method Action b_pgs (GroupbPg value);
        method Action c_pgs (GroupcPg value);
        method Action bc_flts (GroupbcFlts value);
        method Action max_state (A0smstatusA0sm value);
        method Action flt_state (A0smstatusA0sm value);
        method Action flt_b_pgs (GroupbPg value);
        method Action flt_c_pgs (GroupcPg value);
        method Action max_b_pgs (GroupbPg value);
        method Action max_c_pgs (GroupcPg value);
        method Action mapo(Bool value);
        method Action thermtrip(Bool value);
        method Action amd_reset_fedge(Bool value);
        method Action amd_pwrok_fedge(Bool value);
        // method Action output_readbacks (A0OutStatus value);
        // method Action input_readbacks (A0Readbacks value);
    endinterface

    // Allow our output pin source to connect to our output pin sink
    instance Connectable#(A0Regs, A0RegsReverse);
        module mkConnection#(A0Regs source, A0RegsReverse sink) (Empty);
            mkConnection(source.a0_en, sink.a0_en);
            mkConnection(source.ignore_sp, sink.ignore_sp);
            mkConnection(source.ok, sink.ok);
            mkConnection(source.state, sink.state);
            mkConnection(source.status1, sink.status1);
            mkConnection(source.status2, sink.status2);
            mkConnection(source.amd_status, sink.amd_status);
            mkConnection(source.amd_a0, sink.amd_a0);
            mkConnection(source.b_pgs, sink.b_pgs);
            mkConnection(source.c_pgs, sink.c_pgs);
            mkConnection(source.max_state, sink.max_state);
            mkConnection(source.flt_state, sink.flt_state);
            mkConnection(source.flt_b_pgs, sink.flt_b_pgs);
            mkConnection(source.flt_c_pgs, sink.flt_c_pgs);
            mkConnection(source.max_b_pgs, sink.max_b_pgs);
            mkConnection(source.max_c_pgs, sink.max_c_pgs);
            mkConnection(source.bc_flts, sink.bc_flts);
            mkConnection(source.mapo, sink.mapo);
            mkConnection(source.thermtrip, sink.thermtrip);
            mkConnection(source.amd_reset_fedge, sink.amd_reset_fedge);
            mkConnection(source.amd_pwrok_fedge, sink.amd_pwrok_fedge);
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
        method Action sp3_to_seq_fsr_req_l(Bit#(1) value);
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
        method Bit#(1) sp3_to_seq_fsr_req_l();
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
            mkConnection(source.sp3_to_seq_fsr_req_l, sink.sp3_to_seq_fsr_req_l);
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

        method Action pwr_cont1_sp3_cfp(Bit#(1) value);
        method Action pwr_cont1_sp3_nvrhot(Bit#(1) value);
        method Action pwr_cont2_sp3_cfp(Bit#(1) value);
        method Action pwr_cont2_sp3_nvrhot(Bit#(1) value);
        method Action pwr_cont1_sp3_pg0(Bit#(1) value);
        method Action pwr_cont2_sp3_pg0(Bit#(1) value);

        method Bit#(1) pwr_cont1_sp3_pwrok;
        method Bit#(1) pwr_cont2_sp3_pwrok;
    endinterface

    interface A0BlockTop;
        interface A0Pins pins;
        method Action hp_idle(Bool value);
        method Action a1_ok(Bool value);
        method Bool a0_idle;
        method Bool a0_ok;
        interface A0Regs reg_if;
    endinterface


module mkA0BlockSeq#(Integer one_ms_counts)(A0BlockTop);
    Integer two_ms = 2 * one_ms_counts;
    Integer five_ms = 5 * one_ms_counts;
    Integer ten_ms = 10 * one_ms_counts;
    Integer pbtn_low_ms = 20 * one_ms_counts;
    Integer onehundred_ms = 100 * one_ms_counts;
    Integer startup_delay = ten_ms;
    
    Reg#(A0smstatusA0sm) state <- mkReg(IDLE);
    Reg#(A0smstatusA0sm) max_state <- mkReg(IDLE);
    Reg#(A0smstatusA0sm) flt_state <- mkReg(IDLE);

    Reg#(UInt#(24)) ticks_count <- mkReg(0);
    RWire#(UInt#(24)) ticks_count_next <- mkRWire();
    Reg#(Bool)    ok <- mkReg(False);
    Reg#(Bool) abort <- mkDReg(False);
    Reg#(Bool) faulted <- mkReg(False);
    Reg#(Bool) thermal_trip <- mkReg(False);
    Reg#(Bool) mapo <- mkReg(False);
    Reg#(Bool) enable_last <- mkReg(False);
    Reg#(Bool) enable <- mkReg(False);
    Reg#(Bool) ignore_sp <- mkReg(False);
    Reg#(Bool) downstream_idle <- mkReg(True);
    Reg#(Bool) upstream_ok <- mkDReg(False);
    Reg#(Bool) regulator_pwrok <- mkReg(False);
    
    Wire#(Bool) b1_pg <- mkDWire(False);
    Wire#(Bool) b2_pg <- mkDWire(False);
    Wire#(Bool) c_pg <- mkDWire(False);

    Wire#(Bool) aggregate_pg <- mkDWire(False);
    Wire#(Bool) aggregate_fault <- mkDWire(False);

    ConfigReg#(A0Output1Type) status1 <- mkConfigRegU();
    ConfigReg#(A0Output2Type) status2 <- mkConfigRegU();
    ConfigReg#(AmdA0) amd_a0 <- mkConfigRegU();
    ConfigReg#(AmdStatus) amd_status <- mkConfigRegU();
    ConfigReg#(GroupbPg) b_pgs <- mkConfigRegU();
    ConfigReg#(GroupcPg) c_pgs <- mkConfigRegU();
    ConfigReg#(GroupbPg) flt_b_pgs <- mkConfigReg(unpack(0));
    ConfigReg#(GroupcPg) flt_c_pgs <- mkConfigReg(unpack(0));
    ConfigReg#(GroupbPg) max_b_pgs <- mkConfigReg(unpack(0));
    ConfigReg#(GroupcPg) max_c_pgs <- mkConfigReg(unpack(0));
    ConfigReg#(GroupbcFlts) bc_flts <- mkConfigRegU();

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
    Wire#(Bit#(1)) pwr_cont1_sp3_cfp <- mkDWire(0);
    Wire#(Bit#(1)) pwr_cont1_sp3_nvrhot <- mkDWire(1);
    Wire#(Bit#(1)) pwr_cont2_sp3_cfp <- mkDWire(0);
    Reg#(Bit#(1)) pwr_cont2_sp3_nvrhot <- mkDWire(1);
    Wire#(Bit#(1)) sp3_to_seq_thermtrip_l <- mkDWire(1);
    Wire#(Bit#(1)) sp3_to_seq_fsr_req_l <- mkDWire(1);

    // Edge registers
    Reg#(Bit#(1)) sp3_to_seq_pwrok_last <- mkReg(0);
    Reg#(Bit#(1)) sp3_to_seq_reset_l_last <- mkReg(0);
    PulseWire amd_pwrok_fedge <- mkPulseWire();
    PulseWire amd_reset_fedge <- mkPulseWire();

    // Output registers
    Reg#(Bit#(1)) seq_to_sp3_sys_rst_l <- mkReg(1);  // In practice we don't use this
    Reg#(Bit#(1)) seq_to_sp3_pwr_btn_l <- mkReg(1);
    Reg#(Bit#(1)) seq_to_sp3_pwr_good <- mkReg(0);

    Vector#(4, PowerRail) b1_rails =
        vec(vpp_abcd, vpp_efgh, v3p3_sys, v1p8_vdd_18);
    
    Vector#(6, PowerRail) b2_rails =
        vec(vdd_mem_abcd, vdd_mem_efgh, vtt_ab, vtt_cd,
            vtt_ef, vtt_gh);

    function Action enable_rails(Vector#(n, PowerRail) rails, A0smstatusA0sm step) =
        action
            state <= step;
            for (int i = 0; i < fromInteger(valueof(n)); i=i+1)
                rails[i].set_enabled(True);
        endaction;
    
    function Action disable_rails(Vector#(n, PowerRail) rails) =
            action
                for (int i = 0; i < fromInteger(valueof(n)); i=i+1)
                    rails[i].set_enabled(False);
            endaction;

    function Stmt delay(Integer d, A0smstatusA0sm step) =
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
        let mapo_fault = foldr(bool_or, False, map(PowerRail::fault, b1_rails)) ||
                         foldr(bool_or, False, map(PowerRail::fault, b2_rails)) ||
                         (!c_pg && pack(state) >=pack(A0smstatusA0sm'(DELAY_1MS)) && pack(state) <=pack(A0smstatusA0sm'(DONE)));  // Allow group C to drop in SAFE_DISABLE

        aggregate_fault <=  mapo_fault;
    endrule

    (* fire_when_enabled *)
    rule do_flt_debug_latch;
        // rising edge enable = clear
        if (!enable_last && enable) begin
            flt_state <= IDLE;
            flt_b_pgs <= unpack(0);
            flt_c_pgs <= unpack(0);
        end else if ((v3p3_sys.good && sp3_to_seq_thermtrip_l == 0) || aggregate_fault) begin
            // latch current SM
            flt_state <= state;
            // snap current PGs
            flt_b_pgs <= b_pgs;
            flt_c_pgs <= c_pgs;
        end
      
      
    endrule

    (* fire_when_enabled *)
    rule do_max_holds;
        // rising edge enable = clear
        if (!enable_last && enable) begin
            max_state <= IDLE;
            max_b_pgs <= unpack(0);
            max_c_pgs <= unpack(0);
        end else begin
            // max hold on state
            if (pack(state) > pack(max_state)) begin
                max_state <= state;
            end
            if (pack(b_pgs) > pack(max_b_pgs)) begin
                max_b_pgs <= b_pgs;
            end
            if (pack(c_pgs) > pack(max_c_pgs)) begin
                max_c_pgs <= c_pgs;
            end
        end
    endrule

    // Now writing this stupid state machine for the 3rd time
    // in yet a different format.
    // 1 rule per state => Long and annoying
    // mkFSMWithPred  (x3!) => Not flexible enough
    // Now 1 sm per rule => Still ugly but familiar.  This works becasue all the state is internal
    // and we don't have implicit conditions holding us off.
    (* fire_when_enabled, no_implicit_conditions *)
    rule do_sm;
        if (!faulted) begin
            case (state)
                IDLE: begin
                    if (enable&& upstream_ok) begin
                        state <= PBTN;
                        seq_to_sp3_pwr_btn_l <= 0;
                        ticks_count_next.wset(fromInteger(pbtn_low_ms + 1));
                    end else begin
                        disable_rails(b2_rails);
                        disable_rails(b1_rails);
                        seq_to_sp3_pwr_btn_l <= 1;
                        seq_to_sp3_pwr_good <= 0;
                        ticks_count_next.wset(fromInteger(0));
                    end
                end
                PBTN: begin  // PBTN is low here for pbtn_low_ms time
                    if (!enable) begin
                        state <= IDLE;
                    end else if (ticks_count == 0) begin
                        seq_to_sp3_pwr_btn_l <= 1;
                        state <= WAITSLP;
                    end
                end
                WAITSLP: begin  // Wait for slp_x_l signals to de-assert from SP3
                    if (!enable) begin
                        state <= IDLE;
                    end else if (ignore_sp || (sp3_to_seq_slp_s3_l == 1 && sp3_to_seq_slp_s5_l == 1)) begin
                        state <= GROUPB1_EN;
                    end
                end
                //
                // GroupB1 enable
                //
                GROUPB1_EN: begin
                    if (!enable) begin
                        state <= IDLE;
                    end else begin
                        enable_rails(b1_rails, GROUPB1_PG);
                    end
                end
                GROUPB1_PG: begin
                    if (!enable) begin
                        state <= IDLE;
                    end else if (b1_pg) begin
                        state <= GROUPB2_EN;
                    end
                end
                //
                // GroupB2 enable
                //
                GROUPB2_EN: begin
                    if (!enable) begin
                        state <= IDLE;
                    end else begin
                        enable_rails(b2_rails, GROUPB2_PG);
                    end
                end
                GROUPB2_PG: begin
                    if (!enable) begin
                        state <= IDLE;
                    end else if (b2_pg) begin
                        state <= GROUPC_PG;
                    end
                end
                GROUPC_PG: begin
                    if (!enable) begin
                        state <= IDLE;
                    end else if (c_pg) begin
                        ticks_count_next.wset(fromInteger(one_ms_counts + 1));
                        state <= DELAY_1MS;
                    end
                end
                // Delay 1 ms before asserting PowerGood to AMD
                DELAY_1MS: begin
                    if (!enable) begin
                        state <= IDLE;
                    end else if (ticks_count == 0) begin
                        state <= ASSERT_PG;
                        seq_to_sp3_pwr_good <= 1;
                    end
                end
                // Assert PowerGood to AMD
                ASSERT_PG: begin
                    if (!enable) begin
                        state <= IDLE;
                    end else begin
                        state <= WAIT_PWROK;
                    end
                end
                // Wait for AMD's power OK handshake
                WAIT_PWROK: begin
                    if (!enable) begin
                        state <= IDLE;
                    end else if (ignore_sp || (sp3_to_seq_pwrok_v3p3 == 1)) begin
                        state <= WAIT_RESET_L;
                    end
                end
                WAIT_RESET_L: begin
                    if (!enable) begin
                        state <= IDLE;
                    end else if (ignore_sp || (sp3_to_seq_reset_v3p3_l == 1)) begin
                        state <= DONE;
                    end
                end
                DONE: begin
                    if (!enable) begin
                        state <= SAFE_DISABLE;
                        seq_to_sp3_pwr_good <= 0;
                        ticks_count_next.wset(fromInteger(two_ms + 1));
                    end
                end
                SAFE_DISABLE: begin
                    if (ticks_count == 0 && downstream_idle) begin
                        disable_rails(b2_rails);
                        disable_rails(b1_rails);
                        seq_to_sp3_pwr_btn_l <= 1;
                        seq_to_sp3_pwr_good <= 0;
                        state <= IDLE;
                    end
                end
            endcase
        end else if (faulted) begin  // Faulted case
            disable_rails(b2_rails);
            disable_rails(b1_rails);
            seq_to_sp3_pwr_btn_l <= 1;
            seq_to_sp3_pwr_good <= 0;
            state <= IDLE;
            ticks_count_next.wset(fromInteger(0));
        end


    endrule

    (* fire_when_enabled *)
    rule prev_regs;
        sp3_to_seq_pwrok_last <= sp3_to_seq_pwrok_v3p3;
        sp3_to_seq_reset_l_last <= sp3_to_seq_reset_v3p3_l;
    endrule

    (* fire_when_enabled *)
    rule do_sp3_mon;
        if (sp3_to_seq_pwrok_last == 1 && sp3_to_seq_pwrok_v3p3 == 0 && state == DONE) begin
            amd_pwrok_fedge.send();
        end
        if (sp3_to_seq_reset_l_last == 1 && sp3_to_seq_reset_v3p3_l == 0 && state == DONE) begin
            amd_reset_fedge.send();
        end
    endrule

    (* fire_when_enabled *)
    rule do_enable;
        enable_last <= enable;
    endrule

    (* fire_when_enabled *)
    rule raa_power_ok;
        if (pack(state) >= pack(A0smstatusA0sm'(WAIT_PWROK))) begin
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
            thermal_trip <= True;
        // If an enabled rail faults, set the faulted flag
        end else if (aggregate_fault) begin
            faulted <= True;
            mapo <= True;
        // Faulted prevents us from re-starting unless the block has
        // been disabled, preventing failure loops without software
        // involvement.
        end else if (!enable) begin
            faulted <= False;
            thermal_trip <= False;
            mapo <= False;
        end
    endrule

    (* fire_when_enabled *)
    rule do_readbacks;
        status1 <= A0Output1Type {
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
        amd_a0 <= AmdA0 {
            reset : ~sp3_to_seq_reset_v3p3_l,
            pwrok : sp3_to_seq_pwrok_v3p3,
            slp_s5: ~sp3_to_seq_slp_s5_l,
            slp_s3: ~sp3_to_seq_slp_s3_l 
        };
        amd_status <= AmdStatus {
            pwrgd_out: sp3_to_seq_pwrgd_out,
            fsr_req: ~sp3_to_seq_fsr_req_l,
            thermtrip: ~sp3_to_seq_thermtrip_l
        };
        bc_flts <= GroupbcFlts {
            cont2_cfp: pwr_cont2_sp3_cfp,
            cont2_nvrhot: pwr_cont2_sp3_nvrhot,
            cont1_cfp: pwr_cont1_sp3_cfp,
            cont1_nvrhot: pwr_cont1_sp3_nvrhot
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
            method sp3_to_seq_fsr_req_l = sp3_to_seq_fsr_req_l._write;
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
        
        method pwr_cont1_sp3_cfp = pwr_cont1_sp3_cfp._write;
        method pwr_cont1_sp3_nvrhot = pwr_cont1_sp3_nvrhot._write;
        method pwr_cont2_sp3_cfp = pwr_cont2_sp3_cfp._write;
        method pwr_cont2_sp3_nvrhot = pwr_cont2_sp3_nvrhot._write;
        
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
        method Bool ok;
            return state == DONE;
        endmethod
        method state = state._read;
        method status1 = status1._read;
        method status2 = status2._read;
        method amd_status = amd_status._read;
        method amd_a0 = amd_a0._read;
        method b_pgs = b_pgs._read;
        method c_pgs = c_pgs._read;
        method bc_flts = bc_flts._read;
        method max_state = max_state._read;
        method flt_state = flt_state._read;
        method flt_b_pgs = flt_b_pgs._read;
        method flt_c_pgs = flt_c_pgs._read;
        method max_b_pgs = max_b_pgs._read;
        method max_c_pgs = max_c_pgs._read;
        method mapo = mapo._read;
        method thermtrip = thermal_trip._read;
        method amd_pwrok_fedge = amd_pwrok_fedge._read;
        method amd_reset_fedge = amd_reset_fedge._read;
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

    method A0smstatusA0sm dut_state();
    method Bool mapo();
    method Action sp3_disable(Bool value);
    method Action sp3_thermtrip();
    method Action pmbus_on();
    method Action pmbus_off();
    method Action power_up();
    method Action power_down();
    method Action downstream_busy();
    method Action downstream_idle();
    method Action make_upstream_ok();
    method Action make_upstream_not_ok();

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
    Reg#(Bool) pmbus_enabled <- mkReg(False);
    mkConnection(dut.a1_ok, upstream_ok);
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

    method A0smstatusA0sm dut_state();
        return dut.reg_if.state;
    endmethod
    method Bool mapo();
        return dut.reg_if.mapo();
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
    method Action make_upstream_ok();
        upstream_ok <= True;
    endmethod
    method Action make_upstream_not_ok();
        upstream_ok <= False;
    endmethod
    method Action downstream_busy();
        dut.hp_idle(False);
    endmethod
    method Action downstream_idle();
        dut.hp_idle(True);
    endmethod
    method Action sp3_disable(Bool value);
        ignore_sp <= value;
        sp3.disabled(value);
    endmethod
    method Action sp3_thermtrip();
        sp3.thermtrip(True);
    endmethod
endmodule

interface SP3Model;
    interface SP3 pins;
    method Action thermtrip(Bool value);
    method Action disabled(Bool value);
    method Action pwrok_override(Bool value);
    method Action rst_override(Bool value);
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
    Reg#(Bit#(1)) sp3_to_seq_fsr_req_l <- mkReg(1);
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

    rule do_thermtrip;
        sp3_to_seq_thermtrip_l <= pack(!thermtrip_);
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
            thermtrip_ <= False;
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
        method sp3_to_seq_fsr_req_l = sp3_to_seq_fsr_req_l._read;
        // To SP3
        method seq_to_sp3_sys_rst_l = seq_to_sp3_sys_rst_l._write;
        method seq_to_sp3_pwr_btn_l = seq_to_sp3_pwr_btn_l._write;
        method seq_to_sp3_pwr_good = seq_to_sp3_pwr_good._write;
    endinterface
    method thermtrip = thermtrip_._write;
    method disabled = disabled_._write;
    method Action pwrok_override (Bool value);
        if (value) begin
            sp3_to_seq_pwrok_v3p3 <= 1;
        end else begin
            sp3_to_seq_pwrok_v3p3 <= 0;
        end
    endmethod
    method Action rst_override (Bool value);
        if (value) begin
            sp3_to_seq_reset_v3p3_l <= 0;
        end else begin
            sp3_to_seq_reset_v3p3_l <= 1;
        end
    endmethod
endmodule

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

module mkA0PowerErrorsTest(Empty);
    Bench bench <- mkBench();
    
    mkAutoFSM(seq
        // Failed power up due to upstream not ok
        bench.make_upstream_not_ok();
        action
            $display("Don't Power Up, upstream unhappy");
        endaction
        bench.power_up();
        delay(300);
        dynamicAssert(bench.dut_state == IDLE, "State was not IDLE");

        // Normal power up
        bench.make_upstream_ok();
        action
            $display("Power Up, upstream happy");
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

        // Delayed power-down due to down-stream busy
        bench.downstream_busy();
        delay(10);
        bench.power_down();
        bench.pmbus_off();
        delay(2000);
        dynamicAssert(bench.dut_state == SAFE_DISABLE, "State was not SAFE_DISABLE");
        bench.downstream_idle();
        delay(10);
        dynamicAssert(bench.dut_state == IDLE, "State was not IDLE");
        delay(300);

        // Normal power up
        action
            $display("Power Up #2, upstream happy");
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
        

    endseq);
endmodule

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
        dynamicAssert(bench.mapo(), "Did not set MAPO");
        delay(300);
        // Un-fault power rail
        bench.v3p3_sys.force_disable(False);
        delay(10);
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

module mkA0DebugBrokenTest(Empty);
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
        // bench.pmbus_off();
        // delay(5);
        bench.power_down();
        action
            $display("Waiting IDLE");
        endaction
        // await(bench.dut_state == IDLE);
        delay(1200);
    endseq);
endmodule


module mkA0ThermtripTest(Empty);
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
        // Issue thermtrip
        bench.sp3_thermtrip();
        delay(100);
        await(bench.dut_state == IDLE);
        delay(300);
        // Try to power up again without clearing enable (which clears faults).
        bench.power_up();
        delay(300);
        dynamicAssert(bench.dut_state == IDLE, "State was not IDLE");
        // Now clear the faults so we can actually power up.
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