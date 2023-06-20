package IgnitionTransceiver;

export Transceiver(..);
export Transceivers(..);
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

export mkLinkStatusLED;

import BuildVector::*;
import ConfigReg::*;
import Connectable::*;
import FIFO::*;
import GetPut::*;
import RevertingVirtualReg::*;
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
    interface GetPut#(Bit#(1)) serial;
    interface GetS#(Message) to_client;
    interface PutS#(Message) from_client;
    method LinkStatus status();
    method LinkEvents events();
    method Bool receiver_locked_timeout();
endinterface

interface Transceivers#(numeric type n);
    interface Vector#(n, Transceiver) txrs;
    // Strobe driving the shared receiver watchdog.
    method Action tick_1khz();
endinterface

interface TransceiverClient;
    interface GetS#(Message) to_txr;
    interface PutS#(Message) from_txr;
    method Action monitor(LinkStatus status, LinkEvents events);
    // Strobe driving the shared receiver watchdog.
    method Bool tick_1khz();
endinterface

// Use the multi channel `Receiver` to construct a vector of `Transceiver`s.
module mkTransceivers (Transceivers#(n));
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
            interface GetPut serial = tuple2(
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

            method receiver_locked_timeout = rx.locked_timeout[i];
        endinterface);
    endfunction

    interface Vector txrs = map(select_transceiver, genVector);
    method tick_1khz = rx.tick_1khz;
endmodule

// Convenience constructor for just a single Transceiver. This is primarily used
// in tests.
module mkTransceiver #(Bool tick_1khz) (Transceiver);
    (* hide *) Transceivers#(1) _txrs <- mkTransceivers();

    (* fire_when_enabled *)
    rule do_tick_receiver_watchdog (tick_1khz);
        _txrs.tick_1khz();
    endrule

    return _txrs.txrs[0];
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
    method Vector#(2, Bool) receiver_locked_timeout();
    // Strobe driving the shared receiver watchdog.
    method Action tick_1khz();
endinterface

interface TargetTransceiverClient;
    interface GetS#(Message) to_txr;
    interface PutS#(TaggedMessage) from_txr;
    method Action monitor(
        Vector#(2, LinkStatus) status,
        Vector#(2, LinkEvents) events);
    method Bool tick_1khz();
endinterface

module mkTargetTransceiver
        #(Bool receiver_watchdog_enabled)
            (TargetTransceiver);
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

    method receiver_locked_timeout = rx.locked_timeout;

    method Action tick_1khz();
        if (receiver_watchdog_enabled) rx.tick_1khz();
    endmethod
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

        (* fire_when_enabled *)
        rule do_tick_receiver_watchdog (client.tick_1khz);
            txr.tick_1khz();
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

module mkLinkStatusLED
        #(Bool peer_present,
            LinkStatus link_status,
            Bool locked_timeout,
            Bool invert_led)
                (ReadOnly#(Bit#(1)));
    Reg#(Bool) past_locked_timeout <- mkReg(False);
    Reg#(Bit#(1)) locked_timeout_blink <- mkReg(0);
    (* hide *) Reg#(Bit#(1)) _q <- mkReg(0);

    (* fire_when_enabled *)
    rule do_status_led;
        past_locked_timeout <= locked_timeout;

        // Use the positive edge to generate a blinky.
        locked_timeout_blink <=
                !past_locked_timeout && locked_timeout ?
                    ~locked_timeout_blink :
                    locked_timeout_blink;

        // Generate the status LED. The LED will be on if the link is up and a
        // peer is present, off if the link is aligned or locked but no peer is
        // present and blinking if no transmitter detected and the receiver is reset
        // by the watchdog.
        if (peer_present)
            _q <= invert_led ? 0 : 1;
        else if (link_status.receiver_aligned || link_status.receiver_locked)
            _q <= invert_led ? 1 : 0;
        else
            _q <= locked_timeout_blink;
    endrule

    method _read = _q;
endmodule


endpackage
