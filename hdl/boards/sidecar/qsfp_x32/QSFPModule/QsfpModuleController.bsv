// Copyright 2022 Oxide Computer Company
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package QsfpModuleController;

// primary interface and module
export QsfpModuleController(..);
export mkQsfpModuleController;

// useful structs and enums
export Parameters(..);
export RamWrite(..);
export Pins(..);
export Registers(..);
export PowerState(..);
export PortError(..);
export PinState(..);

// functions for doing mapping
export get_pins;
export get_registers;
export get_read_addr;
export get_read_data;
export get_status;
export get_control;

// constants for delay timing
export init_delay_ms;
export lpmode_on_delay_ms;
export lpmode_off_delay_ms;
export reset_delay_us;

// BSV
import BRAM::*;
import BRAMCore::*;
import ConfigReg::*;
import Connectable::*;
import DefaultValue::*;
import DReg::*;
import GetPut::*;
import StmtFSM::*;

// Quartz
import Bidirection::*;
import CommonFunctions::*;
import I2CBitController::*;
import I2CCommon::*;
import I2CCore::*;
import PowerRail::*;

// RDL auto-generated code
import QsfpX32ControllerRegsPkg::*;

typedef struct {
    Integer system_frequency_hz;
    Integer i2c_frequency_hz;
    Integer power_good_timeout_ms;
} Parameters;

instance DefaultValue#(Parameters);
    defaultValue = Parameters {
        system_frequency_hz: 50_000_000,
        i2c_frequency_hz: 100_000,
        power_good_timeout_ms: 10
    };
endinstance

// Types of communication errors a port could communicate
typedef enum {
    NoError = 0,
    NoModule = 1,
    NoPower = 2,
    PowerFault = 3,
    I2cAddressNack = 4,
    I2cByteNack = 5
} PortError deriving (Bits, Eq, FShow);

// Types of power errors that could occur
typedef enum {
    PgTimeout = 0, // module power rail did not enable in time
    PgLost = 1 // module power rail unexpectedly lost pg
} PowerFault deriving (Bits, Eq, FShow);

// High-level power states we can be steady-state in
typedef enum {
    A4 = 0, // module not present
    A3 = 1, // module inserted
    A2 = 2, // module powered in low-power mode with reset deasserted
    A0 = 3, // module in high-power mode
    Fault = 4 // module experience a fault
} PowerState deriving (Eq, Bits, FShow);

// Internal sequence states which handle the various steps when executing
// sequencing
typedef enum {
    NoModule = 0,
    ModulePresent = 1,
    AwaitPowerGood = 2,
    AwaitInitReset = 3,
    LowPowerMode = 4,
    AwaitLpModeOff = 5,
    HighPowerMode = 6,
    AwaitLpModeOn = 7,
    AwaitReset = 8
} SequenceState deriving (Eq, Bits, FShow);

// A data/address pair to do a BRAM write
typedef struct {
    Bit#(8) data;
    Bit#(8) address;
} RamWrite deriving (Eq, Bits, FShow);

// Control Timing information from section 8.1 of SFF-8679
UInt#(11) init_delay_ms = 2000; // t_init, t_serial, t_data, t_reset. 2 seconds!
UInt#(11) lpmode_on_delay_ms = 100; // ton_LPMode
UInt#(11) lpmode_off_delay_ms = 300; // toff_LPMode
UInt#(11) reset_delay_us = 10; // t_reset_init

// helper function to do BRAM accesses
function BRAMRequest#(Bit#(8), Bit#(8)) makeRequest(Bool write,
                                                    Bit#(8) addr, Bit#(8) data);
    return BRAMRequest {
        write: write,
        responseOnWrite: False,
        address: addr,
        datain: data
    };
endfunction

interface Registers;
    interface ReadOnly#(PortStatus) port_status;
    interface Reg#(PortControl) port_control;
    // not in RDL, this is sideband BRAM access
    interface Wire#(Bit#(8)) read_buffer_addr;
    interface ReadOnly#(Bit#(8)) read_buffer_byte;
endinterface

