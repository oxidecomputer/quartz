// Copyright 2022 Oxide Computer Company
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package I2CBitController;

export Pins(..);
export Event(..);
export I2CBitController(..);
export mkI2CBitController;

import ConfigReg::*;
import FIFO::*;
import GetPut::*;
import StmtFSM::*;
import Vector::*;

import Bidirection::*;
import Strobe::*;

import I2CCommon::*;

typedef union tagged {
    void Start;
    void Stop;
    void Ack;
    void Nack;
    Bit#(8) Write;
    Bool Read; // This Bool marks if the next byte is the last one or not
    Bit#(8) ReadData;
} Event deriving (Bits, Eq, FShow);

typedef enum {
    AwaitStart      = 0,
    TransmitStart   = 1,
    AwaitCommand    = 2,
    TransmitByte    = 3,
    ReceiveAck      = 4,
    ReceiveByte     = 5,
    TransmitStop    = 6,
    TransmitAck     = 7
} State deriving (Eq, Bits, FShow);

interface I2CBitController;
    interface Pins pins;
    interface Put#(Event) send;
    interface Get#(Event) receive;

    // way of indicating when there is no bus activity
    method Bool busy();

    // clock stretching information sent sideband from the state machine events
    method Bool scl_stretch_seen();
    method Bool scl_stretch_timeout();

    method Action abort(Bool abort);
endinterface

