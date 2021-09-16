// Copyright 2021 Oxide Computer Company

package GimletSeqTop;

import MetaSync::*;

//SPI interface

(* always_enabled *)
interface Top;
    
endinterface

(* synthesize, default_clock_osc="clk_50mhz" *)
module mkGimletSeq (Top);
    Fans fan_block <- mkFans();

    // Meta-harden inputs.
endmodule

endpackage: GimletSeqTop