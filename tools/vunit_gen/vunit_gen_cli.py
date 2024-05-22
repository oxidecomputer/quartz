# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.
#
# Copyright 2024 Oxide Computer Company

import argparse
from pathlib import Path
from jinja2 import Environment, PackageLoader
import json

parser = argparse.ArgumentParser()
parser.add_argument(
    "--input", dest="input", help=".json file with files and libraries"
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
    libs = {}
    # Parse the json we were handed
    with open(args.input) as fp:
        inputs = json.load(fp)

    # Load jinja templates
    env = Environment(
        loader=PackageLoader("vunit_gen"),
        lstrip_blocks=True,
        trim_blocks=True,
    )
    template = env.get_template("run_py.jinja2")
    # Set up the default library
    libs.update({"lib": Library("lib")})
    for x in inputs.get("files"):
        artifact = x.get("artifact")
        this_lib = x.get('library')
        # By default, libraries are blank and compiled into
        # the default lib so if it's blank we give it the default
        # name here
        if not this_lib:
            this_lib = "lib"
        
        # Now we see if we already have the library added (it's in the dict)
        # or need to add it
        cur_lib = libs.get(this_lib, None)
        if cur_lib is None:
            # New library so lets add it and push it into the dictionary
            libs.update({this_lib: Library(this_lib)})
            cur_lib = libs.get(this_lib, None)
        p = Path.cwd() / Path(artifact)
        cur_lib.files.append(p.absolute().as_posix())

    libs_list = list(libs.values())
    content = template.render(
        libraries=libs_list,
        simulator=args.simulator,
        vhdl_standard=inputs.get("vhdl_std"),
        codec_packages=[],
        # vunit_out=args.vunit_out,
    )
    with open(args.output, mode="w", encoding="utf-8") as message:
        message.write(content)


if __name__ == "__main__":
    main()
