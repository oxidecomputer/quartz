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

// Invariants for when a module is in A4
function Action a4_assertions(Bench bench);
    return (action
        assert_eq(bench.dut_registers.port_status.power_state,
            pack(A4),
            "Expected module to be in A4");
        assert_false(bench.dut_state.enable, "Enable should be deasserted in A4.");
        assert_true(bench.dut_state.reset_, "Reset should be asserted in A4.");
        assert_false(bench.dut_state.lpmode, "LPMode should be deasserted in A4.");
        assert_false(bench.dut_state.pg, "PG should be deasserted in A4.");
        assert_false(bench.dut_state.present, "Present should be deasserted in A4.");
        assert_false(bench.dut_state.irq, "Interrupt should be deasserted in A4.");
        assert_false(bench.dut_pg_timeout, "PG Timeout Fault should not be asserted.");
        assert_false(bench.dut_pg_lost, "PG Lost Fault should not be asserted.");
    endaction);
endfunction

// Invariants for when a module is in A3
function Action a3_assertions(Bench bench);
    return (action
        assert_eq(bench.dut_registers.port_status.power_state,
            pack(A3),
            "Expected module to be in A3");
        assert_false(bench.dut_state.enable, "Enable should be deasserted in A3.");
        assert_true(bench.dut_state.reset_, "Reset should be asserted in A3.");
        assert_false(bench.dut_state.lpmode, "LPMode should be deasserted in A3.");
        assert_false(bench.dut_state.pg, "PG should be deasserted in A3.");
        assert_true(bench.dut_state.present, "Present should be asserted in A3.");
        assert_false(bench.dut_state.irq, "Interrupt should be deasserted in A3.");
        assert_false(bench.dut_pg_timeout, "PG Timeout Fault should not be asserted.");
        assert_false(bench.dut_pg_lost, "PG Lost Fault should not be asserted.");
    endaction);
endfunction

// Invariants for when a module is in A2
function Action a2_assertions(Bench bench);
    return (action
        assert_eq(bench.dut_registers.port_status.power_state,
            pack(A2),
            "Expected module to be in A2");
        assert_true(bench.dut_state.enable, "Enable should be asserted in A2.");
        assert_false(bench.dut_state.reset_, "Reset should be deasserted in A2.");
        assert_true(bench.dut_state.lpmode, "LPMode should be asserted in A2.");
        assert_true(bench.dut_state.pg, "PG should be asserted in A2.");
        assert_true(bench.dut_state.present, "Present should be asserted in A2.");
        assert_false(bench.dut_state.irq, "Interrupt should be deasserted in A2.");
        assert_false(bench.dut_pg_timeout, "PG Timeout Fault should not be asserted.");
        assert_false(bench.dut_pg_lost, "PG Lost Fault should not be asserted.");
    endaction);
endfunction

// Invariants for when a module is in A0
function Action a0_assertions(Bench bench);
    return (action
        assert_eq(bench.dut_registers.port_status.power_state,
            pack(A0),
            "Expected module to be in A0");
        assert_true(bench.dut_state.enable, "Enable should be asserted in A0.");
        assert_false(bench.dut_state.reset_, "Reset should be deasserted in A0.");
        assert_false(bench.dut_state.lpmode, "LPMode should be deasserted in A0.");
        assert_true(bench.dut_state.pg, "PG should be asserted in A0.");
        assert_true(bench.dut_state.present, "Present should be asserted in A0.");
        assert_false(bench.dut_state.irq, "Interrupt should be deasserted in A0.");
        assert_false(bench.dut_pg_timeout, "PG Timeout Fault should not be asserted.");
        assert_false(bench.dut_pg_lost, "PG Lost Fault should not be asserted.");
    endaction);
endfunction

// Sequence to take a module from A4 to A3
function Stmt a4_to_a3(Bench bench);
    return (seq
        bench.set_presence(True);
        delay(input_to_state_change_prop_dly);
        a3_assertions(bench);
    endseq);
