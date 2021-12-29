package IgnitionTargetTop;

import DefaultValue::*;

import Board::*;
import IgnitionTarget::*;
import IgnitionTargetWrapper::*;

//
// Rev A
//

(* synthesize, default_clock_osc = "clk_50mhz", no_default_reset *)
module mkPSCRevAResetButton (IgnitionletTarget);
    Parameters parameters = default_app_with_reset_button;
    parameters.external_reset = False;
    parameters.system_power_fault_monitor_enable = False;

    (* hide *) IgnitionTargetIOWrapper _top <-
        mkIgnitionTargetIOAndResetWrapper(parameters);
    return asIgnitionletTarget(_top);
endmodule

//
// Rev B
//

(* synthesize,
    default_clock_osc = "clk_50mhz",
    default_reset = "design_reset_l" *)
module mkPSCRevBResetButton (IgnitionletTarget);
    Parameters parameters = default_app_with_reset_button;
    parameters.invert_leds = True;

    (* hide *) IgnitionTargetIOWrapper _top <-
        mkIgnitionTargetIOAndResetWrapper(parameters);
    return asIgnitionletTarget(_top);
endmodule

(* synthesize,
    default_clock_osc = "clk_50mhz",
    default_reset = "design_reset_l" *)
module mkPSCRevBResetButtonNoPowerFaultMonitor (IgnitionletTarget);
    Parameters parameters = default_app_with_reset_button;
    parameters.invert_leds = True;
    parameters.system_power_fault_monitor_enable = False;

    (* hide *) IgnitionTargetIOWrapper _top <-
        mkIgnitionTargetIOAndResetWrapper(parameters);
    return asIgnitionletTarget(_top);
endmodule

endpackage
