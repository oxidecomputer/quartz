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
export Pins(..);
export Registers(..);

// functions for doing mapping
export get_pins;
export get_registers;
export get_i2c_data;
export get_status;
export get_control;

// BSV
import BRAM::*;
import BRAMCore::*;
import BRAMFIFO::*;
import ConfigReg::*;
import Connectable::*;
import DefaultValue::*;
import DReg::*;
import FIFOF::*;
import GetPut::*;
import StmtFSM::*;

// Quartz
import Bidirection::*;
import Debouncer::*;
import CommonFunctions::*;
import CommonInterfaces::*;
import Countdown::*;
import I2CBitController::*;
import I2CCommon::*;
import I2CCore::*;
import PowerRail::*;

// RDL auto-generated code
import QsfpX32ControllerRegsPkg::*;

typedef struct {
    Integer system_frequency_hz;
    Integer core_clk_period_ns;
    Integer i2c_frequency_hz;
    Integer power_good_timeout_ms;
    Integer t_init_ms;
    Integer t_clock_hold_us;
    Integer i2c_timeout_us;
} Parameters;

instance DefaultValue#(Parameters);
    defaultValue = Parameters {
        system_frequency_hz: 50_000_000,
        core_clk_period_ns: 20,
        i2c_frequency_hz: 100_000,
        power_good_timeout_ms: 20,
        t_init_ms: 2000, // t_init is 2 seconds per SFF-8679
        t_clock_hold_us: 500, // t_clock_hold is 500 microseconds per SFF-8636
        i2c_timeout_us: 27000 // SFF-8636 doesn't specify, so slightly exceed 25ms to align with SMBus t_timeout,min
    };
endinstance

interface Registers;
    interface ReadOnly#(PortStatus) port_status;
    interface Reg#(PortControl) port_control;
    interface ReadVolatileReg#(Bit#(8)) i2c_data;
    interface Reg#(PortDebug) port_debug;
endinterface

