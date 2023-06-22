package IgnitionProtocol;

import BuildVector::*;
import Vector::*;

import DefaultValue::*;

import Encoding8b10b::*;
import SettableCRC::*;


//
// Protocol Parameters
//

typedef struct {
    Integer version;
    Integer status_interval;
    Integer hello_interval;
} Parameters;

// Protocol defaults, in 1 ms increments.
instance DefaultValue#(Parameters);
    defaultValue = Parameters{
        version: 1,
        status_interval: 25,
        hello_interval: 50};
endinstance

//
// Protocol Message types.
//

typedef struct {
    UInt#(8) id;
} SystemType deriving (Bits, Literal, Eq, FShow);

typedef struct {
    Bool system_power_abort;
    Bool system_power_enabled;
    Bool controller1_present;
    Bool controller0_present;
} SystemStatus deriving (Bits, Eq, FShow);

typedef struct {
    Bool rot;
    Bool sp;
    Bool reserved2;
    Bool reserved1;
    Bool power_a2;
    Bool power_a3;
} SystemFaults deriving (Bits, Eq, FShow);

typedef struct {
    Bool reset_in_progress;
    Bool power_on_in_progress;
    Bool power_off_in_progress;
} RequestStatus deriving (Bits, Eq, FShow);

typedef struct {
    Bool message_checksum_invalid;
    Bool message_type_invalid;
    Bool message_version_invalid;
    Bool ordered_set_invalid;
    Bool decoding_error;
    Bool encoding_error;
} LinkEvents deriving (Bits, Eq, FShow);

typedef struct {
    Bool polarity_inverted;
    Bool receiver_locked;
    Bool receiver_aligned;
} LinkStatus deriving (Bits, Eq, FShow);

typedef enum {
    SystemPowerOff = 1,
    SystemPowerOn = 2,
    SystemReset = 3
} Request deriving (Bits, Eq, FShow);

typedef union tagged {
    struct {
        SystemType system_type;
        SystemStatus system_status;
        SystemFaults system_faults;
        RequestStatus request_status;
        LinkStatus link0_status;
        LinkEvents link0_events;
        LinkStatus link1_status;
        LinkEvents link1_events;
    } Status;
    void Hello;
    Request Request;
} Message deriving (Bits, Eq, FShow);

// The Target is only supposed to receive Hello and Request messages from a
// Controller. Since the number of bits required to represent a Status message
// is much larger than these shorter messages this union type can be used to
// implement a more size efficient parser/receiver for the Target.
typedef union tagged {
    void Hello;
    Request Request;
} ControllerMessage deriving (Bits, Eq, FShow);

//
// CRC Parameters
//
// The protocol uses an 8-bit CRC with the CRC-8-AUTOSTAR parameters, see
// https://www.autosar.org/fileadmin/user_upload/standards/classic/4-3/AUTOSAR_SWS_CRCLibrary.pdf
// section 7.2.1.2. This polynomial provides error detection for a Hamming
// Distance of 4 at a data length up to 119 bits, well over twice the length of
// the longest Message.
//
// For a more thorough dive into CRC polynomials and their performance, see:
// - http://users.ece.cmu.edu/~koopman/pubs/01oct2013_koopman_faa_final_presentation.pdf
// - https://users.ece.cmu.edu/~koopman/crc/crc8.html
// - http://users.ece.cmu.edu/~koopman/crc/notes.html
//
// Note that this Bluespec module uses the +1 notation for the polynomial, so a
// value of (0x1)2f corresponds with the C2 variant in the presentation.
//

typedef struct {
    Bit#(8) poly;
    Bit#(8) init;
    Bit#(8) final_xor;
    Bool reflect_data;
    Bool reflect_remainder;
} CRCParameters;

CRCParameters crc_parameters =
    CRCParameters {
        poly: 'h2f,
        init: 'hff,
        final_xor: 'hff,
        reflect_data: False,
        reflect_remainder: False};

function module#(CRC#(8)) mkIgnitionCRC() =
    mkCRC(
        crc_parameters.poly,
        crc_parameters.init,
        crc_parameters.final_xor,
        crc_parameters.reflect_data,
        crc_parameters.reflect_remainder);

//
// Encoding Ordered Sets
//

