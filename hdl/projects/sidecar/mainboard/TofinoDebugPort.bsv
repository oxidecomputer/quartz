// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package TofinoDebugPort;

// Tofino 2 has an I2C debug port which can be used in conjunction with PCIe to
// read/modify its internal state. This module provides some glue between an I2C
// controller and SPI register map to allow this port to be used.

export ReadVolatileReg(..);
export TofinoDebugPortState(..);
export Registers(..);
export Pins(..);
export TofinoDebugPort(..);
export mkTofinoDebugPort;

// Some additional exports for convenience/tests.
export RequestOpcode(..);
export state_send_buffer_empty;
export state_send_buffer_full;
export state_receive_buffer_empty;
export state_receive_buffer_full;
export state_request_in_progress;
export state_error_valid;
export state_idle;
export state_ready_to_start_request;

import BRAMFIFO::*;
import ConfigReg::*;
import Connectable::*;
import FIFOF::*;
import GetPut::*;
import StmtFSM::*;

import CommonFunctions::*;
import I2CCore::*;
import SidecarMainboardControllerReg::*;


interface ReadVolatileReg #(type t);
    method ActionValue#(t) _read();
    method Action _write(t val);
endinterface

(* always_enabled *)
interface Registers;
    interface Reg#(TofinoDebugPortState) state;
    interface ReadVolatileReg#(Bit#(8)) buffer;
endinterface

interface TofinoDebugPort;
    interface Pins pins;
    interface Registers registers;
endinterface

// An enum type representing the possible operations performed through the debug
// port. These match what is found in
// pkgsrc/bf-platforms/platforms/accton-bf/include/bf_pltfm_slave_i2c.h.
typedef enum {
    LocalWrite = 0,
    LocalRead = 1,
    ImmediateWrite = 2,
    ImmediateRead = 3,
    DirectWrite = 4,
    DirectRead = 5,
    IndirectWrite = 6,
    IndirectRead = 7
} RequestOpcode deriving (Eq, Bits, FShow);

function Bool is_read_request(RequestOpcode opcode);
    return case (opcode)
        LocalRead,
        ImmediateRead,
        DirectRead,
        IndirectRead: True;
        default: False;
    endcase;
endfunction

function Integer request_length(RequestOpcode opcode);
    return case (opcode)
        LocalWrite: 1;
        LocalRead: 0;
        // ImmediateRead/Write do not seem to be implemented in any of the
        // Tofino platforms. These are not prohibited or filtered but will most
        // likely cause incorrect behavior so the driver should not issue them.
        ImmediateWrite: 0;
        ImmediateRead: 0;
        DirectWrite: 8;
        DirectRead: 4;
        IndirectWrite: 21;  // 40 bit address, 16 bytes of data.
        IndirectRead: 5;    // 40 bit address
    endcase;
endfunction

function Integer response_length(RequestOpcode opcode);
    return case (opcode)
        LocalRead: 1;
        DirectRead: 4;
        IndirectRead: 16;
        default: 0;
    endcase;
endfunction

typedef struct {
    Bool write;
    UInt#(3) bytes_remaining;
} Request deriving (Bits, Eq, FShow);

