package IgnitionletTargetTop;

import DefaultValue::*;
import Vector::*;

import IgnitionTarget::*;
import IgnitionTargetWrapper::*;
import IgnitionTargetTop::*;


(* default_clock_osc = "clk_50mhz", default_reset = "design_reset_l" *)
module mkIgnitionletTargetWithResetButton (IgnitionTargetTop);
    let parameters = default_app_with_reset_button;
    parameters.external_reset = False;
    parameters.system_type = tagged Valid 5;

    (* hide *) IgnitionTargetTopWithDebug _top <-
        mkIgnitionTargetIOAndResetWrapper(parameters);
    return asIgnitionTargetTop(_top);
endmodule

(* default_clock_osc = "clk_50mhz", default_reset = "design_reset_l" *)
module mkIgnitionletTargetWithPowerButton (IgnitionTargetTop);
    let parameters = default_app_with_power_button;
    parameters.external_reset = False;
    parameters.system_type = tagged Valid 5;

    (* hide *) IgnitionTargetTopWithDebug _top <-
        mkIgnitionTargetIOAndResetWrapper(parameters);
    return asIgnitionTargetTop(_top);
endmodule

endpackage
