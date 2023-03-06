package IgnitionProtocolParser;

export Error(..);
export Result(..);
export Parser(..);

export MessageParserState;
export MessageParser;
export mkMessageParser;

export ControllerMessageParserState;
export ControllerMessageParser;
export mkControllerMessageParser;

import DefaultValue::*;

import Encoding8b10b::*;

import IgnitionProtocol::*;


typedef enum {
    None = 0,
    VersionInvalid,
    MessageTypeInvalid,
    RequestInvalid,
    ChecksumInvalid,
    OrderedSetInvalid
} Error deriving (Bits, Eq, FShow);

typedef union tagged {
    Error Error;
    Bool Idle1;
    Bool Idle2;
    message_t Message;
} Result#(type message_t) deriving (Bits, Eq, FShow);

interface Parser #(type state_t, type message_t);
    method ActionValue#(state_t) parse(state_t s, Value v, Bit#(8) running_checksum);
    method Bool awaiting_ordered_set(state_t s);
    method Bool parsing_idle(state_t s);
    method Bool done(state_t s);
    method Maybe#(Result#(message_t)) result(state_t s);
endinterface

//
// Message Parser
//
// This is the full fat parser implementation, capable of parsing any valid
// Message type.
//

typedef Parser#(MessageParserState, Message) MessageParser;

typedef union tagged {
    void AwaitingOrderedSet;
    void ParsingIdle;
    void ParsingVersion;
    void ParsingMessageType;
    void ParsingRequest;
    void ParsingSystemType;
    Message ParsingSystemStatus;
    Message ParsingSystemFaults;
    Message ParsingRequestStatus;
    Message ParsingLink0Status;
    Message ParsingLink0Events;
    Message ParsingLink1Status;
    Message ParsingLink1Events;
    Message ComparingChecksum;
    Message ParsingEndOfMessage1;
    Result#(Message) AwaitingReset;
} MessageParserState deriving (Bits, Eq, FShow);

instance DefaultValue#(MessageParserState);
    defaultValue = tagged AwaitingOrderedSet;
endinstance

