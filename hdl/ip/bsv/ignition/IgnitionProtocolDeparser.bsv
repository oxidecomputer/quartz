package IgnitionProtocolDeparser;

import DefaultValue::*;

import Encoding8b10b::*;

import IgnitionProtocol::*;


typedef enum {
    EmitStartOfMessage,
    EmitVersion,
    EmitMessageType,
    EmitSystemType,
    EmitSystemStatus,
    EmitSystemFaults,
    EmitRequestStatus,
    EmitLink0Status,
    EmitLink0Events,
    EmitLink1Status,
    EmitLink1Events,
    EmitRequest,
    EmitChecksum,
    EmitEndOfMessage1,
    AwaitReset
} State deriving (Bits, Eq, FShow);

instance DefaultValue#(State);
    defaultValue = EmitStartOfMessage;
endinstance

function Tuple2#(State, Value)
        deparse(State s, Message m, Bit#(8) crc) =
    case (s)
        EmitStartOfMessage:
            tuple2(EmitVersion, start_of_message);

        EmitVersion:
            tuple2(
                EmitMessageType,
                tagged D fromInteger(defaultValue.version));

        EmitMessageType:
            case (m) matches
                tagged Status .*:
                    tuple2(EmitSystemType, tagged D 1);
                tagged Hello:
                    tuple2(EmitChecksum, tagged D 2);
                tagged Request .*:
                    tuple2(EmitRequest, tagged D 3);
            endcase

        // Emit Status
        EmitSystemType:
            tuple2(EmitSystemStatus, tagged D extend(pack(m.Status.system_type)));

        EmitSystemStatus:
            tuple2(EmitSystemFaults, tagged D extend(pack(m.Status.system_status)));

        EmitSystemFaults:
            tuple2(EmitRequestStatus, tagged D extend(pack(m.Status.system_faults)));

        EmitRequestStatus:
            tuple2(EmitLink0Status, tagged D extend(pack(m.Status.request_status)));

        EmitLink0Status:
            tuple2(EmitLink0Events, tagged D extend(pack(m.Status.link0_status)));

        EmitLink0Events:
            tuple2(EmitLink1Status, tagged D extend(pack(m.Status.link0_events)));

        EmitLink1Status:
            tuple2(EmitLink1Events, tagged D extend(pack(m.Status.link1_status)));

        EmitLink1Events:
            tuple2(EmitChecksum, tagged D extend(pack(m.Status.link1_events)));

        // Emit Request
        EmitRequest:
            tuple2(EmitChecksum, tagged D extend(pack(m.Request)));

        // Emit end of message
        EmitChecksum:
            tuple2(EmitEndOfMessage1, tagged D crc);

        EmitEndOfMessage1:
            tuple2(AwaitReset, end_of_message1);
    endcase;

endpackage
