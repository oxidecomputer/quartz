package TargetTests;

import Assert::*;
import ConfigReg::*;
import Connectable::*;
import GetPut::*;
import StmtFSM::*;

import TestUtils::*;

import BenchTransceiver::*;
import IgnitionProtocol::*;
import IgnitionTarget::*;
import IgnitionTestHelpers::*;
import IgnitionTransceiver::*;
import TargetBench::*;


Parameters parameters =
    Parameters {
        external_reset: True,
        invert_leds: False,
        mirror_link0_rx_as_link1_tx: False,
        system_type: tagged Valid target_system_type,
        button_behavior: ResetButton,
        // Shorten the cool down duration to avoid long sim times.
        system_power_toggle_cool_down: 15,
        system_power_fault_monitor_enable: True,
        system_power_fault_monitor_start_delay: 10,
        protocol: defaultValue};

Integer test_timeout_25_ticks = 25;

(* synthesize *)
module mkPeriodicStatusMessagesTest (Empty);
    TargetBench bench <- mkTargetBench(
        parameters,
        4 * parameters.protocol.status_interval);
    let rx = tpl_1(bench.link.message);

    mkAutoFSM(seq
        bench.link.set_connected(True, False); // Receive from Target only.
        bench.assert_system_powering_on(link_status_disconnected);

        // Reset the ticks elapsed counter to determine the interval between
        // Status messages.
        action
            bench.await_tick();
            bench.reset_ticks_elapsed();
        endaction

        repeat(3) action // This only fires twice, still not sure why.
            // Expect the next Status message ..
            assert_get_eq(rx,
                message_status_system_powered_on,
                "expected Status message");

            // .. and test the interval between it and the previous message.
            // Note that the expired timer for Hello messages fires one tick
            // early, to allow for some slack between send/receive and the
            // timout on the Target side.
            assert_eq(
                bench.ticks_elapsed,
                fromInteger(parameters.protocol.status_interval - 1),
                "expected the configured number of ticks between Status messages");

            bench.reset_ticks_elapsed();
        endaction
    endseq);
endmodule

(* synthesize *)
module mkReportReceiverStatusTest (Empty);
    TargetBench bench <- mkTargetBench(parameters, test_timeout_25_ticks);
    let rx = tpl_1(bench.link.message);

    mkAutoFSM(seq
        bench.link.set_connected(True, False); // Receive from Target only.
        bench.assert_system_powering_on(link_status_disconnected);

        // Connect the receiver and expect a Status update indicating the link
        // connected.
        bench.link.set_connected(True, True);
        assert_get_eq(rx,
            message_status_system_powered_on_link0_connected,
            "expected link0 connected");

        // Disconnect the receiver and expect the status to change accordingly.
        bench.link.set_connected(True, False);
        assert_get_eq(rx,
            message_status_system_powered_on,
            "expected no link connected");
    endseq);
endmodule

(* synthesize *)
module mkControllerPresentTest (Empty);
    TargetBench bench <- mkTargetBench(
        parameters,
        4 * parameters.protocol.hello_interval);
    let rx = tpl_1(bench.link.message);
    let tx = tpl_2(bench.link.message);

    Reg#(SystemStatus) system_status <- mkReg(defaultValue);

    mkAutoFSM(seq
        bench.link.set_connected(True, True);
        bench.assert_system_powering_on(link_status_connected);

        // Send Hello's.
        await(bench.target.tick_1khz);
        repeat(4) seq
            await(bench.target.tick_1khz);
            tx.put(tagged Hello);
        endseq

        await(bench.target.tick_1khz);
        assert_get_eq(rx,
            message_status_system_powered_on_controller0_present,
            "expected controller present on link0");

        // Stop sending Hello's and wait for controller present to time out.
        await_target_system_status(rx, system_status, system_status_system_power_enabled);
        assert_false(
            system_status.controller0_present,
            "expected controller not present");
    endseq);
endmodule

(* synthesize *)
module mkReportLinkEventsTest (Empty);
    TargetBench bench <- mkTargetBench(parameters, test_timeout_25_ticks);
    let rx = tpl_1(bench.link.message);
    let link_events =
        link_events_decoding_error |
        link_events_ordered_set_invalid;

    mkAutoFSM(seq
        bench.link.set_connected(True, False);
        bench.assert_system_powering_on(link_status_disconnected);

        bench.link.set_events(link_events);
        assert_get_eq(rx,
            message_status_with_link0_events(
                message_status_system_powered_on,
                link_events),
            "expected link 0 events set");
    endseq);