interface Pins;
    interface Bidirection#(Bit#(1)) scl;
    interface Bidirection#(Bit#(1)) sda;
    method Bit#(1) lpmode;
    method Bit#(1) resetl;
    method Action intl(Bit#(1) val);
    method Action modprsl(Bit#(1) val);
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
    method Action sw_power_en(Bit#(1) val);

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

    // ticks for internal delay counters
    method Action tick_1ms(Bool val);
endinterface

module mkQsfpModuleController #(Parameters parameters) (QsfpModuleController);
    // I2C core for the module management interface
    I2CCore i2c_core    <-
        mkI2CCore(parameters.system_frequency_hz,
                parameters.i2c_frequency_hz,
                parameters.core_clk_period_ns,
                parameters.t_clock_hold_us);

    Wire#(Bool) i2c_busy_w    <- mkWire();
    mkConnection(i2c_busy_w._write, i2c_core.busy);

    // The read_buffer stores data read back from the module
    FIFOF#(Bit#(8)) rdata_fifo      <- mkSizedBRAMFIFOF(128);
    PulseWire rdata_fifo_deq        <- mkPulseWire();
    PulseWire rdata_fifo_clear_req  <- mkPulseWire();
    Reg#(Bool) rdata_fifo_clear_req_r  <- mkReg(False);
    Reg#(Bit#(8)) rdata_r           <- mkReg('h00);

    // The write_buffer stores data to be written to the module
    FIFOF#(Bit#(8)) wdata_fifo      <- mkSizedBRAMFIFOF(128);
    PulseWire wdata_fifo_deq        <- mkPulseWire();
    PulseWire wdata_fifo_clear_req  <- mkPulseWire();
    Reg#(Bool) wdata_fifo_clear_req_r  <- mkReg(False);
    Wire#(Bit#(8)) wdata_w          <- mkWire();

    // I2C control
    PulseWire new_i2c_command                   <- mkPulseWire();
    PulseWire i2c_data_received                 <- mkPulseWire();
    Reg#(Bool) i2c_attempt                      <- mkDReg(False);
    Reg#(I2CCore::Command) next_i2c_command     <- mkReg(defaultValue);
    Reg#(Bool) module_initialized_r             <- mkReg(False);
    Countdown#(15) i2c_timeout_countdown        <- mkCountdownBy1();
    PulseWire force_i2c_timeout_set             <- mkPulseWire();
    PulseWire force_i2c_timeout_clr             <- mkPulseWire();
    Reg#(Bool) force_i2c_timeout_req      <- mkReg(False);
    Reg#(Bool) force_i2c_timeout          <- mkReg(False);
    Reg#(Bool) wtf                              <- mkReg(False);
    Reg#(Bool) tiggle                           <- mkReg(False);


    // Internal pin signals, named with _ to avoid collisions at the interface
    Reg#(Bit#(1)) resetl_  <- mkReg(1);
    Reg#(Bit#(1)) lpmode_  <- mkReg(0);

    Reg#(Bool) hw_power_en          <- mkReg(False);
    Reg#(Bit#(1)) lpmode_hw_gated   <- mkReg(0);

    Wire#(Bit#(1)) power_en_sw    <- mkWire();

    // Status
    Reg#(QsfpPort0StatusError) error    <- mkReg(NoError);
    PulseWire clear_fault               <- mkPulseWire();
    Reg#(PortStatus) port_status_r <- mkReg(defaultValue);

    // Control - unused currently
    Reg#(PortControl) control   <- mkReg(defaultValue);

    // Delay
    Wire#(Bool) tick_1ms_               <- mkWire();
    Reg#(UInt#(11)) init_delay_counter  <- mkReg(0);

    // We do some light debouncing on these input signals since any single-cycle
    // glitch could cause a fault.
    Debouncer#(5, 5, Bool) power_good_  <- mkDebouncer(False);
    Debouncer#(5, 5, Bool) intl_        <- mkDebouncer(True);
    Debouncer#(5, 5, Bool) modprsl_     <- mkDebouncer(True);
    mkConnection(asIfc(tick_1ms_), asIfc(power_good_));
    mkConnection(asIfc(tick_1ms_), asIfc(intl_));
    mkConnection(asIfc(tick_1ms_), asIfc(modprsl_));

    // Power Rail control for the hot swap controller
    PowerRail#(5) hot_swap  <- mkPowerRailDisableOnAbort(parameters.power_good_timeout_ms);
    Reg#(Bool) power_en_ <- mkReg(False);
    mkConnection(hot_swap.pins.en, power_en_._write);
    mkConnection(power_good_, hot_swap.pins.pg);

    // I2C core puts read bytes into the buffer
    mkConnection(i2c_core.received_data.get, rdata_fifo.enq);
    // Expose the next entry for the SPI interface
    mkConnection(rdata_fifo.first, rdata_r._write);

    // SPI interface puts bytes into the buffer
    mkConnection(wdata_w._read, wdata_fifo.enq);
    // I2C core pulls bytes to write from the buffer
    mkConnection(wdata_fifo.first, i2c_core.send_data.offer);

    // The hot swap expected a tick to correspond with its timeout
    (* fire_when_enabled *)
    rule do_hot_swap_tick (tick_1ms_);
        hot_swap.send();
    endrule

    (* fire_when_enabled *)
    rule do_i2c_timeout_tick(tick_1ms_ && i2c_core.busy());
        i2c_timeout_countdown.send();
    endrule

    (* fire_when_enabled *)
    rule do_force_i2c_timeout_req;
        if (force_i2c_timeout_set) begin
            force_i2c_timeout_req <= True;
        end else if (force_i2c_timeout_clr) begin
            force_i2c_timeout_req <= False;
        end
    endrule

    (* fire_when_enabled *)
    rule do_force_i2c_timeout;
        force_i2c_timeout <= force_i2c_timeout_req && i2c_core.busy();
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

    // Handle the FIFO clear requests
    (* fire_when_enabled *)
    rule do_rdata_fifo_clear_reg (!rdata_fifo_clear_req_r);
        rdata_fifo_clear_req_r  <= rdata_fifo_clear_req;
    endrule

    (* fire_when_enabled *)
    rule do_handle_rdata_fifo_clear (rdata_fifo_clear_req_r && !i2c_busy_w 
                                    && i2c_attempt);
        rdata_fifo.clear();
        rdata_fifo_clear_req_r <= False;
    endrule

    (* fire_when_enabled *)
    rule do_wdata_fifo_clear_reg (!wdata_fifo_clear_req_r);
        wdata_fifo_clear_req_r  <= wdata_fifo_clear_req;
    endrule

    (* fire_when_enabled *)
    rule do_handle_wdata_fifo_clear (wdata_fifo_clear_req_r && !i2c_busy_w);
        wdata_fifo.clear();
        wdata_fifo_clear_req_r <= False;
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

    // When the SPI interface reads a byte, remove it from the read buffer
    (* fire_when_enabled *)
    rule do_read_buffer_deq (rdata_fifo_deq);
        rdata_fifo.deq();
    endrule

    // When the I2C core sends a byte, remove it from the write buffer
    (* fire_when_enabled *)
    rule do_wdata_fifo_deq (i2c_core.send_data.accepted);
        wdata_fifo.deq();
    endrule

    // Since the error register is somewhat derived at this layer it needs to
    // be registered for persistence. It will also stay modprsl until the next
    // I2C transaction starts on the port.
    (* fire_when_enabled *)
    rule do_i2c(!(i2c_timeout_countdown || force_i2c_timeout));
        tiggle <= !tiggle;
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
            i2c_timeout_countdown   <= fromInteger(parameters.i2c_timeout_us);
        end else if (isValid(i2c_core.error)) begin
            let err = fromMaybe(?, i2c_core.error);
            if (err == AddressNack) begin
                error   <= I2cAddressNack;
            end else if (err == ByteNack) begin
                error   <= I2cByteNack;
            end
        end else if (i2c_core.scl_stretch_timeout() && module_initialized_r) begin
            // we gate this on the module being initialized as that means we've
            // actually powered the module (and therefore, the I2C pullups) and
            // released it from reset for it to stretch in the first place.
            error   <= I2cSclStretchTimeout;
        end
    endrule

    (* fire_when_enabled *)
    rule do_i2c_timeout(i2c_timeout_countdown || force_i2c_timeout);
        force_i2c_timeout_clr.send();
        i2c_core.abort.send();
        error   <= I2cTransactionTimeout;
        wtf     <= True;
    endrule

    // Adding a register stage here to help out timing.
    // The mux going into the error register is pretty nasty (see do_i2c rule
    // above) and connecting it directly to the SPI peripheral would result in
    // missing timing occassionally.
    (* fire_when_enabled *)
    rule do_port_status_reg;
        port_status_r <= PortStatus {
            stretching_seen: pack(i2c_core.scl_stretch_seen()),
            rdata_fifo_empty: pack(!rdata_fifo.notEmpty()),
            wdata_fifo_empty: pack(!wdata_fifo.notEmpty()),
            busy: pack(i2c_core.busy()),
            error: pack(error)
        };
    endrule

    // Registers for SPI peripheral
    interface Registers registers;
        interface ReadOnly port_status = valueToReadOnly(port_status_r);

        interface Reg port_control;
            method _read = control;
            method Action _write(PortControl v);
                if (v.rdata_fifo_clear == 1) begin
                    rdata_fifo_clear_req.send();
                end

                if (v.wdata_fifo_clear == 1) begin
                    wdata_fifo_clear_req.send();
                end

                if (v.clear_fault == 1) begin
                    clear_fault.send();
                end
            endmethod
        endinterface

        interface ReadVolatileReg i2c_data;
            method ActionValue#(Bit#(8)) _read;
                rdata_fifo_deq.send();
                return rdata_r;
            endmethod

            method _write = wdata_w._write;
        endinterface

        interface Reg port_debug;
            method _read = PortDebug {
                force_i2c_timeout: pack(force_i2c_timeout_req)
            };
            method Action _write(PortDebug v);
                if (v.force_i2c_timeout == 1) begin
                    force_i2c_timeout_set.send();
                end
            endmethod
        endinterface
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

    method resetl   = resetl_._write;
    method lpmode   = lpmode_._write;
    method modprsl  = modprsl_;
    method intl     = intl_;

    method sw_power_en  = power_en_sw._write;
    method pg           = hot_swap.pin_state.good;
    method pg_timeout   = hot_swap.timed_out;
    method pg_lost      = hot_swap.aborted;

    method module_initialized = module_initialized_r;

    method tick_1ms = tick_1ms_._write;
endmodule

function Pins get_pins(QsfpModuleController m) = m.pins;
function Registers get_registers(QsfpModuleController m) = m.registers;
function ReadVolatileReg#(Bit#(8)) get_i2c_data(QsfpModuleController m) =
    m.registers.i2c_data;
function ReadOnly#(PortStatus) get_status(QsfpModuleController m) =
    m.registers.port_status;
function Reg#(PortControl) get_control(QsfpModuleController m) =
    m.registers.port_control;

endpackage: QsfpModuleController
