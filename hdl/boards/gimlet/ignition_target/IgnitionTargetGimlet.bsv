package IgnitionTargetGimlet;

import DefaultValue::*;

import IgnitionTarget::*;
import IgnitionTargetTop::*;
import IgnitionTargetWrapper::*;


//
// Rev B, C, D
//
// Note: Rev B top modules are compatible with Rev B, Rev C and Rev D board
// revisions.
//

(* default_clock_osc = "clk_50mhz", default_reset = "design_reset_l" *)
module mkGimletRevBTargetWithResetButton (IgnitionTargetTop);
    Parameters parameters = default_app_with_reset_button;
    parameters.invert_leds = True;
    parameters.system_power_fault_monitor_enable = False;

    (* hide *) IgnitionTargetTopWithDebug _top <-
        mkIgnitionTargetIOAndResetWrapper(parameters);
    return asIgnitionTargetTop(_top);
endmodule

(* default_clock_osc = "clk_50mhz", default_reset = "design_reset_l" *)
module mkGimletRevBTargetWithPowerButton (IgnitionTargetTop);
    Parameters parameters = default_app_with_power_button;
    parameters.invert_leds = True;
    parameters.system_power_fault_monitor_enable = False;

    (* hide *) IgnitionTargetTopWithDebug _top <-
        mkIgnitionTargetIOAndResetWrapper(parameters);
    return asIgnitionTargetTop(_top);
endmodule

endpackage