endmodule

(* synthesize *)
module mkReportLinkEventsMultipleOccurencesTest (Empty);
    TargetBench bench <- mkTargetBench(parameters, test_timeout_25_ticks);
    let rx = tpl_1(bench.link.message);

    mkAutoFSM(seq
        bench.link.set_connected(True, False);
        bench.assert_system_powering_on(link_status_disconnected);

        bench.link.set_events(link_events_decoding_error);
        assert_get_eq(
            rx,
            message_status_with_link0_events(
                message_status_system_powered_on,
                link_events_decoding_error),
            "expected link 0 decoding error");

        bench.link.set_events(link_events_decoding_error);
        assert_get_eq(
            rx,
            message_status_with_link0_events(
                message_status_system_powered_on,
                link_events_decoding_error),
            "expected link 0 decoding error");

        bench.link.set_events(link_events_decoding_error);
        assert_get_eq(
            rx,
            message_status_with_link0_events(
                message_status_system_powered_on,
                link_events_decoding_error),
            "expected link 0 decoding error");
    endseq);
endmodule

(* synthesize *)
module mkReportFaultsTest (Empty);
    // Disable the system power fault monitor to avoid the additional Status
    // messages because a fault is triggered.
    Parameters parameters_ = parameters;
    parameters_.system_power_fault_monitor_enable = False;

    TargetBench bench <- mkTargetBench(parameters_, test_timeout_25_ticks);
    let rx = tpl_1(bench.link.message);
    let faults =
            system_faults_power_a2 |
            system_faults_reserved1 |
            system_faults_sp;

    mkAutoFSM(seq
        bench.link.set_connected(True, False);
        bench.assert_system_powering_on(link_status_disconnected);

        bench.set_faults(faults);
        assert_get_eq(
            rx,
            message_status_with_system_faults(
                message_status_system_powered_on, faults),
            "expected power_a2, reserved1 and rot fault bits set");
    endseq);
endmodule

(* synthesize *)
module mkSystemPowerOnRequestTest (Empty);
    // Set power button behavior instead of reset button, to start the system
    // with power disabled.
    Parameters parameters_ = parameters;
    parameters_.button_behavior = PowerButton;

    TargetBench bench <- mkTargetBench(
        parameters_,
        2 * parameters_.system_power_toggle_cool_down);
    let rx = tpl_1(bench.link.message);
    let tx = tpl_2(bench.link.message);

    Reg#(SystemStatus) target_system_status <- mkReg(defaultValue);

    mkAutoFSM(seq
        assert_eq(bench.target.system_power, Off, "expected system powered off");

        // Connect the link, send Hello's and wait for the controller to be
        // marked present.
        bench.link.set_connected(True, True);
        repeat(3) tx.put(tagged Hello);
        await_target_system_status(
            rx,
            target_system_status,
            system_status_system_powered_off_controller0_present);

        // Send a power on request and wait for confirmation.
        tx.put(tagged Request SystemPowerOn);

        action
            let m <- rx.get;

            assert_true(
                m.Status.system_status.system_power_enabled,
                "expected system power enabled");
            assert_eq(
                m.Status.request_status,
                request_status_power_on_in_progress,
                "expected power on in progress");
            assert_eq(
                bench.target.system_power, On,
                "expected system power on");
        endaction

        assert_get_eq(
            rx,
            message_status_system_powered_on_controller0_present,
            "expected power on request bit cleared");
        assert_eq(
            bench.target.system_power, On,
            "expected system power still on");
    endseq);
endmodule

