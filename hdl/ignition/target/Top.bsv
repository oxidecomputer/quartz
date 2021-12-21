// Copyright 2021 Oxide Computer Company
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package Top;

import BuildVector::*;
import Clocks::*;
import Connectable::*;
import Vector::*;

import Board::*;
import IgnitionTarget::*;
import InitialReset::*;
import ICE40::*;
import SchmittReg::*;
import Strobe::*;
import SyncBits::*;


(* synthesize, default_clock_osc = "clk_50mhz", no_default_reset *)
module mkIgnitionTargetTop (IgnitionletTarget);
    Clock clk_50mhz <- exposeCurrentClock();
    Reset initial_reset <- InitialReset::mkInitialReset(3);

    // Input synchronizers to avoid meta unstable signals. These can be uninitialized since the
    // initial reset above runs for two cycles causing the uninitialized state to be ignored. Using
    // the uninitialized variant removes the complaint from BSC about reset information being lost
    // because no reset is present in the module boundary.
    SyncBitsIfc#(UInt#(6)) id_sync <- mkSyncBitsToCC(clk_50mhz, noReset);
    SyncBitsIfc#(Vector#(6, Bool)) flt_sync <- mkSyncBitsToCC(clk_50mhz, noReset);
    SyncBitIfc#(Bool) btn_sync <- mkSyncBitToCC(clk_50mhz, noReset);

    // Button filter/debounce.
    SchmittReg#(3, Bool) btn_filter <-
        mkSchmittRegA(False, EdgePatterns {
            negative_edge: 'b000,
            positive_edge: 'b001,
            mask: 'b111}, reset_by initial_reset);
    Reg#(Bool) btn_filter_prev <- mkRegU();

    // Transceiver primitives.
    DifferentialInput#(Bit#(1)) aux0_rx <- mkDifferentialInput(InputRegistered);
    DifferentialOutput#(Bit#(1)) aux0_tx <- mkDifferentialOutput(OutputRegistered);

    DifferentialInput#(Bit#(1)) aux1_rx <- mkDifferentialInput(InputRegistered);
    DifferentialOutput#(Bit#(1)) aux1_tx <- mkDifferentialOutput(OutputRegistered);

    // Implementation of the Ignition Target application. This module assumes inputs are
    // synchronized/filtered/debounced and Inout interfaces are resolved.
    IgnitionTargetParameters app_parameters = defaultValue;
    IgnitionTarget app <- mkIgnitionTarget(app_parameters, reset_by initial_reset);

    // Strobe, used as a time pulse to generate timed events.
    Strobe#(24) strobe_1khz <- mkFractionalStrobe(50_000_000 / 1_000, 0, reset_by initial_reset);

    // These null crossings are needed to convince BSC the missing reset
    // information for this output signal is acceptable.
    ReadOnly#(Bool) system_power_enable_sync <-
        mkNullCrossingWire(clk_50mhz, app.commands.system_power_enable);
    ReadOnly#(Vector#(2, Bool)) cmd_sync <-
        mkNullCrossingWire(
            clk_50mhz,
            vec(app.commands.cmd1, app.commands.cmd2));

    mkConnection(id_sync.read, app.id);
    mkConnection(flt_sync.read, app.status);
    mkConnection(asIfc(strobe_1khz), asIfc(app.tick_1khz));

    // Filter the button input and send pressed/released events to the application.
    (* fire_when_enabled *)
    rule do_detect_button_events (strobe_1khz);
        btn_filter_prev <= btn_filter;
        btn_filter <= btn_sync.read;

        if (btn_filter != btn_filter_prev) begin
            // The button is negative asserted, so invert when notifying the
            // application.
            app.button_event(!btn_filter);
        end
    endrule

    // Run the strobe.
    (* no_implicit_conditions, fire_when_enabled *)
    rule do_tick_strobe;
        strobe_1khz.send();
    endrule

    method id = id_sync.send;
    method flt = flt_sync.send;
    method btn = btn_sync.send;
    method system_power_enable = system_power_enable_sync._read;
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
