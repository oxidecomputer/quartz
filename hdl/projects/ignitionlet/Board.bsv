// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package Board;

//
// The Ignitionlet Board package contains various top modules which can be used to synthesize
// designs for this board.
//

export IgnitionletTargetDebug(..);
export IgnitionletSequencer(..);
export IgnitionletTest(..);
export mkTestWrapper;

import StmtFSM::*;
import Vector::*;

import ICE40::*;
import InitialReset::*;
import TestUtils::*;


//
// `IgnitionletTargetDebug(..)` is a modified `IgnitionTargetTop(..)` to aid
// debugging on hardware.
//
(* always_enabled *)
interface IgnitionletTargetDebug;
    (* prefix = "" *) method Action btn((* port = "btn" *) Bool val);
    method Bool system_power_enable();
    method Bit#(2) led();
    method Bit#(12) debug();

    interface DifferentialTransceiver#(Bit#(1)) aux0;
    interface DifferentialTransceiver#(Bit#(1)) aux1;
endinterface

//
// `IgnitionletSequencer(..)` is a more generic interface intended for
// prototyping of iCE40 based power sequencing applications.
//
(* always_enabled *)
interface IgnitionletSequencer;
    (* prefix = "" *) method Action io1((* port = "io1" *) Bit#(6) val);
    (* prefix = "" *) method Action io2((* port = "io2" *) Bit#(6) val);
    (* prefix = "" *) method Action io3((* port = "io3" *) Bit#(8) val);
    (* prefix = "" *) method Action sw((* port = "sw" *) Bit#(1) val);
    method Bit#(2) led;
endinterface

//
// `IgnitionletTest(..)` is a top and harness for running unit tests on
// hardware.
//
(* always_enabled *)
interface IgnitionletTest;
    (* prefix = "" *) method Action io1((* port = "io1" *) Bit#(6) val);
    method Bit#(6) io2();
    method Bit#(6) io3();
    (* prefix = "" *) method Action sw((* port = "sw" *) Bit#(1) val);
    method Bit#(2) led;
endinterface

module mkTestWrapper
        #(module#(Test#(status_type, debug_type)) mkTest)
            (IgnitionletTest)
                provisos(
                    Bits#(status_type, status_sz),
                    Add#(status_sz, x, 3),
                    Bits#(debug_type, debug_sz),
                    Add#(debug_sz, y, 16));
    Reset reset_sync <- InitialReset::mkInitialReset(2);

    Test#(status_type, debug_type) test <- mkTest(reset_by reset_sync);
    Reg#(Bool) running <- mkRegU();
    Reg#(Bool) passed <- mkRegU();

    mkAutoFSM(seq
        action
            running <= True;
            passed <= False;
            test.start();
        endaction
        action
            running <= False;
            passed <= (test.result == Pass);
        endaction
    endseq, reset_by reset_sync);

    let debug_bits = pack(test.debug)[3:0];

    method led = {pack(passed), pack(running)};

    // Suppress missing field warnings.
    method Action sw(Bit#(1) val);
    endmethod
    method Action io1(Bit#(6) val);
    endmethod
    method io2 = {'0, debug_bits};
    method io3 = 0;
endmodule

endpackage: Board