(* synthesize *)
module mkSystemPowerOffRequestTest (Empty);
    TargetBench bench <- mkTargetBench(
        parameters,
        3 * parameters.system_power_toggle_cool_down);
    let rx = tpl_1(bench.link.message);
    let tx = tpl_2(bench.link.message);

    Reg#(SystemStatus) target_system_status <- mkReg(defaultValue);

    mkAutoFSM(seq
        bench.link.set_connected(True, True);
        bench.await_system_power_request_complete();

        // Send Hello's and wait for the controller to be marked present.
        repeat(3) tx.put(tagged Hello);
        await_target_system_status(
            rx,
            target_system_status,
            system_status_system_powered_on_controller0_present);

        // Send a power off request and wait for confirmation.
        tx.put(tagged Request SystemPowerOff);

        action
            let m <- rx.get;

            assert_false(
                m.Status.system_status.system_power_enabled,
                "expected system power disabled");
            assert_eq(
                m.Status.request_status,
                request_status_power_off_in_progress,
                "expected power off in progress");
            assert_eq(
                bench.target.system_power, Off,
                "expected system power off");
        endaction

        assert_get_eq(
            rx,
            message_status_system_powered_off_controller0_present,
            "expected power off request bit cleared");
        assert_eq(
            bench.target.system_power, Off,
            "expected system power still off");
    endseq);
endmodule

(* synthesize *)
module mkSystemResetRequestTest (Empty);
    TargetBench bench <- mkTargetBench(
        parameters,
        4 * parameters.system_power_toggle_cool_down);
    let rx = tpl_1(bench.link.message);
    let tx = tpl_2(bench.link.message);

    Reg#(SystemStatus) target_system_status <- mkReg(defaultValue);

    mkAutoFSM(seq
        bench.link.set_connected(True, True);
        bench.await_system_power_request_complete();

        // Send Hello's and wait for the controller to be marked present.
        repeat(3) tx.put(tagged Hello);
        await_target_system_status(
            rx,
            target_system_status,
            system_status_system_powered_on_controller0_present);

        // Send a power off request and wait for confirmation.
        tx.put(tagged Request SystemReset);

        // Expect a Status update indicating the system is powered off and a
        // reset is in progress.
        action
            let m <- rx.get;

            assert_true(
                m.Status.request_status.reset_in_progress,
                "expected reset in progres bit set");
            assert_true(
                m.Status.request_status.power_off_in_progress,
                "expected power off in progress bit set");
            assert_eq(
                bench.target.system_power, Off,
                "expected system power off");
            assert_false(
                m.Status.system_status.system_power_enabled,
                "expected system power disabled");
        endaction

        // Expect a Status update indicating the system is powered on and a
        // reset is in progress.
        action
            let m <- rx.get;

            assert_true(
                m.Status.request_status.reset_in_progress,
                "expected reset in progres bit set");
            assert_true(
                m.Status.request_status.power_on_in_progress,
                "expected power on in progress bit set");
            assert_eq(
                bench.target.system_power, On,
                "expected system power on");
            assert_true(
                m.Status.system_status.system_power_enabled,
                "expected system power enabled");
        endaction

        assert_get_eq(
            rx,
            message_status_system_powered_on_controller0_present,
            "expected request status bits cleared");
        assert_eq(
            bench.target.system_power, On,
            "expected system power still on");
    endseq);
endmodule

(* synthesize *)
module mkSystemResetShortButtonPressTest (Empty);
    TargetBench bench <- mkTargetBench(
        parameters,
        4 * parameters.system_power_toggle_cool_down);

    mkAutoFSM(seq
        assert_eq(
            parameters.button_behavior,
            ResetButton,
            "expected Target configured with reset button");
        // Wait for the initial system power on request to complete.
        bench.await_system_power_request_complete();
        assert_eq(bench.target.system_power, On, "expected system power on");

        // Press the button and assert the system powered off.
        bench.target.button_event(True);
        assert_eq(
            bench.target.system_power, Off,
            "expected system power off");

        // Reset the ticks counter on the next tick.
        action
            bench.await_tick();
            bench.reset_ticks_elapsed();
        endaction

        // Release the button on tick into the power off sequence.
        bench.target.button_event(False);

        // Wait for system power on and confirm the minimum reset duration.
        await(bench.target.system_power == On);
        assert_eq(
            bench.ticks_elapsed,
            fromInteger(parameters.system_power_toggle_cool_down),
            "expected system reset equal to system_power_toggle_cool_down");

        bench.await_system_power_request_complete();
    endseq);
endmodule

