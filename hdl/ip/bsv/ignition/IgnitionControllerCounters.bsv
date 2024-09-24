package IgnitionControllerCounters;

export ControllerCounters(..);
export CounterAddress(..);
export CounterId(..);
export Counter(..);
export CounterServer(..);
export CountableApplicationEvents(..);
export CountableTransceiverEvents(..);

export mkControllerCounters;
export determine_transceiver_events;
export countable_transceiver_events_receiver_reset;

import BRAMFIFO::*;
import BuildVector::*;
import ClientServer::*;
import FIFO::*;
import FIFOF::*;
import GetPut::*;
import Vector::*;

import CounterRAM::*;

import IgnitionControllerShared::*;
import IgnitionProtocol::*;

typedef enum {
    TargetPresent,
    TargetTimeout,
    StatusReceived,
    StatusTimeout,
    HelloSent,
    SystemPowerRequestSent,
    ControllerReceiverReset,
    ControllerReceiverAligned,
    ControllerReceiverLocked,
    ControllerReceiverPolarityInverted,
    ControllerEncodingError,
    ControllerDecodingError,
    ControllerOrderedSetInvalid,
    ControllerMessageVersionInvalid,
    ControllerMessageTypeInvalid,
    ControllerMessageChecksumInvalid,
    TargetLink0ReceiverReset,
    TargetLink0ReceiverAligned,
    TargetLink0ReceiverLocked,
    TargetLink0ReceiverPolarityInverted,
    TargetLink0EncodingError,
    TargetLink0DecodingError,
    TargetLink0OrderedSetInvalid,
    TargetLink0MessageVersionInvalid,
    TargetLink0MessageTypeInvalid,
    TargetLink0MessageChecksumInvalid,
    TargetLink1ReceiverReset,
    TargetLink1ReceiverAligned,
    TargetLink1ReceiverLocked,
    TargetLink1ReceiverPolarityInverted,
    TargetLink1EncodingError,
    TargetLink1DecodingError,
    TargetLink1OrderedSetInvalid,
    TargetLink1MessageVersionInvalid,
    TargetLink1MessageTypeInvalid,
    TargetLink1MessageChecksumInvalid
} CounterId deriving (Bits, Eq, FShow);

typedef struct {
    ControllerId#(n) controller;
    CounterId counter;
} CounterAddress#(numeric type n) deriving (Bits, Eq, FShow);

typedef UInt#(8) Counter;
typedef Server#(CounterAddress#(n), Counter) CounterServer#(numeric type n);

interface ControllerCounters#(numeric type n);
    interface CounterServer#(n) counters;

    method Action count_application_events(
            ControllerId#(n) controller,
            CountableApplicationEvents events);
    method Action count_transceiver_events(
            ControllerId#(n) controller,
            CountableTransceiverEvents events);
    method Action count_target_link0_events(
            ControllerId#(n) controller,
            CountableTransceiverEvents events);
    method Action count_target_link1_events(
            ControllerId#(n) controller,
            CountableTransceiverEvents events);

    // Flag indicating whether or not any counters are to be incremented.
    (* always_ready *) method Bool idle();
endinterface

