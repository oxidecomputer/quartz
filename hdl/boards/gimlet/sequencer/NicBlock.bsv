package NicBlock;

import Assert::*;
import BuildVector::*;
import Connectable::*;
import ConfigReg::*;
import StmtFSM::*;
import Vector::*;

// cobalt imports
import TestUtils::*;

// Local imports
import GimletSeqFpgaRegs::*;
import PowerRail::*;

    interface NicRegs;
        // method Action dbg_ctrl(A1DbgOut value); // Output control
        // method Action dbg_en(Bool value);    // Debug enable pin
        method Action en(Bool value);  // SM enable pin
        method Action sw_reset(Bool value);
        method Action cld_rst_override(Bool value);
        method Action perst_override(Bool value);
        method Action perst_solo(Bool value);
        method Bool ok();
        method NicStateType state();
        method NicStatus pgs;
        method OutStatusNic2 nic_outs;
        // method A1OutStatus output_readbacks();
        // method A1Readbacks input_readbacks();
    endinterface

    interface NicRegsReverse;
        method Bool en;
        method Bool sw_reset;
        method Bool cld_rst_override;
        method Bool perst_override;
        method Bool perst_solo;
        method Action ok(Bool value);
        method Action state(NicStateType value);
        method Action pgs (NicStatus value);
        method Action nic_outs (OutStatusNic2 value);
    endinterface

    // Allow our output pin source to connect to our output pin sink
    instance Connectable#(NicRegs, NicRegsReverse);
        module mkConnection#(NicRegs source, NicRegsReverse sink) (Empty);
            mkConnection(source.en, sink.en);
            mkConnection(source.sw_reset, sink.sw_reset);
            mkConnection(source.cld_rst_override, sink.cld_rst_override);
            mkConnection(source.perst_override, sink.perst_override);
            mkConnection(source.perst_solo, sink.perst_solo);
            mkConnection(source.ok, sink.ok);
            mkConnection(source.state, sink.state);
            mkConnection(source.pgs, sink.pgs);
            mkConnection(source.nic_outs, sink.nic_outs);
            // mkConnection(source.output_readbacks, sink.output_readbacks);
            // mkConnection(source.input_readbacks, sink.input_readbacks);
        endmodule
    endinstance

    // Nic block interfaces
    interface NicPins;
        interface PowerRail::Pins ldo_v3p3;
        interface PowerRail::Pins v1p5a;
        interface PowerRail::Pins v1p5d;
        interface PowerRail::Pins v1p2_enet;
        interface PowerRail::Pins v1p2;
        interface PowerRail::Pins v1p1;
        interface PowerRail::Pins v0p9_a0hp;
        method Action nic_to_seq_ext_rst_l(Bit#(1) value);
        method Action sp3_to_seq_nic_perst_l(Bit#(1) value);
        method Bit#(1) seq_to_nic_cld_rst_l;
        method Bit#(1) seq_to_nic_perst_l;
        method Bit#(1) nic_to_sp3_pwrflt_l;
        method Bit#(1) seq_to_nic_comb_pg_l;
    endinterface

    interface NicBlockTop;
        interface NicPins pins;
        method Bool nic_idle;
        method Action a0_ok(Bool value);
        interface NicRegs reg_if;
    endinterface

    typedef enum {
        IDLE = 'h00,
        DELAY0 = 'h01,
        STAGE0 = 'h02,
        STAGE0_PG = 'h03,
        DELAY = 'h04,
        DONE = 'h05
   
    } NicStateType deriving (Eq, Bits);

    module mkNicBlockSeq#(Integer one_ms_counts)(NicBlockTop);
        Integer ten_ms = 10 * one_ms_counts;
        Integer thirty_ms = 30 * one_ms_counts;
        Reg#(NicStateType) state <- mkReg(IDLE);
        Reg#(Bit#(1)) seq_to_nic_cld_rst_l <- mkReg(0);
        Reg#(Bit#(1)) seq_to_nic_perst_l <- mkReg(0);
        Reg#(Bit#(1)) nic_to_sp3_pwrflt_l <- mkReg(0);
        Reg#(Bit#(1)) seq_to_nic_comb_pg_l <- mkReg(1);
        Reg#(Bool) upstream_ok <- mkReg(False);

        Reg#(Bool) enable <- mkReg(False);
        Reg#(Bool) faulted <- mkReg(False);
        Reg#(Bool) abort <- mkReg(False);

        Wire#(Bool) aggregate_pg <- mkDWire(False);
        Wire#(Bool) aggregate_fault <- mkDWire(False);
        Wire#(Bit#(1)) sp3_to_seq_nic_perst_l <- mkDWire(0);
        Wire#(Bit#(1)) nic_to_seq_ext_rst_l <- mkDWire(0);
        Wire#(Bool) cld_rst_override <- mkDWire(False);
        Wire#(Bool) perst_override <- mkDWire(False);
        Wire#(Bool) perst_solo <- mkDWire(False);
        Wire#(Bool) sw_reset <- mkDWire(False);

        Reg#(UInt#(24)) ticks_count <- mkReg(0);
        RWire#(UInt#(24)) ticks_count_next <- mkRWire();

        ConfigReg#(NicStatus) nic_pg <- mkConfigRegU();

        PowerRail ldo_v3p3 <- mkPowerRail(ten_ms, False);
        PowerRail v1p5a <- mkPowerRail(ten_ms, False);
        PowerRail v1p5d <- mkPowerRail(ten_ms, False);
        PowerRail v1p2_enet <- mkPowerRail(ten_ms, False);
        PowerRail v1p2 <- mkPowerRail(ten_ms, False);
        PowerRail v1p1 <- mkPowerRail(ten_ms, False);
        PowerRail v0p9_a0hp <- mkPowerRail(ten_ms, False);

        Vector#(7, PowerRail) power_rails = 
            vec(ldo_v3p3, v1p5a, v1p5d, v1p2_enet, v1p2, v1p1, v0p9_a0hp);
        
        function Action enable_rails(Vector#(n, PowerRail) rails, NicStateType step) =
        action
            state <= step;
            for (int i = 0; i < fromInteger(valueof(n)); i=i+1)
                rails[i].set_enabled(True);
        endaction;
    
        function Action disable_rails(Vector#(n, PowerRail) rails, NicStateType step) =
                action
                    state <= step;
                    for (int i = 0; i < fromInteger(valueof(n)); i=i+1)
                        rails[i].set_enabled(False);
                endaction;

        function Stmt delay(Integer d, NicStateType step) =
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

        FSM nic_power_up_seq <- mkFSMWithPred(seq
            // Enable all the rails
            await(upstream_ok);
            enable_rails(power_rails, STAGE0);
            action
                state <= STAGE0_PG;
            endaction
            await(aggregate_pg);

            delay(thirty_ms, DELAY);
            action
                state <= DONE;
            endaction
        endseq, enable && !faulted && !abort);

        FSM nic_power_dwn_seq <- mkFSMWithPred(seq
            disable_rails(power_rails, IDLE);
        endseq, !enable || faulted || abort);

         (* fire_when_enabled *)
        rule do_pg_aggregation;
            aggregate_pg <= foldr(bool_and, True, map(PowerRail::good, power_rails));
        endrule

        (* fire_when_enabled *)
        rule do_fault_aggregation;
            aggregate_fault <= foldr(bool_or, False, map(PowerRail::fault, power_rails));
        endrule

        (* fire_when_enabled *)
        rule do_outputs;
            seq_to_nic_cld_rst_l <= pack(state == DONE && !cld_rst_override && !sw_reset);
            // If we're 'soloing' the PERST we want to ignore the SP3 completely and just use the register
            // and statemachine. Otherwise we allow setting it via the register assuming SP3 is out of the
            // picture
            if (perst_solo) begin
                seq_to_nic_perst_l <= pack(state == DONE && !perst_override);
            end else begin
                seq_to_nic_perst_l <= pack(state == DONE && sp3_to_seq_nic_perst_l == 1 && !perst_override);
            end
            nic_to_sp3_pwrflt_l <= 1;
            seq_to_nic_comb_pg_l <= pack(state != DELAY && state != DONE);
        endrule

        (* fire_when_enabled *)
        rule do_enable;
            // enable_last <= enable;
            if (faulted) begin
                // We do a standard power-down in the fault case
                // regardless of the rest of the system state.
                nic_power_dwn_seq.start();
            end else if (enable && state == IDLE) begin
                // We only want to start this on a rising edge of
                // the enable, meaning to re-start you need to
                // clear the enable.
                nic_power_up_seq.start();
            end else if (!enable && state != IDLE) begin
                // Even if we clear the enable, we can't start the 
                // power-down until the down-stream logic has finished
                // powering off.
                nic_power_dwn_seq.start();
            end
        endrule

        interface NicPins pins;
            interface PowerRail::Pins ldo_v3p3 = ldo_v3p3.pins;
            interface PowerRail::Pins v1p5a = v1p5a.pins;
            interface PowerRail::Pins v1p5d = v1p5d.pins;
            interface PowerRail::Pins v1p2_enet = v1p2_enet.pins;
            interface PowerRail::Pins v1p2 = v1p2.pins;
            interface PowerRail::Pins v1p1 = v1p1.pins;
            interface PowerRail::Pins v0p9_a0hp = v0p9_a0hp.pins;
            method nic_to_seq_ext_rst_l = nic_to_seq_ext_rst_l._write;
            method sp3_to_seq_nic_perst_l = sp3_to_seq_nic_perst_l._write;
            method seq_to_nic_cld_rst_l = seq_to_nic_cld_rst_l._read;
            method seq_to_nic_perst_l = seq_to_nic_perst_l._read;
            method nic_to_sp3_pwrflt_l = nic_to_sp3_pwrflt_l._read;
            method seq_to_nic_comb_pg_l = seq_to_nic_comb_pg_l._read;
        endinterface
        method Bool nic_idle;
            return state == IDLE;
        endmethod
        method a0_ok = upstream_ok._write;
        interface NicRegs reg_if;
            method en = enable._write;
            method sw_reset = sw_reset._write;
            method state = state._read;
            method NicStatus pgs;
                return NicStatus {
                    nic_3v3_pg: pack(ldo_v3p3.good),
                    nic_v1p5d_pg: pack(v1p5d.good),
                    nic_v1p5a_pg: pack(v1p5a.good),
                    nic_v1p2_enet_pg: pack(v1p2_enet.good),
                    nic_v1p1_pg: pack(v1p1.good),
                    nic_v1p2_pg: pack(v1p2.good),
                    nic_v0p96_pg: pack(v0p9_a0hp.good)
                };
            endmethod
            method Bool ok;
                return state == DONE;
            endmethod
            method cld_rst_override = cld_rst_override._write;
            method perst_override = perst_override._write;
            method perst_solo = perst_solo._write;
            method OutStatusNic2 nic_outs;
                return OutStatusNic2 {
                   sp3_perst: ~sp3_to_seq_nic_perst_l,
                   nic_perst: ~seq_to_nic_perst_l,
                   pwrflt: ~nic_to_sp3_pwrflt_l,
                   nic_cld_rst: ~seq_to_nic_cld_rst_l,
                   nic_comb_pg: ~seq_to_nic_comb_pg_l,
                   nic_ext_rst: ~nic_to_seq_ext_rst_l
                };
            endmethod
        endinterface

    endmodule
    


     interface Bench;
        interface PowerRailModel ldo_v3p3;
        interface PowerRailModel v1p5a;
        interface PowerRailModel v1p5d;
        interface PowerRailModel v1p2_enet;
        interface PowerRailModel v1p2;
        interface PowerRailModel v1p1;
        interface PowerRailModel v0p9_a0hp;

        method Bool nic_ok();
        method Action power_up();
        method Action power_down();
        method Action sp3_assert_perst();
        method Action sp3_deassert_perst();
        method Action a0_ok(Bool value);
        method NicStateType state();
        method Bit#(1) seq_to_nic_cld_rst_l();
        method Bit#(1) seq_to_nic_perst_l();
        method Bit#(1) nic_to_sp3_pwrflt_l();
        method Bit#(1) seq_to_nic_comb_pg_l();

    endinterface

    module mkBench(Bench);
        PowerRailModel ldo_v3p3_rail <- mkPowerRailModel("ldo_v3p3");
        PowerRailModel v1p5a_rail <- mkPowerRailModel("v1p5a");
        PowerRailModel v1p5d_rail <- mkPowerRailModel("v1p5d");
        PowerRailModel v1p2_enet_rail <- mkPowerRailModel("v1p2_enet");
        PowerRailModel v1p2_rail <- mkPowerRailModel("v1p2");
        PowerRailModel v1p1_rail <- mkPowerRailModel("v1p1");
        PowerRailModel v0p9_a0hp_rail <- mkPowerRailModel("v0p9_a0hp");

        NicBlockTop dut <- mkNicBlockSeq(10);

        Reg#(Bool) upstream_ok <- mkReg(True);

        Reg#(Bit#(1)) nic_to_seq_ext_rst_l <- mkReg(1);
        Reg#(Bit#(1)) sp3_to_seq_nic_perst_l <- mkReg(0);

        mkConnection(upstream_ok, dut.a0_ok);
        mkConnection(nic_to_seq_ext_rst_l, dut.pins.nic_to_seq_ext_rst_l);
        mkConnection(sp3_to_seq_nic_perst_l, dut.pins.sp3_to_seq_nic_perst_l);

        mkConnection(ldo_v3p3_rail.pins, dut.pins.ldo_v3p3);
        mkConnection(v1p5a_rail.pins, dut.pins.v1p5a);
        mkConnection(v1p5d_rail.pins, dut.pins.v1p5d);
        mkConnection(v1p2_enet_rail.pins, dut.pins.v1p2_enet);
        mkConnection(v1p2_rail.pins, dut.pins.v1p2);
        mkConnection(v1p1_rail.pins, dut.pins.v1p1);
        mkConnection(v0p9_a0hp_rail.pins, dut.pins.v0p9_a0hp);

        interface PowerRailModel ldo_v3p3 = ldo_v3p3_rail;
        interface PowerRailModel v1p5a = v1p5a_rail;
        interface PowerRailModel v1p5d = v1p5d_rail;
        interface PowerRailModel v1p2_enet = v1p2_enet_rail;
        interface PowerRailModel v1p2 = v1p2_rail;
        interface PowerRailModel v1p1 = v1p1_rail;
        interface PowerRailModel v0p9_a0hp = v0p9_a0hp_rail;

        method Bool nic_ok();
            return dut.reg_if.state == DONE;
        endmethod
        method Action power_up();
            dut.reg_if.en(True);
        endmethod
        method Action power_down();
            dut.reg_if.en(True);
        endmethod
        method Action sp3_assert_perst();
            sp3_to_seq_nic_perst_l <= 0;
        endmethod
        method Action sp3_deassert_perst();
            sp3_to_seq_nic_perst_l <= 1;
        endmethod
        method Action a0_ok(Bool value);
            upstream_ok <= value;
        endmethod
        method NicStateType state();
            return dut.reg_if.state;
        endmethod
        method seq_to_nic_cld_rst_l = dut.pins.seq_to_nic_cld_rst_l;
        method seq_to_nic_perst_l = dut.pins.seq_to_nic_perst_l;
        method nic_to_sp3_pwrflt_l = dut.pins.nic_to_sp3_pwrflt_l;
        method seq_to_nic_comb_pg_l = dut.pins.seq_to_nic_comb_pg_l;

    endmodule

     (* synthesize *)
    module mkPowerUpNicTest(Empty);
         Bench bench <- mkBench();

        mkAutoFSM(seq
            // Check pre-power conditions
            dynamicAssert(!bench.nic_ok, "Expected Nic off");
            dynamicAssert(bench.seq_to_nic_cld_rst_l == 0, "Expected cld rst asserted");
            dynamicAssert(bench.seq_to_nic_perst_l == 0, "Expected perst asserted");
            dynamicAssert(bench.seq_to_nic_comb_pg_l == 1, "Expected comb-pg de-asserted");
            // Since power is off, SP3 perst de-assert should have no nic impact.
            bench.sp3_deassert_perst();
            delay(5);
            dynamicAssert(bench.seq_to_nic_perst_l == 0, "Expected perst still asserted");
            // now try to power up.
            bench.sp3_assert_perst();
            bench.power_up();
            await(bench.state == DONE);
            // check one representative rail
            dynamicAssert(bench.v0p9_a0hp.enabled, "Expected v0p9 enabled");
            dynamicAssert(bench.seq_to_nic_cld_rst_l == 1, "Expected cld rst deasserted");
            dynamicAssert(bench.seq_to_nic_perst_l == 0, "Expected perst asserted due to SP3");
            dynamicAssert(bench.nic_ok, "Expected Nic on");
            bench.sp3_deassert_perst();
            delay(5);
            dynamicAssert(bench.seq_to_nic_perst_l == 1, "Expected perst now deasserted");
            delay(200);
        endseq);
    endmodule


endpackage