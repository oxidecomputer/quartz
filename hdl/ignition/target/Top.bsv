// Copyright 2021 Oxide Computer Company
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package Top;

import Clocks::*;
import Vector::*;

import Board::*;
import IgnitionTarget::*;
import InitialReset::*;
import InputReg::*;
import ICE40::*;
import SchmittReg::*;
import Strobe::*;


(* synthesize, default_clock_osc = "clk_50mhz", no_default_reset *)
module mkIgnitionTargetTop (IgnitionletTarget);
    Clock clk_50mhz <- exposeCurrentClock();
    Reset initial_reset <- InitialReset::mkInitialReset(2);

    // Input synchronizers to avoid meta unstable signals. These can be uninitialized since the
    // initial reset above runs for two cycles causing the uninitialized state to be ignored. Using
    // the uninitialized variant removes the complaint from BSC about reset information being lost
    // because no reset is present in the module boundary.
    Reg#(UInt#(6)) id_sync <- mkInputRegU();
    Reg#(Vector#(6, Bool)) flt_sync <- mkInputRegU();
    Reg#(Bool) sys_rst_sync <- mkInputRegU();

    // The sys_rst button needs debouncing. A register with schmitt trigger-like behavior and 1kHz
    // sample rate is used to filter the signal from the button. A short lock out is added to avoid
    // double triggering, mechanical or human induced, for the next 50 ms.
    let sys_lock_out_ticks = 50; // 1kHz strobe, or ~50ms.

    SchmittReg#(3, Bool) sys_rst_filter <-
        mkSchmittRegA(False, EdgePatterns {
            negative_edge: 'b000,
            positive_edge: 'b001,
            mask: 'b111}, reset_by initial_reset);
    Reg#(Bool) sys_rst_filter_prev <- mkRegA(False, reset_by initial_reset);
    Reg#(UInt#(7)) sys_rst_lock_out_ticks_remaining
        <- mkRegA(sys_lock_out_ticks, reset_by initial_reset);

    // Transceiver primitives.
    DifferentialInput#(Bit#(1)) aux0_rx <- mkDifferentialInput(InputRegistered);
    DifferentialOutput#(Bit#(1)) aux0_tx <- mkDifferentialOutput(OutputRegistered);

    DifferentialInput#(Bit#(1)) aux1_rx <- mkDifferentialInput(InputRegistered);
    DifferentialOutput#(Bit#(1)) aux1_tx <- mkDifferentialOutput(OutputRegistered);

    // Implementation of the Ignition Target application. This module assumes inputs are
    // discrete/filtered and Inout interfaces are resolved.
    IgnitionTarget app <- mkIgnitionTarget(reset_by initial_reset);

    // Strobe, used to generate timed events.
    Strobe#(24) strobe_1khz <- mkFractionalStrobe(50_000_000 / 1_000, 0, reset_by initial_reset);

    // This null crossing is needed to convince BSC the missing reset information for this output
    // signal is acceptable.
    ReadOnly#(Vector#(3, Bool)) cmd_sync <- mkNullCrossingWire(clk_50mhz, app.cmd);

    // The system ID is latched once by the app after reset. This rule fires only once on reset and
    // ignores the input afterwards.
    (* fire_when_enabled *)
    rule do_set_id;
        app.id(id_sync);
    endrule

    (* no_implicit_conditions, fire_when_enabled *)
    rule do_set_flt;
        app.status(flt_sync);
    endrule

    (* fire_when_enabled *)
    rule do_detect_sys_rst_pressed (strobe_1khz);
        sys_rst_filter <= sys_rst_sync;
        sys_rst_filter_prev <= sys_rst_filter;

        let positive_edge = !sys_rst_filter_prev && sys_rst_filter;
        let lock_out_active = sys_rst_lock_out_ticks_remaining > 0;

        if (lock_out_active) begin
            sys_rst_lock_out_ticks_remaining <= sys_rst_lock_out_ticks_remaining - 1;
        end else if (positive_edge) begin
            sys_rst_lock_out_ticks_remaining <= sys_lock_out_ticks;
            app.button_pressed.send();
        end
    endrule

    (* no_implicit_conditions, fire_when_enabled *)
    rule do_tick_strobe;
        strobe_1khz.send();
    endrule

    (* fire_when_enabled *)
    rule do_tick_app (strobe_1khz);
        app.tick_1khz.send();
    endrule

    method id = id_sync._write;
    method flt = flt_sync._write;
    method sys_rst = sys_rst_sync._write;
    method cmd = cmd_sync._read;

    interface DifferentialTransceiver aux0;
        interface DifferentialPairRx rx = aux0_rx.pads;
        interface DifferentialPairTx tx = aux0_tx.pads;
    endinterface

    interface DifferentialTransceiver aux1;
        interface DifferentialPairRx rx = aux1_rx.pads;
        interface DifferentialPairTx tx = aux1_tx.pads;
    endinterface
endmodule

endpackage: Top
