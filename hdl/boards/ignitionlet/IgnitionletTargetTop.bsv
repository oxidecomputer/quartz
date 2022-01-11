package IgnitionletTargetTop;

import DefaultValue::*;

import Board::*;
import IgnitionTarget::*;
import IgnitionTargetWrapper::*;


(* synthesize, default_clock_osc = "clk_50mhz", no_default_reset *)
module mkIgnitionletTargetWithResetButton (IgnitionletTarget);
    (* hide *) IgnitionletTarget _top <-
        mkIgnitionTargetIOAndResetWrapper(default_app_with_button_as_reset);
    return _top;
endmodule

(* synthesize, default_clock_osc = "clk_50mhz", no_default_reset *)
module mkIgnitionletTargetWithPowerButton (IgnitionletTarget);
    (* hide *) IgnitionletTarget _top <-
        mkIgnitionTargetIOAndResetWrapper(default_app_with_power_button);
    return _top;
endmodule

endpackage