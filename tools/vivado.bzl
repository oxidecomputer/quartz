
# Synthesize
# Optionaly optimize
# Place
# Optionally optimize
# Route
# bitstream gen
load(
    "@prelude//python:toolchain.bzl",
    "PythonToolchainInfo",
)

load(":hdl.bzl", "HDLFileInfo", "UnitTSet")

VivadoConstraintInfo = provider(
    fields={
        "srcs": provider_field(Artifact),
    }
)

VivadoCheckpointInfo = provider(
    fields={
        "checkpoint": provider_field(Artifact),
        "name":provider_field(str, default=""),
    
    })


def _vivado_constraint_impl(ctx):
    # No dep management to worry about so just collect the things
    # and return a ConstraintProvider
    return VivadoConstraintInfo(
        srcs=ctx.attrs.srcs
    )

vivado_constraint = rule(
    impl=_vivado_constraint_impl,
    attrs={
        "srcs": attrs.list(attrs.source(doc="Expected one or more XDC sources")),
    }
)

def _synthesize(ctx):
    providers = []
    # TODO: Deal with constraint files as deps
    # Deal with constraint files as inputs
    constraints = ctx.attrs.constraints

    # Generate synthesis tcl

    # create a checkpoint file
    checkpoint = ctx.actions.declare_output("{}.dcp".format(ctx.attrs.name))
    # create a report file
    report = ctx.actions.declare_output("{}.report".format(ctx.attrs.name))
    # create a log file
    logfile = ctx.actions.declare_output("{}.log".format(ctx.attrs.name))
    # create a journal file
    journal = ctx.actions.declare_output("{}.jou".format(ctx.attrs.name))
    # output of this is a checkpoint file

    # Get list of all sources from the dep tree via the tset in HDLFileInfo
    print(dir(ctx.attrs.top))
    source_files_tset = ctx.attrs.top[HDLFileInfo].set
    source_files = source_files_tset.project_as_json("json", ordering="postorder")
    
    # Write out json file for this to use in command tool
    # Stuff that needs to go into json file:
    # flow = name of flow
    # checkpoint file path
    # report file path
    # logfile file path
    # journal file path
    # part_name string
    # max_threads integer
    # synth args
    # source_files as list
    # constraints files as list
    # TopEntity name
    out_file = {
        "flow": "synthesis",
        "part": ctx.attrs.part,
        "max_threads": 8,
        "synth_args": "",
        "sources": source_files,
        "constraints": constraints,
        "top_name": ctx.attrs.top_entity_name

    }
    in_json_file = ctx.actions.write_json("vivado_gen_input.json", out_file, with_inputs=True)
    
    vivado_flow_tcl = ctx.actions.declare_output("synthesize.tcl")

    vivado_gen = ctx.attrs._vivado_gen[RunInfo]
    cmd = cmd_args()
    cmd.add(vivado_gen)
    cmd.add("--input", in_json_file)
    cmd.add("--output", vivado_flow_tcl.as_output())

    ctx.actions.run(cmd, category="vivado_synth_gen")

    vivado = cmd_args()
    vivado.add("vivado")
    vivado.add("-mode", "batch")
    vivado.add("-source", vivado_flow_tcl)
    vivado.add("-log", logfile.as_output())
    vivado.add("-journal", journal.as_output())
    vivado.add("-tclargs", checkpoint.as_output(), report.as_output())
    
    ctx.actions.run(vivado, category="vivado_synth")

    providers.append(VivadoCheckpointInfo(
        checkpoint=checkpoint,
        name=ctx.attrs.name,
    ))
    providers.append(DefaultInfo(default_output=checkpoint))
    return providers


synthesize = rule(
  impl = _synthesize,
  attrs = {
    "top_entity_name": attrs.string(),
    "top": attrs.dep(doc="Expected top HDL unit"),
    "deps": attrs.list(attrs.dep(), default=[]),
    "part": attrs.string(doc="Vivado-compatible FPGA string"),
    "constraints": attrs.list(attrs.source(doc="Part constraint files"), default=[]),
    "synth_args":  attrs.list(attrs.string(), default = []),
    "_vivado_gen": attrs.exec_dep(
            doc="Generate a Vivado tcl for this project",
            default="root//tools/vivado_gen:vivado_gen",
        ),
  },
)

# create_bitstream = rule(
#     impl=_create_bitstream_impl,
#     attrs={
#         "checkpoint": attr.label(doc="Checkpoint file")
#     },
# )

# vivado_bitstream = rule(
#     impl=_tbd_impl,
#     attrs={
#         "top": attrs.source(doc="Expected HDL sources"),
#         "deps": attrs.list(attrs.dep(), default=[]),
#         "part": attrs.string(doc="Vivado-compatible FPGA string"),
#         "constraints": attrs.list(attrs.source(doc="Part constraint files")),
#         "optimize": attrs.bool(doc="Enable optimizations", default=True),
#         "outputs": attrs.list(attrs.string(), default=[]),
#         "_rdl_gen": attrs.exec_dep(default="root//tools/site_cobble/rdl_pkg:rdl_cli"),
#     },
# )