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

// The Bench is what is accessed in the unit tests themselves. All interaction
// with the DUT is done through this interface.
interface Bench;
    // QSFP module low speed pins
    method Bit#(1) lpmode;
    method Bit#(1) resetl;
    method Action intl(Bit#(1) v);
    method Action modprsl(Bit#(1) v);

    // The SPI register interface for the controller
    interface Registers registers;

    // Handle starting the next I2C transaction
    method Action command (Command cmd);

    // A way to expose if the I2C read/write is finished
    method Bool i2c_busy();

    // Control of the hot swap power good pin
    method Action power_en(Bit#(1) v);
    method Action hsc_pg(Bit#(1) v);
    method Bool hsc_en;
    method Bool hsc_pg_timeout;
    method Bool hsc_pg_lost;
endinterface

module mkBench (Bench);

    // Instantiate a single controller as our DUT
    QsfpModuleController controller <- mkQsfpModuleController(qsfp_test_params);

    // Some registers for inputs, defaulted to 1 as they'd be pulled up
    Reg#(Bit#(1)) intl_r    <- mkReg(1);
    Reg#(Bit#(1)) modprsl_r <- mkReg(1);
    mkConnection(controller.pins.intl, intl_r);
    mkConnection(controller.pins.modprsl, modprsl_r);

    // Hot swap
    Reg#(Bit#(1)) power_en_r  <- mkReg(1);
    Reg#(Bool) hsc_pg_r     <- mkReg(False);
    mkConnection(controller.power_en, power_en_r);
    mkConnection(controller.pins.hsc.pg, hsc_pg_r);

    Strobe#(16) tick_1khz   <-
        mkLimitStrobe(1, qsfp_test_params.system_frequency_hz / 1000, 0);
    mkFreeRunningStrobe(tick_1khz);
    mkConnection(tick_1khz._read, controller.tick_1ms);

    // Instantiate a simple I2C model to act as the faux module target
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

    interface registers = controller.registers;

    method i2c_busy = !write_seq.done() || !read_seq.done() || new_command;

    method Action command(Command cmd) if (write_seq.done() && read_seq.done());
        command_r   <= cmd;
        new_command.send();

        if (cmd.op == Write) begin
            write_seq.start();
        end else if (cmd.op == Read) begin
            read_seq.start();
        end
    endmethod

    method lpmode = controller.pins.lpmode;
    method resetl = controller.pins.resetl;
    method Action intl(Bit#(1) v);
        intl_r <= v;
    endmethod
    method Action modprsl(Bit#(1) v);
        modprsl_r <= v;
    endmethod

    method Action power_en(Bit#(1) v);
        power_en_r <= v;
    endmethod
    method Action hsc_pg(Bit#(1) v);
        hsc_pg_r <= unpack(v);
    endmethod

    method hsc_en = controller.pins.hsc.en;
    method hsc_pg_timeout = controller.pg_timeout;
    method hsc_pg_lost = controller.pg_lost;
endmodule

function Stmt insert_and_power_module(Bench bench);
    return (seq
        // insert a module, which tells the controller to enable power
        assert_false(bench.hsc_en(),
            "Hot swap should not be enabled when module is not present");
        bench.modprsl(0);
        delay(5);
        assert_true(bench.hsc_en(),
            "Hot swap should be enabled when module is present");
        // after some delay, give the controller power good
        bench.hsc_pg(1);
        delay(5);
    endseq);
endfunction

// mkNoModuleTest
//
// This test checks proper behavior when no module is present. This should also
// result in a NoModule error if I2C communication is attempted.
module mkNoModuleTest (Empty);
    Bench bench <- mkBench();

    mkAutoFSM(seq
        delay(5);
        assert_false(bench.hsc_en(),
            "Hot swap should not be enabled when module is not present");
        bench.command(Command {
                op: Read,
                i2c_addr: i2c_test_params.peripheral_addr,
                reg_addr: 8'h00,
                num_bytes: 1
            });
        delay(2);
        assert_eq(unpack(bench.registers.port_status.error[2:0]),
            NoModule,
            "NoModule error should be present when attempting to communicate with a device which is not present.");
        delay(5);
    endseq);
endmodule

// mkNoPowerTest
//
// This test checks that a NoPower error occurs when the hot swap's power good
// has not asserted within the timeout threshold and I2C communication is
// attempted.
module mkNoPowerTest (Empty);
    Bench bench <- mkBench();

    mkAutoFSM(seq
        delay(5);
        bench.modprsl(0);
        await(bench.hsc_en());
        bench.command(Command {
                op: Read,
                i2c_addr: i2c_test_params.peripheral_addr,
                reg_addr: 8'h00,
                num_bytes: 1
            });
        delay(2);
        assert_eq(unpack(bench.registers.port_status.error[2:0]),
            NoPower,
            "NoPower error should be present when attempting to communicate before the hot swap is stable.");
        delay(5);
    endseq);
endmodule

// mkRemovePowerEnableTest
//
// This test checks that power gets disabled when the power enable bit is set
// low. This test covers a bug that existed the first time this module was
// implemented.
module mkRemovePowerEnableTest (Empty);
    Bench bench <- mkBench();

    mkAutoFSM(seq
        delay(5);
        insert_and_power_module(bench);
        await(bench.hsc_en());
        bench.command(Command {
                op: Read,
                i2c_addr: i2c_test_params.peripheral_addr,
                reg_addr: 8'h00,
                num_bytes: 1
            });
        delay(2);
        assert_eq(unpack(bench.registers.port_status.error[2:0]),
            NoError,
            "NoPower should be present when attempting to communicate when the hot swap is stable.");
        bench.power_en(0);
        delay(2);
        bench.hsc_pg(0);
        assert_eq(bench.hsc_en(), False, "Expect hot swap to no longer be enabled.");
        delay(5);
    endseq);
endmodule

// mkPowerGoodTimeoutTest
//
// This test checks that a PowerFault error occurs when the hot swap has timed
// out and I2C communication is attempted.
module mkPowerGoodTimeoutTest (Empty);
    Bench bench <- mkBench();

    mkAutoFSM(seq
        delay(5);
        bench.modprsl(0);
        await(bench.hsc_pg_timeout());
        bench.command(Command {
                op: Read,
                i2c_addr: i2c_test_params.peripheral_addr,
                reg_addr: 8'h00,
                num_bytes: 1
            });
        delay(2);
        assert_eq(unpack(bench.registers.port_status.error[2:0]),
            PowerFault,
            "PowerFault error should be present when attempting to communicate after the hot swap has timed out");
        delay(5);
    endseq);
endmodule

// mkPowerGoodLostTest
//
// This test checks that a PowerFault error occurs when the hot swap has aborted
// and I2C communication is attempted.
module mkPowerGoodLostTest (Empty);
    Bench bench <- mkBench();

    mkAutoFSM(seq
        delay(5);
        insert_and_power_module(bench);
        bench.hsc_pg(0);
        bench.command(Command {
                op: Read,
                i2c_addr: i2c_test_params.peripheral_addr,
                reg_addr: 8'h00,
                num_bytes: 1
            });
        delay(2);
        assert_eq(unpack(bench.registers.port_status.error[2:0]),
            PowerFault,
            "PowerFault error should be present when attempting to communicate after the hot swap has aborted");
        delay(5);
    endseq);
endmodule

// mkI2CReadTest
//
// This test reads an entire page (128 bytes) of module memory.
module mkI2CReadTest (Empty);
    Bench bench <- mkBench();

    Command read_cmd = Command {
        op: Read,
        i2c_addr: i2c_test_params.peripheral_addr,
        reg_addr: 8'h00,
        num_bytes: 128
    };

    mkAutoFSM(seq
        delay(5);
        insert_and_power_module(bench);
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

    Command write_cmd = Command {
        op: Write,
        i2c_addr: i2c_test_params.peripheral_addr,
        reg_addr: 8'h00,
        num_bytes: 128
    };

    mkAutoFSM(seq
        delay(5);
        insert_and_power_module(bench);
        bench.command(write_cmd);
        await(!bench.i2c_busy());
        delay(5);
    endseq);
endmodule

endpackage: QsfpModuleControllerTests
