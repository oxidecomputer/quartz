package BenchTransceiver;

export Link(..);

export BenchTransceiver(..);
export mkBenchTransceiver;

export BenchTargetTransceiver(..);
export mkBenchTargetTransceiver;

import BuildVector::*;
import Connectable::*;
import DReg::*;
import FIFO::*;
import FIFOF::*;
import GetPut::*;
import Vector::*;

import IgnitionProtocol::*;
import IgnitionTransceiver::*;


interface Link;
    interface GetPut#(Message) message;
    method Action set_connected(Bool rx_connected, Bool tx_connected);
    method Action set_events(LinkEvents events);
endinterface

//
// `BenchTargetTransceiver` implements a mock link, allowing for abstracted
// interactions with a `Controller` or `Target` in test benches. This allows for
// more unit test style test benches containing only the unit under test and the
// added complexity of a full SerDes.
//

interface BenchTransceiver;
    // interfaces exposed to `TransceiverClient`.
    interface GetS#(Message) to_client;
    interface PutS#(Message) from_client;
    method LinkStatus status();
    method LinkEvents events();

    // Methods and interfaces exposed to the test bench, allowing receiver
    // events to be triggered and messages to be sent/received.
    interface Link bench;
endinterface

module mkBenchTransceiverWithTxEnable #(Bool tx_enable) (BenchTransceiver);
    FIFOF#(Message) client_to_bench <- mkFIFOF();
    FIFO#(Message) bench_to_client <- mkFIFO();
    PulseWire message_accepted <- mkPulseWire();

    Reg#(Bool) client_to_bench_connected <- mkReg(False);
    Reg#(Bool) bench_to_client_connected <- mkReg(False);

    Reg#(LinkEvents) link_events <- mkDReg(defaultValue);

    interface GetS to_client = fifoToGetS(bench_to_client);

    interface PutS from_client;
        method Action offer(Message m);
            if (client_to_bench_connected) begin
                client_to_bench.enq(m);
            end
            else begin
                $display("%5t [BenchTranceiver] Client message dropped", $time);
            end

            message_accepted.send();
        endmethod

        method accepted = message_accepted;
    endinterface

    method status =
        LinkStatus {
            receiver_aligned: bench_to_client_connected,
            receiver_locked: bench_to_client_connected,
            polarity_inverted: False};

    method events = link_events;

    interface Link bench;
        interface GetPut message;
            interface Get fst = fifoToGet(fifofToFifo(client_to_bench));

            interface Put snd;
                method Action put(Message m);
                    if (bench_to_client_connected)
                        bench_to_client.enq(m);
                    else
                        $display("%5t [BenchTranceiver] Bench message dropped", $time);
                endmethod
            endinterface
        endinterface

        method Action set_connected(
                Bool client_to_bench_connected_,
                Bool bench_to_client_connected_);
            client_to_bench_connected <= client_to_bench_connected_;
            bench_to_client_connected <= bench_to_client_connected_;
        endmethod

        method set_events = link_events._write;
    endinterface
endmodule

module mkBenchTransceiver (BenchTransceiver);
    (* hide *) BenchTransceiver _txr <- mkBenchTransceiverWithTxEnable(True);
    return _txr;
endmodule

//
// `BenchTargetTransceiver` is an adaptation of `BenchTransceiver` to accomodate
// the dual channel nature of `TargetTransceiver`.
//

interface BenchTargetTransceiver;
    // interfaces exposed to `IgnitionTarget`.
    interface GetS#(TaggedMessage) to_client;
    interface PutS#(Message) from_client;
    method Vector#(2, LinkStatus) status();
    method Vector#(2, LinkEvents) events();

    // Methods and interfaces exposed to the test bench, allowing receiver
    // events to be triggered and messages to be sent/received.
    interface Link bench;
endinterface

module mkBenchTargetTransceiver (BenchTargetTransceiver);
    // TX is always enabled for Target transceiver.
    (* hide *) BenchTransceiver _txr <- mkBenchTransceiverWithTxEnable(False);

    interface GetS to_client;
        method TaggedMessage first() =
            TaggedMessage {
                sender: 0,
                // Convert from a Message to ControllerMessage. This does
                // silently convert a Status into a Hello, but since a Target is
                // not expected to receive Status messages this seems like a
                // reasonable trade-off without hacking all this up.
                message:
                    case (_txr.to_client.first) matches
                        tagged Request .r: tagged Request r;
                        default: tagged Hello;
                    endcase};

        method Action deq() = _txr.to_client.deq;
    endinterface

    interface PutS from_client = _txr.from_client;

    method Vector#(2, LinkStatus) status = vec(
        _txr.status,
        // The second link is permanently disconnected.
        link_status_disconnected);

    method Vector#(2, LinkEvents) events = vec(
        _txr.events,
        // The second link is permanently disconnected.
        link_events_none);

    interface Link bench = _txr.bench;
endmodule

//
// Connectable instances.
//
instance Connectable#(BenchTransceiver, TransceiverClient);
    module mkConnection #(
            BenchTransceiver txr,
            TransceiverClient client) (Empty);
        mkConnection(txr.to_client, client.from_txr);
        mkConnection(client.to_txr, txr.from_client);

        (* fire_when_enabled *)
        rule do_monitor;
            client.monitor(txr.status, txr.events);
        endrule
    endmodule
endinstance

instance Connectable#(BenchTargetTransceiver, TargetTransceiverClient);
    module mkConnection #(
            BenchTargetTransceiver txr,
            TargetTransceiverClient client) (Empty);
        mkConnection(txr.to_client, client.from_txr);
        mkConnection(client.to_txr, txr.from_client);

        (* fire_when_enabled *)
        rule do_monitor;
            client.monitor(txr.status, txr.events);
        endrule
    endmodule
endinstance

endpackage
