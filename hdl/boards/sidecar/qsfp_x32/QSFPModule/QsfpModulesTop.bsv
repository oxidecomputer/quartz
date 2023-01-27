// Copyright 2022 Oxide Computer Company
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package QsfpModulesTop;

// BSV
import BRAM::*;
import ConfigReg::*;
import Connectable::*;
import DefaultValue::*;
import DReg::*;
import GetPut::*;
import Vector::*;

// Quartz
import Bidirection::*;
import CommonFunctions::*;
import I2CCore::*;

// Cobalt
import Strobe::*;

import QsfpModuleController::*;
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

interface Registers;
    interface Reg#(I2cBusAddr) i2c_bus_addr;
    interface Reg#(I2cRegAddr) i2c_reg_addr;
    interface Reg#(I2cNumBytes) i2c_num_bytes;
    interface Reg#(I2cBcast0) i2c_bcast0;
    interface Reg#(I2cBcast1) i2c_bcast1;
    interface Reg#(I2cCtrl) i2c_ctrl;
    interface ReadOnly#(I2cBusy0) i2c_busy0;
    interface ReadOnly#(I2cBusy1) i2c_busy1;
    interface Vector#(16, ReadOnly#(PortStatus)) mod_statuses;
    interface Vector#(16, Reg#(PortControl)) mod_controls;
    interface Reg#(PowerEn0) power_en0;
    interface Reg#(PowerEn1) power_en1;
    interface ReadOnly#(PowerGood0) power_good0;
    interface ReadOnly#(PowerGood1) power_good1;
    interface ReadOnly#(PowerGoodTimeout0) power_good_timeout0;
    interface ReadOnly#(PowerGoodTimeout1) power_good_timeout1;
    interface ReadOnly#(PowerGoodLost0) power_good_lost0;
    interface ReadOnly#(PowerGoodLost1) power_good_lost1;
    interface Reg#(ModResetl0) mod_resetl0;
    interface Reg#(ModResetl1) mod_resetl1;
    interface Reg#(ModLpmode0) mod_lpmode0;
    interface Reg#(ModLpmode1) mod_lpmode1;
    interface ReadOnly#(ModModprsl0) mod_modprsl0;
    interface ReadOnly#(ModModprsl1) mod_modprsl1;
    interface ReadOnly#(ModIntl0) mod_intl0;
    interface ReadOnly#(ModIntl1) mod_intl1;
    interface Reg#(Bit#(8)) mod_write_addr;
    interface Reg#(Bit#(8)) mod_write_data;
    interface Vector#(16, Wire#(Bit#(8))) mod_read_addrs;
    interface Vector#(16, ReadOnly#(Bit#(8))) mod_read_buffers;
endinterface

interface QsfpModulesTop;
    interface Registers registers;
    interface Vector#(16, QsfpModuleController::Pins) module_pins;
    method Action tick_1ms(Bool val);
endinterface

