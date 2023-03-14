package A1Block;

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

    interface A1Regs;
        // method Action dbg_ctrl(A1DbgOut value); // Output control
        // method Action dbg_en(Bool value);    // Debug enable pin
        method Action a1_en(Bool value);  // SM enable pin
        method Bool ok();
        method A1smstatusA1sm state();
        method A1OutputType output_readbacks();
        method A1Readbacks input_readbacks();
        method Bool mapo();
    endinterface

    interface A1RegsReverse;
        // method Action dbg_ctrl(A1DbgOut value); // Output control
        // method Action dbg_en(Bool value);    // Debug enable pin
        method Bool a1_en();  // SM enable pin
        method Action ok(Bool value);
        method Action state (A1smstatusA1sm value);
        method Action output_readbacks (A1OutputType value);
        method Action input_readbacks (A1Readbacks value);
        method Action mapo(Bool value);
    endinterface

    // Allow our output pin source to connect to our output pin sink
    instance Connectable#(A1Regs, A1RegsReverse);
        module mkConnection#(A1Regs source, A1RegsReverse sink) (Empty);
            mkConnection(source.a1_en, sink.a1_en);
            mkConnection(source.ok, sink.ok);
            mkConnection(source.state, sink.state);
            mkConnection(source.output_readbacks, sink.output_readbacks);
            mkConnection(source.input_readbacks, sink.input_readbacks);
            mkConnection(source.mapo, sink.mapo);
        endmodule
    endinstance

    // A1 block interfaces
    interface A1Pins;
        interface PowerRail::Pins v3p3_s5;
        interface PowerRail::Pins v1p5_rtc;
        interface PowerRail::Pins v1p8_s5;
        interface PowerRail::Pins v0p9_s5;
        method Bit#(1) seq_to_sp3_rsmrst_v3p3_l;
    endinterface

    // Interface for Block top (syncd pins in, pins out, register if)
    interface A1BlockTop;
        interface A1Pins pins;
        method Action a0_idle(Bool value);
        method Bool a1_ok;
        interface A1Regs reg_if;
    endinterface

    module mkA1BlockSeq#(Integer one_ms_counts)(A1BlockTop);

        Integer ten_ms = 10 * one_ms_counts;
        Integer rsm_delay = 200 * one_ms_counts;

        ConfigReg#(A1smstatusA1sm) state <- mkConfigReg(A1smstatusA1sm'(IDLE));
        ConfigReg#(A1OutputType) output_readbacks <- mkConfigRegU();
        ConfigReg#(A1Readbacks) input_readbacks <- mkConfigRegU();


        Reg#(Bit#(1)) sp3_rsmrst_v3p3_l_ <- mkReg(0);
        Reg#(Bool)    ok <- mkReg(False);
        Reg#(Bool) abort <- mkDReg(False);
        Reg#(Bool) faulted <- mkReg(False);
        Reg#(Bool) enable_last <- mkReg(False);
        Reg#(Bool) enable <- mkReg(False);
        Reg#(UInt#(24)) ticks_count <- mkReg(0);
        RWire#(UInt#(24)) ticks_count_next <- mkRWire();

        Wire#(Bool) downstream_idle <- mkDWire(False);
        Wire#(Bool) aggregate_pg <- mkDWire(False);
        Wire#(Bool) aggregate_fault <- mkDWire(False);

        // Registers here

        PowerRail sp3_v3p3_s5 <- mkPowerRail(ten_ms, False);
        PowerRail sp3_v1p5_rtc <- mkPowerRail(ten_ms, False);
        PowerRail sp3_v0p9_s5 <- mkPowerRail(ten_ms, False);
        PowerRail sp3_v1p8_s5 <- mkPowerRail(ten_ms, False);

        // Add power rails to a vector for easy aggregation
        Vector#(4, PowerRail) power_rails =
            vec(sp3_v3p3_s5, sp3_v1p5_rtc, sp3_v0p9_s5, sp3_v1p8_s5);


        function Action enable_rails(Vector#(4, PowerRail) rails) =
            action
                for (int i = 0; i < 4; i=i+1)
                    rails[i].set_enabled(True);
            endaction;

        function Action disable_rails(Vector#(4, PowerRail) rails) =
            action
                for (int i = 0; i < 4; i=i+1)
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

        (* fire_when_enabled *)
        rule do_readbacks;
            output_readbacks <= A1OutputType {
                rsmrst: ~sp3_rsmrst_v3p3_l_,
                v0p9_s5_en: sp3_v0p9_s5.pins.en,
                v1p8_s5_en: sp3_v1p8_s5.pins.en,
                v1p5_rtc_en: sp3_v1p5_rtc.pins.en,
                v3p3_s5_en: sp3_v3p3_s5.pins.en
            };
            input_readbacks <= A1Readbacks {
                v0p9_vdd_soc_s5_pg: sp3_v0p9_s5.pg_readback,
                v1p8_s5_pg: sp3_v1p8_s5.pg_readback,
                v3p3_s5_pg: sp3_v3p3_s5.pg_readback,
                v1p5_rtc_pg: sp3_v1p5_rtc.pg_readback
            };
        endrule

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
        rule do_pg_aggregation;
            aggregate_pg <= foldr(bool_and, True, map(PowerRail::good, power_rails));
        endrule

        (* fire_when_enabled *)
        rule do_fault_aggregation;
            aggregate_fault <= foldr(bool_or, False, map(PowerRail::fault, power_rails));
        endrule

        (* fire_when_enabled, no_implicit_conditions *)
        rule do_sm;
            if (!faulted) begin
                case (state)
                    IDLE: begin
                        if (enable) begin
                            state <= WAITPG;
                            enable_rails(power_rails);
                            sp3_rsmrst_v3p3_l_ <= 0;
                        end else if (downstream_idle) begin
                            disable_rails(power_rails);
                            sp3_rsmrst_v3p3_l_ <= 0;
                        end
                    end
                    WAITPG: begin
                        if (!enable) begin
                           state <= IDLE;
                        end else if (aggregate_pg) begin
                            state <= DELAY;
                            ticks_count_next.wset(fromInteger(rsm_delay + 1));
                        end
                    end
                    DELAY: begin
                        if (!enable) begin
                            state <= IDLE;
                        end else if (ticks_count == 0) begin
                            state <= DONE;
                            sp3_rsmrst_v3p3_l_ <= 1;
                        end
                    end
                endcase
            end else if (faulted) begin
                disable_rails(power_rails);
                state <= IDLE;
                sp3_rsmrst_v3p3_l_ <= 0;
            end
        endrule

        (* fire_when_enabled *)
        rule do_fault_mon;
            if (aggregate_fault) begin
                faulted <= True;
            end else if (!enable) begin
                faulted <= False;
            end
        endrule

        interface A1Pins pins;
            interface PowerRail::Pins v3p3_s5 = sp3_v3p3_s5.pins;
            interface PowerRail::Pins v1p5_rtc = sp3_v1p5_rtc.pins;
            interface PowerRail::Pins v0p9_s5 = sp3_v0p9_s5.pins;
            interface PowerRail::Pins v1p8_s5 = sp3_v1p8_s5.pins;
            method seq_to_sp3_rsmrst_v3p3_l = sp3_rsmrst_v3p3_l_;
        endinterface

        method Bool a1_ok;
            return state == DONE;
        endmethod
        method a0_idle = downstream_idle._write;

        interface A1Regs reg_if;
            method Bool ok;
                return state == DONE;
            endmethod
            method a1_en = enable._write;
            method state = state._read;
            method mapo = faulted._read;
            method output_readbacks = output_readbacks._read;
            method input_readbacks = input_readbacks._read;
        endinterface
     endmodule


    interface Bench;
        interface PowerRailModel v3p3_s5;
        interface PowerRailModel v1p5_rtc;
        interface PowerRailModel v1p8_s5;
        interface PowerRailModel v0p9_s5;

        method Bool a1_ok();
        method Action power_up();
        method Action power_down();
        method Action a0_busy();
        method Action a0_idle();
        method Bit#(1) seq_to_sp3_rsmrst_v3p3_l();
        method A1smstatusA1sm state();

    endinterface

    module mkBench(Bench);

        PowerRailModel v3p3_s5_rail <- mkPowerRailModel("v3p3_s5");
        PowerRailModel v1p5_rtc_rail <- mkPowerRailModel("v1p5_rtc");
        PowerRailModel v1p8_s5_rail <- mkPowerRailModel("v1p8_s5");
        PowerRailModel v0p9_s5_rail <- mkPowerRailModel("v0p9_s5");

        A1BlockTop dut <- mkA1BlockSeq(10);

        Reg#(Bool) downstream_idle <- mkReg(True);

        mkConnection(v3p3_s5_rail.pins, dut.pins.v3p3_s5);
        mkConnection(v1p5_rtc_rail.pins, dut.pins.v1p5_rtc);
        mkConnection(v1p8_s5_rail.pins, dut.pins.v1p8_s5);
        mkConnection(v0p9_s5_rail.pins, dut.pins.v0p9_s5);
        mkConnection(downstream_idle, dut.a0_idle);

        interface PowerRailModel v3p3_s5 = v3p3_s5_rail;
        interface PowerRailModel v1p5_rtc = v1p5_rtc_rail;
        interface PowerRailModel v1p8_s5 = v1p8_s5_rail;
        interface PowerRailModel v0p9_s5 = v0p9_s5_rail;

        method Action power_up();
            dut.reg_if.a1_en(True);
        endmethod
        method Action power_down();
            dut.reg_if.a1_en(False);
        endmethod
        method Bool a1_ok();
            return dut.a1_ok;
        endmethod
        method Bit#(1) seq_to_sp3_rsmrst_v3p3_l();
            return dut.pins.seq_to_sp3_rsmrst_v3p3_l;
        endmethod
        method state = dut.reg_if.state;
        method Action a0_busy();
            downstream_idle <= False;
        endmethod
        method Action a0_idle();
            downstream_idle <= True;
        endmethod
    endmodule

    module mkA1PowerUpTest(Empty);

        Bench bench <- mkBench();

        mkAutoFSM(seq
            dynamicAssert(bench.a1_ok == False, "Expected sequencer in A2");
            dynamicAssert(bench.seq_to_sp3_rsmrst_v3p3_l == 0, "Expected RSMRST_L asserted");
            bench.power_up();
            delay(100);
            dynamicAssert(bench.v3p3_s5.enabled, "Expected v3p3_s5_en asserted");
            dynamicAssert(bench.seq_to_sp3_rsmrst_v3p3_l == 0, "Expected RSMRST_L asserted");
            await(bench.a1_ok);
            dynamicAssert(bench.seq_to_sp3_rsmrst_v3p3_l == 1, "Expected RSMRST_L de-asserted");
            delay(200);
        endseq);

    endmodule

    module mkA1PowerDownTest(Empty);

        Bench bench <- mkBench();

        mkAutoFSM(seq
            dynamicAssert(bench.a1_ok == False, "Expected sequencer in A2");
            dynamicAssert(bench.seq_to_sp3_rsmrst_v3p3_l == 0, "Expected RSMRST_L asserted");
            bench.power_up();
            await(bench.a1_ok);
            dynamicAssert(bench.seq_to_sp3_rsmrst_v3p3_l == 1, "Expected RSMRST_L de-asserted");
            bench.power_down();
            delay(5);
            dynamicAssert(bench.a1_ok == False, "Expected a1_ok to de-assert");
            dynamicAssert(bench.seq_to_sp3_rsmrst_v3p3_l == 0, "Expected RSMRST_L asserted");
            dynamicAssert(bench.v3p3_s5.enabled == False, "Expected v3p3_s5_en de-asserted");
            delay(200);
        endseq);

    endmodule

    module mkA1PowerDownA0InteractionTest(Empty);

        Bench bench <- mkBench();

        mkAutoFSM(seq
            dynamicAssert(bench.a1_ok == False, "Expected sequencer in A2");
            dynamicAssert(bench.seq_to_sp3_rsmrst_v3p3_l == 0, "Expected RSMRST_L asserted");
            bench.power_up();
            await(bench.a1_ok);
            bench.a0_busy();
            dynamicAssert(bench.seq_to_sp3_rsmrst_v3p3_l == 1, "Expected RSMRST_L de-asserted");
            bench.power_down(); // Should not actually happen because A0 is busy
            delay(200);
            dynamicAssert(bench.a1_ok == True, "Expected a1_ok to still be asserted since it can't power down");
            dynamicAssert(bench.seq_to_sp3_rsmrst_v3p3_l == 1, "Expected RSMRST_L still de-asserted");
            bench.a0_idle();
            delay(5);
            dynamicAssert(bench.a1_ok == False, "Expected a1_ok to be de-asserted we can now power down");
            dynamicAssert(bench.seq_to_sp3_rsmrst_v3p3_l == 0, "Expected RSMRST_L asserted");
            dynamicAssert(bench.v3p3_s5.enabled == False, "Expected v3p3_s5_en de-asserted");
            delay(200);
        endseq);

    endmodule

    module mkA1MAPOTest(Empty);

        Bench bench <- mkBench();

        mkAutoFSM(seq
            dynamicAssert(bench.a1_ok == False, "Expected sequencer in A2");
            dynamicAssert(bench.seq_to_sp3_rsmrst_v3p3_l == 0, "Expected RSMRST_L asserted");
            bench.power_up();
            await(bench.a1_ok);
            dynamicAssert(bench.seq_to_sp3_rsmrst_v3p3_l == 1, "Expected RSMRST_L de-asserted");
            bench.v3p3_s5.force_disable(True);
            delay(10);
            dynamicAssert(bench.a1_ok == False, "Expected a1_ok to de-assert");
            dynamicAssert(bench.seq_to_sp3_rsmrst_v3p3_l == 0, "Expected RSMRST_L asserted");
            dynamicAssert(bench.v3p3_s5.enabled == False, "Expected v3p3_s5_en de-asserted");
            delay(200);
            // Verify no re-start
            bench.v3p3_s5.force_disable(False);
            bench.power_up();
            delay(200);
            dynamicAssert(bench.state == IDLE, "Expected state to be IDLE");
            dynamicAssert(bench.seq_to_sp3_rsmrst_v3p3_l == 0, "Expected RSMRST_L asserted");
            dynamicAssert(bench.v3p3_s5.enabled == False, "Expected v3p3_s5_en de-asserted");
            bench.power_down();
            delay(200);
            bench.power_up();
            delay(20);
            dynamicAssert(bench.state != IDLE, "Expected state to be out of IDLE");
            await(bench.a1_ok);
            dynamicAssert(bench.seq_to_sp3_rsmrst_v3p3_l == 1, "Expected RSMRST_L de-asserted");
            delay(200);

        endseq);

    endmodule

endpackage
