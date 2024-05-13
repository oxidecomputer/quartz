package IgnitionTarget;

export ButtonBehavior(..);
export Parameters(..);
export default_app_with_reset_button;
export default_app_with_power_button;
export default_app;

export SystemPower(..);
export Target(..);
export mkTarget;

import ConfigReg::*;
import Connectable::*;
import DefaultValue::*;
import DReg::*;
import FIFO::*;
import GetPut::*;
import Vector::*;

import Countdown::*;
import SchmittReg::*;
import Strobe::*;

import IgnitionProtocol::*;
import IgnitionTransceiver::*;


//
// This package contains the top level interfaces and modules implementing the
// Ignition Target application.
//

typedef enum {
    Off,
    On
} SystemPower deriving (Bits, Eq, FShow);

interface Target;
    method Action set_system_type(SystemType t);
    (* always_enabled *) method Action set_faults(SystemFaults faults);
    (* always_ready *) method Action button_event(Bool pressed);

    (* always_enabled *) method SystemPower system_power();
    (* always_enabled *) method Bool system_power_hotswap_controller_restart();
    (* always_enabled *) method Bit#(2) leds();

    interface TargetTransceiverClient txr;

    // External tick used to drive timers and generate internal events such as
    // the transmission of Status messages.
    interface PulseWire tick_1khz;

    // Debug interface, can be used in test benches or early builds of the
    // systems.
    method Bool system_power_request_in_progress();
    method Bool system_power_off_in_progress();
    method Bool system_power_on_in_progress();
    method Bool system_power_aborted();

    method Bool controller0_present();
    method Bool controller1_present();
endinterface

typedef enum {
    ResetButton = 0,
    PowerButton,
    NoButton
} ButtonBehavior deriving (Eq, FShow);

// The behavior of an IgnitionTarget application can be tweaked. This is
// primarily useful for test benches.
typedef struct {
    Bool external_reset;
    Bool invert_leds;
    Bool mirror_link0_rx_as_link1_tx;
    Maybe#(SystemType) system_type;
    ButtonBehavior button_behavior;
    Integer system_power_toggle_cool_down;
    // Enable/disable the system power monitor which triggers a mutual assured
    // power-off (MAPO) if A3/A2 power faults occur.
    Bool system_power_fault_monitor_enable;
    // The number of ticks before the power fault monitor starts after powering
    // on the target system.
    Integer system_power_fault_monitor_start_delay;
    // Enable/disable hotswap controller restart during power on/off sequencing.
    Bool system_power_hotswap_controller_restart;
    // Enable/disable the receiver watchdog.
    Bool receiver_watchdog_enable;
    IgnitionProtocol::Parameters protocol;
} Parameters;

Parameters default_app_with_reset_button =
    Parameters{
        external_reset: True,
        invert_leds: False,
        mirror_link0_rx_as_link1_tx: False,
        system_type: tagged Invalid,
        button_behavior: ResetButton,
        system_power_toggle_cool_down: 3000, // 3s if app tick at 1 kHz.
        system_power_fault_monitor_enable: True,
        system_power_fault_monitor_start_delay: 25, // 25ms if app tick at 1kHz.
        system_power_hotswap_controller_restart: True,
        receiver_watchdog_enable: True,
        protocol: defaultValue};

Parameters default_app_with_power_button =
    Parameters{
        external_reset: True,
        invert_leds: False,
        mirror_link0_rx_as_link1_tx: False,
        system_type: tagged Invalid,
        button_behavior: PowerButton,
        system_power_toggle_cool_down: 1000, // 1s if app tick at 1 kHz.
        system_power_fault_monitor_enable: False,
        system_power_fault_monitor_start_delay: 25, // 25ms if app tick at 1kHz.
        system_power_hotswap_controller_restart: False,
        receiver_watchdog_enable: True,
        protocol: defaultValue};

