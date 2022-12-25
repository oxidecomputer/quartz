package IgnitionletTargetTop;

import DefaultValue::*;

import Board::*;
import IgnitionTarget::*;
import IgnitionTargetWrapper::*;


(* default_clock_osc = "clk_50mhz", no_default_reset *)
module mkIgnitionletTargetWithResetButton (IgnitionletTarget);
    let parameters = default_app_with_button_as_reset;
    parameters.external_reset = False;

    (* hide *) IgnitionletTarget _top <-
        mkIgnitionTargetIOAndResetWrapper(parameters);
    return _top;
endmodule

(* default_clock_osc = "clk_50mhz", no_default_reset *)
module mkIgnitionletTargetWithResetButtonAndAuxLoopbackIndicators (IgnitionletTarget);
    let parameters = default_app_with_button_as_reset;
    parameters.external_reset = False;
    parameters.aux_loopback_as_cmd_bits = True;

    (* hide *) IgnitionletTarget _top <-
        mkIgnitionTargetIOAndResetWrapper(parameters);
    return _top;
endmodule

(* default_clock_osc = "clk_50mhz", no_default_reset *)
module mkIgnitionletTargetWithPowerButton (IgnitionletTarget);
    let parameters = default_app_with_power_button;
    parameters.external_reset = False;

    (* hide *) IgnitionletTarget _top <-
        mkIgnitionTargetIOAndResetWrapper(parameters);
    return _top;
endmodule

endpackage