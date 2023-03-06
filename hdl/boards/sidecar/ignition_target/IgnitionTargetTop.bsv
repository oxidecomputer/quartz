package IgnitionTargetTop;

import DefaultValue::*;

import Board::*;
import IgnitionTarget::*;
import IgnitionTargetWrapper::*;


//
// Rev A
//

(* default_clock_osc = "clk_50mhz", no_default_reset *)
module mkSidecarRevATargetWithResetButton (IgnitionletTarget);
    Parameters parameters = default_app_with_reset_button;
    parameters.external_reset = False;
    parameters.system_power_fault_monitor_enable = False;

    (* hide *) IgnitionTargetIOWrapper _top <-
        mkIgnitionTargetIOAndResetWrapper(parameters);
    return asIgnitionletTarget(_top);
endmodule

(* default_clock_osc = "clk_50mhz", no_default_reset *)
module mkSidecarRevATargetWithPowerButton (IgnitionletTarget);
    Parameters parameters = default_app_with_power_button;
    parameters.external_reset = False;
    parameters.system_power_fault_monitor_enable = False;

    (* hide *) IgnitionTargetIOWrapper _top <-
        mkIgnitionTargetIOAndResetWrapper(parameters);
    return asIgnitionletTarget(_top);
endmodule

//
// Rev B
//

(* default_clock_osc = "clk_50mhz", default_reset = "design_reset_l" *)
module mkSidecarRevBTargetWithResetButton (IgnitionletTarget);
    Parameters parameters = default_app_with_reset_button;
    parameters.invert_leds = True;
    parameters.system_power_fault_monitor_enable = False;

    (* hide *) IgnitionTargetIOWrapper _top <-
        mkIgnitionTargetIOAndResetWrapper(parameters);
    return asIgnitionletTarget(_top);
endmodule

(* default_clock_osc = "clk_50mhz", default_reset = "design_reset_l" *)
module mkSidecarRevBTargetWithPowerButton (IgnitionletTarget);
    Parameters parameters = default_app_with_power_button;
    parameters.invert_leds = True;
    parameters.system_power_fault_monitor_enable = False;

    (* hide *) IgnitionTargetIOWrapper _top <-
        mkIgnitionTargetIOAndResetWrapper(parameters);
    return asIgnitionletTarget(_top);
endmodule

endpackage
