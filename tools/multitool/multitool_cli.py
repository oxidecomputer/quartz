# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.
#
# Copyright 2024 Oxide Computer Company

import argparse
import json
import subprocess
import os
from pathlib import Path

# Brute-force finding the project's buck root folder
def find_project_root():
    current_path = os.getcwd()
    drive_root = os.path.splitdrive(os.path.abspath(current_path))[0] + os.sep
    while True:
        if Path(current_path) == Path(current_path).root:
            #raise NoRootException('No ".buckroot" found for project')
            break

        new_path, tail = os.path.split(current_path)
        root_path = Path(current_path) / ".buckroot"
        if root_path.exists():
            break
        current_path = new_path

    return Path(current_path)



def vhdl_format(args):
    root = find_project_root()
    vhdl_syle_config = root / "vsg_config.json"
    # Call buck2 and get the list of vhdl files that we own for
    # formatting (ie no 3rd party things)
    buck_bxl = subprocess.run(
        ["buck2", "bxl", "//tools/vsg-format.bxl:vsg_format_gen"], 
        encoding="utf-8", 
        check=True, 
        capture_output=True
    )
    files_to_format = json.loads(buck_bxl.stdout)
    vsg_cmd = ["vsg", "-c", vhdl_syle_config, "-f", *files_to_format]
    if not args.no_fix:
        vsg_cmd.append("--fix")
    # run formatter
    subprocess.run(
        vsg_cmd,
        cwd=root,
        encoding="utf-8"
    )



# create the top-level parser
parser = argparse.ArgumentParser(prog='quartz')
subparsers = parser.add_subparsers(help='sub-command help')

# create the parser for the "format" command
format_parser = subparsers.add_parser('format', help='format help')
format_parser.set_defaults(func=vhdl_format)
format_parser.add_argument("--no-fix", action="store_true", default=False)

args = parser.parse_args()
args.func(args)

