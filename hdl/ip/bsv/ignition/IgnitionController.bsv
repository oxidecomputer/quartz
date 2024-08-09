package IgnitionController;

export Parameters(..);
export Controller(..);
export ControllerId(..);
export RegisterId(..);
export RegisterRequest_$op(..);
export RegisterRequest(..);
export Registers(..);
export CounterAddress(..);
export CounterId(..);
export Counter(..);
export Counters(..);
export TransmitterOutputEnableMode(..);

export mkController;
export read_controller_register_into;
export clear_controller_counter;
export read_controller_counter_into;
export transceiver_state_value;

import BRAMCore::*;
import BRAMFIFO::*;
import BuildVector::*;
import ClientServer::*;
import ConfigReg::*;
import Connectable::*;
import DefaultValue::*;
import FIFO::*;
import FIFOF::*;
import GetPut::*;
import StmtFSM::*;
import Vector::*;

import CounterRAM::*;

import IgnitionControllerRegisters::*;
import IgnitionProtocol::*;
import IgnitionReceiver::*;
import IgnitionTransceiver::*;
import IgnitionTransmitter::*;


typedef struct {
    Integer tick_period;
    Integer transmitter_output_disable_timeout;
    IgnitionProtocol::Parameters protocol;
} Parameters;

instance DefaultValue#(Parameters);
    defaultValue = Parameters {
        tick_period: 1000,
        transmitter_output_disable_timeout: 100,
        protocol: defaultValue};
endinstance

typedef UInt#(TLog#(n)) ControllerId#(numeric type n);

typedef enum {
    TransceiverState = 0,
    ControllerState,
    TargetSystemType,
    TargetSystemStatus,
    TargetSystemEvents,
    TargetSystemPowerRequestStatus,
    TargetLink0Status,
    TargetLink1Status
} RegisterId deriving (Bits, Eq, FShow);

typedef struct {
    ControllerId#(n) id;
    RegisterId register;
    union tagged {
        void Read;
        Bit#(8) Write;
    } op;
} RegisterRequest#(numeric type n) deriving (Bits, FShow);

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

typedef Server#(RegisterRequest#(n), Bit#(8)) Registers#(numeric type n);
typedef Server#(CounterAddress#(n), Counter) Counters#(numeric type n);

typedef enum {
    Disabled = 0,
    EnabledWhenReceiverAligned = 1,
    EnabledWhenTargetPresent = 2,
    AlwaysEnabled = 3
} TransmitterOutputEnableMode deriving (Bits, Eq, FShow);

// An interface for a Controller with `n` "channels" which processes events
// submitted by a receiver, answers requests from upstack software and generates
// events for a transmitter.
interface Controller #(numeric type n);
    // Strobe used to drive timers and generate internal events.
    method Action tick_1mhz();

    // Transceiver interface
    interface ControllerTransceiverClient#(n) txr;

    // Software interface
    interface Registers#(n) registers;
    interface Counters#(n) counters;
    // A bit vector indicating which channels have a `Target` present.
    method Vector#(n, Bool) presence_summary();

    // Debug
    (* always_ready *) method Bool idle();
endinterface

