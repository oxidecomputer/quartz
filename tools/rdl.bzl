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
    "RDLBSVPkgs",
)


def _rdl_file_impl(ctx):
    providers = []
    # Add the deps to a TSet for these files
    deps_tset = [x[RDLFileInfo].set for x in ctx.attrs.deps]

    # Let's enforce some naming conventions here
    # by convention, and for easier human understand of buck files we prefer our
    # RDL targets to end in _rdl
    # We're particular about this since we want to enforce certain naming standards b/c
    # some collateral is consumed programmatically down-stream by say sw generation tools
    # We could provide a knob to relax this if needed
    if not ctx.attrs.name.endswith("_rdl"):
       fail("RDL target named {} should have an ending in '_rdl'".format(ctx.attrs.name))
    
    src_base_name = ctx.attrs.name[:-4] # Take off the _rdl
    expected_src = src_base_name + ".rdl"
    if not ctx.attrs.src.basename == expected_src:
        fail("RDL file {} does not have an expected name {}".format(ctx.attrs.src.basename, expected_src))

    # Make the deps a child of the tset containing any sources
    top_tset = ctx.actions.tset(RDLTSet, value=ctx.attrs.src, children=deps_tset)

    providers.append(
        RDLFileInfo(
            set=top_tset,
        )
    )

    if ctx.attrs.outputs:
        # Let's do some sanity checking on the naming of the outputs. Again, we're being particular
        # about this because humans can specify but we want machines to be able to consume some of these
        # In general, our convention is <src_base_name>.<file_extension> but we want "_pkg" to be appended
        # in the VHDL case. BSV allows flexible naming to support CamelCase package names.
        for out in ctx.attrs.outputs:
            # Allow .vhd, .bsv, .json, and .html outputs in buck
            if out.endswith(".vhd"):
                expected_name = src_base_name + "_pkg.vhd"
                if out != expected_name:
                    fail("VHDL output {} does not match expected filename {}. Check for typos and follow our naming convention".format(out, expected_name))
            elif out.endswith(".bsv"):
                # BSV files are flexible - allow any name ending in .bsv
                # This supports CamelCase package names (e.g., GimletSeqFpgaRegs.bsv from gimlet_seq_fpga_regs.rdl)
                pass
            elif out.endswith(".json"):
                expected_name = src_base_name + ".json"
                if out != expected_name:
                    fail("JSON output {} does not match expected filename {}".format(out, expected_name))
            elif out.endswith(".html"):
                expected_name = src_base_name + ".html"
                if out != expected_name:
                    fail("HTML output {} does not match expected filename {}".format(out, expected_name))
            else:
                fail("Output {} does not have an expected extension (.vhd, .bsv, .json, .html)".format(out))
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
        bsv_pkgs = [x for x in outs if x.extension == ".bsv"]
        if len(bsv_pkgs) > 0:
            providers.append(RDLBSVPkgs(files=bsv_pkgs))

        # Create sub-targets for each output type to allow selective access
        sub_targets = {}
        for out in outs:
            # Create a sub-target for each individual file (e.g., [bsv], [html], [json])
            extension = out.extension[1:]  # Remove leading dot
            sub_targets[extension] = [DefaultInfo(default_output=out)]

        # Toss a basic default provider in here for the generated files
        providers.append(DefaultInfo(
            default_outputs=outs,
            sub_targets=sub_targets
        ))
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