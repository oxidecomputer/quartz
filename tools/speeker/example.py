# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.
#
# Copyright 2024 Oxide Computer Company

# Super simple read/write example

target = "fe80::c1d:76ff:fea8:34f5"
port = 11114
ifname = "eno1"

import udp_if

con = udp_if.UDPMem(target, ifname, port)

a = con.read32(0x60000000)
print(f"0x0: {a:#x}")
b = con.read32(0x60000008)
print(f"0x8: {b:#x}")
# # write to scratchpad
con.write32(0x60000008, 0xabadbeef)
a = con.read32(0x60000008)
print(f"0x8: {a:#x}")
# # set back to default
con.write32(0x60000008, b)
b = con.read32(0x60000008)
print(f"0x8: {b:#x}")