// Copyright 2022 Oxide Computer Company
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package QsfpX32ControllerSpiServer;

import ClientServer::*;
import ConfigReg::*;
import DefaultValue::*;
import GetPut::*;
import Vector::*;

import CommonInterfaces::*;
import RegCommon::*;

import QsfpModulesTop::*;
import QsfpX32ControllerTopRegs::*;
import QsfpX32ControllerRegsPkg::*;
import VSC8562::*;

typedef RegRequest#(16, 8) SpiRequest;
typedef RegResp#(8) SpiResponse;

typedef Server#(SpiRequest, SpiResponse) SpiServer;

module mkSpiServer #(VSC8562::Registers vsc8562,
                    QsfpX32ControllerTopRegs::Registers top,
                    QsfpModulesTop::Registers qsfp_top) (SpiServer);
    Reg#(SpiRequest) spi_request   <- mkReg(SpiRequest{address: 0, wdata: 0, op: NOOP});
    Wire#(SpiResponse) spi_response <- mkWire();

    ConfigReg#(Scratchpad) scratchpad   <- mkConfigReg(defaultValue);

    Vector#(4, ConfigReg#(ChecksumScratchpad0)) checksum
        <- replicateM(mkConfigReg(defaultValue));

    PulseWire start_request    <- mkPulseWire();
    Reg#(Vector#(3, Bit#(1))) read_dly     <- mkReg(replicate(0));
    Reg#(Vector#(1, Bit#(1))) write_dly    <- mkReg(replicate(0));

    (* fire_when_enabled *)
    rule do_request_delays;
        read_dly    <= shiftInAt0(read_dly, pack(start_request));
        write_dly   <= shiftInAt0(write_dly, pack(start_request));
    endrule

    (* fire_when_enabled *)
    rule do_spi_read ((spi_request.op == READ || spi_request.op == READ_NO_ADDR_INCR)
                        && unpack(last(read_dly)));
        let reader = 
            case (spi_request.address)
                fromInteger(id0Offset): read(Id0'(defaultValue));
                fromInteger(id1Offset): read(Id1'(defaultValue));
                fromInteger(id2Offset): read(Id2'(defaultValue));
                fromInteger(id3Offset): read(Id3'(defaultValue));
                fromInteger(checksumScratchpad0Offset): read(checksum[0]);
                fromInteger(checksumScratchpad1Offset): read(checksum[1]);
                fromInteger(checksumScratchpad2Offset): read(checksum[2]);
                fromInteger(checksumScratchpad3Offset): read(checksum[3]);
                fromInteger(scratchpadOffset): read(scratchpad);

                fromInteger(fpgaIdOffset): read(top.fpga_app_id);
                fromInteger(ledCtrlOffset): read(top.led_ctrl);
                fromInteger(fpgaBoardVerOffset): read(top.fpga_board_ver);

                fromInteger(vsc8562PhyStatusOffset): read(vsc8562.phy_status);
                fromInteger(vsc8562PhyCtrlOffset): read(vsc8562.phy_ctrl);
                fromInteger(vsc8562PhyOscOffset): read(vsc8562.phy_osc);
                fromInteger(vsc8562PhySmiStatusOffset): read(vsc8562.phy_smi_status);
                fromInteger(vsc8562PhySmiRdata0Offset): read(vsc8562.phy_smi_rdata0);
                fromInteger(vsc8562PhySmiRdata1Offset): read(vsc8562.phy_smi_rdata1);
                fromInteger(vsc8562PhySmiWdata0Offset): read(vsc8562.phy_smi_wdata0);
                fromInteger(vsc8562PhySmiWdata1Offset): read(vsc8562.phy_smi_wdata1);
                fromInteger(vsc8562PhySmiPhyAddrOffset): read(vsc8562.phy_smi_phy_addr);
                fromInteger(vsc8562PhySmiRegAddrOffset): read(vsc8562.phy_smi_reg_addr);
                fromInteger(vsc8562PhySmiCtrlOffset): read(vsc8562.phy_smi_ctrl);
                fromInteger(vsc8562PhyRailStatesOffset): read(vsc8562.phy_rail_states);

                fromInteger(qsfpI2cBusAddrOffset): read(qsfp_top.i2c_bus_addr);
                fromInteger(qsfpI2cRegAddrOffset): read(qsfp_top.i2c_reg_addr);
                fromInteger(qsfpI2cNumBytesOffset): read(qsfp_top.i2c_num_bytes);
                fromInteger(qsfpI2cBcast0Offset): read(qsfp_top.i2c_bcast0);
                fromInteger(qsfpI2cBcast1Offset): read(qsfp_top.i2c_bcast1);
                fromInteger(qsfpI2cBusy0Offset): read(qsfp_top.i2c_busy0);
                fromInteger(qsfpI2cBusy1Offset): read(qsfp_top.i2c_busy1);
                fromInteger(qsfpPort0StatusOffset): read(qsfp_top.mod_statuses[0]);
                fromInteger(qsfpPort1StatusOffset): read(qsfp_top.mod_statuses[1]);
                fromInteger(qsfpPort2StatusOffset): read(qsfp_top.mod_statuses[2]);
                fromInteger(qsfpPort3StatusOffset): read(qsfp_top.mod_statuses[3]);
                fromInteger(qsfpPort4StatusOffset): read(qsfp_top.mod_statuses[4]);
                fromInteger(qsfpPort5StatusOffset): read(qsfp_top.mod_statuses[5]);
                fromInteger(qsfpPort6StatusOffset): read(qsfp_top.mod_statuses[6]);
                fromInteger(qsfpPort7StatusOffset): read(qsfp_top.mod_statuses[7]);
                fromInteger(qsfpPort8StatusOffset): read(qsfp_top.mod_statuses[8]);
                fromInteger(qsfpPort9StatusOffset): read(qsfp_top.mod_statuses[9]);
                fromInteger(qsfpPort10StatusOffset): read(qsfp_top.mod_statuses[10]);
                fromInteger(qsfpPort11StatusOffset): read(qsfp_top.mod_statuses[11]);
                fromInteger(qsfpPort12StatusOffset): read(qsfp_top.mod_statuses[12]);
                fromInteger(qsfpPort13StatusOffset): read(qsfp_top.mod_statuses[13]);
                fromInteger(qsfpPort14StatusOffset): read(qsfp_top.mod_statuses[14]);
                fromInteger(qsfpPort15StatusOffset): read(qsfp_top.mod_statuses[15]);
                fromInteger(qsfpPort0ControlOffset): read(qsfp_top.mod_controls[0]);
                fromInteger(qsfpPort1ControlOffset): read(qsfp_top.mod_controls[1]);
                fromInteger(qsfpPort2ControlOffset): read(qsfp_top.mod_controls[2]);
                fromInteger(qsfpPort3ControlOffset): read(qsfp_top.mod_controls[3]);
                fromInteger(qsfpPort4ControlOffset): read(qsfp_top.mod_controls[4]);
                fromInteger(qsfpPort5ControlOffset): read(qsfp_top.mod_controls[5]);
                fromInteger(qsfpPort6ControlOffset): read(qsfp_top.mod_controls[6]);
                fromInteger(qsfpPort7ControlOffset): read(qsfp_top.mod_controls[7]);
                fromInteger(qsfpPort8ControlOffset): read(qsfp_top.mod_controls[8]);
                fromInteger(qsfpPort9ControlOffset): read(qsfp_top.mod_controls[9]);
                fromInteger(qsfpPort10ControlOffset): read(qsfp_top.mod_controls[10]);
                fromInteger(qsfpPort11ControlOffset): read(qsfp_top.mod_controls[11]);
                fromInteger(qsfpPort12ControlOffset): read(qsfp_top.mod_controls[12]);
                fromInteger(qsfpPort13ControlOffset): read(qsfp_top.mod_controls[13]);
                fromInteger(qsfpPort14ControlOffset): read(qsfp_top.mod_controls[14]);
                fromInteger(qsfpPort15ControlOffset): read(qsfp_top.mod_controls[15]);
                fromInteger(qsfpI2cCtrlOffset): read(qsfp_top.i2c_ctrl);
                fromInteger(qsfpPowerEn0Offset): read(qsfp_top.power_en0);
                fromInteger(qsfpPowerEn1Offset): read(qsfp_top.power_en1);
                fromInteger(qsfpPowerGood0Offset): read(qsfp_top.power_good0);
                fromInteger(qsfpPowerGood1Offset): read(qsfp_top.power_good1);
                fromInteger(qsfpPowerGoodTimeout0Offset): read(qsfp_top.power_good_timeout0);
                fromInteger(qsfpPowerGoodTimeout1Offset): read(qsfp_top.power_good_timeout1);
                fromInteger(qsfpPowerGoodLost0Offset): read(qsfp_top.power_good_lost0);
                fromInteger(qsfpPowerGoodLost1Offset): read(qsfp_top.power_good_lost1);
                fromInteger(qsfpModResetl0Offset): read(qsfp_top.mod_resetl0);
                fromInteger(qsfpModResetl1Offset): read(qsfp_top.mod_resetl1);
                fromInteger(qsfpModLpmode0Offset): read(qsfp_top.mod_lpmode0);
                fromInteger(qsfpModLpmode1Offset): read(qsfp_top.mod_lpmode1);
                fromInteger(qsfpModModprsl0Offset): read(qsfp_top.mod_modprsl0);
                fromInteger(qsfpModModprsl1Offset): read(qsfp_top.mod_modprsl1);
                fromInteger(qsfpModIntl0Offset): read(qsfp_top.mod_intl0);
                fromInteger(qsfpModIntl1Offset): read(qsfp_top.mod_intl1);
                fromInteger(qsfpPort0I2cDataOffset): read_volatile(qsfp_top.mod_i2c_data[0]);
                fromInteger(qsfpPort1I2cDataOffset): read_volatile(qsfp_top.mod_i2c_data[1]);
                fromInteger(qsfpPort2I2cDataOffset): read_volatile(qsfp_top.mod_i2c_data[2]);
                fromInteger(qsfpPort3I2cDataOffset): read_volatile(qsfp_top.mod_i2c_data[3]);
                fromInteger(qsfpPort4I2cDataOffset): read_volatile(qsfp_top.mod_i2c_data[4]);
                fromInteger(qsfpPort5I2cDataOffset): read_volatile(qsfp_top.mod_i2c_data[5]);
                fromInteger(qsfpPort6I2cDataOffset): read_volatile(qsfp_top.mod_i2c_data[6]);
                fromInteger(qsfpPort7I2cDataOffset): read_volatile(qsfp_top.mod_i2c_data[7]);
                fromInteger(qsfpPort8I2cDataOffset): read_volatile(qsfp_top.mod_i2c_data[8]);
                fromInteger(qsfpPort9I2cDataOffset): read_volatile(qsfp_top.mod_i2c_data[9]);
                fromInteger(qsfpPort10I2cDataOffset): read_volatile(qsfp_top.mod_i2c_data[10]);
                fromInteger(qsfpPort11I2cDataOffset): read_volatile(qsfp_top.mod_i2c_data[11]);
                fromInteger(qsfpPort12I2cDataOffset): read_volatile(qsfp_top.mod_i2c_data[12]);
                fromInteger(qsfpPort13I2cDataOffset): read_volatile(qsfp_top.mod_i2c_data[13]);
                fromInteger(qsfpPort14I2cDataOffset): read_volatile(qsfp_top.mod_i2c_data[14]);
                fromInteger(qsfpPort15I2cDataOffset): read_volatile(qsfp_top.mod_i2c_data[15]);

                default: read(8'hff);
            endcase;

        let data <- reader;

        spi_response    <= data;
    endrule

    rule do_spi_write(unpack(last(write_dly)));
        case (spi_request.address)
            fromInteger(checksumScratchpad0Offset):
                update(spi_request.op, checksum[0], spi_request.wdata);
            fromInteger(checksumScratchpad1Offset):
                update(spi_request.op, checksum[1], spi_request.wdata);
            fromInteger(checksumScratchpad2Offset):
                update(spi_request.op, checksum[2], spi_request.wdata);
            fromInteger(checksumScratchpad3Offset):
                update(spi_request.op, checksum[3], spi_request.wdata);
            fromInteger(scratchpadOffset):
                update(spi_request.op, scratchpad, spi_request.wdata);
            fromInteger(ledCtrlOffset):
                update(spi_request.op, top.led_ctrl, spi_request.wdata);
            fromInteger(vsc8562PhyCtrlOffset):
                update(spi_request.op, vsc8562.phy_ctrl, spi_request.wdata);
            fromInteger(vsc8562PhyOscOffset):
                update(spi_request.op, vsc8562.phy_osc, spi_request.wdata);
            fromInteger(vsc8562PhySmiWdata1Offset):
                update(spi_request.op, vsc8562.phy_smi_wdata1, spi_request.wdata);
            fromInteger(vsc8562PhySmiWdata0Offset):
                update(spi_request.op, vsc8562.phy_smi_wdata0, spi_request.wdata);
            fromInteger(vsc8562PhySmiPhyAddrOffset):
                update(spi_request.op, vsc8562.phy_smi_phy_addr, spi_request.wdata);
            fromInteger(vsc8562PhySmiRegAddrOffset):
                update(spi_request.op, vsc8562.phy_smi_reg_addr, spi_request.wdata);
            fromInteger(vsc8562PhySmiCtrlOffset):
                update(spi_request.op, vsc8562.phy_smi_ctrl, spi_request.wdata);
            fromInteger(qsfpI2cBusAddrOffset):
                update(spi_request.op, qsfp_top.i2c_bus_addr, spi_request.wdata);
            fromInteger(qsfpI2cRegAddrOffset):
                update(spi_request.op, qsfp_top.i2c_reg_addr, spi_request.wdata);
            fromInteger(qsfpI2cNumBytesOffset):
                update(spi_request.op, qsfp_top.i2c_num_bytes, spi_request.wdata);
            fromInteger(qsfpI2cBcast1Offset):
                update(spi_request.op, qsfp_top.i2c_bcast1, spi_request.wdata);
            fromInteger(qsfpI2cBcast0Offset):
                update(spi_request.op, qsfp_top.i2c_bcast0, spi_request.wdata);
            fromInteger(qsfpI2cCtrlOffset):
                update(spi_request.op, qsfp_top.i2c_ctrl, spi_request.wdata);
            fromInteger(qsfpPowerEn0Offset):
                update(spi_request.op, qsfp_top.power_en0, spi_request.wdata);
            fromInteger(qsfpPowerEn1Offset):
                update(spi_request.op, qsfp_top.power_en1, spi_request.wdata);
            fromInteger(qsfpModResetl0Offset):
                update(spi_request.op, qsfp_top.mod_resetl0, spi_request.wdata);
            fromInteger(qsfpModResetl1Offset):
                update(spi_request.op, qsfp_top.mod_resetl1, spi_request.wdata);
            fromInteger(qsfpModLpmode0Offset):
                update(spi_request.op, qsfp_top.mod_lpmode0, spi_request.wdata);
            fromInteger(qsfpModLpmode1Offset):
                update(spi_request.op, qsfp_top.mod_lpmode1, spi_request.wdata);
            fromInteger(qsfpPort0ControlOffset):
                update(spi_request.op, qsfp_top.mod_controls[0], spi_request.wdata);
            fromInteger(qsfpPort1ControlOffset):
                update(spi_request.op, qsfp_top.mod_controls[1], spi_request.wdata);
            fromInteger(qsfpPort2ControlOffset):
                update(spi_request.op, qsfp_top.mod_controls[2], spi_request.wdata);
            fromInteger(qsfpPort3ControlOffset):
                update(spi_request.op, qsfp_top.mod_controls[3], spi_request.wdata);
            fromInteger(qsfpPort4ControlOffset):
                update(spi_request.op, qsfp_top.mod_controls[4], spi_request.wdata);
            fromInteger(qsfpPort5ControlOffset):
                update(spi_request.op, qsfp_top.mod_controls[5], spi_request.wdata);
            fromInteger(qsfpPort6ControlOffset):
                update(spi_request.op, qsfp_top.mod_controls[6], spi_request.wdata);
            fromInteger(qsfpPort7ControlOffset):
                update(spi_request.op, qsfp_top.mod_controls[7], spi_request.wdata);
            fromInteger(qsfpPort8ControlOffset):
                update(spi_request.op, qsfp_top.mod_controls[8], spi_request.wdata);
            fromInteger(qsfpPort9ControlOffset):
                update(spi_request.op, qsfp_top.mod_controls[9], spi_request.wdata);
            fromInteger(qsfpPort10ControlOffset):
                update(spi_request.op, qsfp_top.mod_controls[10], spi_request.wdata);
            fromInteger(qsfpPort11ControlOffset):
                update(spi_request.op, qsfp_top.mod_controls[11], spi_request.wdata);
            fromInteger(qsfpPort12ControlOffset):
                update(spi_request.op, qsfp_top.mod_controls[12], spi_request.wdata);
            fromInteger(qsfpPort13ControlOffset):
                update(spi_request.op, qsfp_top.mod_controls[13], spi_request.wdata);
            fromInteger(qsfpPort14ControlOffset):
                update(spi_request.op, qsfp_top.mod_controls[14], spi_request.wdata);
            fromInteger(qsfpPort15ControlOffset):
                update(spi_request.op, qsfp_top.mod_controls[15], spi_request.wdata);
            fromInteger(qsfpPort0I2cDataOffset):
                write(spi_request.op, qsfp_top.mod_i2c_data[0]._write, spi_request.wdata);
            fromInteger(qsfpPort1I2cDataOffset):
                write(spi_request.op, qsfp_top.mod_i2c_data[1]._write, spi_request.wdata);
            fromInteger(qsfpPort2I2cDataOffset):
                write(spi_request.op, qsfp_top.mod_i2c_data[2]._write, spi_request.wdata);
            fromInteger(qsfpPort3I2cDataOffset):
                write(spi_request.op, qsfp_top.mod_i2c_data[3]._write, spi_request.wdata);
            fromInteger(qsfpPort4I2cDataOffset):
                write(spi_request.op, qsfp_top.mod_i2c_data[4]._write, spi_request.wdata);
            fromInteger(qsfpPort5I2cDataOffset):
                write(spi_request.op, qsfp_top.mod_i2c_data[5]._write, spi_request.wdata);
            fromInteger(qsfpPort6I2cDataOffset):
                write(spi_request.op, qsfp_top.mod_i2c_data[6]._write, spi_request.wdata);
            fromInteger(qsfpPort7I2cDataOffset):
                write(spi_request.op, qsfp_top.mod_i2c_data[7]._write, spi_request.wdata);
            fromInteger(qsfpPort8I2cDataOffset):
                write(spi_request.op, qsfp_top.mod_i2c_data[8]._write, spi_request.wdata);
            fromInteger(qsfpPort9I2cDataOffset):
                write(spi_request.op, qsfp_top.mod_i2c_data[9]._write, spi_request.wdata);
            fromInteger(qsfpPort10I2cDataOffset):
                write(spi_request.op, qsfp_top.mod_i2c_data[10]._write, spi_request.wdata);
            fromInteger(qsfpPort11I2cDataOffset):
                write(spi_request.op, qsfp_top.mod_i2c_data[11]._write, spi_request.wdata);
            fromInteger(qsfpPort12I2cDataOffset):
                write(spi_request.op, qsfp_top.mod_i2c_data[12]._write, spi_request.wdata);
            fromInteger(qsfpPort13I2cDataOffset):
                write(spi_request.op, qsfp_top.mod_i2c_data[13]._write, spi_request.wdata);
            fromInteger(qsfpPort14I2cDataOffset):
                write(spi_request.op, qsfp_top.mod_i2c_data[14]._write, spi_request.wdata);
            fromInteger(qsfpPort15I2cDataOffset):
                write(spi_request.op, qsfp_top.mod_i2c_data[15]._write, spi_request.wdata);
        endcase
    endrule 

    interface Put request;
        method Action put(new_spi_request);
            start_request.send();
            spi_request <= new_spi_request;
        endmethod
    endinterface
    interface Get response = toGet(asIfc(spi_response));
endmodule

// Turn the read of a register into an ActionValue.
function ActionValue#(SpiResponse) read(t v)
        provisos (Bits#(t, 8));
    return actionvalue
        return SpiResponse {readdata: pack(v)};
    endactionvalue;
endfunction

function ActionValue#(SpiResponse) read_volatile(ActionValue#(t) av)
        provisos (Bits#(t, 8));
    return actionvalue
        let v <- av;
        return SpiResponse {readdata: pack(v)};
    endactionvalue;
endfunction

function Action update(RegOps op, Reg#(t) r, Bit#(8) data)
        provisos (Bits#(t, 8));
    return action
        let r_ = zeroExtend(pack(r));

        case (op)
            WRITE: r <= unpack(truncate(data));
            WRITE_NO_ADDR_INCR: r <= unpack(truncate(data));
            BITSET: r <= unpack(truncate(r_ | data));
            BITCLEAR: r <= unpack(truncate(r_ & ~data));
        endcase
    endaction;
endfunction

function Action write(RegOps op, function Action f(t val), Bit#(8) data)
        provisos (Bits#(t, 8));
    return action
        if (op == WRITE || op == WRITE_NO_ADDR_INCR) f(unpack(truncate(data)));
    endaction;
endfunction

endpackage: QsfpX32ControllerSpiServer