(* synthesize *)
module mkSystemResetLongButtonPressTest (Empty);
    TargetBench bench <- mkTargetBench(
        parameters,
        4 * parameters.system_power_toggle_cool_down);

    mkAutoFSM(seq
        assert_eq(
            parameters.button_behavior,
            ResetButton,
            "expected Target configured with reset button");
        // Wait for the initial system power on request to complete.
        bench.await_system_power_request_complete();
        assert_eq(bench.target.system_power, On, "expected system power on");

        // Press the button and assert the system powered off.
        bench.target.button_event(True);
        assert_eq(
            bench.target.system_power, Off,
            "expected system power off");

        // Reset the ticks counter on the next tick.
        action
            bench.await_tick();
            bench.reset_ticks_elapsed();
        endaction

        // Wait for at least system_power_toggle_cool_down ticks.
        await(bench.ticks_elapsed >=
                fromInteger(parameters.system_power_toggle_cool_down + 1));
        assert_eq(
            bench.target.system_power, Off,
            "expected system still powered off");

        // Release the button and assert the system powered on.
        bench.target.button_event(False);
        bench.await_system_power_request_complete();
        assert_eq(
            bench.target.system_power, On,
            "expected system power on");
    endseq);
endmodule

(* synthesize *)
module mkSystemPowerAbortOnFaultTest (Empty);
    TargetBench bench <- mkTargetBench(
        parameters,
        3 * parameters.system_power_toggle_cool_down);

    let rx = tpl_1(bench.link.message);

    mkAutoFSM(seq
        // Assert that the system initially powers on.
        bench.link.set_connected(True, False);
        assert_get_eq(rx,
            message_status_system_powering_on,
            "expected system powering on Status message");
        assert_eq(bench.target.system_power, On, "expected system power on");

        par
            // Assert an A2 power fault while the system is powering on.
            while (bench.target.system_power == On) seq
                bench.set_faults(system_faults_power_a2);
            endseq

            seq
                // Expect a power fault in A2 fault update while the fault
                // monitor has not yet been enabled.
                assert_get_eq(rx,
                    message_status_system_powering_on_a2_fault,
                    "expected an A2 power fault during power on");

                // Expect a power off request to be initiated.
                assert_get_eq(rx,
                    message_status_system_power_abort_in_progress,
                    "expected system power abort in progress Status message");
                assert_eq(
                    bench.target.system_power, Off,
                    "expected system power off");

                bench.await_system_power_request_complete();
            endseq
        endpar
    endseq);
endmodule

(* synthesize *)
module mkRequestRestartAfterSystemPowerAbortTest (Empty);
    TargetBench bench <- mkTargetBench(
        parameters,
        4 * parameters.system_power_toggle_cool_down);

    let rx = tpl_1(bench.link.message);
    let tx = tpl_2(bench.link.message);

    mkAutoFSM(seq
        // Set an A2 power fault while a system powers on, triggering an
        // emergency power off.
        bench.set_faults(system_faults_power_a2);
        bench.link.set_connected(False, True);
        bench.await_system_power_request_complete();
        assert_eq(bench.target.system_power, Off, "expected system power off");

        // Resolve A2 power fault.
        bench.set_faults(system_faults_none);

        // Send Hello's to mark the Controller present.
        repeat(4) tx.put(tagged Hello);

        // Connect bench RX so Status messages can be monitored, wait for the
        // controller 0 to be marked present.
        bench.link.set_connected(True, True);
        assert_get_eq(rx,
            message_status_system_power_abort_a2_fault_controller0_present,
            "expected system power aborted");

        // Request the system to be powered on again.
        tx.put(tagged Request SystemPowerOn);

        assert_get_eq(rx,
            message_status_system_powering_on_controller0_present,
            "expected system powering on");
        assert_get_eq(rx,
            message_status_system_powered_on_controller0_present,
            "expected system power on request completed");
    endseq);
endmodule

(* synthesize *)
module mkResetButtonRestartAfterSystemPowerAbortTest (Empty);
    TargetBench bench <- mkTargetBench(
        parameters,
        4 * parameters.system_power_toggle_cool_down);

    mkAutoFSM(seq
        // Set an A2 power fault while a system powers on, triggering an
        // emergency power off.
        bench.set_faults(system_faults_power_a2);
        bench.link.set_connected(False, True);
        bench.await_system_power_request_complete();
        assert_eq(bench.target.system_power, Off, "expected system power off");

        // Resolve A2 power fault.
        bench.set_faults(system_faults_none);

        // Press the button.
        bench.target.button_event(True);
        bench.target.button_event(False);

        bench.await_system_power_request_complete();
        assert_eq(
            bench.target.system_power, On,
            "expected system power on");
    endseq);
