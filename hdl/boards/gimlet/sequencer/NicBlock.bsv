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
        method NicsmstatusNicsm state();
        method NicStatus pgs;
        method NicOutput1Type nic_ens;
        method NicOutput2Type nic_outs;
        method Bool mapo();
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
        method Action state(NicsmstatusNicsm value);
        method Action pgs (NicStatus value);
        method Action nic_ens (NicOutput1Type value);
        method Action nic_outs (NicOutput2Type value);
        method Action mapo(Bool value);
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
            mkConnection(source.nic_ens, sink.nic_ens);
            mkConnection(source.mapo, sink.mapo);
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

    // typedef enum {
    //     IDLE = 'h00,
    //     STAGE0 = 'h01,
    //     STAGE0_PG = 'h02,
    //     DELAY = 'h03,
    //     DONE = 'h04

    // } NicStateType deriving (Eq, Bits);

    module mkNicBlockSeq#(Integer one_ms_counts)(NicBlockTop);
        Integer ten_ms = 10 * one_ms_counts;
        Integer thirty_ms = 30 * one_ms_counts;
        Integer cld_rst_to_perst_delay = ten_ms;
        Reg#(NicsmstatusNicsm) state <- mkReg(IDLE);
        Reg#(Bit#(1)) seq_to_nic_cld_rst_l <- mkReg(0);
        Reg#(Bit#(1)) seq_to_nic_perst_l <- mkReg(0);
        Reg#(Bit#(1)) nic_to_sp3_pwrflt_l <- mkReg(0);
        Reg#(Bit#(1)) seq_to_nic_comb_pg_l <- mkReg(1);
        Reg#(Bool) upstream_ok <- mkReg(False);
        Reg#(UInt#(24)) cld_rst_delay_cnts <- mkReg(0);
        Reg#(Bool) enable <- mkReg(False);
        Reg#(Bool) faulted <- mkReg(False);
        Reg#(Bool) abort <- mkReg(False);
        Reg#(Bool) perst_can_deassert <- mkReg(False);

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

        function Action enable_rails(Vector#(n, PowerRail) rails) =
        action
            for (int i = 0; i < fromInteger(valueof(n)); i=i+1)
                rails[i].set_enabled(True);
        endaction;

        function Action disable_rails(Vector#(n, PowerRail) rails) =
                action
                    for (int i = 0; i < fromInteger(valueof(n)); i=i+1)
                        rails[i].set_enabled(False);
                endaction;

        function Stmt delay(Integer d) =
            seq
                action
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

        (* fire_when_enabled, no_implicit_conditions *)
        rule do_sm;
            if (!faulted) begin
                case (state)
                    IDLE: begin
                        // We're enabled, and our upstream is ok, enable the rails
                        if (enable && upstream_ok) begin
                            state <= STAGE0;
                            enable_rails(power_rails);
                        end else begin
                            disable_rails(power_rails);
                        end
                    end
                    STAGE0: begin  // rails enabled, check for PG
                        if (!enable) begin
                            state <= IDLE;
                        end else if (aggregate_pg) begin
                            state <= DELAY;  // Need 30ms delay before asserting comb_pg
                            ticks_count_next.wset(fromInteger(thirty_ms + 1));
                        end
                    end
                    DELAY: begin
                        if (!enable) begin
                            state <= IDLE;
                        end else if (ticks_count == 0) begin
                            state <= DONE;
                        end
                    end
                    DONE: begin
                        if (!enable) begin
                            state <= IDLE;
                        end
                    end
                endcase
            end else if (faulted) begin
                disable_rails(power_rails);
                state <= IDLE;
            end
        endrule

         (* fire_when_enabled *)
        rule do_pg_aggregation;
            aggregate_pg <= foldr(bool_and, True, map(PowerRail::good, power_rails));
        endrule

        (* fire_when_enabled *)
        rule do_fault_aggregation;
            aggregate_fault <= foldr(bool_or, False, map(PowerRail::fault, power_rails));
        endrule

        (* fire_when_enabled *)
        rule do_cld_rst_to_perst_delay;
            if (state != DONE || sw_reset) begin
                cld_rst_delay_cnts <= 0;
            end else if (state == DONE &&
                         !sw_reset && 
                         cld_rst_delay_cnts < fromInteger(cld_rst_to_perst_delay)) begin
                // Count when we're Done sequencing, have released cld_rst
                // we're power enabled from hubris
                // and we havent hit the max count
                cld_rst_delay_cnts <= cld_rst_delay_cnts + 1;
            end
            if (cld_rst_delay_cnts < fromInteger(cld_rst_to_perst_delay)) begin
               perst_can_deassert <= False;
            end else begin
                perst_can_deassert <= True;
            end
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
                seq_to_nic_perst_l <= pack(state == DONE && sp3_to_seq_nic_perst_l == 1 && perst_can_deassert && !perst_override && !sw_reset);
            end
            nic_to_sp3_pwrflt_l <= 1;
            seq_to_nic_comb_pg_l <= pack(state != DELAY && state != DONE);
        endrule

        (* fire_when_enabled *)
        rule do_mapo_fault;
            if (aggregate_fault) begin
                faulted <= aggregate_fault;
            end else if (!enable) begin
                faulted <= False;
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
            method NicOutput1Type nic_ens;
                return NicOutput1Type {
                    nic_v0p9_a0_en: pack(v0p9_a0hp.enabled),
                    nic_v1p2_eth_en: pack(v1p2.enabled),
                    nic_v1p5a_en: pack(v1p5a.enabled),
                    nic_v1p5d_en: pack(v1p5d.enabled),
                    nic_v1p2_en: pack(v1p2.enabled),
                    nic_v1p1_en: pack(v1p1.enabled),
                    nic_v3p3_en: pack(ldo_v3p3.enabled)
                };
            endmethod
            method NicOutput2Type nic_outs;
                return NicOutput2Type {
                   sp3_perst: ~sp3_to_seq_nic_perst_l,
                   nic_perst: ~seq_to_nic_perst_l,
                   pwrflt: ~nic_to_sp3_pwrflt_l,
                   nic_cld_rst: ~seq_to_nic_cld_rst_l,
                   nic_comb_pg: ~seq_to_nic_comb_pg_l,
                   nic_ext_rst: ~nic_to_seq_ext_rst_l
                };
            endmethod
            method mapo = faulted._read;
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
        method NicsmstatusNicsm state();
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
        method NicsmstatusNicsm state();
            return dut.reg_if.state;
        endmethod
        method seq_to_nic_cld_rst_l = dut.pins.seq_to_nic_cld_rst_l;
        method seq_to_nic_perst_l = dut.pins.seq_to_nic_perst_l;
        method nic_to_sp3_pwrflt_l = dut.pins.nic_to_sp3_pwrflt_l;
        method seq_to_nic_comb_pg_l = dut.pins.seq_to_nic_comb_pg_l;

    endmodule

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
            delay(200);
            dynamicAssert(bench.seq_to_nic_perst_l == 1, "Expected perst now deasserted");
            delay(200);
        endseq);
    endmodule

endpackage
