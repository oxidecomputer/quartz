package IgnitionTarget;

export Transceiver(..), Commands(..);
export IgnitionTarget(..), IgnitionTargetParameters(..), mkIgnitionTarget;
export IgnitionTargetBench(..), mkIgnitionTargetBench;

import Connectable::*;
import DefaultValue::*;
import StmtFSM::*;
import Vector::*;

import Strobe::*;


//
// This package contains the top level interfaces and modules implementing the Ignition Target
// application.
//

typedef struct {
    Bool cmd2;
    Bool cmd1;
    Bool system_power_enable;
} Commands deriving (Bits, Eq, FShow);

interface Transceiver;
    method Action rx(Bit#(1) val);
    method Bit#(1) tx();
endinterface

interface IgnitionTarget;
    (* always_enabled *) method Action id(UInt#(6) val);
    (* always_enabled *) method Action status(Vector#(6, Bool) val);
    (* always_enabled *) method Commands commands();
    (* always_ready *) method Action button_event(Bool pressed);

    interface Transceiver aux0;
    interface Transceiver aux1;

    // External tick used to generate internal events such as the transmission of status
    // packets.
    interface PulseWire tick_1khz;
endinterface

// The behavior of an IgnitionTarget application can be tweaked. This is
// primarily useful for test benches.
typedef struct {
    Integer system_reset_min_duration;
    Integer system_reset_cool_down;
} IgnitionTargetParameters;

instance DefaultValue#(IgnitionTargetParameters);
    defaultValue = IgnitionTargetParameters{
        system_reset_min_duration: 2000,    // 2 seconds.
        system_reset_cool_down: 1000};      // 1 seconds.
endinstance

module mkIgnitionTarget #(IgnitionTargetParameters conf) (IgnitionTarget);
    Reg#(Maybe#(UInt#(6))) system_type <- mkRegA(tagged Invalid);
    Reg#(Vector#(6, Bool)) status_r <- mkRegU();

    // Default command bits. This automatically powers on the system upon (power
    // on) reset, with CMD1 showing Ignition status and CMD2 tracking power
    // enabled status.
    let commands_default = Commands{
            system_power_enable: True,
            cmd1: False,
            cmd2: False};
    Reg#(Commands) commands_r <- mkRegA(commands_default);

    Reg#(UInt#(12)) system_reset_ticks_remaining <- mkRegU();

    // Events
    PulseWire button_pressed <- mkPulseWire();
    PulseWire button_released <- mkPulseWire();
    PulseWire tick <- mkPulseWire();

    // Helpers
    function Action set_system_power_enabled(Bool enabled) =
        action
            commands_r <= Commands{
                system_power_enable: enabled,
                cmd1: commands_default.cmd1,
                cmd2: !enabled}; // LED tracking enabled status is inverted.
        endaction;

    function Stmt await_system_reset_ticks_remaining_zero() =
        seq
            while (system_reset_ticks_remaining != 0) seq
                action
                    if (tick) begin
                        system_reset_ticks_remaining <=
                            system_reset_ticks_remaining - 1;
                    end
                endaction
            endseq
        endseq;

    // A FSM implementing a controlled system reset by powering down for a given
    // number of ticks followed by a short lock out to guard against rapid
    // repeat of the sequence.
    FSM system_reset_seq <-
        mkFSM(
            seq
                action
                    set_system_power_enabled(False);
                    // This sequence changes state on a tick. In order to avoid
                    // cutting this duration short by a tick, add one.
                    system_reset_ticks_remaining <=
                        fromInteger(conf.system_reset_min_duration + 1);
                endaction
                // Wait for both the button to be releases and the delay timer
                // to reach zero.
                par
                    await(button_released);
                    await_system_reset_ticks_remaining_zero();
                endpar
                action
                    set_system_power_enabled(True);
                    system_reset_ticks_remaining <=
                        fromInteger(conf.system_reset_cool_down + 1);
                endaction
                await_system_reset_ticks_remaining_zero();
            endseq);

    // Initiate a system reset if the button is pressed and no reset sequence is
    // in progress.
    (* fire_when_enabled *)
    rule do_start_system_reset (button_pressed);
        system_reset_seq.start();
    endrule

    // System type can only be set once after application reset.
    method Action id(UInt#(6) val) if (system_type matches tagged Invalid);
        system_type <= tagged Valid val;
    endmethod

    method status = status_r._write;

    method Action button_event(Bool pressed);
        if (pressed)
            button_pressed.send();
        else
            button_released.send();
    endmethod

    method commands = commands_r;

    interface PulseWire tick_1khz = tick;
endmodule

interface IgnitionTargetBench;
    interface IgnitionTarget target;
    method UInt#(32) ticks_elapsed();
    method Action reset_ticks_elapsed();

    method Bool system_powered_on();
    method Bool system_powered_off();
    method Action press_button();
    method Action release_button();
endinterface

module mkIgnitionTargetBench #(IgnitionTargetParameters conf, UInt#(6) id) (IgnitionTargetBench);
    IgnitionTarget _target <- mkIgnitionTarget(conf);

    Strobe#(2) tick <- mkStrobe(1, 0);
    Reg#(UInt#(32)) ticks_elapsed_ <- mkReg(0);
    PulseWire should_reset_ticks_elapsed <- mkPulseWire();

    Reg#(Bool) system_powered_on_prev <- mkReg(True);

    mkConnection(_target.id, id);
    mkConnection(asIfc(tick), asIfc(_target.tick_1khz));

    (* no_implicit_conditions, fire_when_enabled *)
    rule do_tick;
        tick.send();
    endrule

    (* no_implicit_conditions, fire_when_enabled *)
    rule do_monitor_system_power_state;
        let system_powered_on = _target.commands.system_power_enable;
        system_powered_on_prev <= system_powered_on;

        if (system_powered_on != system_powered_on_prev)
            if (system_powered_on)
                $display("System powered on");
            else
                $display("System powered off");
    endrule

    (* fire_when_enabled *)
    rule do_count_ticks (tick || should_reset_ticks_elapsed);
        ticks_elapsed_ <= (should_reset_ticks_elapsed ? 0 : ticks_elapsed_ + 1);
    endrule

    interface IgnitionTarget target = _target;

    method ticks_elapsed = ticks_elapsed_;
    method reset_ticks_elapsed = should_reset_ticks_elapsed.send;

    method system_powered_on = _target.commands.system_power_enable;
    method system_powered_off = !_target.commands.system_power_enable;

    method Action press_button();
        $display("Button pressed");
        _target.button_event(True);
    endmethod

    method Action release_button();
        $display("Button released");
        _target.button_event(False);
    endmethod
endmodule

endpackage: IgnitionTarget
