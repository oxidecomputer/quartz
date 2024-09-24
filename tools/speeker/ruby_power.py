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

POWER_BUTTON_SGPIO_REG = 0x60000308
POWER_BUTTON_MASK = (1 << 12)

def ruby_on(args):
    con = udp_if.UDPMem(target, ifname, port)
    orig = con.read32(POWER_BUTTON_SGPIO_REG)
    con.write32(POWER_BUTTON_SGPIO_REG, (orig & ~POWER_BUTTON_MASK) & 0xffff)
    # Short push for power on
    time.sleep(1)
    con.write32(POWER_BUTTON_SGPIO_REG, orig)

def ruby_off(args):
    con = udp_if.UDPMem(target, ifname, port)
    orig = con.read32(POWER_BUTTON_SGPIO_REG)
    con.write32(POWER_BUTTON_SGPIO_REG, (orig & ~POWER_BUTTON_MASK) & 0xffff)
    # Long push for power off
    time.sleep(6)
    con.write32(POWER_BUTTON_SGPIO_REG, orig)


# create the top-level parser
parser = argparse.ArgumentParser(prog='ruby_power', description='Ruby power control')
subparsers = parser.add_subparsers(help='sub-command help')

format_parser = subparsers.add_parser('on', help='format help')
format_parser.set_defaults(func=ruby_on)

format_parser = subparsers.add_parser('off', help='format help')
format_parser.set_defaults(func=ruby_off)

args = parser.parse_args()
args.func(args)