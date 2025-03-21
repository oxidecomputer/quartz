# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.
#
# Copyright 2024 Oxide Computer Company

import sys
import argparse
import os
from pathlib import Path

from systemrdl import RDLCompiler, RDLCompileError, RDLWalker
from systemrdl.node import FieldNode

# This is a dumb hack to deal with the fact that buck2 and cobble run python differently
# and I couldn't figure out a way to make them both import the same way
try:
    from exporter import MapExporter, MapofMapsExporter
    from listeners import PreExportListener, MyModelPrintingListener
    from json_dump import convert_to_json
except ModuleNotFoundError:
    from rdl_pkg.exporter import MapExporter, MapofMapsExporter
    from rdl_pkg.listeners import PreExportListener, MyModelPrintingListener
    from rdl_pkg.json_dump import convert_to_json, convert_only_map_to_json

parser = argparse.ArgumentParser()
parser.add_argument(
    "--input", "--inputs", nargs="+", dest="input_file", help="Explicit input list"
)
parser.add_argument(
    "--out-dir", dest="out_dir", default=Path.cwd(), help="Output directory"
)
parser.add_argument("--debug", action="store_true", default=False)
parser.add_argument("--outputs", nargs="+", help="Explicit output list")


def main():
    rdlc = RDLCompiler()

    try:
        for infile in args.input_file:
            rdlc.compile_file(infile)
        root = rdlc.elaborate()
    except RDLCompileError:
        sys.exit(1)

    if args.debug:
        # Traverse the register model with the printer
        walker = RDLWalker(unroll=True)
        listener = MyModelPrintingListener()
        walker.walk(root, listener)

    # Run the pre_export listener so we have a list of maps we need to generate
    pre_export = PreExportListener()
    RDLWalker().walk(root, pre_export)

    output_filenames = [Path(x) for x in args.outputs]
    output_filenames_no_json = [x for x in output_filenames if ".json" not in str(x)]
    # For a map of maps, we're going to generate:
    # Address offsets bsv using full address and flattening the naming
    # Address offsets json using full address and flattening the naming??
    # an HTML file of everything
    if pre_export.is_map_of_maps:
        # Dump Jinja template-based outputs (filter out .json)
        exporter = MapofMapsExporter()
        exporter.export(pre_export.maps[0], output_filenames_no_json)
        json_files = [x for x in output_filenames if ".json" in str(x)]
        if len(json_files) == 1:
            json_name = Path(json_files[0])
            convert_only_map_to_json(rdlc, root, json_name)
        elif len(json_files) > 1:
            raise Exception(f'Specified too many .json outputs: {json_files.join(",")}')

    else:
        # For each standard map, we're going to generate:
        # Standard bsv package from this base address
        # Standard json package from this base address
        # an HTML file of this block
        exporter = MapExporter()
        exporter.export(pre_export.maps[0], output_filenames_no_json)

        # Dump json output if requested
        json_files = [x for x in output_filenames if ".json" in str(x)]
        if len(json_files) == 1:
            json_name = Path(json_files[0])
            convert_to_json(rdlc, root, json_name)
        elif len(json_files) > 1:
            raise Exception(f'Specified too many .json outputs: {json_files.join(",")}')


args = parser.parse_args()

if __name__ == "__main__":
    main()
