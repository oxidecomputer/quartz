# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.
#
# Copyright 2024 Oxide Computer Company

import argparse
import json
import subprocess
import os
import sys
from pathlib import Path

try:
    import tomli_w
except:
    print("Error attempting to import tomli_w module."
          " Check tools/requirements.txt and install deps as necessary"
          " `pip install -r tools/requirements.txt"
    )
    sys.exit(1)

# Brute-force finding the project's buck root folder
def find_project_root():
    current_path = os.getcwd()
    drive_root = os.path.splitdrive(os.path.abspath(current_path))[0] + os.sep
    while True:
        if Path(current_path) == Path(current_path).root:
            break
        new_path, _ = os.path.split(current_path)
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


def vhdl_ls_toml_gen(args):
    root = find_project_root()
    vhdlls_toml = root / "vhdl_ls.toml"
    # Call buck2 and get the list of vhdl files that we own for
    # formatting (ie no 3rd party things)
    buck_bxl = subprocess.run(
        ["buck2", "bxl", "//tools/vhdl-ls.bxl:vhdl_ls_toml_gen"], 
        encoding="utf-8", 
        check=True, 
        capture_output=True
    )
    vhdl_lsp_dict = json.loads(buck_bxl.stdout)
    if not args.print:
        # dump toml
        with open(vhdlls_toml, "wb") as f:
            tomli_w.dump(vhdl_lsp_dict, f)
    else:
        print(json.dumps(vhdl_lsp_dict, indent=4))
        

# create the top-level parser
parser = argparse.ArgumentParser(prog='multitool')
subparsers = parser.add_subparsers(help='sub-command help')

# create the parser for the "format" command
format_parser = subparsers.add_parser('format', help='format help')
format_parser.set_defaults(func=vhdl_format)
format_parser.add_argument(
    "--no-fix", 
    action="store_true", 
    default=False,
    help="Don't fix files, just print erros and warnings to stdout"
)

# create the parser for the "lsp-toml" command
format_parser = subparsers.add_parser('lsp-toml', help='format help')
format_parser.set_defaults(func=vhdl_ls_toml_gen)
format_parser.add_argument(
    "--print", 
    action="store_true", 
    default=False,
    help="Don't write the file, just pretty-print the json representation"
)

args = parser.parse_args()
args.func(args)

