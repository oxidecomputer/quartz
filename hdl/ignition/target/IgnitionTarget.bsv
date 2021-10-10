package IgnitionTarget;

export Transceiver(..);
export IgnitionTarget(..), mkIgnitionTarget;

import BuildVector::*;
import Vector::*;


//
// This package contains the top level interfaces and modules implementing the Ignition Target
// application.
//

interface Transceiver;
    method Action rx(Bit#(1) val);
    method Bit#(1) tx();
endinterface

interface IgnitionTarget;
    (* always_enabled *) method Action id(UInt#(6) val);
    (* always_enabled *) method Action status(Vector#(6, Bool) val);
    (* always_enabled *) method Vector#(3, Bool) cmd;

    interface PulseWire button_pressed;
    interface Transceiver aux0;
    interface Transceiver aux1;

    // External tick used to generate internal events such as the transmission of status
    // packets.
    interface PulseWire tick_1khz;
endinterface

module mkIgnitionTarget (IgnitionTarget);
    Reg#(Maybe#(UInt#(6))) system_type <- mkRegA(tagged Invalid);

    Reg#(Vector#(6, Bool)) status_cur <- mkRegU();
    Wire#(Vector#(6, Bool)) status_next <- mkWire();

    Reg#(Vector#(3, Bool)) cmd_cur <- mkRegA(vec(False, False, True));

    PulseWire button_pressed_ <- mkPulseWire();
    PulseWire tick_1khz_ <- mkPulseWire();

    (* fire_when_enabled *)
    rule do_handle_button_pressed (button_pressed_);
        let system_enable_next = !cmd_cur[0];
        let cmd_next = vec(system_enable_next, cmd_cur[1], !system_enable_next);
        cmd_cur <= cmd_next;
    endrule

    // System type can only be set once after application reset.
    method Action id(UInt#(6) val) if (system_type matches tagged Invalid);
        system_type <= tagged Valid val;
    endmethod

    method status = status_next._write;
    method cmd = cmd_cur._read;

    interface PulseWire button_pressed = button_pressed_;
    interface PulseWire tick_1khz = tick_1khz_;
endmodule

endpackage: IgnitionTarget
