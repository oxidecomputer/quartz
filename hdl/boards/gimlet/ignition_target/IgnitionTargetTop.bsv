package IgnitionTargetTop;

import DefaultValue::*;

import Board::*;
import IgnitionTarget::*;
import IgnitionTargetWrapper::*;


//
// Rev A
//

(* default_clock_osc = "clk_50mhz", no_default_reset *)
module mkGimletRevATargetWithResetButton (IgnitionletTarget);
    Parameters parameters = default_app_with_reset_button;
    parameters.external_reset = False;
    parameters.invert_leds = True;
    parameters.system_power_fault_monitor_enable = False;

    (* hide *) IgnitionTargetIOWrapper _top <-
        mkIgnitionTargetIOAndResetWrapper(parameters);
    return asIgnitionletTarget(_top);
endmodule

(* default_clock_osc = "clk_50mhz", no_default_reset *)
module mkGimletRevATargetWithPowerButton (IgnitionletTarget);
    Parameters parameters = default_app_with_power_button;
    parameters.external_reset = False;
    parameters.invert_leds = True;
    parameters.system_power_fault_monitor_enable = False;

    (* hide *) IgnitionTargetIOWrapper _top <-
        mkIgnitionTargetIOAndResetWrapper(parameters);
    return asIgnitionletTarget(_top);
endmodule

//
// Rev B
//
// Note: Rev B top modules are compatible with both Rev B and Rev C board
// revisions.
//

(* default_clock_osc = "clk_50mhz", default_reset = "design_reset_l" *)
module mkGimletRevBTargetWithResetButton (IgnitionletTarget);
    Parameters parameters = default_app_with_reset_button;
    parameters.invert_leds = True;

    (* hide *) IgnitionTargetIOWrapper _top <-
        mkIgnitionTargetIOAndResetWrapper(parameters);
    return asIgnitionletTarget(_top);
endmodule

(* default_clock_osc = "clk_50mhz", default_reset = "design_reset_l" *)
module mkGimletRevBTargetWithPowerButton (IgnitionletTarget);
    Parameters parameters = default_app_with_power_button;
    parameters.invert_leds = True;
    parameters.system_power_fault_monitor_enable = False;

    (* hide *) IgnitionTargetIOWrapper _top <-
        mkIgnitionTargetIOAndResetWrapper(parameters);
    return asIgnitionletTarget(_top);
endmodule

endpackage
