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
    "--input", dest="input_pkg", help="Explicit input file"
)
parser.add_argument("--output", dest="output", help="Explicit output list")
args = parser.parse_args()

p = Path.cwd() / Path(args.input_pkg)

o = Path.cwd() / Path(args.output)

from vunit import VUnit
vu = VUnit.from_argv(argv=[], compile_builtins=False)
vu.add_com()
lib = vu.add_library("dummy_lib")
lib.add_source_file(p.absolute().as_posix())

pkg = lib.package(Path(args.input_pkg).stem)
pkg.generate_codecs(codec_package_name=o.stem, used_packages=['ieee.std_logic_1164', 'ieee.numeric_std'], output_file_name=o.absolute().as_posix())