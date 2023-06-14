package IgnitionReceiver;

export Receiver(..);
export mkReceiver;

import ConfigReg::*;
import Connectable::*;
import DefaultValue::*;
import DReg::*;
import FIFO::*;
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

        //channels[i].reset_receiver <- mkReg(True);
        channels[i].aligned <- mkConfigRegU();
        channels[i].locked <- mkConfigRegU();
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

        channels[i].locked_timeout <- mkConfigRegU();
    end

    Reg#(UInt#(TLog#(n))) reset_or_fetch_select <- mkReg(0);

    FIFO#(DecodeInput#(n)) decode_input <- mkLFIFO();
    FIFO#(DecodeResult#(n)) decode_result <- mkLFIFO();
    PulseWire decode_done <- mkPulseWire();

    Reg#(parser_t) parser_state <- mkRegU();
    CRC#(8) crc <- mkIgnitionCRC();
    Reg#(Bool) parse_value <- mkDReg(False);

    Wire#(Tuple2#(UInt#(TLog#(n)), message_t)) received_message <- mkWire();

    Reg#(UInt#(8)) watchdog_ticks_remaining <- mkRegU();
    PulseWire watchdog_fired <- mkPulseWire();

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
            channels[i].polarity_inverted <= False;

            channels[i].rd <= RunningNegative;
            channels[i].character_valid_history <= replicate(unknown);

            channels[i].parser_state <= defaultValue;
            channels[i].expect_idle <= False;
            channels[i].idle_set_valid_history <= replicate(unknown);

            channels[i].locked_timeout <= False;
        endrule

        // Fetch the next character for the channel under consideration.
        (* fire_when_enabled *)
        rule do_fetch_channel_character (
                reset_or_fetch_select == fromInteger(i) &&
                channels[i].phase == Fetching);
            channels[i].phase <= Decoding;
            channels[i].character_accepted.send();

            // Prep data needed by the shared rules to decode the received
            // character.
            decode_input.enq(DecodeInput {
                channel_select: fromInteger(i),
                rd: channels[i].rd,
                character: channels[i].character});
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
            // remaining is condering the receive history to determine if the
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

            // Discard the shared parse state, allowing the next channel to
            // continue receiving a character.
            decode_result.deq();

            // Based on the outcome of the character valid history and idle set
            // checks either reset the receiver or continue waiting for the next
            // character.
            channels[i].phase <= reset_receiver ? Resetting : Fetching;
        endrule

        // Monitor the locked watchdog strobe. If the channel is not locked set
        // the timeout flag and request a reset after the next Receive phase.
        // The `locked_timeout` flag is reset during the `Resetting` phase.
        rule do_channel_locked_watchdog (
                channels[i].phase != Resetting &&
                !channels[i].locked &&
                watchdog_fired);
            channels[i].locked_timeout <= True;
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

    method Action tick_1khz();
        // This automatically rolls over from 0, restarting the watchdog
        // timer.
        watchdog_ticks_remaining <= watchdog_ticks_remaining - 1;

        if (watchdog_ticks_remaining == 0) begin
            watchdog_fired.send();
        end
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

endpackage
