// Copyright 2022 Oxide Computer Company
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package I2CCoreTests;

import Assert::*;
import Connectable::*;
import DefaultValue::*;
import GetPut::*;
import FIFO::*;
import StmtFSM::*;

import Bidirection::*;

import I2CBitController::*;
import I2CCommon::*;
import I2CCore::*;
import I2CPeripheralModel::*;

I2CTestParams test_params = defaultValue;

function Action check_peripheral_event(I2CPeripheralModel peripheral,
                                        ModelEvent expected,
                                        String message) =
    action
        let e <- peripheral.receive.get();
        $display("(model) Actual:   ", fshow(e));
        $display("(model) Expected: ", fshow(expected));
        dynamicAssert (e == expected, message);
    endaction;

function Action check_byte(I2CCore dut, Bit#(8) expected, String message) =
    action
        let rdata <- dut.received_data.get();
        $display("(dut) Actual:   ", fshow(rdata));
        $display("(dut) Expected: ", fshow(expected));
        dynamicAssert(rdata == expected, message);
    endaction;

typedef struct {
    Command cmd;
    Bool stretch_clk_valid;
    Bool stretch_clk_invalid;
} TestCommand deriving (Bits, Eq, FShow);

instance DefaultValue #(TestCommand);
    defaultValue = TestCommand {
        cmd: Command {
            op: Read,
            i2c_addr: 7'h7f,
            reg_addr: 8'hff,
            num_bytes: 8'h00
        },
        stretch_clk_valid: False,
        stretch_clk_invalid: False
    };
endinstance

interface Bench;
    method Action command (TestCommand cmd);
    method Bool busy();
    method Bool stretching_seen();
    method Bool stretching_timeout();
endinterface

module mkBench (Bench);
    // Crate a core and a peripheral model, wire them together
    I2CCore dut                 <- mkI2CCore(test_params.core_clk_freq_hz,
                                            test_params.scl_freq_hz,
                                            test_params.core_clk_period_ns,
                                            test_params.max_scl_stretch_us);
    I2CPeripheralModel periph   <- mkI2CPeripheralModel(test_params.peripheral_addr,
                                            test_params.core_clk_period_ns,
                                            test_params.max_scl_stretch_us);

    mkConnection(dut.pins, periph);

    Reg#(Bit#(8)) data_idx         <- mkReg(0);

    Reg#(Command) command_r     <- mkReg(defaultValue);
    PulseWire new_command       <- mkPulseWire();
    Reg#(UInt#(8)) bytes_done   <- mkReg(0);

    // A counter to simulate cycles of ack polling after a write
    Reg#(UInt#(8)) ack_poll_cntr    <- mkReg(0);
    Reg#(Bool) write_done           <- mkReg(False);

    // TODO: This should become a RAM that I can dynamically read/write to so I
    // can read values I expect to have written without relying on bytes_done
    (* fire_when_enabled *)
    rule do_offer_send_data;
        dut.send_data.offer(data_idx);
    endrule

    (* fire_when_enabled *)
    rule do_next_send_data_byte (dut.send_data.accepted);
        data_idx <= data_idx + 1;
    endrule

    FSM write_seq <- mkFSMWithPred(seq
        ack_poll_cntr   <= 2;
        write_done      <= False;
        dut.send_command.put(command_r);
        check_peripheral_event(periph, tagged ReceivedStart, "Expected model to receive START");
        check_peripheral_event(periph, tagged AddressMatch, "Expected address to match");

        check_peripheral_event(periph, tagged ReceivedData command_r.reg_addr, "Expected model to receive reg addr that was sent");

        while (bytes_done < command_r.num_bytes) seq
            check_peripheral_event(periph, tagged ReceivedData pack(bytes_done)[7:0], "Expected to receive data that was sent");
            bytes_done  <= bytes_done + 1;
        endseq

        check_peripheral_event(periph, tagged ReceivedStop, "Expected to receive STOP");
        bytes_done  <= 0;

        // do post-write ack polling to make sure the peripheral finished the write
        while (!write_done) seq
            periph.nack_response(ack_poll_cntr == 0);
            check_peripheral_event(periph, tagged ReceivedStart, "Expected model to receive START");
            action
                let e <- periph.receive.get();
                case(e) matches
                    tagged AddressMatch: begin
                        write_done  <= True;
                    end
                    tagged AddressMismatch: begin
                        // peripheral nack'd, indicating the write is not finsihed
                        ack_poll_cntr <= ack_poll_cntr - 1;
                    end
                endcase
            endaction
        endseq
        check_peripheral_event(periph, tagged ReceivedStop, "Expected to receive STOP");
    endseq, command_r.op == Write && !dut.scl_stretch_timeout);

    FSM read_seq <- mkFSMWithPred(seq
        dut.send_command.put(command_r);
        check_peripheral_event(periph, tagged ReceivedStart, "Expected model to receive START");
        check_peripheral_event(periph, tagged AddressMatch, "Expected address to match");

        while (bytes_done < command_r.num_bytes) seq
            check_peripheral_event(periph, tagged TransmittedData pack(bytes_done)[7:0], "Expected to transmit the data which was previously written");
            check_byte(dut, pack(bytes_done)[7:0], "Expected to read back written data");

            if (bytes_done + 1 < command_r.num_bytes) seq
                check_peripheral_event(periph, tagged ReceivedAck, "Expected to receive ACK to send next byte");
            endseq

            bytes_done  <= bytes_done + 1;
        endseq

        check_peripheral_event(periph, tagged ReceivedNack, "Expected to receive NACK to end the Read");
        check_peripheral_event(periph, tagged ReceivedStop, "Expected to receive STOP");
        bytes_done  <= 0;
    endseq, command_r.op == Read && !dut.scl_stretch_timeout);

    FSM rand_read_seq <- mkFSMWithPred(seq
        dut.send_command.put(command_r);
        check_peripheral_event(periph, tagged ReceivedStart, "Expected model to receive START");
        check_peripheral_event(periph, tagged AddressMatch, "Expected address to match with write operation");
        check_peripheral_event(periph, tagged ReceivedData command_r.reg_addr, "Expected model to receive reg addr that was sent");

        check_peripheral_event(periph, tagged ReceivedStart, "Expected model to receive a second START");
        check_peripheral_event(periph, tagged AddressMatch, "Expected address to match with read operation");

        while (bytes_done < command_r.num_bytes) seq
            check_peripheral_event(periph, tagged TransmittedData pack(bytes_done)[7:0], "Expected to transmit the data which was previously written");
            check_byte(dut, pack(bytes_done)[7:0], "Expected to read back written data");

            if (bytes_done + 1 < command_r.num_bytes) seq
                check_peripheral_event(periph, tagged ReceivedAck, "Expected to receive ACK to send next byte");
            endseq

            bytes_done  <= bytes_done + 1;
        endseq

        check_peripheral_event(periph, tagged ReceivedNack, "Expected to receive NACK to end the Read");
        check_peripheral_event(periph, tagged ReceivedStop, "Expected to receive STOP");
        bytes_done  <= 0;
    endseq, command_r.op == RandomRead && !dut.scl_stretch_timeout);

    rule do_handle_stretch_timeout(dut.scl_stretch_timeout);
        write_seq.abort();
        read_seq.abort();
        rand_read_seq.abort();
    endrule

    method busy = !write_seq.done() || !read_seq.done() || !rand_read_seq.done() || new_command;
    method stretching_seen = dut.scl_stretch_seen;
    method stretching_timeout = dut.scl_stretch_timeout;

    method Action command(TestCommand c) if (write_seq.done() && read_seq.done() && rand_read_seq.done());
        command_r   <= c.cmd;
        new_command.send();

        if (c.cmd.op == Write) begin
            write_seq.start();
        end else if (c.cmd.op == Read) begin
            read_seq.start();
        end else begin
            rand_read_seq.start();
        end

        if (c.stretch_clk_valid) begin
            periph.stretch_next(False);
        end else if (c.stretch_clk_invalid) begin
            periph.stretch_next(True);
        end
    endmethod
endmodule

module mkI2CCoreOneByteWriteTest (Empty);
    Bench bench <- mkBench();

    TestCommand cmd = TestCommand {
        cmd: Command {
            op: Write,
            i2c_addr: test_params.peripheral_addr,
            reg_addr: 8'hA5,
            num_bytes: 1
        },
        stretch_clk_valid: False,
        stretch_clk_invalid: False
    };

    mkAutoFSM(seq
        delay(200);
        bench.command(cmd);
        await(!bench.busy());
        dynamicAssert(!bench.stretching_seen, "Should not have seen SCL stretching");
        delay(200);
    endseq);
endmodule

module mkI2CCoreOneByteReadTest (Empty);
    Bench bench <- mkBench();

    TestCommand read_cmd = TestCommand {
        cmd: Command {
            op: Read,
            i2c_addr: test_params.peripheral_addr,
            reg_addr: 8'hA5,
            num_bytes: 1
        },
        stretch_clk_valid: False,
        stretch_clk_invalid: False
    };

    mkAutoFSM(seq
        delay(200);
        bench.command(read_cmd);
        await(!bench.busy());
        dynamicAssert(!bench.stretching_seen, "Should not have seen SCL stretching");
        delay(200);
    endseq);
endmodule

module mkI2CCoreSequentialWriteTest (Empty);
    Bench bench <- mkBench();

    TestCommand cmd = TestCommand {
        cmd: Command {
            op: Write,
            i2c_addr: test_params.peripheral_addr,
            reg_addr: 8'h5A,
            num_bytes: 128
        },
        stretch_clk_valid: False,
        stretch_clk_invalid: False
    };

    mkAutoFSM(seq
        delay(200);
        bench.command(cmd);
        await(!bench.busy());
        dynamicAssert(!bench.stretching_seen, "Should not have seen SCL stretching");
        delay(200);
    endseq);
endmodule

module mkI2CCoreSequentialReadTest (Empty);
    Bench bench <- mkBench();

    TestCommand read_cmd = TestCommand {
        cmd: Command {
            op: Read,
            i2c_addr: test_params.peripheral_addr,
            reg_addr: 8'h00,
            num_bytes: 128
        },
        stretch_clk_valid: False,
        stretch_clk_invalid: False
    };

    mkAutoFSM(seq
        delay(200);
        bench.command(read_cmd);
        await(!bench.busy());
        dynamicAssert(!bench.stretching_seen, "Should not have seen SCL stretching");
        delay(200);
    endseq);
endmodule

module mkI2CCoreRandomReadTest (Empty);
    Bench bench <- mkBench();

    TestCommand write_cmd = TestCommand {
        cmd: Command {
            op: Write,
            i2c_addr: test_params.peripheral_addr,
            reg_addr: 8'hA5,
            num_bytes: 8
        },
        stretch_clk_valid: False,
        stretch_clk_invalid: False
    };

    TestCommand rand_read_cmd = TestCommand {
        cmd: Command {
            op: RandomRead,
            i2c_addr: test_params.peripheral_addr,
            reg_addr: 8'hA5,
            num_bytes: 8
        },
        stretch_clk_valid: False,
        stretch_clk_invalid: False
    };

    mkAutoFSM(seq
        delay(200);
        bench.command(write_cmd);
        bench.command(rand_read_cmd);
        await(!bench.busy());
        dynamicAssert(!bench.stretching_seen, "Should not have seen SCL stretching");
        delay(200);
    endseq);
endmodule

module mkI2CCoreSclStretchTest (Empty);
    Bench bench <- mkBench();

    TestCommand write_cmd = TestCommand {
        cmd: Command {
            op: Write,
            i2c_addr: test_params.peripheral_addr,
            reg_addr: 8'hA5,
            num_bytes: 1
        },
        stretch_clk_valid: True,
        stretch_clk_invalid: False
    };

    TestCommand read_cmd = TestCommand {
        cmd: Command {
            op: RandomRead,
            i2c_addr: test_params.peripheral_addr,
            reg_addr: 8'hA5,
            num_bytes: 1
        },
        stretch_clk_valid: True,
        stretch_clk_invalid: False
    };

    mkAutoFSM(seq
        delay(200);
        bench.command(write_cmd);
        bench.command(read_cmd);
        await(!bench.busy());
        dynamicAssert(bench.stretching_seen, "Should have seen SCL stretching");
        dynamicAssert(!bench.stretching_timeout, "Should not have seen a SCL timeout");
        delay(200);
    endseq);
endmodule

module mkI2CCoreSclStretchTimeoutTest (Empty);
    Bench bench <- mkBench();

    TestCommand read_cmd = TestCommand {
        cmd: Command {
            op: RandomRead,
            i2c_addr: test_params.peripheral_addr,
            reg_addr: 8'hA5,
            num_bytes: 1
        },
        stretch_clk_valid: False,
        stretch_clk_invalid: True
    };

    mkAutoFSM(seq
        delay(200);
        bench.command(read_cmd);
        await(!bench.busy());
        dynamicAssert(bench.stretching_seen, "Should have seen SCL stretching");
        dynamicAssert(bench.stretching_timeout, "Should have seen a SCL timeout");
        delay(200);
    endseq);
endmodule

endpackage: I2CCoreTests