Parameters default_app =
    Parameters{
        external_reset: True,
        invert_leds: False,
        mirror_link0_rx_as_link1_tx: False,
        system_type: tagged Invalid,
        button_behavior: NoButton,
        system_power_toggle_cool_down: 1000, // 1s if app tick at 1 kHz.
        system_power_fault_monitor_enable: False,
        system_power_fault_monitor_start_delay: 25, // 25ms if app tick at 1kHz.
        system_power_hotswap_controller_restart: False,
        receiver_watchdog_enable: True,
        protocol: defaultValue};

instance DefaultValue#(Parameters);
    defaultValue = default_app_with_reset_button;
endinstance

interface LinkMonitor;
    (* always_ready *) method Action monitor(LinkStatus status, LinkEvents events);

    (* always_enabled *) method LinkStatus status();
    (* always_enabled *) method LinkEvents events();
    (* always_enabled *) method Bool controller_present();
    method Action message_received(Bool hello);
    method Action clear_events();

    interface PulseWire tick;
endinterface

module mkLinkMonitor #(Parameters parameters, Integer link_id) (LinkMonitor);
    Wire#(LinkStatus) status_next <- mkDWire(defaultValue);
    Wire#(LinkEvents) events_next <- mkWire();
    Reg#(LinkEvents) pending_events <- mkReg(defaultValue);

    PulseWire clear_events_ <- mkPulseWire();

    Reg#(Bool) past_controller_present <- mkReg(False);
    SchmittReg#(3, Bool) controller_present_ <-
        mkSchmittReg(False, EdgePatterns {
            negative_edge: 'b100,
            positive_edge: 'b111,
            mask: 'b111});

    Countdown#(6) controller_timeout <- mkCountdownBy1();
    Reg#(Maybe#(Bool)) message_received_ <- mkDReg(tagged Invalid);

    (* fire_when_enabled *)
    rule do_update_link_state;
        // Accumulate any events which occured.
        let pending_events_ = clear_events_ ? link_events_none : pending_events;
        pending_events <= pending_events_ | events_next;

        if (message_received_ matches tagged Valid .hello)
            // The presence filter requires that at least one Hello is received
            // before subsequent messages are used to keep presence alive.
            controller_present_ <= hello || controller_present_;
        else if (controller_timeout)
            controller_present_ <= False;

        // Re-arm the controller timeout countdown.
        if (isValid(message_received_) || controller_timeout) begin
            controller_timeout <=
                fromInteger(parameters.protocol.hello_interval + 2);
        end

        past_controller_present <= controller_present_;

        // Log any changes in presence to aid test debugging.
        if (past_controller_present != controller_present_) begin
            let format = controller_present_ ?
                "%5t [Target] Controller %1d present" :
                "%5t [Target] Controller %1d timeout";

            $display(format, $time, link_id);
        end
    endrule

    method Action monitor(LinkStatus status, LinkEvents events);
        status_next <= status;
        events_next <= events;
    endmethod

    method status = status_next;
    method events = pending_events;
    method clear_events = clear_events_.send;

    interface PulseWire tick;
        method _read = False;
        method send = controller_timeout.send;
    endinterface

    method controller_present = controller_present_;
    method Action message_received(Bool hello);
        message_received_ <= tagged Valid hello;
    endmethod
endmodule

module mkTarget #(Parameters parameters) (Target);
    Vector#(2, LinkMonitor) links <-
        mapM(mkLinkMonitor(parameters), genVector());

    Wire#(TaggedMessage) rx <- mkWire();
    FIFO#(Message) tx <- mkLFIFO();

    // The last Status message sent.
    Reg#(Message) past_status_message <- mkRegU();

    // Primary state registers.
    Reg#(Maybe#(SystemType)) system_type <- mkConfigReg(tagged Invalid);
    Reg#(SystemPower) system_power_r <- mkConfigReg(Off);
    Reg#(Bool) system_power_abort <- mkConfigReg(False);
    Reg#(Bool) system_power_hotswap_controller_restart_r <- mkConfigReg(False);
    Reg#(SystemFaults) system_faults <- mkConfigReg(system_faults_none);
    Reg#(RequestStatus) request_status <- mkConfigReg(defaultValue);
    Reg#(Bit#(2)) leds_r <- mkConfigRegU();

    let initialized = isValid(system_type);
    let system_power_on = (system_power_r == On);
    let system_power_off = (system_power_r == Off);

    let status_message =
        tagged Status {
            system_type: fromMaybe(?, system_type),
            system_status:
                SystemStatus {
                    system_power_abort: system_power_abort,
                    system_power_enabled: system_power_on,
                    controller1_present: links[1].controller_present,
                    controller0_present: links[0].controller_present},
            system_faults: system_faults,
            request_status: request_status,
            link0_status: links[0].status,
            link0_events: links[0].events,
            link1_status: links[1].status,
            link1_events: links[1].events};

    // Short hands used for readability in rule guards.
    let request_in_progress = (request_status != request_status_none);
    let system_powering_on = request_status.power_on_in_progress;
    let system_powering_off = request_status.power_off_in_progress;
    let system_resetting = request_status.reset_in_progress;
    let system_reset_powering_off = (system_resetting && system_powering_off);
    let system_reset_powering_on = (system_resetting && system_powering_on);

    //
    // Events
    //
    PulseWire tick <- mkPulseWire();
    PulseWire received_message_accepted <- mkPulseWire();

    RWire#(Bool) button_event_w <- mkRWire();
    Reg#(Bool) reset_button_released <- mkConfigRegU();

    let button_pressed = fromMaybe(False, button_event_w.wget);
    let button_released = !fromMaybe(True, button_event_w.wget);

    // This Request RWire is used by rules to make system power requests.
    RWire#(Request) request <- mkRWire();

    Countdown#(12) system_power_toggle_cool_down <- mkCountdownBy1();
    Reg#(Bool) system_power_toggle_cool_down_complete <- mkRegU();

    Countdown#(5) system_power_fault_monitor_start <- mkCountdownBy1();
    Reg#(Bool) system_power_fault_monitor_enabled <- mkReg(False);
    PulseWire system_power_fault <- mkPulseWire();

    // Event triggering the next Status Message.
    Countdown#(5) status_update_expired <- mkCountdownBy1();
    Reg#(Bool) status_update_requested <- mkReg(False);

    //
    // Connect the global tick
    //

    (* fire_when_enabled *)
    rule do_tick (tick);
        system_power_toggle_cool_down.send();
        system_power_fault_monitor_start.send();
        status_update_expired.send();
        links[0].tick.send();
        links[1].tick.send();
    endrule

    //
    // System power state management
    //

    (* fire_when_enabled *)
    rule do_update_system_power_state;
        //
        // Updating all the system power state is a managed/modelled in the
        // following steps:
        //
        // 1) Determine if a system power state change is needed based on
        //    whether or not a system power request is in progress. As part of
        //    this step the state associated with this request is updated.
        // 2) If the system power state needs to change as a result of the logic
        //    in step 1, execute that change
        // 3) After changing the system power state in step 2, which sets a
        //    system power toggle cool down timer, monitor the timer for
        //    completion and allow in-progress system power requests to complete
        // 4) Update the system power fault monitor enabled state depending on
        //    state changes made in step 2
        //
        // Note that steps 3 and 4 are happening in parallel and not dependent
        // on each other.
        //

        //
        // Step 1
        //
        // Update any system power request and determine if the system power
        // state needs to change.
        //
        let system_power_next = system_power_r;

        // Turn system power off if a power fault occurs (MAPO). Disabling this
        // in the `parameters` structure will cause the compiler to optimize
        // this out.
        if (parameters.system_power_fault_monitor_enable &&
                system_power_fault_monitor_enabled &&
                system_power_on &&
                system_power_fault) begin
            // Signal the Controller that an abort happened as a result of a
            // fault. This flag is only set here.
            system_power_abort <= True;

            // Initiate a system power off in step 2.
            system_power_next = Off;
            request_status <= request_status_power_off_in_progress;
            $display("%5t [Target] System power fault, requesting SystemPowerOff", $time);
        end
        // If a system reset is in progress and the system power off cool down
        // has completed, initate system power on in step 2.
        else if (system_reset_powering_off &&
                system_power_toggle_cool_down_complete &&
                reset_button_released) begin
            system_power_next = On;
            request_status <=
                request_status_reset_in_progress |
                request_status_power_on_in_progress;
        end
        // Complete an in progress system power request if the cool down has
        // completed. The completion event monitored here is updated in step 3.
        else if (((!system_resetting &&
                        (system_powering_on || system_powering_off)) ||
                    system_reset_powering_on) &&
                system_power_toggle_cool_down_complete) begin
            request_status <= request_status_none;
            $display("%5t [Target] Request complete", $time);
        end
        // Start any pending system power requests based on the current system
        // power state and the request. Only certain transitions are legal and
        // for those transitions which are not the request is simply ignored.
        //
        // It is expected that anyone requesting a change monitors the
        // `request_status` fields in the `Status` messages sent by this Target
        // to determine if the request is taking effect.
        else if (request.wget matches tagged Valid .request_) begin
            case (tuple2(system_power_r, request_)) matches
                {Off, SystemPowerOn}: begin
                    system_power_next = On;
                    request_status <= request_status_power_on_in_progress;
                end

                {On, SystemPowerOff}: begin
                    system_power_next = Off;
                    request_status <= request_status_power_off_in_progress;
                end

                {On, SystemReset}: begin
                    system_power_next = Off;
                    request_status <=
                        request_status_reset_in_progress |
                        request_status_power_off_in_progress;
                end
            endcase
        end

        //
        // Step 2
        //
        // The request logic above has determined that a system power toggle is
        // required. Initiate this change.
        //
        if (system_power_r != system_power_next) begin
            // The system power pin changes here.
            system_power_r <= system_power_next;
            // On some Target implementations the hotswap controller which is
            // part of the A3 system power supply should be restarted/cleared on
            // system power down. This behavior is statically enabled for
            // Gimlet/Sidecar and assumes the restart behavior of an ADM1272.
            if (parameters.system_power_hotswap_controller_restart) begin
                system_power_hotswap_controller_restart_r <= (system_power_next == Off);
            end

            $display("%5t [Target] System power ", $time, fshow(system_power_next));

            // Start the system power toggle cool down timer.
            system_power_toggle_cool_down <=
                fromInteger(parameters.system_power_toggle_cool_down + 1);

            // Previous abort state should be cleared.
            if (system_power_next == On) begin
                system_power_abort <= False;

                if (system_power_abort) begin
                    $display("%5t [Target] System power abort cleared", $time);
                end
            end
        end

        //
        // Step 3
        //
        // Monitor the system power toggle cool down counter for completion.
        //
        if (system_power_r != system_power_next) begin
            // Await the next cool down complete.
            system_power_toggle_cool_down_complete <= False;
        end
        else if (system_power_toggle_cool_down) begin
            system_power_toggle_cool_down_complete <= True;
        end

        //
        // Step 4
        //
        // Determine whether or not to enable the system power fault monitor.
        // There is some subtlety here:
        //
        // If system power hotswap controller restart is enabled this controller
        // may have its own power down cool down. If the power fault monitor
        // were to be enabled before this cool down timer completed and the
        // hotswap controller actually turned on its output the lack of a PG
        // signal would erroneously trip the monitor and abort power before the
        // hotswap controller was given the chance to enable its ouput.
        //
        // If this hotswap controller restart is enabled the power fault monitor
        // enable timer is armed only once A3 PG has been observed/the fault bit
        // has cleared. Otherwise the fault monitor enable timer is armed as
        // soon as a system power transition happens from Off to On.
        //
        // The implicit trade-off here is that there is no A3 PG timeout if
        // hotswap controller restart is enabled and a system may dwell forever
        // in a state where system power is enabled but A3 never reached power
        // good (as indicated by the A3 power fault bit remaining set after some
        // time). Logic elsewhere should monitor for this case to occur and take
        // appropriate action.
        //
        // Finally, with the system potentially dwelling a state where the
        // transition from A3 to A2 never completes it is assumed that the power
        // components in A3 are sufficiently robust that this is no problem.
        // Generally these have appropriate input and output monitors and their
        // own fault logic which should make this appropriate.
        //
        if (parameters.system_power_fault_monitor_enable) begin
            if (system_power_on &&
                    !(parameters.system_power_hotswap_controller_restart ||
                        system_faults.power_a3) &&
                    !system_power_fault_monitor_enabled &&
                    system_power_fault_monitor_start.count != 0) begin
                system_power_fault_monitor_start <=
                    fromInteger(parameters.system_power_fault_monitor_start_delay + 1);
            end

            // Enable the power fault monitor if the start timer has completed.
            if (system_power_fault_monitor_start) begin
                system_power_fault_monitor_enabled <= True;
                $display("%5t [Target] System power fault monitor enabled", $time);
            end
            // If a power fault has occured or the system is powered off,
            // disable the monitor to avoid subsequent erroneous abort triggers.
            else if (system_power_abort || system_power_next == Off) begin
                system_power_fault_monitor_enabled <= False;

                if (system_power_fault_monitor_enabled) begin
                    $display("%5t [Target] System power fault monitor disabled", $time);
                end
            end
        end
        else if (system_power_r != system_power_next) begin
            $display("%5t [Target] System power fault monitor not enabled", $time);
        end
    endrule

    //
    // The button, depending on its desired mode, may trigger system power
    // requests. These rules are added here based on compile-time configuration.
    //
    case (parameters.button_behavior)
        ResetButton: begin
            // Initiate a system power request if the button is pressed and no
            // system power sequence is in progress.
            (* fire_when_enabled *)
            rule do_press_reset_button (
                    initialized &&
                    button_pressed &&
                    !request_in_progress);
                // If the system is powered off, act as a power button rather
                // than a reset button. The system power transition logic will
                // clear the abort flag is this power off was in response to a
                // system power fault/abort.
                let request_ = system_power_off ?
                        SystemPowerOn :
                        SystemReset;

                reset_button_released <= False;
                request.wset(request_);
                $display(
                    "%5t [Target] ", $time,
                    fshow(request_), " Request from button");
            endrule

            (* fire_when_enabled *)
            rule do_await_reset_button_released (
                    !reset_button_released &&
                    button_released);
                reset_button_released <= True;
            endrule
        end

        PowerButton: begin
            // Initiate toggling system power if the button is pressed and no
            // sequence is in progress.
            (* fire_when_enabled *)
            rule do_press_power_button (
                    initialized &&
                    button_pressed &&
                    !request_in_progress);
                let request_ = system_power_off ?
                        SystemPowerOn :
                        SystemPowerOff;

                request.wset(request_);
                $display(
                    "%5t [Target] ", $time, fshow(request_),
                    " Request from button ");
            endrule
        end
    endcase

    (* fire_when_enabled *)
    rule do_handle_system_power_request (
            initialized &&
            !button_pressed &&
            !request_in_progress &&
            // and a request was received from an active controller.
            links[rx.sender].controller_present &&&
            rx.message matches tagged Request .request_);
        // Deq the message and notify the Link a Message was resceived.
        received_message_accepted.send();
        links[rx.sender].message_received(False); // Not Hello message.

        request.wset(request_);

        // Set the reset_button_released event so a SystemReset request can be
        // completed.
        reset_button_released <= True;

        $display(
            "%5t [Target] ", $time, fshow(request_),
            " Request from Controller %1d", rx.sender);
    endrule

    (* fire_when_enabled *)
    rule do_ignore_system_power_request (
            rx.message matches tagged Request .request_ &&&
            (button_pressed ||
                request_in_progress ||
                !links[rx.sender].controller_present));
        received_message_accepted.send();
        links[rx.sender].message_received(False);

        $display(
            "%5t [Target] ", $time, fshow(request_),
            " Request from Controller %1d ignored", rx.sender);
    endrule

    //
    // Status updates.
    //

    (* fire_when_enabled *)
    rule do_request_status_update (
            !status_update_requested &&
            // Period status update.
            (status_update_expired ||
                status_message != past_status_message));
        status_update_requested <= True;
    endrule

    (* fire_when_enabled *)
    rule do_send_status_update (status_update_requested);
        tx.enq(status_message);

        status_update_requested <= False;
        status_update_expired <= fromInteger(
            parameters.protocol.status_interval);

        links[0].clear_events();
        links[1].clear_events();

        // Keep a copy of the current Status message to trigger future updates.
        // The events are explicitly not part of this in order to allow multiple
        // occurances of the same event to trigger update messages.
        past_status_message <=
            tagged Status {
                system_type: status_message.Status.system_type,
                system_status: status_message.Status.system_status,
                system_faults: status_message.Status.system_faults,
                request_status: status_message.Status.request_status,
                link0_status: status_message.Status.link0_status,
                link0_events: link_events_none,
                link1_status: status_message.Status.link1_status,
                link1_events: link_events_none};

        $display(
            "%5t [Target] Sent ", $time,
            message_status_pretty_format(status_message));
    endrule

    (* fire_when_enabled *)
    rule do_receive_hello (rx.message matches tagged Hello);
        received_message_accepted.send();
        links[rx.sender].message_received(True);
        $display("%5t [Target] Hello from Controller %1d", $time, rx.sender);
    endrule

    //
    // Set LEDs
    //

    (* no_implicit_conditions, fire_when_enabled *)
    rule do_set_leds;
        let receiver_locked =
            links[0].status.receiver_locked || links[1].status.receiver_locked;

        let led0 = parameters.invert_leds ?
            ~pack(receiver_locked) :
            pack(receiver_locked);

        let led1 = parameters.invert_leds ?
            ~pack(system_power_r) :
            pack(system_power_r);

        leds_r <= {led1, led0};
    endrule

    //
    // Interface implementation.
    //

    // System type can only be set once after application reset.
    method Action set_system_type(SystemType t) if (!isValid(system_type));
        system_type <= tagged Valid t;

        if (parameters.button_behavior == ResetButton) begin
            request.wset(SystemPowerOn);
        end
    endmethod

    method Action set_faults(SystemFaults f);
        // The power fault bits become sticky when a system power abort happens
        // in order to preserve the fault reason.
        system_faults <=  SystemFaults {
            sp: f.sp,
            rot: f.rot,
            reserved2: f.reserved2,
            reserved1: f.reserved1,
            power_a2: (system_power_abort ? system_faults.power_a2 : f.power_a2),
            power_a3: (system_power_abort ? system_faults.power_a3 : f.power_a3)};

        if (f.power_a3 || f.power_a2) begin
            system_power_fault.send();
        end
    endmethod

    method Action button_event(Bool pressed);
        $display(
            "%5t [Target] Button %s", $time,
            pressed ? "pressed" : "released");
        button_event_w.wset(pressed);
    endmethod

    method system_power = system_power_r;
    method system_power_hotswap_controller_restart =
            system_power_hotswap_controller_restart_r;

    method leds = leds_r;

    interface PulseWire tick_1khz = tick;

    interface TargetTransceiverClient txr;
        interface GetS to_txr = fifoToGetS(tx);

        interface PutS from_txr;
            method offer = rx._write;
            method accepted = received_message_accepted;
        endinterface

        method Action monitor(
                Vector#(2, LinkStatus) status,
                Vector#(2, LinkEvents) events);
            links[0].monitor(status[0], events[0]);
            links[1].monitor(status[1], events[1]);
        endmethod

        method Bool tick_1khz = tick;
    endinterface

    method system_power_request_in_progress = request_in_progress;
    method system_power_off_in_progress = system_powering_off;
    method system_power_on_in_progress = system_powering_on;
    method system_power_aborted = system_power_abort;

    method controller0_present = links[0].controller_present;
    method controller1_present = links[1].controller_present;
endmodule

endpackage: IgnitionTarget
