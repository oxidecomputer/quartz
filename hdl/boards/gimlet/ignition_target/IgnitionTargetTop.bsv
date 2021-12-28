package IgnitionTargetTop;

import DefaultValue::*;

import Board::*;
import IgnitionTarget::*;
import IgnitionTargetWrapper::*;


(* synthesize, default_clock_osc = "clk_50mhz", no_default_reset *)
module mkIgnitionTargetGimletRevA (IgnitionletTarget);
    IgnitionTargetParameters app_parameters = defaultValue;
    app_parameters.invert_cmd_bits = True;

    (* hide *) IgnitionletTarget _top <- mkIgnitionTargetIOAndResetWrapper(app_parameters);
    return _top;
endmodule

endpackage