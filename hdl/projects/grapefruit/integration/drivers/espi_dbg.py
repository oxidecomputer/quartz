# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.
#
# Copyright 2024 Oxide Computer Company

from crc import Calculator, Crc8

from speeker.udp_if import Request

accept_code = 0x08

class EspiCmd:
    opcode_put_pc = 0x0
    opcode_get_pc = 0x1
    opcode_get_flash_np = 0x09
    opcode_put_flash_np = 0x0A
    opcode_get_config = 0x21
    opcode_set_config = 0x22
    opcode_get_status = 0x25
    
    cycle_type_flash_read = 0x0
    cycle_type_message_with_data = 0x11

    def __init__(self, gen_invalid_crc=False):
        self.bytes = bytearray()
        self.size = 0
        self.gen_invalid_crc = gen_invalid_crc

    def __bytes__(self):
        return bytes(self.bytes)
    
    def cmd_size(self):
        return self.size

    def hex(self):
        """Return the hex string rep of our request packet"""
        return self.bytes.hex()
    
    def invalidate_crc(self):
        self.bytes[-1] = ~self.bytes[-1] & 0xFF

    def build_get_status(self):
        # OPCODE + CRC
        self.bytes.append(self.opcode_get_status)
        self._add_crc()

    def build_get_config(self, address):
        # OPCODE + ADDRESS (2 bytes msb 1st) + CRC
        self.bytes.append(self.opcode_get_config)
        self.bytes += address.to_bytes(2, byteorder='big')
        self._add_crc()

    def build_get_config(self, address):
        # OPCODE + ADDRESS (2 bytes msb 1st) + CRC
        self.bytes.append(self.opcode_get_config)
        self.bytes += address.to_bytes(2, byteorder='big')
        self._add_crc()

    def build_set_config(self, address, data):
        # OPCODE + ADDRESS (2 bytes msb 1st) + DATA (4 bytes lsb 1st) + CRC
        self.bytes.append(self.opcode_set_config)
        self.bytes += address.to_bytes(2, byteorder='big')
        self.bytes += data.to_bytes(4, byteorder='little')
        self._add_crc()

    def build_put_flash_np(self, address, length):
        # opcode, cycle type, tag/length, length
        # address (4 bytes msb 1st) + CRC
        self.bytes.append(self.opcode_put_flash_np)
        self.bytes.append(self.cycle_type_flash_read)
        # Note assuming length is properly sized and tag is 0
        self.bytes += length.to_bytes(2, byteorder='big')
        self.bytes += address.to_bytes(4, byteorder='big')
        self._add_crc()

    def build_get_flash_np(self):
        # opcode + CRC
        self.bytes.append(self.opcode_get_flash_np)
        self._add_crc()

    def build_put_uart_data(self, data: bytearray):
        self.bytes.append(self.opcode_put_pc)
        self.bytes.append(self.cycle_type_message_with_data)
        size = len(data)
        # Note assuming length is properly sized and tag is 0
        self.bytes += size.to_bytes(2, byteorder='big')
        self.bytes.extend(data)
        self._add_crc()

    def build_get_uart_data(self):
        self.bytes.append(self.opcode_get_pc)
        self._add_crc()
        
    def _add_crc(self):
        crc = Calculator(Crc8.CCITT).checksum(self.bytes)
        if self.gen_invalid_crc:
            # Trying to intentionally generate a bad crc, so
            # invert the bits to guarantee a bad crc
            crc = ~crc & 0xFF
        self.bytes.append(crc)
        self.size = len(self.bytes)

    def pad_to_32bit(self):
        while len(self.bytes) % 4 != 0:
            self.bytes.append(0)


class EspiResponse:
    def __init__(self, _bytes: bytes):
        self.bytes = bytearray(_bytes)
        self.crc_ok = False
        self.response = self.bytes[0]
        self.status = int.from_bytes(self.bytes[-3:-1], byteorder='little')
        self._validate_crc()

    def __bytes__(self):
        return bytes(self.bytes)
    
    def hex(self):
        """Return the hex string rep of our request packet"""
        return bytes(self).hex()

    @property
    def crc(self):
        return self.bytes[-1]
    
    def get_32bit_payload(self):
        return int.from_bytes(self.bytes[1:5], byteorder='little')

    def _validate_crc(self):
        crc = Calculator(Crc8.CCITT).checksum(self.bytes[:-1])
        self.crc_ok = crc == self.bytes[-1]

    # @classmethod
    # def from_32wide_fifos(cls, fifo_data: list):
    #     # Because we're reading from a 32-bit wide fifo, we need to 
    #     # handle the cases where we get an extra 1-3 bytes of padding

    #     # responses are going to be the of the following form:
    #     # response_code: 1 byte
    #     # Optional data: <some bytes>
    #     # status: 2 bytes
    #     # crc: 1 byte
    #     # optional padding: 1-3 bytes




