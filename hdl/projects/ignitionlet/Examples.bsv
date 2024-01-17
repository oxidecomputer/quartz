// Copyright 2021 Oxide Computer Company
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package Examples;

import Blinky::*;
import Board::*;


(* default_clock_osc = "clk_50mhz", default_reset = "rst_nc" *)
module mkSequencerBlinky (IgnitionletSequencer);
    Wire#(Bit#(6)) io1_next <- mkWire();
    Wire#(Bit#(6)) io2_next <- mkWire();
    Wire#(Bit#(8)) io3_next <- mkWire();
    Wire#(Bit#(1)) sw_next <- mkWire();

    Blinky#(50_000_000) blinky <- Blinky::mkBlinky();

    rule do_handle_button;
        let io = ({'0, ~io1_next} | {'0, ~io2_next} | ~io3_next) != 0;
        let sw = ~sw_next != 0;

        if (io || sw) begin
            blinky.button_pressed();
        end
    endrule

    method io1 = io1_next._write;
    method io2 = io2_next._write;
    method io3 = io3_next._write;
    method sw = sw_next._write;
    method led = blinky.led;
endmodule

endpackage: Examples
