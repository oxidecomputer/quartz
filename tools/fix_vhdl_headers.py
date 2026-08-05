#!/usr/bin/env python3
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

"""Normalize the MPL copyright header at the top of VHDL files.

The canonical header is exactly the three MPL lines and nothing else:

    -- This Source Code Form is subject to the terms of the Mozilla Public
    -- License, v. 2.0. If a copy of the MPL was not distributed with this
    -- file, You can obtain one at https://mozilla.org/MPL/2.0/.

Historically some files also carried a bare `--` continuation line and/or a
`-- Copyright <year> Oxide Computer Company` line. Both are dropped here.
"""

import argparse
import re
import sys
from pathlib import Path

MPL_LINES = (
    "-- This Source Code Form is subject to the terms of the Mozilla Public",
    "-- License, v. 2.0. If a copy of the MPL was not distributed with this",
    "-- file, You can obtain one at https://mozilla.org/MPL/2.0/.",
)

# Skip generated output and third-party trees; their headers aren't ours to touch.
SKIP_DIRS = {".git", ".jj", "buck-out", "vunit_out", "vnd", "build", "__pycache__"}

# Only Oxide's own copyright line goes away. Third-party notices (e.g. the
# 8b10b encoder) must stay intact, so match narrowly.
OXIDE_COPYRIGHT_RE = re.compile(r"^--\s*Copyright\s+(\d{4}\s+)?Oxide Computer Company\s*$")
BARE_COMMENT_RE = re.compile(r"^--\s*$")


def clean(lines):
    """Return the cleaned line list, or None if nothing needed changing."""
    if [line.rstrip() for line in lines[: len(MPL_LINES)]] != list(MPL_LINES):
        return None

    i = len(MPL_LINES)
    end = i
    while end < len(lines):
        line = lines[end]
        if BARE_COMMENT_RE.match(line) or OXIDE_COPYRIGHT_RE.match(line):
            end += 1
        else:
            break

    if end == i:
        return None

    rest = lines[end:]
    # Don't let code end up butted directly against the header.
    if rest and rest[0].strip():
        rest = ["\n"] + rest
    return lines[:i] + rest


def vhdl_files(roots):
    for root in roots:
        if root.is_file():
            yield root
            continue
        for path in sorted(root.rglob("*")):
            if path.suffix not in (".vhd", ".vhdl") or not path.is_file():
                continue
            if SKIP_DIRS & set(path.relative_to(root).parts):
                continue
            yield path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("paths", nargs="*", type=Path, default=[Path(".")],
                        help="files or directories to process (default: cwd)")
    parser.add_argument("--check", action="store_true",
                        help="report files that need fixing without writing")
    args = parser.parse_args()

    changed = []
    for path in vhdl_files(args.paths):
        text = path.read_text()
        lines = text.splitlines(keepends=True)
        cleaned = clean(lines)
        if cleaned is None:
            continue
        changed.append(path)
        if not args.check:
            path.write_text("".join(cleaned))

    for path in changed:
        print(path)
    verb = "need fixing" if args.check else "fixed"
    print(f"{len(changed)} file(s) {verb}", file=sys.stderr)
    return 1 if (args.check and changed) else 0


if __name__ == "__main__":
    sys.exit(main())
