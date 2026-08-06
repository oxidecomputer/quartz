#!/usr/bin/env python3
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

"""Exercise the host-flash path of the FPGA SHA3-256 hashing engine.

Point this at the ROM image that is already programmed into the host flash and
it drives the hashing engine over the FMC bus, using humility's FmcDemo peek32
and poke32, then compares the digest the hardware produced against one computed
here in software.

Sector bypass
-------------
The first sector of the host flash is not part of what we want to measure, so it
is hashed as a run of 0xFF rather than as whatever the flash actually holds. The
engine does that with two registers rather than a dedicated feature:

    PREPEND    = sector size    -- feed this many 0xFF bytes first
    FLASH_ADDR = sector size    -- then start fetching one sector in
    LENGTH     = image size     -- total, counting the 0xFF run

so the message is `0xFF * sector` followed by the image from the second sector
on, which is exactly the image with its first sector blanked. The expected
digest computed here is built the same way, from the ROM file.

Usage
-----
    ./tools/hash_engine_flash_test.py --rom cosmo-host.bin

    # a board that maps the FPGA somewhere other than 0xc0000000
    ./tools/hash_engine_flash_test.py --rom img.bin --hash-offset 0xd0000700

    # see the humility invocations without touching hardware
    ./tools/hash_engine_flash_test.py --rom img.bin --dry-run

    # check the digest and register-packing arithmetic, no hardware needed
    ./tools/hash_engine_flash_test.py --selftest
"""

import argparse
import hashlib
import re
import shutil
import struct
import subprocess
import sys
import time

# Byte offsets within the hashing engine's register window. These mirror
# hdl/ip/vhd/hash_engine/hash_engine_regs.rdl; regenerate that package and
# re-check here if the map ever changes.
REG = {
    "CONTROL": 0x00,
    "CONFIG": 0x04,
    "PREPEND": 0x08,
    "FLASH_ADDR": 0x0C,
    "LENGTH": 0x10,
    "STATUS": 0x14,
    "WDATA": 0x18,
    "PROGRESS": 0x1C,
}
DIGEST0 = 0x20
DIGEST_WORDS = 8

# The engine as the SP sees it: FPGA offset 0x0700 (see cosmo_seq_top.rdl) inside
# the FMC window the STM32 maps the FPGA into at 0xc0000000. FmcDemo.peek32 and
# poke32 take absolute addresses, so this is already one and --base stays at 0.
DEFAULT_HASH_OFFSET = 0xC0000700

# CONTROL bits, both self-clearing.
CTRL_START = 1 << 0
CTRL_ABORT = 1 << 1

# STATUS bits.
ST_BUSY = 1 << 0
ST_DONE = 1 << 1
ST_WFIFO_FULL = 1 << 2
ST_WFIFO_EMPTY = 1 << 3
ST_ABORTED = 1 << 4
ST_CFG_ERR = 1 << 5

# CONFIG.source encoding.
SRC_LOCAL_REG = 0
SRC_HOST_QSPI = 1

# 4 KiB, matching SECTOR_BYTES in the SPI NOR verification component. Override
# with --sector-size if the part in question uses something else.
DEFAULT_SECTOR_SIZE = 0x10000


def status_str(value):
    """Render a STATUS read as something readable in a log."""
    bits = [
        (ST_BUSY, "busy"),
        (ST_DONE, "done"),
        (ST_WFIFO_FULL, "wfifo_full"),
        (ST_WFIFO_EMPTY, "wfifo_empty"),
        (ST_ABORTED, "aborted"),
        (ST_CFG_ERR, "cfg_err"),
    ]
    on = [name for mask, name in bits if value & mask]
    return "0x%08x [%s]" % (value, " ".join(on) if on else "-")


def expected_message(rom, sector_size):
    """The bytes the engine should end up hashing, given the ROM image.

    The first sector is replaced by 0xFF rather than dropped, so the message is
    the same length as the image.
    """
    if len(rom) <= sector_size:
        raise ValueError(
            "ROM is %d bytes, which is not longer than the %d byte sector being "
            "bypassed, so there would be nothing left to hash"
            % (len(rom), sector_size)
        )
    return b"\xff" * sector_size + rom[sector_size:]