module mkControllerCounters (ControllerCounters#(n));
    //
    // While processing software requests, tick- and receiver events the
    // Controller observes the occurance of countable events (apologies for
    // overloading the term "event" here). Examples include decoding or parse
    // errors observed by the receiver, the number of times a Target has become
    // present or timed out, the number of messages sent by the Controller, etc.
    // Counters associated with these events are stored per controller using a
    // BRAM (see `event_counters` below). These counters can be incremented one
    // at the time using a producer port and read by software using a consumer
    // port.
    //
    // A single event processed by the Controller may require several counters
    // to be incremented. Since the event hander is expected to process events
    // at a fixed three-cycle rate and it only needs to increment any counter by
    // one, instead of modifying the counters directly handler emits bit vectors
    // (stored in the `countable_*_events` FIFOs below) indicating which
    // counters need to be incremented.
    //
    // While the Controller has already completed the event, these countable
    // events vectors are then sequentially decoded into a specific counter
    // address and merged into a single BRAM backed FIFO (see
    // `increment_event_counter`). Counter addresses from this FIFO are then
    // processed one at the time, incrementing each counter using the producer
    // port of the counters BRAM.
    //
    // Decoding from the countable event vectors to individual counter addresses
    // is done somewhat in parallel but merged at one counter/cycle into the
    // final BRAM based FIFO. Bursts of vectors can be absorbed, but in order to
    // guarantee not blocking the event handler the countable_*_events FIFOs use
    // an unguarded enq side, allowing the Controller event handler to drop
    // previous vectors if they are not drained quickly enough avoiding a
    // handler stall. This will cause the counters to be undercounted, but the
    // overall Controller state will remain consistent.
    //
    // The counters in BRAM are saturating and will natarally undercount if
    // software is not collecting them in time, which makes event vectors being
    // dropped under a high workload an acceptable decision. The counters
    // therefor have "at least n observed occurances" semantics.
    //
    FIFOF#(CountableApplicationEventsWithId#(n))
            countable_application_events <- mkGFIFOF(True, False);
    FIFOF#(CountableTransceiverEventsWithId#(n))
            countable_transceiver_events <- mkGFIFOF(True, False);
    FIFOF#(CountableTransceiverEventsWithId#(n))
            countable_target_link0_events <- mkGFIFOF(True, False);
    FIFOF#(CountableTransceiverEventsWithId#(n))
            countable_target_link1_events <- mkGFIFOF(True, False);

    FIFOF#(CounterAddress#(n))
            increment_application_event_counter <- mkGLFIFOF(False, True);
    FIFOF#(CounterAddress#(n))
            increment_transceiver_event_counter <- mkGLFIFOF(False, True);
    FIFOF#(CounterAddress#(n))
            increment_target_link0_event_counter <- mkGLFIFOF(False, True);
    FIFOF#(CounterAddress#(n))
            increment_target_link1_event_counter <- mkGLFIFOF(False, True);
    FIFOF#(CounterAddress#(n))
            increment_event_counter <- mkSizedBRAMFIFOF(255);

    // Saturating 8 bit counters in BRAM, incremented by 1 per request.
    let n_counters = valueOf(TExp#(SizeOf#(CounterAddress#(n))));
    CounterRAM#(CounterAddress#(n), 8, 1)
            event_counters <- mkCounterRAM(n_counters);

    //
    // Event counters rules
    //

    Reg#(ControllerId#(n)) countable_application_events_id <- mkRegU();
    Reg#(CountableApplicationEvents)
            countable_application_events_remaining <- mkReg(0);

    (* fire_when_enabled *)
    rule do_deq_countable_application_events
            (countable_application_events_remaining == 0);
        countable_application_events_id <=
                countable_application_events.first.controller;
        countable_application_events_remaining <=
                countable_application_events.first.events;

        countable_application_events.deq();
    endrule

    (* fire_when_enabled *)
    rule do_decode_countable_application_events
            (countable_application_events_remaining != 0);
        Reg#(CountableApplicationEvents) events =
                countable_application_events_remaining;

        function increment(counter) =
            increment_application_event_counter.enq(
                    CounterAddress {
                        controller: countable_application_events_id,
                        counter: counter});

        if (events.status_received) begin
            events.status_received <= False;
            increment(StatusReceived);
        end
        else if (events.status_timeout) begin
            events.status_timeout <= False;
            increment(StatusTimeout);
        end
        else if (events.target_present) begin
            events.target_present <= False;
            increment(TargetPresent);
        end
        else if (events.target_timeout) begin
            events.target_timeout <= False;
            increment(TargetTimeout);
        end
        else if (events.hello_sent) begin
            events.hello_sent <= False;
            increment(HelloSent);
        end
        else if (events.system_power_request_sent) begin
            events.system_power_request_sent <= False;
            increment(SystemPowerRequestSent);
        end
    endrule

    Reg#(ControllerId#(n)) countable_transceiver_events_id <- mkRegU();
    Reg#(CountableTransceiverEvents)
            countable_transceiver_events_remaining <- mkReg(0);

    (* fire_when_enabled *)
    rule do_deq_countable_transceiver_events
            (countable_transceiver_events_remaining == 0);
        countable_transceiver_events_id <=
                countable_transceiver_events.first.controller;
        countable_transceiver_events_remaining <=
                countable_transceiver_events.first.events;

        countable_transceiver_events.deq();
    endrule

    (* fire_when_enabled *)
    rule do_decode_countable_transceiver_events
            (countable_transceiver_events_remaining != 0);
        Reg#(CountableTransceiverEvents) events =
                countable_transceiver_events_remaining;

        function increment(counter) =
            increment_transceiver_event_counter.enq(
                    CounterAddress {
                        controller: countable_transceiver_events_id,
                        counter: counter});

        if (events.encoding_error) begin
            events.encoding_error <= False;
            increment(ControllerEncodingError);
        end
        else if (events.decoding_error) begin
            events.decoding_error <= False;
            increment(ControllerDecodingError);
        end
        else if (events.ordered_set_invalid) begin
            events.ordered_set_invalid <= False;
            increment(ControllerOrderedSetInvalid);
        end
        else if (events.message_version_invalid) begin
            events.message_version_invalid <= False;
            increment(ControllerMessageVersionInvalid);
        end
        else if (events.message_type_invalid) begin
            events.message_type_invalid <= False;
            increment(ControllerMessageTypeInvalid);
        end
        else if (events.message_checksum_invalid) begin
            events.message_checksum_invalid <= False;
            increment(ControllerMessageChecksumInvalid);
        end
        else if (events.aligned) begin
            events.aligned <= False;
            increment(ControllerReceiverAligned);
        end
        else if (events.locked) begin
            events.locked <= False;
            increment(ControllerReceiverLocked);
        end
        else if (events.polarity_inverted) begin
            events.polarity_inverted <= False;
            increment(ControllerReceiverPolarityInverted);
        end
        else if (events.reset) begin
            events.reset <= False;
            increment(ControllerReceiverReset);
        end
    endrule

    Reg#(ControllerId#(n)) countable_target_link0_events_id <- mkRegU();
    Reg#(CountableTransceiverEvents)
            countable_target_link0_events_remaining <- mkReg(0);

    (* fire_when_enabled *)
    rule do_deq_countable_link0_events
            (countable_target_link0_events_remaining == 0);
        countable_target_link0_events_id <=
                countable_target_link0_events.first.controller;
        countable_target_link0_events_remaining <=
                countable_target_link0_events.first.events;

        countable_target_link0_events.deq();
    endrule

    (* fire_when_enabled *)
    rule do_decode_countable_target_link0_events
            (countable_target_link0_events_remaining != 0);
        Reg#(CountableTransceiverEvents) events =
                countable_target_link0_events_remaining;

        function increment(counter) =
            increment_target_link0_event_counter.enq(
                    CounterAddress {
                        controller: countable_target_link0_events_id,
                        counter: counter});

        if (events.encoding_error) begin
            events.encoding_error <= False;
            increment(TargetLink0EncodingError);
        end
        else if (events.decoding_error) begin
            events.decoding_error <= False;
            increment(TargetLink0DecodingError);
        end
        else if (events.ordered_set_invalid) begin
            events.ordered_set_invalid <= False;
            increment(TargetLink0OrderedSetInvalid);
        end
        else if (events.message_version_invalid) begin
            events.message_version_invalid <= False;
            increment(TargetLink0MessageVersionInvalid);
        end
        else if (events.message_type_invalid) begin
            events.message_type_invalid <= False;
            increment(TargetLink0MessageTypeInvalid);
        end
        else if (events.message_checksum_invalid) begin
            events.message_checksum_invalid <= False;
            increment(TargetLink0MessageChecksumInvalid);
        end
        else if (events.aligned) begin
            events.aligned <= False;
            increment(TargetLink0ReceiverAligned);
        end
        else if (events.locked) begin
            events.locked <= False;
            increment(TargetLink0ReceiverLocked);
        end
        else if (events.polarity_inverted) begin
            events.polarity_inverted <= False;
            increment(TargetLink0ReceiverPolarityInverted);
        end
        else if (events.reset) begin
            events.reset <= False;
            increment(TargetLink0ReceiverReset);
        end
    endrule

    Reg#(ControllerId#(n)) countable_target_link1_events_id <- mkRegU();
    Reg#(CountableTransceiverEvents)
            countable_target_link1_events_remaining <- mkReg(0);

    (* fire_when_enabled *)
    rule do_deq_countable_link1_events
            (countable_target_link1_events_remaining == 0);
        countable_target_link1_events_id <=
                countable_target_link1_events.first.controller;
        countable_target_link1_events_remaining <=
                countable_target_link1_events.first.events;

        countable_target_link1_events.deq();
    endrule

    (* fire_when_enabled *)
    rule do_decode_countable_target_link1_events
            (countable_target_link1_events_remaining != 0);
        Reg#(CountableTransceiverEvents) events =
                countable_target_link1_events_remaining;

        function increment(counter) =
            increment_target_link1_event_counter.enq(
                    CounterAddress {
                        controller: countable_target_link1_events_id,
                        counter: counter});

        if (events.encoding_error) begin
            events.encoding_error <= False;
            increment(TargetLink1EncodingError);
        end
        else if (events.decoding_error) begin
            events.decoding_error <= False;
            increment(TargetLink1DecodingError);
        end
        else if (events.ordered_set_invalid) begin
            events.ordered_set_invalid <= False;
            increment(TargetLink1OrderedSetInvalid);
        end
        else if (events.message_version_invalid) begin
            events.message_version_invalid <= False;
            increment(TargetLink1MessageVersionInvalid);
        end
        else if (events.message_type_invalid) begin
            events.message_type_invalid <= False;
            increment(TargetLink1MessageTypeInvalid);
        end
        else if (events.message_checksum_invalid) begin
            events.message_checksum_invalid <= False;
            increment(TargetLink1MessageChecksumInvalid);
        end
        else if (events.aligned) begin
            events.aligned <= False;
            increment(TargetLink1ReceiverAligned);
        end
        else if (events.locked) begin
            events.locked <= False;
            increment(TargetLink1ReceiverLocked);
        end
        else if (events.polarity_inverted) begin
            events.polarity_inverted <= False;
            increment(TargetLink1ReceiverPolarityInverted);
        end
        else if (events.reset) begin
            events.reset <= False;
            increment(TargetLink1ReceiverReset);
        end
    endrule

    Reg#(Vector#(4, Bool))
            increment_event_counter_source_select_base <- mkReg(unpack(1));

    (* fire_when_enabled *)
    rule do_merge_increment_counter_requests;
        let pending = vec(
                increment_application_event_counter.notEmpty,
                increment_transceiver_event_counter.notEmpty,
                increment_target_link0_event_counter.notEmpty,
                increment_target_link1_event_counter.notEmpty);

        let source_select =
                round_robin_select(
                    pending,
                    increment_event_counter_source_select_base);

        function Action deq_from(FIFOF#(CounterAddress#(n)) source) =
            action
                increment_event_counter.enq(source.first);
                source.deq();
                increment_event_counter_source_select_base <=
                        rotateR(source_select);
            endaction;

        if (source_select[0])
            deq_from(increment_application_event_counter);
        else if (source_select[1])
            deq_from(increment_transceiver_event_counter);
        else if (source_select[2])
            deq_from(increment_target_link0_event_counter);
        else if (source_select[3])
            deq_from(increment_target_link1_event_counter);
    endrule

    (* fire_when_enabled *)
    rule do_increment_counter;
        increment_event_counter.deq();
        event_counters.producer.request.put(
                CounterWriteRequest {
                    id: increment_event_counter.first,
                    op: Add,
                    amount: 1});
    endrule

    method count_application_events(controller, events) =
            countable_application_events.enq(
                CountableEventsWithId {
                    controller: controller,
                    events: events});
    method count_transceiver_events(controller, events) =
            countable_transceiver_events.enq(
                CountableEventsWithId {
                    controller: controller,
                    events: events});
    method count_target_link0_events(controller, events) =
            countable_target_link0_events.enq(
                CountableEventsWithId {
                    controller: controller,
                    events: events});
    method count_target_link1_events(controller, events) =
            countable_target_link1_events.enq(
                CountableEventsWithId {
                    controller: controller,
                    events: events});

    interface Server counters;
        interface Put request;
            method put(address) =
                    event_counters.consumer.request.put(
                        CounterReadRequest {
                            id: address,
                            clear: True});
        endinterface

        interface Get response = event_counters.consumer.response;
    endinterface

    method idle =
            !(countable_application_events.notEmpty ||
                countable_transceiver_events.notEmpty ||
                countable_target_link0_events.notEmpty ||
                countable_target_link1_events.notEmpty ||
                increment_application_event_counter.notEmpty ||
                increment_transceiver_event_counter.notEmpty ||
                increment_target_link0_event_counter.notEmpty ||
                increment_target_link1_event_counter.notEmpty ||
                increment_event_counter.notEmpty) &&
            countable_application_events_remaining == 0 &&
            countable_transceiver_events_remaining == 0 &&
            countable_target_link0_events_remaining == 0 &&
            countable_target_link1_events_remaining == 0 &&
            event_counters.producer.idle;
endmodule

typedef struct {
    Bool reset;
    Bool polarity_inverted;
    Bool locked;
    Bool aligned;
    Bool message_checksum_invalid;
    Bool message_type_invalid;
    Bool message_version_invalid;
    Bool ordered_set_invalid;
    Bool decoding_error;
    Bool encoding_error;
} CountableTransceiverEvents deriving (Bits, Eq, FShow);

instance Literal#(CountableTransceiverEvents);
    function CountableTransceiverEvents fromInteger(Integer x) =
            unpack(fromInteger(x));
    function Bool inLiteralRange(CountableTransceiverEvents e, Integer x) =
            fromInteger(x) <= pack(CountableTransceiverEvents'(unpack('1)));
endinstance

function CountableTransceiverEvents determine_transceiver_events(
        LinkStatus past_status,
        LinkStatus current_status,
        LinkEvents link_events,
        Bool infer_reset) =
    CountableTransceiverEvents {
        reset:
            (infer_reset &&
                past_status.polarity_inverted &&
                !current_status.polarity_inverted) ||
            (infer_reset &&
                past_status.receiver_locked &&
                !current_status.receiver_locked) ||
            (infer_reset &&
                past_status.receiver_aligned &&
                !current_status.receiver_aligned),
        polarity_inverted:
            !past_status.polarity_inverted &&
                current_status.polarity_inverted,
        locked:
            !past_status.receiver_locked &&
                current_status.receiver_locked,
        aligned:
            !past_status.receiver_aligned &&
                current_status.receiver_aligned,
        message_checksum_invalid: link_events.message_checksum_invalid,
        message_type_invalid: link_events.message_type_invalid,
        message_version_invalid: link_events.message_version_invalid,
        ordered_set_invalid: link_events.ordered_set_invalid,
        decoding_error: link_events.decoding_error,
        encoding_error: link_events.encoding_error};

CountableTransceiverEvents countable_transceiver_events_receiver_reset =
        CountableTransceiverEvents {
            reset: True,
            polarity_inverted: False,
            locked: False,
            aligned: False,
            message_checksum_invalid: False,
            message_type_invalid: False,
            message_version_invalid: False,
            ordered_set_invalid: False,
            decoding_error: False,
            encoding_error: False};

typedef struct {
    Bool system_power_request_sent;
    Bool hello_sent;
    Bool target_timeout;
    Bool target_present;
    Bool status_timeout;
    Bool status_received;
} CountableApplicationEvents deriving (Bits, Eq, FShow);

instance Literal#(CountableApplicationEvents);
    function CountableApplicationEvents fromInteger(Integer x) =
            unpack(fromInteger(x));
    function Bool inLiteralRange(CountableApplicationEvents e, Integer x) =
            fromInteger(x) <= pack(e);
endinstance

typedef struct {
    ControllerId#(n) controller;
    events_type events;
} CountableEventsWithId#(numeric type n, type events_type)
    deriving (Bits, FShow);

typedef CountableEventsWithId#(n, CountableTransceiverEvents)
        CountableTransceiverEventsWithId#(numeric type n);

typedef CountableEventsWithId#(n, CountableApplicationEvents)
        CountableApplicationEventsWithId#(numeric type n);

endpackage
