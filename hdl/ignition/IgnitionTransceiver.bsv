package IgnitionTransceiver;

export Transceiver(..);
export TransceiverClient(..);
export mkTransceiver;
export mkTransceivers;

export LinkId(..);
export TaggedMessage(..);
export TargetTransceiver(..);
export TargetTransceiverClient(..);
export mkTargetTransceiver;

export Loopback(..);
export mkLoopback;

import BuildVector::*;
import ConfigReg::*;
import Connectable::*;
import FIFO::*;
import GetPut::*;
import Vector::*;

import Deserializer8b10b::*;
import Encoding8b10b::*;
import Serializer8b10b::*;
import SerialIO::*;

import IgnitionProtocol::*;
import IgnitionProtocolParser::*;
import IgnitionReceiver::*;
import IgnitionTransmitter::*;


//
// `Transceiver` interface implements a transmit and receive path for a single
// link. This interface and its implementing module are used by
// `IgnitionController`.
//

interface Transceiver;
    interface SerialIO serial;
    interface GetS#(Message) to_client;
    interface PutS#(Message) from_client;
    method LinkStatus status();
    method LinkEvents events();
endinterface

interface TransceiverClient;
    interface GetS#(Message) to_txr;
    interface PutS#(Message) from_txr;
    method Action monitor(LinkStatus status, LinkEvents events);
endinterface

