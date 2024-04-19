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

// functions for doing mapping
export get_pins;
export get_registers;
export get_read_addr;
export get_read_data;
export get_status;
export get_control;

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
import CommonFunctions::*;
import I2CBitController::*;
import I2CCommon::*;
import I2CCore::*;
import PowerRail::*;

// Cobalt
import Bidirection::*;
import Debouncer::*;

// RDL auto-generated code
import QsfpX32ControllerRegsPkg::*;

typedef struct {
    Integer system_frequency_hz;
    Integer i2c_frequency_hz;
    Integer power_good_timeout_ms;
    Integer t_init_ms;
} Parameters;

instance DefaultValue#(Parameters);
    defaultValue = Parameters {
        system_frequency_hz: 50_000_000,
        i2c_frequency_hz: 100_000,
        power_good_timeout_ms: 10,
        t_init_ms: 2000 // t_init is 2 seconds per SFF-8679
    };
endinstance

// A data/address pair to do a BRAM write
typedef struct {
    Bit#(8) data;
    Bit#(8) address;
} RamWrite deriving (Eq, Bits, FShow);

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
    // communication
    interface Bidirection#(Bit#(1)) scl;
    interface Bidirection#(Bit#(1)) sda;
    // low-speed control
    method Bit#(1) lpmode;
    method Bit#(1) resetl;
    method Action intl(Bit#(1) val);
    method Action modprsl(Bit#(1) val);
    // eFuse power supply
    method Bool power_en;
    method Action power_good(Bool val);
endinterface

interface QsfpModuleController;
    // Physical FPGA pins for the controller
    interface Pins pins;

    // Inputs from module fed back out to register for readback
    method Bool modprsl;
    method Bool intl;

    // Software controlled module pins
    method Action resetl(Bit#(1) val);
    method Action lpmode(Bit#(1) val);

    // Software controlled hot swap controller power enable
    method Action power_en(Bit#(1) val);

    // Power fault state from the controller
    method Bool pg;
    method Bool pg_timeout;
    method Bool pg_lost;

    // Convenience method to query if the module is initialized
    method Bool module_initialized;

    // Register interface exposed over SPI
    interface Registers registers;

    // new I2C Command to feed to the I2C core
    interface Put#(Command) i2c_command;

    // this is how the write buffer gets filled
    interface Put#(RamWrite) i2c_write_data;

    // ticks for internal delay counters
    method Action tick_1ms(Bool val);
endinterface

module mkQsfpModuleController #(Parameters parameters) (QsfpModuleController);
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
    Reg#(Bool) module_initialized_r             <- mkReg(False);

    // Internal pin signals, named with _ to avoid collisions at the interface
    Reg#(Bit#(1)) resetl_  <- mkReg(1);
    Reg#(Bit#(1)) lpmode_  <- mkReg(0);

    Reg#(Bool) hw_power_en          <- mkReg(False);
    Reg#(Bit#(1)) lpmode_hw_gated   <- mkReg(0);

    Wire#(Bit#(1)) power_en_sw    <- mkWire();

    // Status
    Reg#(QsfpStatusPort0Error) error    <- mkReg(NoError);
    PulseWire clear_fault               <- mkPulseWire();
    Reg#(PortStatus) port_status_r <- mkReg(defaultValue);

    // Control - unused currently
    Reg#(PortControl) control   <- mkReg(defaultValue);

    // Delay
    Wire#(Bool) tick_1ms_               <- mkWire();
    Reg#(UInt#(11)) init_delay_counter  <- mkReg(0);

    // We do some light debouncing on these input signals since any single-cycle
    // glitch could cause a fault.
    Debouncer#(5, 5, Bool) power_good_ <- mkDebouncer(False);
    Debouncer#(5, 5, Bool) intl_ <- mkDebouncer(True);
    Debouncer#(5, 5, Bool) modprsl_ <- mkDebouncer(True);

    mkConnection(asIfc(tick_1ms_), asIfc(power_good_));
    mkConnection(asIfc(tick_1ms_), asIfc(intl_));
    mkConnection(asIfc(tick_1ms_), asIfc(modprsl_));

    // Power Rail control for the hot swap controller
    PowerRail#(4) hot_swap  <- mkPowerRailDisableOnAbort(parameters.power_good_timeout_ms);
    Reg#(Bool) power_en_ <- mkReg(False);
    mkConnection(hot_swap.pins.en, power_en_._write);
    mkConnection(power_good_, hot_swap.pins.pg);

    // The hot swap expected a tick to correspond with its timeout
    (* fire_when_enabled *)
    rule do_hot_swap_tick (tick_1ms_);
        hot_swap.send();
    endrule

    (* fire_when_enabled *)
    rule do_power_control;
        if (modprsl_ || (hot_swap.timed_out() || hot_swap.aborted())) begin
            hot_swap.set_enable(False);
            hw_power_en <= False;
        end else if (!modprsl_ && !hw_power_en) begin
            hot_swap.set_enable(power_en_sw == 1);
            hw_power_en <= power_en_;
        end
    endrule

    // The assertion of LpMode needs to be gated by applying eFuse power.
    // Otherwise, the 3V3 from driving LpMode bleeds out on the eFuse 3V3 rail,
    // resulting in pull-ups rising. For additional details, see
    // https://github.com/oxidecomputer/hardware-qsfp-x32/issues/47
    (* fire_when_enabled *)
    rule do_lpmode_gating;
        lpmode_hw_gated <= pack(lpmode_ == 1 && hw_power_en && power_good_);
    endrule

    // Clear a hot swap controller fault
    (* fire_when_enabled *)
    rule do_fault_clear (clear_fault && (hot_swap.timed_out() || hot_swap.aborted()));
        hot_swap.clear();
    endrule

    // Set `module_initialized_r` after `t_init_ms` has elapsed after resetl
    // has been deasserted.
    rule do_reset_initialization (tick_1ms_ && !module_initialized_r && !modprsl_ && resetl_ == 1);
        if (init_delay_counter > fromInteger(parameters.t_init_ms)) begin
            module_initialized_r  <= True;
        end
        init_delay_counter  <= init_delay_counter + 1;
    endrule

    // If resetl is asserted, clear initialized state.
    rule do_reset_init_delay (modprsl_ || resetl_ == 0);
        module_initialized_r  <= False;
        init_delay_counter  <= 0;
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
        read_buffer
            .portA
            .request
            .put(makeRequest(True, read_buffer_write_addr, wdata));
        i2c_data_received.send();
    endrule

    // SPI interface changes read_buffer_read_addr, making a read request via
    //PortB
    (* fire_when_enabled *)
    rule do_read_buffer_portb_write;
        read_buffer
            .portB
            .request
            .put(makeRequest(False, read_buffer_read_addr, 8'h00));
    endrule

    // PortB responds with the requested data, passing it back to SPI via
    //read_buffer_read_data
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

    // I2C interface changes write_buffer_read_addr, making a read request via
    // PortB
    (* fire_when_enabled *)
    rule do_write_buffer_portb_write;
        write_buffer.b.put(False, write_buffer_read_addr, 8'h00);
    endrule

    // PortB responds with the requested data, passing it back to I2C via
    // write_buffer_write_data
    (* fire_when_enabled *)
    rule do_write_buffer_portb_read;
        i2c_core.send_data.offer(write_buffer.b.read());
    endrule

    // Since the error register is somewhat derived at this layer it needs to
    // be registered for persistence. It will also stay modprsl until the next
    // I2C transaction starts on the port.
    (* fire_when_enabled *)
    rule do_i2c;
        if (i2c_attempt && modprsl_) begin
            error   <= NoModule;
        end else if (i2c_attempt &&
            (hot_swap.timed_out || hot_swap.aborted)) begin
            error   <= PowerFault;
        end else if (i2c_attempt && !hot_swap.enabled) begin
            error   <= NoPower;
        end else if (i2c_attempt && !module_initialized_r) begin
            error   <= NotInitialized;
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

    // Adding a register stage here to help out timing.
    // The mux going into the error register is pretty nasty (see do_i2c rule
    // above) and connecting it directly to the SPI peripheral would result in
    // missing timing occassionally.
    (* fire_when_enabled *)
    rule do_port_status_reg;
        port_status_r <= PortStatus {
            busy: pack(i2c_core.busy()),
            error: {0, pack(error)}
        };
    endrule

    // Registers for SPI peripheral
    interface Registers registers;
        interface ReadOnly port_status = valueToReadOnly(port_status_r);
        interface Reg port_control;
            method _read = control;
            method Action _write(PortControl _);
                clear_fault.send();
            endmethod
        endinterface
        interface Wire read_buffer_addr;
            method _read = read_buffer_read_addr;
            method Action _write(Bit#(8) address);
                read_buffer_read_addr   <= address;
            endmethod
        endinterface
        interface ReadOnly read_buffer_byte =
            valueToReadOnly(read_buffer_read_data);
    endinterface

    // Physical module pins
    interface Pins pins;
        interface Bidirection scl = i2c_core.pins.scl;
        interface Bidirection sda = i2c_core.pins.sda;

        method lpmode = pack(lpmode_hw_gated);
        method resetl = pack(resetl_);
        method Action intl(Bit#(1) v);
            intl_ <= unpack(v);
        endmethod
        method Action modprsl(Bit#(1) v);
            modprsl_ <= unpack(v);
        endmethod

        method power_en = power_en_;
        method power_good = power_good_._write;
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

    method resetl   = resetl_._write;
    method lpmode   = lpmode_._write;
    method modprsl  = modprsl_;
    method intl     = intl_;

    method power_en     = power_en_sw._write;
    method pg           = hot_swap.pin_state.good;
    method pg_timeout   = hot_swap.timed_out;
    method pg_lost      = hot_swap.aborted;

    method module_initialized = module_initialized_r;

    method tick_1ms = tick_1ms_._write;

endmodule

function Pins get_pins(QsfpModuleController m) = m.pins;
function Registers get_registers(QsfpModuleController m) = m.registers;
function Wire#(Bit#(8)) get_read_addr(QsfpModuleController m) =
    m.registers.read_buffer_addr;
function ReadOnly#(Bit#(8)) get_read_data(QsfpModuleController m) =
    m.registers.read_buffer_byte;
function ReadOnly#(PortStatus) get_status(QsfpModuleController m) =
    m.registers.port_status;
function Reg#(PortControl) get_control(QsfpModuleController m) =
    m.registers.port_control;

endpackage: QsfpModuleController
