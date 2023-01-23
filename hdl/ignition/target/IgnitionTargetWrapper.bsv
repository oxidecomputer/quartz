// Copyright 2021 Oxide Computer Company
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package IgnitionTargetWrapper;

import BuildVector::*;
import Clocks::*;
import Connectable::*;
import Vector::*;

import ICE40::*;
import InitialReset::*;
import IOSync::*;
import SchmittReg::*;
import Strobe::*;

import Board::*;
import IgnitionTarget::*;

module mkIgnitionTargetIOAndResetWrapper
        #(Parameters parameters) (IgnitionletTarget);
    Clock clk_50mhz <- exposeCurrentClock();
    Reset reset_sync <- case (parameters.external_reset)
            False: InitialReset::mkInitialReset(2);
            True: mkAsyncResetFromCR(2, clk_50mhz);
        endcase;

    // Input synchronizers to avoid meta unstable signals. These can be uninitialized since the
    // initial reset above runs for two cycles causing the uninitialized state to be ignored. Using
    // the uninitialized variant removes the complaint from BSC about reset information being lost
    // because no reset is present in the module boundary.

    // ID is expected to be held stable before the application leaves reset. Use
    // only a single set of registers for the input.
    InputReg#(UInt#(6), 1) id_sync <- mkInputSync();
    InputReg#(Vector#(6, Bool), 2) flt_sync <- mkInputSync();
    // Button is filtered using a SchmittReg below, which acts as the second
    // ff of the synchronizer.
    InputReg#(Bool, 1) btn_sync <- mkInputSync();

    // Button filter/debounce.
    SchmittReg#(3, Bool) btn_filter <-
        mkSchmittRegA(False, EdgePatterns {
            negative_edge: 'b000,
            positive_edge: 'b001,
            mask: 'b111}, reset_by reset_sync);
    Reg#(Bool) btn_filter_prev <- mkRegU();

    // Transceiver primitives.
    DifferentialInput#(Bit#(1)) aux0_rx <- mkDifferentialInput(InputRegistered);
    DifferentialOutput#(Bit#(1)) aux0_tx <- mkDifferentialOutput(OutputRegistered);

    DifferentialInput#(Bit#(1)) aux1_rx <- mkDifferentialInput(InputRegistered);
    DifferentialOutput#(Bit#(1)) aux1_tx <- mkDifferentialOutput(OutputRegistered);

    // Implementation of the Ignition Target application. This module assumes inputs are
    // synchronized/filtered/debounced and Inout interfaces are resolved.
    IgnitionTarget app <- mkIgnitionTarget(parameters, reset_by reset_sync);

    // Strobe, used as a time pulse to generate timed events.
    Strobe#(24) strobe_1khz <-
        mkFractionalStrobe(50_000_000 / 1_000, 0, reset_by reset_sync);
    mkFreeRunningStrobe(strobe_1khz);

    // This null crossings is needed to convince BSC the missing reset
    // information for these output signals is acceptable.
    ReadOnly#(Commands) commands_sync <-
        mkNullCrossingWire(clk_50mhz, app.commands);

    mkConnection(id_sync, app.id);
    mkConnection(flt_sync, app.status);
    mkConnection(asIfc(strobe_1khz), asIfc(app.tick_1khz));

    // Connect the diff IO to the application transceiver interfaces.
    mkConnection(tuple2(asIfc(aux0_rx), asIfc(aux0_tx)), app.aux0);
    mkConnection(tuple2(asIfc(aux1_rx), asIfc(aux1_tx)), app.aux1);

    // Filter the button input and send pressed/released events to the application.
    (* fire_when_enabled *)
    rule do_detect_button_events (strobe_1khz);
        btn_filter_prev <= btn_filter;
        btn_filter <= btn_sync;

        if (btn_filter != btn_filter_prev) begin
            // The button is negative asserted, so invert when notifying the
            // application.
            app.button_event(!btn_filter);
        end
    endrule

    method id = sync(id_sync);
    method flt = sync(flt_sync);
    method btn = sync(btn_sync);
    method system_power_enable = commands_sync.system_power_enable;
    method cmd1 = commands_sync.cmd1;
    method cmd2 = commands_sync.cmd2;

    interface DifferentialTransceiver aux0;
        interface DifferentialPairRx rx = aux0_rx.pads;
        interface DifferentialPairTx tx = aux0_tx.pads;
    endinterface

    interface DifferentialTransceiver aux1;
        interface DifferentialPairRx rx = aux1_rx.pads;
        interface DifferentialPairTx tx = aux1_tx.pads;
    endinterface
endmodule

instance Connectable#(DifferentialInputOutput#(Bit#(1)), Transceiver);
    module mkConnection #(DifferentialInputOutput#(Bit#(1)) pads, Transceiver txr) (Empty);
        match {.rx_pads, .tx_pads} = pads;

        (* fire_when_enabled *)
        rule do_rx;
            txr.rx(rx_pads);
        endrule

        (* fire_when_enabled *)
        rule do_tx;
            tx_pads <= txr.tx;
        endrule
    endmodule
endinstance

endpackage: IgnitionTargetWrapper