endfunction

// Sequence to take a module from A3 to A2
function Stmt a3_to_a2(Bench bench,
    PowerState target,
    Reg#(UInt#(11)) delay_counter,
    Bool power_good);

    return (seq
        // Set a target power state of A2 or A0 to begin transition out of A3.
        bench.dut_registers.port_control <= PortControl {
            power_state: pack(target),
            reset: 0,
            clear_fault: 0};
        delay(input_to_state_change_prop_dly);

        // Make sure teh controller has enabled the hot swap, then after an
        // arbitrary delay set power good
        assert_true(bench.dut_state.enable, "Expected hot swap to be asserted now.");
        delay(3);
        bench.set_hsc_pg(power_good);

        if (power_good) seq
            // power has come on successfully, meaning we can safely begin
            // driving lpmode
            delay(input_to_state_change_prop_dly);
            assert_true(bench.dut_state.lpmode, "Expected lpmode to be asserted now.");
            while (delay_counter <= init_delay_ms) seq
                await(bench.tick_1ms);
                delay_counter <= delay_counter + 1;
            endseq
            delay(1);
            a2_assertions(bench);
        endseq else seq
            // power will not come on successfully, wait out the timeout
            while (delay_counter <= fromInteger(qsfp_test_params.power_good_timeout_ms)) seq
                await(bench.tick_1ms);
                delay_counter <= delay_counter + 1;
            endseq

            // make sure the correct action is taken in the timed out state
            action
                assert_eq(bench.dut_registers.port_status.power_state,
                    pack(Fault),
                    "Expected module to be in Fault after power good timed out.");
                assert_true(bench.dut_pg_timeout, "PG Timeout fault should be asserted after timeout period.");
                assert_false(bench.dut_pg_lost, "PG Lost fault shoud not be asserted during a timeout fault");
            endaction

            // clear the fault, sending the module back to A3
            bench.dut_registers.port_control <= PortControl {
                power_state: pack(target),
                reset: 0,
                clear_fault: 1};
            delay(input_to_state_change_prop_dly);

            action
                assert_eq(bench.dut_registers.port_status.power_state,
                    pack(A3),
                    "Expected module to be in A3 after fault cleared");
                assert_false(bench.dut_state.pg, "PG should be deasserted in after the fault was cleared.");
            endaction
        endseq
        delay_counter <= 0;
    endseq);
endfunction

