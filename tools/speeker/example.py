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

for addr in range(0x60000200, 0x60000220, 4):
    a = con.read32(addr)
    print(f"{addr:#x}: {a:#x}")