module mkMessageParser (Parser#(MessageParserState, Message));
    method ActionValue#(MessageParserState) parse(
            MessageParserState state,
            Value value,
            Bit#(8) running_checksum);
        return case (tuple2(state, value)) matches
            {tagged AwaitingOrderedSet, tagged K 'hbc}: // K28.5, comma
                tagged ParsingIdle;
            {tagged AwaitingOrderedSet, tagged K 'h1c}: // K28.0, start_of_message
                tagged ParsingVersion;
            {tagged AwaitingOrderedSet, .*}:
                tagged AwaitingOrderedSet;

            // Parse idle sets
            {tagged ParsingIdle, tagged D 'h4a}: // D10.2, idle1
                tagged AwaitingReset tagged Idle1 False;
            {tagged ParsingIdle, tagged D 'hb5}: // D21.5, bit inverse of idle1
                tagged AwaitingReset tagged Idle1 True;
            {tagged ParsingIdle, tagged D 'hb3}: // D19.5, idle2
                tagged AwaitingReset tagged Idle2 False;
            {tagged ParsingIdle, tagged D 'h4c}: // D12.2, bit inverse of idle2
                tagged AwaitingReset tagged Idle2 True;

            // Parse message header
            {tagged ParsingVersion, tagged D 1}:
                tagged ParsingMessageType;
            {tagged ParsingVersion, tagged D .*}:
                tagged AwaitingReset tagged Error VersionInvalid;

            {tagged ParsingMessageType, tagged D .d}:
                case (d)
                    1: tagged ParsingSystemType;
                    2: tagged ComparingChecksum tagged Hello;
                    3: tagged ParsingRequest;
                    default: tagged AwaitingReset tagged Error MessageTypeInvalid;
                endcase

            // Parse Request
            {tagged ParsingRequest, tagged D .d}:
                case (d)
                    1: tagged ComparingChecksum tagged Request SystemPowerOff;
                    2: tagged ComparingChecksum tagged Request SystemPowerOn;
                    3: tagged ComparingChecksum tagged Request SystemReset;
                    default: tagged AwaitingReset tagged Error RequestInvalid;
                endcase

            // Parse Status
            {tagged ParsingSystemType, tagged D .d}:
                tagged ParsingSystemStatus tagged Status{
                    system_type: unpack(d),
                    system_status: ?,
                    system_faults: ?,
                    request_status: ?,
                    link0_status: ?,
                    link0_events: ?,
                    link1_status: ?,
                    link1_events: ?};

            {tagged ParsingSystemStatus .m, tagged D .d}:
                tagged ParsingSystemFaults tagged Status {
                    system_type: m.Status.system_type,
                    system_status: unpack(truncate(d)),
                    system_faults: ?,
                    request_status: ?,
                    link0_status: ?,
                    link0_events: ?,
                    link1_status: ?,
                    link1_events: ?};

            {tagged ParsingSystemFaults .m, tagged D .d}:
                tagged ParsingRequestStatus tagged Status {
                    system_type: m.Status.system_type,
                    system_status: m.Status.system_status,
                    system_faults: unpack(truncate(d)),
                    request_status: ?,
                    link0_status: ?,
                    link0_events: ?,
                    link1_status: ?,
                    link1_events: ?};

            {tagged ParsingRequestStatus .m, tagged D .d}:
                tagged ParsingLink0Status tagged Status {
                    system_type: m.Status.system_type,
                    system_status: m.Status.system_status,
                    system_faults: m.Status.system_faults,
                    request_status: unpack(truncate(d)),
                    link0_status: ?,
                    link0_events: ?,
                    link1_status: ?,
                    link1_events: ?};

            {tagged ParsingLink0Status .m, tagged D .d}:
                tagged ParsingLink0Events tagged Status {
                    system_type: m.Status.system_type,
                    system_status: m.Status.system_status,
                    system_faults: m.Status.system_faults,
                    request_status: m.Status.request_status,
                    link0_status: unpack(truncate(d)),
                    link0_events: ?,
                    link1_status: ?,
                    link1_events: ?};

            {tagged ParsingLink0Events .m, tagged D .d}:
                tagged ParsingLink1Status tagged Status {
                    system_type: m.Status.system_type,
                    system_status: m.Status.system_status,
                    system_faults: m.Status.system_faults,
                    request_status: m.Status.request_status,
                    link0_status: m.Status.link0_status,
                    link0_events: unpack(truncate(d)),
                    link1_status: ?,
                    link1_events: ?};

            {tagged ParsingLink1Status .m, tagged D .d}:
                tagged ParsingLink1Events tagged Status {
                    system_type: m.Status.system_type,
                    system_status: m.Status.system_status,
                    system_faults: m.Status.system_faults,
                    request_status: m.Status.request_status,
                    link0_status: m.Status.link0_status,
                    link0_events: m.Status.link0_events,
                    link1_status: unpack(truncate(d)),
                    link1_events: ?};

            {tagged ParsingLink1Events .m, tagged D .d}:
                tagged ComparingChecksum tagged Status {
                    system_type: m.Status.system_type,
                    system_status: m.Status.system_status,
                    system_faults: m.Status.system_faults,
                    request_status: m.Status.request_status,
                    link0_status: m.Status.link0_status,
                    link0_events: m.Status.link0_events,
                    link1_status: m.Status.link1_status,
                    link1_events: unpack(truncate(d))};

            // Parse message footer
            {tagged ComparingChecksum .m, tagged D .d}:
                (begin
                    if (d == running_checksum)
                        tagged ParsingEndOfMessage1 m;
                    else
                        tagged AwaitingReset tagged Error ChecksumInvalid;
                end);

            {tagged ParsingEndOfMessage1 .m, tagged K 'hf7}: // K23.7
                tagged AwaitingReset tagged Message m;

            // Reject anything else as an invalid ordered set.
            default:
                tagged AwaitingReset tagged Error OrderedSetInvalid;
        endcase;
    endmethod

    method Bool awaiting_ordered_set(MessageParserState state);
        return case (state) matches
            tagged AwaitingOrderedSet: True;
            default: False;
        endcase;
    endmethod

    method Bool parsing_idle(MessageParserState state);
        return case (state) matches
            tagged ParsingIdle: True;
            default: False;
        endcase;
    endmethod

    method Bool done(MessageParserState state);
        return case (state) matches
            tagged AwaitingReset .*: True;
            default: False;
        endcase;
    endmethod

    method Maybe#(Result#(Message)) result(MessageParserState state);
        return case (state) matches
            tagged AwaitingReset .result: tagged Valid result;
            default: tagged Invalid;
        endcase;
    endmethod
endmodule

//
// ControllerMessage Parser
//
// This is a slimmed down parser implementation only capable of parsing Hello
// and Request messages. If a Status message is encountered in the character
// stream a MessageTypeInvalid error is generated.
//

typedef Parser#(ControllerMessageParserState, ControllerMessage)
    ControllerMessageParser;

typedef union tagged {
    void AwaitingOrderedSet;
    void ParsingIdle;
    void ParsingVersion;
    void ParsingMessageType;
    void ParsingRequest;
    ControllerMessage ComparingChecksum;
    ControllerMessage ParsingEndOfMessage1;
    Result#(ControllerMessage) AwaitingReset;
} ControllerMessageParserState deriving (Bits, Eq, FShow);

instance DefaultValue#(ControllerMessageParserState);
    defaultValue = tagged AwaitingOrderedSet;
endinstance

module mkControllerMessageParser
        (Parser#(ControllerMessageParserState, ControllerMessage));
    method ActionValue#(ControllerMessageParserState) parse(
            ControllerMessageParserState state,
            Value value,
            Bit#(8) running_checksum);
        return case (tuple2(state, value)) matches
            {tagged AwaitingOrderedSet, tagged K 'hbc}: // K28.5, comma
                tagged ParsingIdle;
            {tagged AwaitingOrderedSet, tagged K 'h1c}: // K28.0, start_of_message
                tagged ParsingVersion;
            {tagged AwaitingOrderedSet, .*}:
                tagged AwaitingOrderedSet;

            // Parse idle sets
            {tagged ParsingIdle, tagged D 'h4a}: // D10.2, idle1
                tagged AwaitingReset tagged Idle1 False;
            {tagged ParsingIdle, tagged D 'hb5}: // D21.5, bit inverse of idle1
                tagged AwaitingReset tagged Idle1 True;
            {tagged ParsingIdle, tagged D 'hb3}: // D19.5, idle2
                tagged AwaitingReset tagged Idle2 False;
            {tagged ParsingIdle, tagged D 'h4c}: // D12.2, bit inverse of idle2
                tagged AwaitingReset tagged Idle2 True;

            // Parse message header
            {tagged ParsingVersion, tagged D 1}:
                tagged ParsingMessageType;
            {tagged ParsingVersion, tagged D .*}:
                tagged AwaitingReset tagged Error VersionInvalid;

            {tagged ParsingMessageType, tagged D .d}:
                case (d)
                    2: tagged ComparingChecksum tagged Hello;
                    3: tagged ParsingRequest;
                    default: tagged AwaitingReset tagged Error MessageTypeInvalid;
                endcase

            // Parse Request
            {tagged ParsingRequest, tagged D .d}:
                case (d)
                    1: tagged ComparingChecksum tagged Request SystemPowerOff;
                    2: tagged ComparingChecksum tagged Request SystemPowerOn;
                    3: tagged ComparingChecksum tagged Request SystemReset;
                    default: tagged AwaitingReset tagged Error RequestInvalid;
                endcase

            // Parse message footer
            {tagged ComparingChecksum .m, tagged D .d}:
                (begin
                    if (d == running_checksum)
                        tagged ParsingEndOfMessage1 m;
                    else
                        tagged AwaitingReset tagged Error ChecksumInvalid;
                end);

            {tagged ParsingEndOfMessage1 .m, tagged K 'hf7}: // K23.7
                tagged AwaitingReset tagged Message m;

            // Reject anything else as an invalid ordered set.
            default:
                tagged AwaitingReset tagged Error OrderedSetInvalid;
        endcase;
    endmethod

    method Bool awaiting_ordered_set(ControllerMessageParserState state);
        return case (state) matches
            tagged AwaitingOrderedSet: True;
            default: False;
        endcase;
    endmethod

    method Bool parsing_idle(ControllerMessageParserState state);
        return case (state) matches
            tagged ParsingIdle: True;
            default: False;
        endcase;
    endmethod

    method Bool done(ControllerMessageParserState state);
        return case (state) matches
            tagged AwaitingReset .*: True;
            default: False;
        endcase;
    endmethod

    method Maybe#(Result#(ControllerMessage))
            result(ControllerMessageParserState state);
        return case (state) matches
            tagged AwaitingReset .result: tagged Valid result;
            default: tagged Invalid;
        endcase;
    endmethod
endmodule

endpackage