def digest_from_words(words):
    """Reassemble DIGEST0..7 into the conventional hex string.

    Each register holds four digest bytes little-endian, and DIGEST0 bits 7:0
    are hash byte 0, so the whole thing is just the words packed little-endian
    end to end.
    """
    if len(words) != DIGEST_WORDS:
        raise ValueError("expected %d digest words, got %d" % (DIGEST_WORDS, len(words)))
    return b"".join(struct.pack("<I", w & 0xFFFFFFFF) for w in words).hex()


class Fmc:
    """Register access over humility's FmcDemo peek32/poke32."""

    # humility prints results in a few shapes depending on version, so pull the
    # last number out of the output rather than matching one exact format.
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
        """Pull a 32-bit result out of humility's output.

        Everything before the last '=>' is dropped so an address echoed back in
        the arguments cannot be mistaken for the result, and the *first* number
        after it is taken rather than the last. A byte-array result is
        reassembled little-endian, which is how a 32-bit peek comes back if the
        idl types it as a buffer.
        """
        tail = text.rsplit("=>", 1)[-1] if "=>" in text else text

        # A list result, e.g. "Ok([0xef, 0xbe, 0xad, 0xde])".
        listing = re.search(r"\[([^\]]*)\]", tail)
        if listing:
            items = [t for t in re.split(r"[,\s]+", listing.group(1)) if t]
            if items:
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
                "raw output was:\n%s\n"
                "If humility prints results in some other shape, _parse in this "
                "script is the place to teach it."
                % (" ".join(cmd or []), text)
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


class HashEngine:
    def __init__(self, fmc, window):
        self.fmc = fmc
        self.window = window

    def _addr(self, reg):
        return self.window + reg

    def read(self, reg):
        return self.fmc.peek(self._addr(reg))

    def write(self, reg, value):
        self.fmc.poke(self._addr(reg), value)

    def status(self):
        return self.read(REG["STATUS"])

    def abort(self):
        self.write(REG["CONTROL"], CTRL_ABORT)

    def configure(self, source, prepend, flash_addr, length):
        self.write(REG["CONFIG"], source)
        self.write(REG["PREPEND"], prepend)
        self.write(REG["FLASH_ADDR"], flash_addr)
        self.write(REG["LENGTH"], length)

    def start(self):
        self.write(REG["CONTROL"], CTRL_START)

    def wait_done(self, timeout_s, poll_s=0.05, progress_cb=None):
        """Poll STATUS until done. Returns the final status word.

        done also means the engine has finished flushing and is ready to run
        again, so it is the right thing to wait on rather than busy going low.
        """
        deadline = time.time() + timeout_s
        while True:
            status = self.status()

            if status & ST_CFG_ERR:
                raise SystemExit(
                    "engine rejected the configuration: %s\n"
                    "That means LENGTH was zero or PREPEND was larger than LENGTH."
                    % status_str(status)
                )
            if status & ST_ABORTED:
                raise SystemExit("hash was aborted: %s" % status_str(status))
            if status & ST_DONE:
                return status

            if time.time() > deadline:
                raise SystemExit(
                    "timed out after %gs waiting for the hash to finish.\n"
                    "  status:   %s\n"
                    "  progress: %d bytes\n"
                    "If progress is not advancing, the engine is most likely not "
                    "getting flash data: check that the SPI NOR controller is idle "
                    "and that nothing else is holding the flash."
                    % (timeout_s, status_str(status), self.read(REG["PROGRESS"]))
                )

            if progress_cb:
                progress_cb(self.read(REG["PROGRESS"]), status)
            time.sleep(poll_s)

    def digest(self):
        return digest_from_words(
            [self.fmc.peek(self._addr(DIGEST0 + 4 * i)) for i in range(DIGEST_WORDS)]
        )


