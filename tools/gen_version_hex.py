#!/usr/bin/env python3
"""Generate a replacement hex file for version ROM stamping.

Produces a 256-line hex file (one byte per line, 2 hex digits)
containing the git commit count and short SHA in big-endian byte
order. This is the "to" file for icebram/ecpbram patching.

Layout:
  [0:3]   - Commit count (big-endian)
  [4:7]   - Short SHA (big-endian)
  [8:255] - Zeros
"""

import subprocess
import sys


def main():
    if len(sys.argv) != 2:
        print(f"Usage: {sys.argv[0]} <output_hex>", file=sys.stderr)
        sys.exit(1)

    output_path = sys.argv[1]

    try:
        sha_hex = subprocess.check_output(
            ["git", "rev-parse", "HEAD"],
            stderr=subprocess.DEVNULL,
            text=True,
        ).strip()
        commit_count = int(
            subprocess.check_output(
                ["git", "rev-list", "--count", "HEAD"],
                stderr=subprocess.DEVNULL,
                text=True,
            ).strip()
        )
    except (subprocess.CalledProcessError, FileNotFoundError):
        sha_hex = "0" * 40
        commit_count = 0

    short_sha = int(sha_hex[:8], 16)

    lines = []
    # Bytes 0-3: commit count, big-endian
    for shift in (24, 16, 8, 0):
        lines.append(f"{(commit_count >> shift) & 0xFF:02X}")
    # Bytes 4-7: short SHA, big-endian
    for shift in (24, 16, 8, 0):
        lines.append(f"{(short_sha >> shift) & 0xFF:02X}")
    # Bytes 8-255: zeros
    for _ in range(248):
        lines.append("00")

    with open(output_path, "w") as f:
        f.write("\n".join(lines) + "\n")


if __name__ == "__main__":
    main()
