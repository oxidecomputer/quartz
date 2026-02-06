# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.
#
# Copyright 2024 Oxide Computer Company

# This stuff is factored here because it is used potentially in multiple bzl files
# and we don't want deal with possible circular dependencies


# RDL Types
def rdl_project_as_args(value: Artifact):
    return cmd_args(value)


RDLTSet = transitive_set(args_projections={"args": rdl_project_as_args})

RDLFileInfo = provider(fields={"set": provider_field(RDLTSet)})
RDLHtmlMaps = provider(fields=["files"])
RDLJsonMaps = provider(fields=["files"])
RDLBSVPkgs = provider(fields=["files"])


VHDLFileInfo = record(
    src = field(Artifact),
    library = field(str, default=""),
    standard = field(str, default="2008"),
    is_synth = field(bool, default=True),
    is_third_party = field(bool, default=False),
    is_tb = field(bool, default=False)
)

# Take a TSet and project out the values as names for
# a command-line tool
def project_as_args(value):
    return cmd_args(value.src)


def project_as_json(value):
    v = {
        "artifact": value.src,
        "library": value.library,
        "standard": value.standard,
        "is_synth": value.is_synth,
    }
    
    return v


# Helper function for max_vhdl reduction
# Some tools don't support mixed standards so we need to artificially
# Set the standard up to the max we need.  These come in as strings
# but right now we realistically only have 2008 and 2019 so we deal
# with that here
def max_vhdl(stds: list[str]):
    max = "2008"
    for x in stds:
        if x == "2019":
            max = x
            break
    return max

# The actual reduction method. This will take a set of children and and optional
# node, we have to flatten this top level ourselves by checking both the top
# file and its children
def max_vhdl_standard_required(children: list[str], infos: VHDLFileInfo | None):
    if infos:
        # Need to compare this node *and* it's children
        full_list = children
        full_list.append(infos.standard)
        return max_vhdl(full_list)
    return max_vhdl(children)

# A TSet for HDL units. The value is the VHDLFileInfo record
# and we have some projections and reductions here
HDLFileInfoTSet = transitive_set(
    args_projections={"args": project_as_args},
    json_projections={"json": project_as_json},
    reductions = {
        "vhdl_std": max_vhdl_standard_required
    },
)
# HDL files can have 0 or more dependencies on other HDL files
# so we return a HDLFileInfoTSet with the file and any deps (as TSets)
HDLFileInfo = provider(
    fields={
        "set_all": provider_field(HDLFileInfoTSet),
    })
# Some build stages generate HDL that we'd like to do something
# with down-stream, so we return them as an Artifact so they can
# be dealt with specially if needed
GenVHDLInfo = provider(
    fields={
        "src": provider_field(Artifact),
        "library":provider_field(str, default=""),
    
    })


