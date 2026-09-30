#!/usr/bin/env python3
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

"""Read a flash part's JEDEC ID through one of the metro FPGA's spi_nor blocks.

This is the FPGA side of cosmo-metro-hf's flash_read_id, driven over the FMC
bus with humility's FmcDemo peek32 and poke32, for images that do not carry the
host-flash task (the FMC demo image) or where the flash is not the part that
task insists on.

Which spi_nor block to talk to depends on which one is wired to the flash you
care about. Normally the host flash is behind the block at 0x100 and the
Versal's flash behind the one at 0x800; the bring-up build with the pins
swapped has them the other way round. --spi-nor picks.

The Versal's flash sits behind the sheet-137 mux, which is pointed at the
Versal unless the FPGA has been granted it. --take-mux sets mux_ctrl.to_fpga and
mux_en, checks mux_status, and clears them again afterwards unless --keep-mux.

Usage
-----
    # bring-up build with the pins swapped: the 0x100 block is on the Versal
    # flash, and the mux has to be taken first
    ./tools/versal_flash_id.py --spi-nor 0x100 --take-mux

    # a normal build: the host flash, no mux involved
    ./tools/versal_flash_id.py --spi-nor 0x100

    # see the humility invocations without touching hardware
    ./tools/versal_flash_id.py --spi-nor 0x100 --take-mux --dry-run
"""

import argparse
import re
import subprocess
import sys
import time

# Byte offsets within a spi_nor block. These mirror
# hdl/ip/vhd/spi_nor_controller/spi_nor_regs.rdl.
SPI_NOR = {
    "SPICR": 0x00,
    "SPISR": 0x04,
    "ADDR": 0x08,
    "DUMMYCYCLES": 0x0C,
    "DATABYTES": 0x10,
    "INSTR": 0x14,
    "TX_FIFO_WDATA": 0x18,
    "RX_FIFO_RDATA": 0x1C,
}
SPICR_SP5_OWNS_FLASH = 1 << 31
SPICR_RX_FIFO_RESET = 1 << 15
SPICR_TX_FIFO_RESET = 1 << 7
SPISR_BUSY = 1 << 0
SPISR_RX_EMPTY = 1 << 6
SPISR_RX_USED_SHIFT = 8
SPISR_RX_USED_MASK = 0x7F

# The Versal flash mux control block, from
# hdl/projects/metro_seq/versal_subsystem/versal_flash_regs.rdl.
MUX_WINDOW = 0x900
MUX_CTRL = 0x00
MUX_STATUS = 0x04
MUX_CTRL_REQUEST = 1 << 0
MUX_CTRL_TO_FPGA = 1 << 1
MUX_CTRL_MUX_EN = 1 << 2
MUX_STATUS_BITS = [
    (1 << 0, "granted"),
    (1 << 1, "seq_owned"),
    (1 << 2, "mux_sel (0 = FPGA, 1 = Versal)"),
    (1 << 3, "mux_en_l"),
    (1 << 4, "versal_held_in_reset"),
]

READ_JEDEC_ID = 0x9F

# A few manufacturer IDs worth naming; anything else is printed raw.
MANUFACTURERS = {
    0x01: "Infineon/Cypress/Spansion",
    0x20: "Micron",
    0x9D: "ISSI",
    0xC2: "Macronix",
    0xEF: "Winbond",
}


class Fmc:
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
                "could not run %r. Is humility on PATH? Use --humility to point at "
                "it, or --dry-run to see the commands without executing them."
                % self.humility
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


def decode_mux_status(value):
    return ", ".join(
        "%s=%d" % (name, 1 if value & bit else 0) for bit, name in MUX_STATUS_BITS
    )


def take_mux(fmc):
    fmc.poke(MUX_WINDOW + MUX_CTRL, MUX_CTRL_TO_FPGA | MUX_CTRL_MUX_EN)
    status = fmc.peek(MUX_WINDOW + MUX_STATUS)
    print("mux_status = 0x%02x: %s" % (status, decode_mux_status(status)))
    if not fmc.dry_run and not status & 1:
        raise SystemExit(
            "the mux was not granted to the FPGA; this image may predate the "
            "to_fpga override"
        )


def release_mux(fmc):
    fmc.poke(MUX_WINDOW + MUX_CTRL, 0)


def read_jedec_id(fmc, window, dry_run):
    def reg(name):
        return window + SPI_NOR[name]

    spicr = fmc.peek(reg("SPICR"))
    if spicr & SPICR_SP5_OWNS_FLASH:
        raise SystemExit(
            "SPICR.sp5_owns_flash is set on the block at 0x%x, so the SP side "
            "is locked out; clear it first" % window
        )

    # Same sequence as cosmo-metro-hf's flash_read_id: clear the FIFOs, ask for
    # three data bytes with no address or dummy cycles, and writing the opcode
    # starts the transaction.
    fmc.poke(reg("SPICR"), SPICR_RX_FIFO_RESET | SPICR_TX_FIFO_RESET)
    fmc.poke(reg("DATABYTES"), 3)
    fmc.poke(reg("ADDR"), 0)
    fmc.poke(reg("DUMMYCYCLES"), 0)
    fmc.poke(reg("INSTR"), READ_JEDEC_ID)

    deadline = time.monotonic() + 2.0
    while True:
        spisr = fmc.peek(reg("SPISR"))
        if dry_run or not spisr & SPISR_BUSY:
            break
        if time.monotonic() > deadline:
            raise SystemExit("spi_nor stayed busy (SPISR = 0x%08x)" % spisr)

    rx_used = (spisr >> SPISR_RX_USED_SHIFT) & SPISR_RX_USED_MASK
    print("SPISR = 0x%08x: busy=%d rx_empty=%d rx_used_wds=%d"
          % (spisr, spisr & SPISR_BUSY, 1 if spisr & SPISR_RX_EMPTY else 0, rx_used))
    if not dry_run and spisr & SPISR_RX_EMPTY:
        raise SystemExit(
            "no data came back into the RX FIFO: the transaction did not run, "
            "which points at the register side rather than the flash"
        )

    word = fmc.peek(reg("RX_FIFO_RDATA"))
    mfr, mem_type, capacity = word.to_bytes(4, "little")[:3]
    return mfr, mem_type, capacity


def main():
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument(
        "--spi-nor", type=lambda s: int(s, 0), default=0x100,
        help="offset of the spi_nor block to use: 0x100 (host flash normally) "
             "or 0x800 (Versal flash normally). Default 0x100.",
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
    parser.add_argument("--humility", default="humility")
    parser.add_argument(
        "--humility-arg", action="append", default=[],
        help="extra argument passed to humility before 'hiffy', repeatable",
    )
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("-v", "--verbose", action="store_true")
    args = parser.parse_args()

    fmc = Fmc(args.fpga_base, args.humility, args.humility_arg, args.dry_run,
              args.verbose)

    if args.take_mux:
        take_mux(fmc)
    try:
        mfr, mem_type, capacity = read_jedec_id(fmc, args.spi_nor, args.dry_run)
    finally:
        if args.take_mux and not args.keep_mux:
            release_mux(fmc)

    if args.dry_run:
        return 0

    print("JEDEC ID: %02x %02x %02x (%s, type 0x%02x, capacity 0x%02x)" % (
        mfr, mem_type, capacity, MANUFACTURERS.get(mfr, "unknown manufacturer"),
        mem_type, capacity))
    if (mfr, mem_type, capacity) in ((0, 0, 0), (0xFF, 0xFF, 0xFF)):
        print("that is not a flash answering: check the part's power, the mux, "
              "and the sclk rate/sample point for these pins")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
