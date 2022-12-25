package IgnitionTargetTop;

import DefaultValue::*;

import Board::*;
import IgnitionTarget::*;
import IgnitionTargetWrapper::*;


(* default_clock_osc = "clk_50mhz", no_default_reset *)
module mkGimletRevATargetWithResetButton (IgnitionletTarget);
    Parameters parameters = default_app_with_button_as_reset;
    parameters.external_reset = False;
    parameters.invert_cmd_bits = True;

    (* hide *) IgnitionletTarget _top <-
        mkIgnitionTargetIOAndResetWrapper(parameters);
    return _top;
endmodule

(* default_clock_osc = "clk_50mhz", no_default_reset *)
module mkGimletRevATargetWithPowerButton (IgnitionletTarget);
    Parameters parameters = default_app_with_power_button;
    parameters.external_reset = False;
    parameters.invert_cmd_bits = True;

    (* hide *) IgnitionletTarget _top <-
        mkIgnitionTargetIOAndResetWrapper(parameters);
    return _top;
endmodule

(* default_clock_osc = "clk_50mhz",
    default_reset = "design_reset_l" *)
module mkGimletRevBTargetWithResetButton (IgnitionletTarget);
    Parameters parameters = default_app_with_button_as_reset;
    parameters.invert_cmd_bits = True;

    (* hide *) IgnitionletTarget _top <-
        mkIgnitionTargetIOAndResetWrapper(parameters);
    return _top;
endmodule

(* default_clock_osc = "clk_50mhz",
    default_reset = "design_reset_l" *)
module mkGimletRevBTargetWithPowerButton (IgnitionletTarget);
    Parameters parameters = default_app_with_power_button;
    parameters.invert_cmd_bits = True;

    (* hide *) IgnitionletTarget _top <-
        mkIgnitionTargetIOAndResetWrapper(parameters);
    return _top;
endmodule

endpackage
