# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.
#
# Copyright 2024 Oxide Computer Company

import argparse
from pathlib import Path
from jinja2 import Environment, PackageLoader


parser = argparse.ArgumentParser()
parser.add_argument(
    "--input", "--inputs", nargs="+", dest="inputs", help="Explicit input file list"
)
parser.add_argument("--output", dest="output", help="Explicit output list")
parser.add_argument("--simulator", dest="simulator", default="", help="specify simulator name (ghdl or nvc)")

args = parser.parse_args()


class Library:
    def __init__(self, name, files=None):
        self.name = name
        self.files = [] if files is None else files

class CodecGen:
    def __init__(self, types_name, codec_name):
        self.types_name
        self.codec_name

def codecs_from_inputs(i):
    pass

def main():
    # Load jinja templates
    env = Environment(
        loader=PackageLoader("vunit_gen"),
        lstrip_blocks=True,
        trim_blocks=True,
    )
    template = env.get_template("run_py.jinja2")

    lib = Library("lib")
    print([Path.cwd() / Path(x) for x in args.inputs])
    for x in args.inputs:
        p = Path.cwd() / Path(x)
        lib.files.append(p.absolute().as_posix())

    content = template.render(
        libraries=[lib],
        simulator=args.simulator,
        codec_packages=[],
        # vunit_out=args.vunit_out,
    )
    with open(args.output, mode="w", encoding="utf-8") as message:
        message.write(content)


if __name__ == "__main__":
    main()
