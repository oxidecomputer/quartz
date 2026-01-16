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
import CommonInterfaces::*;
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
    interface Reg#(SwPowerEn0) sw_power_en0;
    interface Reg#(SwPowerEn1) sw_power_en1;
    interface ReadOnly#(PowerEn0) power_en0;
    interface ReadOnly#(PowerEn1) power_en1;
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
    interface Vector#(16, ReadVolatileReg#(Bit#(8))) mod_i2c_data;
    interface Vector#(16, Reg#(PortDebug)) mod_debugs;
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

    // SPI Interface
    Reg#(I2cBusAddr) i2c_bus_addr   <- mkReg(defaultValue);
    Reg#(I2cRegAddr) i2c_reg_addr   <- mkReg(defaultValue);
    Reg#(I2cNumBytes) i2c_num_bytes <- mkReg(defaultValue);
    Reg#(I2cBcast0) i2c_bcast0      <- mkReg(defaultValue);
    Reg#(I2cBcast1) i2c_bcast1      <- mkReg(defaultValue);
    Reg#(I2cCtrl) i2c_ctrl          <- mkDReg(defaultValue);
    Reg#(SwPowerEn0) sw_power_en0   <- mkReg(defaultValue);
    Reg#(SwPowerEn1) sw_power_en1   <- mkReg(defaultValue);
    Reg#(PowerEn0) power_en0        <- mkReg(defaultValue);
    Reg#(PowerEn1) power_en1        <- mkReg(defaultValue);
    Reg#(ModResetl0) mod_resetl0    <- mkReg(defaultValue);
    Reg#(ModResetl1) mod_resetl1    <- mkReg(defaultValue);
    Reg#(ModLpmode0) mod_lpmode0    <- mkReg(defaultValue);
    Reg#(ModLpmode1) mod_lpmode1    <- mkReg(defaultValue);

    // Extra register stages
    Reg#(I2cCtrl) i2c_ctrl_r        <- mkDReg(defaultValue);

    Vector#(16, Bool) i2c_broadcast_enabled =
        unpack({unpack(pack(i2c_bcast1)), unpack(pack(i2c_bcast0))});
    Vector#(16, Reg#(Bool)) i2c_broadcast_enabled_r <- replicateM(mkReg(False));

    // Vectorize all the low speed module signals mapping into local registers.
    Vector#(16, Bit#(1)) sw_power_en_bits =
        unpack({pack(sw_power_en1), pack(sw_power_en0)});
    Vector#(16, Reg#(Bit#(1))) sw_power_en_bits_r <- replicateM(mkReg(1));

    Vector#(16, Bit#(1)) resetl_bits =
        unpack({pack(mod_resetl1), pack(mod_resetl0)});
    Vector#(16, Reg#(Bit#(1))) resetl_bits_r <- replicateM(mkReg(1));

    Vector#(16, Bit#(1)) lpmode_bits =
        unpack({pack(mod_lpmode1), pack(mod_lpmode0)});
    Vector#(16, Reg#(Bit#(1))) lpmode_bits_r <- replicateM(mkReg(1));

    Vector#(16, Reg#(Bit#(1))) power_en_bits_r    <- replicateM(mkReg(0));
    Vector#(16, Reg#(Bit#(1))) pg_bits_r          <- replicateM(mkReg(0));
    Vector#(16, Reg#(Bit#(1))) pg_timeout_bits_r  <- replicateM(mkReg(0));
    Vector#(16, Reg#(Bit#(1))) pg_lost_bits_r     <- replicateM(mkReg(0));

    Vector#(16, Reg#(Bit#(1))) modprsl_bits_r <- replicateM(mkReg(1));
    Vector#(16, Reg#(Bit#(1))) intl_bits_r    <- replicateM(mkReg(1));

    // Vectorize I2C status signals
    Vector#(16, Bit#(1)) i2c_busys;

    Wire#(Bool) tick_1ms_       <- mkWire();

    // Local registers for module signals
    (* fire_when_enabled *)
    rule do_module_regs;
         for (int i = 0; i < 16; i = i + 1) begin
            // software control
            sw_power_en_bits_r[i]   <= sw_power_en_bits[i];
            resetl_bits_r[i]        <= resetl_bits[i];
            lpmode_bits_r[i]        <= lpmode_bits[i];

            // pin state readbacks
            power_en_bits_r[i]  <= pack(qsfp_ports[i].pins.power_en);
            pg_bits_r[i]        <= pack(qsfp_ports[i].pg);
            modprsl_bits_r[i]   <= pack(qsfp_ports[i].modprsl);
            intl_bits_r[i]      <= pack(qsfp_ports[i].intl);

            // fault state readbacks
            pg_timeout_bits_r[i]  <= pack(qsfp_ports[i].pg_timeout);
            pg_lost_bits_r[i]     <= pack(qsfp_ports[i].pg_lost);

            i2c_broadcast_enabled_r[i] <= i2c_broadcast_enabled[i];
        end

        i2c_ctrl_r  <= i2c_ctrl;
    endrule

    // Map all the module signals around
    for (int i = 0; i < 16; i = i + 1) begin
        // software controlled bits
        mkConnection(qsfp_ports[i].resetl, resetl_bits_r[i]);
        mkConnection(qsfp_ports[i].lpmode, lpmode_bits_r[i]);
        mkConnection(qsfp_ports[i].sw_power_en, sw_power_en_bits_r[i]);

        // tick fan out
        mkConnection(qsfp_ports[i].tick_1ms, tick_1ms_);

        // other state
        i2c_busys[i]        = qsfp_ports[i].registers.port_status.busy;
    end

    // Only do I2C transactions if they are enabled for the given port.
    (* fire_when_enabled *)
    rule do_i2c_command_broadcast(i2c_ctrl_r.start == 1);

        Command next_command = Command {
            op: unpack(i2c_ctrl_r.op),
            i2c_addr: i2c_bus_addr.addr,
            reg_addr: i2c_reg_addr.addr,
            num_bytes: unpack(i2c_num_bytes.count)
        };

        for (int i = 0; i < 16; i = i + 1) begin
            if (i2c_broadcast_enabled_r[i]) begin
                qsfp_ports[i].i2c_command.put(next_command);
            end
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
        interface Reg sw_power_en0 = sw_power_en0;
        interface Reg sw_power_en1 = sw_power_en1;
        interface Reg mod_resetl0 = mod_resetl0;
        interface Reg mod_resetl1 = mod_resetl1;
        interface Reg mod_lpmode0 = mod_lpmode0;
        interface Reg mod_lpmode1 = mod_lpmode1;
        interface ReadOnly power_en0 =
            valueToReadOnly(unpack(pack(map(readReg, power_en_bits_r))[7:0]));
        interface ReadOnly power_en1 = 
            valueToReadOnly(unpack(pack(map(readReg, power_en_bits_r))[15:8]));
        interface ReadOnly power_good0 =
            valueToReadOnly(unpack(pack(map(readReg, pg_bits_r))[7:0]));
        interface ReadOnly power_good1 =
            valueToReadOnly(unpack(pack(map(readReg, pg_bits_r))[15:8]));
        interface ReadOnly mod_modprsl0 =
            valueToReadOnly(unpack(pack(map(readReg, modprsl_bits_r))[7:0]));
        interface ReadOnly mod_modprsl1 =
            valueToReadOnly(unpack(pack(map(readReg, modprsl_bits_r))[15:8]));
        interface ReadOnly mod_intl0 =
            valueToReadOnly(unpack(pack(map(readReg, intl_bits_r))[7:0]));
        interface ReadOnly mod_intl1 =
            valueToReadOnly(unpack(pack(map(readReg, intl_bits_r))[15:8]));
        interface ReadOnly power_good_timeout0 =
            valueToReadOnly(unpack(pack(map(readReg, pg_timeout_bits_r))[7:0]));
        interface ReadOnly power_good_timeout1 =
            valueToReadOnly(unpack(pack(map(readReg, pg_timeout_bits_r))[15:8]));
        interface ReadOnly power_good_lost0 =
            valueToReadOnly(unpack(pack(map(readReg, pg_lost_bits_r))[7:0]));
        interface ReadOnly power_good_lost1 =
            valueToReadOnly(unpack(pack(map(readReg, pg_lost_bits_r))[15:8]));
        interface mod_i2c_data =
            map(QsfpModuleController::get_i2c_data, qsfp_ports);
        interface mod_debugs =
            map(QsfpModuleController::get_debug, qsfp_ports);
    endinterface

    interface module_pins = map(QsfpModuleController::get_pins, qsfp_ports);
    method tick_1ms = tick_1ms_._write;
endmodule

endpackage: QsfpModulesTop
