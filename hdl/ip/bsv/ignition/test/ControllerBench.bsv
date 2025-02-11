package ControllerBench;

import ClientServer::*;
import Connectable::*;
import GetPut::*;
import StmtFSM::*;

import Strobe::*;
import TestUtils::*;

import BenchTransceiver::*;
import IgnitionController::*;
import IgnitionProtocol::*;
import IgnitionReceiver::*;
import IgnitionTestHelpers::*;
import IgnitionTransceiver::*;
import IgnitionTransmitter::*;


interface ControllerBench;
    interface Controller#(4) controller;

    method Integer tick_period();
    method UInt#(32) ticks_elapsed();
    method Action reset_ticks_elapsed();
    method Action await_tick();
    method Action await_ticks_elapsed(Integer n);

    method Stmt clear_counter(ControllerId#(4) controller, CounterId counter);
    method Stmt receive_status_message(
            ControllerId#(4) controller,
            Message messge);

    method Action assert_target_present(ControllerId#(4) id, String msg);
    method Stmt assert_counter_eq(
            ControllerId#(4) controller,
            CounterId counter,
            UInt#(8) expected_count,
            String msg);
    method Action assert_controller_message_eq(
            ControllerId#(4) controller,
            ControllerMessage message,
            String msg);
endinterface

//Integer tick_duration = 2**2;

module mkControllerBench
        #(Parameters parameters, Integer watchdog_timeout_in_ticks)
        (ControllerBench);
    (* hide *) Controller#(4) _controller <- mkController(parameters, True);

    Reg#(UInt#(10)) bench_ticks_elapsed <- mkReg(0);
    Reg#(UInt#(32)) controller_ticks_elapsed <- mkReg(0);

    PulseWire controller_tick <- mkPulseWire();
    PulseWire reset_ticks_elapsed_ <- mkPulseWire();

    (* fire_when_enabled *)
    rule do_tick;
        _controller.tick_1mhz();

        let controller_tick_ =
                bench_ticks_elapsed ==
                fromInteger(parameters.tick_period - 1);

        bench_ticks_elapsed <= controller_tick_ ? 0 : bench_ticks_elapsed + 1;

        if (reset_ticks_elapsed_)
            controller_ticks_elapsed <= 0;
        else if (controller_tick_) begin
            controller_tick.send();
            controller_ticks_elapsed <= controller_ticks_elapsed + 1;
        end
    endrule

    TestWatchdog wd <- mkTestWatchdog(
            parameters.tick_period *
            watchdog_timeout_in_ticks);

    interface Controller controller = _controller;

    method tick_period = parameters.tick_period;
    method ticks_elapsed = controller_ticks_elapsed;
    method reset_ticks_elapsed = reset_ticks_elapsed_.send;
    method Action await_tick() = await(controller_tick);
    method Action await_ticks_elapsed(Integer n) =
            await(controller_ticks_elapsed >= fromInteger(n));

    method Stmt clear_counter(
            ControllerId#(4) controller_,
            CounterId counter_) =
        seq
            _controller.counters.request.put(
                    CounterAddress {
                        controller: controller_,
                        counter: counter_});
            assert_get_any(_controller.counters.response);
        endseq;

    method Stmt receive_status_message(
            ControllerId#(4) controller_,
            Message message) =
                controller_receive_status_message(
                        _controller,
                        controller_,
                        message);

    method Action assert_target_present(ControllerId#(4) id, String msg) =
            assert_true(_controller.presence_summary[id], msg);

    method Stmt assert_counter_eq(
            ControllerId#(4) controller_,
            CounterId counter_,
            UInt#(8) expected_count,
            String msg) =
        seq
            _controller.counters.request.put(
                    CounterAddress {
                        controller: controller_,
                        counter: counter_});
            assert_get_eq(_controller.counters.response, expected_count, msg);
        endseq;

    method Action assert_controller_message_eq(
            ControllerId#(4) controller_,
            ControllerMessage message,
            String msg) =
        assert_get_eq(
            _controller.txr.tx,
            TransmitterEvent {
                id: controller_,
                ev: tagged Message message},
            msg);
endmodule

function Integer bench_cycles(ControllerBench b, Integer n_ticks) =
    b.tick_period * n_ticks;

endpackage
