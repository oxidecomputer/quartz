#!/usr/bin/env python3
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

"""FMC interface frequency sweep and verification driver.

Drives the FPGA's FMC target through hubris' fmc-demo-server: bulk traffic
uses the UDP peek/poke protocol (tools/speeker/udp_if.py), and the FMC_CLK
frequency is changed between phases through humility hiffy calls to the
FmcDemo timing Idol operations, and each change is verified by reading
BTR1 back.

The phases are ordered so that a timing miss at a new frequency shows up as
bad data before it can show up as bus contention: reads of a known-constant
register first (the SP never drives the bus during read data phases, so a
miscapture is data-corruption-only), then scratch write/readback, then
batched back-to-back stress, then a seeded random soak, then a throughput
measurement.

Usage
-----
    # sanity run at the current frequency
    ./tools/fmc_sweep/fmc_sweep.py --ip fe80::0c1d:beff:fe3f:0001 --interface eno1

    # sweep 50 -> 66.67 -> 100 MHz (CLKDIV divisor values, i.e. kernel/N)
    ./tools/fmc_sweep/fmc_sweep.py --ip ... --interface eno1 \
        --sweep 4,3,2 --archive /path/to/build-grapefruit.zip

    # frequency control done by hand (or by re-flashing), just verify
    ./tools/fmc_sweep/fmc_sweep.py --ip ... --interface eno1 --no-timing-control

Notes
-----
* --sweep takes *divisor* values (FMC_CLK = 200 MHz / N), so 4 = 50 MHz,
  3 = 66.67 MHz, 2 = 100 MHz. The Idol op takes the same divisor and
  subtracts one for the register field itself.
* Neither board exposes a bulk R/W RAM over FMC, so bulk traffic is split:
  back-to-back *reads* sweep a read-only region (default: the eSPI post-code
  buffer at FPGA offset 0x8100, an external capture mem -- AXI writes to it
  are silently dropped, which is exactly why it cannot be used for write
  verification), and back-to-back *writes* hammer a single R/W scribble
  register (default: the info block scratchpad at offset 0x10). Write
  verification is last-value-plus-ordering here; per-word write verification
  is the simulation suite's job. Do NOT point --scratch-addr at
  fpga_checksum (offset 0xC): hubris uses it to decide whether the FPGA
  needs reprogramming.
* On any phase failure the sweep restores the baseline divisor and
  re-verifies phase A so the board is left usable.
"""

import argparse
import json
import os
import random
import re
import subprocess
import sys
import time

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from speeker.udp_if import Request, UDPMem  # noqa: E402

FPGA_WINDOW = 0xC0000000
KERNEL_CLK_MHZ = 200.0
# ops per packet: each peek_adv4 is 1 byte, each poke_adv4 is 5 bytes, plus
# the 2-byte header and 6-byte address op; 128 words stays well inside the
# 1500-byte cap in both directions (a read reply is 4 bytes per word).
BATCH_WORDS = 128


class TimingCtl:
    """FMC_CLK control through humility hiffy FmcDemo calls."""

    def __init__(self, humility, archive, dry_run=False, verbose=False):
        self.cmd_base = [humility]
        if archive:
            self.cmd_base += ["-a", archive]
        self.dry_run = dry_run
        self.verbose = verbose

    def _run(self, call, args):
        cmd = list(self.cmd_base) + ["hiffy", "-c", call]
        for key, value in args:
            cmd += ["-a", "%s=%s" % (key, value)]
        if self.verbose or self.dry_run:
            print("    $ " + " ".join(cmd))
        if self.dry_run:
            return
        out = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
        # humility exits 0 even when the served op returns Err, including
        # "<server died>" from a task that faulted and restarted, so the
        # output text has to be checked too.
        if out.returncode != 0 or "Err(" in out.stdout:
            raise SystemExit(
                "humility hiffy failed: %s\n%s%s"
                % (" ".join(cmd), out.stdout, out.stderr)
            )

    def set_divisor(self, divisor):
        self._run("FmcDemo.set_clock_divider", [("n", str(divisor))])

    def get_btr1(self):
        """FMC_BTR1 readback via the get_btr1 Idol op, or None on older
        firmware / dry runs. CLKDIV is bits [23:20]."""
        if self.dry_run:
            return None
        cmd = list(self.cmd_base) + ["hiffy", "-c", "FmcDemo.get_btr1"]
        try:
            out = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
        except (subprocess.TimeoutExpired, FileNotFoundError):
            return None
        if out.returncode != 0 or "Err(" in out.stdout:
            return None
        # parse only the success-reply form "FmcDemo.get_btr1() => <value>";
        # anything looser can match numbers inside an Err message
        m = re.search(r"=>\s*(0x[0-9a-fA-F]+|\d+)\s*$", out.stdout.strip())
        return int(m.group(1), 0) if m else None

    def verify_divisor(self, divisor):
        """Returns (btr1, ok_or_None): ok compares the CLKDIV field against
        what set_divisor should have programmed (divisor - 1); None when the
        firmware has no readback op."""
        btr1 = self.get_btr1()
        if btr1 is None:
            return None, None
        clkdiv = (btr1 >> 20) & 0xF
        return btr1, clkdiv == divisor - 1

    def system_time(self):
        """Kernel tick count from `humility tasks`, or None if it could not
        be read. Ticks reset on an SP reboot, which is how a hang-then-
        watchdog event is told apart from a dropped packet: the tick clock
        going backwards across a step means the SP restarted under us."""
        if self.dry_run:
            return None
        cmd = list(self.cmd_base) + ["tasks"]
        try:
            out = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
        except (subprocess.TimeoutExpired, FileNotFoundError):
            return None
        if out.returncode != 0:
            return None
        m = re.search(r"system time = (\d+)", out.stdout)
        return int(m.group(1)) if m else None


