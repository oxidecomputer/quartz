package IgnitionTargetPSC;

import DefaultValue::*;

import IgnitionTarget::*;
import IgnitionTargetTop::*;
import IgnitionTargetWrapper::*;

//
// Rev A
//

(* default_clock_osc = "clk_50mhz", no_default_reset *)
module mkPSCRevAResetButton (IgnitionTargetTopRevA);
    Parameters parameters = default_app_with_reset_button;
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
module mkPSCRevBResetButton (IgnitionTargetTop);
    Parameters parameters = default_app_with_reset_button;
    parameters.invert_leds = True;

    (* hide *) IgnitionTargetTopWithDebug _top <-
        mkIgnitionTargetIOAndResetWrapper(parameters);
    return asIgnitionTargetTop(_top);
endmodule

(* default_clock_osc = "clk_50mhz", default_reset = "design_reset_l" *)
module mkPSCRevBResetButtonNoPowerFaultMonitor (IgnitionTargetTop);
    Parameters parameters = default_app_with_reset_button;
    parameters.invert_leds = True;
    parameters.system_power_fault_monitor_enable = False;

    (* hide *) IgnitionTargetTopWithDebug _top <-
        mkIgnitionTargetIOAndResetWrapper(parameters);
    return asIgnitionTargetTop(_top);
endmodule

endpackage
