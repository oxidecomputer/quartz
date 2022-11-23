// Copyright 2022 Oxide Computer Company
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package QsfpModuleControllerTests;

import Assert::*;
import Connectable::*;
import DefaultValue::*;
import GetPut::*;
import FIFO::*;
import StmtFSM::*;

import Bidirection::*;

import I2CCommon::*;
import I2CCore::*;
import I2CPeripheralModel::*;

import QsfpModuleController::*;

I2CTestParams i2c_test_params = defaultValue;
QsfpModuleController::Parameters qsfp_test_params =
    QsfpModuleController::Parameters {
        system_frequency_hz: i2c_test_params.core_clk_freq,
        i2c_frequency_hz: i2c_test_params.scl_freq
    };

function Action check_peripheral_event(I2CPeripheralModel peripheral,
                                        ModelEvent expected,
                                        String message) =
    action
        let e <- peripheral.receive.get();
        $display("(model) Actual:   ", fshow(e));
        $display("(model) Expected: ", fshow(expected));
        dynamicAssert (e == expected, message);
    endaction;

interface Bench;
    method Action command (Command cmd);
    method Bool busy();
endinterface

module mkBench (Bench);
    QsfpModuleController dut    <- mkQsfpModuleController(qsfp_test_params);
    I2CPeripheralModel periph   <- mkI2CPeripheralModel(i2c_test_params.peripheral_addr);

    mkConnection(dut.pins.scl.out, periph.scl_i);
    mkConnection(dut.pins.sda.out, periph.sda_i);
    mkConnection(pack(dut.pins.sda.out_en), periph.sda_i_en);
    mkConnection(dut.pins.sda.in, periph.sda_o);

    Reg#(Bit#(1)) enable_r  <- mkReg(1);
    Reg#(Bit#(1)) reset_r   <- mkReg(0);
    Reg#(Bit#(1)) present_r <- mkReg(1);

    mkConnection(dut.pins.present, present_r);
    mkConnection(dut.enable, enable_r);
    mkConnection(dut.reset_, reset_r);

    // A fifo of dummy data for the DUT to pull from
    FIFO#(RamWrite) write_data_fifo  <- mkSizedFIFO(128);
    Reg#(UInt#(8)) fifo_idx         <- mkReg(0);

    mkConnection(dut.i2c_write_data, toGet(write_data_fifo));

    Reg#(Command) command_r         <- mkReg(defaultValue);
    PulseWire new_command           <- mkPulseWire();
    Reg#(UInt#(8)) bytes_done       <- mkReg(0);

    (* fire_when_enabled *)
    rule do_test_read_addr(command_r.op == Read);
        dut.registers.read_buffer_addr  <= pack(bytes_done)[7:0];
    endrule

    // TODO: This should become a RAM that I can dynamically read/write to so I
    // can read values I expect to have written without relying on bytes_done
    rule do_fill_write_data_fifo(fifo_idx < 128);
        write_data_fifo.enq(RamWrite{data: pack(fifo_idx), address: pack(fifo_idx)});
        fifo_idx    <= fifo_idx + 1;
    endrule

    FSM write_seq <- mkFSMWithPred(seq
        dut.i2c_command.put(command_r);
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
        dut.i2c_command.put(command_r);
        check_peripheral_event(periph, tagged ReceivedStart, "Expected model to receive START");
        check_peripheral_event(periph, tagged AddressMatch, "Expected address to match");

        while (bytes_done < command_r.num_bytes) seq
            check_peripheral_event(periph, tagged TransmittedData pack(bytes_done)[7:0], "Expected to transmit the data which was previously written");

            if (bytes_done + 1 < command_r.num_bytes) seq
                check_peripheral_event(periph, tagged ReceivedAck, "Expected to receive ACK to send next byte");
            endseq

            bytes_done  <= bytes_done + 1;
        endseq

        check_peripheral_event(periph, tagged ReceivedNack, "Expected to receive NACK to end the Read");
        check_peripheral_event(periph, tagged ReceivedStop, "Expected to receive STOP");
        bytes_done  <= 0;
    endseq, command_r.op == Read);

    method busy = !write_seq.done() || !read_seq.done() || new_command;

    method Action command(Command cmd) if (write_seq.done() && read_seq.done());
        command_r   <= cmd;
        new_command.send();

        if (cmd.op == Write) begin
            write_seq.start();
        end else if (cmd.op == Read) begin
            read_seq.start();
        end
    endmethod
endmodule

(* synthesize *)
module mkQsfpModuleControllerReadTest (Empty);
    Bench bench <- mkBench();

    Command read_cmd = Command {
        op: Read,
        i2c_addr: i2c_test_params.peripheral_addr,
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
module mkQsfpModuleControllerWriteTest (Empty);
    Bench bench <- mkBench();

    Command write_cmd = Command {
        op: Write,
        i2c_addr: i2c_test_params.peripheral_addr,
        reg_addr: 8'h00,
        num_bytes: 128
    };

    mkAutoFSM(seq
        delay(200);
        bench.command(write_cmd);
        await(!bench.busy());
        delay(200);
    endseq);
endmodule

endpackage: QsfpModuleControllerTests
