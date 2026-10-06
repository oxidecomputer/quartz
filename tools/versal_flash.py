#!/usr/bin/env python3
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

"""Poke at a flash part through one of the metro FPGA's spi_nor blocks.

Reads ranges of the flash, reads its ID and status registers, and reads and
writes the nonvolatile configuration register (NVCR) of a Micron-style part.
The register sequences are the ones cosmo-metro-hf uses, driven from here so
they work on images without that task and on parts it does not recognise.

Transport
---------
Registers are reached either through humility's FmcDemo peek32/poke32 (the
default; slow, one humility run per access) or over the FMC demo server's UDP
peek/poke socket (--udp; fast, and reads are batched):

    ./tools/versal_flash.py id
    ./tools/versal_flash.py --udp --ip fe80::... --interface enp5s0 id

Which spi_nor
-------------
--spi-nor picks the block. The Versal's flash is behind the one at 0x800,
which is the default; the bring-up build with the pins swapped has it behind
0x100 instead. The Versal's flash also sits behind the sheet-137 mux, so
--take-mux is usually wanted: it sets mux_ctrl.to_fpga and mux_en, checks
mux_status, and clears them afterwards unless --keep-mux.

Commands
--------
    id                      JEDEC ID (9F)
    status                  status (05) and flag status (70) registers
    read ADDR LEN           read LEN bytes at ADDR; hexdump, or -o FILE
    nvcr                    read the NVCR (B5) and decode it
    nvcr --set VALUE        write the NVCR (06, B1), wait, read it back

The flag status and NVCR opcodes need an FPGA image whose spi_nor knows them
(spi_nor_pkg's READ_FLAG_STATUS_OP and friends). An older image sends them as
a bare instruction with no data phase, and this script says so when the RX
FIFO comes back empty.

Examples
--------
    # swapped bring-up build, over humility
    ./tools/versal_flash.py --spi-nor 0x100 --take-mux id
    ./tools/versal_flash.py --spi-nor 0x100 --take-mux read 0x0 0x200
    ./tools/versal_flash.py --spi-nor 0x100 --take-mux nvcr
    ./tools/versal_flash.py --spi-nor 0x100 --take-mux nvcr --set 0xfffe

    # a megabyte to a file, over UDP
    ./tools/versal_flash.py --udp --ip fe80::... --interface enp5s0 \\
        --take-mux read 0x0 0x100000 -o image_head.bin

    # see what would be sent without touching hardware (humility only)
    ./tools/versal_flash.py --take-mux --dry-run nvcr
"""

import argparse
import os
import re
import subprocess
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

# Byte offsets within a spi_nor block. These mirror
# hdl/ip/vhd/spi_nor_controller/spi_nor_regs.rdl.
SPICR = 0x00
SPISR = 0x04
ADDR = 0x08
DUMMYCYCLES = 0x0C
DATABYTES = 0x10
INSTR = 0x14
TX_FIFO_WDATA = 0x18
RX_FIFO_RDATA = 0x1C

SPICR_SP5_OWNS_FLASH = 1 << 31
SPICR_RX_FIFO_RESET = 1 << 15
SPICR_TX_FIFO_RESET = 1 << 7
SPISR_BUSY = 1 << 0
SPISR_RX_EMPTY = 1 << 6

# The Versal flash mux control block, from
# hdl/projects/metro_seq/versal_subsystem/versal_flash_regs.rdl.
MUX_CTRL = 0x900
MUX_STATUS = 0x904
MUX_CTRL_TO_FPGA = 1 << 1
MUX_CTRL_MUX_EN = 1 << 2
MUX_STATUS_BITS = [
    (1 << 0, "granted"),
    (1 << 1, "seq_owned"),
    (1 << 2, "mux_sel"),
    (1 << 3, "mux_en_l"),
    (1 << 4, "versal_held_in_reset"),
]

OP_WRITE_ENABLE = 0x06
OP_READ_STATUS = 0x05
OP_READ_FLAG_STATUS = 0x70
OP_READ_JEDEC_ID = 0x9F
OP_READ_NVCR = 0xB5
OP_WRITE_NVCR = 0xB1
# How to read data, by --read-mode: opcode and dummy cycles. All take a
# four-byte address, so they do not depend on the part's address mode. The
# plain read needs nothing configured in the part and is the one to trust
# when the configuration itself is in question; the others depend on the
# part's dummy-cycle setting matching.
READ_MODES = {
    "plain": (0x13, 0),
    "fast": (0x0C, 8),
    "quad": (0x6C, 8),
}

