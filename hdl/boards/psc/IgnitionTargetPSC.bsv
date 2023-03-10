package IgnitionTargetPSC;

import DefaultValue::*;

import IgnitionTarget::*;
import IgnitionTargetTop::*;
import IgnitionTargetWrapper::*;

//
// Rev A
//

(* default_clock_osc = "clk_50mhz", default_reset = "design_reset_l" *)
module mkPSCRevAResetButton (IgnitionTargetTop);
    Parameters parameters = default_app_with_reset_button;
    parameters.external_reset = False;
    parameters.system_power_fault_monitor_enable = False;

    (* hide *) IgnitionTargetTopWithDebug _top <-
        mkIgnitionTargetIOAndResetWrapper(parameters);
    return asIgnitionTargetTop(_top);
endmodule

//
// Rev B
//

(* default_clock_osc = "clk_50mhz", default_reset = "design_reset_l" *)
module mkPSCRevBResetButton (IgnitionTargetTop);
    Parameters parameters = default_app_with_reset_button;
    parameters.invert_leds = True;
    // PSC rev B has a broken PG in its power tree. Disable the power fault
    // monitor to avoid the device never starting up.
    parameters.system_power_fault_monitor_enable = False;

    (* hide *) IgnitionTargetTopWithDebug _top <-
        mkIgnitionTargetIOAndResetWrapper(parameters);
    return asIgnitionTargetTop(_top);
endmodule

endpackage
