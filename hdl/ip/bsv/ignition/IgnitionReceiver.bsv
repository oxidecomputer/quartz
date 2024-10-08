package IgnitionReceiver;

export Receiver(..);
export mkReceiver;

export ControllerReceiver(..);
export mkControllerReceiver;
export StatusMessageFragment(..);
export ReceiverEvent(..);
export ReceiverEvent_$ev(..);

import BRAMCore::*;
import BRAMFIFO::*;
import ConfigReg::*;
import Connectable::*;
import DefaultValue::*;
import DReg::*;
import FIFO::*;
import FIFOF::*;
import GetPut::*;
import OInt::*;
import Vector::*;

import Deserializer8b10b::*;
import Encoding8b10b::*;
import SettableCRC::*;

import IgnitionProtocol::*;
import IgnitionProtocolParser::*;


interface Receiver#(numeric type n, type message_t);
    interface Vector#(n, PutS#(DeserializedCharacter)) character;
    interface Get#(Tuple2#(UInt#(TLog#(n)), message_t)) message;
    method Vector#(n, LinkStatus) status();
    method Vector#(n, LinkEvents) events();
    method Vector#(n, Bool) locked_timeout();
    method Vector#(n, Bool) reset_event();
    method Action tick_1khz();
endinterface

typedef enum {
    Resetting = 0,
    Fetching,
    Decoding,
    Parsing,
    Receiving
} Phase deriving (Bits, Eq, FShow);

instance DefaultValue#(Phase);
    defaultValue = Resetting;
endinstance

typedef struct {
    Reg#(Phase) phase;
    // Receiver state for the channel.
    Reg#(Bool) aligned;
    Reg#(Bool) locked;
    Reg#(Bool) polarity_inverted;
    // Decoder state for the channel.
    Reg#(RunningDisparity) rd;
    Reg#(Bool) comma;
    Reg#(CharacterValidHistory) character_valid_history;
    // Parser state for the channel.
    Reg#(parser_t) parser_state;
    Reg#(Bool) expect_idle;
    Reg#(IdleSetValidHistory) idle_set_valid_history;
    Reg#(Bit#(8)) running_checksum;
    // Receiver events for the channel.
    Reg#(Bool) decoding_error;
    Reg#(Bool) ordered_set_invalid;
    Reg#(Bool) message_version_invalid;
    Reg#(Bool) message_type_invalid;
    Reg#(Bool) message_checksum_invalid;
    Reg#(Bool) request_invalid;
    // Deserializer interface for the channel.
    Wire#(DeserializedCharacter) character;
    PulseWire character_accepted;
    // Watchdog interface for the channel.
    Reg#(Bool) locked_timeout;
    Reg#(Bool) reset_event;
} State#(type parser_t);

