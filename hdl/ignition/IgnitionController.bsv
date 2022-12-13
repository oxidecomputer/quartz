package IgnitionController;

export Parameters(..);
export ReadVolatile(..);
export LinkEventCounterRegisters(..);
export Registers(..);
export Interrupts(..);
export Status(..);
export Controller(..);

export mkController;
export registers;
export transceiver_client;
export register_pages;
export target_present;

// Interrupt helpers.
export interrupts_none;

import ConfigReg::*;
import Connectable::*;
import DefaultValue::*;
import DReg::*;
import GetPut::*;
import FIFO::*;
import Vector::*;

import Countdown::*;
import SchmittReg::*;
import Strobe::*;

import IgnitionControllerRegisters::*;
import IgnitionEventCounter::*;
import IgnitionProtocol::*;
import IgnitionTransceiver::*;


typedef struct {
    IgnitionProtocol::Parameters protocol;
} Parameters;

instance DefaultValue#(Parameters);
    defaultValue = Parameters {
        protocol: defaultValue};
endinstance

typedef struct {
} Interrupts deriving (Bits, Eq, FShow);

interface ReadVolatile#(type t);
    method ActionValue#(t) _read();
endinterface

interface LinkEventCounterRegisters;
    interface Reg#(IgnitionControllerRegisters::LinkEvents) summary;
    interface ReadVolatile#(IgnitionControllerRegisters::Counter) encoding_error;
    interface ReadVolatile#(IgnitionControllerRegisters::Counter) decoding_error;
    interface ReadVolatile#(IgnitionControllerRegisters::Counter) ordered_set_invalid;
    interface ReadVolatile#(IgnitionControllerRegisters::Counter) message_version_invalid;
    interface ReadVolatile#(IgnitionControllerRegisters::Counter) message_type_invalid;
    interface ReadVolatile#(IgnitionControllerRegisters::Counter) message_checksum_invalid;
endinterface

interface Registers;
    interface ReadOnly#(IgnitionControllerRegisters::ControllerStatus) controller_status;
    interface ReadOnly#(IgnitionControllerRegisters::LinkStatus) controller_link_status;
    interface ReadOnly#(IgnitionControllerRegisters::TargetSystemType) target_system_type;
    interface ReadOnly#(IgnitionControllerRegisters::TargetSystemStatus) target_system_status;
    interface ReadOnly#(IgnitionControllerRegisters::TargetSystemFaults) target_system_faults;
    interface ReadOnly#(IgnitionControllerRegisters::TargetRequestStatus) target_request_status;
    interface ReadOnly#(IgnitionControllerRegisters::LinkStatus) target_link0_status;
    interface ReadOnly#(IgnitionControllerRegisters::LinkStatus) target_link1_status;
    interface Reg#(IgnitionControllerRegisters::TargetRequest) target_request;
    interface ReadVolatile#(IgnitionControllerRegisters::Counter) controller_status_received_count;
    interface ReadVolatile#(IgnitionControllerRegisters::Counter) controller_hello_sent_count;
    interface ReadVolatile#(IgnitionControllerRegisters::Counter) controller_request_sent_count;
    interface ReadVolatile#(IgnitionControllerRegisters::Counter) controller_message_dropped_count;
    interface LinkEventCounterRegisters controller_link_counters;
    interface LinkEventCounterRegisters target_link0_counters;
    interface LinkEventCounterRegisters target_link1_counters;
endinterface

typedef struct {
    Bool target_present;
    Bool receiver_locked;
} Status deriving (Bits);

interface Controller;
    interface TransceiverClient txr;
    interface Registers registers;
    interface Reg#(Interrupts) interrupts;
    interface PulseWire tick_1khz;
    (* always_enabled *) method Status status();
endinterface

