package IgnitionTestHelpers;

import BuildVector::*;
import GetPut::*;
import Vector::*;

import Encoding8b10b::*;
import Encoding8b10bReference::*;
import TestUtils::*;

import IgnitionProtocol::*;


Bit#(20) default_disconnect_pattern = '0;
Bit#(20) almost_comma_disconnect_pattern = 'b00011_00000_11111_00000;

// Shared Constants
SystemType target_system_type = 'b000101;

SystemStatus system_status_system_powered_on_controller0_present =
    system_status_system_power_enabled |
    system_status_controller0_present;

SystemStatus system_status_system_powered_off_controller0_present =
    system_status_controller0_present;

SystemStatus system_status_system_powered_on_both_controllers_present =
    system_status_system_power_enabled |
    system_status_controller1_present |
    system_status_controller0_present;

Message message_status_system_powering_on =
    tagged Status {
        system_type: target_system_type,
        system_status: system_status_system_power_enabled,
        system_faults: system_faults_none,
        request_status: request_status_power_on_in_progress,
        link0_status: link_status_disconnected,
        link0_events: link_events_none,
        link1_status: link_status_disconnected,
        link1_events: link_events_none};

Message message_status_system_powering_on_controller0_present =
    tagged Status {
        system_type: target_system_type,
        system_status:
            system_status_system_power_enabled |
            system_status_controller0_present,
        system_faults: system_faults_none,
        request_status: request_status_power_on_in_progress,
        link0_status: link_status_connected,
        link0_events: link_events_none,
        link1_status: link_status_disconnected,
        link1_events: link_events_none};

Message message_status_system_powered_on =
    tagged Status {
        system_type: target_system_type,
        system_status: system_status_system_power_enabled,
        system_faults: system_faults_none,
        request_status: request_status_none,
        link0_status: link_status_disconnected,
        link0_events: link_events_none,
        link1_status: link_status_disconnected,
        link1_events: link_events_none};

Message message_status_system_powered_on_link0_connected =
    tagged Status {
        system_type: target_system_type,
        system_status: system_status_system_power_enabled,
        system_faults: system_faults_none,
        request_status: request_status_none,
        link0_status: link_status_connected,
        link0_events: link_events_none,
        link1_status: link_status_disconnected,
        link1_events: link_events_none};

Message message_status_system_powered_on_controller0_present =
    tagged Status {
        system_type: target_system_type,
        system_status: system_status_system_powered_on_controller0_present,
        system_faults: system_faults_none,
        request_status: request_status_none,
        link0_status: link_status_connected,
        link0_events: link_events_none,
        link1_status: link_status_disconnected,
        link1_events: link_events_none};

Message message_status_system_powered_on_both_controllers_present =
    tagged Status {
        system_type: target_system_type,
        system_status: system_status_system_powered_on_both_controllers_present,
        system_faults: system_faults_none,
        request_status: request_status_none,
        link0_status: link_status_connected,
        link0_events: link_events_none,
        link1_status: link_status_connected,
        link1_events: link_events_none};

Message message_status_system_powered_off_controller0_present =
    tagged Status {
        system_type: target_system_type,
        system_status: system_status_system_powered_off_controller0_present,
        system_faults: system_faults_none,
        request_status: request_status_none,
        link0_status: link_status_connected,
        link0_events: link_events_none,
        link1_status: link_status_disconnected,
        link1_events: link_events_none};

Message message_status_system_powering_on_a3_fault =
    tagged Status {
        system_type: target_system_type,
        system_status: system_status_system_power_enabled,
        system_faults: system_faults_power_a3,
        request_status: request_status_power_on_in_progress,
        link0_status: link_status_disconnected,
        link0_events: link_events_none,
        link1_status: link_status_disconnected,
        link1_events: link_events_none};

Message message_status_system_powering_on_a2_fault =
    tagged Status {
        system_type: target_system_type,
        system_status: system_status_system_power_enabled,
        system_faults: system_faults_power_a2,
        request_status: request_status_power_on_in_progress,
        link0_status: link_status_disconnected,
        link0_events: link_events_none,
        link1_status: link_status_disconnected,
        link1_events: link_events_none};

