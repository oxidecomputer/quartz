# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.
#
# Copyright 2024 Oxide Computer Company


class OxideSpiNorDebug:
    base_reg = 0x6000_0100
    ctrl_reg = base_reg + 0x00
    sp5_offset_reg = base_reg + 0x20

    def __init__(self, con):
        self.mem = con

    def give_flash_to_espi(self, offset=0x0):
        owned_by_sp5_mask = 0x8000_0000
        self.mem.write32(self.sp5_offset_reg, offset)
        self.mem.write32(self.ctrl_reg, owned_by_sp5_mask)


    def give_flash_to_sp(self):
         self.mem.write32(self.ctrl_reg, 0x0)
