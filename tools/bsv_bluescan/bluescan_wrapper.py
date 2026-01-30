#!/usr/bin/env python3
#
# Copyright 2026 Oxide Computer Company
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

"""
Buck2 wrapper for bluescan dependency scanner.

This script wraps the BSV import dependency scanner for use in buck2 builds.
It scans BSV source files for import statements and resolves them to .bo object
files using a module map from dependencies.
"""

import argparse
import json
import os
import re
import sys


def scan_imports(source_path, bs_prefix):
    """
    Scan a BSV source file for import statements.

    Args:
        source_path: Path to BSV source file
        bs_prefix: Bluespec stdlib installation path

    Returns:
        Set of imported module names (excluding standard library)
    """
    # Get standard library modules from Bluespec installation
    prelude_modules = set()
    lib_path = os.path.join(bs_prefix, 'lib', 'Libraries')

    if os.path.exists(lib_path):
        for entry in os.scandir(lib_path):
            if entry.is_file() and entry.name.endswith('.bo'):
                prelude_modules.add(entry.name[:-3])

    # Scan source file for imports
    import_re = re.compile(r'^import\s+([A-Za-z0-9_]+)')
    unique_imports = set()

    with open(source_path, 'r') as f:
        for line in f:
            match = import_re.match(line)
            if match:
                module_name = match.group(1)
                # Skip standard library modules
                if module_name not in prelude_modules:
                    unique_imports.add(module_name)

    return unique_imports


def resolve_dependencies(imports, module_map):
    """
    Resolve import module names to .bo file paths.

    Args:
        imports: Set of imported module names
        module_map: Dict mapping module names to .bo file paths

    Returns:
        List of .bo file paths
    """
    dependencies = []

    for module in sorted(imports):
        if module in module_map:
            dependencies.append(module_map[module])
        else:
            # Module not found in map - this is an error but we'll let bsc
            # report it during compilation
            print(f"Warning: No mapping for import {module}", file=sys.stderr)

    return dependencies


def main():
    parser = argparse.ArgumentParser(
        description="BSV dependency scanner for buck2"
    )
    parser.add_argument(
        "--source",
        required=True,
        help="BSV source file to scan"
    )
    parser.add_argument(
        "--object",
        required=True,
        help="Output .bo object file path"
    )
    parser.add_argument(
        "--bo-map-json",
        required=True,
        help="JSON file with Module=path.bo mappings from dependencies"
    )
    parser.add_argument(
        "--bs-prefix",
        required=True,
        help="Bluespec stdlib installation path"
    )
    parser.add_argument(
        "--output-json",
        required=True,
        help="Output dependency info as JSON"
    )

    args = parser.parse_args()

    # Load module map from dependencies
    with open(args.bo_map_json, 'r') as f:
        module_map = json.load(f)

    # Scan source file for imports
    imports = scan_imports(args.source, args.bs_prefix)

    # Resolve imports to .bo file paths
    dependencies = resolve_dependencies(imports, module_map)

    # Write dependency info as JSON for buck2
    output = {
        "object": args.object,
        "source": args.source,
        "dependencies": dependencies,
        "imports": sorted(list(imports)),
    }

    with open(args.output_json, 'w') as f:
        json.dump(output, f, indent=2)


if __name__ == "__main__":
    main()
