package IgnitionEventCounter;

export Count(..);
export Counter(..);
export EventCounters(..);
export CountingMonitor(..);
export mkCounter;
export mkCountingMonitor;

import IgnitionProtocol::*;


//
// Event counters.
//

typedef struct {
    UInt#(8) x;
} Count deriving (Bits, Literal, Eq, FShow);

interface Counter;
    method ActionValue#(Count) _read();
    method Action send();
    method Action clear();
    method Bool zero();
endinterface

module mkCounter (Counter);
    Reg#(Count) count <- mkRegU();
    Reg#(Bool) zero_ <- mkRegU();

    PulseWire clear_ <- mkPulseWire;
    PulseWire read <- mkPulseWire();
    PulseWire increment <- mkPulseWire();

    (* fire_when_enabled *)
    rule do_update;
        let x_ = (read || clear_) ? 0 : count.x;
        count <= Count {x: satPlus(Sat_Bound, x_, (increment ? 1 : 0))};

        if (read || clear_ || increment)
            zero_ <= !increment;
    endrule

    method ActionValue#(Count) _read();
        read.send();
        return count;
    endmethod

    method send = increment.send;
    method clear = clear_.send;
    method zero = zero_;
endmodule

interface EventCounters;
    method LinkEvents summary();
    method ActionValue#(Count) encoding_error;
    method ActionValue#(Count) decoding_error;
    method ActionValue#(Count) ordered_set_invalid;
    method ActionValue#(Count) message_version_invalid;
    method ActionValue#(Count) message_type_invalid;
    method ActionValue#(Count) message_checksum_invalid;
    method Action clear(LinkEvents counters);
endinterface

interface CountingMonitor;
    method Action monitor(LinkEvents events);
    interface EventCounters counters;
endinterface

module mkCountingMonitor (CountingMonitor);
    Counter n_encoding_error <- mkCounter();
    Counter n_decoding_error <- mkCounter();
    Counter n_ordered_set_invalid <- mkCounter();
    Counter n_message_version_invalid <- mkCounter();
    Counter n_message_type_invalid <- mkCounter();
    Counter n_message_checksum_invalid <- mkCounter();

    method Action monitor(LinkEvents events);
        if (events.encoding_error) n_encoding_error.send();
        if (events.decoding_error) n_decoding_error.send();
        if (events.ordered_set_invalid) n_ordered_set_invalid.send();
        if (events.message_version_invalid)
            n_message_version_invalid.send();
        if (events.message_type_invalid) n_message_type_invalid.send();
        if (events.message_checksum_invalid)
            n_message_checksum_invalid.send();
    endmethod

    interface EventCounters counters;
        method summary = LinkEvents {
            encoding_error: !n_encoding_error.zero,
            decoding_error: !n_decoding_error.zero,
            ordered_set_invalid: !n_ordered_set_invalid.zero,
            message_version_invalid: !n_message_version_invalid.zero,
            message_type_invalid: !n_message_type_invalid.zero,
            message_checksum_invalid: !n_message_checksum_invalid.zero};
        method encoding_error = n_encoding_error;
        method decoding_error = n_decoding_error;
        method ordered_set_invalid = n_ordered_set_invalid;
        method message_version_invalid = n_message_version_invalid;
        method message_type_invalid = n_message_type_invalid;
        method message_checksum_invalid = n_message_checksum_invalid;

        method Action clear(LinkEvents events);
            if (events.encoding_error) n_encoding_error.clear();
            if (events.decoding_error) n_decoding_error.clear();
            if (events.ordered_set_invalid) n_ordered_set_invalid.clear();
            if (events.message_version_invalid)
                n_message_version_invalid.clear();
            if (events.message_type_invalid) n_message_type_invalid.clear();
            if (events.message_checksum_invalid)
                n_message_checksum_invalid.clear();
        endmethod
    endinterface
endmodule

endpackage