Value comma = mk_k(28, 5);
Value idle1 = mk_d(10, 2);
Value idle1_inverted = mk_d(21, 5);
Value idle2 = mk_d(19, 5);
Value idle2_inverted = mk_d(12, 2);
Value start_of_message = mk_k(28, 0);
Value end_of_message1 = mk_k(23, 7);
Value end_of_message2 = mk_k(29, 7);
Value end_of_message_invalid = mk_k(30, 7);

//
// DefaultValue, Bitwise instances and named helper values.
//

instance DefaultValue#(SystemStatus);
    defaultValue = unpack('0);
endinstance

instance Bitwise#(SystemStatus);
    function SystemStatus \& (SystemStatus s1, SystemStatus s2) = unpack(pack(s1) & pack(s2));
    function SystemStatus \| (SystemStatus s1, SystemStatus s2) = unpack(pack(s1) | pack(s2));
    function SystemStatus \^ (SystemStatus s1, SystemStatus s2) = unpack(pack(s1) ^ pack(s2));
    function SystemStatus \~^ (SystemStatus s1, SystemStatus s2) = unpack(pack(s1) ~^ pack(s2));
    function SystemStatus \^~ (SystemStatus s1, SystemStatus s2) = unpack(pack(s1) ^~ pack(s2));
    function SystemStatus invert (SystemStatus s) = unpack(invert(pack(s)));

    function SystemStatus \<< (SystemStatus s, t x) =
        error("Left shift operation is not supported with type SystemStatus");
    function SystemStatus \>> (SystemStatus s, t x) =
        error("Right shift operation is not supported with type SystemStatus");
    function Bit#(1) msb (SystemStatus s) =
        error("msb operation is not supported with type SystemStatus");
    function Bit#(1) lsb (SystemStatus s) =
        error("lsb operation is not supported with type SystemStatus");
endinstance

SystemStatus system_status_controller0_present = unpack('h1);
SystemStatus system_status_controller1_present = unpack('h2);
SystemStatus system_status_system_power_enabled = unpack('h4);
SystemStatus system_status_system_power_abort = unpack('h8);

instance DefaultValue#(SystemFaults);
    defaultValue = unpack('0);
endinstance

instance Bitwise#(SystemFaults);
    function SystemFaults \& (SystemFaults f1, SystemFaults f2) = unpack(pack(f1) & pack(f2));
    function SystemFaults \| (SystemFaults f1, SystemFaults f2) = unpack(pack(f1) | pack(f2));
    function SystemFaults \^ (SystemFaults f1, SystemFaults f2) = unpack(pack(f1) ^ pack(f2));
    function SystemFaults \~^ (SystemFaults f1, SystemFaults f2) = unpack(pack(f1) ~^ pack(f2));
    function SystemFaults \^~ (SystemFaults f1, SystemFaults f2) = unpack(pack(f1) ^~ pack(f2));
    function SystemFaults invert (SystemFaults s) = unpack(invert(pack(s)));

    function SystemFaults \<< (SystemFaults s, t x) =
        error("Left shift operation is not supported with type SystemFaults");
    function SystemFaults \>> (SystemFaults s, t x) =
        error("Right shift operation is not supported with type SystemFaults");
    function Bit#(1) msb (SystemFaults s) =
        error("msb operation is not supported with type SystemFaults");
    function Bit#(1) lsb (SystemFaults s) =
        error("lsb operation is not supported with type SystemFaults");
endinstance

SystemFaults system_faults_none = defaultValue;
SystemFaults system_faults_power_a3 = unpack('h1);
SystemFaults system_faults_power_a2 = unpack('h2);
SystemFaults system_faults_reserved1 = unpack('h4);
SystemFaults system_faults_reserved2 = unpack('h8);
SystemFaults system_faults_sp = unpack('h10);
SystemFaults system_faults_rot = unpack('h20);

instance DefaultValue#(RequestStatus);
    defaultValue = unpack('0);
endinstance

instance Bitwise#(RequestStatus);
    function RequestStatus \& (RequestStatus s1, RequestStatus s2) = unpack(pack(s1) & pack(s2));
    function RequestStatus \| (RequestStatus s1, RequestStatus s2) = unpack(pack(s1) | pack(s2));
    function RequestStatus \^ (RequestStatus s1, RequestStatus s2) = unpack(pack(s1) ^ pack(s2));
    function RequestStatus \~^ (RequestStatus s1, RequestStatus s2) = unpack(pack(s1) ~^ pack(s2));
    function RequestStatus \^~ (RequestStatus s1, RequestStatus s2) = unpack(pack(s1) ^~ pack(s2));
    function RequestStatus invert (RequestStatus s) = unpack(invert(pack(s)));

    function RequestStatus \<< (RequestStatus s, t x) =
        error("Left shift operation is not supported with type RequestStatus");
    function RequestStatus \>> (RequestStatus s, t x) =
        error("Right shift operation is not supported with type RequestStatus");
    function Bit#(1) msb (RequestStatus s) =
        error("msb operation is not supported with type RequestStatus");
    function Bit#(1) lsb (RequestStatus s) =
        error("lsb operation is not supported with type RequestStatus");
endinstance

RequestStatus request_status_none = defaultValue;
RequestStatus request_status_power_off_in_progress = unpack('h1);
RequestStatus request_status_power_on_in_progress = unpack('h2);
RequestStatus request_status_reset_in_progress = unpack('h4);

instance DefaultValue#(LinkEvents);
    defaultValue = unpack('0);
endinstance

instance Bitwise#(LinkEvents);
    function LinkEvents \& (LinkEvents e1, LinkEvents e2) = unpack(pack(e1) & pack(e2));
    function LinkEvents \| (LinkEvents e1, LinkEvents e2) = unpack(pack(e1) | pack(e2));
    function LinkEvents \^ (LinkEvents e1, LinkEvents e2) = unpack(pack(e1) ^ pack(e2));
    function LinkEvents \~^ (LinkEvents e1, LinkEvents e2) = unpack(pack(e1) ~^ pack(e2));
    function LinkEvents \^~ (LinkEvents e1, LinkEvents e2) = unpack(pack(e1) ^~ pack(e2));
    function LinkEvents invert (LinkEvents e) = unpack(invert(pack(e)));

    function LinkEvents \<< (LinkEvents e, t x) =
        error("Left shift operation is not supported with type LinkEvents");
    function LinkEvents \>> (LinkEvents e, t x) =
        error("Right shift operation is not supported with type LinkEvents");
    function Bit#(1) msb (LinkEvents e) =
        error("msb operation is not supported with type LinkEvents");
    function Bit#(1) lsb (LinkEvents e) =
        error("lsb operation is not supported with type LinkEvents");
endinstance

LinkEvents link_events_none = defaultValue;
LinkEvents link_events_encoding_error = unpack('h1);
LinkEvents link_events_decoding_error = unpack('h2);
LinkEvents link_events_ordered_set_invalid = unpack('h4);
LinkEvents link_events_message_version_invalid = unpack('h8);
LinkEvents link_events_message_type_invalid = unpack('h10);
LinkEvents link_events_message_checksum_invalid = unpack('h20);

instance DefaultValue#(LinkStatus);
    defaultValue = unpack('0);
endinstance

instance Bitwise#(LinkStatus);
    function LinkStatus \& (LinkStatus s1, LinkStatus s2) = unpack(pack(s1) & pack(s2));
    function LinkStatus \| (LinkStatus s1, LinkStatus s2) = unpack(pack(s1) | pack(s2));
    function LinkStatus \^ (LinkStatus s1, LinkStatus s2) = unpack(pack(s1) ^ pack(s2));
    function LinkStatus \~^ (LinkStatus s1, LinkStatus s2) = unpack(pack(s1) ~^ pack(s2));
    function LinkStatus \^~ (LinkStatus s1, LinkStatus s2) = unpack(pack(s1) ^~ pack(s2));
    function LinkStatus invert (LinkStatus s) = unpack(invert(pack(s)));

    function LinkStatus \<< (LinkStatus s, t x) =
        error("Left shift operation is not supported with type LinkStatus");
    function LinkStatus \>> (LinkStatus s, t x) =
        error("Right shift operation is not supported with type LinkStatus");
    function Bit#(1) msb (LinkStatus s) =
        error("msb operation is not supported with type LinkStatus");
    function Bit#(1) lsb (LinkStatus s) =
        error("lsb operation is not supported with type LinkStatus");
endinstance

LinkStatus link_status_disconnected = defaultValue;
LinkStatus link_status_connected = unpack('h3);
LinkStatus link_status_connected_polarity_inverted = unpack('h7);

//
// Status Message pretty printer
//

function Fmt message_status_pretty_format(Message m);
    function String indent0(String s) = "\n        " + s;
    function String indent1(String s) = "\n            " + s;
    function String indent2(String s) = "\n                " + s;

    let system_status =
        (m.Status.system_status.controller0_present ?
            $format(indent1("controller0_present")) :
            $format("")) +
        (m.Status.system_status.controller1_present ?
            $format(indent1("controller1_present")) :
            $format("")) +
        (m.Status.system_status.system_power_enabled ?
            $format(indent1("system_power_enabled")) :
            $format("")) +
        (m.Status.system_status.system_power_abort ?
            $format(indent1("system_power_abort")) :
            $format(""));

    let system_faults =
        (m.Status.system_faults.power_a3 ?
            $format(indent1("power_a3")) : $format("")) +
        (m.Status.system_faults.power_a2 ?
            $format(indent1("power_a2")) : $format("")) +
        (m.Status.system_faults.reserved1 ?
            $format(indent1("reserved1")) : $format("")) +
        (m.Status.system_faults.reserved2 ?
            $format(indent1("reserved2")) : $format("")) +
        (m.Status.system_faults.sp ?
            $format(indent1("sp")) : $format("")) +
        (m.Status.system_faults.rot ?
            $format(indent1("rot")) : $format(""));

    let request_status =
        (m.Status.request_status.power_off_in_progress ?
            $format(indent1("power_off_in_progress")) : $format("")) +
        (m.Status.request_status.power_on_in_progress ?
            $format(indent1("power_on_in_progress")) : $format("")) +
        (m.Status.request_status.reset_in_progress ?
            $format(indent1("reset_in_progress")) : $format(""));

    function Fmt format_link_status(LinkStatus s) =
        (s.receiver_aligned ?
            $format(indent1("receiver_aligned")) :
            $format("")) +
        (s.receiver_locked ?
            $format(indent1("receiver_locked")) :
            $format("")) +
        (s.polarity_inverted ?
            $format(indent1("polarity_inverted")) :
            $format(""));

    function Fmt format_link_events(LinkEvents e) =
        (e.encoding_error ?
            $format(indent1("encoding_error")) :
            $format("")) +
        (e.decoding_error ?
            $format(indent1("decoding_error")) :
            $format("")) +
        (e.ordered_set_invalid ?
            $format(indent1("ordered_set_invalid")) :
            $format("")) +
        (e.message_version_invalid ?
            $format(indent1("message_version_invalid")) :
            $format("")) +
        (e.message_type_invalid ?
            $format(indent1("message_type_invalid")) :
            $format("")) +
        (e.message_checksum_invalid ?
            $format(indent1("message_checksum_invalid")) :
            $format(""));

    return (
        $format("Status {") +
        (m.Status.system_type != 0 ?
            $format(indent0("system_type: %3d"), m.Status.system_type) :
            $format("")) +
        (m.Status.system_status != defaultValue ?
            $format(indent0("system_status:"), system_status) :
            $format("")) +
        (m.Status.system_faults != defaultValue ?
            $format(indent0("system_faults:"), system_faults) :
            $format("")) +
        (m.Status.request_status != defaultValue ?
            $format(indent0("request_status:"), request_status) :
            $format("")) +
        (m.Status.link0_status != defaultValue ?
            $format(indent0("link0_status:")) +
                format_link_status(m.Status.link0_status) :
            $format("")) +
        (m.Status.link0_events != defaultValue ?
            $format(indent0("link0_events:")) +
                format_link_events(m.Status.link0_events) :
            $format("")) +
        (m.Status.link1_status != defaultValue ?
            $format(indent0("link1_status:")) +
                format_link_status(m.Status.link1_status) :
            $format("")) +
        (m.Status.link1_events != defaultValue ?
            $format(indent0("link1_events:")) +
                format_link_events(m.Status.link1_events) :
            $format("")) +
        $format(" }"));
endfunction

endpackage
