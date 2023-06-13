package IgnitionControllerAndTargetBench;

import ConfigReg::*;
import Connectable::*;
import DefaultValue::*;
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
    // Target, transceiver and IO adapter.
    //
    Target target_ <- mkTarget(parameters.target);
    TargetTransceiver target_txr <- mkTargetTransceiver();

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
    Transceiver controller_txr <- mkTransceiver();

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
            tx_enable(controller_));

    Link target_to_controller_link <-
        mkLink(
            "Target->Controller",
            target_io.tx,
            controller_io.rx,
            parameters.invert_link_polarity,
            True);

    //
    // Bench timing.
    //
    Strobe#(10) tick <- mkLimitStrobe(1, tick_duration, 0);

    mkConnection(asIfc(tick), asIfc(target_.tick_1khz));
    mkConnection(asIfc(tick), asIfc(controller_.tick_1khz));
    mkFreeRunningStrobe(tick);

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
endmodule

endpackage
