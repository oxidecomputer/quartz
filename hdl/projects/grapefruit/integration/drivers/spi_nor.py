# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.
#
# Copyright 2024 Oxide Computer Company
import time

op_page_program = 0x02
op_read = 0x03
op_read_status_1 = 0x05
op_write_enable = 0x06
op_fast_read_quad = 0x6b
op_fast_read_quad_output_4b = 0x6c
op_sector_erase = 0x20
op_read_jedec_id = 0x9f
op_block_erase_64kB = 0xd8
op_block_erase_64kB_4b = 0xdc
op_quad_input_page_program = 0x32
op_quad_input_page_program_4b = 0x34

class OxideSpiNorDebug:
    base_reg = 0x6000_0100
    ctrl_reg = base_reg + 0x00
    status_reg = base_reg + 0x04
    addr_reg = base_reg + 0x08
    dummy_cycles_reg = base_reg + 0x0c
    data_bytes_reg = base_reg + 0x10
    instr_reg = base_reg + 0x14
    tx_fifo_reg = base_reg + 0x18
    rx_fifo_reg = base_reg + 0x1c
    sp5_offset_reg = base_reg + 0x20

    def __init__(self, con):
        self.mem = con

    def clear_fifos(self) -> None:
        self.mem.write32(self.ctrl_reg, 0x8080)

    def wait_fpga_busy(self) -> None:
        while self.mem.read32(self.ctrl_reg) & 0x1 != 0:
            time.sleep(0.001)

    def read_flash_status(self) -> bytearray:
        status = bytearray()
        self.clear_fifos()
        self.mem.write32(self.data_bytes_reg, 20)
        self.mem.write32(self.addr_reg, 0)
        self.mem.write32(self.dummy_cycles_reg, 0)
        self.mem.write32(self.instr_reg, op_read_status_1)
        self.wait_fpga_busy()
        for i in range(20/4):
            d = self.mem.read32(self.rx_fifo_reg)
            status.extend(d.to_bytes(4, 'little'))
        return status

    def wait_flash_busy(self) -> None:
        while self.read_flash_status() & 0x1 != 0:
            time.sleep(0.001)

    def flash_write_enable(self) -> None:
        self.mem.write32(self.data_bytes_reg, 0)
        self.mem.write32(self.addr_reg, 0)
        self.mem.write32(self.dummy_cycles_reg, 0)
        self.mem.write32(self.instr_reg, op_write_enable)
        self.wait_fpga_busy()

    def flash_sector_erase(self, address: int) -> None:
        self.flash_write_enable()
        self.mem.write32(self.data_bytes_reg, 0)
        self.mem.write32(self.addr_reg, address)
        self.mem.write32(self.dummy_cycles_reg, 0)
        self.mem.write32(self.instr_reg, op_block_erase_64kB_4b)
        self.wait_fpga_busy()
        self.wait_flash_busy()
        
    def flash_read(self, offset: int, size_bytes: int) -> bytearray:
        data = bytearray()
        self.mem.write32(self.data_bytes_reg, size)
        self.mem.write32(self.addr_reg, offset)
        self.mem.write32(self.dummy_cycles_reg, 0)
        self.mem.write32(self.instr_reg, op_fast_read_quad_output_4b)
        self.wait_fpga_busy()
        for i in range(size//4):
            d = self.mem.read32(self.rx_fifo_reg)
            data.extend(d.to_bytes(4, 'little'))
        return data
    def give_flash_to_espi(self, offset=0x0):
        owned_by_sp5_mask = 0x8000_0000
        self.mem.write32(self.sp5_offset_reg, offset)
        self.mem.write32(self.ctrl_reg, owned_by_sp5_mask)

    def give_flash_to_sp(self):
         self.mem.write32(self.ctrl_reg, 0x0)

    def read_flash(self, address, read_size_bytes):
        data = bytearray();
        rem_bytes = read_size_bytes
        while rem_bytes > 0:
            cur_read_size = min(rem_bytes, self.max_read_size)
            # issue read command
            # poll for done
            # read data
            # store into data
            rem_bytes -= cur_read_size
            address += cur_read_size
        return data