// Use the multi channel `Receiver` to construct a vector of `Transceiver`s.
module mkTransceivers (Vector#(n, Transceiver));
    //
    // Receive chain
    //
    Vector#(n, Deserializer) deserializers <- replicateM(mkDeserializer());
    MessageParser parser <- mkMessageParser();
    Receiver#(n, Message) rx <- mkReceiver(parser);

    mkConnection(deserializers, rx);

    // Messages are received by rx one at the time. Distribute them to a series
    // of output FIFOs based on their channel tag.
    Vector#(n, FIFO#(Message)) rx_out <- replicateM(mkLFIFO());

    for (Integer i = 0; i < valueOf(n); i = i + 1) begin
        (* fire_when_enabled *)
        rule do_receive_message (tpl_1(peekGet(rx.message)) == fromInteger(i));
            let tagged_message <- rx.message.get;
            rx_out[i].enq(tpl_2(tagged_message));
        endrule
    end

    //
    // Transmit chain
    //
    Vector#(n, Transmitter) tx <- replicateM(mkTransmitter());
    Vector#(n, Serializer) serializers <- replicateM(mkSerializer());

    zipWithM(mkConnection, tx, serializers);

    // Stitch one channel of both the receive and transmit chains into a
    // Transceiver.
    function Transceiver select_transceiver(Integer i);
        return (interface Transceiver;
            interface SerialIO serial = tuple2(
                    serializers[i].serial,
                    deserializers[i].serial);
            interface GetS to_client = fifoToGetS(rx_out[i]);
            interface PutS from_client = tx[i].message;
            method status = rx.status[i];

            // The fields in the LinkEvents struct are mutually exclusive
            // between the transmitter and receiver and both modules have their
            // unused bits set to False. As such it is assumed this "or" will
            // disappear during synthesis.
            method events = rx.events[i] | tx[i].events;
        endinterface);
    endfunction

    return map(select_transceiver, genVector);
endmodule

// Convenience constructor for just a single Transceiver. This is primarily used
// in tests.
module mkTransceiver (Transceiver);
    (* hide *) Vector#(1, Transceiver) _txrs <- mkTransceivers();
    return _txrs[0];
endmodule

//
// `TargetTransceiver` interface implements the transmit and receive paths for
// `IgnitionTarget`.
//

typedef UInt#(1) LinkId;

typedef struct {
    LinkId sender;
    ControllerMessage message;
} TaggedMessage deriving (Bits, Eq, FShow);

interface TargetTransceiver;
    interface Get#(Bit#(1)) to_link;
    interface Vector#(2, Put#(Bit#(1))) from_link;
    interface GetS#(TaggedMessage) to_client;
    interface PutS#(Message) from_client;
    method Vector#(2, LinkStatus) status();
    method Vector#(2, LinkEvents) events();
endinterface

interface TargetTransceiverClient;
    interface GetS#(Message) to_txr;
    interface PutS#(TaggedMessage) from_txr;
    method Action monitor(
        Vector#(2, LinkStatus) status,
        Vector#(2, LinkEvents) events);
endinterface

module mkTargetTransceiver (TargetTransceiver);
    // Receive chain.
    Vector#(2, Deserializer) deserializers <- replicateM(mkDeserializer());
    ControllerMessageParser parser <- mkControllerMessageParser();
    Receiver#(2, ControllerMessage) rx <- mkReceiver(parser);
    FIFO#(TaggedMessage) received_message <- mkLFIFO();

    mkConnection(deserializers, rx);

    (* fire_when_enabled *)
    rule do_receive_message;
        let message_from_channel <- rx.message.get;
        received_message.enq(TaggedMessage {
            sender: tpl_1(message_from_channel),
            message: tpl_2(message_from_channel)});
    endrule

    // Transmit chain.
    Serializer serializer <- mkSerializer();
    Transmitter tx <- mkTransmitter();

    mkConnection(tx, serializer);

    interface Get to_link = serializer.serial;
    interface Vector from_link = vec(
        deserializers[0].serial,
        deserializers[1].serial);
    interface GetS to_client = fifoToGetS(received_message);
    interface PutS from_client = tx.message;

    method status = rx.status;

    // The fields in the LinkEvents struct are mutually exclusive between the
    // transmitter and receiver and both modules have their unused bits set to
    // False. As such it is assumed this "or" will disappear during synthesis.
    method events = vec(
        rx.events[0] | tx.events,
        rx.events[1] | tx.events);
endmodule

//
// `Connectable` instances.
//

instance Connectable#(Transceiver, TransceiverClient);
    module mkConnection #(Transceiver txr, TransceiverClient client) (Empty);
        mkConnection(txr.to_client, client.from_txr);
        mkConnection(client.to_txr, txr.from_client);

        (* fire_when_enabled *)
        rule do_monitor;
            client.monitor(txr.status, txr.events);
        endrule
    endmodule
endinstance

instance Connectable#(TransceiverClient, Transceiver);
    module mkConnection #(TransceiverClient client, Transceiver txr) (Empty);
        mkConnection(txr, client);
    endmodule
endinstance

instance Connectable#(TargetTransceiver, TargetTransceiverClient);
    module mkConnection #(TargetTransceiver txr, TargetTransceiverClient client) (Empty);
        mkConnection(txr.to_client, client.from_txr);
        mkConnection(client.to_txr, txr.from_client);

        (* fire_when_enabled *)
        rule do_monitor;
            client.monitor(txr.status, txr.events);
        endrule
    endmodule
endinstance

instance Connectable#(TargetTransceiverClient, TargetTransceiver);
    module mkConnection #(TargetTransceiverClient client, TargetTransceiver txr) (Empty);
        mkConnection(txr, client);
    endmodule
endinstance

instance Connectable#(Transceiver, Transceiver);
    module mkConnection #(Transceiver a, Transceiver b) (Empty);
        mkConnection(tpl_1(a.serial), tpl_2(b.serial));
    endmodule
endinstance

instance ToSerialIO#(Transceiver);
    function SerialIO toSerialIO(Transceiver txr) = txr.serial;
endinstance

interface Loopback;
    (* always_enabled *) method Bit#(1) _read();
    method Bool connected();
    method Action set_connected(Bool connected);
endinterface

module mkLoopback #(
        Transceiver t,
        Bool polarity_inverted,
        Bit#(20) disconnect_pattern)
            (Loopback);
    Reg#(Bool) connected_ <- mkConfigReg(True);
    Reg#(Bit#(1)) b <- mkRegU();

    Reg#(UInt#(5)) disconnect_bit_select <- mkReg(0);

    (* fire_when_enabled *)
    rule do_tx;
        let tx_b <- tpl_1(t.serial).get;

        // Select between the transmitted bit or a bit from the disconnected
        // pattern.
        let b_ = connected_ ? tx_b : disconnect_pattern[disconnect_bit_select];
        // Invert the bit if the receiver is connectd with inverted polarity.
        let b__ = polarity_inverted ? ~b_ : b_;

        // Transmit a bit to the receiver.
        b <= b__;
        tpl_2(t.serial).put(b__);

        // Select the next bit from the disconnect pattern.
        if (!connected_)
            disconnect_bit_select <= ((disconnect_bit_select + 1) % 20);
    endrule

    method _read = b;
    method connected = connected_;
    method set_connected = connected_._write;
endmodule

endpackage