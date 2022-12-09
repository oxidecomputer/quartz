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
        end else if (spi_request.address == fromInteger(qsfpI2cBcast0Offset)) begin
            ret_byte = pack(qsfp_top.i2c_bcast0);
        end else if (spi_request.address == fromInteger(qsfpI2cBcast1Offset)) begin
            ret_byte = pack(qsfp_top.i2c_bcast1);
        end else if (spi_request.address == fromInteger(qsfpI2cBusy0Offset)) begin
            ret_byte = pack(qsfp_top.i2c_busy0);
        end else if (spi_request.address == fromInteger(qsfpI2cBusy1Offset)) begin
            ret_byte = pack(qsfp_top.i2c_busy1);
        end else if (spi_request.address == fromInteger(qsfpStatusPort0Offset)) begin
            ret_byte = pack(qsfp_top.mod_statuses[0]);
        end else if (spi_request.address == fromInteger(qsfpStatusPort1Offset)) begin
            ret_byte = pack(qsfp_top.mod_statuses[1]);
        end else if (spi_request.address == fromInteger(qsfpStatusPort2Offset)) begin
            ret_byte = pack(qsfp_top.mod_statuses[2]);
        end else if (spi_request.address == fromInteger(qsfpStatusPort3Offset)) begin
            ret_byte = pack(qsfp_top.mod_statuses[3]);
        end else if (spi_request.address == fromInteger(qsfpStatusPort4Offset)) begin
            ret_byte = pack(qsfp_top.mod_statuses[4]);
        end else if (spi_request.address == fromInteger(qsfpStatusPort5Offset)) begin
            ret_byte = pack(qsfp_top.mod_statuses[5]);
        end else if (spi_request.address == fromInteger(qsfpStatusPort6Offset)) begin
            ret_byte = pack(qsfp_top.mod_statuses[6]);
        end else if (spi_request.address == fromInteger(qsfpStatusPort7Offset)) begin
            ret_byte = pack(qsfp_top.mod_statuses[7]);
        end else if (spi_request.address == fromInteger(qsfpStatusPort8Offset)) begin
            ret_byte = pack(qsfp_top.mod_statuses[8]);
        end else if (spi_request.address == fromInteger(qsfpStatusPort9Offset)) begin
            ret_byte = pack(qsfp_top.mod_statuses[9]);
        end else if (spi_request.address == fromInteger(qsfpStatusPort10Offset)) begin
            ret_byte = pack(qsfp_top.mod_statuses[10]);
        end else if (spi_request.address == fromInteger(qsfpStatusPort11Offset)) begin
            ret_byte = pack(qsfp_top.mod_statuses[11]);
        end else if (spi_request.address == fromInteger(qsfpStatusPort12Offset)) begin
            ret_byte = pack(qsfp_top.mod_statuses[12]);
        end else if (spi_request.address == fromInteger(qsfpStatusPort13Offset)) begin
            ret_byte = pack(qsfp_top.mod_statuses[13]);
        end else if (spi_request.address == fromInteger(qsfpStatusPort14Offset)) begin
            ret_byte = pack(qsfp_top.mod_statuses[14]);
        end else if (spi_request.address == fromInteger(qsfpStatusPort15Offset)) begin
            ret_byte = pack(qsfp_top.mod_statuses[15]);
        end else if (spi_request.address == fromInteger(qsfpControlPort0Offset)) begin
            ret_byte = pack(qsfp_top.mod_controls[0]);
        end else if (spi_request.address == fromInteger(qsfpControlPort1Offset)) begin
            ret_byte = pack(qsfp_top.mod_controls[1]);
        end else if (spi_request.address == fromInteger(qsfpControlPort2Offset)) begin
            ret_byte = pack(qsfp_top.mod_controls[2]);
        end else if (spi_request.address == fromInteger(qsfpControlPort3Offset)) begin
            ret_byte = pack(qsfp_top.mod_controls[3]);
        end else if (spi_request.address == fromInteger(qsfpControlPort4Offset)) begin
            ret_byte = pack(qsfp_top.mod_controls[4]);
        end else if (spi_request.address == fromInteger(qsfpControlPort5Offset)) begin
            ret_byte = pack(qsfp_top.mod_controls[5]);
        end else if (spi_request.address == fromInteger(qsfpControlPort6Offset)) begin
            ret_byte = pack(qsfp_top.mod_controls[6]);
        end else if (spi_request.address == fromInteger(qsfpControlPort7Offset)) begin
            ret_byte = pack(qsfp_top.mod_controls[7]);
        end else if (spi_request.address == fromInteger(qsfpControlPort8Offset)) begin
            ret_byte = pack(qsfp_top.mod_controls[8]);
        end else if (spi_request.address == fromInteger(qsfpControlPort9Offset)) begin
            ret_byte = pack(qsfp_top.mod_controls[9]);
        end else if (spi_request.address == fromInteger(qsfpControlPort10Offset)) begin
            ret_byte = pack(qsfp_top.mod_controls[10]);
        end else if (spi_request.address == fromInteger(qsfpControlPort11Offset)) begin
            ret_byte = pack(qsfp_top.mod_controls[11]);
        end else if (spi_request.address == fromInteger(qsfpControlPort12Offset)) begin
            ret_byte = pack(qsfp_top.mod_controls[12]);
        end else if (spi_request.address == fromInteger(qsfpControlPort13Offset)) begin
            ret_byte = pack(qsfp_top.mod_controls[13]);
        end else if (spi_request.address == fromInteger(qsfpControlPort14Offset)) begin
            ret_byte = pack(qsfp_top.mod_controls[14]);
        end else if (spi_request.address == fromInteger(qsfpControlPort15Offset)) begin
            ret_byte = pack(qsfp_top.mod_controls[15]);
        end else if (spi_request.address == fromInteger(qsfpI2cCtrlOffset)) begin
            ret_byte = pack(qsfp_top.i2c_ctrl);
        end else if (spi_request.address == fromInteger(qsfpPowerEnSw0Offset)) begin
            ret_byte = pack(qsfp_top.power_en_sw0);
        end else if (spi_request.address == fromInteger(qsfpPowerEnSw1Offset)) begin
            ret_byte = pack(qsfp_top.power_en_sw1);
        end else if (spi_request.address == fromInteger(qsfpPowerEnHw0Offset)) begin
            ret_byte = pack(qsfp_top.power_en_hw0);
        end else if (spi_request.address == fromInteger(qsfpPowerEnHw1Offset)) begin
            ret_byte = pack(qsfp_top.power_en_hw1);
        end else if (spi_request.address == fromInteger(qsfpPowerEn0Offset)) begin
            ret_byte = pack(qsfp_top.power_en0);
        end else if (spi_request.address == fromInteger(qsfpPowerEn1Offset)) begin
            ret_byte = pack(qsfp_top.power_en1);
        end else if (spi_request.address == fromInteger(qsfpPowerGood0Offset)) begin
            ret_byte = pack(qsfp_top.power_good0);
        end else if (spi_request.address == fromInteger(qsfpPowerGood1Offset)) begin
            ret_byte = pack(qsfp_top.power_good1);
        end else if (spi_request.address == fromInteger(qsfpPowerGoodTimeout0Offset)) begin
            ret_byte = pack(qsfp_top.power_good_timeout0);
        end else if (spi_request.address == fromInteger(qsfpPowerGoodTimeout1Offset)) begin
            ret_byte = pack(qsfp_top.power_good_timeout1);
        end else if (spi_request.address == fromInteger(qsfpPowerGoodLost0Offset)) begin
            ret_byte = pack(qsfp_top.power_good_lost0);
        end else if (spi_request.address == fromInteger(qsfpPowerGoodLost1Offset)) begin
            ret_byte = pack(qsfp_top.power_good_lost1);
        end else if (spi_request.address == fromInteger(qsfpModResetl0Offset)) begin
            ret_byte = pack(qsfp_top.mod_resetl0);
        end else if (spi_request.address == fromInteger(qsfpModResetl1Offset)) begin
            ret_byte = pack(qsfp_top.mod_resetl1);
        end else if (spi_request.address == fromInteger(qsfpModLpmode0Offset)) begin
            ret_byte = pack(qsfp_top.mod_lpmode0);
        end else if (spi_request.address == fromInteger(qsfpModLpmode1Offset)) begin
            ret_byte = pack(qsfp_top.mod_lpmode1);
        end else if (spi_request.address == fromInteger(qsfpModModprsl0Offset)) begin
            ret_byte = pack(qsfp_top.mod_modprsl0);
        end else if (spi_request.address == fromInteger(qsfpModModprsl1Offset)) begin
            ret_byte = pack(qsfp_top.mod_modprsl1);
        end else if (spi_request.address == fromInteger(qsfpModIntl0Offset)) begin
            ret_byte = pack(qsfp_top.mod_intl0);
        end else if (spi_request.address == fromInteger(qsfpModIntl1Offset)) begin
            ret_byte = pack(qsfp_top.mod_intl1);
        end else if (spi_request.address == fromInteger(qsfpPort0StatusOffset)) begin
            ret_byte = pack(qsfp_top.mod_statuses[0]);
        end else if (isBetween(spi_request.address, qsfpPort0ReadBufferOffset, readBufferNumEntries)) begin
            ret_byte = pack(qsfp_top.mod_read_buffers[0]);
        end else if (spi_request.address == fromInteger(qsfpPort1StatusOffset)) begin
            ret_byte = pack(qsfp_top.mod_statuses[1]);
        end else if (isBetween(spi_request.address, qsfpPort1ReadBufferOffset, readBufferNumEntries)) begin
            ret_byte = pack(qsfp_top.mod_read_buffers[1]);
        end else if (spi_request.address == fromInteger(qsfpPort2StatusOffset)) begin
            ret_byte = pack(qsfp_top.mod_statuses[2]);
        end else if (isBetween(spi_request.address, qsfpPort2ReadBufferOffset, readBufferNumEntries)) begin
            ret_byte = pack(qsfp_top.mod_read_buffers[2]);
        end else if (spi_request.address == fromInteger(qsfpPort3StatusOffset)) begin
            ret_byte = pack(qsfp_top.mod_statuses[3]);
        end else if (isBetween(spi_request.address, qsfpPort3ReadBufferOffset, readBufferNumEntries)) begin
            ret_byte = pack(qsfp_top.mod_read_buffers[3]);
        end else if (spi_request.address == fromInteger(qsfpPort4StatusOffset)) begin
            ret_byte = pack(qsfp_top.mod_statuses[4]);
        end else if (isBetween(spi_request.address, qsfpPort4ReadBufferOffset, readBufferNumEntries)) begin
            ret_byte = pack(qsfp_top.mod_read_buffers[4]);
        end else if (spi_request.address == fromInteger(qsfpPort5StatusOffset)) begin
            ret_byte = pack(qsfp_top.mod_statuses[5]);
        end else if (isBetween(spi_request.address, qsfpPort5ReadBufferOffset, readBufferNumEntries)) begin
            ret_byte = pack(qsfp_top.mod_read_buffers[5]);
        end else if (spi_request.address == fromInteger(qsfpPort6StatusOffset)) begin
            ret_byte = pack(qsfp_top.mod_statuses[6]);
        end else if (isBetween(spi_request.address, qsfpPort6ReadBufferOffset, readBufferNumEntries)) begin
            ret_byte = pack(qsfp_top.mod_read_buffers[6]);
        end else if (spi_request.address == fromInteger(qsfpPort7StatusOffset)) begin
            ret_byte = pack(qsfp_top.mod_statuses[7]);
        end else if (isBetween(spi_request.address, qsfpPort7ReadBufferOffset, readBufferNumEntries)) begin
            ret_byte = pack(qsfp_top.mod_read_buffers[7]);
        end else if (spi_request.address == fromInteger(qsfpPort8StatusOffset)) begin
            ret_byte = pack(qsfp_top.mod_statuses[8]);
        end else if (isBetween(spi_request.address, qsfpPort8ReadBufferOffset, readBufferNumEntries)) begin
            ret_byte = pack(qsfp_top.mod_read_buffers[8]);
        end else if (spi_request.address == fromInteger(qsfpPort9StatusOffset)) begin
            ret_byte = pack(qsfp_top.mod_statuses[9]);
        end else if (isBetween(spi_request.address, qsfpPort9ReadBufferOffset, readBufferNumEntries)) begin
            ret_byte = pack(qsfp_top.mod_read_buffers[9]);
        end else if (spi_request.address == fromInteger(qsfpPort10StatusOffset)) begin
            ret_byte = pack(qsfp_top.mod_statuses[10]);
        end else if (isBetween(spi_request.address, qsfpPort10ReadBufferOffset, readBufferNumEntries)) begin
            ret_byte = pack(qsfp_top.mod_read_buffers[10]);
        end else if (spi_request.address == fromInteger(qsfpPort11StatusOffset)) begin
            ret_byte = pack(qsfp_top.mod_statuses[11]);
        end else if (isBetween(spi_request.address, qsfpPort11ReadBufferOffset, readBufferNumEntries)) begin
            ret_byte = pack(qsfp_top.mod_read_buffers[11]);
        end else if (spi_request.address == fromInteger(qsfpPort12StatusOffset)) begin
            ret_byte = pack(qsfp_top.mod_statuses[12]);
        end else if (isBetween(spi_request.address, qsfpPort12ReadBufferOffset, readBufferNumEntries)) begin
            ret_byte = pack(qsfp_top.mod_read_buffers[12]);
        end else if (spi_request.address == fromInteger(qsfpPort13StatusOffset)) begin
            ret_byte = pack(qsfp_top.mod_statuses[13]);
        end else if (isBetween(spi_request.address, qsfpPort13ReadBufferOffset, readBufferNumEntries)) begin
            ret_byte = pack(qsfp_top.mod_read_buffers[13]);
        end else if (spi_request.address == fromInteger(qsfpPort14StatusOffset)) begin
            ret_byte = pack(qsfp_top.mod_statuses[14]);
        end else if (isBetween(spi_request.address, qsfpPort14ReadBufferOffset, readBufferNumEntries)) begin
            ret_byte = pack(qsfp_top.mod_read_buffers[14]);
        end else if (spi_request.address == fromInteger(qsfpPort15StatusOffset)) begin
            ret_byte = pack(qsfp_top.mod_statuses[15]);
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
    addRules(do_spi_write(qsfpI2cBcast1Offset, qsfp_top.i2c_bcast1));
    addRules(do_spi_write(qsfpI2cBcast0Offset, qsfp_top.i2c_bcast0));
    addRules(do_spi_write(qsfpI2cCtrlOffset, qsfp_top.i2c_ctrl));
    addRules(do_spi_write(qsfpPowerEnSw0Offset, qsfp_top.power_en_sw0));
    addRules(do_spi_write(qsfpPowerEnSw1Offset, qsfp_top.power_en_sw1));
    addRules(do_spi_write(qsfpModResetl0Offset, qsfp_top.mod_resetl0));
    addRules(do_spi_write(qsfpModResetl1Offset, qsfp_top.mod_resetl1));
    addRules(do_spi_write(qsfpModLpmode0Offset, qsfp_top.mod_lpmode0));
    addRules(do_spi_write(qsfpModLpmode1Offset, qsfp_top.mod_lpmode1));
    addRules(do_spi_write(qsfpControlPort0Offset, qsfp_top.mod_controls[0]));
    addRules(do_spi_write(qsfpControlPort1Offset, qsfp_top.mod_controls[1]));
    addRules(do_spi_write(qsfpControlPort2Offset, qsfp_top.mod_controls[2]));
    addRules(do_spi_write(qsfpControlPort3Offset, qsfp_top.mod_controls[3]));
    addRules(do_spi_write(qsfpControlPort4Offset, qsfp_top.mod_controls[4]));
    addRules(do_spi_write(qsfpControlPort5Offset, qsfp_top.mod_controls[5]));
    addRules(do_spi_write(qsfpControlPort6Offset, qsfp_top.mod_controls[6]));
    addRules(do_spi_write(qsfpControlPort7Offset, qsfp_top.mod_controls[7]));
    addRules(do_spi_write(qsfpControlPort8Offset, qsfp_top.mod_controls[8]));
    addRules(do_spi_write(qsfpControlPort9Offset, qsfp_top.mod_controls[9]));
    addRules(do_spi_write(qsfpControlPort10Offset, qsfp_top.mod_controls[10]));
    addRules(do_spi_write(qsfpControlPort11Offset, qsfp_top.mod_controls[11]));
    addRules(do_spi_write(qsfpControlPort12Offset, qsfp_top.mod_controls[12]));
    addRules(do_spi_write(qsfpControlPort13Offset, qsfp_top.mod_controls[13]));
    addRules(do_spi_write(qsfpControlPort14Offset, qsfp_top.mod_controls[14]));
    addRules(do_spi_write(qsfpControlPort15Offset, qsfp_top.mod_controls[15]));
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
