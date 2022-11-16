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

import RegCommon::*;

import QsfpModulesTop::*;
import QsfpX32ControllerTopRegs::*;
import QsfpX32ControllerRegsPkg::*;
import VSC8562::*;

typedef RegRequest#(16, 8) SpiRequest;
typedef RegResp#(8) SpiResponse;

typedef Server#(SpiRequest, SpiResponse) SpiServer;

// helper to get an actual BRAM address from a request address
function Bit#(8) getBRAMAddr(Bit#(16) request_addr, Integer memOffset);
    UInt#(16) offset = fromInteger(memOffset);
    return truncate(pack(unpack(request_addr) - offset));
endfunction

function Bool isBetween(Bit#(16) request_addr, Integer base, Integer offset);
    Bit#(16) first = fromInteger(base);
    Bit#(16) last = fromInteger(base + offset - 1);
    return (request_addr >= first) && (request_addr <= last);
endfunction

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
    rule do_spi_read_dly (spi_request.op == READ && unpack(|pack(read_dly)));
        if (isBetween(spi_request.address, qsfpPort0ReadBufferOffset, readBufferNumEntries)) begin
            qsfp_top.mod_read_addrs[0]   <= getBRAMAddr(spi_request.address, qsfpPort0ReadBufferOffset);
        end else if (isBetween(spi_request.address, qsfpPort1ReadBufferOffset, readBufferNumEntries)) begin
            qsfp_top.mod_read_addrs[1]   <= getBRAMAddr(spi_request.address, qsfpPort1ReadBufferOffset);
        end else if (isBetween(spi_request.address, qsfpPort2ReadBufferOffset, readBufferNumEntries)) begin
            qsfp_top.mod_read_addrs[2]   <= getBRAMAddr(spi_request.address, qsfpPort2ReadBufferOffset);
        end else if (isBetween(spi_request.address, qsfpPort3ReadBufferOffset, readBufferNumEntries)) begin
            qsfp_top.mod_read_addrs[3]   <= getBRAMAddr(spi_request.address, qsfpPort3ReadBufferOffset);
        end else if (isBetween(spi_request.address, qsfpPort4ReadBufferOffset, readBufferNumEntries)) begin
            qsfp_top.mod_read_addrs[4]   <= getBRAMAddr(spi_request.address, qsfpPort4ReadBufferOffset);
        end else if (isBetween(spi_request.address, qsfpPort5ReadBufferOffset, readBufferNumEntries)) begin
            qsfp_top.mod_read_addrs[5]   <= getBRAMAddr(spi_request.address, qsfpPort5ReadBufferOffset);
        end else if (isBetween(spi_request.address, qsfpPort6ReadBufferOffset, readBufferNumEntries)) begin
            qsfp_top.mod_read_addrs[6]   <= getBRAMAddr(spi_request.address, qsfpPort6ReadBufferOffset);
        end else if (isBetween(spi_request.address, qsfpPort7ReadBufferOffset, readBufferNumEntries)) begin
            qsfp_top.mod_read_addrs[7]   <= getBRAMAddr(spi_request.address, qsfpPort7ReadBufferOffset);
        end else if (isBetween(spi_request.address, qsfpPort8ReadBufferOffset, readBufferNumEntries)) begin
            qsfp_top.mod_read_addrs[8]   <= getBRAMAddr(spi_request.address, qsfpPort8ReadBufferOffset);
        end else if (isBetween(spi_request.address, qsfpPort9ReadBufferOffset, readBufferNumEntries)) begin
            qsfp_top.mod_read_addrs[9]   <= getBRAMAddr(spi_request.address, qsfpPort9ReadBufferOffset);
        end else if (isBetween(spi_request.address, qsfpPort10ReadBufferOffset, readBufferNumEntries)) begin
            qsfp_top.mod_read_addrs[10]   <= getBRAMAddr(spi_request.address, qsfpPort10ReadBufferOffset);
        end else if (isBetween(spi_request.address, qsfpPort11ReadBufferOffset, readBufferNumEntries)) begin
            qsfp_top.mod_read_addrs[11]   <= getBRAMAddr(spi_request.address, qsfpPort11ReadBufferOffset);
        end  else if (isBetween(spi_request.address, qsfpPort12ReadBufferOffset, readBufferNumEntries)) begin
            qsfp_top.mod_read_addrs[12]   <= getBRAMAddr(spi_request.address, qsfpPort12ReadBufferOffset);
        end else if (isBetween(spi_request.address, qsfpPort13ReadBufferOffset, readBufferNumEntries)) begin
            qsfp_top.mod_read_addrs[13]   <= getBRAMAddr(spi_request.address, qsfpPort13ReadBufferOffset);
        end else if (isBetween(spi_request.address, qsfpPort14ReadBufferOffset, readBufferNumEntries)) begin
            qsfp_top.mod_read_addrs[14]   <= getBRAMAddr(spi_request.address, qsfpPort14ReadBufferOffset);
        end else if (isBetween(spi_request.address, qsfpPort15ReadBufferOffset, readBufferNumEntries)) begin
            qsfp_top.mod_read_addrs[15]   <= getBRAMAddr(spi_request.address, qsfpPort15ReadBufferOffset);
        end
    endrule

    (* fire_when_enabled *)
    rule do_spi_read (spi_request.op == READ && unpack(last(read_dly)));
        Bit#(8) ret_byte;
        if (spi_request.address == fromInteger(id0Offset)) begin
            ret_byte = 'h01;
        end else if (spi_request.address == fromInteger(id1Offset)) begin
            ret_byte = 'hde;
        end else if (spi_request.address == fromInteger(id2Offset)) begin
            ret_byte = 'haa;
        end else if (spi_request.address == fromInteger(id3Offset)) begin
            ret_byte = 'h55;
        end else if (spi_request.address == fromInteger(checksumScratchpad0Offset)) begin
            ret_byte = pack(checksum[0]);
        end else if (spi_request.address == fromInteger(checksumScratchpad1Offset)) begin
            ret_byte = pack(checksum[1]);
        end else if (spi_request.address == fromInteger(checksumScratchpad2Offset)) begin
            ret_byte = pack(checksum[2]);
        end else if (spi_request.address == fromInteger(checksumScratchpad3Offset)) begin
            ret_byte = pack(checksum[3]);
        end else if (spi_request.address == fromInteger(scratchpadOffset)) begin
            ret_byte = pack(scratchpad);
        end else if (spi_request.address == fromInteger(fpgaIdOffset)) begin
            ret_byte = pack(top.fpga_app_id);
        end else if (spi_request.address == fromInteger(ledCtrlOffset)) begin
            ret_byte = pack(top.led_ctrl);
        end else if (spi_request.address == fromInteger(vsc8562PhyStatusOffset)) begin
            ret_byte = pack(vsc8562.phy_status);
        end else if (spi_request.address == fromInteger(vsc8562PhyCtrlOffset)) begin
            ret_byte = pack(vsc8562.phy_ctrl);
        end else if (spi_request.address == fromInteger(vsc8562PhySmiStatusOffset)) begin
            ret_byte = pack(vsc8562.phy_smi_status);
        end else if (spi_request.address == fromInteger(vsc8562PhySmiRdataHOffset)) begin
            ret_byte = pack(vsc8562.phy_smi_rdata_h);
        end else if (spi_request.address == fromInteger(vsc8562PhySmiRdataLOffset)) begin
            ret_byte = pack(vsc8562.phy_smi_rdata_l);
        end else if (spi_request.address == fromInteger(vsc8562PhySmiWdataHOffset)) begin
            ret_byte = pack(vsc8562.phy_smi_wdata_h);
        end else if (spi_request.address == fromInteger(vsc8562PhySmiWdataLOffset)) begin
            ret_byte = pack(vsc8562.phy_smi_wdata_l);
        end else if (spi_request.address == fromInteger(vsc8562PhySmiPhyAddrOffset)) begin
            ret_byte = pack(vsc8562.phy_smi_phy_addr);
        end else if (spi_request.address == fromInteger(vsc8562PhySmiRegAddrOffset)) begin
            ret_byte = pack(vsc8562.phy_smi_reg_addr);
        end else if (spi_request.address == fromInteger(vsc8562PhySmiCtrlOffset)) begin
            ret_byte = pack(vsc8562.phy_smi_ctrl);
        end else if (spi_request.address == fromInteger(qsfpI2cBusAddrOffset)) begin
            ret_byte = pack(qsfp_top.i2c_bus_addr);
        end else if (spi_request.address == fromInteger(qsfpI2cRegAddrOffset)) begin
            ret_byte = pack(qsfp_top.i2c_reg_addr);
        end else if (spi_request.address == fromInteger(qsfpI2cNumBytesOffset)) begin
            ret_byte = pack(qsfp_top.i2c_num_bytes);
        end else if (spi_request.address == fromInteger(qsfpI2cBcastHOffset)) begin
            ret_byte = pack(qsfp_top.i2c_bcast_h);
        end else if (spi_request.address == fromInteger(qsfpI2cBcastLOffset)) begin
            ret_byte = pack(qsfp_top.i2c_bcast_l);
        end else if (spi_request.address == fromInteger(qsfpI2cBusyHOffset)) begin
            ret_byte = pack(qsfp_top.i2c_busy_h);
        end else if (spi_request.address == fromInteger(qsfpI2cBusyLOffset)) begin
            ret_byte = pack(qsfp_top.i2c_busy_l);
        end else if (spi_request.address == fromInteger(qsfpI2cError01Offset)) begin
            ret_byte = pack(qsfp_top.i2c_error_0_1);
        end else if (spi_request.address == fromInteger(qsfpI2cError23Offset)) begin
            ret_byte = pack(qsfp_top.i2c_error_2_3);
        end else if (spi_request.address == fromInteger(qsfpI2cError45Offset)) begin
            ret_byte = pack(qsfp_top.i2c_error_4_5);
        end else if (spi_request.address == fromInteger(qsfpI2cError67Offset)) begin
            ret_byte = pack(qsfp_top.i2c_error_6_7);
        end else if (spi_request.address == fromInteger(qsfpI2cError89Offset)) begin
            ret_byte = pack(qsfp_top.i2c_error_8_9);
        end else if (spi_request.address == fromInteger(qsfpI2cError1011Offset)) begin
            ret_byte = pack(qsfp_top.i2c_error_10_11);
        end else if (spi_request.address == fromInteger(qsfpI2cError1213Offset)) begin
            ret_byte = pack(qsfp_top.i2c_error_12_13);
        end else if (spi_request.address == fromInteger(qsfpI2cError1415Offset)) begin
            ret_byte = pack(qsfp_top.i2c_error_14_15);
        end else if (spi_request.address == fromInteger(qsfpI2cCtrlOffset)) begin
            ret_byte = pack(qsfp_top.i2c_ctrl);
        end else if (spi_request.address == fromInteger(qsfpCtrlEnHOffset)) begin
            ret_byte = pack(qsfp_top.mod_en_h);
        end else if (spi_request.address == fromInteger(qsfpCtrlEnLOffset)) begin
            ret_byte = pack(qsfp_top.mod_en_l);
        end else if (spi_request.address == fromInteger(qsfpCtrlResetHOffset)) begin
            ret_byte = pack(qsfp_top.mod_reset_h);
        end else if (spi_request.address == fromInteger(qsfpCtrlResetLOffset)) begin
            ret_byte = pack(qsfp_top.mod_reset_l);
        end else if (spi_request.address == fromInteger(qsfpCtrlLpmodeHOffset)) begin
            ret_byte = pack(qsfp_top.mod_lpmode_h);
        end else if (spi_request.address == fromInteger(qsfpCtrlLpmodeLOffset)) begin
            ret_byte = pack(qsfp_top.mod_lpmode_l);
        end else if (spi_request.address == fromInteger(qsfpStatusPgHOffset)) begin
            ret_byte = pack(qsfp_top.mod_pg_h);
        end else if (spi_request.address == fromInteger(qsfpStatusPgLOffset)) begin
            ret_byte = pack(qsfp_top.mod_pg_l);
        end else if (spi_request.address == fromInteger(qsfpStatusPgTimeoutHOffset)) begin
            ret_byte = pack(qsfp_top.mod_pg_timeout_h);
        end else if (spi_request.address == fromInteger(qsfpStatusPgTimeoutLOffset)) begin
            ret_byte = pack(qsfp_top.mod_pg_timeout_l);
        end else if (spi_request.address == fromInteger(qsfpStatusPresentHOffset)) begin
            ret_byte = pack(qsfp_top.mod_present_h);
        end else if (spi_request.address == fromInteger(qsfpStatusPresentLOffset)) begin
            ret_byte = pack(qsfp_top.mod_present_l);
        end else if (spi_request.address == fromInteger(qsfpStatusIrqHOffset)) begin
            ret_byte = pack(qsfp_top.mod_irq_h);
        end else if (spi_request.address == fromInteger(qsfpStatusIrqLOffset)) begin
            ret_byte = pack(qsfp_top.mod_irq_l);
        end else if (spi_request.address == fromInteger(qsfpPort0I2cStatusOffset)) begin
            ret_byte = pack(qsfp_top.mod_i2c_statuses[0]);
        end else if (isBetween(spi_request.address, qsfpPort0ReadBufferOffset, readBufferNumEntries)) begin
            ret_byte = pack(qsfp_top.mod_read_buffers[0]);
        end else if (spi_request.address == fromInteger(qsfpPort1I2cStatusOffset)) begin
            ret_byte = pack(qsfp_top.mod_i2c_statuses[1]);
        end else if (isBetween(spi_request.address, qsfpPort1ReadBufferOffset, readBufferNumEntries)) begin
            ret_byte = pack(qsfp_top.mod_read_buffers[1]);
        end else if (spi_request.address == fromInteger(qsfpPort2I2cStatusOffset)) begin
            ret_byte = pack(qsfp_top.mod_i2c_statuses[2]);
        end else if (isBetween(spi_request.address, qsfpPort2ReadBufferOffset, readBufferNumEntries)) begin
            ret_byte = pack(qsfp_top.mod_read_buffers[2]);
        end else if (spi_request.address == fromInteger(qsfpPort3I2cStatusOffset)) begin
            ret_byte = pack(qsfp_top.mod_i2c_statuses[3]);
        end else if (isBetween(spi_request.address, qsfpPort3ReadBufferOffset, readBufferNumEntries)) begin
            ret_byte = pack(qsfp_top.mod_read_buffers[3]);
        end else if (spi_request.address == fromInteger(qsfpPort4I2cStatusOffset)) begin
            ret_byte = pack(qsfp_top.mod_i2c_statuses[4]);
        end else if (isBetween(spi_request.address, qsfpPort4ReadBufferOffset, readBufferNumEntries)) begin
            ret_byte = pack(qsfp_top.mod_read_buffers[4]);
        end else if (spi_request.address == fromInteger(qsfpPort5I2cStatusOffset)) begin
            ret_byte = pack(qsfp_top.mod_i2c_statuses[5]);
        end else if (isBetween(spi_request.address, qsfpPort5ReadBufferOffset, readBufferNumEntries)) begin
            ret_byte = pack(qsfp_top.mod_read_buffers[5]);
        end else if (spi_request.address == fromInteger(qsfpPort6I2cStatusOffset)) begin
            ret_byte = pack(qsfp_top.mod_i2c_statuses[6]);
        end else if (isBetween(spi_request.address, qsfpPort6ReadBufferOffset, readBufferNumEntries)) begin
            ret_byte = pack(qsfp_top.mod_read_buffers[6]);
        end else if (spi_request.address == fromInteger(qsfpPort7I2cStatusOffset)) begin
            ret_byte = pack(qsfp_top.mod_i2c_statuses[7]);
        end else if (isBetween(spi_request.address, qsfpPort7ReadBufferOffset, readBufferNumEntries)) begin
            ret_byte = pack(qsfp_top.mod_read_buffers[7]);
        end else if (spi_request.address == fromInteger(qsfpPort8I2cStatusOffset)) begin
            ret_byte = pack(qsfp_top.mod_i2c_statuses[8]);
        end else if (isBetween(spi_request.address, qsfpPort8ReadBufferOffset, readBufferNumEntries)) begin
            ret_byte = pack(qsfp_top.mod_read_buffers[8]);
        end else if (spi_request.address == fromInteger(qsfpPort9I2cStatusOffset)) begin
            ret_byte = pack(qsfp_top.mod_i2c_statuses[9]);
        end else if (isBetween(spi_request.address, qsfpPort9ReadBufferOffset, readBufferNumEntries)) begin
            ret_byte = pack(qsfp_top.mod_read_buffers[9]);
        end else if (spi_request.address == fromInteger(qsfpPort10I2cStatusOffset)) begin
            ret_byte = pack(qsfp_top.mod_i2c_statuses[10]);
        end else if (isBetween(spi_request.address, qsfpPort10ReadBufferOffset, readBufferNumEntries)) begin
            ret_byte = pack(qsfp_top.mod_read_buffers[10]);
        end else if (spi_request.address == fromInteger(qsfpPort11I2cStatusOffset)) begin
            ret_byte = pack(qsfp_top.mod_i2c_statuses[11]);
        end else if (isBetween(spi_request.address, qsfpPort11ReadBufferOffset, readBufferNumEntries)) begin
            ret_byte = pack(qsfp_top.mod_read_buffers[11]);
        end else if (spi_request.address == fromInteger(qsfpPort12I2cStatusOffset)) begin
            ret_byte = pack(qsfp_top.mod_i2c_statuses[12]);
        end else if (isBetween(spi_request.address, qsfpPort12ReadBufferOffset, readBufferNumEntries)) begin
            ret_byte = pack(qsfp_top.mod_read_buffers[12]);
        end else if (spi_request.address == fromInteger(qsfpPort13I2cStatusOffset)) begin
            ret_byte = pack(qsfp_top.mod_i2c_statuses[13]);
        end else if (isBetween(spi_request.address, qsfpPort13ReadBufferOffset, readBufferNumEntries)) begin
            ret_byte = pack(qsfp_top.mod_read_buffers[13]);
        end else if (spi_request.address == fromInteger(qsfpPort14I2cStatusOffset)) begin
            ret_byte = pack(qsfp_top.mod_i2c_statuses[14]);
        end else if (isBetween(spi_request.address, qsfpPort14ReadBufferOffset, readBufferNumEntries)) begin
            ret_byte = pack(qsfp_top.mod_read_buffers[14]);
        end else if (spi_request.address == fromInteger(qsfpPort15I2cStatusOffset)) begin
            ret_byte = pack(qsfp_top.mod_i2c_statuses[15]);
        end else if (isBetween(spi_request.address, qsfpPort15ReadBufferOffset, readBufferNumEntries)) begin
            ret_byte = pack(qsfp_top.mod_read_buffers[15]);
        end else begin
            ret_byte = 'hff;
        end

        spi_response    <= SpiResponse{readdata: ret_byte};
    endrule

    // Helper which adds a rule updating the provided register if a SPI request
    // matches the given address.
    function Rules do_spi_write(Integer address, ConfigReg#(t) r)
            provisos (
                Bits#(t, sz),
                // Make sure the register type is <= 8 bits in width.
                Add#(sz, x, 8));
        return (rules
                (* fire_when_enabled *)
                rule do_spi_write (fromInteger(address) == spi_request.address && unpack(last(write_dly)));
                    // Make `r` and `wdata` equal length.
                    let r_bits = zeroExtend(pack(r));
                    let wdata_bits = pack(spi_request.wdata);

                    case (spi_request.op)
                        WRITE: r <= unpack(truncate(wdata_bits));
                        BITSET: r <= unpack(truncate(wdata_bits | r_bits));
                        BITCLEAR: r <= unpack(truncate(~wdata_bits & r_bits));
                    endcase
                endrule
            endrules);
    endfunction

    // Similar to the above helper, but for writing directly into a BRAM
    function Rules do_spi_bram_write(Integer base_address, Integer offset, ConfigReg#(Bit#(8)) r_data, ConfigReg#(Bit#(8)) r_addr);
        return (rules
                (* fire_when_enabled *)
                rule do_spi_write (isBetween(spi_request.address, base_address, offset) && unpack(last(write_dly)));
                    // Make `r` and `wdata` equal length.
                    let r_bits = zeroExtend(pack(r_data));
                    let wdata_bits = pack(spi_request.wdata);

                    case (spi_request.op)
                        WRITE: r_data <= unpack(truncate(wdata_bits));
                        BITSET: r_data <= unpack(truncate(wdata_bits | r_bits));
                        BITCLEAR: r_data <= unpack(truncate(~wdata_bits & r_bits));
                    endcase

                    r_addr  <= getBRAMAddr(spi_request.address, offset);
                endrule
            endrules);
    endfunction

    // Update registers on SPI requests.
    addRules(do_spi_write(checksumScratchpad0Offset, checksum[0]));
    addRules(do_spi_write(checksumScratchpad1Offset, checksum[1]));
    addRules(do_spi_write(checksumScratchpad2Offset, checksum[2]));
    addRules(do_spi_write(checksumScratchpad3Offset, checksum[3]));
    addRules(do_spi_write(scratchpadOffset, scratchpad));
    addRules(do_spi_write(ledCtrlOffset, top.led_ctrl));
    addRules(do_spi_write(vsc8562PhyCtrlOffset, vsc8562.phy_ctrl));
    addRules(do_spi_write(vsc8562PhySmiWdataHOffset, vsc8562.phy_smi_wdata_h));
    addRules(do_spi_write(vsc8562PhySmiWdataLOffset, vsc8562.phy_smi_wdata_l));
    addRules(do_spi_write(vsc8562PhySmiPhyAddrOffset, vsc8562.phy_smi_phy_addr));
    addRules(do_spi_write(vsc8562PhySmiRegAddrOffset, vsc8562.phy_smi_reg_addr));
    addRules(do_spi_write(vsc8562PhySmiCtrlOffset, vsc8562.phy_smi_ctrl));
    addRules(do_spi_write(qsfpI2cBusAddrOffset, qsfp_top.i2c_bus_addr));
    addRules(do_spi_write(qsfpI2cRegAddrOffset, qsfp_top.i2c_reg_addr));
    addRules(do_spi_write(qsfpI2cNumBytesOffset, qsfp_top.i2c_num_bytes));
    addRules(do_spi_write(qsfpI2cBcastHOffset, qsfp_top.i2c_bcast_h));
    addRules(do_spi_write(qsfpI2cBcastLOffset, qsfp_top.i2c_bcast_l));
    addRules(do_spi_write(qsfpI2cCtrlOffset, qsfp_top.i2c_ctrl));
    addRules(do_spi_write(qsfpCtrlEnHOffset, qsfp_top.mod_en_h));
    addRules(do_spi_write(qsfpCtrlEnLOffset, qsfp_top.mod_en_l));
    addRules(do_spi_write(qsfpCtrlResetHOffset, qsfp_top.mod_reset_h));
    addRules(do_spi_write(qsfpCtrlResetLOffset, qsfp_top.mod_reset_l));
    addRules(do_spi_write(qsfpCtrlLpmodeHOffset, qsfp_top.mod_lpmode_h));
    addRules(do_spi_write(qsfpCtrlLpmodeLOffset, qsfp_top.mod_lpmode_l));
    addRules(do_spi_bram_write(qsfpWriteBufferOffset, writeBufferNumEntries, qsfp_top.mod_write_data, qsfp_top.mod_write_addr));

    interface Put request;
        method Action put(new_spi_request);
            start_request.send();
            spi_request <= new_spi_request;
        endmethod
    endinterface
    interface Get response = toGet(asIfc(spi_response));
endmodule

endpackage: QsfpX32ControllerSpiServer
