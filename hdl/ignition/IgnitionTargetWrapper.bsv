// Copyright 2021 Oxide Computer Company
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package IgnitionTargetWrapper;

import BuildVector::*;
import Clocks::*;
import ConfigReg::*;
import Connectable::*;
import GetPut::*;
import Vector::*;

import BitSampling::*;
import InitialReset::*;
import ICE40::*;
import IOSync::*;
import SerialIO::*;
import SchmittReg::*;
import Strobe::*;

import Board::*;
import IgnitionProtocol::*;
import IgnitionTarget::*;
import IgnitionTransceiver::*;


(* always_enabled *)
interface IgnitionTargetIOWrapper;
    method Action id(UInt#(6) val);
    method Action flt(SystemFaults val);
    method Action btn(Bool val);
    method Bool system_power_enable();
    method Bit#(2) led();
    method Bit#(12) debug();

    interface DifferentialTransceiver#(Bit#(1)) aux0;
    interface DifferentialTransceiver#(Bit#(1)) aux1;
endinterface

module mkIgnitionTargetIOAndResetWrapper
        #(Parameters parameters) (IgnitionTargetIOWrapper);
    Clock clk_50mhz <- exposeCurrentClock();
    Reset reset_sync <- case (parameters.external_reset)
            False: InitialReset::mkInitialReset(3);
            True: mkAsyncResetFromCR(3, clk_50mhz);
        endcase;

    // Input synchronizers to avoid meta unstable signals. These can be
    // uninitialized since the initial reset above runs for two cycles causing
    // the uninitialized state to be ignored. Using the uninitialized variant
    // removes the complaint from BSC about reset information being lost because
    // no reset is present in the module boundary.
    Reg#(UInt#(6)) id_sync <- mkConfigRegU();
    Reg#(SystemFaults) flt_sync <- mkInputSync();
    Reg#(Bool) btn_sync <- mkInputSync();

    // A3/A2 power fault filter/debounce. These are to avoid tripping the power
    // fault monitor during a short duration glitch on these signals.
    SchmittReg#(3, Bool) power_a3_fault_filter <-
        mkSchmittReg(False, EdgePatterns {
            negative_edge: 'b000,
            positive_edge: 'b111,
            mask: 'b111}, reset_by reset_sync);

    SchmittReg#(3, Bool) power_a2_fault_filter <-
        mkSchmittReg(False, EdgePatterns {
            negative_edge: 'b000,
            positive_edge: 'b111,
            mask: 'b111}, reset_by reset_sync);

    // Button filter/debounce.
    SchmittReg#(3, Bool) btn_filter <-
        mkSchmittReg(False, EdgePatterns {
            negative_edge: 'b000,
            positive_edge: 'b001,
            mask: 'b111}, reset_by reset_sync);
    Reg#(Bool) btn_filter_prev <- mkRegU();

    // Transceiver primitives. The SerialIOAdapters help connect the contineous
    // input/output pins with the transceiver Get/Put interfaces and incorporate
    // a bit sampler, removing some error prone boiler plate rules.
    //
    // The tx strobe and five cycle bit samplers divide clk_50mhz into an
    // effective link baudrate of 10Mb/s.

    Strobe#(3) tx_strobe <- mkLimitStrobe(1, 5, 0, reset_by reset_sync);
    TargetTransceiver txr <- mkTargetTransceiver(reset_by reset_sync);

    // Connect link 0.
    SerialIOAdapter#(5) aux0_adapter <-
        mkSerialIOAdapter(
            tx_strobe,
            tuple2(txr.to_link, txr.from_link[0]),
            reset_by reset_sync);

    DifferentialInput#(Bit#(1)) aux0_rx <- mkDifferentialInput(InputRegistered);
    DifferentialOutput#(Bit#(1)) aux0_tx <- mkDifferentialOutput(OutputRegistered);

    mkConnection(aux0_rx, aux0_adapter.rx);
    mkConnection(aux0_adapter.tx, aux0_tx._write);

    // Connect link 1.
    //
    // The transceiver has a single Get interface, intending to broadcast the
    // same data on both links. The IOAdapter of the second link only observes
    // the serial Get interface to read the bit to be transmitterd, without
    // advancing it. This will make both IOAdapters transmit at the same time
    // without rule scheduling conflicts.
    SerialIOAdapter#(5) aux1_adapter <-
        mkSerialIOAdapterPassiveTx(
            tuple2(txr.to_link, txr.from_link[1]),
            reset_by reset_sync);

    DifferentialInput#(Bit#(1)) aux1_rx <- mkDifferentialInput(InputRegistered);
    DifferentialOutput#(Bit#(1)) aux1_tx <- mkDifferentialOutput(OutputRegistered);

    mkConnection(aux1_rx, aux1_adapter.rx);
    // Mirror aux0_rx to aux1_tx if requested in the parameters.
    if (parameters.mirror_link0_rx_as_link1_tx)
        mkConnection(aux0_adapter.rx_sampled, aux1_tx._write);
    else
        mkConnection(aux1_adapter.tx, aux1_tx._write);

    // Strobe, used as a time pulse to generate timed events.
    Strobe#(16) strobe_1khz <-
        mkLimitStrobe(1, 50_000_000 / 1_000, 0, reset_by reset_sync);

    // Implementation of the Ignition Target application. This module assumes
    // inputs are synchronized/filtered/debounced and Inout interfaces are
    // resolved.
    Target app <- mkTarget(parameters, reset_by reset_sync);

    // Connect the app to the 1kHz tick.
    mkConnection(asIfc(strobe_1khz), asIfc(app.tick_1khz));

    // Connect the app to the transceiver.
    mkConnection(txr, app.txr);

    // This null crossings is needed to convince BSC the missing reset
    // information for these output signals is acceptable.
    ReadOnly#(SystemPower) system_power_sync <-
        mkNullCrossingWire(clk_50mhz, app.system_power);

    ReadOnly#(Bit#(2)) leds_sync <-
        mkNullCrossingWire(clk_50mhz, app.leds);

    // Connect application methods to synchronized inputs.
    (* fire_when_enabled *)
    rule do_set_system_type;
        app.set_system_type(
            fromMaybe(
                SystemType {id: extend(id_sync)},
                parameters.system_type));
    endrule

    (* fire_when_enabled *)
    rule do_filter_power_faults (strobe_1khz);
        power_a3_fault_filter <= flt_sync.power_a3;
        power_a2_fault_filter <= flt_sync.power_a2;
    endrule

    (* no_implicit_conditions, fire_when_enabled *)
    rule do_set_faults;
        app.set_faults(SystemFaults {
            rot: flt_sync.rot,
            sp: flt_sync.sp,
            reserved2: flt_sync.reserved2,
            reserved1: flt_sync.reserved1,
            power_a2: power_a2_fault_filter,
            power_a3: power_a3_fault_filter});
    endrule

    // Filter the button input and send pressed/released events to the
    // application.
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

    // Run the strobes.
    (* no_implicit_conditions, fire_when_enabled *)
    rule do_tick_strobe;
        tx_strobe.send();
        strobe_1khz.send();
    endrule

    method id = sync(id_sync);
    method flt = sync_inverted(flt_sync);
    method btn = sync(btn_sync);
    method system_power_enable = unpack(pack(system_power_sync));
    method led = leds_sync;
    method debug = '0;

    interface DifferentialTransceiver aux0;
        interface DifferentialPairRx rx = aux0_rx.pads;
        interface DifferentialPairTx tx = aux0_tx.pads;
    endinterface

    interface DifferentialTransceiver aux1;
        interface DifferentialPairRx rx = aux1_rx.pads;
        interface DifferentialPairTx tx = aux1_tx.pads;
    endinterface
endmodule

function IgnitionletTarget
        asIgnitionletTarget(IgnitionTargetIOWrapper wrapper) =
    interface IgnitionletTarget;
        method id = wrapper.id;
        method Action flt(val) = wrapper.flt(unpack(pack(val)));
        method btn = wrapper.btn;
        method system_power_enable = wrapper.system_power_enable;
        method led = wrapper.led;
        interface DifferentialTransceiver aux0 = wrapper.aux0;
        interface DifferentialTransceiver aux1 = wrapper.aux1;
    endinterface;

endpackage: IgnitionTargetWrapper
