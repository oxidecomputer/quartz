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

import CommonInterfaces::*;

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

interface Bench;
    method Action command (Command cmd);
    method Bool busy();
endinterface

module mkBench (Bench);
    // Crate a core and a peripheral model, wire them together
    I2CCore dut                 <- mkI2CCore(test_params.core_clk_freq, test_params.scl_freq);
    I2CPeripheralModel periph   <- mkI2CPeripheralModel(test_params.peripheral_addr);

    mkConnection(dut.pins.scl.out, periph.scl_i);
    mkConnection(dut.pins.sda.out, periph.sda_i);
    mkConnection(dut.pins.sda.out_en, periph.sda_i_en);
    mkConnection(dut.pins.sda.in, periph.sda_o);

    Reg#(Bit#(8)) data_idx         <- mkReg(0);

    Reg#(Command) command_r     <- mkReg(defaultValue);
    PulseWire new_command       <- mkPulseWire();
    Reg#(UInt#(8)) bytes_done   <- mkReg(0);

    // TODO: This should become a RAM that I can dynamically read/write to so I
    // can read values I expect to have written without relying on bytes_done
    rule do_fill_write_data_fifo(dut.request_write_data);
        dut.write_data.put(data_idx + 1);
        data_idx    <= data_idx + 1;
    endrule

    FSM write_seq <- mkFSMWithPred(seq
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
    endseq, command_r.op == Write);

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
    endseq, command_r.op == Read);

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
    endseq, command_r.op == RandomRead);

    method busy = !write_seq.done() || !read_seq.done() || !rand_read_seq.done() || new_command;

    method Action command(Command cmd) if (write_seq.done() && read_seq.done() && rand_read_seq.done());
        command_r   <= cmd;
        new_command.send();

        if (cmd.op == Write) begin
            write_seq.start();
        end else if (cmd.op == Read) begin
            read_seq.start();
        end else begin
            rand_read_seq.start();
        end
    endmethod
endmodule

(* synthesize *)
module mkI2CCoreOneByteWriteTest (Empty);
    Bench bench <- mkBench();

    Command cmd = Command {
        op: Write,
        i2c_addr: test_params.peripheral_addr,
        reg_addr: 8'hA5,
        num_bytes: 1
    };

    mkAutoFSM(seq
        delay(200);
        bench.command(cmd);
        await(!bench.busy());
        delay(200);
    endseq);
endmodule

(* synthesize *)
module mkI2CCoreOneByteReadTest (Empty);
    Bench bench <- mkBench();

    Command read_cmd = Command {
        op: Read,
        i2c_addr: test_params.peripheral_addr,
        reg_addr: 8'hA5,
        num_bytes: 1
    };

    mkAutoFSM(seq
        delay(200);
        bench.command(read_cmd);
        await(!bench.busy());
        delay(200);
    endseq);
endmodule

(* synthesize *)
module mkI2CCoreSequentialWriteTest (Empty);
    Bench bench <- mkBench();

    Command cmd = Command {
        op: Write,
        i2c_addr: test_params.peripheral_addr,
        reg_addr: 8'h5A,
        num_bytes: 128
    };

    mkAutoFSM(seq
        delay(200);
        bench.command(cmd);
        await(!bench.busy());
        delay(200);
    endseq);
endmodule

(* synthesize *)
module mkI2CCoreSequentialReadTest (Empty);
    Bench bench <- mkBench();

    Command read_cmd = Command {
        op: Read,
        i2c_addr: test_params.peripheral_addr,
        reg_addr: 8'h00,
        num_bytes: 128
    };

    mkAutoFSM(seq
        delay(200);
        bench.command(read_cmd);
        await(!bench.busy());
        delay(200);
    endseq);
endmodule

(* synthesize *)
module mkI2CCoreRandomReadTest (Empty);
    Bench bench <- mkBench();

    Command write_cmd = Command {
        op: Write,
        i2c_addr: test_params.peripheral_addr,
        reg_addr: 8'hA5,
        num_bytes: 8
    };

    Command rand_read_cmd = Command {
        op: RandomRead,
        i2c_addr: test_params.peripheral_addr,
        reg_addr: 8'hA5,
        num_bytes: 8
    };

    mkAutoFSM(seq
        delay(200);
        bench.command(write_cmd);
        bench.command(rand_read_cmd);
        await(!bench.busy());
        delay(200);
    endseq);
endmodule

endpackage: I2CCoreTests