def freq_mhz(divisor):
    return KERNEL_CLK_MHZ / divisor


def batched_read(mem, base, count):
    """Read count 32-bit words starting at base using peek_adv4 batches."""
    words = []
    for chunk_at in range(0, count, BATCH_WORDS):
        n = min(BATCH_WORDS, count - chunk_at)
        req = Request()
        req.set_address(base + 4 * chunk_at)
        req.add_read32_advances(n)
        resp = mem.execute_prebuilt_request(req)
        words += [r.payload for r in resp.expected_responses]
    return words


def phase_a_const_reads(mem, args, golden):
    """Repeated single reads of a known-constant register, with gaps."""
    seen = set()
    for i in range(args.const_iters):
        seen.add(mem.read32(args.const_addr))
        time.sleep(0.001)
    ok = len(seen) == 1 and (golden is None or seen == {golden})
    return ok, {"values": sorted("0x%08x" % v for v in seen)}


def phase_b_scratch(mem, args):
    """Single write/readback of walking and random patterns."""
    addr = args.scratch_addr
    patterns = (
        [1 << b for b in range(32)]
        + [0xFFFFFFFF ^ (1 << b) for b in range(32)]
        + [0x00000000, 0xFFFFFFFF, 0xA5A5A5A5, 0x5A5A5A5A]
    )
    bad = []
    for pat in patterns:
        mem.write32(addr, pat)
        got = mem.read32(addr)
        if got != pat:
            bad.append({"wrote": "0x%08x" % pat, "read": "0x%08x" % got})
    return not bad, {"patterns": len(patterns), "mismatches": bad[:8]}


def scratch_write_burst(mem, addr, values):
    """Back-to-back non-advancing writes to one register per packet batch."""
    for chunk_at in range(0, len(values), BATCH_WORDS):
        chunk = values[chunk_at : chunk_at + BATCH_WORDS]
        req = Request()
        req.set_address(addr)
        req.add_write32s(chunk)
        mem.execute_prebuilt_request(req)


def phase_c_stress(mem, args, rng):
    """Back-to-back stress: a write burst into the scratch register (posted
    writes queue back-to-back; the last value read back proves ordering and
    that nothing was dropped or hung), then two read sweeps of the read-only
    stress region compared against each other (content is arbitrary but must
    be stable)."""
    values = [rng.getrandbits(32) for _ in range(args.stress_words)]
    scratch_write_burst(mem, args.scratch_addr, values)
    got = mem.read32(args.scratch_addr)
    bad = []
    if got != values[-1]:
        bad.append({"scratch_last": "0x%08x" % values[-1],
                    "read": "0x%08x" % got})
    pass1 = batched_read(mem, args.stress_base, args.stress_words)
    pass2 = batched_read(mem, args.stress_base, args.stress_words)
    for i, (x, y) in enumerate(zip(pass1, pass2)):
        if x != y and len(bad) < 8:
            bad.append({"index": i, "pass1": "0x%08x" % x, "pass2": "0x%08x" % y})
    return not bad, {"write_burst": len(values), "read_words": args.stress_words,
                     "mismatches": bad}


