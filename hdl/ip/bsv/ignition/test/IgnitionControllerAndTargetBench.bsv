package IgnitionControllerAndTargetBench;

import ConfigReg::*;
import Connectable::*;
import DefaultValue::*;
import DReg::*;
import GetPut::*;
import Probe::*;
import StmtFSM::*;
import Vector::*;

import BitSampling::*;
import Strobe::*;
import SerialIO::*;
import TestUtils::*;

import IgnitionController::*;
import IgnitionProtocol::*;
import IgnitionTarget::*;
import IgnitionTransceiver::*;


typedef enum {
    Disconnected,
    Connected
} LinkState deriving (Bits, Eq, FShow);

interface Link;
    method Action set_state(LinkState state);
endinterface

interface IgnitionControllerAndTargetBench;
    interface Target target;
    interface Controller controller;
    interface Link controller_to_target;
    interface Link target_to_controller;

    method Action await_tick();
    method Action pet_watchdog();
    method Action set_target_system_faults(SystemFaults faults);

    method Bool controller_receiver_locked_timeout();
    interface Vector#(2, Bool) target_receiver_locked_timeout;

    method Bit#(1) controller_to_target_status_led();
    method Bit#(1) target_to_controller_status_led();
endinterface

typedef struct {
    IgnitionTarget::Parameters target;
    IgnitionController::Parameters controller;
    Bool invert_link_polarity;
} Parameters;

module mkLink #(
        String name,
        Bit#(1) tx,
        function Action rx(Bit#(1) b),
        Bool invert_link_polarity,
        Bool tx_enable)
            (Link);
    Reg#(LinkState) state <- mkReg(Disconnected);
    Probe#(Bit#(1)) tap <- mkProbe();

    (* fire_when_enabled *)
    rule do_transmit;
        let b = state == Connected && tx_enable ? tx : 0;
        let b_ = invert_link_polarity ? ~b : b;

        tap <= b_;
        rx(b_);
    endrule

    method Action set_state(LinkState state_);
        case (tuple2(state, state_)) matches
            {Disconnected, Connected}: begin
                state <= Connected;
                $display("%5t [Bench] %s connected", $time, name);
            end

            {Connected, Disconnected}: begin
                state <= Disconnected;
                $display("%5t [Bench] %s disconnected", $time, name);
            end
        endcase
    endmethod
endmodule

Integer tick_duration = 1000;

module mkIgnitionControllerAndTargetBench #(
        Parameters parameters,
        Integer watchdog_timeout_in_ticks)
            (IgnitionControllerAndTargetBench);
    //
    // Bench tick.
    //
    Strobe#(10) tick <- mkLimitStrobe(1, tick_duration, 0);
    mkFreeRunningStrobe(tick);

    //
    // Target, transceiver and IO adapter.
    //
    Target target_ <- mkTarget(parameters.target);
    TargetTransceiver target_txr <- mkTargetTransceiver(True);

    mkConnection(asIfc(tick), asIfc(target_.tick_1khz));

    Strobe#(3) target_tx_strobe <- mkLimitStrobe(1, 5, 0);
    SampledSerialIO#(5) target_io <-
        mkSampledSerialIOWithTxStrobe(
            target_tx_strobe,
            tuple2(target_txr.to_link, target_txr.from_link[0]));

    mkConnection(target_txr, target_.txr);
    mkFreeRunningStrobe(target_tx_strobe);

    //
    // Controller, transceiver and IO adapter.
    //
    Controller controller_ <- mkController(parameters.controller);
    Transceiver controller_txr <- mkTransceiver(tick);

    mkConnection(asIfc(tick), asIfc(controller_.tick_1khz));

    // Set this TX strobe ~180 degrees out of phase from Target TX.
    Strobe#(3) controller_tx_strobe <- mkLimitStrobe(1, 5, 3);
    SampledSerialIO#(5) controller_io <-
        mkSampledSerialIOWithTxStrobe(
            controller_tx_strobe,
            controller_txr.serial);

    mkConnection(controller_txr, controller_.txr);
    mkFreeRunningStrobe(controller_tx_strobe);

    // Connect the transceivers.
    Link controller_to_target_link <-
        mkLink(
            "Controller->Target",
            controller_io.tx,
            target_io.rx,
            parameters.invert_link_polarity,
            // Mimic the hardware implementation where the output buffer of the
            // Controller transmitter is only enabled if a Target is present or
            // the `always_transmit` bit has been set.
            tx_enabled(controller_));

    Link target_to_controller_link <-
        mkLink(
            "Target->Controller",
            target_io.tx,
            controller_io.rx,
            parameters.invert_link_polarity,
            True);

    // Link status "LEDs".
    ReadOnly#(Bit#(1)) controller_to_target_link_status_led <-
        mkLinkStatusLED(
            target_.controller0_present,
            target_txr.status[0],
            target_txr.receiver_locked_timeout[0],
            False);

    ReadOnly#(Bit#(1)) target_to_controller_link_status_led <-
        mkLinkStatusLED(
            controller_.status.target_present,
            controller_txr.status,
            controller_txr.receiver_locked_timeout,
            False);

    // Generate single cycle timeout strobes on the positive edge for both
    // receivers.
    Reg#(Bool) past_controller_receiver_locked_timeout <- mkReg(False);
    Reg#(Bool) controller_receiver_locked_timeout_ <- mkDReg(False);

    Vector#(2, Reg#(Bool)) past_target_receiver_locked_timeout <- replicateM(mkReg(False));
    Vector#(2, Reg#(Bool)) target_receiver_locked_timeout_ <- replicateM(mkDReg(False));

    (* fire_when_enabled *)
    rule do_past_receiver_locked_timeout;
        past_controller_receiver_locked_timeout <=
            controller_txr.receiver_locked_timeout;

        controller_receiver_locked_timeout_ <=
            !past_controller_receiver_locked_timeout &&
                controller_txr.receiver_locked_timeout;

        for (Integer i = 0; i < 2; i = i + 1) begin
            past_target_receiver_locked_timeout[i] <=
                target_txr.receiver_locked_timeout[i];

            target_receiver_locked_timeout_[i] <=
                !past_target_receiver_locked_timeout[i] &&
                    target_txr.receiver_locked_timeout[i];
        end
    endrule

    (* fire_when_enabled *)
    rule do_display_tick (tick);
        $display("%5t [Bench] Tick", $time);
    endrule

    TestWatchdog wd <-
        mkTestWatchdog(tick_duration * watchdog_timeout_in_ticks);

    (* fire_when_enabled *)
    rule do_set_system_type;
        target_.set_system_type(fromMaybe(0, parameters.target.system_type));
    endrule

    ConfigReg#(SystemFaults) target_faults <- mkReg(defaultValue);

    (* fire_when_enabled *)
    rule do_set_faults;
        target_.set_faults(target_faults);
    endrule

    interface Target target = target_;
    interface Controller controller = controller_;
    interface Link controller_to_target = controller_to_target_link;
    interface Link target_to_controller = target_to_controller_link;

    method await_tick = await(tick);
    method pet_watchdog = wd.send;
    method set_target_system_faults = target_faults._write;

    method controller_receiver_locked_timeout =
            controller_receiver_locked_timeout_;
    interface Vector target_receiver_locked_timeout =
            readVReg(target_receiver_locked_timeout_);

    method controller_to_target_status_led =
            controller_to_target_link_status_led;
    method target_to_controller_status_led =
            target_to_controller_link_status_led;
endmodule

endpackage
