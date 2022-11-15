// Copyright 2022 Oxide Computer Company
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package QsfpModulesTop;

import BRAM::*;
import ConfigReg::*;
import Connectable::*;
import DefaultValue::*;
import DReg::*;
import GetPut::*;
import Vector::*;

import Bidirection::*;
import CommonFunctions::*;
import I2CCore::*;

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
    interface Reg#(I2cBcastL) i2c_bcast_l;
    interface Reg#(I2cBcastH) i2c_bcast_h;
    interface Reg#(I2cCtrl) i2c_ctrl;
    interface ReadOnly#(I2cBusyL) i2c_busy_l;
    interface ReadOnly#(I2cBusyH) i2c_busy_h;
    interface ReadOnly#(I2cStatusPort0) i2c_status_port0;
    interface ReadOnly#(I2cStatusPort1) i2c_status_port1;
    interface ReadOnly#(I2cStatusPort2) i2c_status_port2;
    interface ReadOnly#(I2cStatusPort3) i2c_status_port3;
    interface ReadOnly#(I2cStatusPort4) i2c_status_port4;
    interface ReadOnly#(I2cStatusPort5) i2c_status_port5;
    interface ReadOnly#(I2cStatusPort6) i2c_status_port6;
    interface ReadOnly#(I2cStatusPort7) i2c_status_port7;
    interface ReadOnly#(I2cStatusPort8) i2c_status_port8;
    interface ReadOnly#(I2cStatusPort9) i2c_status_port9;
    interface ReadOnly#(I2cStatusPort10) i2c_status_port10;
    interface ReadOnly#(I2cStatusPort11) i2c_status_port11;
    interface ReadOnly#(I2cStatusPort12) i2c_status_port12;
    interface ReadOnly#(I2cStatusPort13) i2c_status_port13;
    interface ReadOnly#(I2cStatusPort14) i2c_status_port14;
    interface ReadOnly#(I2cStatusPort15) i2c_status_port15;
    interface Reg#(CtrlEnL) mod_en_l;
    interface Reg#(CtrlEnH) mod_en_h;
    interface Reg#(CtrlResetL) mod_reset_l;
    interface Reg#(CtrlResetH) mod_reset_h;
    interface Reg#(CtrlLpmodeL) mod_lpmode_l;
    interface Reg#(CtrlLpmodeH) mod_lpmode_h;
    interface ReadOnly#(StatusPgL) mod_pg_l;
    interface ReadOnly#(StatusPgH) mod_pg_h;
    interface ReadOnly#(StatusPgTimeoutL) mod_pg_timeout_l;
    interface ReadOnly#(StatusPgTimeoutH) mod_pg_timeout_h;
    interface ReadOnly#(StatusPresentL) mod_present_l;
    interface ReadOnly#(StatusPresentH) mod_present_h;
    interface ReadOnly#(StatusIrqL) mod_irq_l;
    interface ReadOnly#(StatusIrqH) mod_irq_h;
    interface Reg#(Bit#(8)) mod_write_addr;
    interface Reg#(Bit#(8)) mod_write_data;
    interface Vector#(16, Wire#(Bit#(8))) mod_read_addrs;
    interface Vector#(16, ReadOnly#(Bit#(8))) mod_read_buffers;
endinterface

interface QsfpModulesTop;
    interface Registers registers;
    interface Vector#(16, QsfpModuleController::Pins) module_pins;
endinterface

