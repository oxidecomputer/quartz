# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.
#
# Copyright 2024 Oxide Computer Company

import argparse
import bz2

parser = argparse.ArgumentParser()
parser.add_argument(
    "--input", dest="input_file", help="Explicit input file"
)
parser.add_argument("--output", dest="output", help="Explicit compressed output file")

args = parser.parse_args()


def main():
    with open(args.input_file, "rb") as f:
        data = f.read()
    
    with bz2.open(args.output, "wb") as f:
        f.write(data)

if __name__ == "__main__":
    main()