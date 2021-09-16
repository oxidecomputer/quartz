// Copyright 2021 Oxide Computer Company
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

// This is a SPI peripheral for implementation in an FPGA.
// SPI devices may opporate in a number of different modes specified by
// a clock polarity (CPOL) and clock phase  (CPHA) which are often specified
// using numbers as described below.
//
// Clock Polarity
// --------------
// CPOL = 0 means a clock idles at 0 and pulses at 1. the leading edge is rising,
//  the trailing edge is falling.
// CPOL = 1 flips the behavior (leading falls, trailing rises).
//
// Clock Phase
//------------
// CPHA = 0 means the out-side changes data on the trailing edge, the in side captures
//  data on the leading edge. The out side must hold data valid until the trailing edge.
//  The first bit out (MOSI) needs to be on the wire before the first clock
// CPHA = 1 is opposite of CPHA0, thus the MISO bit remains valid until select is deasserted.
//
// This block supports SPI modes 0, 0.
// The main interface exposes a BSV client interface to upper-level blocks that
// may deal with an upper level protocol. This block is only concerned with shifting
// data in and out and another block above this will consume and provide the data.
// This block will reset the shifters when chip-select is de-asserted to prevent or
// recover from synchronization issues and provides an indication of selection loss
// for upper blocks to also reset/drop/recover.
//
//             ┌─────────────────────────────────────────────────────┐
//             │                    SPIPeriph                        │
//             │                                                     │
//             │                                                     │
//             │    ┌───────────────────┐                            │
//             │    │                   │◄───────────────────────────┼──  MOSI
// ◄────────── │    │   Deserializer    │                            │
//             │    │                   │◄────── ┌──────────────┐    │
//             │    └───────────────────┘        │              │ ◄──┼─── CS_N
//   Client IF │                                 │  BusMonitor  │    │
//    (bytes)  │    ┌───────────────────┐        │              │ ◄──┼─── SCLK
//             │    │                   │◄────── └──────────────┘    │
// ──────────► │    │    Serializer     │                            │
//             │    │                   ├────────────────────────────┼─►  MISO
//             │    └───────────────────┘                            │
//             │                                                     │
//             │                                                     │
//             └─────────────────────────────────────────────────────┘

package SpiPeriph;

import Connectable::*;
import ClientServer::*;
import GetPut::*;
import StmtFSM::*;
import TestUtils::*;
import Vector::*;


// Main exported interface for this block, expected to be dropped into
// user designs.
//   This interface includes the physical SPI pins, and a BSV client interface which will
//   provide the external requests to an upper-level block which provides responses as
//   appropriate.
interface Spi_periph;
    interface Client#(Bit#(8), Bit#(8)) spi_sys_if;  // Request/response interface to larger system
    (* prefix = "" *)
    interface SpiPins pins;
endinterface

