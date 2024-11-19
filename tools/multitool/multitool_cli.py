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


def vunit_files():
    # This is kind of an ugly hack since vunit doesn't provide an API for this
    # see https://github.com/VUnit/vunit/issues/699
    try:
        import vunit
        vunit_install_dir = Path(vunit.__file__).parent
    except:
        print("Error attempting to import vunit module."
              " Check tools/requirements.txt and install deps as necessary"
              " `pip install -r tools/requirements.txt"
        )
        sys.exit(1)

    vunit_vhdl = vunit_install_dir / "vhdl"
    ret = {}
    ret["vunit_lib"] = []
    ret["osvvm"] = []
    for file in vunit_vhdl.rglob("*.vhd"):
        if "osvvm" in str(file):
            lib = "osvvm"
        else:
            lib = "vunit_lib"
        ret[lib].append(str(file.resolve()))
    return ret
    


def vhdl_ls_toml_gen(args):
    root = find_project_root()
    vhdlls_toml = root / "vhdl_ls.toml"
    # Call buck2 and get the list of vhdl files that we own for
    # formatting (ie no 3rd party things)
    # We capture stdout here because we need to parse the json but 
    # allow the stderr to go to the console
    buck_bxl = subprocess.Popen(
        ["buck2", "bxl", "//tools/vhdl-ls.bxl:vhdl_ls_toml_gen"], 
        encoding="utf-8",
        stdout=subprocess.PIPE
    )
    stdout, _ = buck_bxl.communicate()
    if buck_bxl.returncode != 0:
        sys.exit(buck_bxl.returncode)
    
    # Get known libraries and files from buck via the bxk's stdout
    vhdl_lsp_dict = json.loads(stdout)

    # A bit of a hack to also figure out where the vunit included files are
    # and jack them into the toml file also
    vunit_dict = vunit_files()
    # set these lists up into the expected format
    vunit = {"vunit_lib": {"files": vunit_dict["vunit_lib"]}}
    osvvm = {"osvvm": {"files": vunit_dict["osvvm"]}}

    # Update the running structure with these new libraries
    vhdl_lsp_dict["libraries"].update(vunit)
    vhdl_lsp_dict["libraries"].update(osvvm)

    # Write the toml file (or print if someone asked for that)
    if not args.print:
        # dump toml
        with open(vhdlls_toml, "wb") as f:
            tomli_w.dump(vhdl_lsp_dict, f)
    else:
        print(json.dumps(vhdl_lsp_dict, indent=4))

class VunitProject:
    def __init__(self, name, path):
        self.name = name
        self.path = path
        self.year = 2024
        self.half_period = "4 ns"
        self.reset_time = "200 ns"
        self.reset_delay = "500 ns"
        self.sim_wdog = "10 ms"

def vunit_tb_gen(args):
    from jinja2 import Environment, PackageLoader

     # Build jinja env
    env = Environment(
        loader=PackageLoader("multitool"),
        lstrip_blocks=True,
        trim_blocks=True,
    )

    project = VunitProject(args.name, args.path)

    templates = [
        (env.get_template("vunit_tb.jinja2"), f"{project.name}_tb.vhd"),
        (env.get_template("vunit_th.jinja2"), f"{project.name}_th.vhd"),
    ]

    for template, filename in templates:
        # Now render the template and write it out
        content = template.render(
            project=project,
        )
        fout = Path(args.path) / filename
        with open(fout, mode="w", encoding="utf-8") as message:
            message.write(content)


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
format_parser = subparsers.add_parser('lsp-toml', help='LSP toml help')
format_parser.set_defaults(func=vhdl_ls_toml_gen)
format_parser.add_argument(
    "--print", 
    action="store_true", 
    default=False,
    help="Don't write the file, just pretty-print the json representation"
)

# create the parser for the "tb-gen" command
format_parser = subparsers.add_parser('tb-gen', help='tb-gen help')
format_parser.set_defaults(func=vunit_tb_gen)
format_parser.add_argument(
    "--name", 
    action="store", 
    help="name of testbench entity without _tb or _th suffix"
)
format_parser.add_argument(
    "--path", 
    action="store", 
    help="Folder path for the testbench files to live"
)

args = parser.parse_args()
args.func(args)