endmodule

(* synthesize *)
module mkPowerButtonRestartAfterSystemPowerAbortTest (Empty);
    Parameters parameters_ = parameters;
    parameters_.button_behavior = PowerButton;

    TargetBench bench <- mkTargetBench(
        parameters_,
        4 * parameters.system_power_toggle_cool_down);

    mkAutoFSM(seq
        // Set an A2 power fault while a system powers on, triggering an
        // emergency power off.
        bench.set_faults(system_faults_power_a2);
        bench.link.set_connected(False, True);
        bench.await_system_power_request_complete();
        assert_eq(bench.target.system_power, Off, "expected system power off");

        // Resolve A2 power fault.
        bench.set_faults(system_faults_none);

        // Press the button.
        bench.target.button_event(True);
        bench.target.button_event(False);

        bench.await_system_power_request_complete();
        assert_eq(
            bench.target.system_power, On,
            "expected system power on");
    endseq);
endmodule

(* synthesize *)
module mkPowerFaultBitsStickyAfterSystemPowerAbortTest (Empty);
    TargetBench bench <- mkTargetBench(
        parameters,
        4 * parameters.system_power_toggle_cool_down);

    let rx = tpl_1(bench.link.message);

    mkAutoFSM(seq
        // Set an A2 power fault while a system powers on, triggering an
        // emergency power off.
        bench.set_faults(system_faults_power_a2);
        bench.await_system_power_request_complete();
        assert_eq(bench.target.system_power, Off, "expected system power off");

        // Connect RX so Status messages can be received.
        bench.link.set_connected(True, False);

        // Resolve A2 power fault and wait for a period Status update still
        // showing the A2 fault even though the fault bit has been cleared.
        bench.set_faults(system_faults_none);
        assert_get_eq(rx,
            message_status_system_power_abort_a2_fault,
            "expected system power abort with A2 power fault");

        // Set the SP fault bit.
        bench.set_faults(system_faults_sp);
        assert_get_eq(rx,
            message_status_system_power_abort_a2_sp_fault,
            "expected system power abort with A2 power and SP faults");
    endseq);
endmodule

(* synthesize *)
module mkSystemPowerFaultMonitorDisabledDuringResetTest (Empty);
    TargetBench bench <- mkTargetBench(
        parameters,
        4 * parameters.system_power_toggle_cool_down);

    let rx = tpl_1(bench.link.message);

    mkAutoFSM(seq
        bench.await_system_power_request_complete();
        assert_eq(bench.target.system_power, On, "expected system power on");

        // Press the reset button. As a result of system power turning off the
        // A2 power fault signal goes high.
        bench.target.button_event(True);
        bench.set_faults(system_faults_power_a2);
        assert_eq(bench.target.system_power, Off, "expected system power off");
        bench.target.button_event(False);

        // Wait for the system to power off and the power on sequence to be
        // initiated.
        bench.await_system_power_off_complete();
        assert_eq(bench.target.system_power, On, "expected system power on");
        // Wait a few ticks for the power fault signals to be resolved.
        repeat(3) bench.await_tick();
        bench.set_faults(system_faults_none);

        bench.await_system_power_request_complete();
        assert_eq(bench.target.system_power, On, "expected system power on");
    endseq);
endmodule

//
// Helpers
//

function Stmt await_controller_reported_present(
        Reg#(IgnitionProtocol::SystemStatus) status,
        Get#(Message) link) =
    seq
        while (!status.controller0_present) action
            let message <- link.get;
            if (message matches tagged Status .message_)
                status <= message_.system_status;
        endaction
    endseq;

function Stmt await_target_system_status(
        Get#(Message) link,
        Reg#(IgnitionProtocol::SystemStatus) current_status,
        IgnitionProtocol::SystemStatus expected_status) =
    seq
        while (current_status != expected_status) action
            let envelope <- link.get;
            if (envelope matches tagged Status .message)
                current_status <= message.system_status;
        endaction
    endseq;

endpackage
