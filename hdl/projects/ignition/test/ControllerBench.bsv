package ControllerBench;

import Connectable::*;
import StmtFSM::*;

import Strobe::*;
import TestUtils::*;

import BenchTransceiver::*;
import IgnitionController::*;
import IgnitionProtocol::*;
import IgnitionTransceiver::*;


interface ControllerBench;
    interface Controller controller;
    interface Link link;

    method Integer tick_duration();
    method UInt#(32) ticks_elapsed();
    method Action reset_ticks_elapsed();

    method Action await_tick();
    method Action await_ticks_elapsed(Integer n);

    method Action pet_watchdog();
endinterface

Integer tick_duration = 2**2;

module mkControllerBench
        #(Parameters parameters, Integer watchdog_timeout_in_ticks)
        (ControllerBench);
    (* hide *) Controller _controller <- mkController(parameters);
    BenchTransceiver txr <- mkBenchTransceiver();
    Strobe#(2) tick <- mkPowerTwoStrobe(1, 0);

    mkConnection(txr, _controller.txr);
    mkConnection(asIfc(tick), asIfc(_controller.tick_1khz));

    mkFreeRunningStrobe(tick);

    Reg#(UInt#(32)) ticks_elapsed_ <- mkReg(0);
    PulseWire reset_ticks_elapsed_ <- mkPulseWire();

    TestWatchdog wd <- mkTestWatchdog(tick_duration * watchdog_timeout_in_ticks);

    (* fire_when_enabled *)
    rule do_count_ticks (tick || reset_ticks_elapsed_);
        ticks_elapsed_ <= (reset_ticks_elapsed_ ? 0 : ticks_elapsed_ + 1);
    endrule

    interface IgnitionController controller = _controller;
    interface Link link = txr.bench;

    method ticks_elapsed = ticks_elapsed_;
    method reset_ticks_elapsed = reset_ticks_elapsed_.send;
    method tick_duration = tick_duration;

    method Action await_tick() = await(_controller.tick_1khz);
    method Action await_ticks_elapsed(Integer n) =
        await(ticks_elapsed_ >= fromInteger(tick_duration * n));

    method pet_watchdog = wd.send;
endmodule

function Integer bench_cycles(ControllerBench b, Integer n_ticks) =
    b.tick_duration * n_ticks;

endpackage
