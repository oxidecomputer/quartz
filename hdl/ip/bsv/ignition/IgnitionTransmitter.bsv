package IgnitionTransmitter;

export Transmitter(..);
export mkTransmitter;

export ControllerTransmitter(..);
export mkControllerTransmitter;
export TransmitterEvent(..);
export TransmitterEvent_$ev(..);

import Connectable::*;
import DReg::*;
import FIFO::*;
import GetPut::*;

import Encoding8b10b::*;
import Serializer8b10b::*;
import SettableCRC::*;

import IgnitionProtocol::*;
import IgnitionProtocolDeparser::*;


interface Transmitter;
    interface PutS#(Message) message;
    interface Get#(Character) character;
    method LinkEvents events();
endinterface

typedef enum {
    Deparse,
    Encode
} Phase deriving (Bits, Eq, FShow);

module mkTransmitter (Transmitter);
    Wire#(Message) in <- mkWire();
    FIFO#(Character) out <- mkLFIFO();

    Reg#(Phase) phase <- mkReg(Deparse);

    Reg#(IgnitionProtocolDeparser::State) deparser <- mkReg(defaultValue);
    Reg#(Value) value <- mkRegU();
    CRC#(8) crc <- mkIgnitionCRC();

    // State of the link.
    Reg#(Bool) idle <- mkReg(True);
    Reg#(Bool) even <- mkReg(True);
    Reg#(RunningDisparity) rd <- mkReg(RunningNegative);
    Reg#(UInt#(2)) burst_count <- mkRegU();

    // Events
    Reg#(Bool) message_accepted <- mkDReg(False);
    Reg#(Bool) encoding_error <- mkDReg(False);

    let start_of_message =
        (even && burst_count != 3 && deparser == EmitStartOfMessage);

    (* fire_when_enabled *)
    rule do_deparse_message (phase == Deparse && (!idle || start_of_message));
        match {.deparser_, .value_} = deparse(deparser, in, crc.result);

        let done = (deparser == EmitEndOfMessage1);

        deparser <= deparser_;
        value <= value_;
        idle <= done;

        if (done) begin
            message_accepted <= True;
            burst_count <= burst_count + 1;
        end

        // Clearing the CRC during EmitVersion allows the calculation to start
        // during the Encode phase.
        if (deparser == EmitVersion)
            crc.clear();

        // Encode the value just generated by the Deparser.
        phase <= Encode;
    endrule

    (* descending_urgency = "do_deparse_message, do_select_ordered_set" *)
    rule do_select_ordered_set (phase == Deparse && idle);
        if (!even && deparser == AwaitReset)
            // A message with an odd number of characters was transmitted.
            // Transmit EndOfMessage2 to align to the sequence boundary.
            value <= end_of_message2;
        else if (!even && rd == RunningPositive)
            // The link is idle, odd and running positive. This means the link
            // is in the middle of an Idle1 sequence, since the prior comma will
            // have turned the running disparity from negative to positive.
            value <= idle1;
        else if (!even && rd == RunningNegative)
            // The link is idle, odd and running negative. This means the link
            // is in the middle of an Idle2 sequence, since the prior comma will
            // have turned the running disparity from positive to negative.
            value <= idle2;
        else begin
            // The link is idle and aligned. Transmit a comma and start the next
            // idle set. Note that this will always flip the running disparity.
            value <= comma;

            // An idle sequence is about to be transmitted, so reset the message
            // burst count.
            burst_count <= 0;
        end

        // Keep the Deparser in reset during Idle sequences.
        deparser <= EmitStartOfMessage;

        // Encode the value just selected.
        phase <= Encode;
    endrule

    (* fire_when_enabled *)
    rule do_encode_value (phase == Encode);
        let result = encode(value, rd);

        case (result.character) matches
            tagged Invalid .c: begin
                // If the result is invalid raise an error but do not change the
                // state of the link. This can really only happen if this module
                // tries encoding invalid K values so absent design bugs or
                // flipped bits at runtime this should not occur.
                //
                // Skipping a character will result in missing characters on the
                // receiver end, but the receiver will detect this either as a
                // result of a decode error, a message not parsing properly or a
                // checksum error.
                out.enq(unpack(c));
                encoding_error <= True;
            end
            tagged Valid .c: begin
                out.enq(c);
            end
        endcase

        even <= !even;
        rd <= result.rd;

        // Perform the CRC calculation in parallel with decoding the value so
        // its result will be available during the `Deparse` phase.
        crc.add(value_bits(value));

        // Select the next value for decode.
        phase <= Deparse;
    endrule

    interface PutS message;
        method offer = in._write;
        method accepted = message_accepted;
    endinterface

    interface Get character = toGet(out);

    method events =
        LinkEvents {
            message_checksum_invalid: False,
            message_type_invalid: False,
            message_version_invalid: False,
            ordered_set_invalid: False,
            decoding_error: False,
            encoding_error: encoding_error};
endmodule

