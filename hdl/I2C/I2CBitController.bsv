// Copyright 2022 Oxide Computer Company
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package I2CBitController;

import FIFO::*;
import GetPut::*;
import StmtFSM::*;
import Vector::*;

import CommonInterfaces::*;
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
    method Bool error();
    method Action clear();
endinterface

// I2C Bit Controller
// This initial implementation is very rigid and naive, be some details:
// START condition to first rising edge of SCL is 1/2 SCL period
// SDA switches to next value at falling edge of SCL
module mkI2CBitController #(Integer core_clk_freq, Integer i2c_scl_freq) (I2CBitController);
    // generate strobe to toggle scl at a desired period
    // ex: 50MHz / 100KHz / 2 = 250
    Integer scl_half_period_limit = core_clk_freq / i2c_scl_freq / 2;

    // Counts to scl_half_period_limit and then pulses
    Strobe#(8) scl_toggle_strobe    <- mkLimitStrobe(1, scl_half_period_limit, 0);

    // Counts the number of core_clk periods between the scl/sda transitions for
    // START and STOP conditions.
    // Hardcoded to 250 (5us / 20ns), where 20ns is assuming a 50MHz clock, but
    // obviously this should get parameterized along with the other clock
    // dependent functionality.
    // For standard mode (100KHz) the minimum setup time is 4.7us and hold time
    // is 4 us. For fast mode (400KHz), both of these fall to 0.6us.
    Strobe#(8) setup_strobe <- mkLimitStrobe(1, 250, 0);
    Strobe#(8) hold_strobe <- mkLimitStrobe(1, 250, 0);
    Reg#(Bool) setup_done   <- mkReg(False);

    // Delays the transition of SDA after the falling edge of SCL
    // Aside from START/STOP, SDA should not change while SCL is high
    Strobe#(3) sda_transition_strobe <- mkLimitStrobe(1, 7, 0);

    // Buffers for Events
    FIFO#(Event) incoming_events    <- mkFIFO1();
    FIFO#(Event) outgoing_events    <- mkFIFO1();

    Reg#(Bit#(1))   scl_out         <- mkReg(1);
    Reg#(Bit#(1))   scl_out_en      <- mkReg(1);
    Wire#(Bit#(1))  scl_in          <- mkWire();
    Reg#(Bit#(1))   scl_out_next    <- mkReg(1);
    PulseWire       scl_redge       <- mkPulseWire();
    PulseWire       scl_fedge       <- mkPulseWire();

    Reg#(Bit#(1))   sda_out         <- mkReg(1);
    Reg#(Bit#(1))   sda_out_en      <- mkReg(1);
    Wire#(Bit#(1))  sda_in          <- mkWire();
    Reg#(Bool)      sda_changed     <- mkReg(False);

    Reg#(State) state           <- mkReg(AwaitStart);
    Reg#(Bool) scl_active       <- mkReg(False);
    Reg#(ShiftBits) shift_bits  <- mkReg(shift_bits_reset);
    Reg#(Bool) read_finished    <- mkReg(False);
    Reg#(Bool) ack_sending      <- mkReg(False);

    (* fire_when_enabled *)
    rule do_setup_delay((state == TransmitStart || state == TransmitStop) && scl_out == 1 && sda_out == 1);
        setup_strobe.send();
    endrule

    (* fire_when_enabled *)
    rule do_hold_delay((state == TransmitStart || state == TransmitStop) && scl_out == 1 && sda_out == 0);
        hold_strobe.send();
    endrule

    (* fire_when_enabled *)
    rule do_tick_scl_toggle(scl_active);
        scl_toggle_strobe.send();
    endrule

    (* fire_when_enabled *)
    rule do_scl_reset(!scl_active);
        scl_out_next    <= 1;
        scl_out         <= 1;
    endrule

    (* fire_when_enabled *)
    rule do_scl_toggle((scl_toggle_strobe || hold_strobe) && scl_active);
        scl_out_next    <= ~scl_out;

        if (~scl_out == 1 && scl_out == 0) begin
            scl_redge.send();
        end

        if (~scl_out == 0 && scl_out == 1) begin
            scl_fedge.send();
        end
    endrule

    (* fire_when_enabled *)
    rule do_align_scl_to_sda(!scl_toggle_strobe && !hold_strobe && scl_active);
        scl_out         <= scl_out_next;
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

    rule do_next;
        // Poll fifo for an event. If nothing is there, the rule will not fire.
        let e = incoming_events.first;

        // Handle events given the state
        case (tuple2(state, e)) matches

            {AwaitStart, tagged Start}: begin
                sda_out_en  <= 1;
                sda_out     <= 1;
                state       <= TransmitStart;
                incoming_events.deq();
            end

            {TransmitStart, .*}: begin
                sda_out_en  <= 1;
                sda_out     <= pack(!setup_done);

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
                sda_out_en  <= 1;
                shift_bits  <= map(tagged Valid, unpack(byte_));
                state       <= TransmitByte;
            end

            {TransmitByte, .*}: begin
                if (sda_transition_strobe) begin
                    case (last(shift_bits)) matches
                        tagged Valid .bit_: begin
                            sda_out <= bit_;
                            shift_bits <= shiftOutFromN(tagged Invalid, shift_bits, 1);
                        end

                        tagged Invalid: begin
                            state   <= ReceiveAck;
                        end
                    endcase
                end
            end

            {ReceiveAck, .*}: begin
                sda_out     <= 0;

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
                    sda_out_en  <= 1;
                    sda_out     <= pack(read_finished);
                    ack_sending <= True;
                end

                if (sda_transition_strobe && ack_sending) begin
                    incoming_events.deq();
                    ack_sending <= False;
                    state       <= AwaitCommand;
                end
            end

            {AwaitCommand, tagged Stop}: begin
                if (scl_fedge) begin
                    sda_out_en  <= 1;
                    sda_out     <= 0;
                    state       <= TransmitStop;
                end
            end

            {TransmitStop, .*}: begin
                if (scl_redge) begin
                    scl_active  <= False;
                end

                if (hold_strobe) begin
                    sda_out     <= 1;
                    state   <= AwaitStart;
                    incoming_events.deq();
                end
            end

            {AwaitCommand, tagged Start}: begin
                if (scl_fedge) begin
                    sda_out <= 1;
                    state   <= TransmitStart;
                    incoming_events.deq();
                end
            end
        endcase
    endrule

    interface Pins pins;
        interface Tristate scl;
            method out      = scl_out;
            method out_en   = scl_out_en;
            method in       = scl_in._write;
        endinterface
        interface Tristate sda;
            method out      = sda_out;
            method out_en   = sda_out_en;
            method in       = sda_in._write;
        endinterface
    endinterface

    interface Put send;
        method put = incoming_events.enq;
    endinterface
    interface Get receive = toGet(outgoing_events);
endmodule

endpackage: I2CBitController
