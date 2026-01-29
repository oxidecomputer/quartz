# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.
#
# Copyright 2024 Oxide Computer Company

# BSV (Bluespec SystemVerilog) build system providers and types
# This file contains provider definitions for the BSV buck2 build system

# Record type for BSV file metadata
BSVFileInfo = record(
    src = field(Artifact),                    # .bsv source file
    bo = field(Artifact | None, None),        # .bo object file (if compiled)
    bo_dir = field(Artifact | None, None),    # Directory artifact containing .bo file
    module = field(str),                      # Module name (from filename)
    is_synth = field(bool, default = True),   # For synthesis vs sim-only
)

# Projection function: Extract .bo directory paths for bsc -p search path
def project_bsv_as_bo_paths(value: BSVFileInfo):
    """Project .bo directory artifacts as paths for bsc -p flag"""
    if value.bo_dir:
        return cmd_args(value.bo_dir)  # Artifact will be converted to path automatically
    return cmd_args()

# Projection function: Extract source artifacts
def project_bsv_source(value: BSVFileInfo):
    """Project source artifacts for dependency tracking"""
    return cmd_args(value.src)

# Projection function: Create Module=path.bo mapping for bluescan
def project_bsv_as_bo_map(value: BSVFileInfo):
    """Project as Module=path.bo mapping for bluescan dependency resolution"""
    if value.bo:
        return {value.module: str(value.bo)}
    return {}

# Transitive set for BSV compilation units
# Supports projections for search paths, source tracking, and module mapping
BSVFileInfoTSet = transitive_set(
    args_projections = {
        "bo_paths": project_bsv_as_bo_paths,  # For bsc -p flag
        "sources": project_bsv_source,         # Source artifacts
    },
    json_projections = {
        "bo_map": project_bsv_as_bo_map,       # Module=path.bo for bluescan
    },
)

# Provider for BSV libraries (compilation units)
BSVLibraryInfo = provider(
    fields = {
        "tset": provider_field(BSVFileInfoTSet),
        # Directory artifact containing .bo files for this library
        "bo_dir": provider_field(Artifact | None, default = None),
    },
)

# Provider for generated Verilog modules
BSVVerilogInfo = provider(
    fields = {
        # Map of module_name -> verilog_artifact
        "modules": provider_field(dict[str, Artifact]),
    },
)

# Provider for Bluesim executables
BSVSimInfo = provider(
    fields = {
        # Executable script
        "script": provider_field(Artifact),
        # Shared object
        "so": provider_field(Artifact),
    },
)