def phase_d_soak(mem, args, rng):
    """Seeded random mix of scratch writes/readbacks, constant reads, and
    read-region bursts, scoreboarding the scratch register and the golden
    constant. Runs for --soak-ops operations or --soak-seconds, whichever
    lasts longer (each op is one UDP round trip, so op counts alone finish
    in seconds)."""
    snapshot = batched_read(mem, args.stress_base, args.stress_words)
    golden = mem.read32(args.const_addr)
    last_scratch = None
    bad = []
    ops = 0
    deadline = time.monotonic() + args.soak_seconds
    while ops < args.soak_ops or time.monotonic() < deadline:
        ops += 1
        op = rng.randrange(4)
        if op == 0:
            last_scratch = rng.getrandbits(32)
            mem.write32(args.scratch_addr, last_scratch)
        elif op == 1 and last_scratch is not None:
            got = mem.read32(args.scratch_addr)
            if got != last_scratch and len(bad) < 8:
                bad.append({"scratch_expect": "0x%08x" % last_scratch,
                            "read": "0x%08x" % got})
        elif op == 2:
            got = mem.read32(args.const_addr)
            if got != golden and len(bad) < 8:
                bad.append({"const_expect": "0x%08x" % golden,
                            "read": "0x%08x" % got})
        else:
            index = rng.randrange(args.stress_words - 16)
            got = batched_read(mem, args.stress_base + 4 * index, 16)
            if got != snapshot[index : index + 16] and len(bad) < 8:
                bad.append({"region_index": index})
        if bad and len(bad) >= 8:
            break  # no point soaking further on a badly broken link
    return not bad, {"ops": ops, "mismatches": bad}