module mkQsfpModulesTop #(Parameters parameters) (QsfpModulesTop);

    // Vector of all the ports this FPGA will control
    Vector#(16, QsfpModuleController) qsfp_ports <-
        replicateM(mkQsfpModuleController(defaultValue));

    Reg#(I2cBusAddr) i2c_bus_addr   <- mkReg(defaultValue);
    Reg#(I2cRegAddr) i2c_reg_addr   <- mkReg(defaultValue);
    Reg#(I2cNumBytes) i2c_num_bytes <- mkReg(defaultValue);
    Reg#(I2cBcast0) i2c_bcast0      <- mkReg(defaultValue);
    Reg#(I2cBcast1) i2c_bcast1      <- mkReg(defaultValue);
    Reg#(I2cCtrl) i2c_ctrl          <- mkDReg(defaultValue);
    Reg#(PowerEn0) power_en0        <- mkReg(defaultValue);
    Reg#(PowerEn1) power_en1        <- mkReg(defaultValue);
    Reg#(ModResetl0) mod_resetl0    <- mkReg(defaultValue);
    Reg#(ModResetl1) mod_resetl1    <- mkReg(defaultValue);
    Reg#(ModLpmode0) mod_lpmode0    <- mkReg(defaultValue);
    Reg#(ModLpmode1) mod_lpmode1    <- mkReg(defaultValue);

    // opting to register these since there will be a lot of fan out
    ConfigReg#(Bit#(8)) mod_write_addr  <- mkConfigReg(0);
    ConfigReg#(Bit#(8)) mod_write_data  <- mkConfigReg(0);
    Reg#(Bool) issue_write              <- mkDReg(False);

    Vector#(16, Bool) i2c_broadcast_enabled =
        unpack({unpack(pack(i2c_bcast1)), unpack(pack(i2c_bcast0))});

    // Vectorize all the low speed module signals for reading
    Vector#(16, Bit#(1)) power_en_bits =
    unpack({pack(power_en1), pack(power_en0)});
    Vector#(16, Bit#(1)) pg_bits;
    Vector#(16, Bit#(1)) pg_timeout_bits;
    Vector#(16, Bit#(1)) pg_lost_bits;
    Vector#(16, Bit#(1)) resetl_bits =
        unpack({pack(mod_resetl1), pack(mod_resetl0)});
    Vector#(16, Bit#(1)) lpmode_bits =
        unpack({pack(mod_lpmode1), pack(mod_lpmode0)});
    Vector#(16, Bit#(1)) modprsl_bits;
    Vector#(16, Bit#(1)) intl_bits;

    // Vectorize I2C status signals
    Vector#(16, Bit#(1)) i2c_busys;

    Wire#(Bool) tick_1ms_       <- mkWire();

    // map modules into registers
    for (int i = 0; i < 16; i = i + 1) begin
        // pin state readbacks
        pg_bits[i]          = pack(qsfp_ports[i].pg);
        modprsl_bits[i]     = pack(qsfp_ports[i].modprsl);
        intl_bits[i]        = pack(qsfp_ports[i].intl);

        // fault state readbacks
        pg_timeout_bits[i]  = pack(qsfp_ports[i].pg_timeout);
        pg_lost_bits[i]     = pack(qsfp_ports[i].pg_lost);

        // software controlled bits
        mkConnection(qsfp_ports[i].resetl, resetl_bits[i]);
        mkConnection(qsfp_ports[i].lpmode, lpmode_bits[i]);
        mkConnection(qsfp_ports[i].power_en, power_en_bits[i]);

        // tick fan out
        mkConnection(qsfp_ports[i].tick_1ms, tick_1ms_);

        // other state
        i2c_busys[i]        = qsfp_ports[i].registers.port_status.busy;
    end

    // Only do I2C transactions if they are enabled for the given port.
    (* fire_when_enabled *)
    rule do_i2c_command_broadcast(i2c_ctrl.start == 1);

        Command next_command = Command {
            op: unpack(i2c_ctrl.op),
            i2c_addr: i2c_bus_addr.addr,
            reg_addr: i2c_reg_addr.addr,
            num_bytes: unpack(i2c_num_bytes.count)
        };

        for (int i = 0; i < 16; i = i + 1) begin
            if (i2c_broadcast_enabled[i]) begin
                qsfp_ports[i].i2c_command.put(next_command);
            end
        end
    endrule

    // Put I2C write data into all write buffers, regardless if broadcast is
    // enabled. This makes the mental model for the programmer a bit more simple
    // in that you do not need to ensure broadcast is enabled to a port before
    // blasting in write data. If the port has i2c disabled, it won't receive
    // the command anyway.
    (* fire_when_enabled *)
    rule do_i2c_write_data_broadcast(issue_write);
        for (int i = 0; i < 16; i = i + 1) begin
                qsfp_ports[i]
                    .i2c_write_data
                    .put(RamWrite {
                        data: mod_write_data,
                        address: mod_write_addr });
        end
    endrule

    interface Registers registers;
        interface Reg i2c_bus_addr = i2c_bus_addr;
        interface Reg i2c_reg_addr = i2c_reg_addr;
        interface Reg i2c_num_bytes = i2c_num_bytes;
        interface Reg i2c_bcast0 = i2c_bcast0;
        interface Reg i2c_bcast1 = i2c_bcast1;
        interface Reg i2c_ctrl = i2c_ctrl;
        interface ReadOnly i2c_busy0 =
            valueToReadOnly(unpack(pack(i2c_busys)[7:0]));
        interface ReadOnly i2c_busy1 =
            valueToReadOnly(unpack(pack(i2c_busys)[15:8]));
        interface mod_statuses =
            map(QsfpModuleController::get_status, qsfp_ports);
        interface mod_controls =
            map(QsfpModuleController::get_control, qsfp_ports);
        interface Reg power_en0 = power_en0;
        interface Reg power_en1 = power_en1;
        interface Reg mod_resetl0 = mod_resetl0;
        interface Reg mod_resetl1 = mod_resetl1;
        interface Reg mod_lpmode0 = mod_lpmode0;
        interface Reg mod_lpmode1 = mod_lpmode1;
        interface ReadOnly power_good0 =
            valueToReadOnly(unpack(pack(pg_bits)[7:0]));
        interface ReadOnly power_good1 =
            valueToReadOnly(unpack(pack(pg_bits)[15:8]));
        interface ReadOnly mod_modprsl0 =
            valueToReadOnly(unpack(pack(modprsl_bits)[7:0]));
        interface ReadOnly mod_modprsl1 =
            valueToReadOnly(unpack(pack(modprsl_bits)[15:8]));
        interface ReadOnly mod_intl0 =
            valueToReadOnly(unpack(pack(intl_bits)[7:0]));
        interface ReadOnly mod_intl1 =
            valueToReadOnly(unpack(pack(intl_bits)[15:8]));
        interface ReadOnly power_good_timeout0 =
            valueToReadOnly(unpack(pack(pg_timeout_bits)[7:0]));
        interface ReadOnly power_good_timeout1 =
            valueToReadOnly(unpack(pack(pg_timeout_bits)[15:8]));
        interface ReadOnly power_good_lost0 =
            valueToReadOnly(unpack(pack(pg_lost_bits)[7:0]));
        interface ReadOnly power_good_lost1 =
            valueToReadOnly(unpack(pack(pg_lost_bits)[15:8]));
        interface mod_read_addrs =
            map(QsfpModuleController::get_read_addr, qsfp_ports);
        interface mod_read_buffers =
            map(QsfpModuleController::get_read_data, qsfp_ports);

        // addr and data are written in the same cycle in the SpiServer anyway,
        // so arbitrarily choose to pulse issue_write here versus in
        // mod_write_data
        interface Reg mod_write_addr;
            method _read = mod_write_addr;
            method Action _write(Bit#(8) new_addr);
                mod_write_addr  <= new_addr;
                issue_write     <= True;
            endmethod
        endinterface
        interface Reg mod_write_data = mod_write_data;
    endinterface

    interface module_pins = map(QsfpModuleController::get_pins, qsfp_ports);
    method tick_1ms = tick_1ms_._write;
endmodule

endpackage: QsfpModulesTop