interface Pins;
    interface PowerRail::Pins hsc;
    interface Bidirection#(Bit#(1)) scl;
    interface Bidirection#(Bit#(1)) sda;
    method Bit#(1) lpmode;
    method Bit#(1) reset_;
    method Action irq(Bit#(1) val);
    method Action present(Bit#(1) val);
endinterface

typedef struct{
    Bool enable;
    Bool lpmode;
    Bool reset_;
    Bool pg;
    Bool present;
    Bool irq;
} PinState deriving (Eq, Bits, FShow);

interface QsfpModuleController;
    // Physical FPGA pins for the controller
    interface Pins pins;

    // A way to expose signal state that will be vectorized into registers
    // with other controllers' state by a top level controller module
    method PinState pin_state;

    // Other useful state from the controller
    method Bool pg_timeout;
    method Bool pg_lost;

    // Register interface exposed over SPI
    interface Registers registers;

    // new I2C Command to feed to the I2C core
    interface Put#(Command) i2c_command;

    // this is how the write buffer gets filled
    interface Put#(RamWrite) i2c_write_data;

    // ticks for internal delay counters
    method Action tick_1ms(Bool val);
    method Action tick_1us(Bool val);
endinterface

module mkQsfpModuleController #(Parameters parameters) (QsfpModuleController);
    // Power Rail control for the hot swap controller
    PowerRail#(4) hot_swap  <- mkPowerRailDisableOnAbort(parameters.power_good_timeout_ms);

    // I2C core for the module management interface
    I2CCore i2c_core    <-
        mkI2CCore(parameters.system_frequency_hz, parameters.i2c_frequency_hz);

    // Block RAM configuration to store I2C transaction data
    // While only 128 bytes are needed, they are sized to 256 so the tools will
    // automatically synthesize them to BRAM not LUTRAM.
    BRAM_Configure read_bram_cfg = BRAM_Configure {
        memorySize: 256,                // 256 bytes
        latency: 1,                     // address on read is registered
        outFIFODepth: 3,                // latency + 2 for optimal pipeline
        loadFormat: tagged None,        // no load file used
        allowWriteResponseBypass: False // pipeline write response
    };
    // Do not change bramSize from 128 to 256, it appears to cause a synthesis
    // issue. See https://github.com/oxidecomputer/quartz/issues/55
    Integer bramSize = 128;
    Bool hasOutputRegister = False;

    // The read_buffer stores data read back from the module
    // The write_buffer stores data to be written to the module
    // portA for writes, portB for reads on both BRAMs
    BRAM2Port#(Bit#(8), Bit#(8)) read_buffer  <- mkBRAM2Server(read_bram_cfg);
    BRAM_DUAL_PORT#(Bit#(8), Bit#(8)) write_buffer <-
        mkBRAMCore2(bramSize, hasOutputRegister);

    // Buffer signals
    Wire#(Bit#(8)) read_buffer_read_addr        <- mkDWire(8'h00);
    ConfigReg#(Bit#(8)) read_buffer_read_data   <- mkConfigReg(8'h00);
    Reg#(Bit#(8)) read_buffer_write_addr        <- mkReg(0);
    Reg#(Bit#(8)) write_buffer_read_addr        <- mkReg(0);
    PulseWire read_from_write_buffer            <- mkPulseWire();
    PulseWire requested_from_write_buffer       <- mkPulseWire();

    // I2C control
    PulseWire new_i2c_command                   <- mkPulseWire();
    PulseWire i2c_data_received                 <- mkPulseWire();
    Reg#(Bool) i2c_attempt                      <- mkDReg(False);
    Reg#(I2CCore::Command) next_i2c_command     <- mkReg(defaultValue);

    // Pin registers, named with _ to avoid collisions at the interface
    Reg#(Bool) reset__   <- mkReg(True);
    Reg#(Bool) lpmode_   <- mkReg(False);
    Reg#(Bool) irq_      <- mkReg(False);
    Reg#(Bool) present_  <- mkReg(False);

    // Status
    Reg#(PortError) error   <- mkReg(NoError);
    Reg#(Maybe#(PowerFault)) fault <- mkReg(tagged Invalid);

    // Control
    Reg#(SequenceState) sequence_state          <- mkReg(NoModule);
    ConfigReg#(PowerState) current_power_state  <- mkConfigReg(A4);
    Wire#(PowerState) target_power_state        <- mkWire();
    Reg#(PortControl) control                   <- mkReg(defaultValue);
    Reg#(PortControl) control_one_shot          <- mkDReg(defaultValue);
    ConfigReg#(Bool) reset_requested            <- mkConfigReg(False);

    // Delay
    Wire#(Bool) tick_1ms_           <- mkWire();
    Wire#(Bool) tick_1us_           <- mkWire();
    Reg#(UInt#(11)) delay_counter  <- mkReg(0);

    // The hot swap expected a tick to correspond with its timeout
    (* fire_when_enabled *)
    rule do_hot_swap_tick (tick_1ms_);
        hot_swap.send();
    endrule

    // Capture a fault if one was to occur
    (* fire_when_enabled *)
    rule do_fault (!isValid(fault));
        if (hot_swap.timed_out) begin
            fault <= tagged Valid PgTimeout;
        end else if (hot_swap.aborted) begin
            fault <= tagged Valid PgLost;
        end
    endrule

    // Clear a captured fault. Note that we have to be in the Fault state for
    // this to happen. Depending on exactly what happens, it may take several
    // cycles to get back to A3 and formally Fault. In practice that should not
    // matter, but in simulation it may.
    (* fire_when_enabled *)
    rule do_fault_clear (isValid(fault) && 
                        current_power_state == Fault &&
                        control_one_shot.clear_fault == 1);
        fault <= tagged Invalid;
        hot_swap.clear();
    endrule

    // This is just a wire that makes it more clear what the intent of the
    // control.power_state field is.
    (* fire_when_enabled *)
    rule do_drive_target_state;
        target_power_state <= unpack(control.power_state);
    endrule

    // Ignore reset request if we are already in the middle of a reset
    (* fire_when_enabled *)
    rule do_reset_request (control_one_shot.reset == 1 && 
                            sequence_state != AwaitReset);
        reset_requested <= True;
    endrule

    // A4 Power State
    //
    // Transition from A4 -> A3 regardless of the value of desired_state. While
    // it could theoretically be set to A4, in practice this is meaningless
    // because software cannot order a module to be removed, and therefore it
    // should be considered an invalid state.
    (* fire_when_enabled *)
    rule do_no_module (sequence_state == NoModule || !present_);
        hot_swap.set_enable(False);
        reset__ <= True;
        lpmode_ <= False;
        current_power_state <= A4;

        if (present_) begin
            sequence_state <= ModulePresent;
        end else begin
            sequence_state <= NoModule;
        end
    endrule

    // A3 Power State
    //
    // This is where the controller will sit if a fault were to occur or until
    // a target state of A2 or A0 is written in.
    (* fire_when_enabled *)
    rule do_module_present ((sequence_state == ModulePresent && present_) ||
                            (present_ &&
                            isValid(fault) &&
                            sequence_state != NoModule));
        hot_swap.set_enable(False);
        reset__ <= True;
        lpmode_ <= False;

        if (isValid(fault)) begin
            current_power_state <= Fault;
        end else begin
            current_power_state <= A3;
        end

        if (!isValid(fault) && (target_power_state == A2 || target_power_state == A0)) begin
            sequence_state <= AwaitPowerGood;
        end else begin
            sequence_state <= ModulePresent;
        end
    endrule

    // Enable the hot swap controller, moving forward once power good is seen
    (* fire_when_enabled *)
    rule do_await_power_good (sequence_state == AwaitPowerGood && (present_ && !isValid(fault)));
        if (hot_swap.enabled()) begin
            lpmode_ <= True;
            sequence_state <= AwaitInitReset;
        end else if (!hot_swap.ramping_up()) begin
            hot_swap.set_enable(True);
        end
    endrule

    // Release reset and wait out the mammoth initial reset time
    (* fire_when_enabled *)
    rule do_await_init_reset (sequence_state == AwaitInitReset && (present_ && !isValid(fault)));
        reset__ <= False;
        if (delay_counter > init_delay_ms) begin
            delay_counter  <= 0;
            sequence_state  <= LowPowerMode;
        end else if (tick_1ms_) begin
            delay_counter  <= delay_counter + 1;
        end
    endrule

    // Power State A2
    //
    // This is another primary state where I2C communicate can occur while the
    // module remains in low-power mode.
    (* fire_when_enabled *)
    rule do_low_power_mode (sequence_state == LowPowerMode && (present_ && !isValid(fault)));
        current_power_state <= A2;

        if (reset_requested) begin
            sequence_state  <= AwaitReset;
        end else if (target_power_state == A0) begin
            sequence_state  <= AwaitLpModeOff;
        end
    endrule

    // Ensure that reset is asserted for at least the specified duration
    (* fire_when_enabled *)
    rule do_await_reset (sequence_state == AwaitReset && (present_ && !isValid(fault)));
        if (delay_counter > reset_delay_us) begin
            delay_counter <= 0;
            reset__ <= False;
            reset_requested <= False;
            sequence_state <= LowPowerMode;
        end else begin
            reset__ <= True;
            if (tick_1us_) begin
                delay_counter <= delay_counter + 1;
            end
        end
    endrule

    // Wait the amount of time specified to enter high-power mode before
    // advertising that the module is in high-power mode.
    (* fire_when_enabled *)
    rule do_await_lp_mode_off (sequence_state == AwaitLpModeOff && (present_ && !isValid(fault)));
        lpmode_ <= False;
        if (delay_counter > lpmode_off_delay_ms) begin
            delay_counter <= 0;
            sequence_state <= HighPowerMode;
        end else if (tick_1ms_) begin
            delay_counter <= delay_counter + 1;
        end
    endrule

    // Wait the amount of time specified to leave high-power mode before
    // advertising that the module is back in low-power mode.
    (* fire_when_enabled *)
    rule do_await_lp_mode_on (sequence_state == AwaitLpModeOn && (present_ && !isValid(fault)));
        lpmode_ <= True;
        if (delay_counter > lpmode_on_delay_ms) begin
            delay_counter <= 0;
            sequence_state <= LowPowerMode;
        end else if (tick_1ms_) begin
            delay_counter <= delay_counter + 1;
        end
    endrule

    // Power State A0
    //
    // The controller will spend most of the time in this state as this is where
    // normal operation will occur.
    (* fire_when_enabled *)
    rule do_high_power_mode (sequence_state == HighPowerMode && (present_ && !isValid(fault)));
        current_power_state <= A0;

        if (reset_requested) begin
            sequence_state <= AwaitLpModeOn;
        end
    endrule

    // The buffer data is only considered valid for the transaction, so reset
    // the address at the start of a new read operation.
    (* fire_when_enabled *)
    rule do_read_buffer_write_addr;
        if (new_i2c_command || read_buffer_write_addr == 128) begin
            read_buffer_write_addr  <= 0;
        end else if (i2c_data_received) begin
            if (read_buffer_write_addr < 128) begin
                read_buffer_write_addr    <= read_buffer_write_addr + 1;
            end else begin
                read_buffer_write_addr    <= 0;
            end
        end
    endrule

    // I2C writes into read_buffer via PortA
    (* fire_when_enabled *)
    rule do_read_buffer_porta_write;
        let wdata   <- i2c_core.received_data.get();
        read_buffer.portA.request.put(makeRequest(True, read_buffer_write_addr, wdata));
        i2c_data_received.send();
    endrule

    // SPI interface changes read_buffer_read_addr, making a read request via PortB
    (* fire_when_enabled *)
    rule do_read_buffer_portb_write;
        read_buffer.portB.request.put(makeRequest(False, read_buffer_read_addr, 8'h00));
    endrule

    // PortB responds with the requested data, passing it back to SPI via read_buffer_read_data
    (* fire_when_enabled *)
    rule do_read_buffer_portb_read;
        let rdata   <- read_buffer.portB.response.get();
        read_buffer_read_data  <= rdata;
    endrule

    // The buffer data is only considered valid for the transaction, so reset
    // the address at the start of a new  operation.
    (* fire_when_enabled *)
    rule do_reg_write_buffer_read_addr;
        if (new_i2c_command) begin
            write_buffer_read_addr    <= 0;
        end else if (i2c_core.send_data.accepted) begin
            if (write_buffer_read_addr < 128) begin
                write_buffer_read_addr    <= write_buffer_read_addr + 1;
            end else begin
                write_buffer_read_addr    <= 0;
            end
        end
    endrule

    // I2C interface changes write_buffer_read_addr, making a read request via PortB
    (* fire_when_enabled *)
    rule do_write_buffer_portb_write;
        write_buffer.b.put(False, write_buffer_read_addr, 8'h00);
    endrule

    // PortB responds with the requested data, passing it back to I2C via write_buffer_write_data
    (* fire_when_enabled *)
    rule do_write_buffer_portb_read;
        i2c_core.send_data.offer(write_buffer.b.read());
    endrule

    // Since the error register is somewhat derived at this layer it needs to
    // be registered for persistence. It will also stay present until the next
    // I2C transaction starts on the port.
    (* fire_when_enabled *)
    rule do_i2c;
        if (i2c_attempt && !present_) begin
            error   <= NoModule;
        end else if (i2c_attempt && !hot_swap.enabled) begin
            error   <= NoPower;
        end else if (i2c_attempt && isValid(fault)) begin
            error   <= PowerFault;
        end else if (i2c_attempt) begin
            new_i2c_command.send();
            error   <= NoError;
            i2c_core.send_command.put(next_i2c_command);
        end else if (isValid(i2c_core.error)) begin
            let err = fromMaybe(?, i2c_core.error);
            if (err == AddressNack) begin
                error   <= I2cAddressNack;
            end else if (err == ByteNack) begin
                error   <= I2cByteNack;
            end
        end
    endrule

    // Registers for SPI peripheral
    interface Registers registers;
        interface ReadOnly port_status = valueToReadOnly(PortStatus {
            power_state: {pack(current_power_state)},
            busy: pack(i2c_core.busy()),
            error: {0, pack(error)}
        });
        interface Reg port_control;
            method _read = control;
            method Action _write(PortControl next);
                control <= PortControl {
                    power_state: next.power_state,
                    reset: 0,
                    clear_fault: 0};

                control_one_shot <= PortControl {
                    power_state: 0,
                    reset: next.reset,
                    clear_fault: next.clear_fault};
            endmethod
        endinterface
        interface Wire read_buffer_addr;
            method _read = read_buffer_read_addr;
            method Action _write(Bit#(8) address);
                read_buffer_read_addr   <= address;
            endmethod
        endinterface
        interface ReadOnly read_buffer_byte = valueToReadOnly(read_buffer_read_data);
    endinterface

    // Physical module pins
    interface Pins pins;
        interface PowerRail::Pins hsc = hot_swap.pins;
        interface Bidirection scl = i2c_core.pins.scl;
        interface Bidirection sda = i2c_core.pins.sda;

        method lpmode = pack(lpmode_);
        method reset_ = pack(reset__);
        method Action irq(Bit#(1) v);
            irq_ <= unpack(v);
        endmethod
        method Action present(Bit#(1) v);
            present_ <= unpack(v);
        endmethod
    endinterface

    // next i2c command
    interface Put i2c_command;
        method Action put(new_command);
            i2c_attempt         <= True;
            next_i2c_command    <= new_command;
        endmethod
    endinterface

    // external source writes into write_buffer via PortA
    interface Put i2c_write_data;
        method Action put(new_ram_write);
            write_buffer.a.put(True, new_ram_write.address, new_ram_write.data);
        endmethod
    endinterface

    method PinState pin_state = PinState {
        enable: hot_swap.pin_state.enable,
        lpmode: lpmode_,
        reset_: reset__,
        pg: hot_swap.pin_state.good,
        present: present_,
        irq: irq_};
    method pg_timeout = isValid(fault) && fromMaybe(?, fault) == PgTimeout;
    method pg_lost = isValid(fault) && fromMaybe(?, fault) == PgLost;
    method tick_1ms = tick_1ms_._write;
    method tick_1us = tick_1us_._write;
endmodule

function Pins get_pins(QsfpModuleController m) = m.pins;
function Registers get_registers(QsfpModuleController m) = m.registers;
function Wire#(Bit#(8)) get_read_addr(QsfpModuleController m) = m.registers.read_buffer_addr;
function ReadOnly#(Bit#(8)) get_read_data(QsfpModuleController m) = m.registers.read_buffer_byte;
function ReadOnly#(PortStatus) get_status(QsfpModuleController m) = m.registers.port_status;
function Reg#(PortControl) get_control(QsfpModuleController m) = m.registers.port_control;

endpackage: QsfpModuleController