(* synthesize *)
module mkController #(Parameters parameters) (Controller);
    //
    // External pulse used to generate timed events.
    //
    Reg#(Bool) tick <- mkDReg(False);

    Reg#(LinkStatus) link_status <- mkRegU();
    Wire#(Message) rx <- mkWire();
    FIFO#(Message) tx <- mkLFIFO();

    // `CountingMonitors` keep track of link events occuring on the local
    // receiver as well as the two receivers on the `Target` side.
    CountingMonitor link_monitor <- mkCountingMonitor();
    CountingMonitor target_link0_monitor <- mkCountingMonitor();
    CountingMonitor target_link1_monitor <- mkCountingMonitor();

    // Additional Message counters.
    Counter n_status_received <- mkCounter();
    Counter n_hello_sent <- mkCounter();
    Counter n_request_sent <- mkCounter();
    Counter n_message_dropped <- mkCounter();

    // `Target` present indicator. This is implemented using a filter, requiring
    // three Status messages to be received before the `Target` is marked
    // present.
    Reg#(Bool) past_target_present <- mkReg(False);
    SchmittReg#(3, Bool) target_present <-
        mkSchmittReg(False, EdgePatterns {
            negative_edge: 'b100,
            positive_edge: 'b111,
            mask: 'b111});

    // The latest `Status` `Message` received from a `Target`. This should only
    // be considered valid if the `target_present` flag above is True.
    Reg#(Message) status_message <- mkRegU();

    // A pending `Request`, received upstream (software).
    ConfigReg#(Maybe#(Request)) pending_request <- mkConfigReg(tagged Invalid);

    //
    // Events
    //
    PulseWire message_accepted <- mkPulseWire();

    PulseWire status_received <- mkPulseWire();
    Countdown#(6) status_update_expired <- mkCountdownBy1();

    Countdown#(6) hello_expired <- mkCountdownBy1();
    Reg#(Bool) hello_requested <- mkReg(True);

    //
    // Connect the global tick
    //

    (* fire_when_enabled *)
    rule do_tick (tick);
        status_update_expired.send();
        hello_expired.send();
    endrule

    (* fire_when_enabled *)
    rule do_update_target_presence;
        if (status_received)
            target_present <= True;
        else if (status_update_expired) begin
            target_present <= False;
            $display("%5t [Controller] Target Status timeout", $time);
        end

        if (status_received || status_update_expired) begin
            status_update_expired <=
                fromInteger(parameters.protocol.status_interval + 2);
        end

        past_target_present <= target_present;

        if (past_target_present != target_present) begin
            let format = target_present ?
                "%5t [Controller] Target present" :
                "%5t [Controller] Target not present";
            $display(format, $time);
        end
    endrule

    (* fire_when_enabled *)
    rule do_receive_status_message (rx matches tagged Status .*);
        message_accepted.send();
        status_message <= rx;

        // Update the counters tracking Target side link events.
        target_link0_monitor.monitor(rx.Status.link0_events);
        target_link1_monitor.monitor(rx.Status.link1_events);

        n_status_received.send();
        status_received.send();

        $display(
            "%5t [Controller] Received ", $time,
            message_status_pretty_format(rx));
    endrule

    (* fire_when_enabled *)
    rule do_request_hello (!hello_requested && hello_expired);
        hello_requested <= True;
    endrule

    (* fire_when_enabled *)
    rule do_handle_hello_expired (hello_requested && !isValid(pending_request));
        tx.enq(tagged Hello);

        n_hello_sent.send();
        hello_expired <= fromInteger(parameters.protocol.hello_interval);
        hello_requested <= False;

        $display("%5t [Controller] Sent Hello", $time);
    endrule

    (* fire_when_enabled *)
    rule do_send_request (pending_request matches tagged Valid .request);
        tx.enq(tagged Request request);

        n_request_sent.send();
        pending_request <= tagged Invalid;

        $display("%5t [Controller] Sent Request ", $time, fshow(request));
    endrule

    (* fire_when_enabled *)
    rule do_drop_hello_message (rx matches tagged Hello);
        message_accepted.send();
        n_message_dropped.send();
        $display("%5t [Controller] Hello dropped", $time);
    endrule

    (* fire_when_enabled *)
    rule do_drop_request_message (rx matches tagged Request .request);
        message_accepted.send();
        n_message_dropped.send();
        $display("%5t [Controller] Request ", $time, fshow(request), " dropped");
    endrule

    let system_type =
        TargetSystemType {
            system_type: pack(status_message.Status.system_type.id)};

    let target_system_status = target_present ?
            pack(status_message.Status.system_status) :
            '0;

    interface TransceiverClient txr;
        interface GetS to_txr = fifoToGetS(tx);

        interface PutS from_txr;
            method offer = rx._write;
            method accepted = message_accepted;
        endinterface

        method Action monitor(LinkStatus status, LinkEvents events);
            link_status <= status;
            link_monitor.monitor(events);
        endmethod
    endinterface

    interface Registers registers;
        interface ReadOnly controller_status = valueToReadOnly(
            ControllerStatus {
                target_present: pack(target_present)});

        interface ReadOnly controller_link_status =
            valueToReadOnly(
                IgnitionControllerRegisters::LinkStatus {
                    receiver_aligned: pack(link_status.receiver_aligned),
                    receiver_locked: pack(link_status.receiver_locked),
                    polarity_inverted: pack(link_status.polarity_inverted)});

        interface ReadOnly target_system_type =
            castToReadOnlyIf(
                target_present,
                status_message.Status.system_type,
                defaultValue);

        interface ReadOnly target_system_status =
            castToReadOnlyIf(
                target_present,
                status_message.Status.system_status,
                defaultValue);

        interface ReadOnly target_system_faults =
            castToReadOnlyIf(
                target_present,
                status_message.Status.system_faults,
                defaultValue);

        interface ReadOnly target_request_status =
            castToReadOnlyIf(
                target_present,
                status_message.Status.request_status,
                defaultValue);

        interface ReadOnly target_link0_status =
            castToReadOnlyIf(
                target_present,
                status_message.Status.link0_status,
                defaultValue);

        interface ReadOnly target_link1_status =
            castToReadOnlyIf(
                target_present,
                status_message.Status.link1_status,
                defaultValue);

        interface Reg target_request;
            method TargetRequest _read();
                let kind = isValid(pending_request) ?
                        pack(fromMaybe(?, pending_request)) : 0;
                return TargetRequest {
                    kind: pack(kind),
                    pending: pack(isValid(pending_request))};
            endmethod

            method Action _write(TargetRequest request) if (!isValid(pending_request));
                let request_ =
                    case (request.kind)
                        1: tagged Valid SystemPowerOff;
                        2: tagged Valid SystemPowerOn;
                        3: tagged Valid SystemReset;
                        default: tagged Invalid;
                    endcase;
                pending_request <= request_;

                if (request_ matches tagged Valid .r)
                    $display(
                        "%5t [Controller] ", $time,
                        fshow(r), " Request pending");
                else
                    $display("%5t [Controller] Request kind %2d ignored", $time);
            endmethod
        endinterface

        interface ReadVolatile controller_status_received_count = readCounter(n_status_received);
        interface ReadVolatile controller_hello_sent_count = readCounter(n_hello_sent);
        interface ReadVolatile controller_request_sent_count = readCounter(n_request_sent);
        interface ReadVolatile controller_message_dropped_count = readCounter(n_message_dropped);
        interface LinkEventCounterRegisters controller_link_counters = asLinkEventCounterRegisters(link_monitor);
        interface LinkEventCounterRegisters target_link0_counters = asLinkEventCounterRegisters(target_link0_monitor);
        interface LinkEventCounterRegisters target_link1_counters = asLinkEventCounterRegisters(target_link1_monitor);
    endinterface

    interface Reg interrupts;
        method _read = defaultValue;
        method Action _write(Interrupts i);
        endmethod
    endinterface

    interface PulseWire tick_1khz;
        method _read = tick;
        method Action send();
            tick <= True;
        endmethod
    endinterface

    method status = Status {
        receiver_locked: link_status.receiver_locked,
        target_present: target_present};
endmodule

//
// Helpers
//

instance Connectable#(Transceiver, Controller);
    module mkConnection #(Transceiver txr, Controller c) (Empty);
        mkConnection(txr, c.txr);
    endmodule
endinstance

// Interrupts
Interrupts interrupts_none = unpack('0);

instance DefaultValue#(Interrupts);
    defaultValue = interrupts_none;
endinstance

instance Bitwise#(Interrupts);
    function Interrupts \& (Interrupts i1, Interrupts i2) =
        unpack(pack(i1) & pack(i2));
    function Interrupts \| (Interrupts i1, Interrupts i2) =
        unpack(pack(i1) | pack(i2));
    function Interrupts \^ (Interrupts i1, Interrupts i2) =
        unpack(pack(i1) ^ pack(i2));
    function Interrupts \~^ (Interrupts i1, Interrupts i2) =
        unpack(pack(i1) ~^ pack(i2));
    function Interrupts \^~ (Interrupts i1, Interrupts i2) =
        unpack(pack(i1) ^~ pack(i2));
    function Interrupts invert (Interrupts i) =
        unpack(invert(pack(i)));
    function Interrupts \<< (Interrupts i, t x) =
        error("Left shift operation is not supported with type Interrupts");
    function Interrupts \>> (Interrupts i, t x) =
        error("Right shift operation is not supported with type Interrupts");
    function Bit#(1) msb (Interrupts i) =
        error("msb operation is not supported with type Interrupts");
    function Bit#(1) lsb (Interrupts i) =
        error("lsb operation is not supported with type Interrupts");
endinstance

// Helpers used to map values/internal registers onto the register interface.
function ReadOnly#(t) valueToReadOnly(t val);
    return (
        interface ReadOnly
            method _read = val;
        endinterface);
endfunction

function ReadOnly#(v) castToReadOnly(t val)
        provisos (
            Bits#(t, t_sz),
            Bits#(v, v_sz),
            Add#(t_sz, _, v_sz));
    return (
        interface ReadOnly
            method _read = unpack(zeroExtend(pack(val)));
        endinterface);
endfunction

function ReadOnly#(v) castToReadOnlyIf(Bool pred, t val, t alt)
        provisos (
            Bits#(t, t_sz),
            Bits#(v, v_sz),
            Add#(t_sz, _, v_sz));
    return castToReadOnly(pred ? val : alt);
endfunction

function ReadVolatile#(IgnitionControllerRegisters::Counter)
        readCounter(ActionValue#(Count) c) =
    (interface ReadVolatile#(IgnitionControllerRegisters::Counter);
        method ActionValue#(IgnitionControllerRegisters::Counter) _read();
            let x <- c;
            return unpack(pack(x));
        endmethod
    endinterface);

function LinkEventCounterRegisters
        asLinkEventCounterRegisters(CountingMonitor monitor) =
    (interface LinkEventCounterRegisters;
        interface Reg summary;
            method _read = unpack(extend(pack(monitor.counters.summary)));
            method Action _write(IgnitionControllerRegisters::LinkEvents e) =
                monitor.counters.clear(unpack(truncate(pack(e))));
        endinterface
        interface ReadVolatile encoding_error = readCounter(monitor.counters.encoding_error);
        interface ReadVolatile decoding_error = readCounter(monitor.counters.decoding_error);
        interface ReadVolatile ordered_set_invalid = readCounter(monitor.counters.ordered_set_invalid);
        interface ReadVolatile message_version_invalid = readCounter(monitor.counters.message_version_invalid);
        interface ReadVolatile message_type_invalid = readCounter(monitor.counters.message_type_invalid);
        interface ReadVolatile message_checksum_invalid = readCounter(monitor.counters.message_checksum_invalid);
    endinterface);

function Registers registers(Controller c) = c.registers;

function Vector#(n, Registers) register_pages(Vector#(n, Controller) controllers) =
    map(registers, controllers);

function TransceiverClient transceiver_client(Controller c) = c.txr;

function Bool target_present(Controller c) = c.status.target_present;

endpackage
