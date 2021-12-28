package IgnitionletTargetTop;

import DefaultValue::*;

import Board::*;
import IgnitionTarget::*;
import IgnitionTargetWrapper::*;


(* synthesize, default_clock_osc = "clk_50mhz", no_default_reset *)
module mkIgnitionletTarget (IgnitionletTarget);
    IgnitionTargetParameters app_parameters = defaultValue;

    (* hide *) IgnitionletTarget _top <- mkIgnitionTargetIOAndResetWrapper(app_parameters);
    return _top;
endmodule

endpackage