module mkReceiver
        #(Parser#(parser_t, message_t) parser)
            (Receiver#(n, message_t))
                provisos (
                    Bits#(parser_t, parser_sz),
                    Bits#(message_t, message_sz),
                    DefaultValue#(parser_t));
    Vector#(n, State#(parser_t)) channels;

    // Allocate state for each channel.
    for (Integer i = 0; i < valueOf(n); i = i + 1) begin
        channels[i].phase <- mkReg(Resetting);

        channels[i].aligned <- mkConfigRegU();
        channels[i].locked <- mkConfigRegU();
        channels[i].locked_timeout <- mkConfigRegU();
        channels[i].polarity_inverted <- mkConfigRegU();

        channels[i].rd <- mkRegU();
        channels[i].comma <- mkRegU();
        channels[i].character_valid_history <- mkRegU();

        channels[i].parser_state <- mkRegU();
        channels[i].expect_idle <- mkRegU();
        channels[i].idle_set_valid_history <- mkRegU();
        channels[i].running_checksum <- mkRegU();

        channels[i].decoding_error <- mkDReg(False);
        channels[i].ordered_set_invalid <- mkDReg(False);
        channels[i].message_version_invalid <- mkDReg(False);
        channels[i].message_type_invalid <- mkDReg(False);
        channels[i].message_checksum_invalid <- mkDReg(False);
        channels[i].request_invalid <- mkDReg(False);

        channels[i].character <- mkWire();
        channels[i].character_accepted <- mkPulseWire();

        channels[i].reset_event <- mkDReg(False);
    end

    Reg#(UInt#(TLog#(n))) reset_or_fetch_select <- mkReg(0);

    FIFO#(DecodeInput#(n)) decode_input <- mkLFIFO();
    FIFO#(DecodeResult#(n)) decode_result <- mkLFIFO();
    PulseWire decode_done <- mkPulseWire();

    Reg#(parser_t) parser_state <- mkRegU();
    CRC#(8) crc <- mkIgnitionCRC();
    Reg#(Bool) parse_value <- mkDReg(False);

    Wire#(Tuple2#(UInt#(TLog#(n)), message_t)) received_message <- mkWire();

    Reg#(UInt#(9)) watchdog_ticks_remaining <- mkRegU();
    Reg#(Bool) watchdog_fired <- mkDReg(False);

    // This rule only makes sense for a receiver with more than 1 channel. The
    // compiler does the right thing here and optimizes the contents away, but
    // then leaves the empty rule resulting in a warning. This compile time
    // condition simply omits the rule when not needed.
    if (valueOf(n) > 1) begin
        // Round-robbin over the available channels to allow for a reset or decode
        // if the given channel is in a the appropriate phase.
        (* fire_when_enabled *)
        rule do_select_next_channel_for_reset_or_character_fetch;
            let last_channel = fromInteger(valueOf(n) - 1);
            let wrap = (reset_or_fetch_select == last_channel);

            reset_or_fetch_select <= (wrap ? 0 : reset_or_fetch_select + 1);
        endrule
    end

    for (Integer i = 0; i < valueOf(n); i = i + 1) begin
        // Reset the selected channel when requested.
        (* fire_when_enabled *)
        rule do_reset_channel (
                reset_or_fetch_select == fromInteger(i) &&
                channels[i].phase == Resetting);
            // Discard the current character, keeping the timing as if a decode
            // step occured.
            channels[i].character_accepted.send();

            channels[i].phase <= Fetching;

            channels[i].aligned <= False;
            channels[i].locked <= False;
            channels[i].locked_timeout <= False;
            channels[i].polarity_inverted <= False;

            channels[i].rd <= RunningNegative;
            channels[i].character_valid_history <= replicate(unknown);

            channels[i].parser_state <= defaultValue;
            channels[i].expect_idle <= False;
            channels[i].idle_set_valid_history <= replicate(unknown);

            channels[i].reset_event <= True;
        endrule

        // Fetch the next character for the channel under consideration. Note
        // that this rule has an implicit dependency on the deserializer
        // producing the characters. If the receiver is not aligned (a comma has
        // not been succesfully decoded) the deserializer may not produce
        // characters at a steady rate and the receiver will remain in this
        // `phase`, waiting for the next character to be produced by the
        // deserializer.
        //
        // Subsequent phases do not have this behavior and once a character has
        // been dequeued the receiver will go through the `Decoding`, `Parsing`
        // and `Receiving` phases and return to either the `Resetting` or
        // `Fetching` phase.
        (* fire_when_enabled *)
        rule do_fetch_channel_character (
                reset_or_fetch_select == fromInteger(i) &&
                channels[i].phase == Fetching &&
                !channels[i].locked_timeout);
            channels[i].phase <= Decoding;
            channels[i].character_accepted.send();

            // Prep data needed by the shared rules to decode the received
            // character.
            decode_input.enq(DecodeInput {
                channel_select: fromInteger(i),
                rd: channels[i].rd,
                character: channels[i].character});
        endrule

        // Because the rule above may block if no character is received from the
        // deserializer `locked_timeout` can preempt this and return the
        // receiver to the `Resetting` phase. This guarantees that the receiver
        // is either locked or periodically returns to the `Resetting` phase.
        // Upon receiver reset the deserializer will slip bits until the next
        // comma is succesfully decoded.
        (* fire_when_enabled *)
        rule do_abort_fetch_on_locked_timeout (
                reset_or_fetch_select == fromInteger(i) &&
                channels[i].phase == Fetching &&
                channels[i].locked_timeout);
            channels[i].phase <= Resetting;
        endrule

        // The shared decode rule has signaled that decoding completed. Demux
        // the parser state for this channel into the shared pipeline.
        (* fire_when_enabled *)
        rule do_channel_decode (
                decode_input.first.channel_select == fromInteger(i) &&
                channels[i].phase == Decoding &&
                decode_done &&
                !parse_value);
            channels[i].phase <= Parsing;
            parser_state <= channels[i].parser_state;
            crc.set(channels[i].running_checksum);

            // The decoding inputs are no longer needed. Release them and allow
            // another channel to start receiving a character.
            decode_input.deq();
        endrule

        // Update the state for this channel based on whether or not the decode
        // of the character succeeded. The shared parsing rule will run in
        // parallel to this rule, determining the next parser state.
        (* fire_when_enabled *)
        rule do_channel_parse (
                decode_result.first.channel_select == fromInteger(i) &&
                channels[i].phase == Parsing &&
                parse_value);
            let character_valid = decode_result.first.character_valid;

            channels[i].phase <= Receiving;

            // Write back running disparity from the shared pipeline.
            channels[i].rd <= decode_result.first.rd;

            // Update the character history for the channel.
            channels[i].character_valid_history <= shiftInAt0(
                channels[i].character_valid_history,
                tagged Valid character_valid);

            // Flag any decoding errors as significant when the receiver is not
            // in start-up.
            channels[i].decoding_error <=
                (channels[i].locked && !character_valid);
        endrule

        (* fire_when_enabled *)
        rule do_channel_receive (
                decode_result.first.channel_select == fromInteger(i) &&
                channels[i].phase == Receiving &&
                !parse_value);
            Bool reset_receiver = False;

            // Write back the updated checksum for the channel.
            channels[i].running_checksum <= crc.value;

            // Consider the state of the parser and determine events impacting
            // the link state.
            Bool idle1 = False;
            Bool idle2 = False;
            Bool idle_inverted = False;

            if (parser.result(parser_state) matches tagged Valid .result) begin
                case (result) matches
                    tagged Idle1 .inverted: begin
                        idle1 = True;
                        idle_inverted = inverted;
                    end

                    tagged Idle2 .inverted: begin
                        idle2 = True;
                        idle_inverted = inverted;
                    end

                    tagged Message .m:
                        if (channels[i].locked)
                            received_message <= tuple2(fromInteger(i), m);

                    tagged Error .e:
                        // OrderedSetInvalid errors may occur during link
                        // start-up. To avoid this noise being propagated in
                        // Status messages, suppress these errors specifically
                        // until the link is locked. Other errors are fair game
                        // even if the link is not locked since the parser
                        // should not produce them unless conditions are really
                        // bad/odd.
                        case (e)
                            OrderedSetInvalid:
                                if (channels[i].locked)
                                    channels[i].ordered_set_invalid <= True;
                            VersionInvalid:
                                channels[i].message_version_invalid <= True;
                            MessageTypeInvalid:
                                channels[i].message_type_invalid <= True;
                            ChecksumInvalid:
                                channels[i].message_checksum_invalid <= True;
                            RequestInvalid:
                                channels[i].request_invalid <= True;
                        endcase
                endcase

                channels[i].parser_state <= defaultValue;
            end
            else begin
                channels[i].parser_state <= parser_state;
            end

            // A valid Idle1 or Idle2 set, with the correct polarity was
            // received. Update the history accordingly.
            if ((idle1 || idle2) &&
                    (!idle_inverted ||
                        (idle_inverted && !channels[i].polarity_inverted))) begin
                channels[i].expect_idle <= False;
                channels[i].idle_set_valid_history <= shiftInAt0(
                    channels[i].idle_set_valid_history,
                    known_valid);
            end
            // An Idle set was expected to be completed by the received
            // character but either the parser did not return a valid Idle set
            // or the polarity was not as expected. Update the history
            // accordingly.
            else if (channels[i].expect_idle) begin
                channels[i].expect_idle <= False;
                channels[i].idle_set_valid_history <= shiftInAt0(
                    channels[i].idle_set_valid_history,
                    known_invalid);
            end
            // Declare the deserializer aligned if the parser has seen a valid
            // comma. The next received character should complete an Idle set.
            // Setting this expectation will mean that if this was not a valid
            // comma according to the parser, the idle_set_valid_history will be
            // marked which in turn will trigger a receiver reset if alignment
            // is off.
            else if (parser.parsing_idle(parser_state)) begin
                channels[i].aligned <= True;
                channels[i].expect_idle <= True;
            end

            // When an Idle set is received the running disparity of the link
            // can be determined. This is idempotent and safe to set any time an
            // Idle set is received.
            if (idle1) begin
                channels[i].rd <= RunningPositive;
            end
            else if (idle2) begin
                channels[i].rd <= RunningNegative;
            end

            // The link polarity gets to be adjusted once. Subsequent occurances
            // of inverted Idle sets are recorded as Invalid in the Idle history
            // and will trigger a link reset.
            //
            // It is tempting to restrict this even further and only allow this
            // when the first slot in the Idle sets valid history is in unknown
            // state, but a link may receive one or more invalid Idle sets as
            // part of the alignment step. In such an instance any link with
            // inverted polarity would be unable to start.
            if (!channels[i].polarity_inverted && idle_inverted) begin
                channels[i].polarity_inverted <= True;
            end

            // With most of the bookkeeping out of the way the only thing
            // remaining is considering the receive history to determine if the
            // link should be locked.
            if (countElem(known_invalid, channels[i].character_valid_history) > 2 ||
                    channels[i].idle_set_valid_history == all_idle_sets_invalid ||
                    channels[i].locked_timeout)  begin
                reset_receiver = True;
            end
            else if (channels[i].aligned &&
                    channels[i].character_valid_history == all_characters_valid &&
                    channels[i].idle_set_valid_history == all_idle_sets_valid) begin
                channels[i].locked <= True;
            end

            // Discard the shared parser state, allowing the next channel to
            // continue receiving a character.
            decode_result.deq();

            // Based on the outcome of the character valid history and idle set
            // checks, either reset the receiver or continue waiting for the
            // next character.
            channels[i].phase <= reset_receiver ? Resetting : Fetching;
        endrule

        // Monitor the locked watchdog strobe. If the channel is not locked set
        // the timeout flag and request a reset after the next Receive phase.
        // The `locked_timeout` flag is reset during the `Resetting` phase.
        rule do_channel_locked_watchdog (
                channels[i].phase != Resetting &&
                watchdog_fired);
            channels[i].locked_timeout <=
                !channels[i].aligned || !channels[i].locked;
        endrule
    end

    (* fire_when_enabled *)
    rule do_shared_decode;
        let rd = decode_input.first.rd;
        let character = decode_input.first.character.c;
        let decode_result_ = decode(character, rd);

        // Convert any decoding errors into end_of_message_invalid
        // values for the parser, forcing a parser reset.
        Bool character_valid = False;
        Value value = end_of_message_invalid;

        if (decode_result_.value matches tagged Valid .v &&&
                isValid(decode_result_.rd)) begin
            character_valid = True;
            value = v;
        end

        // Forward decoding results to parse phase.
        decode_result.enq(DecodeResult {
                channel_select: decode_input.first.channel_select,
                // If either the character or rd were not valid, the returned rd
                // has a good chance of being invalid is as well. This is
                // acceptable since subsequent decode failures due to this wrong
                // rd either trigger a reset of the receiver, trigger a parser
                // error, or may accidentally get it back on track in case two
                // wrongs do make a right.
                rd: fromMaybe(rd, decode_result_.rd),
                character_valid: character_valid,
                value: value});

        // Signal the decode rule for this channel that it can release the
        // shared inputs and demux its parser state.
        decode_done.send();

        // Request the rule below to parse the decoded value on the next cycle.
        parse_value <= True;
    endrule

    (* fire_when_enabled *)
    rule do_shared_parse (parse_value);
        let parser_state_ <- parser.parse(
                parser_state,
                decode_result.first.value,
                crc.result);

        parser_state <= parser_state_;

        // Update the running CRC. Note that this considers the channel
        // parser state up to the previous character.
        if (parser.awaiting_ordered_set(parser_state))
            // Reset the CRC while the parser is receiving Ordered Sets.
            // This means it'll automatically start tracking/calculating as
            // message parsing starts.
            crc.clear();
        else
            crc.add(value_bits(decode_result.first.value));
    endrule

    interface Vector character = map(receiver_deserializer, channels);
    interface Get message = toGet(received_message);
    method status = map(receiver_status, channels);
    method events = map(receiver_events, channels);
    method locked_timeout = map(receiver_locked_timeout, channels);
    method reset_event = map(receiver_reset_event, channels);

    method Action tick_1khz();
        // This automatically rolls over from 0, restarting the watchdog
        // timer.
        watchdog_ticks_remaining <= watchdog_ticks_remaining - 1;
        watchdog_fired <= (watchdog_ticks_remaining == 0);
    endmethod
endmodule

//
// Record types for data carried between the receive phases.
//

typedef struct {
    UInt#(TLog#(n)) channel_select;
    RunningDisparity rd;
    DeserializedCharacter character;
} DecodeInput#(numeric type n) deriving (Bits);

typedef struct {
    UInt#(TLog#(n)) channel_select;
    RunningDisparity rd;
    Bool character_valid;
    Value value;
} DecodeResult#(numeric type n) deriving (Bits);

//
// Per channel types.
//

typedef Vector#(6, Maybe#(Bool)) CharacterValidHistory;
typedef Vector#(2, Maybe#(Bool)) IdleSetValidHistory;

Maybe#(Bool) unknown = tagged Invalid;
Maybe#(Bool) known_valid = tagged Valid True;
Maybe#(Bool) known_invalid = tagged Valid False;

CharacterValidHistory all_characters_invalid = replicate(known_invalid);
CharacterValidHistory all_characters_valid = replicate(known_valid);
Vector#(4, Maybe#(Bool)) past_four_characters_invalid = replicate(known_invalid);
Vector#(4, Maybe#(Bool)) past_four_characters_valid = replicate(known_valid);

IdleSetValidHistory all_idle_sets_invalid = replicate(known_invalid);
IdleSetValidHistory all_idle_sets_valid = replicate(known_valid);

function PutS#(DeserializedCharacter)
        receiver_deserializer(State#(parser_t) channel);
    return (interface PutS;
        method offer = channel.character._write;
        method accepted = channel.character_accepted;
    endinterface);
endfunction

function LinkStatus receiver_status(State#(parser_t) channel);
    return LinkStatus {
            polarity_inverted: channel.polarity_inverted,
            receiver_locked: channel.locked,
            receiver_aligned: channel.aligned};
endfunction

function LinkEvents receiver_events(State#(parser_t) channel);
    return LinkEvents {
            message_checksum_invalid: channel.message_checksum_invalid,
            message_type_invalid: channel.message_type_invalid,
            message_version_invalid: channel.message_version_invalid,
            ordered_set_invalid: channel.ordered_set_invalid,
            decoding_error: channel.decoding_error,
            encoding_error: False};
endfunction

function Bool receiver_locked_timeout(State#(parser_t) channel) =
        channel.locked_timeout;

function Bool receiver_reset_event(State#(parser_t) channel) =
        channel.reset_event;

instance Connectable#(Vector#(n, Deserializer8b10b::Deserializer), Receiver#(n, message_t));
    module mkConnection #(
            Vector#(n, Deserializer8b10b::Deserializer) des,
            Receiver#(n, message_t) rx)
                (Empty);
        for (Integer i = 0; i < valueOf(n); i = i + 1) begin
            mkConnection(des[i].character, rx.character[i]);

            (* fire_when_enabled *)
            rule do_align (!rx.status[i].receiver_aligned);
                des[i].search_for_comma();
            endrule

            (* fire_when_enabled *)
            rule do_invert_polarity (rx.status[i].polarity_inverted);
                des[i].invert_polarity();
            endrule
        end
    endmodule
endinstance

//
// Controller Receiver
//

interface ControllerReceiver #(numeric type n);
    interface Vector#(n, DeserializerClient) rx;
    interface Get#(ReceiverEvent#(n)) events;
    method Action tick_1khz();
endinterface

interface DeserializerChannel #(numeric type n);
    interface DeserializerClient deserializer;
    interface FIFOF#(DeserializerEvent#(n)) events;

    // Control methods used by upstream receiver logic.
    method Action request_reset();
    method Action set_search_for_comma(Bool search_for_comma);
    method Action set_invert_polarity(Bool invert_polarity);
endinterface

module mkDeserializerChannel #(Integer id) (DeserializerChannel#(n));
    RWire#(DeserializedCharacter) next_character <- mkRWire();
    RWire#(DeserializerEvent#(n)) next_event <- mkRWire();

    PulseWire deq <- mkPulseWire();
    PulseWire reset_request <- mkPulseWire();

    Reg#(Bool) reset_requested <- mkReg(True);
    Reg#(Bool) search_for_comma <- mkReg(False);
    Reg#(Bool) invert_polarity <- mkReg(False);

    (* fire_when_enabled *)
    rule do_enq_reset_event (reset_requested);
        next_event.wset(DeserializerEvent {
                id: fromInteger(id),
                ev: tagged DecoderReset});
    endrule

    (* fire_when_enabled *)
    rule do_enq_character (
                !reset_requested &&&
                next_character.wget matches tagged Valid .c);
        next_event.wset(DeserializerEvent {
                id: fromInteger(id),
                ev: tagged Character c.c});
    endrule

    (* fire_when_enabled *)
    rule ack_reset_request (reset_requested && deq);
        reset_requested <= reset_request;
    endrule

    (* fire_when_enabled *)
    rule do_request_reset (!reset_requested);
        reset_requested <= reset_request;
    endrule

    interface DeserializerClient deserializer;
        interface PutS character;
            method offer = next_character.wset;
            method accepted = deq;
        endinterface

        method search_for_comma = search_for_comma;
        method invert_polarity = invert_polarity;
    endinterface

    interface FIFOF events;
        method Action enq(DeserializerEvent#(n) e);
        endmethod
        method deq = deq.send;
        method first = fromMaybe(?, next_event.wget);
        method notEmpty = isValid(next_event.wget);
        method notFull = !isValid(next_event.wget);
        method Action clear() = noAction;
    endinterface

    method request_reset = reset_request.send;
    method set_search_for_comma = search_for_comma._write;
    method set_invert_polarity = invert_polarity._write;
endmodule

typedef Vector#(m, FIFOF#(DeserializerEvent#(n)))
        DeserializerEventFIFOs#(numeric type m, numeric type n);

module mkControllerReceiver (ControllerReceiver#(n))
            provisos (
                Add#(4, _, n),
                NumAlias#(TLog#(n), id_sz));
    Vector#(n, DeserializerChannel#(n))
            channels <- mapM(mkDeserializerChannel, genVector);
    Vector#(n, Reg#(Bool)) channels_locked <- replicateM(mkReg(False));

    Reg#(UInt#(9)) watchdog_ticks_remaining <- mkRegU();
    Reg#(Bool) watchdog_fired <- mkDReg(False);

    // Use a regular FIFO here but of size two, allowing it to act as a skid
    // buffer. This decouples the demux pipeline from the receiver logic,
    // reducing the length of pipeline enable signals while preserving the
    // ability to process a receiver event very cycle.
    FIFOF#(DeserializerEvent#(n)) deserializer_events_l0 <- mkGFIFOF(False, True);

    //
    // Deserializer mux stage(s)
    //

    function Rules do_forward_event(
            Get#(DeserializerEvent#(n)) source,
            Put#(DeserializerEvent#(n)) sink,
            Bool sink_selected,
            Reg#(Bit#(demux_sz)) grant_base,
            Bit#(demux_sz) grant);
        return (
            rules
                (* fire_when_enabled *)
                rule do_forward_receiver_event (sink_selected);
                    let e <- source.get;
                    sink.put(e);
                    grant_base <= rotateBitsBy(grant, 1);
                endrule
            endrules);
    endfunction

    if (valueof(n) == 36) begin
        Reg#(Bit#(3)) grant_base_l0 <- mkReg(1);

        Vector#(3, FIFOF#(DeserializerEvent#(n)))
                deserializer_events_l1 <- replicateM(mkLFIFOF());
        Vector#(3, Reg#(Bit#(3))) grant_base_l1 <- replicateM(mkReg(1));

        Vector#(9, FIFOF#(DeserializerEvent#(n)))
                deserializer_events_l2 <- replicateM(mkLFIFOF());
        Vector#(9, Reg#(Bit#(4))) grant_base_l2 <- replicateM(mkReg(1));

        begin
            let sink = deserializer_events_l0;
            let sources = deserializer_events_l1;
            let not_empty = map(notEmpty, sources);
            let grant = select_fifo(not_empty, grant_base_l0);

            Vector#(3, Rules) forwarding_rules;

            for (Integer j = 0; j < 3; j = j + 1) begin
                forwarding_rules[j] =
                        do_forward_event(
                            toGet(sources[j]),
                            toPut(sink),
                            not_empty[j] && grant[j],
                            asIfc(grant_base_l0),
                            pack(grant));
            end

            addRules(foldr(
                    rJoinMutuallyExclusive,
                    emptyRules,
                    forwarding_rules));
        end

        for (Integer i = 0; i < 3; i = i + 1) begin
            let sink = deserializer_events_l1[i];
            let sources = DeserializerEventFIFOs#(3, n)'(takeAt(3 * i, deserializer_events_l2));
            let not_empty = map(notEmpty, sources);
            let grant = select_fifo(not_empty, grant_base_l1[i]);

            Vector#(3, Rules) forwarding_rules;

            for (Integer j = 0; j < 3; j = j + 1) begin
                forwarding_rules[j] =
                        do_forward_event(
                            toGet(sources[j]),
                            toPut(sink),
                            not_empty[j] && grant[j],
                            asIfc(grant_base_l1[i]),
                            pack(grant));
            end

            addRules(foldr(
                    rJoinMutuallyExclusive,
                    emptyRules,
                    forwarding_rules));
        end

        for (Integer i = 0; i < 9; i = i + 1) begin
            let sink = deserializer_events_l2[i];
            let sources = DeserializerEventFIFOs#(4, n)'(takeAt(4 * i, map(events, channels)));
            let not_empty = map(notEmpty, sources);
            let grant = select_fifo(not_empty, grant_base_l2[i]);

            Vector#(4, Rules) forwarding_rules;

            for (Integer j = 0; j < 4; j = j + 1) begin
                forwarding_rules[j] =
                        do_forward_event(
                            toGet(sources[j]),
                            toPut(sink),
                            not_empty[j] && grant[j],
                            asIfc(grant_base_l2[i]),
                            pack(grant));
            end

            addRules(foldr(
                    rJoinMutuallyExclusive,
                    emptyRules,
                    forwarding_rules));
        end
    end

    // With up to four receiver channels there is no need for intermediate mux
    // stages. Instead deserializers should forward directly to
    // `deserializer_events_l0`.
    else if (valueof(n) <= 4) begin
        Reg#(Bit#(n)) grant_base_l0 <- mkReg(1);

        begin
            let sink = deserializer_events_l0;
            let sources = DeserializerEventFIFOs#(n, n)'(map(events, channels));
            let not_empty = map(notEmpty, sources);
            let grant = select_fifo(not_empty, grant_base_l0);

            Vector#(n, Rules) forwarding_rules;

            for (Integer j = 0; j < valueof(n); j = j + 1) begin
                forwarding_rules[j] =
                        do_forward_event(
                            toGet(sources[j]),
                            toPut(sink),
                            not_empty[j] && grant[j],
                            asIfc(grant_base_l0),
                            pack(grant));
            end

            addRules(foldr(
                    rJoinMutuallyExclusive,
                    emptyRules,
                    forwarding_rules));
        end
    end

    //
    // Receive Phase
    //

    BRAM_DUAL_PORT#(UInt#(id_sz), ReceiveState1)
            receive_state_1 <- mkBRAMCore2(valueof(n), False);
    BRAM_DUAL_PORT#(UInt#(id_sz), ReceiveState2)
            receive_state_2 <- mkBRAMCore2(valueof(n), False);

    StreamingStatusMessageParser parser <- mkStreamingStatusMessageParser();

    Reg#(Maybe#(DeserializerEvent#(n))) deserializer_event <- mkReg(tagged Invalid);
    Reg#(Maybe#(DecoderEvent#(n))) decoder_event <- mkReg(tagged Invalid);
    Reg#(Maybe#(ParserEvent#(n))) parser_event <- mkReg(tagged Invalid);
    FIFOF#(ReceiverEvent#(n)) receiver_events <- mkSizedBRAMFIFOF(1023);

    Reg#(Maybe#(UInt#(id_sz))) receive_state_1_id <- mkReg(tagged Invalid);
    Reg#(ReceiveState1) receive_state_1_next <- mkRegU();
    Reg#(Maybe#(UInt#(id_sz))) receive_state_2_id <- mkReg(tagged Invalid);
    Reg#(ReceiveState2) receive_state_2_next <- mkRegU();

    function Bool stage_available(Maybe#(t) next_stage) =
            !isValid(next_stage) || receiver_events.notFull;

    (* fire_when_enabled *)
    rule do_handle_events;
        //
        // Wait for BRAM read.
        //

        if (deserializer_events_l0.notEmpty &&
                stage_available(deserializer_event)) begin
            receive_state_1.a.put(False, deserializer_events_l0.first.id, ?);
            deserializer_event <= tagged Valid deserializer_events_l0.first;
            deserializer_events_l0.deq();
        end
        else if (!deserializer_events_l0.notEmpty &&
                    receiver_events.notFull) begin
            deserializer_event <= tagged Invalid;
        end

        //
        // Decode.
        //

        if (deserializer_event matches tagged Valid .ev &&&
                stage_available(decoder_event)) begin
            let rd = receive_state_1.a.read.rd;
            let parser_state = receive_state_1.a.read.parser_state;
            let running_crc = receive_state_1.a.read.running_crc;

            case (ev.ev) matches
                tagged DecoderReset:
                    decoder_event <= tagged Valid
                        DecoderEvent {
                            id: ev.id,
                            ev: tagged ParserReset};

                tagged Character .c:
                    decoder_event <= tagged Valid
                        DecoderEvent {
                            id: ev.id,
                            ev: tagged DecodeResult {
                                    result: decode(c, rd),
                                    parser_state: parser_state,
                                    running_crc: running_crc}};
            endcase
        end
        else if (deserializer_event matches tagged Invalid &&&
                    receiver_events.notFull) begin
            decoder_event <= tagged Invalid;
        end

        //
        // Parse.
        //

        if (decoder_event matches tagged Valid .ev &&&
                stage_available(parser_event)) begin
            case (ev.ev) matches
                tagged ParserReset:
                    parser_event <= tagged Valid
                        ParserEvent {
                            id: ev.id,
                            ev: tagged ReceiverReset};

                tagged DecodeResult {
                        result: .decode_result,
                        parser_state: .parser_state,
                        running_crc: .running_crc}: begin
                    // Determine the value to be parsed based on the decoder
                    // result.
                    match {.value, .character_valid} =
                        case (decode_result.value) matches
                            tagged Valid .value: tuple2(value, True);
                            tagged Invalid .*:
                                tuple2(end_of_message_invalid, False);
                        endcase;

                    // if (ev.id == 0) begin
                    //     $display("%05t: ", $time, fshow(parser_state), " ", fshow(value));
                    // end

                    // Parse the value given the current parser state. If the
                    // case statement above returned the
                    // `end_of_message_invalid` value it'll force a parse
                    // failure causing the parser to get reset in the next step.
                    //
                    // The next parser state may hold a parse Error, idle token
                    // or a byte from the incoming message for the receive stage
                    // to use.
                    let parser_state_next <-
                            parser.parse(
                                parser_state,
                                value,
                                crc_result(running_crc));

                    // When the parser is processing a message byte the running
                    // CRC for the message should be updated. This is done by
                    // resetting the running CRC to the init value when the
                    // parser is waiting and adding the received value to the
                    // CRC in all other states.
                    let running_crc_next =
                            case (parser_state) matches
                                tagged AwaitingOrderedSet:
                                    crc_parameters.init;
                                default:
                                    crc_add(running_crc, value_bits(value));
                            endcase;

                    parser_event <= tagged Valid
                            ParserEvent {
                                id: ev.id,
                                ev: tagged ParserResult {
                                        running_crc: running_crc_next,
                                        parser_state: parser_state_next,
                                        character_valid: character_valid,
                                        rd: fromMaybe(
                                                RunningNegative,
                                                decode_result.rd)}};

                    // Read the remaining receiver state from BRAM.
                    receive_state_2.a.put(False, ev.id, ?);
                end
            endcase
        end
        else if (decoder_event matches tagged Invalid &&&
                    receiver_events.notFull) begin
            parser_event <= tagged Invalid;
        end

        //
        // Update receiver state.
        //

        if (parser_event matches tagged Valid .ev &&&
                    receiver_events.notFull) begin
            function Action enq_event(ReceiverEvent_$ev#(n) e) =
                receiver_events.enq(ReceiverEvent {id: ev.id, ev: e});

            let reset_receiver = False;
            let link_status_change = False;

            let aligned = receive_state_2.a.read.aligned;
            let locked = receive_state_2.a.read.locked;
            let polarity_inverted = receive_state_2.a.read.polarity_inverted;
            let expect_idle = receive_state_2.a.read.expect_idle;
            let idle_set_valid_history =
                    receive_state_2.a.read.idle_set_valid_history;
            let character_valid_history =
                    receive_state_2.a.read.character_valid_history;

            let rd_next = ev.ev.ParserResult.rd;
            let parser_state_next = ev.ev.ParserResult.parser_state;
            let running_crc_next = ev.ev.ParserResult.running_crc;
            let aligned_next = aligned;
            let locked_next = locked;
            let polarity_inverted_next = polarity_inverted;
            let expect_idle_next = expect_idle;
            let idle_set_valid_history_next = idle_set_valid_history;
            let character_valid_history_next =
                    shiftInAtN(
                        character_valid_history,
                        tagged Valid ev.ev.ParserResult.character_valid);

            if (ev.ev matches tagged ParserResult {
                        parser_state: .parser_state,
                        running_crc: .*,
                        character_valid: .*}) begin
                // Consider the state of the parser and determine events
                // impacting the link state.
                Bool idle1 = False;
                Bool idle2 = False;
                Bool idle_inverted = False;

                if (parser_state matches tagged AwaitingReset .r) begin
                    parser_state_next = tagged AwaitingOrderedSet;

                    case (r) matches
                        tagged Idle1 .inverted: begin
                            idle1 = True;
                            idle_inverted = inverted;
                        end

                        tagged Idle2 .inverted: begin
                            idle2 = True;
                            idle_inverted = inverted;
                        end
                    endcase
                end

                // A valid Idle1 or Idle2 set, with the correct polarity was
                // received. Update the history accordingly.
                if ((idle1 || idle2) &&
                        (!idle_inverted ||
                            (idle_inverted && !polarity_inverted))) begin
                    expect_idle_next = False;
                    idle_set_valid_history_next =
                            shiftInAt0(
                                idle_set_valid_history,
                                known_valid);
                end
                // An Idle set was expected to be completed by the received
                // character but either the parser did not return a valid
                // Idle set or the polarity was not as expected. Update the
                // history accordingly.
                else if (expect_idle) begin
                    expect_idle_next = False;
                    idle_set_valid_history_next =
                            shiftInAt0(
                                idle_set_valid_history,
                                known_invalid);
                end
                // Declare the deserializer aligned if the parser has seen a
                // valid comma. The next received character should complete
                // an Idle set. Setting this expectation will mean that if
                // this was not a valid comma according to the parser, the
                // idle_set_valid_history will be marked which in turn will
                // trigger a receiver reset if alignment is off.
                else if (parser.parsing_idle(parser_state)) begin
                    aligned_next = True;
                    expect_idle_next = True;
                    link_status_change = !aligned;
                end

                // When an Idle set is received the running disparity of the
                // link can be determined. This is idempotent and safe to
                // set any time an Idle set is received.
                if (idle1) begin
                    rd_next = RunningPositive;
                end
                else if (idle2) begin
                    rd_next = RunningNegative;
                end

                // The link polarity gets to be adjusted once. Subsequent
                // occurances of inverted Idle sets are recorded as Invalid
                // in the Idle history and will trigger a link reset.
                //
                // It is tempting to restrict this even further and only
                // allow this when the first slot in the Idle sets valid
                // history is in unknown state, but a link may receive one
                // or more invalid Idle sets as part of the alignment step.
                // In such an instance any link with inverted polarity would
                // be unable to start.
                if (!polarity_inverted && idle_inverted) begin
                    polarity_inverted_next = True;
                    link_status_change = !polarity_inverted;
                end

                // With most of the bookkeeping out of the way the only
                // thing remaining is considering the receive history to
                // determine if the link should be locked.
                if (countElem(known_invalid, character_valid_history) > 2 ||
                        idle_set_valid_history ==
                            all_idle_sets_invalid)  begin
                    reset_receiver = True;
                end
                else if (aligned &&
                        character_valid_history == all_characters_valid &&
                        idle_set_valid_history == all_idle_sets_valid) begin
                    locked_next = True;
                    link_status_change = !locked;
                end
            end
            else begin
                reset_receiver = True;
            end

            // If the logic above triggered a receiver reset do so before
            // writing back the state.
            if (reset_receiver) begin
                rd_next = RunningNegative;
                parser_state_next = tagged AwaitingOrderedSet;
                running_crc_next = crc_parameters.init;
                aligned_next = False;
                locked_next = False;
                polarity_inverted_next = False;
                expect_idle_next = False;
                idle_set_valid_history_next =
                        IdleSetValidHistory'(replicate(unknown));
                character_valid_history_next =
                        CharacterValidHistory'(replicate(unknown));
            end

            receive_state_1_id <= tagged Valid ev.id;
            receive_state_1_next <=
                ReceiveState1 {
                    rd: rd_next,
                    parser_state: parser_state_next,
                    running_crc: running_crc_next};

            receive_state_2_id <= tagged Valid ev.id;
            receive_state_2_next <=
                ReceiveState2 {
                    aligned: aligned_next,
                    locked: locked_next,
                    polarity_inverted: polarity_inverted_next,
                    expect_idle: expect_idle_next,
                    character_valid_history: character_valid_history_next,
                    idle_set_valid_history: idle_set_valid_history_next};

            if (reset_receiver) begin
                enq_event(tagged ReceiverReset);
            end
            else if (link_status_change) begin
                enq_event(tagged ReceiverStatusChange
                        LinkStatus {
                            receiver_aligned: aligned_next,
                            receiver_locked: locked_next,
                            polarity_inverted:
                                polarity_inverted_next});
            end
            else begin
                case (ev.ev.ParserResult.parser_state) matches
                    tagged AwaitingReset .result:
                        case (result) matches
                            tagged Error .e:
                                case (e)
                                    // OrderedSetInvalid errors may occur during
                                    // link start-up. To avoid this noise being
                                    // propagated in counters, suppress these
                                    // errors specifically until the link is
                                    // locked. Other errors are fair game even
                                    // if the link is not locked since the
                                    // parser should not produce them unless
                                    // conditions are really bad/odd.
                                    OrderedSetInvalid:
                                        if (locked)
                                            enq_event(tagged ReceiverEvent
                                                link_events_ordered_set_invalid);
                                    VersionInvalid:
                                        enq_event(tagged ReceiverEvent
                                            link_events_message_version_invalid);
                                    MessageTypeInvalid:
                                        enq_event(tagged ReceiverEvent
                                            link_events_message_type_invalid);
                                    ChecksumInvalid:
                                        enq_event(tagged ReceiverEvent
                                            link_events_message_checksum_invalid);
                                endcase

                            tagged Message .*:
                                enq_event(tagged TargetStatusReceived);
                        endcase

                    tagged ParsingSystemStatus .d:
                        enq_event(tagged StatusMessageFragment
                                    tagged SystemType d);

                    tagged ParsingSystemFaults .d:
                        enq_event(tagged StatusMessageFragment
                                    tagged SystemStatus d);

                    tagged ParsingRequestStatus .d:
                        enq_event(tagged StatusMessageFragment
                                    tagged SystemEvents d);

                    tagged ParsingLink0Status .d:
                        enq_event(tagged StatusMessageFragment
                                    tagged SystemPowerRequestStatus d);

                    tagged ParsingLink0Events .d:
                        enq_event(tagged StatusMessageFragment
                                    tagged Link0Status d);

                    tagged ParsingLink1Status .d:
                        enq_event(tagged StatusMessageFragment
                                    tagged Link0Events d);

                    tagged ParsingLink1Events .d:
                        enq_event(tagged StatusMessageFragment
                                    tagged Link1Status d);

                    tagged ComparingChecksum .d:
                        enq_event(tagged StatusMessageFragment
                                    tagged Link1Events d);
                endcase
            end
        end
        else if (parser_event matches tagged Invalid &&&
                    receiver_events.notFull) begin
            receive_state_1_id <= tagged Invalid;
            receive_state_2_id <= tagged Invalid;
        end

        //
        // Write back receiver state.
        //

        if (receive_state_1_id matches tagged Valid .id) begin
            receive_state_1.b.put(True, id, receive_state_1_next);
        end

        if (receive_state_2_id matches tagged Valid .id) begin
            receive_state_2.b.put(True, id, receive_state_2_next);

            channels[id].set_search_for_comma(!receive_state_2_next.aligned);
            channels[id].set_invert_polarity(
                    receive_state_2_next.polarity_inverted);

            channels_locked[id] <=
                    receive_state_2_next.aligned &&
                    receive_state_2_next.locked;
        end
    endrule

    for (Integer id = 0; id < valueOf(n); id = id + 1) begin
        (* fire_when_enabled *)
        rule do_channel_locked_watchdog
                (watchdog_fired && !channels_locked[fromInteger(id)]);
            channels[fromInteger(id)].request_reset();
        endrule
    end

    interface Vector rx = map(deserializer_client, channels);
    interface Get events = toGet(receiver_events);

    method Action tick_1khz();
        // This automatically rolls over from 0, restarting the watchdog
        // timer.
        watchdog_ticks_remaining <= watchdog_ticks_remaining - 1;
        watchdog_fired <= (watchdog_ticks_remaining == 0);
    endmethod
endmodule

typedef struct {
    UInt#(TLog#(n)) id;
    union tagged {
        void DecoderReset;
        Character Character;
    } ev;
} DeserializerEvent#(numeric type n) deriving (Bits, Eq, FShow);

typedef struct {
    UInt#(TLog#(n)) id;
    union tagged {
        void ParserReset;
        struct {
            Bit#(8) running_crc;
            StreamingStatusMessageParserState parser_state;
            Encoding8b10b::DecodeResult result;
        } DecodeResult;
    } ev;
} DecoderEvent#(numeric type n) deriving (Bits, Eq, FShow);

typedef struct {
    UInt#(TLog#(n)) id;
    union tagged {
        void ReceiverReset;
        struct {
            Bit#(8) running_crc;
            StreamingStatusMessageParserState parser_state;
            Bool character_valid;
            RunningDisparity rd;
        } ParserResult;
    } ev;
} ParserEvent#(numeric type n) deriving (Bits, Eq, FShow);

typedef union tagged {
    SystemType SystemType;
    SystemStatus SystemStatus;
    SystemFaults SystemEvents;
    RequestStatus SystemPowerRequestStatus;
    LinkStatus Link0Status;
    LinkEvents Link0Events;
    LinkStatus Link1Status;
    LinkEvents Link1Events;
} StatusMessageFragment deriving (Bits, Eq, FShow);

typedef struct {
    UInt#(TLog#(n)) id;
    union tagged {
        void ReceiverReset;
        LinkStatus ReceiverStatusChange;
        LinkEvents ReceiverEvent;
        StatusMessageFragment StatusMessageFragment;
        void TargetStatusReceived;
    } ev;
} ReceiverEvent#(numeric type n) deriving (Bits, Eq, FShow);

typedef struct {
    Bit#(8) running_crc;
    StreamingStatusMessageParserState parser_state;
    RunningDisparity rd;
} ReceiveState1 deriving (Bits);

typedef struct {
    IdleSetValidHistory idle_set_valid_history;
    CharacterValidHistory character_valid_history;
    Bool expect_idle;
    Bool polarity_inverted;
    Bool locked;
    Bool aligned;
} ReceiveState2 deriving (Bits);

function DeserializerClient deserializer_client(DeserializerChannel#(n) c) = c.deserializer;
function FIFOF#(DeserializerEvent#(n)) events(DeserializerChannel#(n) c) = c.events;
function Bool notEmpty(FIFOF#(t) f) = f.notEmpty;

function Vector#(n, Bool) select_fifo(
            Vector#(n, Bool) not_empty,
            Bit#(n) grant_base);
    let pending = {pack(not_empty), pack(not_empty)};

    match {.left, .right} = split(pending & ~(pending - extend(grant_base)));
    return unpack(left | right);
endfunction

endpackage