// Sequence to take a module from A2 to A0
function Stmt a2_to_a0(Bench bench, Reg#(UInt#(11)) delay_counter);
    return (seq
        bench.dut_registers.port_control <= PortControl {
            power_state: pack(A0),
            reset: 0,
            clear_fault: 0};
        delay(input_to_state_change_prop_dly);
        assert_false(bench.dut_state.lpmode, "Expected lpmode to be deasserted now.");

        while (delay_counter <= lpmode_off_delay_ms) seq
            await(bench.tick_1ms);
            delay_counter <= delay_counter + 1;
        endseq
        delay(input_to_state_change_prop_dly);

        a0_assertions(bench);
        delay_counter <= 0;
    endseq);
endfunction

// mkPowerStateA4Test
//
// This test verifies assertions when a module is in A4.
(* synthesize *)
module mkPowerStateA4Test (Empty);
    Bench bench <- mkBench();

    mkAutoFSM(seq
        delay(5);
        a4_assertions(bench);
        delay(5);
    endseq);
endmodule

// mkPowerStateA3Test
//
// This test verifies assertions when a module is taken to A3.
(* synthesize *)
module mkPowerStateA3Test (Empty);
    Bench bench <- mkBench();

    mkAutoFSM(seq
        delay(5);
        a4_to_a3(bench);
        delay(5);
    endseq);
endmodule

// mkPowerStateA2Test
//
// This test verifies assertions when a module is taken to A2 successfully.
(* synthesize *)
module mkPowerStateA2Test (Empty);
    Bench bench <- mkBench();
    Reg#(UInt#(11)) delay_counter <- mkReg(0);

    mkAutoFSM(seq
        delay(5);
        a4_to_a3(bench);
        a3_to_a2(bench, A2, delay_counter, True);
        delay(5);
    endseq);
endmodule

// mkPowerStateA0Test
//
// This test verifies assertions when a module is taken to A0.
(* synthesize *)
module mkPowerStateA0Test (Empty);
    Bench bench <- mkBench();
    Reg#(UInt#(11)) delay_counter <- mkReg(0);

    mkAutoFSM(seq
        delay(5);
        a4_to_a3(bench);
        a3_to_a2(bench, A0, delay_counter, True);
        a2_to_a0(bench, delay_counter);
        delay(5);
    endseq);
endmodule

// mkPowerStateA2PgTimeoutTest
//
// This test verifies assertions when a module is taken to A2 but a power fault
// occurs, including recovering from it by setting the clear_fault bit.
(* synthesize *)
module mkPowerStateA2PgTimeoutTest (Empty);
    Bench bench <- mkBench();
    Reg#(UInt#(11)) delay_counter <- mkReg(0);

    mkAutoFSM(seq
        delay(5);
        a4_to_a3(bench);
        a3_to_a2(bench, A2, delay_counter, False);
        delay(5);
    endseq);
endmodule

// mkResetFromA2Test
//
// This test verifies that setting the reset bit will reset the module from the
// A2 state.
(* synthesize *)
module mkResetFromA2Test (Empty);
    Bench bench <- mkBench();
    Reg#(UInt#(11)) delay_counter <- mkReg(0);

    mkAutoFSM(seq
        delay(5);
        a4_to_a3(bench);
        a3_to_a2(bench, A2, delay_counter, True);

        // Request a reset
        bench.dut_registers.port_control <= PortControl {
            power_state: pack(A2),
            reset: 1,
            clear_fault: 0};
        delay(input_to_state_change_prop_dly);
        assert_true(bench.dut_state.reset_, "Reset should be asserted after reset request.");
        while (delay_counter <= reset_delay_us) seq
            await(bench.tick_1us);
            delay_counter <= delay_counter + 1;
        endseq
        assert_false(bench.dut_state.reset_, "Reset should be deasserted after reset period.");
        delay(5);
    endseq);
endmodule

// mkResetFromA0Test
//
// This test verifies that setting the reset bit will reset the module from the
// A0 state. The controller will first place the module into low-power mode for
// the required time and then formally transition from A0 -> A2 where the reset
// will be performed.
(* synthesize *)
module mkResetFromA0Test (Empty);
    Bench bench <- mkBench();
    Reg#(UInt#(11)) delay_counter <- mkReg(0);

    mkAutoFSM(seq
        delay(5);
        a4_to_a3(bench);
        a3_to_a2(bench, A0, delay_counter, True);
        a2_to_a0(bench, delay_counter);

        // request a reset
        bench.dut_registers.port_control <= PortControl {
            power_state: pack(A2),
            reset: 1,
            clear_fault: 0};
        while (delay_counter <= lpmode_on_delay_ms) seq
            await(bench.tick_1ms);
            delay_counter <= delay_counter + 1;
        endseq
        delay_counter <= 0;

        // wait as the A0 -> A2 transition occurs
        delay(input_to_state_change_prop_dly);
        assert_true(bench.dut_state.reset_, "Reset should be asserted after reset request.");
        while (delay_counter <= reset_delay_us) seq
            await(bench.tick_1us);
            delay_counter <= delay_counter + 1;
        endseq
        assert_false(bench.dut_state.reset_, "Reset should be deasserted after reset period.");
        delay(5);
    endseq);
endmodule

// mkA0ToA2Test
//
// This test verifies that we will transition from A0 -> A2 if the target state
// should change.
(* synthesize *)
module mkA0ToA2Test (Empty);
Bench bench <- mkBench();
    Reg#(UInt#(11)) delay_counter <- mkReg(0);

    mkAutoFSM(seq
        delay(5);
        a4_to_a3(bench);
        a3_to_a2(bench, A0, delay_counter, True);
        a2_to_a0(bench, delay_counter);

        bench.dut_registers.port_control <= PortControl {
            power_state: pack(A2),
            reset: 0,
            clear_fault: 0};
        while (delay_counter <= lpmode_on_delay_ms) seq
            await(bench.tick_1ms);
            delay_counter <= delay_counter + 1;
        endseq
        delay(input_to_state_change_prop_dly);
        a2_assertions(bench);
    endseq);
endmodule

// mkA0ToA3Test
//
// This test verifies that we will transition from A0 -> A2 -> A3 if the target
// state should change.
(* synthesize *)
module mkA0ToA3Test (Empty);
Bench bench <- mkBench();
    Reg#(UInt#(11)) delay_counter <- mkReg(0);

    mkAutoFSM(seq
        delay(5);
        a4_to_a3(bench);
        a3_to_a2(bench, A0, delay_counter, True);
        a2_to_a0(bench, delay_counter);

        bench.dut_registers.port_control <= PortControl {
            power_state: pack(A3),
            reset: 0,
            clear_fault: 0};
        while (delay_counter <= lpmode_on_delay_ms) seq
            await(bench.tick_1ms);
            delay_counter <= delay_counter + 1;
        endseq
        delay(1);
        a2_assertions(bench);
        // when the controller disables power, remove power good
        await(!bench.dut_state.enable);
        bench.set_hsc_pg(False);
        delay(input_to_state_change_prop_dly);
        a3_assertions(bench);
    endseq);
endmodule

// mkModuleRemovalTest
//
// This test verifies that the removal of a module will result in the controller
// unwinding the module sequencing and end up in the A4 state.
(* synthesize *)
module mkModuleRemovalTest (Empty);
    Bench bench <- mkBench();
    Reg#(UInt#(11)) delay_counter <- mkReg(0);

    mkAutoFSM(seq
        delay(5);
        a4_to_a3(bench);
        a3_to_a2(bench, A0, delay_counter, True);
        a2_to_a0(bench, delay_counter);

        // remove the module
        bench.set_presence(False);
        // when the controller disables power, remove power good
        await(!bench.dut_state.enable);
        bench.set_hsc_pg(False);
        delay(5);
        a4_assertions(bench);
        delay(5);
    endseq);
endmodule

// mkModulePowerLostTest
//
// This test verifies that if power was to disappear during operation that the
// correct Fault state is reached and able to be cleared.
(* synthesize *)
module mkModulePowerLostTest (Empty);
    Bench bench <- mkBench();
    Reg#(UInt#(11)) delay_counter <- mkReg(0);

    mkAutoFSM(seq
        delay(5);
        a4_to_a3(bench);
        a3_to_a2(bench, A0, delay_counter, True);
        a2_to_a0(bench, delay_counter);

        // remove power
        bench.set_hsc_pg(False);
        delay(10);

        // make sure the correct action is taken in the loss of power state
        action
            assert_eq(bench.dut_registers.port_status.power_state,
                pack(Fault),
                "Expected module to be in Fault after power was removed.");
            assert_false(bench.dut_pg_timeout, "PG Timeout fault should not be asserted during a power loss fault");
            assert_true(bench.dut_pg_lost, "PG Lost fault should be asserted after power is lost.");
        endaction

        // clear the fault, send the module back to A3
        bench.dut_registers.port_control <= PortControl {
            power_state: pack(A3),
            reset: 0,
            clear_fault: 1};
        delay(input_to_state_change_prop_dly);

        action
            assert_eq(bench.dut_registers.port_status.power_state,
                pack(A3),
                "Expected module to be in A3 after fault cleared");
        endaction

    endseq);
endmodule

// mkI2CReadTest
//
// This test reads an entire page (128 bytes) of module memory.
(* synthesize *)
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
(* synthesize *)
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
