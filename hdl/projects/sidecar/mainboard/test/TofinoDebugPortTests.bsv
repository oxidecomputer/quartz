package TofinoDebugPortTests;

import Connectable::*;
import GetPut::*;
import StmtFSM::*;
import Vector::*;

import TestUtils::*;

import I2CPeripheralModel::*;
import TofinoDebugPort::*;


Bit#(7) tofino_address = 7'b1011_011;
Bit#(7) incorrect_address = 7'b0;

function Bit#(8) local_read(Bit#(5) i) = {pack(LocalRead), i};
function Bit#(8) local_write(Bit#(5) i) = {pack(LocalWrite), i};

module mkClearSendBufferTest (Empty);
    TofinoDebugPort debug_port <- mkTofinoDebugPort(10000, 5, 100, tofino_address, 5);
    I2CPeripheralModel tofino <- mkI2CPeripheralModel(tofino_address);

    mkConnection(debug_port.pins, tofino);

    let state = asIfc(debug_port.registers.state);
    let buffer = asIfc(debug_port.registers.buffer);

    mkAutoFSM(seq
        assert_set(state.send_buffer_empty, "expected send buffer empty");

        buffer <= 1;
        assert_not_set(state.send_buffer_empty, "expected send buffer not empty");

        state <= state_send_buffer_empty;
        assert_set(state.send_buffer_empty, "expected send buffer empty");
    endseq);
endmodule

module mkAbortRequestOnAddressNackTest (Empty);
    TofinoDebugPort debug_port <- mkTofinoDebugPort(10000, 5, 100, tofino_address, 5);
    I2CPeripheralModel tofino <- mkI2CPeripheralModel(incorrect_address);

    mkConnection(debug_port.pins, tofino);

    let state = asIfc(debug_port.registers.state);
    let buffer = asIfc(debug_port.registers.buffer);

    mkAutoFSM(seq
        assert_eq(state, state_idle, "expect debug port idle");

        // Submit a request.
        buffer <= local_read(1);
        assert_eq(state,
            state_ready_to_start_request,
            "expected port ready to start request");

        // Start the request and wait for the busy bit to clear.
        state <= state_request_in_progress;
        await(state.request_in_progress == 0);

        assert_set(state.error_valid, "expected error");
        assert_eq(state.error_details, 0, "expected address NACK error");

        // Clear the error and retry.
        state <= state_error_valid;
        assert_not_set(state.error_valid, "expected error cleared");
    endseq);
endmodule

module mkLocalWriteTest (Empty);
    TofinoDebugPort debug_port <- mkTofinoDebugPort(10000, 5, 100, tofino_address, 5);
    I2CPeripheralModel tofino <- mkI2CPeripheralModel(tofino_address);

    mkConnection(debug_port.pins, tofino);

    let state = asIfc(debug_port.registers.state);
    let buffer = asIfc(debug_port.registers.buffer);

    mkAutoFSM(seq
        buffer <= local_write(1);
        buffer <= 'haa;
        assert_not_set(state.send_buffer_empty, "expected send buffer not empty");
        assert_set(state.receive_buffer_empty, "expected receive buffer empty");

        // Issue the request.
        par
            seq
                state <= state_request_in_progress;
                assert_set(state.request_in_progress, "expected request in progress");
                await(state.request_in_progress == 0);
            endseq

            seq
                assert_get_eq(tofino.receive, tagged ReceivedStart, "expected START");
                assert_get_eq(tofino.receive, tagged AddressMatch, "expected address");
                assert_get_eq(
                    tofino.receive,
                    tagged ReceivedData local_write(1),
                    "expected LocalWrite of register 1");
                assert_get_eq(
                    tofino.receive,
                    tagged ReceivedData 'haa,
                    "expected data byte");
                assert_get_eq(tofino.receive, tagged ReceivedStop, "expected STOP");
            endseq
        endpar

        assert_set(state.receive_buffer_empty, "expected receive buffer still empty");
    endseq);
endmodule

