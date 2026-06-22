#!/usr/bin/env python3
"""Wrapper for icebram/ecpbram stdin/stdout interface.

These tools read the design file from stdin and write the patched
result to stdout. This wrapper provides a file-based interface
suitable for use in build rules.

Usage:
    python3 icebram_wrapper.py <tool> <from_hex> <to_hex> <input> <output>

Example:
    python3 icebram_wrapper.py icebram from.hex to.hex design.asc patched.asc
    python3 icebram_wrapper.py ecpbram from.hex to.hex design.config patched.config
"""

import subprocess
import sys


def main():
    if len(sys.argv) != 6:
        print(
            f"Usage: {sys.argv[0]} <tool> <from_hex> <to_hex> <input> <output>",
            file=sys.stderr,
        )
        sys.exit(1)

    tool, from_hex, to_hex, input_file, output_file = sys.argv[1:]

    with open(input_file, "rb") as f:
        input_data = f.read()

    result = subprocess.run(
        [tool, from_hex, to_hex],
        input=input_data,
        capture_output=True,
    )

    if result.returncode != 0:
        sys.stderr.buffer.write(result.stderr)
        sys.exit(result.returncode)

    with open(output_file, "wb") as f:
        f.write(result.stdout)


if __name__ == "__main__":
    main()
