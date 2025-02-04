# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.
#
# Copyright 2024 Oxide Computer Company

# RDL files can have 0 or more dependencies on other RDL files
# This block provides the following providers:
# - RDLFileInfo: A provider that contains a TSet of all the RDL files
# - HDLFileInfo: A provider that contains a TSet of all the generated VHDL files

load(
    "@prelude//python:toolchain.bzl",
    "PythonToolchainInfo",
)
load(
    ":hdl_common.bzl", 
    "GenVHDLInfo", 
    "RDLFileInfo", 
    "RDLTSet", 
    "HDLFileInfo",
    "HDLFileInfoTSet", 
    "VHDLFileInfo",
    "RDLHtmlMaps",
    "RDLJsonMaps",
)


def _rdl_file_impl(ctx):
    providers = []
    # Add the deps to a TSet for these files
    deps_tset = [x[RDLFileInfo].set for x in ctx.attrs.deps]

    # Make the deps a child of the tset containing any sources
    top_tset = ctx.actions.tset(RDLTSet, value=ctx.attrs.src, children=deps_tset)

    providers.append(
        RDLFileInfo(
            set=top_tset,
        )
    )

    if ctx.attrs.outputs:
        # Get the rdl python executable since we'll be using it for
        #  for generating our outputs
        rdl_gen_py = ctx.attrs._rdl_gen[RunInfo]
        rdl_ordered_args = top_tset.project_as_args("args", ordering="postorder")
        outs = [ctx.actions.declare_output(out) for out in ctx.attrs.outputs]
        rdl_out_gen = cmd_args()
        rdl_out_gen.add(rdl_gen_py)
        rdl_out_gen.add("--inputs", rdl_ordered_args)
        rdl_out_gen.add("--outputs", [x.as_output() for x in outs])
        ctx.actions.run(
            rdl_out_gen,
            category="rdl",
        )

        # Build TSets for the generated VHDL files as a list of VHDLFileInfo
        # This is the way down-stream logic would like to consume them
        gen_vhdl_tset = [
            ctx.actions.tset(
                HDLFileInfoTSet, 
                value=VHDLFileInfo(src=x)
            ) 
            for x in outs if x.extension in [".vhd", ".vhdl"]
        ]
        # If we have one or more generated VHDL files, create an empty TSet with each
        # of them as a child, and then build an HDLFileInfo provider with that TSet
        # for use by downstream rules
        if len(gen_vhdl_tset) > 0:
            all_gen_vhdl = ctx.actions.tset(HDLFileInfoTSet, children=gen_vhdl_tset)
            providers.append(HDLFileInfo(set_all=all_gen_vhdl))

        html_maps = [x for x in outs if x.extension == ".html"]
        if len(html_maps) > 0:
            providers.append(RDLHtmlMaps(files=html_maps))
        json_maps = [x for x in outs if x.extension == ".json"]
        if len(json_maps) > 0:
            providers.append(RDLJsonMaps(files=json_maps))

        # Toss a basic default provider in here for the generated files
        providers.append(DefaultInfo(default_outputs=outs))
    else:
        providers.append(
            DefaultInfo(default_output=ctx.attrs.src)
        )  # Unclear if this is correct

    return providers


rdl_file = rule(
    impl=_rdl_file_impl,
    attrs={
        "src": attrs.source(),
        "deps": attrs.list(attrs.dep(), default=[]),
        "outputs": attrs.list(attrs.string(), default=[]),
        "_rdl_gen": attrs.exec_dep(default="root//tools/site_cobble/rdl_pkg:rdl_cli"),
    },
)
