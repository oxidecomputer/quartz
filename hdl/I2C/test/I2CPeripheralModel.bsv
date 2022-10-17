// Copyright 2022 Oxide Computer Company
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

// Simulation Interface for a basic I2C peripheral
// Since Bluesim does not support tri-states/inouts, take the output_en
// from the controller and use it to gate the peripheral output

package I2CPeripheralModel;

import Connectable::*;
import ConfigReg::*;
import FIFO::*;
import GetPut::*;
import StmtFSM::*;
import Vector::*;

import I2CCommon::*;

interface I2CPeripheralModel;
    method Action scl_i(Bit#(1) scl_i_next);
    method Bit#(1) sda_o;
    method Action sda_i_en(Bit#(1) sda_i_en);
    method Action sda_i(Bit#(1) sda_i_next);

    interface Put#(ModelEvent) send;
    interface Get#(ModelEvent) receive;
    method Action nack_next();
endinterface

typedef union tagged {
    void    ReceivedStart;
    void    ReceivedStop;
    void    ReceivedAck;
    void    ReceivedNack;
    void    AddressMatch;
    void    AddressMismatch;
    Bit#(8) TransmittedData;
    Bit#(8) ReceivedData;
} ModelEvent deriving (Bits, Eq, FShow);

typedef enum {
    AwaitStartByte      = 0,
    ReceiveStartByte    = 1,
    ReceiveByte         = 2,
    TransmitByte        = 3,
    ReceiveAck          = 4,
    TransmitAck         = 5,
    AwaitStop           = 6
} ModelState deriving (Eq, Bits, FShow);

/*
    Generic I2C Peripheral Model

    I2C address assigned at instantiation (i2c_address)
*/
module mkI2CPeripheralModel #(Bit#(7) i2c_address) (I2CPeripheralModel);
    // The peripheral's 7-bit I2C address
    Reg#(Bit#(7)) peripheral_address    <- mkReg(i2c_address);

    // The register map
    Reg#(Vector#(256, Bit#(8))) memory_map <- mkReg(map(fromInteger, genVector()));

    // ModelEvent buffers
    FIFO#(ModelEvent) outgoing_events    <- mkFIFO1();

    Reg#(Bit#(1)) sda_out       <- mkReg(1);
    Reg#(Bit#(1)) sda_in_en     <- mkReg(1);
    Reg#(Bit#(1)) sda_in        <- mkReg(1);
    Reg#(Bit#(1)) sda_prev      <- mkReg(1);
    Reg#(Bit#(1)) scl_in        <- mkReg(1);
    Reg#(Bit#(1)) scl_in_prev   <- mkReg(1);
    PulseWire scl_redge         <- mkPulseWire();
    PulseWire scl_in_fedge      <- mkPulseWire();
    PulseWire sda_redge         <- mkPulseWire();
    PulseWire sda_fedge         <- mkPulseWire();

    PulseWire start_detected    <- mkPulseWire();
    PulseWire stop_detected     <- mkPulseWire();

    Reg#(ModelState) state      <- mkReg(AwaitStartByte);
    Reg#(ShiftBits) shift_bits  <- mkReg(shift_bits_reset);

    Reg#(Bit#(8)) cur_data          <- mkReg(0);
    ConfigReg#(UInt#(8)) cur_addr   <- mkConfigReg(0);

    Reg#(Bool) addr_set         <- mkReg(False);
    Reg#(Bool) is_read          <- mkReg(False);
    Reg#(Bool) is_sequential    <- mkReg(False);
    Reg#(Bool) do_read          <- mkReg(False);
    Reg#(Bool) do_write         <- mkReg(False);
    Reg#(Bool) nack_next_       <- mkReg(False);


    (* fire_when_enabled *)
    rule do_detect_scl_fedge;
        scl_in_prev <= scl_in;

        if (scl_in == 0 && scl_in_prev == 1) begin
            scl_in_fedge.send();
        end
    endrule

    (* fire_when_enabled *)
    rule do_detect_sda_edges;
        sda_prev <= sda_in;

        if (sda_in == 1 && sda_prev == 0) begin
            sda_redge.send();
        end else if (sda_in == 0 && sda_prev == 1) begin
            sda_fedge.send();
        end
    endrule

    (* fire_when_enabled *)
    rule do_detect_start(scl_in == 1 && sda_fedge);
        start_detected.send();
    endrule

    (* fire_when_enabled *)
    rule do_detect_stop(scl_in == 1 && sda_redge);
        stop_detected.send();
    endrule

    (* fire_when_enabled *)
    rule do_await_start (state == AwaitStartByte);
        shift_bits  <= shift_bits_reset;
        is_sequential   <= False;
        if (start_detected) begin
            state <= ReceiveStartByte;
            outgoing_events.enq(tagged ReceivedStart);
        end
    endrule

    (* fire_when_enabled *)
    rule do_receive_start_byte (state == ReceiveStartByte);
        addr_set        <= False;
        if (scl_redge) begin
            case (last(shift_bits)) matches
                tagged Invalid: begin
                    shift_bits <= shiftInAt0(shift_bits, tagged Valid sda_in);
                end
            endcase
        end

        case (last(shift_bits)) matches
            tagged Valid .bit_: begin
                shift_bits  <= shift_bits_reset;
                let command_byte = pack(map(bit_from_maybe, shift_bits));
                if (command_byte[7:1] == peripheral_address) begin
                    is_read <= command_byte[0] == 1;
                    state   <= TransmitAck;
                    outgoing_events.enq(tagged AddressMatch);
                end else begin
                    state   <= AwaitStartByte;
                    outgoing_events.enq(tagged AddressMismatch);
                end
            end
        endcase

    endrule

    (* fire_when_enabled *)
    rule do_receive_byte (state == ReceiveByte);

        if (stop_detected) begin
            state <= AwaitStartByte;
            outgoing_events.enq(tagged ReceivedStop);
        end else if (start_detected && !scl_redge) begin
            shift_bits  <= shift_bits_reset;
            state       <= ReceiveStartByte;
            outgoing_events.enq(tagged ReceivedStart);
        end else if (scl_redge) begin
            case (last(shift_bits)) matches
                tagged Invalid: begin
                    shift_bits <= shiftInAt0(shift_bits, tagged Valid sda_in);
                end
            endcase
        end else begin
            case (last(shift_bits)) matches
                tagged Valid .bit_: begin
                    state       <= TransmitAck;
                    outgoing_events.enq(tagged ReceivedData pack(map(bit_from_maybe, shift_bits)));

                    if (!addr_set) begin
                        addr_set    <= True;
                        cur_addr    <= unpack(pack(map(bit_from_maybe, shift_bits)));
                    end else if (!is_read) begin
                        let wdata        = pack(map(bit_from_maybe, shift_bits));
                        cur_data        <= wdata;
                        is_sequential   <= True;
                        if (is_sequential) begin
                            cur_addr                    <= cur_addr + 1;
                            memory_map[cur_addr + 1]    <= wdata;
                        end else begin
                            memory_map[cur_addr]        <= wdata;
                        end
                    end
                end
            endcase
        end
    endrule

    (* fire_when_enabled *)
    rule do_transmit_byte (state == TransmitByte);
        if (scl_in_fedge) begin
            case (last(shift_bits)) matches
                tagged Valid .bit_: begin
                    sda_out <= bit_;
                    shift_bits <= shiftOutFromN(tagged Invalid, shift_bits, 1);
                end

                tagged Invalid: begin
                    outgoing_events.enq(tagged TransmittedData cur_data);
                    state   <= ReceiveAck;
                end
            endcase
        end
    endrule

    (* fire_when_enabled *)
    rule do_receive_ack (state == ReceiveAck);
        if (scl_redge) begin
            if (sda_in == 0) begin
                // ACK'd, set up next byte to read
                state       <= TransmitByte;
                cur_addr    <= cur_addr + 1;
                cur_data    <= memory_map[cur_addr + 1];
                shift_bits  <= map(tagged Valid, unpack(memory_map[cur_addr + 1]));
                outgoing_events.enq(tagged ReceivedAck);
            end else begin
                // NACK'd, transaction is over
                state   <= AwaitStop;
                outgoing_events.enq(tagged ReceivedNack);
            end
        end
    endrule

    (* fire_when_enabled *)
    rule do_transmit_ack (state == TransmitAck);
        sda_out     <= pack(nack_next_);
        nack_next_  <= False;
        do_write    <= False;
        do_read     <= False;
        if (scl_redge) begin
            if (is_read) begin
                cur_data    <= memory_map[cur_addr];
                shift_bits  <= map(tagged Valid, unpack(memory_map[cur_addr]));
                state       <= TransmitByte;
            end else begin
                shift_bits  <= shift_bits_reset;
                state       <= ReceiveByte;
            end
        end
    endrule

    (* fire_when_enabled *)
    rule do_await_stop (state == AwaitStop);
        if (stop_detected) begin
            state <= AwaitStartByte;
            outgoing_events.enq(tagged ReceivedStop);
        end
    endrule

    method Action scl_i(Bit#(1) scl_i_next);
        scl_in._write(scl_i_next);
        if (scl_i_next == 1 && scl_in == 0) begin
            scl_redge.send();
        end
    endmethod

    method Action sda_i(Bit#(1) sda_i_next) = sda_in._write(sda_i_next);

    method Action sda_i_en(Bit#(1) sda_i_en_next) = sda_in_en._write(sda_i_en_next);

    method Bit#(1) sda_o();
        return sda_out & ~sda_in_en;
    endmethod

    method Action nack_next();
        nack_next_ <= True;
    endmethod

    interface Get receive = toGet(outgoing_events);
endmodule

endpackage: I2CPeripheralModel