module mkTofinoDebugPort #(
        Integer system_frequency_hz,
        Integer system_period_ns,
        Integer i2c_frequency_hz,
        Bit#(7) tofino_i2c_address,
        Integer tofino_i2c_stretch_timeout_us)
            (TofinoDebugPort);
    I2CCore i2c <- mkI2CCore(system_frequency_hz,
                                i2c_frequency_hz,
                                system_period_ns,
                                tofino_i2c_stretch_timeout_us);
    ConfigReg#(Maybe#(Error)) error <- mkConfigReg(tagged Invalid);

    // Buffer and connections to the module interface.
    FIFOF#(Bit#(8)) send_buffer <- mkSizedBRAMFIFOF(256);
    FIFOF#(Bit#(8)) receive_buffer <- mkSizedBRAMFIFOF(256);

    // Connect the FIFOs to the register interface. The use of a DWire between
    // the receive FIFO and register interface will return a 0 if the FIFO is
    // empty. Likewise a Wire between the register interface and the send FIFO
    // will cause bytes to be dropped rather than block either serial interface
    // if the FIFO is full.
    //
    // It is be the responsibility of a driver using this peripheral to keep
    // track of these FIFOs and know how much data is expected to be received
    // based on requests issued. Fortunately the Tofino register interface
    // operates on 1, 4, or 16 bytes depending on the opcode, so this should be
    // no problem.
    Wire#(Bit#(8)) send_byte <- mkWire();
    Wire#(Bit#(8)) byte_from_receive_buffer <- mkDWire('h00);
    Wire#(Bit#(8)) byte_to_receive_buffer <- mkWire();

    PulseWire deq_send_buffer <- mkPulseWire();
    PulseWire deq_receive_buffer <- mkPulseWire();

    mkConnection(send_byte, send_buffer.enq);
    mkConnection(send_buffer.first, i2c.send_data.offer);
    mkConnection(receive_buffer.first, byte_from_receive_buffer._write);
    mkConnection(byte_to_receive_buffer, receive_buffer.enq);

    (* fire_when_enabled *)
    rule do_deq_send_buffer (deq_send_buffer || i2c.send_data.accepted);
        send_buffer.deq();

        if (i2c.send_data.accepted)
            $display("%t ", $time, fshow(send_buffer.first));
    endrule

    (* fire_when_enabled *)
    rule do_deq_receive_buffer (deq_receive_buffer);
        receive_buffer.deq;
    endrule

    // Request state.
    ConfigReg#(Bool) request_in_progress <- mkConfigReg(False);
    Reg#(RequestOpcode) opcode <- mkRegU();
    Reg#(UInt#(5)) bytes_remaining <- mkRegU();

    PulseWire start_request <- mkPulseWire();
    PulseWire clear_error <- mkPulseWire();

    FSM request_seq <- mkFSMWithPred(seq
        // Issue a Write, sending the opcode and any request data.
        action
            let opcode_byte = send_buffer.first;
            let opcode_ = RequestOpcode'(unpack(opcode_byte[7:5]));
            let request_length_ = fromInteger(request_length(opcode_));

            opcode <= opcode_;
            bytes_remaining <= request_length_;

            i2c.send_command.put(
                I2CCore::Command {
                    op: Write,
                    i2c_addr: tofino_i2c_address,
                    reg_addr: send_buffer.first,
                    num_bytes: request_length_});

            deq_send_buffer.send();

            $display(
                "%t I2C Write, ", $time,
                ((opcode_ == LocalRead || opcode_ == LocalWrite) ?
                    $format(fshow(opcode_), " %2d", opcode_byte[4:0]) :
                    $format(fshow(opcode_))),
                ", length %3d", request_length_);
        endaction

        // Move request data from the send FIFO to I2C controller. It is
        // tempting to directly use the `first`, `enq` and `deg` methods on
        // FIFOs here, but doing so would cause this action to block if there is
        // no request data to send (in the case of LocalRead) and the send FIFO
        // is empty.
        //
        // So instead those methods are called from separate rules (which will
        // appropriately block if the send FIFO is empty) to make sure this
        // sequence can keep making progress.
        while (bytes_remaining != 0) action
            if (i2c.send_data.accepted)
                bytes_remaining <= bytes_remaining - 1;
        endaction

        // In the case of a read request, turn the bus around and issue a Read
        // to get the response.
        if (is_read_request(opcode)) seq
            action
                let response_length_ = fromInteger(response_length(opcode));

                bytes_remaining <= response_length_;
                i2c.send_command.put(
                    I2CCore::Command {
                        op: Read,
                        i2c_addr: tofino_i2c_address,
                        reg_addr: ?,
                        num_bytes: response_length_});

                $display("%t I2C Read, length %3d", $time, response_length_);
            endaction

            // Read from the I2C controller and enqueue in the receive FIFO. In
            // the case of a read request at least one byte is expected to be
            // received so it is safe to call `receive_buffer.get` from within
            // this action.
            //
            // `receive_buffer.enq` may block however if the FIFO is full, so
            // write to a Wire instead allowing the byte to be dropped rather
            // than stall this action and cause the I2C controller to get out of
            // sync. It is the responsibility of the driver to make the receive
            // buffer has sufficient space to complete the request buffer and
            // not drop data (which it should know given that this can be
            // determined using the request opcodes).
            while (bytes_remaining != 0) action
                let b <- i2c.received_data.get;

                byte_to_receive_buffer <= b;
                bytes_remaining <= bytes_remaining - 1;

                $display("%t ", $time, fshow(b));
            endaction
        endseq
    endseq, request_in_progress);

    (* fire_when_enabled *)
    rule do_update_state;
        // Clear/latch errors from the I2C controller.
        if (clear_error)
            error <= tagged Invalid;
        else if (!isValid(error))
            error <= i2c.error;

        // Manage the in progress request status.
        if (isValid(i2c.error)) begin
            request_seq.abort();
            request_in_progress <= False;
        end
        // If there is data in the send buffer, start a new request if requested
        // by the driver or continue with the next request. This implictly
        // completes the last request once the send buffer is empty.
        else if ((!request_in_progress && start_request) ||
                    (request_in_progress && request_seq.done)) begin
            request_in_progress <= send_buffer.notEmpty;
        end
    endrule

    // A FSM `start` may block, so try this in its own rule. This will greedily
    // try to start the next request whenever it is allowed to.
    rule do_start_request (request_in_progress && !isValid(error));
        request_seq.start();
    endrule

    interface Pins pins = i2c.pins;

    interface Registers registers;
        interface Reg state;
            method _read =
                TofinoDebugPortState {
                    send_buffer_empty: ~pack(send_buffer.notEmpty),
                    send_buffer_full: ~pack(send_buffer.notFull),
                    receive_buffer_empty: ~pack(receive_buffer.notEmpty),
                    receive_buffer_full: ~pack(receive_buffer.notFull),
                    request_in_progress: pack(request_in_progress),
                    error_valid: pack(isValid(error)),
                    error_details: pack(fromMaybe(defaultValue, error))};

            method Action _write(TofinoDebugPortState state_);
                if (state_.send_buffer_empty == 1)
                    send_buffer.clear();

                if (state_.receive_buffer_empty == 1)
                    receive_buffer.clear();

                if (state_.request_in_progress == 1)
                    start_request.send();

                if (state_.error_valid == 1)
                    clear_error.send();
            endmethod
        endinterface

        interface ReadVolatileReg buffer;
            method ActionValue#(Bit#(8)) _read();
                deq_receive_buffer.send();
                return byte_from_receive_buffer;
            endmethod

            method _write = send_byte._write;
        endinterface
    endinterface
endmodule

TofinoDebugPortState state_send_buffer_empty = unpack('b0000001);
TofinoDebugPortState state_send_buffer_full = unpack('b0000010);
TofinoDebugPortState state_receive_buffer_empty = unpack('b0000100);
TofinoDebugPortState state_receive_buffer_full = unpack('b0001000);
TofinoDebugPortState state_request_in_progress = unpack('b0010000);
TofinoDebugPortState state_error_valid = unpack('b0100000);

TofinoDebugPortState state_idle =
    state_send_buffer_empty |
    state_receive_buffer_empty;
TofinoDebugPortState state_ready_to_start_request = state_receive_buffer_empty;

endpackage
