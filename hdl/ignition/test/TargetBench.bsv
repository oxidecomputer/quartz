package TargetBench;

import ConfigReg::*;
import Connectable::*;
import StmtFSM::*;

import Strobe::*;
import TestUtils::*;

import BenchTransceiver::*;
import IgnitionProtocol::*;
import IgnitionTarget::*;
import IgnitionTestHelpers::*;
import IgnitionTransceiver::*;


interface TargetBench;
    interface Target target;
    interface Link link;
    method Action set_faults(SystemFaults faults);

    method Integer tick_duration();
    method UInt#(32) ticks_elapsed();
    method Action reset_ticks_elapsed();

    method Action await_tick();
    method Action await_ticks_elapsed(Integer n);
    method Action pet_watchdog();

    method Action await_system_power_request_complete();
    method Action await_system_power_off_complete();
    method Stmt assert_system_powering_on(LinkStatus expected_link0_status);
endinterface

Integer tick_duration = 2**2;

module mkTargetBench #(
        Parameters parameters,
        Integer watchdog_timeout_in_ticks)
            (TargetBench);
    (* hide *) Target _target <- mkTarget(parameters);
    BenchTargetTransceiver txr <- mkBenchTargetTransceiver();
    Strobe#(2) tick <- mkPowerTwoStrobe(1, 0);

    mkConnection(txr, _target.txr);
    mkConnection(asIfc(tick), asIfc(_target.tick_1khz));

    mkFreeRunningStrobe(tick);

    Reg#(UInt#(32)) ticks_elapsed_ <- mkReg(0);
    PulseWire reset_ticks_elapsed_ <- mkPulseWire();

    TestWatchdog wd <- mkTestWatchdog(tick_duration * watchdog_timeout_in_ticks);

    Reg#(SystemFaults) faults <- mkConfigReg(system_faults_none);

    (* fire_when_enabled *)
    rule do_set_system_type;
        _target.set_system_type(fromMaybe(0, parameters.system_type));
    endrule

    (* fire_when_enabled *)
    rule do_set_faults;
        _target.set_faults(faults);
    endrule

    (* fire_when_enabled *)
    rule do_count_ticks (tick || reset_ticks_elapsed_);
        ticks_elapsed_ <= (reset_ticks_elapsed_ ? 0 : ticks_elapsed_ + 1);
    endrule

    interface IgnitionTarget target = _target;
    interface Link link = txr.bench;

    method set_faults = faults._write;

    method ticks_elapsed = ticks_elapsed_;
    method reset_ticks_elapsed = reset_ticks_elapsed_.send;
    method tick_duration = tick_duration;

    method Action await_tick() = await(tick);
    method Action await_ticks_elapsed(Integer n) =
        await(ticks_elapsed_ >= fromInteger(tick_duration * n));
    method pet_watchdog = wd.send;

    method Action await_system_power_request_complete() =
        await(!_target.system_power_request_in_progress);

    method Action await_system_power_off_complete() =
        await(!_target.system_power_off_in_progress);

    method Stmt assert_system_powering_on(LinkStatus expected_link0_status) =
        seq
            assert_get_eq(
                tpl_1(txr.bench.message),
                message_status_system_powering_on,
                "expected system power on request in progress Status message");

            assert_eq(_target.system_power, On, "expected system power on");

            // If link 0 was connected at the same time as the Target is
            // initializing, expect an additional Status update with the link
            // status changing.
            if (expected_link0_status != link_status_disconnected) seq
                assert_get_eq(
                    tpl_1(txr.bench.message),
                    message_status_with_link0_status(
                        message_status_system_powering_on,
                        expected_link0_status),
                    "expected link 0 Status update");
            endseq

            // Finally, expect the system power on request to be completed.
            assert_get_eq(
                tpl_1(txr.bench.message),
                message_status_with_link0_status(
                    message_status_system_powered_on,
                    expected_link0_status),
                "expected system powered on Status message");
        endseq;
endmodule

endpackage