module mkQsfpModulesTop #(Parameters parameters) (QsfpModulesTop);

    Vector#(16, QsfpModuleController) qsfp_ports <-
        replicateM(mkQsfpModuleController(defaultValue));

    Reg#(I2cBusAddr) i2c_bus_addr   <- mkReg(defaultValue);
    Reg#(I2cRegAddr) i2c_reg_addr   <- mkReg(defaultValue);
    Reg#(I2cNumBytes) i2c_num_bytes <- mkReg(defaultValue);
    Reg#(I2cBcastL) i2c_bcast_l     <- mkReg(defaultValue);
    Reg#(I2cBcastH) i2c_bcast_h     <- mkReg(defaultValue);
    Reg#(I2cCtrl) i2c_ctrl          <- mkDReg(defaultValue);
    Reg#(CtrlEnL) mod_en_l          <- mkReg(defaultValue);
    Reg#(CtrlEnH) mod_en_h          <- mkReg(defaultValue);
    Reg#(CtrlResetL) mod_reset_l    <- mkReg(defaultValue);
    Reg#(CtrlResetH) mod_reset_h    <- mkReg(defaultValue);
    Reg#(CtrlLpmodeL) mod_lpmode_l  <- mkReg(defaultValue);
    Reg#(CtrlLpmodeH) mod_lpmode_h  <- mkReg(defaultValue);

    // opting to register these since there will be a lot of fan out
    ConfigReg#(Bit#(8)) mod_write_addr    <- mkConfigReg(0);
    ConfigReg#(Bit#(8)) mod_write_data    <- mkConfigReg(0);
    Reg#(Bool) issue_write          <- mkDReg(False);

    Vector#(16, Bool) i2c_broadcast_enabled = unpack({unpack(pack(i2c_bcast_h)), unpack(pack(i2c_bcast_l))});
    Vector#(16, Reg#(Bit#(4))) i2c_errors_r <- replicateM(mkReg(0));

    // Vectorize all the low speed module signals
    Vector#(16, Bit#(1)) enable_bits = unpack({pack(mod_en_h), pack(mod_en_l)});
    Vector#(16, Bit#(1)) reset_bits = unpack({pack(mod_reset_h), pack(mod_reset_l)});
    Vector#(16, Bit#(1)) lpmode_bits = unpack({pack(mod_lpmode_h), pack(mod_lpmode_l)});
    Vector#(16, Bit#(1)) pg_bits;
    Vector#(16, Bit#(1)) pg_timeout_bits;
    Vector#(16, Bit#(1)) present_bits;
    Vector#(16, Bit#(1)) irq_bits;

    // Vectorize I2C status signals
    Vector#(16, Bit#(1)) i2c_busys;
    Vector#(16, Bit#(8)) i2c_status;

    for (int i = 0; i < 16; i = i + 1) begin
        // map registers into modules
        mkConnection(qsfp_ports[i].enable, enable_bits[i]);
        mkConnection(qsfp_ports[i].reset_, reset_bits[i]);
        mkConnection(qsfp_ports[i].lpmode, lpmode_bits[i]);

        // map modules into registers
        pg_bits[i]          = qsfp_ports[i].pg;
        pg_timeout_bits[i]  = qsfp_ports[i].pg_timeout;
        present_bits[i]     = qsfp_ports[i].present;
        irq_bits[i]         = qsfp_ports[i].irq;
        i2c_busys[i]        = qsfp_ports[i].i2c_busy;
        i2c_status[i]       = {3'h0, qsfp_ports[i].i2c_busy, i2c_errors_r[i]};
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

    // Since the error register is somewhat derived at this layer it needs to
    // be registered for persistence. It will also stay present until the next
    // I2C transaction starts on the port.
    (* fire_when_enabled *)
    rule do_i2c_error_regs;
        for (int i = 0; i < 16; i = i + 1) begin
            if (i2c_ctrl.start == 1 && i2c_broadcast_enabled[i]) begin
                i2c_errors_r[i] <= 0;
            end else if (isValid(qsfp_ports[i].i2c_error)) begin
                // The I2CCore::Error enum packs down to a single bit currently, but
                // a 3-bit wide field is reserved for it.
                let error_type = {2'b00, pack(fromMaybe(?, qsfp_ports[i].i2c_error))};
                i2c_errors_r[i] <= {1'b1, error_type};
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
                qsfp_ports[i].i2c_write_data.put(RamWrite { data: mod_write_data,
                                                address: mod_write_addr });
        end
    endrule

    interface Registers registers;
        interface Reg i2c_bus_addr = i2c_bus_addr;
        interface Reg i2c_reg_addr = i2c_reg_addr;
        interface Reg i2c_num_bytes = i2c_num_bytes;
        interface Reg i2c_bcast_l = i2c_bcast_l;
        interface Reg i2c_bcast_h = i2c_bcast_h;
        interface Reg i2c_ctrl = i2c_ctrl;
        interface ReadOnly i2c_busy_l = valueToReadOnly(unpack(pack(i2c_busys)[7:0]));
        interface ReadOnly i2c_busy_h = valueToReadOnly(unpack(pack(i2c_busys)[15:8]));
        interface ReadOnly i2c_status_port0 = valueToReadOnly(unpack(i2c_status[0]));
        interface ReadOnly i2c_status_port1 = valueToReadOnly(unpack(i2c_status[1]));
        interface ReadOnly i2c_status_port2 = valueToReadOnly(unpack(i2c_status[2]));
        interface ReadOnly i2c_status_port3 = valueToReadOnly(unpack(i2c_status[3]));
        interface ReadOnly i2c_status_port4 = valueToReadOnly(unpack(i2c_status[4]));
        interface ReadOnly i2c_status_port5 = valueToReadOnly(unpack(i2c_status[5]));
        interface ReadOnly i2c_status_port6 = valueToReadOnly(unpack(i2c_status[6]));
        interface ReadOnly i2c_status_port7 = valueToReadOnly(unpack(i2c_status[7]));
        interface ReadOnly i2c_status_port8 = valueToReadOnly(unpack(i2c_status[8]));
        interface ReadOnly i2c_status_port9 = valueToReadOnly(unpack(i2c_status[9]));
        interface ReadOnly i2c_status_port10 = valueToReadOnly(unpack(i2c_status[10]));
        interface ReadOnly i2c_status_port11 = valueToReadOnly(unpack(i2c_status[11]));
        interface ReadOnly i2c_status_port12 = valueToReadOnly(unpack(i2c_status[12]));
        interface ReadOnly i2c_status_port13 = valueToReadOnly(unpack(i2c_status[13]));
        interface ReadOnly i2c_status_port14 = valueToReadOnly(unpack(i2c_status[14]));
        interface ReadOnly i2c_status_port15 = valueToReadOnly(unpack(i2c_status[15]));
        interface Reg mod_en_l = mod_en_l;
        interface Reg mod_en_h = mod_en_h;
        interface Reg mod_reset_l = mod_reset_l;
        interface Reg mod_reset_h = mod_reset_h;
        interface Reg mod_lpmode_l = mod_lpmode_l;
        interface Reg mod_lpmode_h = mod_lpmode_h;
        interface ReadOnly mod_pg_l = valueToReadOnly(unpack(pack(pg_bits)[7:0]));
        interface ReadOnly mod_pg_h = valueToReadOnly(unpack(pack(pg_bits)[15:8]));
        interface ReadOnly mod_pg_timeout_l = valueToReadOnly(unpack(pack(pg_timeout_bits)[7:0]));
        interface ReadOnly mod_pg_timeout_h = valueToReadOnly(unpack(pack(pg_timeout_bits)[15:8]));
        interface ReadOnly mod_present_l = valueToReadOnly(unpack(pack(present_bits)[7:0]));
        interface ReadOnly mod_present_h = valueToReadOnly(unpack(pack(present_bits)[15:8]));
        interface ReadOnly mod_irq_l = valueToReadOnly(unpack(pack(irq_bits)[7:0]));
        interface ReadOnly mod_irq_h = valueToReadOnly(unpack(pack(irq_bits)[15:8]));
        interface mod_read_addrs = map(QsfpModuleController::get_read_addr, qsfp_ports);
        interface mod_read_buffers = map(QsfpModuleController::get_read_data, qsfp_ports);

        // addr and data are written in the same cycle in the SpiServer anyway,
        // so arbitrarily choose to pulse issue_write here versus in mod_write_data
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
endmodule

endpackage: QsfpModulesTop