module mkLocalReadTest (Empty);
    TofinoDebugPort debug_port <- mkTofinoDebugPort(10000, 5, 100, tofino_address, 5);
    I2CPeripheralModel tofino <- mkI2CPeripheralModel(tofino_address);

    mkConnection(debug_port.pins, tofino);

    let state = asIfc(debug_port.registers.state);
    let buffer = asIfc(debug_port.registers.buffer);

    mkAutoFSM(seq
        buffer <= local_read(1);
        assert_not_set(state.send_buffer_empty, "expected send buffer not empty");
        assert_set(state.receive_buffer_empty, "expected receive buffer empty");

        // Issue the request.
        par
            seq
                state <= state_request_in_progress;
                assert_set(state.request_in_progress, "expected request in progress");
                await(state.request_in_progress == 0);
            endseq

            seq
                assert_get_eq(tofino.receive, tagged ReceivedStart, "expected START");
                assert_get_eq(tofino.receive, tagged AddressMatch, "expected address");
                assert_get_eq(
                    tofino.receive,
                    tagged ReceivedData local_read(1),
                    "expected LocalRead of register 1");
                assert_get_eq(tofino.receive,tagged ReceivedStop, "expected STOP");

                assert_get_eq(tofino.receive, tagged ReceivedStart, "expected START");
                assert_get_eq(tofino.receive, tagged AddressMatch, "expected address");

                // The peripheral doesn't handle outside data just yet, so
                // ignore the response for now.
                assert_get_any(tofino.receive);
                assert_get_eq(tofino.receive, tagged ReceivedNack, "expected NACK");
                assert_get_eq(tofino.receive, tagged ReceivedStop, "expected STOP");
            endseq
        endpar

        assert_not_set(state.receive_buffer_empty, "expected receive buffer not empty");
        assert_av_not_eq(buffer, 'h00, "expected register value");
    endseq);

    mkTestWatchdog(20000);
endmodule

module mkDirectWriteTest (Empty);
    TofinoDebugPort debug_port <- mkTofinoDebugPort(10000, 5, 100, tofino_address, 5);
    I2CPeripheralModel tofino <- mkI2CPeripheralModel(tofino_address);

    mkConnection(debug_port.pins, tofino);

    let state = asIfc(debug_port.registers.state);
    let buffer = asIfc(debug_port.registers.buffer);
    let opcode_byte = Bit#(8)'({pack(DirectWrite), 5'b0});

    Vector#(4, Bit#(8)) address = unpack('h01020304);
    Vector#(4, Bit#(8)) value = unpack('h04030201);

    mkAutoFSM(seq
        buffer <= opcode_byte;
        buffer <= address[0];
        buffer <= address[1];
        buffer <= address[2];
        buffer <= address[3];
        buffer <= value[0];
        buffer <= value[1];
        buffer <= value[2];
        buffer <= value[3];

        assert_not_set(state.send_buffer_empty, "expected send buffer not empty");
        assert_set(state.receive_buffer_empty, "expected receive buffer empty");

        // Issue the request.
        par
            seq
                state <= state_request_in_progress;
                assert_set(state.request_in_progress, "expected request in progress");
                await(state.request_in_progress == 0);
            endseq

            seq
                assert_get_eq(tofino.receive, tagged ReceivedStart, "expected START");
                assert_get_eq(tofino.receive, tagged AddressMatch, "expected address");
                assert_get_eq(tofino.receive, tagged ReceivedData opcode_byte, "expected Opcode");
                assert_get_eq(tofino.receive, tagged ReceivedData 'h04, "expected address byte 0");
                assert_get_eq(tofino.receive, tagged ReceivedData 'h03, "expected address byte 1");
                assert_get_eq(tofino.receive, tagged ReceivedData 'h02, "expected address byte 2");
                assert_get_eq(tofino.receive, tagged ReceivedData 'h01, "expected address byte 3");
                assert_get_eq(tofino.receive, tagged ReceivedData 'h01, "expected value byte 0");
                assert_get_eq(tofino.receive, tagged ReceivedData 'h02, "expected value byte 1");
                assert_get_eq(tofino.receive, tagged ReceivedData 'h03, "expected value byte 2");
                assert_get_eq(tofino.receive, tagged ReceivedData 'h04, "expected value byte 3");
                assert_get_eq(tofino.receive, tagged ReceivedStop, "expected STOP");
            endseq
        endpar

        assert_set(state.receive_buffer_empty, "expected receive buffer still empty");
    endseq);

    mkTestWatchdog(20000);
endmodule

module mkDirectReadTest (Empty);
    TofinoDebugPort debug_port <- mkTofinoDebugPort(10000, 5, 100, tofino_address, 5);
    I2CPeripheralModel tofino <- mkI2CPeripheralModel(tofino_address);

    mkConnection(debug_port.pins, tofino);

    let state = asIfc(debug_port.registers.state);
    let buffer = asIfc(debug_port.registers.buffer);
    let opcode_byte = Bit#(8)'({pack(DirectRead), 5'b0});

    Vector#(4, Bit#(8)) address = unpack('h01020304);

    mkAutoFSM(seq
        buffer <= opcode_byte;
        buffer <= address[3];
        buffer <= address[2];
        buffer <= address[1];
        buffer <= address[0];

        assert_not_set(state.send_buffer_empty, "expected send buffer not empty");
        assert_set(state.receive_buffer_empty, "expected receive buffer empty");

        // Issue the request.
        par
            seq
                state <= state_request_in_progress;
                assert_set(state.request_in_progress, "expected request in progress");
                await(state.request_in_progress == 0);
            endseq

            seq
                assert_get_eq(tofino.receive, tagged ReceivedStart, "expected START");
                assert_get_eq(tofino.receive, tagged AddressMatch, "expected address");
                assert_get_eq(tofino.receive, tagged ReceivedData opcode_byte, "expected Opcode");
                assert_get_eq(tofino.receive, tagged ReceivedData 'h01, "expected address byte 0");
                assert_get_eq(tofino.receive, tagged ReceivedData 'h02, "expected address byte 1");
                assert_get_eq(tofino.receive, tagged ReceivedData 'h03, "expected address byte 2");
                assert_get_eq(tofino.receive, tagged ReceivedData 'h04, "expected address byte 3");
                assert_get_eq(tofino.receive,tagged ReceivedStop, "expected STOP");

                assert_get_eq(tofino.receive, tagged ReceivedStart, "expected START");
                assert_get_eq(tofino.receive, tagged AddressMatch, "expected address");
                // Receive the first 3 value bytes.
                repeat(4) seq
                    assert_get_any(tofino.receive);
                    assert_get_eq(tofino.receive, tagged ReceivedAck, "expected Ack");
                endseq
                // Receive the last value byte.
                assert_get_any(tofino.receive);
                assert_get_eq(tofino.receive, tagged ReceivedNack, "expected Nack");
                assert_get_eq(tofino.receive, tagged ReceivedStop, "expected STOP");
            endseq
        endpar

        assert_not_set(state.receive_buffer_empty, "expected receive buffer not empty");
        $display("%t Buffer Read, 4", $time);
        repeat(4) action
            assert_av_not_eq_display(buffer, 'h00, "expected value byte");
        endaction
    endseq);

    mkTestWatchdog(20000);
endmodule

endpackage
