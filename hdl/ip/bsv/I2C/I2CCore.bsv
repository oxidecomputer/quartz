// Copyright 2022 Oxide Computer Company
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package I2CCore;

export Operation(..);
export Command(..);
export Error(..);
export Pins(..);
export I2CCore(..);
export mkI2CCore;

import DefaultValue::*;
import DReg::*;
import FIFO::*;
import GetPut::*;
import StmtFSM::*;

import I2CCommon::*;
import I2CBitController::*;

typedef enum {
    Read = 0,
    Write = 1,
    RandomRead = 2
} Operation deriving (Eq, Bits, FShow);

typedef struct {
    Operation op;
    Bit#(7) i2c_addr;
    Bit#(8) reg_addr;
    UInt#(8) num_bytes;
} Command deriving (Bits, Eq, FShow);

instance DefaultValue #(Command);
    defaultValue = Command {
        op: Read,
        i2c_addr: 7'h7f,
        reg_addr: 8'hff,
        num_bytes: 8'h00
    };
endinstance

typedef enum {
    Idle = 0,
    SendStart = 1,
    SendAddr = 2,
    AwaitAddrAck = 3,
    Reading = 4,
    NextRead = 5,
    Writing = 6,
    AwaitWriteAck = 7,
    Stop = 8,
    Done = 9
} State deriving (Eq, Bits, FShow);

typedef enum {
    AddressNack = 0,
    ByteNack = 1
} Error deriving (Bits, Eq, FShow);

instance DefaultValue#(Error);
    defaultValue = AddressNack;
endinstance

interface I2CCore;
    interface Pins pins;
    interface Put#(Command) send_command;
    interface PutS#(Bit#(8)) send_data;
    interface Get#(Bit#(8)) received_data;
    method Maybe#(Error) error;
    method Bool busy;
endinterface

module mkI2CCore#(Integer core_clk_freq, Integer i2c_scl_freq) (I2CCore);
    I2CBitController bit_ctrl   <- mkI2CBitController(core_clk_freq, i2c_scl_freq);

    // FIFOs for Put/Get interfaces
    FIFO#(Command) next_command <- mkFIFO1();
    FIFO#(Bit#(8)) rx_data_q    <- mkFIFO1();

    // internal state
    Reg#(Maybe#(Command)) cur_command   <- mkReg(tagged Invalid);
    Reg#(Bit#(8)) tx_data               <- mkReg(0);
    Reg#(State) state_r                 <- mkReg(Idle);
    Reg#(Maybe#(Error)) error_r         <- mkReg(tagged Invalid);
    Wire#(Bool) valid_command           <- mkWire();
    Reg#(UInt#(8)) bytes_done           <- mkReg(0);
    Reg#(Bool) in_random_read           <- mkReg(False);

    PulseWire next_send_data           <- mkPulseWire;

    (* fire_when_enabled, no_implicit_conditions *)
    rule do_valid_command;
        valid_command   <= isValid(cur_command);
    endrule

    (* fire_when_enabled *)
    rule do_register_command(state_r == Idle && !valid_command);
        cur_command <= tagged Valid next_command.first;
        error_r     <= tagged Invalid;
        state_r <= SendStart;
    endrule

    (* fire_when_enabled *)
    rule do_send_start (state_r == SendStart && valid_command);
        bit_ctrl.send.put(tagged Start);
        state_r <= SendAddr;
    endrule

    (* fire_when_enabled *)
    rule do_send_addr (state_r == SendAddr && valid_command);
        let cmd = fromMaybe(?, cur_command);
        let is_read = (cmd.op == Read) || in_random_read;
        let addr_byte = {cmd.i2c_addr, pack(is_read)};
        bit_ctrl.send.put(tagged Write addr_byte);
        state_r <= AwaitAddrAck;
    endrule

    (* fire_when_enabled *)
    rule do_await_addr_ack (state_r == AwaitAddrAck && valid_command);
        let ack_nack <- bit_ctrl.receive.get();
        let cmd = fromMaybe(?, cur_command);

        case (ack_nack) matches
            tagged Ack: begin
                if (cmd.op == Read || in_random_read) begin
                    bytes_done  <= 1;
                    bit_ctrl.send.put(tagged Read (cmd.num_bytes == 1));
                    state_r <= Reading;
                end else begin
                    bit_ctrl.send.put(tagged Write cmd.reg_addr);
                    state_r <= AwaitWriteAck;
                end
            end

            tagged Nack: begin
                state_r <= Stop;
                error_r <= tagged Valid AddressNack;
            end
        endcase
    endrule

    (* fire_when_enabled *)
    rule do_writing (state_r == Writing && valid_command);
        bit_ctrl.send.put(tagged Write tx_data);
        next_send_data.send();
        state_r <= AwaitWriteAck;
    endrule

    (* fire_when_enabled *)
    rule do_await_writing_ack (state_r == AwaitWriteAck && valid_command);
        let ack_nack <- bit_ctrl.receive.get();
        let cmd = fromMaybe(?, cur_command);

        case (ack_nack) matches
            tagged Ack: begin
                bytes_done  <= bytes_done + 1;

                if (cmd.op == RandomRead) begin
                    in_random_read  <= True;
                    state_r <= SendStart;
                end else if (cmd.num_bytes == bytes_done) begin
                    state_r <= Stop;
                end else begin
                    state_r <= Writing;
                end
            end

            tagged Nack: begin
                state_r <= Stop;
                error_r <= tagged Valid ByteNack;
            end
        endcase
    endrule

    (* fire_when_enabled *)
    rule do_reading (state_r == Reading && valid_command);
        let rdata   <- bit_ctrl.receive.get();
        let cmd     = fromMaybe(?, cur_command);

        case (rdata) matches
            tagged ReadData .data: begin
                rx_data_q.enq(data);

                if (cmd.num_bytes == bytes_done) begin
                    state_r     <= Stop;
                end else begin
                    bytes_done  <= bytes_done + 1;
                    state_r     <= NextRead;
                end
            end
        endcase
    endrule

    rule do_next_read (state_r == NextRead && valid_command);
        let cmd     = fromMaybe(?, cur_command);
        bit_ctrl.send.put(tagged Read (cmd.num_bytes == bytes_done));
        state_r <= Reading;
    endrule

    (* fire_when_enabled *)
    rule do_stop (state_r == Stop && valid_command);
        bit_ctrl.send.put(tagged Stop);
        state_r     <= Done;
    endrule

    (* fire_when_enabled *)
    rule do_done (state_r == Done && valid_command);
        next_command.deq();
        bytes_done      <= 0;
        in_random_read  <= False;
        cur_command     <= tagged Invalid;
        state_r         <= Idle;
    endrule

    interface pins = bit_ctrl.pins;

    interface Put send_command;
        method put = next_command.enq;
    endinterface

    interface PutS send_data;
        method offer = tx_data._write;
        method accepted = next_send_data;
    endinterface

    interface Get received_data = toGet(rx_data_q);

    method error = error_r;
    method busy = state_r != Idle;
endmodule

endpackage: I2CCore
