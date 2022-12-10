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
import CommonFunctions::*;
import I2CCommon::*;
import I2CCore::*;
import I2CPeripheralModel::*;
import PowerRail::*;
import Strobe::*;
import TestUtils::*;

import QsfpModuleController::*;
import QsfpX32ControllerRegsPkg::*;

I2CTestParams i2c_test_params = defaultValue;
QsfpModuleController::Parameters qsfp_test_params =
    QsfpModuleController::Parameters {
        system_frequency_hz: i2c_test_params.core_clk_freq,
        i2c_frequency_hz: i2c_test_params.scl_freq,
        power_good_timeout_ms: 10
    };

// Helper function to unpack the Value from an ActionValue and do an assertion.
function Action check_peripheral_event(I2CPeripheralModel peripheral,
                                        ModelEvent expected,
                                        String message) =
    action
        let e <- peripheral.receive.get();
        assert_eq(e, expected, message);
    endaction;

// Between registers in the Bench and within the module, it takes 4 cycles for
// a change in input to show changes in output.
UInt#(3) input_to_state_change_prop_dly = 4;

// The Bench is what is accessed in the unit tests themselves. All interaction
// with the DUT is done through this interface.
interface Bench;
    // Expose the SPI register interface
    interface Registers dut_registers;

    // Expose some internal state to run assertions against
    method PinState dut_state;
    method Bool dut_pg_timeout;
    method Bool dut_pg_lost;

    // Set inputs to the controller
    method Action set_presence (Bool v);
    method Action set_hsc_pg (Bool v);

    // Handle starting the next I2C transaction
    method Action command (Command cmd);

    // A way to expose if the I2C read/write is finished
    method Bool i2c_busy();

    // Expose the ticks to the tests themselves so they can wait as needed
    // TODO: integrate those waits into the bench, removing them from tests?
    method Bool tick_1ms();
    method Bool tick_1us();
endinterface

module mkBench (Bench);

    // Instantiate a single controller as our DUT
    QsfpModuleController controller <- mkQsfpModuleController(qsfp_test_params);

    // The test clock is already accelerated by 1000x and we create a few ticks
    // with that in mind here. While named according to their intended use in a
    // real design, these do not reflect actual timings here as they are just
    // used to accelerate actions and reduce simulation time.
    Strobe#(16) tick_1khz   <-
        mkLimitStrobe(1, qsfp_test_params.system_frequency_hz / 1000, 0);
    mkFreeRunningStrobe(tick_1khz);
    mkConnection(tick_1khz._read, controller.tick_1ms);

    Strobe#(6) tick_1mhz   <-
        mkLimitStrobe(1, qsfp_test_params.system_frequency_hz / 10000, 0);
    mkFreeRunningStrobe(tick_1mhz);
    mkConnection(tick_1mhz._read, controller.tick_1us);

    // Registers for inputs expected by the controller
    Reg#(Bool) module_presence <- mkReg(False);
    Reg#(Bool) module_hsc_pg <- mkReg(False);
    mkConnection(controller.pins.present, pack(module_presence));
    mkConnection(controller.pins.hsc.pg, module_hsc_pg);

    // Istantiate a simple I2C model to act as the faux module target
    I2CPeripheralModel periph   <- mkI2CPeripheralModel(i2c_test_params.peripheral_addr);
    mkConnection(controller.pins.scl.out, periph.scl_i);
    mkConnection(controller.pins.sda.out, periph.sda_i);
    mkConnection(pack(controller.pins.sda.out_en), periph.sda_i_en);
    mkConnection(controller.pins.sda.in, periph.sda_o);

    // A fifo of dummy data for the DUT to pull from
    FIFO#(RamWrite) write_data_fifo  <- mkSizedFIFO(128);
    Reg#(UInt#(8)) fifo_idx         <- mkReg(0);
    mkConnection(controller.i2c_write_data, toGet(write_data_fifo));

    // Internal bench state
    Reg#(Command) command_r         <- mkReg(defaultValue);
    PulseWire new_command           <- mkPulseWire();
    Reg#(UInt#(8)) bytes_done       <- mkReg(0);

    // lazy way to read data out, we probably shouldn't have this dependent on
    // bytes_done
    (* fire_when_enabled *)
    rule do_test_read_addr(command_r.op == Read);
        controller.registers.read_buffer_addr  <= pack(bytes_done)[7:0];
    endrule

    // TODO: This should become a RAM that I can dynamically read/write to so I
    // can read values I expect to have written without relying on bytes_done
    rule do_fill_write_data_fifo(fifo_idx < 128);
        write_data_fifo.enq(RamWrite{data: pack(fifo_idx), address: pack(fifo_idx)});
        fifo_idx    <= fifo_idx + 1;
    endrule

    // An FSM to execute an I2C write transaction to a module
    FSM write_seq <- mkFSMWithPred(seq
        controller.i2c_command.put(command_r);
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

    // An FSM to execute an I2C read transaction to a module
    FSM read_seq <- mkFSMWithPred(seq
        controller.i2c_command.put(command_r);
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

    method i2c_busy = !write_seq.done() || !read_seq.done() || new_command;
    method tick_1ms = tick_1khz._read;
    method tick_1us = tick_1mhz._read;
    method dut_state = controller.pin_state;
    method dut_registers = controller.registers;
    method dut_pg_timeout = controller.pg_timeout;
    method dut_pg_lost = controller.pg_lost;

    method Action command(Command cmd) if (write_seq.done() && read_seq.done());
        command_r   <= cmd;
        new_command.send();

        if (cmd.op == Write) begin
            write_seq.start();
        end else if (cmd.op == Read) begin
            read_seq.start();
        end
    endmethod

    method Action set_presence(Bool v);
        module_presence <= v;
    endmethod

    method Action set_hsc_pg(Bool v);
        module_hsc_pg <= v;
    endmethod
endmodule

// mkI2CReadTest
//
// This test reads an entire page (128 bytes) of module memory.
module mkI2CReadTest (Empty);
    Bench bench <- mkBench();
    Reg#(UInt#(11)) delay_counter <- mkReg(0);

    Command read_cmd = Command {
        op: Read,
        i2c_addr: i2c_test_params.peripheral_addr,
        reg_addr: 8'h00,
        num_bytes: 128
    };

    mkAutoFSM(seq
        delay(5);
        a4_to_a3(bench);
        a3_to_a2(bench, A2, delay_counter, True);
        bench.command(read_cmd);
        await(!bench.i2c_busy());
        delay(5);
    endseq);
endmodule

// mkI2CWriteTest
//
// This test writes an entire page (128 bytes) of module memory.
module mkI2CWriteTest (Empty);
    Bench bench <- mkBench();
    Reg#(UInt#(11)) delay_counter <- mkReg(0);

    Command write_cmd = Command {
        op: Write,
        i2c_addr: i2c_test_params.peripheral_addr,
        reg_addr: 8'h00,
        num_bytes: 128
    };

    mkAutoFSM(seq
        delay(5);
        a4_to_a3(bench);
        a3_to_a2(bench, A2, delay_counter, True);
        bench.command(write_cmd);
        await(!bench.i2c_busy());
        delay(5);
    endseq);
endmodule

endpackage: QsfpModuleControllerTests