// Physical pins interface
interface SpiPins;
    (* prefix = "" *)
    method Action csn(Bit#(1) value);   // Chip select pin, always sampled
    method Action sclk(Bit#(1) value);  // sclk pin, always sampled
    method Action mosi(Bit#(1) data);   // Input data pin sampled on appropriate sclk detected edge
    method Bit#(1) miso; // Output pin, always valid, shifts on appropriate sclk detected edge
endinterface;

// Internal interface for chipselect and sample logic
interface BusMonitor;
    method Put#(Bit#(1)) sclk;
    method Put#(Bit#(1)) csn;
    interface PulseWire spi_clk_redge;
    interface PulseWire spi_clk_fedge;
endinterface

// The deserializer block takes the sampled mosi and
// stores it in a shift register
interface Deserializer;
    // Strobed to sync reset the state machine if we lose selection unexpectedly
    interface PulseWire select_lost;
    // Something samples the input and uses the put
    // interface to bring the data in.
    interface Put#(Bit#(1)) mosi;
    // After 8 bits are sampled the rx'd byte is 
    // available via the get interface
    interface Get#(Bit#(8)) rxd_byte;
endinterface

// The serializer block takes the data to be transmitted and
// shifts it out each sclk cycle
interface Serializer;
    // Strobed to sync reset the state machine if we lose selection unexpectedly
    interface PulseWire select_lost;
    // feed byte to be shifted out into the put if
    interface Put#(Bit#(8)) tx_data;
    // Output serial bit available via the get if
    interface Get#(Bit#(1)) miso;
endinterface




// TX shift register. Can only put new data in once
// current data is shifted out (done shifting and ready for new data when
// tx_bits is tagged Invalid).
module mkSerializer (Serializer);
    // Registers
    Reg#(Maybe#(Bit#(8))) tx_bits <- mkReg(tagged Invalid);
    Reg#(UInt#(4)) cnts <- mkReg(0);
    Reg#(Bit#(1)) out_bit <- mkRegU();  // Don't care reset
    
    // Wiring
    RWire#(Bit#(8)) new_tx_bits <- mkRWire();
    PulseWire deselected <- mkPulseWire();  // Bus-select went away, reset the shifters
    PulseWire shift_out_bit <- mkPulseWire();  // We need to shift and output new value

    (* fire_when_enabled *)
    rule do_serialize if (!deselected);
        // We want to grab the remaining bit or the next byte.
        // `maybe_in_byte` will be either the Invalid variant, in which case the output
        // bit should be 0, or Valid containing some number of bits to be shifted out.
        let maybe_in_bits = isValid(new_tx_bits.wget()) ? new_tx_bits.wget() : tx_bits;

        if (shift_out_bit) begin
            // A bit is shifting out and a new byte my be clocked in
            cnts <= cnts + 1;
            out_bit <= fromMaybe(0, maybe_in_bits)[7];
            // Still shifting, not done case
            if (isValid(tx_bits) && cnts < 7)  begin

                tx_bits <= tagged Valid (fromMaybe(?, tx_bits) << 1);
            end
            // Done shifting have new bits case
            if (cnts == 8 && isValid(new_tx_bits.wget()) ) begin
                tx_bits <= maybe_in_bits;
            // Done shifting, no new bits case
            end else if (cnts == 8 && !isValid(new_tx_bits.wget())) begin
                tx_bits <= tagged Invalid;
            end
        // Not shifting so hold current bits or load newly available ones.
        end else begin
            tx_bits <= maybe_in_bits;
        end
    endrule

    (* fire_when_enabled *)
    rule do_reset if (deselected);
        // Sync reset our state registers back so we can start a new transaction when
        // we are re-selected.
        tx_bits <= tagged Invalid;
        cnts    <= 0;
        out_bit <= 0;
    endrule

    interface PulseWire select_lost = deselected;
    interface Get miso;
        method ActionValue#(Bit#(1)) get();
            shift_out_bit.send();  // Set strobe to drive shifter logic
            return out_bit;
        endmethod
    endinterface

    interface Put tx_data;
        method Action put(Bit#(8) tx_data) if (!isValid(tx_bits));
            new_tx_bits.wset(tx_data);
        endmethod
    endinterface


endmodule

// This is a fairly garbage testbench that doesn't really pound on the design
(* synthesize *)
module mkSerializerTest (Empty);
    Serializer ser <- mkSerializer();
    

    mkAutoFSM(seq
        ser.tx_data.put('h55);
        action

            assert_get(ser.miso, 1, "expected idle bit");
        endaction
        repeat(7) assert_get(ser.miso, 1, "expected high bit");
    endseq);

    mkTestWatchdog(15);
endmodule

// RX shift register.
// on each put request, data the sampled data is passed in causing a shift
// the get interface is valid when rx_bits is tagged valid (once we've had 8 shifts)
module mkDeserializer (Deserializer);
    
    // Sample buffer. We have 9 bits such that the msb means valid rather
    // than keeping a counter    
    Reg#(Vector#(9, Bit#(1))) rx_bits <- mkReg(unpack(1));
    
    // Putting a value here indicates we should sample the signal and cause a shift
    RWire#(Bit#(1)) cur_mosi <- mkRWire();
    // This indicates the data was pulled out and we use it to reset the shift register
    PulseWire byte_dequeued <- mkPulseWire();
    PulseWire deselected <- mkPulseWire();

    (* fire_when_enabled *)
    rule do_deserialize if (!deselected);
        let new_bits = byte_dequeued ? unpack(1) : rx_bits;
        if (isValid(cur_mosi.wget())) begin
            new_bits = shiftInAt0(rx_bits, fromMaybe(?, cur_mosi.wget()));
        end
        rx_bits <= new_bits;
    endrule

    (* fire_when_enabled *)
    rule do_reset if (deselected);
        rx_bits <= unpack(1);
    endrule
    
    interface select_lost = deselected;
    // Something samples the input and uses the put
    // interface to bring the data in, causing shifts
    interface Put mosi = toPut(cur_mosi);
    // After 8 bits are sampled the rx'd byte is available via the get interface
    // This is guarded by the MSB being 1 which we're using to indicate a full
    // byte has been shifted in.
     interface Get rxd_byte;
        method ActionValue#(Bit#(8)) get() if (rx_bits[8] == 1);
            byte_dequeued.send();
            return pack(rx_bits)[7:0];
        endmethod
    endinterface
endmodule


// This is a fairly garbage testbench that doesn't really pound on the design
(* synthesize *)
module mkDeserializerTest (Empty);
    Deserializer deser <- mkDeserializer();
    

    mkAutoFSM(seq
        repeat(8) deser.mosi.put(1);
        action

            assert_get(deser.rxd_byte, 'hFF, "expected idle bit");
        endaction
    endseq);

    mkTestWatchdog(15);
endmodule

// Sample control block.
// Monitors csn and sclk and drives the shifters
// Mode 0,0 or 1,1
module mkBusMonitor (BusMonitor);
    Reg#(Bit#(1)) csn_last <- mkReg(1);
    Reg#(Bit#(1)) sclk_last <- mkReg(0);

    RWire#(Bit#(1)) cur_csn <- mkRWire();
    RWire#(Bit#(1)) cur_sclk <- mkRWire();
    PulseWire redge <- mkPulseWire();
    PulseWire fedge <- mkPulseWire();
    PulseWire selection_lost <- mkPulseWire();

    // We're going to store the last state of the csn and sclk signals
    // and trigger the redge and fedge pulse wires appropriately.
    // We also want to detect loss of chip select so that the 
    // serdes blocks can reset so they're not out of sync in the case
    // of errors etc.
    rule build_samples;
        let sclk_now = fromMaybe(sclk_last, cur_sclk.wget());
        let csn_now = fromMaybe(1, cur_csn.wget());
        
        // Register history for edge detection
        sclk_last <= sclk_now;
        csn_last <= csn_now;

        // We've been selected for >1 clock cycle
        if (csn_now == 0 && csn_last == 0) begin
            if (sclk_last == 0 && sclk_now == 1) begin
                redge.send();
            end
            if (sclk_last == 1 && sclk_now == 0) begin
                fedge.send();
            end
        end
        // We're no longer selected
        if (csn_now == 1 && csn_last == 0) begin
            selection_lost.send();
        end
    endrule

    interface Put sclk = toPut(cur_sclk);
    interface Put csn = toPut(cur_csn);

    interface PulseWire spi_clk_redge = redge;
    interface PulseWire spi_clk_fedge = fedge;


endmodule

// SPI peripheral top block
module mkSpi_periph (Spi_periph);
    Serializer ser   <- mkSerializer();
    Deserializer des <- mkDeserializer();
    BusMonitor monitor <- mkBusMonitor();

    RWire#(Bit#(1)) cur_mosi <- mkRWire();

    rule do_sample;
        if (monitor.spi_clk_redge) begin
            des.mosi.put(fromMaybe(?, cur_mosi.wget()));
        end
    endrule

    method csn = monitor.csn.put;
    method sclk = monitor.sclk.put;
    method Action mosi(Bit#(1) data);
        cur_mosi.wset(data);
    endmethod
    method miso = peekGet(ser.miso); // Output pin
    interface Client spi_sys_if;
        interface request = des.rxd_byte;
        interface response = ser.tx_data;
    endinterface
        
endmodule

// This is a fairly garbage testbench that doesn't really pound on the design
(* synthesize *)
module mkPeriphTest (Empty);
    Spi_periph periph <- mkSpi_periph();
    
    Reg#(Bit#(8)) data <- mkReg('hAA);
    Reg#(Bit#(1)) sclk <- mkReg(0);
    Reg#(Bit#(1)) csn <- mkReg(1);
    Reg#(UInt#(4)) test_cnts <- mkReg(0);


    rule do_clock;
        let next_sclk = ~sclk;
        let next_csn = ~csn;
        let next_data = data;
        if (sclk == 0) begin
            test_cnts <= test_cnts + 1;  // count every spi redge
            next_data = data << 1;  // shift data ever spi redge
        end

        if (test_cnts > 7) begin
            next_csn = 0;
        end else begin
            next_csn = 1;
            next_data = 'hAA;
        end
        
        // Load current values into peripheral
        periph.csn(csn);
        periph.sclk(sclk);
        periph.mosi(data[7]);

        sclk <= next_sclk;
        data <= next_data;
        csn  <= next_csn;
    endrule

    mkTestWatchdog(15);
endmodule
endpackage