def selftest():
    """Check the pure arithmetic. No hardware involved."""
    failures = []

    def check(name, got, want):
        if got != want:
            failures.append("%s: got %r, want %r" % (name, got, want))
        else:
            print("  ok   %s" % name)

    # Digest word packing. sha3-256("abc") is a published value, and the engine
    # presents it least significant word first with DIGEST0 bits 7:0 as hash
    # byte 0.
    abc = hashlib.sha3_256(b"abc").hexdigest()
    words = [
        int.from_bytes(bytes.fromhex(abc)[4 * i:4 * i + 4], "little")
        for i in range(DIGEST_WORDS)
    ]
    check("DIGEST0 packing", "0x%08x" % words[0], "0xa75d983a")
    check("DIGEST7 packing", "0x%08x" % words[7], "0x32154311")
    check("digest_from_words round trip", digest_from_words(words), abc)

    # Sector bypass: the message is the image with its first sector replaced by
    # 0xFF, so it keeps the image's length.
    rom = bytes(range(256)) * 64          # 16 KiB of non-0xFF data
    msg = expected_message(rom, 0x1000)
    check("bypassed message length", len(msg), len(rom))
    check("first sector blanked", msg[:0x1000], b"\xff" * 0x1000)
    check("remainder untouched", msg[0x1000:], rom[0x1000:])
    check(
        "digest matches a directly built message",
        hashlib.sha3_256(msg).hexdigest(),
        hashlib.sha3_256(b"\xff" * 0x1000 + rom[0x1000:]).hexdigest(),
    )

    # A ROM no longer than the sector leaves nothing to hash.
    try:
        expected_message(b"\x00" * 0x1000, 0x1000)
        failures.append("short ROM should have been rejected")
    except ValueError:
        print("  ok   short ROM rejected")

    # STATUS decoding.
    check("status_str", status_str(ST_BUSY | ST_DONE), "0x00000003 [busy done]")

    # humility output parsing. The exact shape varies, and a value silently
    # parsed from the wrong part of the line would be far worse than a hard
    # failure, so pin the plausible ones.
    cases = [
        ("FmcDemo.peek32() => 0xdeadbeef", 0xDEADBEEF),
        ("FmcDemo.peek32() => Ok(0xdeadbeef)", 0xDEADBEEF),
        ("humility: attached to bar\nFmcDemo.peek32() => 0x00000003", 3),
        # The address appears first, so a parser that grabbed the last number,
        # or ignored the '=>', would get this wrong.
        ("peek32(addr=0x700) => 0x1", 1),
        ("FmcDemo.peek32() => 0", 0),
        ("FmcDemo.peek32() => Ok([0xef, 0xbe, 0xad, 0xde])", 0xDEADBEEF),
        ("FmcDemo.peek32() => 3735928559", 3735928559),
    ]
    for text, want in cases:
        check("parse %r" % text.splitlines()[-1][:44], Fmc._parse(text), want)

    if failures:
        print("\nFAIL")
        for f in failures:
            print("  " + f)
        return 1
    print("\nall self-tests passed")
    return 0


def auto_int(text):
    return int(text, 0)


