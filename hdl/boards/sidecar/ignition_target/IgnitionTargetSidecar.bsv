package IgnitionTargetSidecar;

import DefaultValue::*;

import IgnitionTarget::*;
import IgnitionTargetTop::*;
import IgnitionTargetWrapper::*;


//
// Rev A
//

(* default_clock_osc = "clk_50mhz", no_default_reset *)
module mkSidecarRevATargetWithResetButton (IgnitionTargetTopRevA);
    Parameters parameters = default_app_with_reset_button;
    parameters.external_reset = False;
    parameters.system_power_fault_monitor_enable = False;

    (* hide *) IgnitionTargetTopWithDebug _top <-
        mkIgnitionTargetIOAndResetWrapper(parameters);
    return asIgnitionTargetTopRevA(_top);
endmodule

(* default_clock_osc = "clk_50mhz", no_default_reset *)
module mkSidecarRevATargetWithPowerButton (IgnitionTargetTopRevA);
    Parameters parameters = default_app_with_power_button;
    parameters.external_reset = False;
    parameters.system_power_fault_monitor_enable = False;

    (* hide *) IgnitionTargetTopWithDebug _top <-
        mkIgnitionTargetIOAndResetWrapper(parameters);
    return asIgnitionTargetTopRevA(_top);
endmodule

//
// Rev B
//

(* default_clock_osc = "clk_50mhz", default_reset = "design_reset_l" *)
module mkSidecarRevBTargetWithResetButton (IgnitionTargetTop);
    Parameters parameters = default_app_with_reset_button;
    parameters.invert_leds = True;
    parameters.system_power_fault_monitor_enable = False;

    (* hide *) IgnitionTargetTopWithDebug _top <-
        mkIgnitionTargetIOAndResetWrapper(parameters);
    return asIgnitionTargetTop(_top);
endmodule

(* default_clock_osc = "clk_50mhz", default_reset = "design_reset_l" *)
module mkSidecarRevBTargetWithPowerButton (IgnitionTargetTop);
    Parameters parameters = default_app_with_power_button;
    parameters.invert_leds = True;
    parameters.system_power_fault_monitor_enable = False;

    (* hide *) IgnitionTargetTopWithDebug _top <-
        mkIgnitionTargetIOAndResetWrapper(parameters);
    return asIgnitionTargetTop(_top);
endmodule

endpackage