# One spi_nor transaction. The controller's byte counter is nine bits; a page
# is what hubris uses and what the RX FIFO is sized for.
CHUNK = 256

MANUFACTURERS = {
    0x01: "Infineon/Cypress/Spansion",
    0x20: "Micron",
    0x2C: "Micron",
    0x9D: "ISSI",
    0xC2: "Macronix",
    0xEF: "Winbond",
}


class HumilityBus:
    """Register access over humility's FmcDemo peek32/poke32."""

    _VALUE_RE = re.compile(r"(0x[0-9a-fA-F]+|\b\d+\b)")

    def __init__(self, base, humility="humility", extra_args=None, dry_run=False,
                 verbose=False):
        self.base = base
        self.humility = humility
        self.extra_args = list(extra_args or [])
        self.dry_run = dry_run
        self.verbose = verbose

    def _run(self, call, args):
        cmd = [self.humility] + self.extra_args + ["hiffy", "-c", call]
        for key, value in args:
            cmd += ["-a", "%s=%s" % (key, value)]
        if self.verbose or self.dry_run:
            print("    $ " + " ".join(cmd))
        if self.dry_run:
            return 0
        try:
            out = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
        except FileNotFoundError:
            raise SystemExit(
                "could not run %r. Is humility on PATH? Use --humility to point "
                "at it." % self.humility
            )
        except subprocess.TimeoutExpired:
            raise SystemExit("humility timed out running: %s" % " ".join(cmd))
        if out.returncode != 0:
            raise SystemExit(
                "humility failed (exit %d): %s\n%s%s"
                % (out.returncode, " ".join(cmd), out.stdout, out.stderr)
            )
        return self._parse(out.stdout + out.stderr, cmd)

    @classmethod
    def _parse(cls, text, cmd=None):
        # Everything before the last '=>' is dropped so an address echoed back
        # in the arguments cannot be mistaken for the result.
        tail = text.rsplit("=>", 1)[-1] if "=>" in text else text
        listing = re.search(r"\[([^\]]*)\]", tail)
        if listing:
            items = [t for t in re.split(r"[,\s]+", listing.group(1)) if t]
            try:
                vals = [int(t, 16) if t.lower().startswith("0x") else int(t)
                        for t in items]
            except ValueError:
                vals = []
            if vals and all(0 <= v <= 0xFF for v in vals):
                return int.from_bytes(bytes(vals[:4]), "little")
        found = cls._VALUE_RE.findall(tail)
        if not found:
            raise SystemExit(
                "could not find a value in humility's output for: %s\n"
                "raw output was:\n%s" % (" ".join(cmd or []), text)
            )
        token = found[0]
        return int(token, 16) if token.lower().startswith("0x") else int(token)

    def peek(self, addr):
        return self._run("FmcDemo.peek32", [("addr", "0x%x" % (self.base + addr))])

    def poke(self, addr, value):
        self._run(
            "FmcDemo.poke32",
            [("addr", "0x%x" % (self.base + addr)), ("value", "0x%x" % value)],
        )

    def peek_repeat(self, addr, count):
        return [self.peek(addr) for _ in range(count)]


class UdpBus:
    """Register access over the FMC demo server's UDP peek/poke socket."""

    # Reads of one address per datagram. Each is a byte of request and four of
    # response, so this is nowhere near the MTU; it is one page of flash data.
    BATCH = 64

    def __init__(self, base, ip, interface, port, verbose=False):
        from speeker.udp_if import Request, UDPMem
        self._Request = Request
        self.base = base
        self.dry_run = False
        self.verbose = verbose
        # No retries. Reading the RX FIFO register pops it, so a request that
        # was acted on but whose response was lost must not be sent again: the
        # data would come back shifted with nothing to say so. A lost datagram
        # is an error here, and the read can simply be run again.
        self.mem = UDPMem(ip, interface, target_port=port, retries=0)

    def peek(self, addr):
        value = self.mem.read32(self.base + addr)
        if self.verbose:
            print("    peek 0x%08x => 0x%08x" % (self.base + addr, value))
        return value

    def poke(self, addr, value):
        if self.verbose:
            print("    poke 0x%08x <= 0x%08x" % (self.base + addr, value))
        self.mem.write32(self.base + addr, value)

    def peek_repeat(self, addr, count):
        out = []
        while count:
            n = min(count, self.BATCH)
            req = self._Request()
            req.set_address(self.base + addr)
            req.add_read32s(n)
            resp = self.mem.execute_prebuilt_request(req)
            out += [r.payload for r in resp.expected_responses]
            count -= n
        return out