def main():
    ap = argparse.ArgumentParser(
        description="Exercise the host-flash path of the FPGA SHA3-256 hashing engine.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__.split("Usage\n-----\n", 1)[-1],
    )
    ap.add_argument("--rom", help="ROM image already programmed into the host flash")
    ap.add_argument(
        "--sector-size", type=auto_int, default=DEFAULT_SECTOR_SIZE,
        help="bytes in the bypassed first sector (default 0x%x)" % DEFAULT_SECTOR_SIZE,
    )
    ap.add_argument(
        "--no-bypass", action="store_true",
        help="hash the flash straight through from offset 0 with no 0xFF run. "
             "The expected digest is then the ROM file as-is, which only matches "
             "if the first sector on the part really does hold the image.",
    )
    ap.add_argument(
        "--length", type=auto_int,
        help="bytes to hash (default: the ROM file's size)",
    )
    ap.add_argument(
        "--base", type=auto_int, default=0,
        help="added to every address. --hash-offset already carries the FMC "
             "window base, so this is only needed to shift the whole map "
             "(default 0)",
    )
    ap.add_argument(
        "--hash-offset", type=auto_int, default=DEFAULT_HASH_OFFSET,
        help="absolute address of the engine's register window "
             "(default 0x%x)" % DEFAULT_HASH_OFFSET,
    )
    ap.add_argument("--humility", default="humility", help="humility binary")
    ap.add_argument(
        "--humility-arg", action="append", default=[], metavar="ARG",
        help="extra argument passed to humility before 'hiffy', repeatable "
             "(e.g. --humility-arg -a --humility-arg /path/to/archive.zip)",
    )
    ap.add_argument(
        "--timeout", type=float, default=120.0,
        help="seconds to wait for the hash to finish (default 120)",
    )
    ap.add_argument("--dry-run", action="store_true",
                    help="print the humility commands instead of running them")
    ap.add_argument("-v", "--verbose", action="store_true",
                    help="echo every humility invocation")
    ap.add_argument("--selftest", action="store_true",
                    help="check the digest and packing arithmetic, then exit")
    args = ap.parse_args()

    if args.selftest:
        return selftest()

    if not args.rom:
        ap.error("--rom is required (or use --selftest)")

    with open(args.rom, "rb") as f:
        rom = f.read()
    if not rom:
        raise SystemExit("%s is empty" % args.rom)

    if args.no_bypass:
        prepend = 0
        flash_addr = 0
        message = rom
    else:
        prepend = args.sector_size
        flash_addr = args.sector_size
        try:
            message = expected_message(rom, args.sector_size)
        except ValueError as exc:
            raise SystemExit(str(exc))

    length = args.length if args.length is not None else len(message)
    if length > len(message):
        raise SystemExit(
            "--length %d is longer than the %d bytes the ROM file can account for"
            % (length, len(message))
        )
    message = message[:length]
    if length < prepend:
        raise SystemExit(
            "--length %d is smaller than the %d byte 0xFF run, which the engine "
            "will reject" % (length, prepend)
        )

    expected = hashlib.sha3_256(message).hexdigest()

    print("ROM file        : %s (%d bytes)" % (args.rom, len(rom)))
    if args.no_bypass:
        print("Sector bypass   : disabled, hashing flash from offset 0")
    else:
        print("Sector bypass   : first 0x%x bytes fed as 0xFF, flash read from 0x%x"
              % (args.sector_size, flash_addr))
    print("Bytes to hash   : %d" % length)
    print("Engine window   : 0x%x (base 0x%x)" % (args.hash_offset, args.base))
    print("Expected digest : %s" % expected)
    print()

    fmc = Fmc(
        base=args.base,
        humility=args.humility,
        extra_args=args.humility_arg,
        dry_run=args.dry_run,
        verbose=args.verbose,
    )
    if not args.dry_run and shutil.which(args.humility) is None:
        raise SystemExit(
            "%r not found on PATH. Use --humility to point at it, or --dry-run."
            % args.humility
        )

    eng = HashEngine(fmc, args.hash_offset)

    # Clear anything left over from a previous run. An abort on an idle engine
    # is harmless, and if one was mid-flight this resynchronises the flash
    # channel before we start.
    print("Aborting any run in flight...")
    eng.abort()
    if not args.dry_run:
        deadline = time.time() + 10
        while eng.status() & ST_BUSY:
            if time.time() > deadline:
                raise SystemExit(
                    "engine still busy 10s after an abort: %s\n"
                    "An abort during a flash read has to drain the bytes the "
                    "controller still owes, but that should not take this long."
                    % status_str(eng.status())
                )
            time.sleep(0.05)

    print("Configuring...")
    eng.configure(SRC_HOST_QSPI, prepend, flash_addr, length)

    print("Starting...")
    eng.start()

    if args.dry_run:
        print("\n(dry run: reading STATUS, PROGRESS and DIGEST0..7 would follow)")
        for i in range(DIGEST_WORDS):
            fmc.peek(args.hash_offset + DIGEST0 + 4 * i)
        return 0

    last = [-1]

    def show(progress, status):
        if progress != last[0]:
            last[0] = progress
            pct = (100.0 * progress / length) if length else 0.0
            print("\r  %d/%d bytes (%.1f%%)  %s"
                  % (progress, length, pct, status_str(status)), end="", flush=True)

    started = time.time()
    status = eng.wait_done(args.timeout, progress_cb=show)
    elapsed = time.time() - started
    print("\r  %d/%d bytes (100.0%%)  %s" % (length, length, status_str(status)))

    progress = eng.read(REG["PROGRESS"])
    actual = eng.digest()

    print()
    print("Elapsed         : %.2fs (%.1f KiB/s)"
          % (elapsed, (length / 1024.0 / elapsed) if elapsed > 0 else 0.0))
    print("Bytes processed : %d" % progress)
    print("Expected digest : %s" % expected)
    print("Hardware digest : %s" % actual)
    print()

    ok = True
    if progress != length:
        print("MISMATCH: engine reports %d bytes processed, expected %d"
              % (progress, length))
        ok = False
    if actual != expected:
        print("MISMATCH: digest differs")
        # A digest over a shorter or longer run is the usual cause, so say
        # whether the flash contents or the framing is the more likely suspect.
        if progress == length:
            print("  Byte count matched, so the framing is right and the flash "
                  "contents differ from the ROM file.")
            print("  Check the image really is programmed, and that "
                  "--sector-size (0x%x) matches the part." % args.sector_size)
        ok = False

    if ok:
        print("PASS")
        return 0
    print("FAIL")
    return 1


if __name__ == "__main__":
    sys.exit(main())
