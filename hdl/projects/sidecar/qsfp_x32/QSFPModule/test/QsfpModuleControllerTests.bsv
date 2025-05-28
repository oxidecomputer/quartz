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
import CommonInterfaces::*;
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
        system_frequency_hz: i2c_test_params.core_clk_freq_hz,
        core_clk_period_ns: i2c_test_params.core_clk_period_ns,
        i2c_frequency_hz: i2c_test_params.scl_freq_hz,
        power_good_timeout_ms: 10,
        t_init_ms: 5, // normally 2000, but sped up for simulation
        t_clock_hold_us: i2c_test_params.max_scl_stretch_us,
        i2c_timeout_us: 15000 // normally 27, but sped up for simulation
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
    // The SPI register interface for the controller
    interface Registers registers;

    // Handle starting the next I2C transaction
    method Action command (Command cmd, Bool stretch_valid, Bool stretch_timeout);

    // A way to expose if the I2C read/write is finished
    method Bool i2c_busy();

    // Software control of the hot swap power enable pin
    method Action set_sw_power_en(Bit#(1) v);
    // Readback of the enable pin
    method Bool hsc_en;
    // Control of the hot swap power good pin
    method Action set_hsc_pg(Bit#(1) v);
    // Readback of the enable pin
    method Bool hsc_pg;

    method Bool hsc_pg_timeout;
    method Bool hsc_pg_lost;

    // Control of ModResetL for the bench
    method Action set_resetl(Bit#(1) v);
    // Readback of ModResetL pin
    method Bit#(1) resetl;

    // Control of LPMode/TxDis for the bench
    method Action set_lpmode(Bit#(1) v);
    // Readback of LPMode pin
    method Bit#(1) lpmode;

    // Control of IntL for the bench
    method Action set_intl(Bit#(1) v);
    // Readback of IntL pin
    method Bit#(1) intl;

    // Control of ModPrsL for the bench
    method Action set_modprsl(Bit#(1) v);
    // Readback of ModPrsL pin
    method Bit#(1) modprsl;

    // Expose if the module has been initialized or not
    method Bool module_initialized;

    // Reset the state of the perhiperhal model
    method Action reset_peripheral;
endinterface

module mkBench (Bench);

    // Instantiate a single controller as our DUT
    QsfpModuleController controller <- mkQsfpModuleController(qsfp_test_params);

    // Some registers for inputs, defaulted to 1 as they'd be pulled up
    Reg#(Bit#(1)) intl_r    <- mkReg(1);
    Reg#(Bit#(1)) modprsl_r <- mkReg(1);
    mkConnection(controller.pins.intl, intl_r);
    mkConnection(controller.pins.modprsl, modprsl_r);

    // Some registers for setting outputs
    Reg#(Bit#(1)) resetl_r   <- mkReg(0); // 0 as it is pulled down on board
    Reg#(Bit#(1)) lpmode_r <- mkReg(0);
    mkConnection(controller.resetl, resetl_r);
    mkConnection(controller.lpmode, lpmode_r);

    // Hot swap
    Reg#(Bit#(1)) sw_power_en_r  <- mkReg(1);
    Reg#(Bool) hsc_pg_r     <- mkReg(False);
    mkConnection(controller.sw_power_en, sw_power_en_r);
    mkConnection(controller.pins.power_good, hsc_pg_r);

    Strobe#(16) tick_1khz   <-
        mkLimitStrobe(1, qsfp_test_params.system_frequency_hz / 1000, 0);
    mkFreeRunningStrobe(tick_1khz);
    mkConnection(tick_1khz._read, controller.tick_1ms);

    // Instantiate a simple I2C model to act as the faux module target
    I2CPeripheralModel periph   <-
        mkI2CPeripheralModel(i2c_test_params.peripheral_addr,
                        qsfp_test_params.core_clk_period_ns,
                        qsfp_test_params.t_clock_hold_us);

    // Connect I2C busses since TriStates cannot be simulated
    mkConnection(controller.pins.scl.out, periph.scl_i);
    mkConnection(periph.scl_o, controller.pins.scl.in);
    mkConnection(controller.pins.sda.out, periph.sda_i);
    mkConnection(periph.sda_o, controller.pins.sda.in);

    // We need the ability to simulate the bus losing its pull-ups when a module has not been
    // inserted since that is how the design behaves. We only apply power to the module (and by the
    // board design, it's bus) when a module is present. This is kind of janky given we can't
    // properly simulate tristate logic in bluesim.
    rule do_pullup_simulation;
        periph.bus_pullups(controller.pg);
    endrule

    // Used to make dummy data for the DUT to pull from
    Reg#(UInt#(8)) fifo_idx         <- mkReg(0);

    // Internal bench state
    Reg#(Command) command_r         <- mkReg(defaultValue);
    PulseWire new_command           <- mkPulseWire();
    Reg#(UInt#(8)) bytes_done       <- mkReg(0);
    Reg#(Bool) stretch_timeout_expected     <- mkReg(False);
    Reg#(Bool) protocol_timeout_expected    <- mkReg(False);

    // TODO: This should become a RAM that I can dynamically read/write to so I
    // can read values I expect to have written without relying on bytes_done
    rule do_fill_write_data_fifo(fifo_idx < 128);
        controller.registers.i2c_data <= pack(fifo_idx);
        fifo_idx    <= fifo_idx + 1;
    endrule

    // An FSM to execute an I2C write transaction to a module. The controller
    // should ignore the command if the module has not been initialized.
    FSM write_seq <- mkFSMWithPred(seq
        controller.i2c_command.put(command_r);
        if (controller.module_initialized()) seq
            if (protocol_timeout_expected) seq
                check_peripheral_event(periph, tagged ReceivedStart, "Expected model to receive START");
                check_peripheral_event(periph, tagged AddressMatch, "Expected address to match");
                check_peripheral_event(periph, tagged ReceivedStop, "Expected to receive STOP");
            endseq else seq
                check_peripheral_event(periph, tagged ReceivedStart, "Expected model to receive START");
                check_peripheral_event(periph, tagged AddressMatch, "Expected address to match");

                check_peripheral_event(periph, tagged ReceivedData command_r.reg_addr, "Expected model to receive reg addr that was sent");

                while (bytes_done < command_r.num_bytes) seq
                    check_peripheral_event(periph, tagged ReceivedData pack(bytes_done)[7:0], "Expected to receive data that was sent");
                    bytes_done  <= bytes_done + 1;
                endseq

                check_peripheral_event(periph, tagged ReceivedStop, "Expected to receive STOP");
                bytes_done  <= 0;

                // The I2CCore will ack-poll to make sure the write took. In this test bench the
                // peripheral will ack the first try. We need to handle those events.
                check_peripheral_event(periph, tagged ReceivedStart, "Expected model to receive START");
                check_peripheral_event(periph, tagged AddressMatch, "Expected address to match");
                check_peripheral_event(periph, tagged ReceivedStop, "Expected to receive STOP");
            endseq
        endseq
    endseq, command_r.op == Write);

    // An FSM to execute an I2C read transaction to a module The controller
    // should ignore the command if the module has not been initialized. After
    // the bytes read are placed into the read data FIFO, drain it and validate
    // all the bytes match.
    FSM read_seq <- mkFSMWithPred(seq
        controller.i2c_command.put(command_r);
        if (controller.module_initialized()) seq
            // I2C transaction
            check_peripheral_event(periph, tagged ReceivedStart, "Expected model to receive START");
            check_peripheral_event(periph, tagged AddressMatch, "Expected address to match");

            // hacky way to handle the timeouts in the testbench context
            if (protocol_timeout_expected) seq
                // we can't safely end a transaction until we can nack, so rx a byte to allow that
                check_peripheral_event(periph, tagged TransmittedData pack(bytes_done)[7:0], "Expected to transmit the data which was previously written");
                action
                    let d <- controller.registers.i2c_data;
                    assert_eq(d, pack(bytes_done), "Expected data in FIFO to match");
                endaction
                check_peripheral_event(periph, tagged ReceivedNack, "Expected to receive NACK to end the Read");
                check_peripheral_event(periph, tagged ReceivedStop, "Expected to receive STOP");
            endseq else if (stretch_timeout_expected) seq
                await(unpack(controller.registers.port_status.error) == I2cSclStretchTimeout);
            endseq else seq
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
                await(!(unpack(controller.registers.port_status.busy)));

                // drain read data FIFO
                while (bytes_done < command_r.num_bytes) seq
                    action
                        let d <- controller.registers.i2c_data;
                        assert_eq(d, pack(bytes_done), "Expected data in FIFO to match");
                    endaction
                    bytes_done  <= bytes_done + 1;
                endseq
            endseq
        endseq
    endseq, command_r.op == Read);

    interface registers = controller.registers;

    method i2c_busy = !write_seq.done() || !read_seq.done() || new_command;

    method Action command(Command cmd, Bool stretch_valid, Bool stretch_timeout)
                        if (write_seq.done() && read_seq.done());
        command_r   <= cmd;
        new_command.send();

        if (cmd.op == Write) begin
            write_seq.start();
        end else if (cmd.op == Read) begin
            read_seq.start();
        end

        if (stretch_valid) begin
            periph.stretch_next(False);
        end else if (stretch_timeout) begin
            periph.stretch_next(True);
        end
        stretch_timeout_expected <= stretch_timeout;
        protocol_timeout_expected <= unpack(controller.registers.port_debug.force_i2c_timeout);
    endmethod

    method intl = pack(controller.intl);
    method modprsl = pack(controller.modprsl);
    method resetl = controller.pins.resetl;
    method lpmode = controller.pins.lpmode;

    method Action set_intl(Bit#(1) v);
        intl_r <= v;
    endmethod

    method Action set_modprsl(Bit#(1) v);
        modprsl_r <= v;
    endmethod

    method Action set_resetl(Bit#(1) v);
        resetl_r    <= v;
    endmethod

    method Action set_lpmode(Bit#(1) v);
        lpmode_r    <= v;
    endmethod

    method Action set_sw_power_en(Bit#(1) v);
        sw_power_en_r <= v;
    endmethod

    method Action set_hsc_pg(Bit#(1) v);
        hsc_pg_r <= unpack(v);
    endmethod

    method hsc_en = controller.pins.power_en;
    method hsc_pg = controller.pg;
    method hsc_pg_timeout = controller.pg_timeout;
    method hsc_pg_lost = controller.pg_lost;

    method module_initialized = controller.module_initialized;

    method Action reset_peripheral = periph.reset_device();
endmodule

function Stmt insert_and_power_module(Bench bench);
    return (seq
        // insert a module, which tells the controller to enable power
        assert_false(bench.hsc_en(),
            "Hot swap should not be enabled when module is not present");
        bench.set_modprsl(0);
        // modprsl is debounced, so wait for it to transition
        await(bench.modprsl == 0);
        delay(5);
        assert_true(bench.hsc_en(),
            "Hot swap should be enabled when module is present");
        // after some delay, give the controller power good
        bench.set_hsc_pg(1);
        // power good is debounced, so wait for it to transition
        await(bench.hsc_pg);
        delay(5);
    endseq);
endfunction

function Stmt remove_and_power_down_module(Bench bench);
    return (seq
        bench.set_modprsl(1);
        // modprsl is debounced, so wait for it to transition
        await(bench.modprsl == 1);
        delay(5);
        assert_false(bench.hsc_en(),
            "Hot swap should be disabled when module is missing");
        // after some delay, remove power good
        bench.set_hsc_pg(0);
        // power good is debounced, so wait for it to transition
        await(!bench.hsc_pg);
    endseq);
endfunction

function Stmt deassert_reset_and_await_init(Bench bench);
    return (seq
        // release reset
        bench.set_resetl(1);
        // wait for module initialization
        await(bench.module_initialized());
    endseq);
endfunction

function Stmt add_and_initialize_module(Bench bench);
    return (seq
        insert_and_power_module(bench);
        deassert_reset_and_await_init(bench);
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
            }, False, False);
        delay(5);
        assert_eq(unpack(bench.registers.port_status.error),
            NoModule,
            "NoModule error should be present when attempting to communicate with a device which is not present.");
        assert_eq(unpack(bench.registers.port_status.stretching_seen),
            False,
            "Should not have observed and SCL stretching.");
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
        bench.set_modprsl(0);
        await(bench.hsc_en());
        bench.command(Command {
                op: Read,
                i2c_addr: i2c_test_params.peripheral_addr,
                reg_addr: 8'h00,
                num_bytes: 1
            }, False, False);
        delay(5);
        assert_eq(unpack(bench.registers.port_status.error),
            NoPower,
            "NoPower error should be present when attempting to communicate before the hot swap is stable.");
        assert_eq(unpack(bench.registers.port_status.stretching_seen),
            False,
            "Should not have observed and SCL stretching.");
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
        add_and_initialize_module(bench);
        await(bench.hsc_en());
        bench.command(Command {
                op: Read,
                i2c_addr: i2c_test_params.peripheral_addr,
                reg_addr: 8'h00,
                num_bytes: 1
            }, False, False);
        delay(5);
        assert_eq(unpack(bench.registers.port_status.error),
            NoError,
            "NoPower should be present when attempting to communicate when the hot swap is stable.");
        bench.set_sw_power_en(0);
        delay(2);
        bench.set_hsc_pg(0);
        // power good is debounced and thus won't transition immediately
        await(!bench.hsc_pg);
        delay(3);
        assert_eq(bench.hsc_en(), False, "Expect hot swap to no longer be enabled.");
        assert_eq(unpack(bench.registers.port_status.stretching_seen),
            False,
            "Should not have observed and SCL stretching.");
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
        bench.set_modprsl(0);
        await(bench.hsc_pg_timeout());
        bench.command(Command {
                op: Read,
                i2c_addr: i2c_test_params.peripheral_addr,
                reg_addr: 8'h00,
                num_bytes: 1
            }, False, False);
        delay(5);
        assert_eq(unpack(bench.registers.port_status.error),
            PowerFault,
            "PowerFault error should be present when attempting to communicate after the hot swap has timed out");
        assert_eq(unpack(bench.registers.port_status.stretching_seen),
            False,
            "Should not have observed and SCL stretching.");
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
        add_and_initialize_module(bench);
        bench.set_hsc_pg(0);
        // power good is debounced and thus won't transition immediately
        await(!bench.hsc_pg);
        bench.command(Command {
                op: Read,
                i2c_addr: i2c_test_params.peripheral_addr,
                reg_addr: 8'h00,
                num_bytes: 1
            }, False, False);
        delay(5);
        assert_eq(unpack(bench.registers.port_status.error),
            PowerFault,
            "PowerFault error should be present when attempting to communicate after the hot swap has aborted");
        assert_eq(unpack(bench.registers.port_status.stretching_seen),
            False,
            "Should not have observed and SCL stretching.");
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
        add_and_initialize_module(bench);
        bench.command(read_cmd, False, False);
        await(!bench.i2c_busy());
        assert_eq(unpack(bench.registers.port_status.stretching_seen),
            False,
            "Should not have observed and SCL stretching.");
        assert_eq(unpack(bench.registers.port_status.error),
            NoError,
            "Should not have an I2C error.");
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
        add_and_initialize_module(bench);
        bench.command(write_cmd, False, False);
        await(!bench.i2c_busy());
        assert_eq(unpack(bench.registers.port_status.stretching_seen),
            False,
            "Should not have observed and SCL stretching.");
        assert_eq(unpack(bench.registers.port_status.error),
            NoError,
            "Should not have an I2C error.");
        delay(5);
    endseq);
endmodule

// mkInitializationTest
//
// This test attempts to do an I2C op with a module after its reset has been
// released, but before t_init (see SFF-8679) has elapsed. That should yield a
// `NotInitialized` error in the PORT_STATUS::ERROR register. It then makes sure
// an I2C op can complete successfully, returning `NoError`. Finally, we assert
// reset again and make sure that clears any initialized state and we receive
// `NotInitialized` on a I2C op.
module mkInitializationTest (Empty);
    Bench bench <- mkBench();

    Command read_cmd = Command {
        op: Read,
        i2c_addr: i2c_test_params.peripheral_addr,
        reg_addr: 8'h00,
        num_bytes: 1
    };

    mkAutoFSM(seq
        delay(5);
        insert_and_power_module(bench);
        bench.set_resetl(1);
        bench.command(read_cmd, False, False);
        await(!bench.i2c_busy());
        delay(3);
        assert_eq(unpack(bench.registers.port_status.error),
            NotInitialized,
            "NotInitialized error should be present when attempting to communicate before t_init has elapsed.");

        deassert_reset_and_await_init(bench);
        bench.command(read_cmd, False, False);
        await(!bench.i2c_busy());
        delay(3);
        assert_eq(unpack(bench.registers.port_status.error),
            NoError,
            "NoError should be present when attempting to communicate after t_init has elapsed.");

        bench.set_resetl(0);
        bench.command(read_cmd, False, False);
        await(!bench.i2c_busy());
        delay(3);
        assert_eq(unpack(bench.registers.port_status.error),
            NotInitialized,
            "NotInitialized error should be present when resetl is asserted.");
        assert_eq(unpack(bench.registers.port_status.stretching_seen),
            False,
            "Should not have observed and SCL stretching.");
        delay(5);
    endseq);
endmodule

// mkUninitializationAfterRemovalTest
//
// This test ensures that a previously initialized module is uninitialized when
// the module is removed regardless of `ResetL`'s status. That way when it is
// reinserted, the initialization process happens again.
module mkUninitializationAfterRemovalTest (Empty);
    Bench bench <- mkBench();

    Command read_cmd = Command {
        op: Read,
        i2c_addr: i2c_test_params.peripheral_addr,
        reg_addr: 8'h00,
        num_bytes: 1
    };

    mkAutoFSM(seq
        add_and_initialize_module(bench);
        bench.command(read_cmd, False, False);
        await(!bench.i2c_busy());
        assert_eq(unpack(bench.registers.port_status.error),
            NoError,
            "NoError should be present when attempting to communicate after t_init has elapsed.");

        remove_and_power_down_module(bench);
        insert_and_power_module(bench);

        bench.command(read_cmd, False, False);
        await(!bench.i2c_busy());
        delay(3);
        assert_eq(unpack(bench.registers.port_status.error),
            NotInitialized,
            "NotInitialized error should be present when a module has been reseated but not initialized.");
        assert_eq(unpack(bench.registers.port_status.stretching_seen),
            False,
            "Should not have observed and SCL stretching.");
    endseq);
endmodule

// mkNoLPModeWhenModuleIsUnpoweredTest
//
// This test checks that hardware gating of the LPMode signal is working to
// override SW setting LPMode when a module has not been powered. Details on
// why we do this: https://github.com/oxidecomputer/hardware-qsfp-x32/issues/47
module mkNoLPModeWhenModuleIsUnpoweredTest (Empty);
    Bench bench <- mkBench();

    mkAutoFSM(seq
        bench.set_lpmode(0);
        delay(3);
        assert_not_set(bench.lpmode, "LpMode should be deasserted when set to 0.");

        bench.set_lpmode(1); // SW attempts to assert LPMode
        delay(3);
        assert_not_set(bench.lpmode, "LpMode should be deasserted when a module is not present and powered.");

        bench.set_modprsl(0); // insert a module
        await(bench.modprsl == 0); // wait out debounce
        delay(3);
        assert_set(bench.hsc_en, "HSC power should be enabled now that a module is present.");
        bench.set_hsc_pg(1);
        assert_not_set(bench.hsc_pg, "HSC PG should not be debounced yet.");
        assert_not_set(bench.lpmode, "LpMode should be deasserted when a module is not present and powered.");

        await(bench.hsc_pg); // wait out debounce
        assert_set(bench.lpmode, "LpMode should be asserted now that 3.3V is up.");
        assert_eq(unpack(bench.registers.port_status.stretching_seen),
            False,
            "Should not have observed and SCL stretching.");
    endseq);
endmodule

// mkIntLTest
//
// This test ensures that the IntL input pin is properly reflected on the
// interface.
module mkIntLTest (Empty);
    Bench bench <- mkBench();

    mkAutoFSM(seq
        assert_set(bench.intl, "IntL's default state should be pulled up.");
        bench.set_intl(0);
        await(bench.intl == 0);
        assert_not_set(bench.intl, "IntL should be low after debounce");
        assert_eq(unpack(bench.registers.port_status.stretching_seen),
            False,
            "Should not have observed and SCL stretching.");
    endseq);
endmodule

// mkModPrsLTest
//
// This test ensures that the ModPrsL input pin is properly reflected on the
// interface.
module mkModPrsLTest (Empty);
    Bench bench <- mkBench();

    mkAutoFSM(seq
        assert_set(bench.modprsl, "ModPrsL's default state should be pulled up.");
        bench.set_modprsl(0);
        await(bench.modprsl == 0);
        assert_not_set(bench.modprsl, "ModPrsL should be low after debounce");
        assert_eq(unpack(bench.registers.port_status.stretching_seen),
            False,
            "Should not have observed and SCL stretching.");
    endseq);
endmodule

// mkI2CSclStretchTest
//
// This test reads an entire page 8 bytes of module memory and the module will
// stretch SCL. It also tests various conditions around module removal, re-insertion, and a device
// that won't stretch.
module mkI2CSclStretchTest (Empty);
    Bench bench <- mkBench();

    Command read_cmd = Command {
        op: Read,
        i2c_addr: i2c_test_params.peripheral_addr,
        reg_addr: 8'h00,
        num_bytes: 8
    };

    Command set_addr_cmd = Command {
        op: Write,
        i2c_addr: i2c_test_params.peripheral_addr,
        reg_addr: 8'h00,
        num_bytes: 0
    };

    mkAutoFSM(seq
        delay(5);
        add_and_initialize_module(bench);
        bench.command(read_cmd, True, False);
        await(!bench.i2c_busy());
        assert_eq(unpack(bench.registers.port_status.stretching_seen),
            True,
            "Should have observed SCL stretching.");
        assert_eq(unpack(bench.registers.port_status.error),
            NoError,
            "NoError should be present when a transaction completed successfully.");
        delay(5);

        // SCL stretch is latched per I2C transaction, so expect it to stick around even after the
        // module has been removed and reinserted.
        remove_and_power_down_module(bench);
        assert_eq(unpack(bench.registers.port_status.stretching_seen),
            True,
            "Should still have observed SCL stretching after module removal");
        insert_and_power_module(bench);
        assert_eq(unpack(bench.registers.port_status.stretching_seen),
            True,
            "Should still have observed SCL stretching after module reinsertion");
        
        // The module should be able to complete the next transaction successfully and the SCL
        // stretch seen register cleared.
        deassert_reset_and_await_init(bench);
        bench.command(set_addr_cmd, False, False);
        await(!bench.i2c_busy());
        assert_eq(unpack(bench.registers.port_status.stretching_seen),
            False,
            "Should not have observed SCL stretching.");
        assert_eq(unpack(bench.registers.port_status.error),
            NoError,
            "Should not have an I2C error.");

        bench.command(read_cmd, False, False);
        await(!bench.i2c_busy());
        assert_eq(unpack(bench.registers.port_status.stretching_seen),
            False,
            "Should not have observed SCL stretching.");
        assert_eq(unpack(bench.registers.port_status.error),
            NoError,
            "Should not have an I2C error.");
    endseq);
endmodule

// mkI2CSclStretchTimeoutTest
//
// This test reads an entire page 8 bytes of module memory and the module will
// stretch SCL for too long and the I2C core should timeout. It also tests various conditions around
// module removal, re-insertion, and a device that won't stretch.
module mkI2CSclStretchTimeoutTest (Empty);
    Bench bench <- mkBench();

    Command read_cmd = Command {
        op: Read,
        i2c_addr: i2c_test_params.peripheral_addr,
        reg_addr: 8'h00,
        num_bytes: 8
    };

    Command set_addr_cmd = Command {
        op: Write,
        i2c_addr: i2c_test_params.peripheral_addr,
        reg_addr: 8'h00,
        num_bytes: 0
    };

    mkAutoFSM(seq
        delay(5);
        add_and_initialize_module(bench);
        bench.command(read_cmd, False, True);
        await(!bench.i2c_busy());
        assert_eq(unpack(bench.registers.port_status.stretching_seen),
            True,
            "Should have observed and SCL stretching.");
        assert_eq(unpack(bench.registers.port_status.error),
            I2cSclStretchTimeout,
            "I2cSclStretchTimeout error should be present when a module stretching SCL too long.");
        delay(5);

        // unwedge the timed out peripheral since the I2CCore gives up
        bench.reset_peripheral();

        // SCL stretch is latched per I2C transaction, so expect it to stick around even after the
        // module has been removed and reinserted.
        remove_and_power_down_module(bench);
        assert_eq(unpack(bench.registers.port_status.stretching_seen),
            True,
            "Should still have observed SCL stretching after module removal");
        assert_eq(unpack(bench.registers.port_status.error),
            I2cSclStretchTimeout,
            "I2cSclStretchTimeout error should be present when a module stretching SCL too long.");
        insert_and_power_module(bench);
        assert_eq(unpack(bench.registers.port_status.stretching_seen),
            True,
            "Should still have observed SCL stretching after module reinsertion");
        assert_eq(unpack(bench.registers.port_status.error),
            I2cSclStretchTimeout,
            "I2cSclStretchTimeout error should be present when a module stretching SCL too long.");

        // The module should be able to complete the next transaction successfully and the SCL
        // stretch seen register cleared.
        deassert_reset_and_await_init(bench);
        bench.command(set_addr_cmd, False, False);
        await(!bench.i2c_busy());
        assert_eq(unpack(bench.registers.port_status.stretching_seen),
            False,
            "Should not have observed SCL stretching.");
        assert_eq(unpack(bench.registers.port_status.error),
            NoError,
            "Should not have an I2C error.");

        bench.command(read_cmd, False, False);
        await(!bench.i2c_busy());
        assert_eq(unpack(bench.registers.port_status.stretching_seen),
            False,
            "Should not have observed SCL stretching.");
        assert_eq(unpack(bench.registers.port_status.error),
            NoError,
            "Should not have an I2C error.");
    endseq);
endmodule

// mkI2CReadTimeoutTest
//
// This test reads an entire page (128 bytes) of module memory but will timeout. The controller
// should smoothly abort the transaction automatically.
module mkI2CReadTimeoutTest (Empty);
    Bench bench <- mkBench();

    Command read_cmd = Command {
        op: Read,
        i2c_addr: i2c_test_params.peripheral_addr,
        reg_addr: 8'h00,
        num_bytes: 128
    };

    PortDebug dbg_reg = PortDebug {
        force_i2c_timeout: 1
    };

    mkAutoFSM(seq
        delay(5);
        add_and_initialize_module(bench);
        bench.registers.port_debug <= dbg_reg;
        bench.command(read_cmd, False, False);
        await(!bench.i2c_busy());
        assert_eq(unpack(bench.registers.port_status.stretching_seen),
            False,
            "Should not have observed and SCL stretching.");
        // make sure we saw the error
        assert_eq(unpack(bench.registers.port_status.error),
            I2cTransactionTimeout,
            "Should have seen a transaction timeout error.");
        
        // the next transaction should complete just fine since the timeout bit clears automatically
        bench.command(read_cmd, False, False);
        await(!bench.i2c_busy());
        assert_eq(unpack(bench.registers.port_status.stretching_seen),
            False,
            "Should not have observed and SCL stretching.");
        assert_eq(unpack(bench.registers.port_status.error),
            NoError,
            "Should not have an I2C error.");
        delay(5);
    endseq);
endmodule

// mkI2CWriteTimeoutTest
//
// This test writes an entire page (128 bytes) of module memory but will timeout. The controller
// should smoothly abort the transaction automatically.
module mkI2CWriteTimeoutTest (Empty);
    Bench bench <- mkBench();

    Command write_cmd = Command {
        op: Write,
        i2c_addr: i2c_test_params.peripheral_addr,
        reg_addr: 8'h00,
        num_bytes: 128
    };

    PortDebug dbg_reg = PortDebug {
        force_i2c_timeout: 1
    };

    mkAutoFSM(seq
        delay(5);
        add_and_initialize_module(bench);
        bench.registers.port_debug <= dbg_reg;
        bench.command(write_cmd, False, False);
        await(!bench.i2c_busy());
        assert_eq(unpack(bench.registers.port_status.stretching_seen),
            False,
            "Should not have observed and SCL stretching.");
        // make sure we saw the error
        assert_eq(unpack(bench.registers.port_status.error),
            I2cTransactionTimeout,
            "Should have seen a transaction timeout error.");
        
        // the next transaction should complete just fine since the timeout bit clears automatically
        bench.command(write_cmd, False, False);
        await(!bench.i2c_busy());
        assert_eq(unpack(bench.registers.port_status.stretching_seen),
            False,
            "Should not have observed and SCL stretching.");
        assert_eq(unpack(bench.registers.port_status.error),
            NoError,
            "Should not have an I2C error.");
        delay(5);
    endseq);
endmodule

endpackage: QsfpModuleControllerTests