instance Connectable#(Transmitter, Serializer);
    module mkConnection #(Transmitter t, Serializer s) (Empty);
        mkConnection(t.character, s.character);
    endmodule
endinstance

interface ControllerTransmitter;
    interface Put#(ControllerMessage) message;
    interface Get#(Character) character;
    method LinkEvents events();
endinterface

module mkControllerTransmitter (ControllerTransmitter);
    FIFO#(ControllerMessage) in <- mkLFIFO();
    FIFO#(Character) out <- mkLFIFO();

    Reg#(Phase) phase <- mkReg(Deparse);

    Reg#(IgnitionProtocolDeparser::State) deparser <- mkReg(defaultValue);
    Reg#(Value) value <- mkRegU();
    CRC#(8) crc <- mkIgnitionCRC();

    // State of the link.
    Reg#(Bool) idle <- mkReg(True);
    Reg#(Bool) even <- mkReg(True);
    Reg#(RunningDisparity) rd <- mkReg(RunningNegative);
    Reg#(UInt#(2)) burst_count <- mkRegU();

    // Events
    Reg#(Bool) message_accepted <- mkDReg(False);
    Reg#(Bool) encoding_error <- mkDReg(False);

    let start_of_message =
        (even && burst_count != 3 && deparser == EmitStartOfMessage);

    (* fire_when_enabled *)
    rule do_deparse_message (phase == Deparse && (!idle || start_of_message));
        match {.deparser_, .value_} =
                deparse_controller_message(deparser, in.first, crc.result);

        let done = (deparser == EmitEndOfMessage1);

        deparser <= deparser_;
        value <= value_;
        idle <= done;

        if (done) begin
            message_accepted <= True;
            burst_count <= burst_count + 1;
        end

        // Clearing the CRC during EmitVersion allows the calculation to start
        // during the Encode phase.
        if (deparser == EmitVersion)
            crc.clear();

        // Encode the value just generated by the Deparser.
        phase <= Encode;
    endrule

    (* descending_urgency = "do_deparse_message, do_select_ordered_set" *)
    rule do_select_ordered_set (phase == Deparse && idle);
        if (!even && deparser == AwaitReset)
            // A message with an odd number of characters was transmitted.
            // Transmit EndOfMessage2 to align to the sequence boundary.
            value <= end_of_message2;
        else if (!even && rd == RunningPositive)
            // The link is idle, odd and running positive. This means the link
            // is in the middle of an Idle1 sequence, since the prior comma will
            // have turned the running disparity from negative to positive.
            value <= idle1;
        else if (!even && rd == RunningNegative)
            // The link is idle, odd and running negative. This means the link
            // is in the middle of an Idle2 sequence, since the prior comma will
            // have turned the running disparity from positive to negative.
            value <= idle2;
        else begin
            // The link is idle and aligned. Transmit a comma and start the next
            // idle set. Note that this will always flip the running disparity.
            value <= comma;

            // An idle sequence is about to be transmitted, so reset the message
            // burst count.
            burst_count <= 0;
        end

        // Keep the Deparser in reset during Idle sequences.
        deparser <= EmitStartOfMessage;

        // Encode the value just selected.
        phase <= Encode;
    endrule

    (* fire_when_enabled *)
    rule do_encode_value (phase == Encode);
        let result = encode(value, rd);

        case (result.character) matches
            tagged Invalid .c: begin
                // If the result is invalid raise an error but do not change the
                // state of the link. This can really only happen if this module
                // tries encoding invalid K values so absent design bugs or
                // flipped bits at runtime this should not occur.
                //
                // Skipping a character will result in missing characters on the
                // receiver end, but the receiver will detect this either as a
                // result of a decode error, a message not parsing properly or a
                // checksum error.
                out.enq(unpack(c));
                encoding_error <= True;
            end
            tagged Valid .c: begin
                out.enq(c);
            end
        endcase

        even <= !even;
        rd <= result.rd;

        // Perform the CRC calculation in parallel with decoding the value so
        // its result will be available during the `Deparse` phase.
        crc.add(value_bits(value));

        // Select the next value for decode.
        phase <= Deparse;
    endrule

    (* fire_when_enabled *)
    rule do_message_done (message_accepted);
        in.deq();
    endrule

    interface Put message = toPut(in);
    interface Get character = toGet(out);

    method events =
        LinkEvents {
            message_checksum_invalid: False,
            message_type_invalid: False,
            message_version_invalid: False,
            ordered_set_invalid: False,
            decoding_error: False,
            encoding_error: encoding_error};
endmodule

instance Connectable#(ControllerTransmitter, Serializer);
    module mkConnection #(ControllerTransmitter t, Serializer s) (Empty);
        mkConnection(t.character, s.character);
    endmodule
endinstance

typedef struct {
    UInt#(TLog#(n)) id;
    union tagged {
        Bool OutputEnabled;
        ControllerMessage Message;
    } ev;
} TransmitterEvent#(numeric type n) deriving (Bits, Eq, FShow);

endpackage