Message message_status_system_power_abort_a3_in_progress =
    tagged Status {
        system_type: target_system_type,
        system_status: system_status_system_power_abort,
        system_faults: system_faults_power_a3,
        request_status: request_status_power_off_in_progress,
        link0_status: link_status_disconnected,
        link0_events: link_events_none,
        link1_status: link_status_disconnected,
        link1_events: link_events_none};

Message message_status_system_power_abort_a2_in_progress =
    tagged Status {
        system_type: target_system_type,
        system_status: system_status_system_power_abort,
        system_faults: system_faults_power_a2,
        request_status: request_status_power_off_in_progress,
        link0_status: link_status_disconnected,
        link0_events: link_events_none,
        link1_status: link_status_disconnected,
        link1_events: link_events_none};

Message message_status_system_power_abort_a2_fault =
    tagged Status {
        system_type: target_system_type,
        system_status: system_status_system_power_abort,
        system_faults: system_faults_power_a2,
        request_status: request_status_none,
        link0_status: link_status_disconnected,
        link0_events: link_events_none,
        link1_status: link_status_disconnected,
        link1_events: link_events_none};

Message message_status_system_power_abort_a2_sp_fault =
    tagged Status {
        system_type: target_system_type,
        system_status: system_status_system_power_abort,
        system_faults:
            system_faults_power_a2 |
            system_faults_sp,
        request_status: request_status_none,
        link0_status: link_status_disconnected,
        link0_events: link_events_none,
        link1_status: link_status_disconnected,
        link1_events: link_events_none};

Message message_status_system_power_abort_a2_fault_controller0_present =
    tagged Status {
        system_type: target_system_type,
        system_status:
            system_status_system_power_abort |
            system_status_controller0_present,
        system_faults: system_faults_power_a2,
        request_status: request_status_none,
        link0_status: link_status_connected,
        link0_events: link_events_none,
        link1_status: link_status_disconnected,
        link1_events: link_events_none};

function Message message_status_with_link0_status(
        Message m,
        LinkStatus link0_status) =
    tagged Status {
        system_type: m.Status.system_type,
        system_status: m.Status.system_status,
        system_faults: m.Status.system_faults,
        request_status: m.Status.request_status,
        link0_status: link0_status,
        link0_events: m.Status.link0_events,
        link1_status: m.Status.link1_status,
        link1_events: m.Status.link1_events};

function Message message_status_with_link0_events(
        Message m,
        LinkEvents events) =
    tagged Status {
        system_type: m.Status.system_type,
        system_status: m.Status.system_status,
        system_faults: m.Status.system_faults,
        request_status: m.Status.request_status,
        link0_status: m.Status.link0_status,
        link0_events: events,
        link1_status: m.Status.link1_status,
        link1_events: m.Status.link1_events};

function Message message_status_with_system_faults(
        Message m,
        SystemFaults faults) =
    tagged Status {
        system_type: m.Status.system_type,
        system_status: m.Status.system_status,
        system_faults: faults,
        request_status: m.Status.request_status,
        link0_status: m.Status.link0_status,
        link0_events: m.Status.link0_events,
        link1_status: m.Status.link1_status,
        link1_events: m.Status.link1_events};

// A Status message populated with irregular patterns so as to help debug
// parse/deparse errors.
Message message_status_parse_deparse =
    tagged Status {
        system_type: 'b10101010,
        system_status:
            SystemStatus {
                system_power_abort: False,
                system_power_enabled: True,
                controller1_present: False,
                controller0_present: True},
        system_faults:
            SystemFaults {
                rot: False,
                sp: True,
                reserved2: False,
                reserved1: True,
                power_a2: False,
                power_a3: True},
        request_status:
            RequestStatus {
                reset_in_progress: True,
                power_on_in_progress: True,
                power_off_in_progress: False},
        link0_status:
            LinkStatus {
                polarity_inverted: False,
                receiver_locked: True,
                receiver_aligned: True},
        link0_events: unpack('b010101),
        link1_status:
            LinkStatus {
                polarity_inverted: True,
                receiver_locked: False,
                receiver_aligned: True},
        link1_events: unpack('b101010)};

typedef Vector#(n, Value) ValueSequence#(numeric type n);

function ValueSequence#(13) mk_status_sequence(Message m) = vec(
    start_of_message,
    tagged D fromInteger(defaultValue.version),
    tagged D 1,
    tagged D extend(pack(m.Status.system_type)),
    tagged D extend(pack(m.Status.system_status)),
    tagged D extend(pack(m.Status.system_faults)),
    tagged D extend(pack(m.Status.request_status)),
    tagged D extend(pack(m.Status.link0_status)),
    tagged D extend(pack(m.Status.link0_events)),
    tagged D extend(pack(m.Status.link1_status)),
    tagged D extend(pack(m.Status.link1_events)),
    tagged D 0,
    end_of_message1);

ValueSequence#(5) hello_sequence = vec(
    start_of_message,
    tagged D fromInteger(defaultValue.version),
    tagged D 2,
    tagged D 'hf0,
    end_of_message1);

function ValueSequence#(6) mk_request_sequence(Request r) = vec(
    start_of_message,
    tagged D fromInteger(defaultValue.version),
    tagged D 3,
    tagged D extend(pack(r)),
    tagged D
        (case (r)
            SystemPowerOff: 'ha3;
            SystemPowerOn: 'hd2;
            SystemReset: 'hfd;
        endcase),
    end_of_message1);

