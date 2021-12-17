// Copyright 2021 Oxide Computer Company
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package Board;

//
// The Ignitionlet Board package contains various top modules which can be used to synthesize
// designs for this board.
//

export DifferentialTransceiver(..);
export IgnitionletTarget(..), IgnitionletSequencer(..);

import Vector::*;

import ICE40::*;


//
// `DifferentialTranceiver(..)` is used to implement an LVDS transceiver, allowing the pin pads of
// the diff pair to be connected somewhat conveniently to an appropriate IO primitive.
//
interface DifferentialTransceiver #(type one_bit_type);
    interface DifferentialPairTx#(one_bit_type) tx;
    interface DifferentialPairRx#(one_bit_type) rx;
endinterface

//
// `IgnitionletTarget(..)` is an interface used to implement/prototype the Ignition Target
// subsystem.
//
(* always_enabled *)
interface IgnitionletTarget;
    (* prefix = "" *) method Action id((* port = "id" *) UInt#(6) val);
    (* prefix = "" *) method Action flt((* port = "flt" *) Vector#(6, Bool) val);
    (* prefix = "" *) method Action btn((* port = "btn" *) Bool val);
    method Vector#(3, Bool) cmd;

    interface DifferentialTransceiver#(Bit#(1)) aux0;
    interface DifferentialTransceiver#(Bit#(1)) aux1;
endinterface

//
// `IgnitionletSequencer(..)` is a more generic interface intended for prototyping of iCE40 based
// power sequencing applications.
//
(* always_enabled *)
interface IgnitionletSequencer;
    (* prefix = "" *) method Action io1((* port = "io1" *) Bit#(6) val);
    (* prefix = "" *) method Action io2((* port = "io2" *) Bit#(6) val);
    (* prefix = "" *) method Action io3((* port = "io3" *) Bit#(8) val);
    (* prefix = "" *) method Action sw((* port = "sw" *) Bit#(1) val);
    method Bit#(2) led;
endinterface

endpackage: Board
