#!/usr/bin/env python3
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

"""Run the published SHA3-256 test vectors against the FPGA hashing engine.

Vectors are the ones from https://di-mgt.com.au/sha_testvectors.html, which are
in turn the NIST/NESSIE standard set. They are fed through the engine's manual
path: CONFIG.source = LOCAL_REG and the message written a word at a time into
WDATA, so this exercises the core and the sponge without involving the flash.

Every digest in the table below was checked against Python's hashlib before being
committed, and --selftest re-checks them, so a failure here is the hardware
disagreeing with the standard rather than a transcription slip.

Three of the six vectors need comment:

  empty       The engine cannot hash a zero length message: AXI streaming has no
              zero beat packet, so there is no way to mark a last byte without
              also presenting one. Rather than skip it, this checks the engine
              *rejects* LENGTH = 0 by setting STATUS.cfg_err, which is the
              documented behaviour, and compares the known digest in software.

  million-a   1,000,000 bytes is 250,000 WDATA writes, and every register access
              is a separate humility process. That runs for hours, so it is off
              by default behind --include-million.

  extreme     ~1 GB. At the same rate that is weeks. Never run against hardware;
              the table keeps it only so --selftest covers it.

Usage
-----
    ./tools/hash_engine_vectors_test.py                 # the four short vectors
    ./tools/hash_engine_vectors_test.py --include-million
    ./tools/hash_engine_vectors_test.py --dry-run
    ./tools/hash_engine_vectors_test.py --selftest      # no hardware needed
"""

import argparse
import hashlib
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

# Register map, humility plumbing and status decoding all live in the flash test
# already; there is no reason for a second copy of any of it.
from hash_engine_flash_test import (  # noqa: E402
    DEFAULT_HASH_OFFSET,
    DIGEST_WORDS,
    REG,
    SRC_LOCAL_REG,
    ST_ABORTED,
    ST_BUSY,
    ST_CFG_ERR,
    ST_DONE,
    ST_WFIFO_FULL,
    Fmc,
    HashEngine,
    auto_int,
    status_str,
)

# The software data FIFO is 64 words deep (SW_FIFO_DEPTH in hash_engine_top).
SW_FIFO_WORDS = 64

# Poll wfifo_full once per this many writes rather than before every one. Safe by
# construction: even if the engine consumed nothing at all, a batch this size
# cannot overflow a FIFO four times as deep, and we would see full on the next
# poll. In practice the engine drains at a byte per clock and the bus delivers
# four bytes per humility process, so it is never remotely close.
POLL_EVERY = SW_FIFO_WORDS // 4


def _rep(block, count):
    return block * count


# name, message bytes (or a thunk for the big ones), published digest.
# Messages that would cost real memory are built lazily.
VECTORS = [
    ("abc", lambda: b"abc",
     "3a985da74fe225b2045c172d6bd390bd855f086e3e9d525b46bfe24511431532"),
    ("empty", lambda: b"",
     "a7ffc6f8bf1ed76651c14756a061d662f580ff4de43b49fa82d80a4b80f8434a"),
    ("448-bit", lambda: b"abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq",
     "41c0dba2a9d6240849100376a8235e2c82e1b9998a999e21db32dd97496d3376"),
    ("896-bit",
     lambda: b"abcdefghbcdefghicdefghijdefghijkefghijklfghijklmghijklmn"
             b"hijklmnoijklmnopjklmnopqklmnopqrlmnopqrsmnopqrstnopqrstu",
     "916f6061fe879741ca6469b43971dfdb28b1a32dc36cb3254e812be27aad1d18"),
    ("million-a", lambda: _rep(b"a", 1000000),
     "5c8875ae474a3634ba4fd55ec85bffd661f32aca75c6d699d0cdcb6c115891c1"),
    ("extreme",
     lambda: _rep(b"abcdefghbcdefghicdefghijdefghijkefghijklfghijklmghijklmnhijklmno",
                  16777216),
     "ecbbc42cbf296603acb2c6bc0410ef4378bafb24b710357f12df607758b33e2b"),
]