class SpiNor:
    """One spi_nor block, driven the way cosmo-metro-hf drives it."""

    def __init__(self, bus, window):
        self.bus = bus
        self.window = window

    def _peek(self, reg):
        return self.bus.peek(self.window + reg)

    def _poke(self, reg, value):
        self.bus.poke(self.window + reg, value)

    def check_owner(self):
        if self._peek(SPICR) & SPICR_SP5_OWNS_FLASH:
            raise SystemExit(
                "SPICR.sp5_owns_flash is set on the block at 0x%x, so the SP "
                "side is locked out; clear it first" % self.window
            )

    def clear_fifos(self):
        self._poke(SPICR, SPICR_RX_FIFO_RESET | SPICR_TX_FIFO_RESET)

    def wait_idle(self, what):
        deadline = time.monotonic() + 5.0
        while True:
            spisr = self._peek(SPISR)
            if self.bus.dry_run or not spisr & SPISR_BUSY:
                return spisr
            if time.monotonic() > deadline:
                raise SystemExit(
                    "spi_nor stayed busy during %s (SPISR = 0x%08x)" % (what, spisr)
                )

    def command(self, opcode, addr=0, dummy=0, rx_bytes=0, tx=b"", what="command"):
        """Run one transaction and return the bytes read, if any.

        The opcode decides what the controller does with the byte count: it
        is a read length for a read opcode and a write length for a write one.
        Writing the instruction register is what starts it.
        """
        self.clear_fifos()
        self._poke(DATABYTES, rx_bytes if rx_bytes else len(tx))
        self._poke(ADDR, addr)
        self._poke(DUMMYCYCLES, dummy)
        for i in range(0, len(tx), 4):
            word = tx[i:i + 4].ljust(4, b"\0")
            self._poke(TX_FIFO_WDATA, int.from_bytes(word, "little"))
        self._poke(INSTR, opcode)
        spisr = self.wait_idle(what)
        if not rx_bytes:
            return b""
        if not self.bus.dry_run and spisr & SPISR_RX_EMPTY:
            raise SystemExit(
                "%s (opcode 0x%02x) put nothing in the RX FIFO. Either the "
                "transaction did not run, or this FPGA image's spi_nor does "
                "not know the opcode and sent it without a data phase."
                % (what, opcode)
            )
        words = self.bus.peek_repeat(self.window + RX_FIFO_RDATA, (rx_bytes + 3) // 4)
        data = b"".join(w.to_bytes(4, "little") for w in words)
        return data[:rx_bytes]

    def read_id(self):
        return self.command(OP_READ_JEDEC_ID, rx_bytes=3, what="read ID")

    def read_status(self):
        return self.command(OP_READ_STATUS, rx_bytes=1, what="read status")[0]

    def read_flag_status(self):
        return self.command(OP_READ_FLAG_STATUS, rx_bytes=1, what="read flag status")[0]

    def write_enable(self):
        self.command(OP_WRITE_ENABLE, what="write enable")

    def wait_write_done(self, what, timeout=5.0):
        deadline = time.monotonic() + timeout
        while True:
            status = self.read_status()
            if self.bus.dry_run or not status & 1:
                return
            if time.monotonic() > deadline:
                raise SystemExit(
                    "the flash stayed busy after %s (status = 0x%02x)" % (what, status)
                )

    def read_nvcr(self):
        data = self.command(OP_READ_NVCR, rx_bytes=2, what="read NVCR")
        return int.from_bytes(data, "little")

    def write_nvcr(self, value):
        self.write_enable()
        if not self.bus.dry_run and not self.read_status() & 2:
            raise SystemExit(
                "the write enable latch did not set; the part is not taking "
                "commands, or is write protected"
            )
        self.write_enable()
        self.command(OP_WRITE_NVCR, tx=value.to_bytes(2, "little"), what="write NVCR")
        self.wait_write_done("write NVCR")

    def read(self, addr, length, mode, progress=None):
        opcode, dummy = READ_MODES[mode]
        out = bytearray()
        while len(out) < length:
            n = min(CHUNK, length - len(out))
            out += self.command(opcode, addr=addr + len(out), dummy=dummy,
                                rx_bytes=n, what="read")
            if progress:
                progress(len(out), length)
        return bytes(out)


def decode_mux_status(value):
    return ", ".join(
        "%s=%d" % (name, 1 if value & bit else 0) for bit, name in MUX_STATUS_BITS
    )


def take_mux(bus):
    bus.poke(MUX_CTRL, MUX_CTRL_TO_FPGA | MUX_CTRL_MUX_EN)
    status = bus.peek(MUX_STATUS)
    print("mux_status = 0x%02x: %s" % (status, decode_mux_status(status)))
    if not bus.dry_run and not status & 1:
        raise SystemExit(
            "the mux was not granted to the FPGA; this image may predate the "
            "to_fpga override"
        )


def decode_nvcr(value):
    """Field breakdown per the Micron MT25Q NVCR layout.

    Other parts and families lay this register out differently; check the
    datasheet for the part on the board before leaning on the decode.
    """
    dummy = (value >> 12) & 0xF
    xip = (value >> 9) & 0x7
    drive = (value >> 6) & 0x7
    lines = [
        "  [15:12] dummy cycles          %s" % (
            "default (0xf)" if dummy == 0xF else str(dummy)),
        "  [11:9]  XIP mode at power-on  %s" % (
            "disabled (0b111)" if xip == 0x7 else "0b{:03b}".format(xip)),
        "  [8:6]   output drive strength 0b{:03b}".format(drive),
        "  [5]     double transfer rate  %s" % (
            "disabled" if value & (1 << 5) else "ENABLED"),
        "  [4]     reset/hold on DQ3     %s" % (
            "enabled" if value & (1 << 4) else "DISABLED"),
        "  [3]     quad I/O protocol     %s" % (
            "disabled" if value & (1 << 3) else "ENABLED"),
        "  [2]     dual I/O protocol     %s" % (
            "disabled" if value & (1 << 2) else "ENABLED"),
        "  [1]     128Mb segment select  %s" % (
            "highest (default)" if value & (1 << 1) else "lowest"),
        "  [0]     address bytes         %s" % (
            "3-byte (default)" if value & 1 else "4-byte"),
    ]
    return "\n".join(lines)


def hexdump(data, base):
    lines = []
    for off in range(0, len(data), 16):
        row = data[off:off + 16]
        hexes = " ".join("%02x" % b for b in row)
        text = "".join(chr(b) if 32 <= b < 127 else "." for b in row)
        lines.append("%08x  %-47s  |%s|" % (base + off, hexes, text))
    return "\n".join(lines)


def cmd_id(nor, args):
    mfr, mem_type, capacity = nor.read_id()
    print("JEDEC ID: %02x %02x %02x (%s, type 0x%02x, capacity 0x%02x)" % (
        mfr, mem_type, capacity, MANUFACTURERS.get(mfr, "unknown manufacturer"),
        mem_type, capacity))
    if (mfr, mem_type, capacity) in ((0, 0, 0), (0xFF, 0xFF, 0xFF)):
        print("that is not a flash answering: check the part's power, the mux, "
              "and the sclk rate/sample point for these pins")
        return 1
    return 0


def cmd_status(nor, args):
    status = nor.read_status()
    print("status      = 0x%02x: WIP=%d WEL=%d" % (status, status & 1, (status >> 1) & 1))
    flag = nor.read_flag_status()
    print("flag status = 0x%02x: ready=%d erase_err=%d program_err=%d "
          "protection_err=%d 4byte_addr=%d" % (
              flag, (flag >> 7) & 1, (flag >> 5) & 1, (flag >> 4) & 1,
              (flag >> 1) & 1, flag & 1))
    return 0


def cmd_read(nor, args):
    def progress(done, total):
        if args.output:
            sys.stderr.write("\r%d / %d bytes" % (done, total))
            sys.stderr.flush()

    data = nor.read(args.addr, args.length, args.read_mode, progress)
    if args.output:
        sys.stderr.write("\n")
        with open(args.output, "wb") as f:
            f.write(data)
        print("wrote %d bytes from 0x%x to %s" % (len(data), args.addr, args.output))
    else:
        print(hexdump(data, args.addr))
    return 0


def cmd_nvcr(nor, args):
    before = nor.read_nvcr()
    print("NVCR = 0x%04x" % before)
    print(decode_nvcr(before))
    if args.set is None:
        return 0

    if not 0 <= args.set <= 0xFFFF:
        raise SystemExit("the NVCR is 16 bits; 0x%x does not fit" % args.set)
    if not args.yes:
        print("\nabout to write NVCR = 0x%04x:" % args.set)
        print(decode_nvcr(args.set))
        print("This is nonvolatile and decides how the part comes up at its "
              "next power-on, including whether whatever boots from it can "
              "still talk to it.")
        if input("type 'yes' to write it: ").strip() != "yes":
            print("not written")
            return 1

    nor.write_nvcr(args.set)
    after = nor.read_nvcr()
    print("NVCR = 0x%04x after the write" % after)
    if not nor.bus.dry_run and after != args.set:
        print("readback does not match what was written")
        return 1
    print("The new value takes effect at the part's next power-on or reset.")
    return 0


def main():
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument(
        "--spi-nor", type=lambda s: int(s, 0), default=0x800,
        help="offset of the spi_nor block to use: 0x800 is the Versal flash's "
             "(the default), 0x100 the host flash's; the swapped bring-up "
             "build has them the other way round",
    )
    parser.add_argument(
        "--fpga-base", type=lambda s: int(s, 0), default=0xC0000000,
        help="where the FPGA's registers sit in the SP's address space "
             "(default 0xc0000000)",
    )
    parser.add_argument(
        "--take-mux", action="store_true",
        help="point the Versal flash mux at the FPGA first, by override",
    )
    parser.add_argument(
        "--keep-mux", action="store_true",
        help="leave the mux with the FPGA afterwards",
    )
    parser.add_argument("-v", "--verbose", action="store_true",
                        help="show every register access")

    hum = parser.add_argument_group("humility transport (the default)")
    hum.add_argument("--humility", default="humility")
    hum.add_argument(
        "--humility-arg", action="append", default=[],
        help="extra argument passed to humility before 'hiffy', repeatable",
    )
    hum.add_argument("--dry-run", action="store_true",
                     help="print the humility commands without running them")

    udp = parser.add_argument_group("UDP transport")
    udp.add_argument("--udp", action="store_true",
                     help="use the FMC demo server's UDP peek/poke socket")
    udp.add_argument("--ip", help="the SP's IPv6 link-local address")
    udp.add_argument("--interface", help="the host interface it is reached on")
    udp.add_argument("--port", type=int, default=11114)

    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("id", help="read the JEDEC ID").set_defaults(func=cmd_id)
    sub.add_parser(
        "status", help="read the status and flag status registers"
    ).set_defaults(func=cmd_status)

    p_read = sub.add_parser("read", help="read a range of the flash")
    p_read.add_argument("addr", type=lambda s: int(s, 0))
    p_read.add_argument("length", type=lambda s: int(s, 0))
    p_read.add_argument("-o", "--output", help="write the bytes here instead "
                        "of printing a hexdump")
    p_read.add_argument(
        "--read-mode", choices=sorted(READ_MODES), default="plain",
        help="plain: 13h, no dummy cycles, depends on nothing in the part's "
             "configuration (the default). fast: 0Ch with 8 dummy cycles. "
             "quad: 6Ch with 8 dummy cycles, what hubris uses",
    )
    p_read.set_defaults(func=cmd_read)

    p_nvcr = sub.add_parser(
        "nvcr", help="read, and optionally write, the nonvolatile "
        "configuration register")
    p_nvcr.add_argument("--set", type=lambda s: int(s, 0), metavar="VALUE",
                        help="write this 16-bit value")
    p_nvcr.add_argument("--yes", action="store_true",
                        help="do not ask before writing")
    p_nvcr.set_defaults(func=cmd_nvcr)

    args = parser.parse_args()

    if args.udp:
        if args.dry_run:
            parser.error("--dry-run only applies to the humility transport")
        if not args.ip or not args.interface:
            parser.error("--udp needs --ip and --interface")
        bus = UdpBus(args.fpga_base, args.ip, args.interface, args.port, args.verbose)
    else:
        bus = HumilityBus(args.fpga_base, args.humility, args.humility_arg,
                          args.dry_run, args.verbose)

    nor = SpiNor(bus, args.spi_nor)
    if args.take_mux:
        take_mux(bus)
    try:
        nor.check_owner()
        return args.func(nor, args)
    finally:
        if args.take_mux and not args.keep_mux:
            bus.poke(MUX_CTRL, 0)


if __name__ == "__main__":
    sys.exit(main())