//
// I2C Bit Controller
// This initial implementation is very rigid and naive, be some details:
// - START condition to first rising edge of SCL is 1/2 SCL period
// - SDA switches to next value sda_transition_strobe counts after the falling
// edge of SCL
// - SDA and SCL are the inversion of their output enable signals given the open
// drain nature of an I2C bus.
// OUT_EN = 1, OUT = 0 drives the bus low
// OUT_EN = 0, OUT = 1 puts the tristate in high impedance, letting the bus
// pull-ups pull the bus high
// - Clock stretching is supported
//
module mkI2CBitController #(
        Integer core_clk_freq_hz,
        Integer i2c_scl_freq_hz,
        Integer core_clk_period_ns,
        Integer max_scl_stretch_us)
    (I2CBitController);
    // generate strobe to toggle scl at a desired period
    // ex: 50MHz / 100KHz / 2 = 250
    Integer scl_half_period_limit = core_clk_freq_hz / i2c_scl_freq_hz / 2;

    // Counts to scl_half_period_limit and then pulses
    Strobe#(8) scl_toggle_strobe <- mkLimitStrobe(1, scl_half_period_limit, 0);

    // Calculate number of ticks until we generate an error. We subtract 1 us
    // because we don't sample for stretching until we're already that duration
    // into it. See scl_stretch_sample_strobe.
    // ex: (500 - 1) us * 1000 / 20 ns = 24000
    Integer scl_stretch_limit = (max_scl_stretch_us - 1) * 1000 / core_clk_period_ns;

    // Counts the number of ticks to scl_stretch_limit and then pulses
    Strobe#(16) scl_stretch_timeout_cntr <- mkLimitStrobe(1, scl_stretch_limit, 0);

    // Counts the number of core_clk periods between the scl/sda transitions for
    // START and STOP conditions.
    // Hardcoded to 250 (5us / 20ns), where 20ns is assuming a 50MHz clock, but
    // obviously this should get parameterized along with the other clock
    // dependent functionality.
    // For standard mode (100KHz) the minimum setup time is 4.7us and hold time
    // is 4 us. For fast mode (400KHz), both of these fall to 0.6us.
    // TODO: parameterize this
    Strobe#(8) setup_strobe <- mkLimitStrobe(1, 250, 0);
    Strobe#(8) hold_strobe <- mkLimitStrobe(1, 250, 0);
    Reg#(Bool) setup_done <- mkReg(False);

    // Delays the transition of SDA after the falling edge of SCL
    // Aside from START/STOP, SDA should not change while SCL is high
    Strobe#(3) sda_transition_strobe <- mkLimitStrobe(1, 7, 0);

    // After we release SCL, wait 50 cycles (1us / 20ns) and see if the line was
    // held low by a peripheral.
    Strobe#(6) scl_stretch_sample_strobe <- mkLimitStrobe(1, 50, 0);

    // Buffers for Events
    FIFO#(Event) incoming_events    <- mkFIFO1();
    FIFO#(Event) outgoing_events    <- mkFIFO1();

    Reg#(Bit#(1))   scl_out_en      <- mkReg(0);
    Reg#(Bit#(1))   scl_out_en_next <- mkReg(0);
    Wire#(Bit#(1))  scl_in          <- mkWire();
    PulseWire       scl_redge       <- mkPulseWire();
    PulseWire       scl_fedge       <- mkPulseWire();

    Reg#(Bit#(1))   sda_out_en      <- mkReg(0);
    Wire#(Bit#(1))  sda_in          <- mkWire();
    Reg#(Bool)      sda_changed     <- mkReg(False);

    Reg#(Bit#(1)) scl_out_en_r  <- mkReg(0);
    Reg#(Bit#(1)) sda_out_en_r  <- mkReg(0);
    Reg#(Bit#(1)) scl_out_en_n  <- mkReg(0);
    Reg#(Bit#(1)) sda_out_en_n  <- mkReg(0);

    ConfigReg#(State) state     <- mkConfigReg(AwaitStart);
    ConfigReg#(Bool) scl_active <- mkConfigReg(False);
    Reg#(ShiftBits) shift_bits  <- mkReg(shift_bits_reset);
    Reg#(Bool) read_finished    <- mkReg(False);
    Wire#(Bool) abort_requested <- mkWire();
    Reg#(Bool) ack_sending      <- mkReg(False);
    PulseWire begin_transaction <- mkPulseWire();

    Reg#(Bool) scl_stretching           <- mkReg(False);
    Reg#(Bool) scl_stretch_sample_delay <- mkReg(False);
    Reg#(Bool) scl_stretch_seen_r       <- mkReg(False);
    Reg#(Bool) scl_stretch_timeout_r    <- mkReg(False);

    // When we release SCL, start counting before we sample to see if a
    // peripheral is attempting to stretch.
    (* fire_when_enabled *)
    rule do_start_scl_sample_delay(scl_redge && !scl_stretch_sample_strobe);
        scl_stretch_sample_delay <= True;
    endrule

    // Counter to time when we should sample SCL to see if its beeing stretched
    (* fire_when_enabled *)
    rule do_scl_sample_delay(scl_stretch_sample_delay);
        scl_stretch_sample_strobe.send();
    endrule

    // After the delay we know SCL is being stretched if we aren't the ones
    // holding it low.
    (* fire_when_enabled *)
    rule do_sample_scl_stretch(scl_stretch_sample_strobe);
        scl_stretching              <= scl_out_en == 0 && scl_in == 0;
        scl_stretch_sample_delay    <= False;
    endrule

    // If SCL is high then no one is holding it
    (* fire_when_enabled *)
    rule do_clear_scl_stretch(scl_in == 1 && !scl_stretch_sample_strobe);
        scl_stretching <= False;
    endrule

    // Register if we've seen any stretching and expose that externally
    (* fire_when_enabled *)
    rule do_stretching_reg;
        if (begin_transaction) begin
            scl_stretch_seen_r <= False;
        end else if (!scl_stretch_seen_r) begin
            scl_stretch_seen_r <= scl_stretching;
        end
    endrule

    // Counter to see if the peripheral has held SCL for too long
    (* fire_when_enabled *)
    rule do_scl_stretch_tick;
        if (scl_stretching) begin
            scl_stretch_timeout_cntr.send();
        end else begin
            scl_stretch_timeout_cntr <= 0;
        end
    endrule

    (* fire_when_enabled *)
    rule do_setup_delay((state == TransmitStart || state == TransmitStop)
                        && scl_out_en == 0
                        && sda_out_en == 0);
        setup_strobe.send();
    endrule

    (* fire_when_enabled *)
    rule do_hold_delay((state == TransmitStart || state == TransmitStop)
                        && scl_out_en == 0
                        && sda_out_en == 1);
        hold_strobe.send();
    endrule

    (* fire_when_enabled *)
    rule do_tick_scl_toggle(scl_active && !scl_stretching);
        scl_toggle_strobe.send();
    endrule

    (* fire_when_enabled *)
    rule do_scl_reset(!scl_active);
        scl_out_en      <= 0;
        scl_out_en_next <= 0;
    endrule

    (* fire_when_enabled *)
    rule do_scl_toggle((scl_toggle_strobe || hold_strobe)
                        && scl_active
                        && !scl_stretching);
        scl_out_en_next    <= ~scl_out_en;

        if (~scl_out_en == 0 && scl_out_en == 1) begin
            scl_redge.send();
        end

        if (~scl_out_en == 1 && scl_out_en == 0) begin
            scl_fedge.send();
        end
    endrule

    (* fire_when_enabled *)
    rule do_align_scl_to_sda(!scl_toggle_strobe && !hold_strobe && scl_active);
        scl_out_en <= scl_out_en_next;
    endrule

    (* fire_when_enabled *)
    rule do_sda_transition_delay(scl_fedge);
        sda_changed <= False;
    endrule

    (* fire_when_enabled *)
    rule do_scl_fedge_delay(!scl_fedge && sda_transition_strobe);
        sda_changed <= True;
    endrule

    (* fire_when_enabled *)
    rule do_tick_sda_transition_delay(!sda_changed);
        sda_transition_strobe.send();
    endrule

    // A peripheral has held SCL too long. Clear all controller state and wait
    // for new orders.
    (* fire_when_enabled *)
    rule do_scl_stretch_timeout(scl_stretch_timeout_cntr);
        state                   <= AwaitStart;
        scl_active              <= False;
        sda_out_en              <= 0;
        scl_stretch_timeout_r   <= True;
        incoming_events.clear();
    endrule

    // Since a SCL stretch timeout needs to highjack core state, this rule
    // cannot fire the same cycle.
    rule do_next(!scl_stretch_timeout_cntr);
        // Poll fifo for an event. If nothing is there, the rule will not fire.
        let e = incoming_events.first;

        // Handle events given the state
        case (tuple2(state, e)) matches

            {AwaitStart, tagged Start}: begin
                begin_transaction.send();
                sda_out_en              <= 0;
                state                   <= TransmitStart;
                scl_stretch_timeout_r   <= False;
                incoming_events.deq();
            end

            {TransmitStart, .*}: begin
                sda_out_en  <= pack(setup_done);

                if (scl_redge) begin
                    scl_active  <= False;
                end else if (setup_strobe) begin
                    setup_done  <= True;
                end else if (hold_strobe) begin
                    setup_done  <= False;
                    scl_active  <= True;
                    state       <= AwaitCommand;
                end
            end

            {AwaitCommand, tagged Write .byte_}: begin
                shift_bits  <= map(tagged Valid, unpack(byte_));
                state       <= TransmitByte;
            end

            {TransmitByte, .*}: begin
                if (sda_transition_strobe) begin
                    case (last(shift_bits)) matches
                        tagged Valid .bit_: begin
                            sda_out_en  <= ~bit_;
                            shift_bits  <= shiftOutFromN(tagged Invalid, shift_bits, 1);
                        end

                        tagged Invalid: begin
                            state   <= ReceiveAck;
                        end
                    endcase
                end
            end

            {ReceiveAck, .*}: begin
                if (scl_redge) begin
                    state       <= AwaitCommand;
                    incoming_events.deq();

                    if (sda_in == 0) begin
                        outgoing_events.enq(tagged Ack);
                    end else begin
                        outgoing_events.enq(tagged Nack);
                    end
                end else begin
                    sda_out_en  <= 0;
                end
            end

            {AwaitCommand, tagged Read .is_last_byte}: begin
                sda_out_en      <= 0;
                shift_bits      <= shift_bits_reset;
                read_finished   <= is_last_byte;
                state           <= ReceiveByte;
            end

            {ReceiveByte, .*}: begin
                case (last(shift_bits)) matches
                    tagged Valid .bit_: begin
                        state   <= TransmitAck;
                        outgoing_events.enq(tagged ReadData pack(map(bit_from_maybe, shift_bits)));
                    end
                endcase

                if (scl_redge) begin
                    case (last(shift_bits)) matches
                        tagged Invalid: begin
                            shift_bits <= shiftInAt0(shift_bits, tagged Valid sda_in);
                        end
                    endcase
                end
            end

            {TransmitAck, .*}: begin
                if (sda_transition_strobe && !ack_sending) begin
                    sda_out_en  <= ~pack(read_finished || abort_requested);
                    ack_sending <= True;
                end

                if (sda_transition_strobe && ack_sending) begin
                    incoming_events.deq();
                    ack_sending <= False;
                    state       <= AwaitCommand;
                end
            end

            {AwaitCommand, tagged Stop}: begin
                if (sda_transition_strobe) begin
                    sda_out_en  <= 1;
                    state       <= TransmitStop;
                end
            end

            {TransmitStop, .*}: begin
                if (scl_redge) begin
                    scl_active  <= False;
                end

                if (hold_strobe) begin
                    sda_out_en  <= 0;
                    state       <= AwaitStart;
                    incoming_events.deq();
                end
            end

            {AwaitCommand, tagged Start}: begin
                if (scl_fedge) begin
                    state   <= TransmitStart;
                    incoming_events.deq();
                end
            end
        endcase
    endrule

    // Register the output signals to have a stable output, rather than a
    // combinatorial one. This means we should register the tristate enable as
    // well to keep things aligned.
    (* fire_when_enabled *)
    rule do_register_output_inversions;
        scl_out_en_n  <= ~scl_out_en;
        sda_out_en_n  <= ~sda_out_en;

        scl_out_en_r    <= scl_out_en;
        sda_out_en_r    <= sda_out_en;
    endrule

    interface Pins pins;
        interface Bidirection scl;
            method out      = scl_out_en_n;
            method out_en   = unpack(scl_out_en_r);
            method in       = scl_in._write;
        endinterface
        interface Bidirection sda;
            method out      = sda_out_en_n;
            method out_en   = unpack(sda_out_en_r);
            method in       = sda_in._write;
        endinterface
    endinterface

    interface Put send;
        method put if (!scl_stretch_timeout_cntr) = incoming_events.enq;
    endinterface
    interface Get receive = toGet(outgoing_events);

    method busy = state != AwaitStart;

    method scl_stretch_seen     = scl_stretch_seen_r;
    method scl_stretch_timeout  = scl_stretch_timeout_r;

    method abort = abort_requested._write;
endmodule

endpackage: I2CBitController
