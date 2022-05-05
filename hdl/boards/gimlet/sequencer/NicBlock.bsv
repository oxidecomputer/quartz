package NicBlock;

import Assert::*;
import BuildVector::*;
import Connectable::*;
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
        method NicStateType state();
        // method A1OutStatus output_readbacks();
        // method A1Readbacks input_readbacks();
    endinterface

    interface NicRegsReverse;
        method Bool en;
        method Action state(NicStateType value);
    endinterface

    // Allow our output pin source to connect to our output pin sink
    instance Connectable#(NicRegs, NicRegsReverse);
        module mkConnection#(NicRegs source, NicRegsReverse sink) (Empty);
            mkConnection(source.en, sink.en);
            mkConnection(source.state, sink.state);
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

        Reg#(UInt#(24)) ticks_count <- mkReg(0);
        RWire#(UInt#(24)) ticks_count_next <- mkRWire();

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
            enable_rails(power_rails, IDLE);
        endseq, !enable || faulted && abort);

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
            seq_to_nic_cld_rst_l <= pack(state == DONE);
            seq_to_nic_perst_l <= pack(state == DONE && sp3_to_seq_nic_perst_l == 1);
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
            end else if (enable) begin
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
            method state = state._read;
        endinterface

    endmodule
        

endpackage