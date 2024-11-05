# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.
#
# Copyright 2024 Oxide Computer Company

# Control ruby power from gfruit over sgpio

target = "fe80::0c1d:62ff:fee0:308f"
port = 11114
ifname = "eno1"

import udp_if
import time
import argparse

spi_cr = 0x60000100
sp5_offset_addr = 0x60000120

ruby_flash_offset = -0x3000000
sp5_owns_flash = (1 << 31)

def to_sp5(args):
    con = udp_if.UDPMem(target, ifname, port)
    con.write32(spi_cr, sp5_owns_flash)
    con.write32(sp5_offset_addr,ruby_flash_offset)
    a = con.read32(sp5_offset_addr)
    print(f"{sp5_offset_addr:#x}: {a:#x}")

def to_sp(args):
    con = udp_if.UDPMem(target, ifname, port)
    con.write32(spi_cr, 0)


# create the top-level parser
parser = argparse.ArgumentParser(prog='espi_mux', description='espi mux control')
subparsers = parser.add_subparsers(help='sub-command help')

format_parser = subparsers.add_parser('on', help='format help')
format_parser.set_defaults(func=to_sp5)

format_parser = subparsers.add_parser('off', help='format help')
format_parser.set_defaults(func=to_sp)

args = parser.parse_args()
args.func(args)