package Top;

import Assert::*;
import BuildVector::*;
import Clocks::*;
import Connectable::*;
import StmtFSM::*;
import Vector::*;

import Board::*;
import ICE40::*;
import IgnitionTarget::*;
import SchmittReg::*;
import Strobe::*;


(* synthesize, default_clock_osc = "clk_50mhz", default_reset = "rst_nc" *)
module mkIgnitionTargetTop (IgnitionletTarget);
    Clock clk_50mhz <- exposeCurrentClock();
    Reset initial_reset <- ICE40::mkInitialReset(clocked_by clk_50mhz);

    SyncBitIfc#(Bool) sys_rst_sync <- mkSyncBit1FromCC(clk_50mhz, reset_by initial_reset);

    IgnitionletTarget app <-
        mkIgnitionTargetIOWrapper(
            clocked_by clk_50mhz,
            reset_by initial_reset);

    mkConnection(sys_rst_sync.read, app.sys_rst);

    method id = app.id;
    method flt = app.flt;
    method sys_rst = sys_rst_sync.send;
    method cmd = app.cmd;

    interface DifferentialTransceiver aux0 = app.aux0;
    interface DifferentialTransceiver aux1 = app.aux1;
endmodule

module mkIgnitionTargetIOWrapper (IgnitionletTarget);
    Wire#(UInt#(6)) id_next <- mkWire();

    // Strobe, used to generate timed events.
    Strobe#(24) strobe_1khz <- mkFractionalStrobe(50_000_000 / 1_000, 0);

    SchmittReg#(3, Bool) sys_rst_filter <-
        mkSchmittRegA(False, EdgePatterns {
            negative_edge: 'b000,
            positive_edge: 'b001,
            mask: 'b111});
    Reg#(Bool) sys_rst_filter_prev <- mkRegA(False);
    Reg#(UInt#(7)) sys_rst_lock_out_ticks_remaining <- mkRegA(50);

    // Transceiver primitives.
    DifferentialInput#(Bit#(1)) aux0_rx <- mkDifferentialInput(InputRegistered);
    DifferentialOutput#(Bit#(1)) aux0_tx <- mkDifferentialOutput(OutputRegistered);

    DifferentialInput#(Bit#(1)) aux1_rx <- mkDifferentialInput(InputRegistered);
    DifferentialOutput#(Bit#(1)) aux1_tx <- mkDifferentialOutput(OutputRegistered);

    IgnitionTarget app <- mkIgnitionTarget();

    (* no_implicit_conditions, fire_when_enabled *)
    rule do_tick_strobe;
        strobe_1khz.send();
    endrule

    (* fire_when_enabled *)
    rule do_tick_app (strobe_1khz);
        app.tick_1khz.send();
    endrule

    (* fire_when_enabled *)
    rule do_set_id;
        app.id(id_next);
    endrule

    (* fire_when_enabled *)
    rule do_detect_sys_rst_pressed (strobe_1khz);
        sys_rst_filter_prev <= sys_rst_filter;

        let positive_edge = !sys_rst_filter_prev && sys_rst_filter;
        let lock_out_active = sys_rst_lock_out_ticks_remaining > 0;

        if (lock_out_active) begin
            sys_rst_lock_out_ticks_remaining <= sys_rst_lock_out_ticks_remaining - 1;
        end else if (positive_edge) begin
            sys_rst_lock_out_ticks_remaining <= 50; // ~50ms.
            app.button_pressed.send();
        end
    endrule

    method id = id_next._write;
    method flt = app.status;
    method sys_rst = sys_rst_filter._write;
    method cmd = app.cmd;

    interface DifferentialTransceiver aux0;
        interface DifferentialPairRx rx = aux0_rx.pads;
        interface DifferentialPairTx tx = aux0_tx.pads;
    endinterface

    interface DifferentialTransceiver aux1;
        interface DifferentialPairRx rx = aux1_rx.pads;
        interface DifferentialPairTx tx = aux1_tx.pads;
    endinterface
endmodule: mkIgnitionTargetIOWrapper

endpackage: Top
