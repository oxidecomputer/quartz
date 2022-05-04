package IgnitionTargetTop;

import DefaultValue::*;

import Board::*;
import IgnitionTarget::*;
import IgnitionTargetWrapper::*;


(* synthesize, default_clock_osc = "clk_50mhz", no_default_reset *)
module mkGimletRevATargetWithResetButton (IgnitionletTarget);
    Parameters parameters = default_app_with_button_as_reset;
    parameters.invert_cmd_bits = True;

    (* hide *) IgnitionletTarget _top <-
        mkIgnitionTargetIOAndResetWrapper(parameters);
    return _top;
endmodule

(* synthesize, default_clock_osc = "clk_50mhz", no_default_reset *)
module mkGimletRevATargetWithPowerButton (IgnitionletTarget);
    Parameters parameters = default_app_with_power_button;
    parameters.invert_cmd_bits = True;

    (* hide *) IgnitionletTarget _top <-
        mkIgnitionTargetIOAndResetWrapper(parameters);
    return _top;
endmodule

endpackage