def _timed_block_op(mem, build_request, small, large, repeats=5):
    """Median duration delta between a `large`-count and a `small`-count
    server-side block op: the round trip, stack, and per-packet costs cancel,
    leaving (large - small) bus accesses. Returns (seconds_per_word, checksum
    of the last large op)."""
    def run(count):
        req = build_request(count)
        t0 = time.monotonic()
        resp = mem.execute_prebuilt_request(req)
        dt = time.monotonic() - t0
        payload = resp.expected_responses[0].payload if resp.expected_responses else None
        return dt, payload
    deltas = []
    checksum = None
    for _ in range(repeats):
        t_small, _ = run(small)
        t_large, checksum = run(large)
        deltas.append(t_large - t_small)
    deltas.sort()
    return deltas[len(deltas) // 2] / (large - small), checksum


def phase_e_throughput(mem, args, rng):
    """FMC line rate via the server-side block ops (delta-timed so network,
    stack, and per-packet costs cancel), with the wire-level batched numbers
    kept for reference. Falls back to wire-level only against firmware
    without ops 17-19."""
    results = {}
    ok = True

    # wire-level reference numbers (dominated by per-word network bytes)
    values = [rng.getrandbits(32) for _ in range(args.stress_words)]
    t0 = time.monotonic()
    scratch_write_burst(mem, args.scratch_addr, values)
    t_write = time.monotonic() - t0
    ok = mem.read32(args.scratch_addr) == values[-1]
    t0 = time.monotonic()
    snapshot = batched_read(mem, args.stress_base, args.stress_words)
    t_read = time.monotonic() - t0
    nbytes = 4 * args.stress_words
    results["wire_write_MBps"] = round(nbytes / t_write / 1e6, 3)
    results["wire_read_MBps"] = round(nbytes / t_read / 1e6, 3)

    n = 200
    t0 = time.monotonic()
    for _ in range(n):
        mem.read32(args.const_addr)
    results["single_read_us"] = round((time.monotonic() - t0) / n * 1e6, 1)

    # bus-level numbers via ops 17-19
    try:
        golden = mem.read32(args.const_addr)
        retried_before = mem.timeouts_retried

        def rd_req(count):
            req = Request()
            req.set_address(args.stress_base)
            req.add_peek_block_checksum(count, advance=True)
            return req

        spw, checksum = _timed_block_op(mem, rd_req, 64, args.stress_words)
        results["fmc_read_MBps"] = round(4 / spw / 1e6, 2)
        results["fmc_read_ns_per_word"] = round(spw * 1e9)
        expect = sum(snapshot) & 0xFFFFFFFF
        if checksum != expect:
            ok = False
            results["read_checksum_mismatch"] = {
                "got": "0x%08x" % checksum, "expect": "0x%08x" % expect}

        def rdf_req(count):
            req = Request()
            req.set_address(args.const_addr)
            req.add_peek_block_checksum(count, advance=False)
            return req

        spw, checksum = _timed_block_op(mem, rdf_req, 64, 8192)
        results["fmc_read_fixed_ns_per_word"] = round(spw * 1e9)
        if checksum != (golden * 8192) & 0xFFFFFFFF:
            ok = False
            results["fixed_checksum_mismatch"] = "0x%08x" % checksum

        fill_value = rng.getrandbits(32)

        def wr_req(count):
            req = Request()
            req.set_address(args.scratch_addr)
            req.add_poke_block_fill(count, fill_value)
            return req

        spw, _ = _timed_block_op(mem, wr_req, 64, 8192)
        results["fmc_write_MBps"] = round(4 / spw / 1e6, 2)
        results["fmc_write_ns_per_word"] = round(spw * 1e9)
        if mem.read32(args.scratch_addr) != fill_value:
            ok = False
            results["fill_readback_mismatch"] = True
        if mem.timeouts_retried != retried_before:
            # a resend during a timed op makes that sample garbage
            results["retried_during_timing"] = True
    except Exception as exc:
        results["block_ops"] = "unsupported or failed: %r" % exc

    results["note"] = ("fmc_* numbers are bus line rate (delta-timed block "
                       "ops); wire_* include per-word network cost and are "
                       "insensitive to the FMC clock")
    return ok, results


PHASES = [
    ("A_const_reads", phase_a_const_reads),
    ("B_scratch", phase_b_scratch),
    ("C_stress", phase_c_stress),
    ("D_soak", phase_d_soak),
    ("E_throughput", phase_e_throughput),
]


def run_phases(mem, args, rng, golden):
    results = {}
    all_ok = True
    for name, fn in PHASES:
        if name == "A_const_reads":
            ok, detail = fn(mem, args, golden)
        elif name == "B_scratch":
            ok, detail = fn(mem, args)
        else:
            ok, detail = fn(mem, args, rng)
        results[name] = {"ok": ok, **detail}
        status = "ok" if ok else "FAIL"
        print("  %-16s %s  %s" % (name, status, json.dumps(detail)[:120]))
        if not ok:
            all_ok = False
            break  # keep the electrical exposure of later phases off a bad link
    return all_ok, results


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--ip", required=True, help="SP link-local IPv6 address")
    ap.add_argument("--interface", required=True, help="host network interface")
    ap.add_argument("--port", type=int, default=11114)
    ap.add_argument("--sweep", default=None,
                    help="comma-separated FMC_CLK divisors to sweep, e.g. 4,3,2")
    ap.add_argument("--baseline-divisor", type=int, default=4,
                    help="known-good divisor to calibrate at and restore to")
    ap.add_argument("--no-timing-control", action="store_true",
                    help="never call humility; frequency is managed externally")
    ap.add_argument("--humility", default="humility")
    ap.add_argument("--archive", default=None, help="hubris archive for humility")
    ap.add_argument("--const-addr", type=lambda x: int(x, 0),
                    default=FPGA_WINDOW,
                    help="address of a read-only constant register")
    ap.add_argument("--const-iters", type=int, default=50)
    ap.add_argument("--scratch-addr", type=lambda x: int(x, 0),
                    default=FPGA_WINDOW + 0x10,
                    help="address of a harmless 32-bit r/w scratch register "
                         "(default: info block scratchpad; never point this "
                         "at fpga_checksum)")
    ap.add_argument("--stress-base", type=lambda x: int(x, 0),
                    default=FPGA_WINDOW + 0x8100,
                    help="base of a readable region for bulk read traffic "
                         "(default: eSPI post-code buffer; reads only, its "
                         "content just has to be stable during the run)")
    ap.add_argument("--stress-words", type=int, default=1024)
    ap.add_argument("--soak-ops", type=int, default=500,
                    help="minimum soak operations (each is one UDP round trip)")
    ap.add_argument("--soak-seconds", type=int, default=0,
                    help="minimum soak duration; the soak runs until BOTH "
                         "this and --soak-ops are satisfied. Applies to every "
                         "divisor in a sweep, so budget accordingly.")
    ap.add_argument("--udp-retries", type=int, default=3,
                    help="resend attempts after a UDP timeout before a step "
                         "fails (0 = old fail-on-first-loss behavior)")
    ap.add_argument("--seed", type=int, default=0x1DE)
    ap.add_argument("--json", default=None, help="write results here")
    ap.add_argument("--dry-run", action="store_true",
                    help="print humility commands without running them")
    args = ap.parse_args()

    # retries make a dropped frame on a flaky link (USB NICs especially) a
    # logged statistic instead of a dead hour-long soak; three consecutive
    # losses still fails the step, which is the "target actually gone" case
    mem = UDPMem(args.ip, args.interface, target_port=args.port,
                 retries=args.udp_retries)
    # The archive enables observation (BTR1 readback, SP uptime/reboot
    # detection) even when frequency control is off; --no-timing-control
    # only means "never change the divisor" -- the mode for soaking a board
    # at its kernel-configured boot frequency.
    ctl = TimingCtl(args.humility, args.archive,
                    dry_run=args.dry_run) if args.archive else None
    control = ctl is not None and not args.no_timing_control

    report = {"seed": args.seed, "steps": []}

    # Calibrate the constant register at the known-good divisor.
    if control:
        ctl.set_divisor(args.baseline_divisor)
        time.sleep(0.1)
    golden = mem.read32(args.const_addr)
    print("golden const read @%s: 0x%08x" % (hex(args.const_addr), golden))

    if args.sweep:
        if not control:
            raise SystemExit("--sweep requires timing control "
                             "(an --archive, without --no-timing-control)")
        divisors = [int(d) for d in args.sweep.split(",")]
    elif control:
        divisors = [args.baseline_divisor]
    else:
        # frequency untouched: label the step with the divisor the SP
        # actually booted with, when readable
        btr1 = ctl.get_btr1() if ctl else None
        divisors = [((btr1 >> 20) & 0xF) + 1 if btr1 is not None
                    else args.baseline_divisor]
        if btr1 is not None:
            print("boot BTR1 = 0x%08x -> divisor %d (%.2f MHz)"
                  % (btr1, divisors[0], freq_mhz(divisors[0])))
    overall_ok = True
    for divisor in divisors:
        print("== divisor %d (FMC_CLK %.2f MHz) ==" % (divisor, freq_mhz(divisor)))
        if control:
            ctl.set_divisor(divisor)
            time.sleep(0.1)
        rng = random.Random(args.seed)
        btr1, div_ok = ctl.verify_divisor(divisor) if ctl else (None, None)
        if btr1 is not None:
            print("  BTR1 = 0x%08x (CLKDIV field %d, %s)" %
                  (btr1, (btr1 >> 20) & 0xF,
                   "matches" if div_ok else "DOES NOT MATCH requested divisor"))
        if div_ok is False and not control:
            # informational only: we did not request this divisor
            div_ok = None
        if div_ok is False:
            # the programmed divider never landed: nothing this step would
            # measure is at the requested frequency, so fail before phases
            report["steps"].append({
                "divisor": divisor,
                "freq_mhz": freq_mhz(divisor),
                "ok": False,
                "btr1": "0x%08x" % btr1,
                "clkdiv_verified": False,
            })
            overall_ok = False
            print("  divisor %d FAILED (CLKDIV readback mismatch); "
                  "restoring baseline" % divisor)
            break
        ticks_before = ctl.system_time() if ctl else None
        try:
            ok, results = run_phases(mem, args, rng, golden)
        except Exception as exc:  # timeouts etc. count as a hard step failure
            ok, results = False, {"exception": repr(exc)}
            print("  step raised: %r" % exc)
        step = {
            "divisor": divisor,
            "freq_mhz": freq_mhz(divisor),
            "ok": ok,
            "udp_timeouts_retried": mem.timeouts_retried,
            "phases": results,
        }
        if btr1 is not None:
            step["btr1"] = "0x%08x" % btr1
            step["clkdiv_verified"] = div_ok
        if ctl:
            ticks_after = ctl.system_time()
            step["sp_ticks_before"] = ticks_before
            step["sp_ticks_after"] = ticks_after
            if ticks_before is not None and ticks_after is not None:
                # ticks are milliseconds since boot and only ever increase
                # while the SP stays up
                step["sp_rebooted"] = ticks_after < ticks_before
                if step["sp_rebooted"]:
                    ok = False
                    step["ok"] = False
                    print("  SP REBOOTED during this step (ticks %d -> %d):"
                          " it hung and was reset, this was not packet loss"
                          % (ticks_before, ticks_after))
            elif ticks_after is None:
                step["sp_unresponsive"] = True
                print("  could not read SP system time after the step "
                      "(SP hung or humility unavailable)")
        report["steps"].append(step)
        if not ok:
            overall_ok = False
            print("  divisor %d FAILED; restoring baseline" % divisor)
            break

    if control:
        # also covers the reboot case: a restarted SP booted back at its
        # kernel-configured divisor, and this re-asserts the sweep baseline
        ctl.set_divisor(args.baseline_divisor)
        time.sleep(0.1)
        ok, _ = phase_a_const_reads(mem, args, golden)
        report["restored_baseline_ok"] = ok
        print("baseline restore check: %s" % ("ok" if ok else "FAIL"))
        overall_ok = overall_ok and ok

    if args.json:
        with open(args.json, "w") as f:
            json.dump(report, f, indent=2)
        print("results written to", args.json)

    sys.exit(0 if overall_ok else 1)


if __name__ == "__main__":
    main()
