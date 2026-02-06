#!/usr/bin/env python3
"""Generate BSV git version file for Buck2"""

import subprocess
import sys
from pathlib import Path

def main():
    if len(sys.argv) != 2:
        print("Usage: gen_git_version_bsv_buck2.py <output_dir>")
        sys.exit(1)

    output_dir = Path(sys.argv[1])
    output_file = output_dir / "git_version.bsv"

    # Get git information
    try:
        sha = subprocess.check_output(
            ["git", "rev-parse", "HEAD"],
            stderr=subprocess.DEVNULL,
            text=True
        ).strip()
        code = subprocess.check_output(
            ["git", "rev-list", "--count", "HEAD"],
            stderr=subprocess.DEVNULL,
            text=True
        ).strip()
    except (subprocess.CalledProcessError, FileNotFoundError):
        # Git not available or not in a repo
        sha = "0000000000000000"
        code = "0"

    short_sha = sha[:8]
    version_hex = format(int(code), 'x')
    try:
        sha_hex = format(int(short_sha, 16), 'x')
    except ValueError:
        sha_hex = "0"

    # Generate BSV file
    template = f"""// Auto-generated as part of the FPGA build.
package git_version;

import Vector::*;

Vector#(4, Bit#(8)) version = reverse(unpack('h{version_hex}));
Vector#(4, Bit#(8)) sha = reverse(unpack('h{sha_hex}));

endpackage
"""

    output_file.write_text(template)
    print(f"Generated {output_file}")

if __name__ == "__main__":
    main()
