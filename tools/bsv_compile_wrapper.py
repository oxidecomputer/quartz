#!/usr/bin/env python3
"""
Wrapper script for BSC compilation that creates output directory first.

Buck2 doesn't automatically create output directories, so this script
ensures the directory exists before invoking bsc.
"""

import os
import subprocess
import sys


def main():
    if len(sys.argv) < 3:
        print("Usage: bsv_compile_wrapper.py <bsc_path> <output_dir_or_file> [--extra-dir <dir>] [bsc_args...]", file=sys.stderr)
        sys.exit(1)

    bsc_path = sys.argv[1]
    output_path = sys.argv[2]

    # If output_path is a file (ends with .bo), extract directory; otherwise use as-is
    if output_path.endswith('.bo'):
        output_dir = os.path.dirname(output_path)
    else:
        output_dir = output_path

    # Parse remaining arguments, looking for --extra-dir flags and replacing -bdir arguments
    bsc_args = []
    extra_dirs = []
    i = 3
    while i < len(sys.argv):
        if sys.argv[i] == "--extra-dir" and i + 1 < len(sys.argv):
            extra_dirs.append(sys.argv[i + 1])
            i += 2
        elif sys.argv[i] == "-bdir" and i + 1 < len(sys.argv):
            # Replace -bdir argument with the computed output directory
            bsc_args.append("-bdir")
            # If the next arg is also a .bo file path, use its directory
            bdir_arg = sys.argv[i + 1]
            if bdir_arg.endswith('.bo'):
                bsc_args.append(os.path.dirname(bdir_arg))
            else:
                bsc_args.append(bdir_arg)
            i += 2
        else:
            bsc_args.append(sys.argv[i])
            i += 1

    # Create output directory and any extra directories
    os.makedirs(output_dir, exist_ok=True)
    for extra_dir in extra_dirs:
        os.makedirs(extra_dir, exist_ok=True)

    # Run bsc
    cmd = [bsc_path] + bsc_args
    result = subprocess.run(cmd)
    sys.exit(result.returncode)


if __name__ == "__main__":
    main()