class OxideEspiDebug:
    base_reg = 0x6000_0200
    flags_reg = base_reg + 0x00
    ctrl_reg = base_reg + 0x04
    status_reg = base_reg + 0x08
    fifo_status_reg = base_reg + 0x0C
    cmd_fifo_wdata_reg = base_reg + 0x10
    resp_fifo_rdata_reg = base_reg + 0x14
    cmd_size_fifo_reg = base_reg + 0x18

    def __init__(self, target_mem):
        self.mem = target_mem
        self.gen_invalid_crc = False
        #self.set_crc_enforcement(False)

    def enable_debug_mode(self):
        self.mem.write32(self.ctrl_reg, 0x1)

    def set_crc_enforcement(self, enforce: bool):
        cap_reg_offset = 0x8
        # Get current value, verify ok
        resp = self.get_config(cap_reg_offset)
        cur_cap = resp.get_32bit_payload()
        # Bitwise OR in the crc enable and send checking response
        if enforce:
            new_cap = cur_cap | (1 << 31)
        else:
            new_cap = cur_cap & (0x7fffffff)
        resp = self.set_config(cap_reg_offset, new_cap)

    def fifos_reset(self):
        reset_mask = 0xe
        # get current value (care about being enabled)
        val = self.mem.read32(self.ctrl_reg)
        val |= reset_mask
        self.mem.write32(self.ctrl_reg, val)

    def get_status(self) -> EspiResponse:
        get_status = EspiCmd(self.gen_invalid_crc)
        get_status.build_get_status()
        self.send_cmd(get_status)
        self.wait_for_done()
        return self.get_response()

    def resp_wds_avail(self):
        status = self.mem.read32(self.fifo_status_reg)
        return status & 0x0000_FFFF
    
    def get_config(self, address: int):
        get_config = EspiCmd(self.gen_invalid_crc)
        get_config.build_get_config(address)
        self.send_cmd(get_config)
        self.wait_for_done()
        return self.get_response()

    def set_config(self, address: int, data: int):
        get_config = EspiCmd(self.gen_invalid_crc)
        get_config.build_set_config(address, data)
        self.send_cmd(get_config)
        self.wait_for_done()
        return self.get_response()

    def send_cmd(self, cmd: EspiCmd):
        # need to build a custom command here
        # all the data in the cmd object goes into the cmd fifo
        # size of the cmd goes into the cmd_size_fifo which
        # starts the command
        cmd.pad_to_32bit()
        req = Request()
        req.set_address(self.cmd_fifo_wdata_reg)
        req.add_write32s(bytes(cmd))
        req.set_address(self.cmd_size_fifo_reg)
        req.add_write32s([cmd.cmd_size()])
        self.mem.execute_prebuilt_request(req)

    def get_response(self) -> EspiResponse:
        num_wds = self.resp_wds_avail()
        print(f"num_wds: {num_wds}")
        assert 0 < num_wds < 256  # Need chunking logic to get more than this due
        req = Request()
        req.set_address(self.resp_fifo_rdata_reg)
        req.add_read32s(num_wds)
        resp = self.mem.execute_prebuilt_request(req)
        num_wds = self.resp_wds_avail()
        espi_resp = EspiResponse(bytes(resp))
        return espi_resp

    def wait_for_done(self):
        busy_mask = 0x1
        status = busy_mask
        cntr = 0
        while status & busy_mask == busy_mask:
            status = self.mem.read32(self.status_reg)
            fifo_status = self.mem.read32(self.fifo_status_reg)
            cntr += 1
            assert cntr < 100

    def wait_for_alert(self):
        pass

    @property
    def alert_pending(self) -> bool:
        pass

