package TransceiverDebugTop;

import BuildVector::*;
import Clocks::*;
import ConfigReg::*;
import Connectable::*;
import GetPut::*;
import Vector::*;

import ICE40::*;
import InitialReset::*;
import IOSync::*;
import SerialIO::*;
import Strobe::*;

import Board::*;
import IgnitionProtocol::*;
import IgnitionTransceiver::*;


(* default_clock_osc = "clk_50mhz", no_default_reset *)
module mkTransceiverDebugTop (IgnitionletTargetDebug);
    Reset reset_sync <- InitialReset::mkInitialReset(3);

    Strobe#(16) strobe_1khz <-
        mkLimitStrobe(1, 50_000_000 / 1_000, 0, reset_by reset_sync);

    mkFreeRunningStrobe(strobe_1khz);

    // Transceiver primitives. The SerialIOAdapters help connect the contineous
    // input/output pins with the transceiver Get/Put interfaces and incorporate
    // a bit sampler, removing some error prone boiler plate rules.
    //
    // The tx strobe and five cycle bit samplers divide clk_50mhz into an
    // effective link baudrate of 10Mb/s.

    Strobe#(3) tx_strobe <- mkLimitStrobe(1, 5, 0, reset_by reset_sync);
    TargetTransceiver txr <- mkTargetTransceiver(True, reset_by reset_sync);

    mkFreeRunningStrobe(tx_strobe);

    // Connect link 0.
    SampledSerialIO#(5) aux0_io <-
        mkSampledSerialIOWithTxStrobe(
            tx_strobe,
            tuple2(txr.to_link, txr.from_link[0]),
            reset_by reset_sync);

    DifferentialInput#(Bit#(1)) aux0_rx <- mkDifferentialInput(InputRegistered);
    DifferentialOutput#(Bit#(1)) aux0_tx <- mkDifferentialOutput(OutputRegistered);

    mkConnection(aux0_rx, aux0_io.rx);
    mkConnection(aux0_io.tx, aux0_tx._write);

    // Connect link 1.
    //
    // The transceiver has a single Get interface, intending to broadcast the
    // same data on both links. The IOAdapter of the second link only observes
    // the serial Get interface to read the bit to be transmitterd, without
    // advancing it. This will make both IOAdapters transmit at the same time
    // without rule scheduling conflicts.
    SampledSerialIO#(5) aux1_io <-
        mkSampledSerialIOWithPassiveTx(
            tuple2(txr.to_link, txr.from_link[1]),
            reset_by reset_sync);

    DifferentialInput#(Bit#(1)) aux1_rx <- mkDifferentialInput(InputRegistered);
    DifferentialOutput#(Bit#(1)) aux1_tx <- mkDifferentialOutput(OutputRegistered);

    mkConnection(aux1_rx, aux1_io.rx);
    mkConnection(aux1_io.tx, aux1_tx._write);

    // Connect the receiver watchdog tick.
    mkConnection(asIfc(strobe_1khz), asIfc(txr.tick_1khz));

    // Loopback the received message.
    (* fire_when_enabled *)
    rule do_loopback_message;
        case (txr.to_client.first.message) matches
            tagged Hello: txr.from_client.offer(tagged Hello);
            tagged Request .r: txr.from_client.offer(tagged Request r);
        endcase

        if (txr.from_client.accepted) begin
            txr.to_client.deq();
        end
    endrule

    // Link status LEDs.
    ReadOnly#(Bit#(1)) aux0_link_status_led <-
        mkLinkStatusLED(
            txr.status[0].receiver_locked,
            txr.status[0],
            txr.receiver_locked_timeout[0],
            False,
            reset_by reset_sync);

    ReadOnly#(Bit#(1)) aux1_link_status_led <-
        mkLinkStatusLED(
            txr.status[1].receiver_locked,
            txr.status[1],
            txr.receiver_locked_timeout[1],
            False,
            reset_by reset_sync);

    ReadOnly#(Bit#(2)) led_sync <-
        mkOutputSyncFor({aux1_link_status_led, aux0_link_status_led});

    ReadOnly#(Bool) receiver_aligned_sync <-
        mkOutputSyncFor(txr.status[0].receiver_aligned);
    ReadOnly#(Bool) receiver_locked_sync <-
        mkOutputSyncFor(txr.status[0].receiver_locked);
    ReadOnly#(Bool) receiver_polarity_inverted_sync <-
        mkOutputSyncFor(txr.status[0].polarity_inverted);
    ReadOnly#(Bool) receiver_locked_timeout_sync <-
        mkOutputSyncFor(txr.receiver_locked_timeout[0]);

    method Action btn(btn_);
    endmethod

    method system_power_enable = unpack(led_sync[0]);
    method led = {'0, led_sync[1]};
    method debug = {
        '0,
        pack(receiver_locked_timeout_sync),
        pack(receiver_polarity_inverted_sync),
        pack(receiver_locked_sync),
        pack(receiver_aligned_sync)};

    interface DifferentialTransceiver aux0;
        interface DifferentialPairRx rx = aux0_rx.pads;
        interface DifferentialPairTx tx = aux0_tx.pads;
    endinterface

    interface DifferentialTransceiver aux1;
        interface DifferentialPairRx rx = aux1_rx.pads;
        interface DifferentialPairTx tx = aux1_tx.pads;
    endinterface
endmodule

endpackage