ValueSequence#(2) invalid_version_sequence = vec(
    start_of_message,
    tagged D 255);

ValueSequence#(3) invalid_message_type_sequence = vec(
    start_of_message,
    tagged D fromInteger(defaultValue.version),
    tagged D 0);

ValueSequence#(5) invalid_checksum_sequence = vec(
    start_of_message,
    tagged D fromInteger(defaultValue.version),
    tagged D 2,
    tagged D 255,
    end_of_message1);

ValueSequence#(3) invalid_ordered_set_sequence = vec(
    start_of_message,
    end_of_message_invalid,
    end_of_message1);

function Action _assert_character(
        Character actual,
        Value v,
        String msg,
        Bool compare_rdn,
        Bool compare_rdp) =
    action
        Maybe#(LookupResult) maybe_result =
            case (v) matches
                tagged D .d: tagged Valid lookup_d(d);
                tagged K .k: lookup_k(k);
            endcase;

        case (maybe_result) matches
            tagged Valid .result: begin
                // The characters are bit reversed. Correct them before
                // comparing the the actual value.
                let rdn = mk_c(result.rdn);
                let rdp = mk_c(result.rdp);
                let eq =
                    (compare_rdn && actual == rdn) ||
                    (compare_rdp && actual == rdp);

                if (!eq) begin
                    if (compare_rdn != compare_rdp)
                        $display("expected: ", fshow(compare_rdn ? rdn : rdp));
                    else
                        $display("expected: ", fshow(rdn), " or ", fshow(rdp));
                    $display("actual: ", fshow(actual));
                end
                assert_true(eq, msg);
            end
            tagged Invalid: begin
                assert_fail("invalid K value");
            end
        endcase
    endaction;

function Action assert_character(Character actual, Value v, String msg) = _assert_character(actual, v, msg, True, True);
function Action assert_character_rdn(Character actual, Value v, String msg) = _assert_character(actual, v, msg, True, False);
function Action assert_character_rdp(Character actual, Value v, String msg) = _assert_character(actual, v, msg, False, True);

function Action assert_character_get(Get#(Character) g, Value v, String msg) =
    action
        let actual <- g.get;
        assert_character(actual, v, msg);
    endaction;

function Action assert_character_rdn_get(Get#(Character) g, Value v, String msg) =
    action
        let actual <- g.get;
        assert_character_rdn(actual, v, msg);
    endaction;

function Action assert_character_rdp_get(
        Get#(Character) g,
        Value v,
        String msg) =
    action
        let actual <- g.get;
        assert_character_rdp(actual, v, msg);
    endaction;

function Action assert_character_get_display(
        Get#(Character) g,
        Value v,
        String msg) =
    action
        let actual <- g.get;
        assert_character(actual, v, msg);
        $display(fshow(actual));
    endaction;

function Action assert_character_rdn_get_display(
        Get#(Character) g,
        Value v,
        String msg) =
    action
        let actual <- g.get;
        assert_character_rdn(actual, v, msg);
        $display(fshow(actual), " (%h)", actual.x);
    endaction;

function Action assert_character_rdp_get_display(
        Get#(Character) g,
        Value v,
        String msg) =
    action
        let actual <- g.get;
        assert_character_rdp(actual, v, msg);
        $display(fshow(actual), " (%h)", actual.x);
    endaction;

endpackage
