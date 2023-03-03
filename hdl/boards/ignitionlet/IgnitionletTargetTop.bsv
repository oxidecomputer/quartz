package IgnitionletTargetTop;

import DefaultValue::*;
import Vector::*;

import IgnitionTarget::*;
import IgnitionTargetWrapper::*;
import IgnitionTargetTop::*;


(* default_clock_osc = "clk_50mhz", no_default_reset *)
module mkIgnitionletTargetWithResetButton (IgnitionTargetTopRevA);
    let parameters = default_app_with_reset_button;
    parameters.external_reset = False;
    parameters.system_type = tagged Valid 5;

    (* hide *) IgnitionTargetTopWithDebug _top <-
        mkIgnitionTargetIOAndResetWrapper(parameters);
    return asIgnitionTargetTopRevA(_top);
endmodule

(* default_clock_osc = "clk_50mhz", no_default_reset *)
module mkIgnitionletTargetWithPowerButton (IgnitionTargetTopRevA);
    let parameters = default_app_with_power_button;
    parameters.external_reset = False;
    parameters.system_type = tagged Valid 5;

    (* hide *) IgnitionTargetTopWithDebug _top <-
        mkIgnitionTargetIOAndResetWrapper(parameters);
    return asIgnitionTargetTopRevA(_top);
endmodule

(* default_clock_osc = "clk_50mhz", no_default_reset *)
module mkIgnitionletTargetDebug (IgnitionTargetTopWithDebug);
    let parameters = default_app_with_reset_button;
    parameters.external_reset = False;
    parameters.system_type = tagged Valid 5;
    parameters.mirror_link0_rx_as_link1_tx = True;

    (* hide *) IgnitionTargetTopWithDebug _top <-
        mkIgnitionTargetIOAndResetWrapper(parameters);

    (* fire_when_enabled *)
    rule do_set_flt;
        _top.flt(unpack('1)); // flt bits get inverted downstream.
    endrule

    method system_power_enable = _top.system_power_enable;
    method btn = _top.btn;
    method led = _top.led;
    method debug = _top.debug;
    interface DifferentialTransceiver aux0 = _top.aux0;
    interface DifferentialTransceiver aux1 = _top.aux1;
endmodule

endpackage
