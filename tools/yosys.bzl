load(
    "@prelude//python:toolchain.bzl",
    "PythonToolchainInfo",
)

load(
    ":hdl_common.bzl", 
    "HDLFileInfo", 
    "VHDLFileInfo", 
    "HDLFileInfoTSet",
    "RDLHtmlMaps",
    "RDLJsonMaps",
)

load(
    ":compress.bzl", "compress_bitstream",
)

def _ice40_bitstream_impl(ctx):
    yosys_synth_providers = yosys_vhdl_synth(ctx)
    next_pnr_providers = ice40_nextpnr(ctx, yosys_synth_providers)
    icepack_providers = icepack(ctx, next_pnr_providers)
    compressed = compress_bitstream(ctx, icepack_providers)
    return [
        DefaultInfo(
            default_output=compressed[0].default_outputs[0],
            sub_targets = {
                "synth": yosys_synth_providers,
                "route": next_pnr_providers,
            }
        )
    ]
    pass

def yosys_vhdl_synth(ctx):
    providers = []
     # Get list of all sources from the dep tree via the tset in HDLFileInfo
    source_files_tset = ctx.attrs.top[HDLFileInfo].set_all
    source_files = source_files_tset.project_as_json("json", ordering="postorder")

    # The yosys synth json file, out-ut of this step
    yosys_json = ctx.actions.declare_output("{}.json".format(ctx.attrs.top_entity_name))

    out_json = {
        "sources": source_files,
        "top_entity_name": ctx.attrs.top_entity_name,
    }
    in_json_file = ctx.actions.write_json("yosys_synth_input.json", out_json, with_inputs=True)

    # Dump some register map stuff
    maps = []
    json_maps = ctx.attrs.top.get(RDLJsonMaps)
    if json_maps != None:
            for file in set(json_maps.files):
                new_file = ctx.actions.declare_output("maps", file.basename)
                maps.append(ctx.actions.copy_file(new_file, file))
    html_maps = ctx.attrs.top.get(RDLHtmlMaps)
    if html_maps != None:
            for file in set(html_maps.files):
                new_file = ctx.actions.declare_output("maps", file.basename)
                maps.append(ctx.actions.copy_file(new_file, file))

    # This is a bit sketchy but we're declaring any maps as hidden inputs
    # here to force the generation of these files since nothing downstream
    # depends on them. Buck2 is too smart such that since nothing depends
    # on them, it doesn't even build them 
    # This is a bit of a hack but it works for now.
    yosys_py = ctx.actions.declare_output("synth.py")

    yosys_gen = ctx.attrs._yosys_gen[RunInfo]
    cmd = cmd_args()
    cmd.add(yosys_gen)
    cmd.add("--input", in_json_file)
    cmd.add("--output", yosys_py.as_output())
   

    ctx.actions.run(cmd, category="yosys_synth_gen",  local_only = True, allow_cache_upload=True)

    yosys_synth_log = ctx.actions.declare_output("synth.log")
    yosys_ghdl_warns = ctx.actions.declare_output("ghdl_stderr.log")
    yosys_synth_cmd = cmd_args(hidden=[in_json_file, maps])
    yosys_synth_cmd.add(ctx.attrs._python[PythonToolchainInfo].interpreter)
    yosys_synth_cmd.add(yosys_py)
    yosys_synth_cmd.add("--output", yosys_json.as_output())
    yosys_synth_cmd.add("--log", yosys_synth_log.as_output())
    yosys_synth_cmd.add("--ghdl_stderr", yosys_ghdl_warns.as_output())


    ctx.actions.run(yosys_synth_cmd, category="yosys_run",  local_only = True,allow_cache_upload=True)
    providers.append(DefaultInfo(default_output=yosys_json))

    return providers

def ice40_nextpnr(ctx, yoys_providers):
    providers = []

    yosys_json = yoys_providers[0].default_outputs[0]

    asc = ctx.actions.declare_output("{}.asc".format(ctx.attrs.name))
    next_pnr_log = ctx.actions.declare_output("nextpnr.log")
    cmd = cmd_args()
    cmd.add(ctx.attrs._nextpnr_ice40[RunInfo])
    cmd.add(next_pnr_family_flags(ctx.attrs.family))
    cmd.add("--package", ctx.attrs.package)
    cmd.add("--pcf", ctx.attrs.pinmap)
    cmd.add("--json", yosys_json)
    cmd.add("--asc", asc.as_output())
    cmd.add("--log", next_pnr_log.as_output())
    for nextpnr_arg in ctx.attrs.nextpnr_args:
        cmd.add(nextpnr_arg)

    ctx.actions.run(cmd, category="next_pnr",  local_only = True,allow_cache_upload=True)

    providers.append(DefaultInfo(default_output=asc))
    return providers

# naive implemenation of turning family into nextpnr flags
def next_pnr_family_flags(family):
    return "--{}".format(family)


def icepack(ctx, next_pnr_providers):
    providers = []
    
    asc = next_pnr_providers[0].default_outputs[0]
    bit = ctx.actions.declare_output("{}.bin".format(ctx.attrs.name))
    cmd = cmd_args()
    cmd.add(ctx.attrs._icepack[RunInfo])
    cmd.add(asc)
    cmd.add( bit.as_output())

    ctx.actions.run(cmd, category="icepak",  local_only = True, allow_cache_upload=True)
    providers.append(DefaultInfo(default_output=bit))
    return providers

ice40_bitstream = rule(
    impl=_ice40_bitstream_impl,
    attrs={
        "top_entity_name": attrs.string(),
        "top": attrs.dep(doc="Expected top HDL unit"),
        "family": attrs.string(doc="FPGA family"),
        "package": attrs.string(doc="Supported FPGA package"),
        "pinmap": attrs.source(doc="Pin constraints file *.pcf"),
        "nextpnr_args": attrs.list(
            attrs.string(doc="Nextpnr arguments"),
            default=[],
        ),
        "_yosys_gen": attrs.exec_dep(
                doc="Generate a Vivado tcl for this project",
                default="root//tools/yosys_gen:yosys_gen",
            ),
        "_python": attrs.toolchain_dep(
            doc="Use system python toolchain for running stuff",
            default="toolchains//:python",
        ),
        "_bz2compress": attrs.exec_dep(
                doc="bz2 compressor",
                default="root//tools/bz2compress:bz2compress",
            ),
        "_icepack": attrs.toolchain_dep(
            doc="Use system python toolchain for running python stuff",
            default="toolchains//:icepack",
        ),
        "_nextpnr_ice40": attrs.toolchain_dep(
            doc="Use system python toolchain for running python stuff",
            default="toolchains//:nextpnr-ice40",
        ),
    },
)