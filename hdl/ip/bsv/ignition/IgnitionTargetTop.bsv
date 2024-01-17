// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package IgnitionTargetTop;

//
// The IgnitionTargetTop package contains various top modules for synthesizing
// versions tailored to specific boards.
//

export DifferentialTransceiver(..);
export IgnitionTargetTop(..);
export IgnitionTargetTopWithDebug(..);

export asIgnitionTargetTop;

import ICE40::*;
import IgnitionProtocol::*;

//
// `DifferentialTranceiver(..)` is used to implement an LVDS transceiver,
// allowing the pin pads of the diff pair to be connected somewhat conveniently
// to an appropriate IO primitive.
//
interface DifferentialTransceiver #(type one_bit_type);
    interface DifferentialPairTx#(one_bit_type) tx;
    interface DifferentialPairRx#(one_bit_type) rx;
endinterface

//
// `IgnitionTargetTop(..)` is an interface used to implement the current
// Ignition Target subsystem.
//
(* always_enabled *)
interface IgnitionTargetTop;
    // Target system status and control
    (* prefix = "" *) method Action id(UInt#(6) id);
    (* prefix = "" *) method Action flt(SystemFaults flt);

    method Bool system_power_enable();
    method Bool system_power_hotswap_controller_restart();

    // UI
    method Bit#(2) led();
    (* prefix = "" *) method Action btn(Bool btn);

    interface DifferentialTransceiver#(Bit#(1)) aux0;
    interface DifferentialTransceiver#(Bit#(1)) aux1;
endinterface

//
// `IgnitionTargetTopWithDebug(..)` adds some debug bits to
// `IgnitionTargetTop(..)` for use with external analyzers.
//
(* always_enabled *)
interface IgnitionTargetTopWithDebug;
    // Target system status and control
    (* prefix = "" *) method Action id(UInt#(6) id);
    (* prefix = "" *) method Action flt(SystemFaults flt);

    method Bool system_power_enable();
    method Bool system_power_hotswap_controller_restart();

    // UI
    method Bit#(2) led();
    (* prefix = "" *) method Action btn(Bool btn);
    method Bit#(12) debug();

    interface DifferentialTransceiver#(Bit#(1)) aux0;
    interface DifferentialTransceiver#(Bit#(1)) aux1;
endinterface

// Expose a `IgnitionTargetTopWithDebug` as `IgnitionTargetTop` by stripping the
// debug method.
function IgnitionTargetTop
        asIgnitionTargetTop(IgnitionTargetTopWithDebug wrapper) =
    interface IgnitionTargetTop;
        method id = wrapper.id;
        method Action flt(val) = wrapper.flt(unpack(pack(val)));
        method btn = wrapper.btn;
        method system_power_enable = wrapper.system_power_enable;
        method system_power_hotswap_controller_restart =
                wrapper.system_power_hotswap_controller_restart;
        method led = wrapper.led;
        interface DifferentialTransceiver aux0 = wrapper.aux0;
        interface DifferentialTransceiver aux1 = wrapper.aux1;
    endinterface;

endpackage