//
// mkController
//
// This is the second iteration of the Ignition Controller and an implementation
// of the multi-channel `Controller(..)` interface using a series of RAM
// elements to track the state of `n` Target systems. The first iteration of the
// Controller implemented all logic per channel, only time-multiplexing some
// parts of the receiver, resulting in very high device utilization of the ECP5
// FPGA running the design when synthesizing up to 36 copies. This second
// iteration in contrast aims to do as much work in a serial and
// time-multiplexed manner by making use of the relatively slow baudrate of the
// link between Controller and Target. This results in far fewer copies of most
// logic blocks resulting in much lower FPGA device utilization while expanding
// the feature set.
//
// The following calculations are used to justify this design:
//
// Both the Controller and Target are operating at a 50 MHz design clock.
// Messages are exchanged between the systems using an 8B10B encoded serial
// link, operating at 10 MBit/s. Message bytes are encoded using 10 bit symbols
// resulting in a symbol rate of 1M symbols/s/receiver, or a combined 36M
// symbols/s for the current maximum of 36 channels.
//
// The receiver is pipelined such that it deserializes bits into symbols in
// parallel and then processes all symbols in serial at a rate of one
// symbol/clock cycle. At a 50 MHz design clock this results in a peak sustained
// throughput of 50M symbols/s, which is well below the required 36M symbols/s
// generated by all 36 receivers. Note that due to clock jitter between the two
// systems a symbol period of 50 cycles is not strictly true and some symbols
// may last 49 or 51 clock cycles. But 50 cycles makes for convenient math and
// is expected to be true on average.
//
// Not all symbols however need to be processed by the Controller as it is only
// concerned with Target data. Framing and clock recovery symbols transmitted
// between messages are only useful to the receiver and can be dropped once
// observed.
//
// The current transmitter implementation will transmit at most three Target
// Status messages back to back after which it is required to transmit an Idle1
// and Idle2 ordered set consisting of two symbols each for clock recovery
// purposes. Each Status message consists of a start symbol, version and message
// types symbols, eight data symbols, a checksum symbol and two end of message
// symbols for a total of 12 symbols. See the `IgnitionProtocol` package and
// `TransmitterTests` for more details.
//
// For each Status message received the receiver emits eight symbol events and a
// nineth "message received" event to the Controller. For a sequence of three
// Status messages followed by two Idle sets making up 40 transmitted symbols
// the receiver therefor emits 27 events to the Controller. Given a symbol rate
// of 1M symbol/s each receiver can generate 675k events/s and 36 such receivers
// can generate at total of 24.3M events/s.
//
// Each event emitted by the receiver is handled in a fixed three clock cycles
// by the Controller. Operating at 50 MHz it can thus process up to 16.66M
// event/s. This falls short of the combined 24.3M events which can be
// generated, but this would be a worst case scenario where every Target would
// generate Status messages at line rate.
//
// In practice we expect each Target to emit less than half of that number of
// messages and certainly not for a sustained period of time. The expectation is
// that with some appropriately sized FIFOs between the receiver and Controller
// it can keep up with realistic workload. Note that the Controller generates an
// additional 1000 tick events/channel used to generate timeout events and needs
// cycles to respond to software requests, but these are expected to consume at
// most 1-2% of available event cycles leaving enough allocated for receiver
// events.
//
// If more event processing throughput is required or if the number of channels
// is increased a second copy of the Controller could be instantiated with each
// handling half of the channels. This would double aggregate event processing
// throughput. The cost of an additional Controller handling half the channels
// and splitting the transceivers may be acceptable.
//
// Additional design details are explained below when logic elements are
// declared.
//
module mkController #(
            Parameters parameters,
            Bool zero_registers)
                (Controller#(n));
    let status_message_timeout_reset_value =
            fromInteger(parameters.protocol.status_interval + 1);

    //
    // Event handler FIFOs
    //
    // FIFOs used to receive software requests, internally generated tick events
    // and receiver events respectively. These FIFOs have an guarded enq side
    // and unguarded deq side. This allows the enq side to be connected to
    // external logic with the implicit guards providing automatic backpressure
    // while the deq side of all three FIFOs can be used in a single rule
    // without those rules getting (implicitely) blocked by the scheduler if one
    // of the FIFOs is empty.
    //
    FIFOF#(RegisterRequest#(n)) software_request <- mkGFIFOF(False, True);
    FIFOF#(ControllerId#(n)) tick_events <- mkGFIFOF(False, True);
    FIFOF#(ReceiverEvent#(n)) receiver_events <- mkGFIFOF(False, True);

    //
    // Output FIFOs holding the results produced when processing software
    // requests, tick- and receiver events. Note that these FIFOs are implicitly
    // guarded causing the event handler rules and downstream events to block if
    // they are not emptied by upstream logic in a timely fashion.
    //
    FIFOF#(Bit#(8)) software_response <- mkFIFOF();
    FIFOF#(TransmitterEvent#(n)) transmitter_events <- mkFIFOF();

    let event_handler_idle =
            !(software_request.notEmpty ||
                tick_events.notEmpty ||
                receiver_events.notEmpty);

    //
    // Register files holding the per-Controller state
    //
    // Upon receiving an event the Controller is expected to select the
    // registers in the register files according to the controller id attached
    // to the event. The handler then waits one cycle for the RAM outputs to
    // become valid, handles the event on the third cycle and writes back the
    // registers while the next event is selected. This allows an event to be
    // processed every three cycles.
    //
    // In order to keep the state in the receiver as minimal as possible
    // multi-byte Status messages sent by Targets are streamed to the Controller
    // one byte at the time as they are decoded and parsed. But the receiver
    // does not yet know if the whole Status message is valid until it has
    // decoded and parsed all bytes and the required checksum. In order to store
    // these in-progress Status messages, some register files double buffer
    // their data using an active/inactive value slot.
    //
    // The bytes for an incoming Status message are written to the inactive
    // value slots, while software requests for the Status data are read from
    // the active value slots. Once the receiver has successfully parsed the
    // whole message it emits an event indicating so, at which point the buffer
    // pointer stored in the `presence` register is updated. The Controller
    // state is updated with the now active values and subsequent software
    // requests will read the new Status data.
    //
    // If a complete and valid Status message is not received by the receiver
    // the buffer pointer is never updated and the next Status message will
    // simply overwrite the partial previous message in inactive slots.
    //
    RegisterFile#(n, PresenceRegister) presence <- mkBRAMRegisterFile();
    RegisterFile#(n, TransceiverRegister) transceiver <- mkBRAMRegisterFile();
    RegisterFile#(n, HelloTimerRegister) hello_timer <- mkBRAMRegisterFile();
    BufferedValueRegisterFile#(n, SystemType)
            target_system_type <- mkBRAMRegisterFile();
    BufferedValueRegisterFile#(n, SystemStatus)
            target_system_status <- mkBRAMRegisterFile();
    BufferedValueRegisterFile#(n, SystemFaults)
            target_system_events <- mkBRAMRegisterFile();
    BufferedValueRegisterFile#(n, RequestStatus)
            target_system_power_request_status <- mkBRAMRegisterFile();
    BufferedValueRegisterFile#(n, LinkStatus)
            target_link0_status <- mkBRAMRegisterFile();
    BufferedValueRegisterFile#(n, LinkEvents)
            target_link0_events <- mkBRAMRegisterFile();
    BufferedValueRegisterFile#(n, LinkStatus)
            target_link1_status <- mkBRAMRegisterFile();
    BufferedValueRegisterFile#(n, LinkEvents)
            target_link1_events <- mkBRAMRegisterFile();

    // While updating the presence flag for each Target, a read-only copy is
    // kept in a summary vector, which can be read by software to determine
    // which channels to query for data.
    Vector#(n, Reg#(Bool)) presence_summary_r <- replicateM(mkConfigReg(False));

    //
    // Event counter state
    //
    // While processing software requests and tick- and receiver events the
    // event handler observes the occurance of countable events (apologies for
    // overloading the term "event" here). Examples include decoding- or parse
    // errors observed by the receiver, the number of times a Target has become
    // present or timed out, the number of messages sent by the Controller, etc.
    // Counters associated with these events are stored per Controller using a
    // BRAM (see `event_counters` below), which exposes a single producer port
    // used to read/modify/write their values one at the time.
    //
    // A single event processed by the event handler however may require several
    // counters to be incremented. And since the hander is expected to process
    // events at a fixed three-cycle rate and it only needs to increment any
    // counter by one, the event handler instead emits bit vectors (stored in
    // the `countable_*_events` FIFOs below) indicating which counters need to
    // be incremented.
    //
    // While the event handler has already completed the event, these countable
    // events vectors are then sequentially decoded into their respective
    // counter address and merged into a single BRAM backed FIFO (see
    // `increment_event_counter`). This FIFO is then emptied incrementing each
    // counter using the producer port of the counters BRAM.
    //
    // Decoding from the countable event vectors to individual counter addresses
    // is done somewhat in parallel but merged at one counter/cycle into the
    // final BRAM based FIFO. Bursts of vectors can be absorbed, but in order to
    // guarantee not blocking the event handler the countable_*_events FIFOs use
    // an unguarded enq side, allowing the event handler to overwrite previous
    // vectors if they are not drained quickly enough. This will cause the
    // counters to be undercount, but the overall Controller state will remain
    // consistent.
    //
    // The counters in BRAM are saturating and will natarally
    // undercount if software is not collecting them in time which makes event
    // vectors being dropped under a high workload an acceptable decision. As
    // such the counters have "at least n observed occurances" semantics.
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

    // Event handler state
    Reg#(EventHandlerState) event_handler_state <- mkReg(AwaitingEvent);
    Reg#(EventHandlerState) event_handler_select <- mkRegU();
    Reg#(ControllerId#(n)) current_controller <- mkRegU();

    PulseWire tick <- mkPulseWire();
    Reg#(UInt#(10)) tick_count <- mkReg(0);

    //
    // Register file init
    //
    // The register files may be initialized with random data upon reset. This
    // reset sequence will reset all registers to zero and then not run again.
    // If this module is part of a design targeting a device which clears BRAMs
    // on PoR, `init` can be set to False during elaboration which will optimize
    // this away.
    //
    Reg#(Bool) init_complete <- mkReg(!zero_registers);

    if (zero_registers) begin
        Reg#(ControllerId#(n)) i <- mkReg(0);

        FSM init_seq <- mkFSMWithPred(seq
            repeat(fromInteger(valueof(n))) action
                // Select the registers for each Controller in sequence..
                presence.select(i);
                transceiver.select(i);
                hello_timer.select(i);

                target_system_type.select(i);
                target_system_status.select(i);
                target_system_events.select(i);
                target_system_power_request_status.select(i);
                target_link0_status.select(i);
                target_link0_events.select(i);
                target_link1_status.select(i);
                target_link1_events.select(i);

                // .. and reset the their values.
                //
                // A read-modify-write sequence is not needed so the select and
                // write-back of the registers can happen in the same cycle.
                presence <= unpack('0);
                transceiver <= unpack('0);
                hello_timer <= unpack('0);

                target_system_type <= unpack('0);
                target_system_status <= unpack('0);
                target_system_events <= unpack('0);
                target_system_power_request_status <= unpack('0);
                target_link0_status <= unpack('0);
                target_link0_events <= unpack('0);
                target_link1_status <= unpack('0);
                target_link1_events <= unpack('0);

                i <= i + 1;
            endaction
            init_complete <= True;
        endseq, !init_complete);

        (* fire_when_enabled *)
        rule do_init (!init_complete);
            init_seq.start();
        endrule
    end

    //
    // Generate Tick events
    //
    // Each Controller channel requires a 1 KHz tick in order to generate
    // timeouts and send periodic Hello messages. These ticks are generated
    // using a single counter and the rules below, enqueueing Tick events for
    // each channel into a FIFO when appropriate.
    //
    // These Tick events are handled by the event handler with relatively high
    // priority, so in order to not starve other events from being handled by a
    // burst of Tick events for many channels, the ticks for the different
    // channels are generated with a phase offset by dividing the available 1000
    // microseconds by `n` channels.
    //
    // Note that in order to reduce the time between ticks during simulation the
    // total tick period which gets divided can be configured through the
    // `Parameters` used when constructing the `Controller`.
    //
    (* fire_when_enabled *)
    rule do_tick (init_complete && tick);
        let wrap = tick_count == fromInteger(parameters.tick_period - 1);
        tick_count <= wrap ? 0 : tick_count + 1;
    endrule

    let tick_phase_shift = parameters.tick_period / valueof(n);

    // Per channel rule which generates a Tick event for the given channel when
    // the counter hits the count for the determined phase offset.
    for (Integer i = 0; i < valueof(n); i = i + 1) begin
        (* fire_when_enabled *)
        rule do_enq_tick_event (
                init_complete &&
                tick &&
                tick_count == fromInteger(i * tick_phase_shift));
            tick_events.enq(fromInteger(i));
        endrule
    end

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
                countable_application_events.first.id;
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
                countable_transceiver_events.first.id;
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
                countable_target_link0_events.first.id;
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
                countable_target_link1_events.first.id;
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

    let event_counting_idle =
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

    //
    // Event handler rules
    //

    function Action enq_countable_application_events(
            CountableApplicationEvents events) =
        countable_application_events.enq(
                CountableApplicationEventsWithId {
                    id: current_controller,
                    events: events});

    function Action enq_countable_transceiver_events(
            CountableTransceiverEvents events) =
        countable_transceiver_events.enq(
                CountableTransceiverEventsWithId {
                    id: current_controller,
                    events: events});

    (* fire_when_enabled *)
    rule do_start_event_handler (
            init_complete &&
            event_handler_state == AwaitingEvent);
        // Get the Controller id for the next pending event. If no event is
        // pending the `Invalid` variant will keep the event handler waiting
        // until one arrives.
        let maybe_controller_id = tagged Invalid;

        if (software_request.notEmpty) begin
            event_handler_select <= HandlingSoftwareRequest;
            maybe_controller_id = tagged Valid software_request.first.id;
        end
        else if (tick_events.notEmpty) begin
            event_handler_select <= HandlingTickEvent;
            maybe_controller_id = tagged Valid tick_events.first;
        end
        else if (receiver_events.notEmpty) begin
            event_handler_select <= HandlingReceiverEvent;
            maybe_controller_id = tagged Valid receiver_events.first.id;
        end

        // If an event is pending, request the Controller state to be read by
        // setting the id in all register files. This will automatically cause a
        // read of each register file on the next clock cycle.
        if (maybe_controller_id matches tagged Valid .id) begin
            current_controller <= id;

            presence.select(id);
            transceiver.select(id);
            hello_timer.select(id);

            target_system_type.select(id);
            target_system_status.select(id);
            target_system_events.select(id);
            target_system_power_request_status.select(id);
            target_link0_status.select(id);
            target_link0_events.select(id);
            target_link1_status.select(id);
            target_link1_events.select(id);

            event_handler_state <= ReadingRegisters;
        end
    endrule

    (* fire_when_enabled *)
    rule do_read_registers (
            init_complete &&
            event_handler_state == ReadingRegisters);
        // Select the appropriate handler.
        event_handler_state <= event_handler_select;
    endrule

    (* fire_when_enabled *)
    rule do_handle_software_request (
            init_complete &&
            software_request.notEmpty &&
            event_handler_state == HandlingSoftwareRequest);
        function Action respond_with(value_t value)
                provisos (
                    Bits#(value_t, value_t_sz),
                    Add#(value_t_sz, a__, 8),
                    FShow#(value_t)) =
            software_response.enq(extend(pack(value)));

        function Action respond_with_current(
                RegisterFile#(n, Vector#(2, value_t)) file)
                    provisos (
                        Bits#(value_t, value_t_sz),
                        Add#(value_t_sz, a__, 8),
                        DefaultValue#(value_t)) =
            software_response.enq(extend(pack(
                    presence.present ?
                        file[presence.current_status_message] :
                        defaultValue)));

        case (tuple2(
                software_request.first.op,
                software_request.first.register)) matches
            {tagged Read, TransceiverState}:
                respond_with(pack(transceiver)[5:0]);

            {tagged Write .b, TransceiverState}: begin
                TransceiverRegister request = unpack(extend(b));
                TransceiverRegister transceiver_ = transceiver;

                transceiver_.transmitter_output_enable_mode =
                        request.transmitter_output_enable_mode;

                case (request.transmitter_output_enable_mode)
                    Disabled: begin
                        transceiver_.transmitter_output_disable_timeout_ticks_remaining = 0;
                        transceiver_.transmitter_output_enabled = False;
                    end

                    EnabledWhenReceiverAligned:
                        if (transceiver.receiver_status.receiver_aligned) begin
                            transceiver_.transmitter_output_disable_timeout_ticks_remaining = 0;
                            transceiver_.transmitter_output_enabled = True;
                        end
                        else if (transceiver.transmitter_output_enabled &&
                                    transceiver.transmitter_output_disable_timeout_ticks_remaining == 0) begin
                            transceiver_.transmitter_output_disable_timeout_ticks_remaining =
                                fromInteger(parameters.transmitter_output_disable_timeout);
                        end

                    EnabledWhenTargetPresent:
                        if (presence.present) begin
                            transceiver_.transmitter_output_disable_timeout_ticks_remaining = 0;
                            transceiver_.transmitter_output_enabled = True;
                        end
                        else if (transceiver.transmitter_output_enabled &&
                                    transceiver.transmitter_output_disable_timeout_ticks_remaining == 0) begin
                            transceiver_.transmitter_output_disable_timeout_ticks_remaining =
                                fromInteger(parameters.transmitter_output_disable_timeout);
                        end

                    AlwaysEnabled: begin
                        transceiver_.transmitter_output_disable_timeout_ticks_remaining = 0;
                        transceiver_.transmitter_output_enabled = True;
                    end
                endcase

                $display("%5t [Controller %02d] Transmitter output enable mode ",
                        $time,
                        current_controller,
                        fshow(transceiver_.transmitter_output_enable_mode));

                if (transceiver.transmitter_output_enabled &&
                        !transceiver_.transmitter_output_enabled) begin
                    $display("%5t [Controller %02d] Transmitter output disabled",
                            $time,
                            current_controller);
                end
                else if (!transceiver.transmitter_output_enabled &&
                        transceiver_.transmitter_output_enabled) begin
                    $display("%5t [Controller %02d] Transmitter output enabled",
                            $time,
                            current_controller);
                end

                // Update the transceiver register. Any changes are applied on
                // the next tick event. See `do_handle_tick_event`.
                transceiver <= transceiver_;
            end

            {tagged Read, ControllerState}:
                respond_with(presence.present);

            {tagged Read, TargetSystemType}:
                respond_with_current(target_system_type);

            {tagged Read, TargetSystemStatus}:
                respond_with_current(target_system_status);

            {tagged Read, TargetSystemEvents}:
                respond_with_current(target_system_events);

            {tagged Read, TargetSystemPowerRequestStatus}:
                respond_with_current(
                    target_system_power_request_status);

            {tagged Write .b, TargetSystemPowerRequestStatus}: begin
                let maybe_request =
                        case (b[5:4])
                            1: tagged Valid SystemPowerOff;
                            2: tagged Valid SystemPowerOn;
                            3: tagged Valid SystemPowerReset;
                            default: tagged Invalid;
                        endcase;

                if (presence.present &&&
                        maybe_request matches tagged Valid .request) begin
                    $display("%5t [Controller %02d] Requesting ",
                            $time,
                            current_controller, fshow(request));

                    transmitter_events.enq(
                            TransmitterEvent {
                                id: current_controller,
                                ev: tagged Message tagged Request request});

                    enq_countable_application_events(
                            CountableApplicationEvents {
                                status_received: False,
                                status_timeout: False,
                                target_present: False,
                                target_timeout: False,
                                hello_sent: False,
                                system_power_request_sent: True});
                end
            end

            {tagged Read, TargetLink0Status}:
                respond_with_current(target_link0_status);

            {tagged Read, TargetLink1Status}:
                respond_with_current(target_link1_status);
        endcase

        software_request.deq();
        event_handler_state <= AwaitingEvent;
    endrule

    (* fire_when_enabled *)
    rule do_handle_tick_event (
            init_complete &&
            tick_events.notEmpty &&
            event_handler_state == HandlingTickEvent);
        let status_timeout = False;
        let target_timeout = False;
        let hello_sent = False;

        // Copy the `presence` and `transceiver` registers so indiviual fields
        // can be updated as appropriate.
        let presence_ = presence;
        let transceiver_ = transceiver;

        // Update the presence history if a Status message timeout occures.
        if (presence.status_message_timeout_ticks_remaining == 0) begin
            $display("%5t [Controller %02d] Target Status timeout",
                    $time,
                    current_controller);

            // Add a timeout to the presence history.
            presence_.history = shiftInAt0(presence.history, False);

            // Reset the timeout counter.
            presence_.status_message_timeout_ticks_remaining =
                    status_message_timeout_reset_value;

            status_timeout = True;
        end
        // Count down the Status message timeout counter.
        else begin
            presence_.status_message_timeout_ticks_remaining =
                presence.status_message_timeout_ticks_remaining - 1;
        end

        // Update the filtered presence bit given the new history.
        if (pack(presence_.history) == 'b000 && presence.present) begin
            $display("%5t [Controller %02d] Target not present",
                    $time,
                    current_controller);

            target_timeout = True;
            presence_.present = False;
        end

        // Write back the presence state.
        presence <= presence_;
        presence_summary_r[current_controller] <= presence_.present;

        // Count down until the next Hello.
        if (hello_timer.ticks_remaining == 0) begin
            hello_timer.ticks_remaining <=
                    fromInteger(parameters.protocol.hello_interval);
        end
        else begin
            hello_timer.ticks_remaining <= hello_timer.ticks_remaining - 1;
        end

        // Count down the transmitter disable timeout if the counter is active.
        if (transceiver.transmitter_output_disable_timeout_ticks_remaining != 0) begin
            transceiver_.transmitter_output_disable_timeout_ticks_remaining =
                transceiver.transmitter_output_disable_timeout_ticks_remaining - 1;
        end
        // Start the disable timeout counter if the Target has been declared not
        // present.
        else if (transceiver.transmitter_output_enable_mode ==
                        EnabledWhenTargetPresent &&
                    presence.present &&
                    !presence_.present) begin
            transceiver_.transmitter_output_disable_timeout_ticks_remaining =
                fromInteger(parameters.transmitter_output_disable_timeout);
        end

        // Disable the transmitter output if the transmitter disable output
        // timer expires. A count of one is used as the timeout here since this
        // does not have to be precise and allows a value of zero to indicate
        // the counter is not active.
        if (transceiver.transmitter_output_enabled &&
                transceiver.transmitter_output_disable_timeout_ticks_remaining == 1) begin
            $display("%5t [Controller %02d] Transmitter output disabled",
                    $time,
                    current_controller);

            transceiver_.transmitter_output_enabled = False;
        end

        // Write back the transceiver state.
        transceiver <= transceiver_;

        // Transmit an Hello message if the Hello timer expires.
        if (hello_timer.ticks_remaining == 0) begin
            $display("%5t [Controller %02d] Hello",
                    $time,
                    current_controller);

            transmitter_events.enq(
                    TransmitterEvent {
                        id: current_controller,
                        ev: tagged Message tagged Hello});

            hello_sent = True;
        end
        // Transmit an OutputEnable event otherwise. These are sent every tick
        // so that even if a state change in the output enable is requested
        // during the same tick as the Hello message above the state will
        // converge at most one tick later.
        else begin
            transmitter_events.enq(
                    TransmitterEvent {
                        id: current_controller,
                        ev: tagged OutputEnabled
                            transceiver_.transmitter_output_enabled});
        end

        // Enqueue a request to update the appropriate counters.
        if (status_timeout || target_timeout || hello_sent) begin
            enq_countable_application_events(
                    CountableApplicationEvents {
                        status_received: False,
                        status_timeout: status_timeout,
                        target_present: False,
                        target_timeout: target_timeout,
                        hello_sent: hello_sent,
                        system_power_request_sent: False});
        end

        // Complete the tick event.
        tick_events.deq();
        event_handler_state <= AwaitingEvent;
    endrule

    (* fire_when_enabled *)
    rule do_handle_receiver_event (
            init_complete &&
            receiver_events.notEmpty &&
            event_handler_state == HandlingReceiverEvent);
        case (receiver_events.first.ev) matches
            tagged TargetStatusReceived: begin
                $display("%5t [Controller %02d] Received Status",
                        $time,
                        current_controller);

                PresenceRegister presence_ = presence;
                Bool target_present = False;

                // Make the last Status message active by flipping the
                // Status message pointer.
                presence_.current_status_message =
                        presence.current_status_message + 1;

                // Reset the Status timeout counter.
                presence_.status_message_timeout_ticks_remaining =
                        status_message_timeout_reset_value;

                // Update the presence history.
                presence_.history = shiftInAt0(presence.history, True);

                if (pack(presence_.history) == 3'b001 &&
                        !presence.present) begin
                    $display("%5t [Controller %02d] Target present",
                            $time,
                            current_controller);

                    presence_.present = True;
                    target_present = True;
                end

                // Write back the presence state.
                presence <= presence_;
                presence_summary_r[current_controller] <= presence_.present;

                // Update the transmitter output enabled state if configured.
                // The actual TransmitterEvent will be sent on the next tick.
                // See the Tick handler.
                TransceiverRegister transceiver_ = transceiver;

                if (transceiver.transmitter_output_enable_mode ==
                            EnabledWhenTargetPresent &&
                        !presence.present &&
                        presence_.present) begin
                    $display("%5t [Controller %02d] Transmitter output enabled",
                            $time,
                            current_controller);

                    transceiver_.transmitter_output_enabled = True;
                    transceiver_.transmitter_output_disable_timeout_ticks_remaining = 0;
                end

                transceiver <= transceiver_;

                enq_countable_application_events(
                        CountableApplicationEvents {
                            status_received: True,
                            status_timeout: False,
                            target_present: target_present,
                            target_timeout: False,
                            hello_sent: False,
                            system_power_request_sent: False});

                // Request the Target link events to be counted.
                let previous = presence.current_status_message;
                let current = presence_.current_status_message;

                countable_target_link0_events.enq(
                        CountableTransceiverEventsWithId {
                            id: current_controller,
                            events: determine_transceiver_events(
                                target_link0_status[previous],
                                target_link0_status[current],
                                target_link0_events[current],
                                // Attempt to detect receiver resets by
                                // comparing the current and previous receiver
                                // status. This is not an accurate count since
                                // this will only count instances where the
                                // status changes as a result of the reset.
                                // Subsequent resets may happen without the
                                // status changing, which will go unnoticed
                                // here. But for the purposes of remote
                                // monitoring the Target this is good enough.
                                True)});

                countable_target_link1_events.enq(
                        CountableTransceiverEventsWithId {
                            id: current_controller,
                            events: determine_transceiver_events(
                                target_link1_status[previous],
                                target_link1_status[current],
                                target_link1_events[current],
                                True)});
            end

            tagged StatusMessageFragment .field: begin
                // Write the non-active value slot of a Status message field
                // register.
                function Action write_status_message_field(
                        BufferedValueRegisterFile#(n, t) register,
                        t value)
                            provisos (Bits#(t, t_sz)) =
                    action
                        let both_values = register;

                        // Update the non-active value slot in the register.
                        if (presence.current_status_message == 0)
                            both_values[1] = value;
                        else
                            both_values[0] = value;

                        // Write back the register.
                        register <= both_values;
                    endaction;

                case (field) matches
                    tagged SystemType .system_type:
                        write_status_message_field(
                                target_system_type,
                                system_type);

                    tagged SystemStatus .system_status:
                        write_status_message_field(
                                target_system_status,
                                system_status);

                    tagged SystemEvents .system_events:
                        write_status_message_field(
                                target_system_events,
                                system_events);

                    tagged SystemPowerRequestStatus
                            .system_power_request_status:
                        write_status_message_field(
                                target_system_power_request_status,
                                system_power_request_status);

                    tagged Link0Status .link0_status:
                        write_status_message_field(
                                target_link0_status,
                                link0_status);

                    tagged Link0Events .link0_events:
                        write_status_message_field(
                                target_link0_events,
                                link0_events);

                    tagged Link0Status .link1_status:
                        write_status_message_field(
                                target_link1_status,
                                link1_status);

                    tagged Link0Events .link1_events:
                        write_status_message_field(
                                target_link1_events,
                                link1_events);
                endcase
            end

            tagged ReceiverReset: begin
                $display("%5t [Controller %02d] Receiver reset",
                        $time,
                        current_controller);

                TransceiverRegister transceiver_ = transceiver;

                transceiver_.receiver_status = link_status_none;

                if (transceiver.transmitter_output_enable_mode ==
                            EnabledWhenReceiverAligned &&
                        transceiver.transmitter_output_enabled &&
                        transceiver.transmitter_output_disable_timeout_ticks_remaining == 0) begin
                    // A ReceiverReset means the receiver is not aligned anymore
                    // and the disable timeout counter should be started.
                    transceiver_.transmitter_output_disable_timeout_ticks_remaining =
                        fromInteger(parameters.transmitter_output_disable_timeout);
                end

                // Write back the transceiver state.
                transceiver <= transceiver_;

                enq_countable_transceiver_events(
                        countable_transceiver_events_receiver_reset);
            end

            tagged ReceiverStatusChange .current_status: begin
                TransceiverRegister transceiver_ = transceiver;

                transceiver_.receiver_status = current_status;

                if (transceiver.transmitter_output_enable_mode ==
                            EnabledWhenReceiverAligned &&
                        !transceiver.transmitter_output_enabled &&
                        current_status.receiver_aligned) begin
                    $display("%5t [Controller %02d] Transmitter output enabled",
                            $time,
                            current_controller);

                    transceiver_.transmitter_output_enabled = True;
                    transceiver_.transmitter_output_disable_timeout_ticks_remaining = 0;
                end

                // Write back the transceiver state.
                transceiver <= transceiver_;

                enq_countable_transceiver_events(
                        determine_transceiver_events(
                            transceiver.receiver_status,
                            current_status,
                            defaultValue,
                            // Do not attempt to infer receiver resets from the
                            // link status as that would result in the wrong
                            // count. The receiver may reset multiple times
                            // without the status changing, which would result
                            // in those events not being counted. The
                            // `ReceiverReset` event above is the more accurate
                            // way to update this counter.
                            False));
            end

            tagged ReceiverEvent .events: begin
                enq_countable_transceiver_events(
                        determine_transceiver_events(
                            defaultValue,
                            defaultValue,
                            events,
                            False));
            end
        endcase

        // Complete the receiver event.
        receiver_events.deq();
        event_handler_state <= AwaitingEvent;
    endrule

    interface ControllerTransceiverClient txr;
        interface Get tx = toGet(transmitter_events);
        interface Put rx = toPut(receiver_events);
    endinterface

    interface Server registers;
        interface Put request = toPut(software_request);
        interface Get response = toGet(software_response);
    endinterface

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

    method presence_summary = readVReg(presence_summary_r);

    method tick_1mhz = tick.send;

    method idle = init_complete && event_handler_idle && event_counting_idle;
endmodule

interface RegisterFile#(numeric type n, type t);
    method Action select(ControllerId#(n) id);
    method Action _write(t value);
    method t _read();
endinterface

typedef RegisterFile#(n, Vector#(2, t))
        BufferedValueRegisterFile#(numeric type n, type t);

module mkBRAMRegisterFile (RegisterFile#(n, t))
        provisos (Bits#(t, t_sz));
    BRAM_PORT#(ControllerId#(n), t) ram <- mkBRAMCore1(valueof(n), False);
    Reg#(RegisterFileRequest#(n, t)) request <- mkRegU();

    RWire#(ControllerId#(n)) controller_id <- mkRWire();
    RWire#(t) new_value <- mkRWire();

    (* fire_when_enabled *)
    rule do_update_state;
        request <= RegisterFileRequest {
                id: fromMaybe(request.id, controller_id.wget),
                data: new_value.wget};

        // The register file contineously reads or writes the data for the set
        // Controller id. If no new data is provided through `new_value`, the
        // `data` field in the request automatically becomes `Invalid` causing a
        // BRAM read instead of a write.
        if (request.data matches tagged Valid .data)
            ram.put(True, request.id, data);
        else
            ram.put(False, request.id, ?);
    endrule

    method select = controller_id.wset;
    method _read = ram.read;
    method _write = new_value.wset;
endmodule

typedef struct {
    ControllerId#(n) id;
    Maybe#(t) data;
} RegisterFileRequest#(numeric type n, type t) deriving (Bits, Eq, FShow);

typedef struct {
    ControllerId#(n) id;
    union tagged {
        TransmitterOutputEnableMode SetTransmitterOutputEnableMode;
        SystemPowerRequest SystemPowerRequest;
    } ev;
} SoftwareEvent#(numeric type n) deriving (Bits, Eq, FShow);

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
    ControllerId#(n) id;
    events_type events;
} CountableEventsWithId#(numeric type n, type events_type)
    deriving (Bits, FShow);

typedef CountableEventsWithId#(n, CountableTransceiverEvents)
        CountableTransceiverEventsWithId#(numeric type n);

typedef CountableEventsWithId#(n, CountableApplicationEvents)
        CountableApplicationEventsWithId#(numeric type n);

typedef struct {
    UInt#(1) current_status_message;
    UInt#(6) status_message_timeout_ticks_remaining;
    Bool present;
    Vector#(3, Bool) history;
} PresenceRegister deriving (Bits, FShow);

typedef struct {
    UInt#(8) transmitter_output_disable_timeout_ticks_remaining;
    TransmitterOutputEnableMode transmitter_output_enable_mode;
    Bool transmitter_output_enabled;
    LinkStatus receiver_status;
} TransceiverRegister deriving (Bits, FShow);

typedef struct {
    UInt#(6) ticks_remaining;
} HelloTimerRegister deriving (Bits, FShow);

typedef enum {
    AwaitingEvent = 0,
    ReadingRegisters,
    HandlingSoftwareRequest,
    HandlingTickEvent,
    HandlingReceiverEvent
} EventHandlerState deriving (Bits, Eq, FShow);

module mkDefaultControllerUsingBRAM (Controller#(36));
    (* hide *) Controller#(36) _c <- mkController(defaultValue, False);
    return _c;
endmodule

function Stmt read_controller_register_into(
        Controller#(n) controller,
        ControllerId#(n) controller_id,
        RegisterId register_id,
        Reg#(register_value_type) destination)
            provisos (
                Bits#(register_value_type, register_value_type_sz),
                Add#(register_value_type_sz, a__, 8));
    return seq
        controller.registers.request.put(
                RegisterRequest {
                    op: tagged Read,
                    id: controller_id,
                    register: register_id});

        action
            let response <- controller.registers.response.get;
            destination <= unpack(truncate(response));
        endaction
    endseq;
endfunction

function Stmt clear_controller_counter(
        Controller#(n) controller,
        ControllerId#(n) controller_id,
        CounterId counter_id) =
    seq
        controller.counters.request.put(
                CounterAddress {
                    controller: controller_id,
                    counter: counter_id});

        action
            let count <- controller.counters.response.get;
        endaction
    endseq;

function Stmt read_controller_counter_into(
        Controller#(n) controller,
        ControllerId#(n) controller_id,
        CounterId counter_id,
        Reg#(UInt#(8)) counter) =
    seq
        controller.counters.request.put(
                CounterAddress {
                    controller: controller_id,
                    counter: counter_id});
        action
            let count <- controller.counters.response.get;
            counter <= count;
        endaction
    endseq;

function Bit#(8) transceiver_state_value(
        TransmitterOutputEnableMode mode,
        Bool transmitter_status,
        LinkStatus receiver_status) =
    {2'h0, pack(mode), pack(transmitter_status), pack(receiver_status)};

// Given a bit_vector_t with zero or more bits indicating requests and a
// bit_vector_t with exactly one bit set indicating the preferred (next) request
// to select, round-robin select the next request.
function bit_vector_t round_robin_select(
        bit_vector_t pending,
        bit_vector_t base)
            provisos (Bits#(bit_vector_t, sz));
    let _base = extend(pack(base));
    let _pending = {pack(pending), pack(pending)};

    match {.left, .right} = split(_pending & ~(_pending - _base));
    return unpack(left | right);
endfunction

endpackage
