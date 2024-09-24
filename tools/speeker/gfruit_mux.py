# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.
#
# Copyright 2024 Oxide Computer Company

# Super simple read/write example

target = "fe80::0c1d:62ff:fee0:308f"
port = 11114
ifname = "eno1"

import udp_if
import time
SGPIO_0_REG = 0x60000300
SGPIO_1_REG = 0x60000308

ctrl_0s = [1 << 11, 1 << 8, 1 << 7, 1 << 6, 1 << 5, 1 << 4, 1 << 3, 1 << 2]

ctrl_1s = [1 << 9, 1 << 8, 1 << 7, 1 << 6, 1 << 5]

con = udp_if.UDPMem(target, ifname, port)

orig =  con.read32(SGPIO_0_REG)

print("Reg0")
for val in ctrl_0s:
    print(f"Setting {val:08x}")
    con.write32(SGPIO_0_REG, orig | val)
    time.sleep(4)
con.write32(SGPIO_0_REG,orig)


orig =  con.read32(SGPIO_1_REG)
print("Reg1")
for val in ctrl_1s:
    print(f"Setting {val:08x}")
    con.write32(SGPIO_1_REG, orig | val)
    time.sleep(4)
con.write32(SGPIO_1_REG,orig)

