package IgnitionTarget;

export Transceiver(..), Commands(..);

export ButtonBehavior(..);
export Parameters(..);
export default_app_with_power_button;
export default_app_with_button_as_reset;

export IgnitionTarget(..), mkIgnitionTarget;
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

typedef union tagged {
    struct {
        Integer min_duration;
        Integer cool_down;
    } ResetButton;
    struct {
        Integer cool_down;
    } PowerButton;
} ButtonBehavior;

// The behavior of an IgnitionTarget application can be tweaked. This is
// primarily useful for test benches.
typedef struct {
    ButtonBehavior button_behavior;
    Bool invert_cmd_bits;
} Parameters;

Parameters default_app_with_button_as_reset =
    Parameters{
        button_behavior:
            tagged ResetButton {
                min_duration: 2000, // 2s if app tick at 1KHz.
                cool_down: 1000},   // 1s if app tick at 1KHz.
        invert_cmd_bits: False};

Parameters default_app_with_power_button =
    Parameters{
        button_behavior:
            tagged PowerButton {
                cool_down: 50},     // 50 ms if app tick at 1KHz.
        invert_cmd_bits: False};

instance DefaultValue#(Parameters);
    defaultValue = default_app_with_button_as_reset;
endinstance

module mkIgnitionTarget #(Parameters parameters) (IgnitionTarget);
    Reg#(Maybe#(UInt#(6))) system_type <- mkRegA(tagged Invalid);
    Reg#(Vector#(6, Bool)) status_r <- mkRegU();

    // Default command bits.
    let commands_default =
        case (parameters.button_behavior) matches
            tagged ResetButton .*:
                // Powers on the system upon (power on) reset, with CMD1 showing
                // Ignition reset status and CMD2 tracking power enabled status.
                Commands {
                    system_power_enable: True,
                    cmd1: parameters.invert_cmd_bits ? False : True,
                    cmd2: parameters.invert_cmd_bits ? False : True};
            tagged PowerButton .*:
                // Leaves system power off upon (power on) reset, waiting for
                // operator button input before power on. CMD1 shows Ignition
                // reset status and CMD2 tracks power enabled status.
                Commands {
                    system_power_enable: False,
                    cmd1: parameters.invert_cmd_bits ? False : True,
                    cmd2: parameters.invert_cmd_bits ? True : False};
        endcase;

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
                cmd2: parameters.invert_cmd_bits ? !enabled : enabled};
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
    case (parameters.button_behavior) matches
        tagged ResetButton .reset_button_parameters: begin
            FSM system_reset_seq <-
                mkFSM(
                    seq
                        action
                            set_system_power_enabled(False);
                            // This sequence changes state on a tick. In order to avoid
                            // cutting this duration short by a tick, add one.
                            system_reset_ticks_remaining <=
                                fromInteger(reset_button_parameters.min_duration + 1);
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
                                fromInteger(reset_button_parameters.cool_down + 1);
                        endaction
                        await_system_reset_ticks_remaining_zero();
                    endseq);

            // Initiate a system reset if the button is pressed and no reset sequence is
            // in progress.
            (* fire_when_enabled *)
            rule do_start_system_reset (button_pressed);
                system_reset_seq.start();
            endrule
        end

        tagged PowerButton .power_button_parameters: begin
            FSM system_power_on_or_off_seq <-
                mkFSM(
                    seq
                        action
                            set_system_power_enabled(!commands_r.system_power_enable);
                            system_reset_ticks_remaining <=
                                fromInteger(power_button_parameters.cool_down + 1);
                        endaction
                        await_system_reset_ticks_remaining_zero();
                    endseq);

            // Initiate a system reset if the button is pressed and no reset sequence is
            // in progress.
            (* fire_when_enabled *)
            rule do_power_system_on_or_off (button_pressed);
                system_power_on_or_off_seq.start();
            endrule
        end
    endcase


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

module mkIgnitionTargetBench #(Parameters parameters, UInt#(6) id) (IgnitionTargetBench);
    IgnitionTarget _target <- mkIgnitionTarget(parameters);

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