# Vectors that are impractical or impossible to drive over the register interface.
SKIP_ALWAYS = {"extreme"}
SKIP_UNLESS_ASKED = {"million-a"}
# Not a skip: run as a rejection check instead of a hash.
REJECT_CASE = "empty"


def to_words(data):
    """Message bytes as the 32 bit words WDATA takes, least significant first.

    A trailing partial word is zero filled. LENGTH bounds what the engine
    consumes, so the padding is never part of the message.
    """
    return [
        int.from_bytes(data[i:i + 4].ljust(4, b"\x00"), "little")
        for i in range(0, len(data), 4)
    ]


def feed(eng, data, progress_cb=None):
    """Write the message into WDATA, respecting the FIFO's full flag."""
    words = to_words(data)

    for i, word in enumerate(words):
        if i % POLL_EVERY == 0:
            while eng.status() & ST_WFIFO_FULL:
                time.sleep(0.01)
            if progress_cb and i:
                progress_cb(i * 4, len(data))

        eng.write(REG["WDATA"], word)

    return len(words)


def run_vector(eng, name, data, expected, timeout_s, verbose=False):
    """Hash one vector through the manual path and check the digest."""
    eng.abort()
    deadline = time.time() + 10
    while eng.status() & ST_BUSY:
        if time.time() > deadline:
            print("    engine still busy after abort: %s" % status_str(eng.status()))
            return False
        time.sleep(0.02)

    eng.configure(SRC_LOCAL_REG, prepend=0, flash_addr=0, length=len(data))
    eng.start()

    started = time.time()

    def show(done_bytes, total):
        pct = 100.0 * done_bytes / total if total else 0.0
        print("\r    fed %d/%d bytes (%.1f%%)" % (done_bytes, total, pct),
              end="", flush=True)

    nwords = feed(eng, data, progress_cb=show if len(data) > 4096 else None)
    if len(data) > 4096:
        print("\r    fed %d/%d bytes (100.0%%)      " % (len(data), len(data)))

    status = eng.wait_done(timeout_s)
    elapsed = time.time() - started

    progress = eng.read(REG["PROGRESS"])
    actual = eng.digest()

    ok = True
    if progress != len(data):
        print("    PROGRESS %d, expected %d" % (progress, len(data)))
        ok = False
    if actual != expected:
        print("    expected %s" % expected)
        print("    got      %s" % actual)
        ok = False

    if verbose or not ok:
        print("    %d words, %.1fs, status %s" % (nwords, elapsed, status_str(status)))

    return ok


def run_reject_case(eng, expected, verbose=False):
    """The empty message: check the engine refuses it rather than hangs."""
    eng.abort()
    time.sleep(0.05)

    eng.configure(SRC_LOCAL_REG, prepend=0, flash_addr=0, length=0)
    eng.start()
    time.sleep(0.2)

    status = eng.status()
    ok = True

    if not status & ST_CFG_ERR:
        print("    expected cfg_err for LENGTH = 0, got %s" % status_str(status))
        ok = False
    if status & ST_BUSY:
        print("    engine went busy on a zero length message: %s" % status_str(status))
        ok = False

    if ok:
        print("    correctly rejected (cfg_err), known digest %s..." % expected[:16])
    if verbose:
        print("    status %s" % status_str(status))

    return ok


def selftest():
    """Check the vector table against hashlib. No hardware."""
    failures = []

    for name, build, expected in VECTORS:
        got = hashlib.sha3_256(build()).hexdigest()
        if got == expected:
            print("  ok   %-11s %d bytes" % (name, len(build())))
        else:
            failures.append("%s: table says %s, hashlib says %s" % (name, expected, got))

    # The packing WDATA expects, checked end to end on a ragged length.
    msg = b"abcde"
    words = to_words(msg)
    if words != [0x64636261, 0x00000065]:
        failures.append("to_words(%r) = %r" % (msg, [hex(w) for w in words]))
    else:
        print("  ok   WDATA word packing, least significant byte first")

    if failures:
        print("\nFAIL")
        for f in failures:
            print("  " + f)
        return 1

    print("\nvector table matches hashlib")
    return 0


def main():
    ap = argparse.ArgumentParser(
        description="Run the published SHA3-256 test vectors against the FPGA "
                    "hashing engine over its manual (LOCAL_REG) path.",
    )
    ap.add_argument("--include-million", action="store_true",
                    help="also run the one-million-'a' vector. 250,000 register "
                         "writes, so expect hours rather than minutes")
    ap.add_argument("--only", metavar="NAME",
                    help="run just this vector (%s)"
                         % ", ".join(n for n, _, _ in VECTORS))
    ap.add_argument("--base", type=auto_int, default=0,
                    help="added to every address (default 0)")
    ap.add_argument("--hash-offset", type=auto_int, default=DEFAULT_HASH_OFFSET,
                    help="absolute address of the engine's register window "
                         "(default 0x%x)" % DEFAULT_HASH_OFFSET)
    ap.add_argument("--humility", default="humility", help="humility binary")
    ap.add_argument("--humility-arg", action="append", default=[], metavar="ARG",
                    help="extra argument passed to humility before 'hiffy'")
    ap.add_argument("--timeout", type=float, default=300.0,
                    help="seconds to wait for a hash to finish (default 300)")
    ap.add_argument("--dry-run", action="store_true",
                    help="print the humility commands instead of running them")
    ap.add_argument("-v", "--verbose", action="store_true")
    ap.add_argument("--selftest", action="store_true",
                    help="check the vector table against hashlib, then exit")
    args = ap.parse_args()

    if args.selftest:
        return selftest()

    fmc = Fmc(
        base=args.base,
        humility=args.humility,
        extra_args=args.humility_arg,
        dry_run=args.dry_run,
        verbose=args.verbose,
    )
    eng = HashEngine(fmc, args.hash_offset)

    print("Engine window : 0x%x (base 0x%x)" % (args.hash_offset, args.base))
    print("Source        : LOCAL_REG, message written through WDATA")
    print()

    results = []

    for name, build, expected in VECTORS:
        if args.only and name != args.only:
            continue

        if not args.only:
            if name in SKIP_ALWAYS:
                print("%-11s SKIP  ~1 GB over the register interface is not "
                      "practical" % name)
                results.append((name, None))
                continue
            if name in SKIP_UNLESS_ASKED and not args.include_million:
                print("%-11s SKIP  pass --include-million to run it "
                      "(250,000 register writes)" % name)
                results.append((name, None))
                continue

        if name in SKIP_ALWAYS:
            print("%-11s refusing: ~1 GB over the register interface would take "
                  "weeks" % name)
            results.append((name, None))
            continue

        data = build()

        if name == REJECT_CASE:
            print("%-11s zero length, expecting a rejection" % name)
            ok = True if args.dry_run else run_reject_case(eng, expected, args.verbose)
        else:
            n = len(data)
            est = ""
            if n > 100000:
                est = "  (~%d register writes)" % (n // 4)
            print("%-11s %d bytes%s" % (name, n, est))
            ok = True
            if args.dry_run:
                eng.configure(SRC_LOCAL_REG, prepend=0, flash_addr=0, length=n)
                eng.start()
                print("    (dry run: %d WDATA writes would follow)" % len(to_words(data)))
            else:
                ok = run_vector(eng, name, data, expected, args.timeout, args.verbose)

        print("%-11s %s" % ("", "PASS" if ok else "FAIL"))
        results.append((name, ok))

    print()
    ran = [r for _, r in results if r is not None]
    skipped = len([r for _, r in results if r is None])
    failed = len([r for r in ran if not r])

    print("%d run, %d passed, %d failed, %d skipped"
          % (len(ran), len(ran) - failed, failed, skipped))

    if args.dry_run:
        return 0
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
