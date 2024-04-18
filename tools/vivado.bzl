
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

def _vivado_bitstream(ctx):
    synth = synthesize(ctx)
    opt = optimize(ctx, synth)
    placer =  place(ctx, opt, False)
    placer_opt = place(ctx, placer, True)
    router = route(ctx, placer_opt)
    return bitstream(ctx, router)

def synthesize(ctx):
    flow = "synthesize"
    name_and_flow = ctx.attrs.name + "_" + flow

    providers = []
    # TODO: Do we want to also deal with constraint files as deps?
    # Deal with constraint files as inputs
    constraints = ctx.attrs.constraints

    # create a checkpoint file
    checkpoint = ctx.actions.declare_output("{}.dcp".format(name_and_flow))
    # create a report file
    report = ctx.actions.declare_output("{}.rpt".format(name_and_flow))
    # create a log file
    logfile = ctx.actions.declare_output("{}.log".format(name_and_flow))
    # create a journal file
    journal = ctx.actions.declare_output("{}.jou".format(name_and_flow))
    # output of this is a checkpoint file

    # Get list of all sources from the dep tree via the tset in HDLFileInfo
    source_files_tset = ctx.attrs.top[HDLFileInfo].set
    source_files = source_files_tset.project_as_json("json", ordering="postorder")
    

    out_file = {
        "flow": "synthesis",
        "part": ctx.attrs.part,
        "max_threads": 8,
        "synth_args": "",
        "sources": source_files,
        "constraints": constraints,
        "top_name": ctx.attrs.top_entity_name

    }
    in_json_file = ctx.actions.write_json("vivado_{}_input.json".format(flow), out_file, with_inputs=True)
    
    vivado_flow_tcl = ctx.actions.declare_output("{}.tcl".format(flow))

    vivado_gen = ctx.attrs._vivado_gen[RunInfo]
    cmd = cmd_args()
    cmd.add(vivado_gen)
    cmd.add("--input", in_json_file)
    cmd.add("--output", vivado_flow_tcl.as_output())

    ctx.actions.run(cmd, category="vivado_tcl_{}_gen".format(flow))

    vivado = cmd_args()
    vivado.add("vivado")
    vivado.add("-mode", "batch")
    vivado.add("-source", vivado_flow_tcl)
    vivado.add("-log", logfile.as_output())
    vivado.add("-journal", journal.as_output())
    vivado.add("-tclargs", checkpoint.as_output(), report.as_output())
    # because we're using the inputs to generate a tcl that *just* lists them,
    # irrespective of their content, we make the inputs here hidden inputs
    # so that if they change this step is re-run rather than just relying
    # on cache. We need this step to run if the input file content, or
    # constraint file content changes
    vivado.hidden(ctx.attrs.constraints)
    vivado.hidden(ctx.attrs.top.get(DefaultInfo).default_outputs)
    
    ctx.actions.run(vivado, category="vivado_{}".format(flow))
    providers.append(DefaultInfo(default_output=checkpoint))
    return providers


def optimize(ctx, input_checkpoint):
    flow = "optimize"
    name_and_flow = ctx.attrs.name + "_" + flow
    input_checkpoint = input_checkpoint[0].default_outputs[0]

    providers = []
    out_file = {
        "flow": flow,
        "max_threads": ctx.attrs.max_threads,
        "input_checkpoint": input_checkpoint,
    }
    in_json_file = ctx.actions.write_json("vivado_{}_input.json".format(flow), out_file, with_inputs=True)
    # create a checkpoint file
    out_checkpoint = ctx.actions.declare_output("{}.dcp".format(name_and_flow))
    # create a report file
    timing_report = ctx.actions.declare_output("{}_timing.rpt".format(name_and_flow))
    utilization_report = ctx.actions.declare_output("{}_utilization.rpt".format(name_and_flow))
    # create a log file
    logfile = ctx.actions.declare_output("{}.log".format(name_and_flow))
    # create a journal file
    journal = ctx.actions.declare_output("{}.jou".format(name_and_flow))
    # drc report
    drc = ctx.actions.declare_output("{}_drc.rpt".format(name_and_flow))

    vivado_flow_tcl = ctx.actions.declare_output("{}.tcl".format(flow))

    vivado_gen = ctx.attrs._vivado_gen[RunInfo]
    cmd = cmd_args()
    cmd.add(vivado_gen)
    cmd.add("--input", in_json_file)
    cmd.add("--output", vivado_flow_tcl.as_output())
    ctx.actions.run(cmd, category="vivado_tcl_{}_gen".format(flow))

    vivado = cmd_args()
    vivado.add("vivado")
    vivado.add("-mode", "batch")
    vivado.add("-source", vivado_flow_tcl)
    vivado.add("-log", logfile.as_output())
    vivado.add("-journal", journal.as_output())
    vivado.add("-tclargs", 
        out_checkpoint.as_output(), 
        timing_report.as_output(), 
        utilization_report.as_output(),
        drc.as_output()
    )
    # because we're using the inputs to generate a tcl that *just* lists them,
    # irrespective of their content, we make the checkpoint a hidden input
    # so that if it changesthis step is re-run rather than just relying
    # on cache. We need this step to run if the input file content, or
    # constraint file content changes
    vivado.hidden(input_checkpoint)
    
    ctx.actions.run(vivado, category="vivado_{}".format(flow))
    providers.append(DefaultInfo(default_output=out_checkpoint))
    return providers

def place(ctx, input_checkpoint, optimize=False):
    flow = "place_optimize" if optimize else "place"
    name_and_flow = ctx.attrs.name + "_" + flow
    input_checkpoint = input_checkpoint[0].default_outputs[0]

    providers = []
    out_file = {
        "flow": flow,
        "max_threads": ctx.attrs.max_threads,
        "input_checkpoint": input_checkpoint,
    }

    in_json_file = ctx.actions.write_json("vivado_{}_input.json".format(flow), out_file, with_inputs=True)
    # create a checkpoint file
    out_checkpoint = ctx.actions.declare_output("{}.dcp".format(name_and_flow))
    # create a report file
    timing_report = ctx.actions.declare_output("{}_timing.rpt".format(name_and_flow))
    utilization_report = ctx.actions.declare_output("{}_utilization.rpt".format(name_and_flow))
    # create a log file
    logfile = ctx.actions.declare_output("{}log".format(name_and_flow))
    # create a journal file
    journal = ctx.actions.declare_output("{}.jou".format(name_and_flow))

    vivado_flow_tcl = ctx.actions.declare_output("{}.tcl".format(flow))

    vivado_gen = ctx.attrs._vivado_gen[RunInfo]
    cmd = cmd_args()
    cmd.add(vivado_gen)
    cmd.add("--input", in_json_file)
    cmd.add("--output", vivado_flow_tcl.as_output())
    ctx.actions.run(cmd, category="vivado_tcl_{}_gen".format(flow))

    vivado = cmd_args()
    vivado.add("vivado")
    vivado.add("-mode", "batch")
    vivado.add("-source", vivado_flow_tcl)
    vivado.add("-log", logfile.as_output())
    vivado.add("-journal", journal.as_output())
    vivado.add("-tclargs", 
        out_checkpoint.as_output(), 
        timing_report.as_output(), 
        utilization_report.as_output()
    )
    # because we're using the inputs to generate a tcl that *just* lists them,
    # irrespective of their content, we make the checkpoint a hidden input
    # so that if it changesthis step is re-run rather than just relying
    # on cache. We need this step to run if the input file content, or
    # constraint file content changes
    vivado.hidden(input_checkpoint)
    
    ctx.actions.run(vivado, category="vivado_{}".format(flow))
    providers.append(DefaultInfo(default_output=out_checkpoint))
    return providers

def route(ctx, input_checkpoint):
    flow = "route"
    name_and_flow = ctx.attrs.name + "_" + flow
    input_checkpoint = input_checkpoint[0].default_outputs[0]
    providers = []
    out_file = {
        "flow": flow,
        "max_threads": ctx.attrs.max_threads,
        "input_checkpoint": input_checkpoint,
    }

    in_json_file = ctx.actions.write_json("vivado_{}_input.json".format(flow), out_file, with_inputs=True)
    # create a checkpoint file
    out_checkpoint = ctx.actions.declare_output("{}.dcp".format(name_and_flow))
    # create reports files
    timing_report = ctx.actions.declare_output("{}_timing.rpt".format(name_and_flow))
    utilization_report = ctx.actions.declare_output("{}_utilization.rpt".format(name_and_flow))
    route_status_report = ctx.actions.declare_output("{}_route_status.rpt".format(name_and_flow))
    io_report = ctx.actions.declare_output("{}_io.rpt".format(name_and_flow))
    power_report = ctx.actions.declare_output("{}_power.rpt".format(name_and_flow))
    io_timing_report = ctx.actions.declare_output("{}_io_timing.rpt".format(name_and_flow))
    # create a log file
    logfile = ctx.actions.declare_output("{}log".format(name_and_flow))
    # create a journal file
    journal = ctx.actions.declare_output("{}.jou".format(name_and_flow))

    vivado_flow_tcl = ctx.actions.declare_output("{}.tcl".format(flow))

    vivado_gen = ctx.attrs._vivado_gen[RunInfo]
    cmd = cmd_args()
    cmd.add(vivado_gen)
    cmd.add("--input", in_json_file)
    cmd.add("--output", vivado_flow_tcl.as_output())
    ctx.actions.run(cmd, category="vivado_tcl_{}_gen".format(flow))

    vivado = cmd_args()
    vivado.add("vivado")
    vivado.add("-mode", "batch")
    vivado.add("-source", vivado_flow_tcl)
    vivado.add("-log", logfile.as_output())
    vivado.add("-journal", journal.as_output())
    vivado.add("-tclargs", 
        out_checkpoint.as_output(), 
        timing_report.as_output(), 
        utilization_report.as_output(),
        route_status_report.as_output(),
        io_report.as_output(),
        power_report.as_output(),
        io_timing_report.as_output(),
    )
    # because we're using the inputs to generate a tcl that *just* lists them,
    # irrespective of their content, we make the checkpoint a hidden input
    # so that if it changesthis step is re-run rather than just relying
    # on cache. We need this step to run if the input file content, or
    # constraint file content changes
    vivado.hidden(input_checkpoint)
    
    ctx.actions.run(vivado, category="vivado_{}".format(flow))
    providers.append(DefaultInfo(default_output=out_checkpoint))
    return providers

def bitstream(ctx, input_checkpoint):
    flow = "bitstream"
    name_and_flow = ctx.attrs.name + "_" + flow
    input_checkpoint = input_checkpoint[0].default_outputs[0]

    providers = []
    out_file = {
        "flow": flow,
        "max_threads": ctx.attrs.max_threads,
        "input_checkpoint": input_checkpoint,
    }
    in_json_file = ctx.actions.write_json("vivado_{}_input.json".format(flow), out_file, with_inputs=True)
    
    # create a bitstream file
    bitstream = ctx.actions.declare_output("{}.bit".format(ctx.attrs.name))
    # create a log file
    logfile = ctx.actions.declare_output("{}.log".format(name_and_flow))
    # create a journal file
    journal = ctx.actions.declare_output("{}.jou".format(name_and_flow))

    vivado_flow_tcl = ctx.actions.declare_output("{}.tcl".format(flow))

    vivado_gen = ctx.attrs._vivado_gen[RunInfo]
    cmd = cmd_args()
    cmd.add(vivado_gen)
    cmd.add("--input", in_json_file)
    cmd.add("--output", vivado_flow_tcl.as_output())
    ctx.actions.run(cmd, category="vivado_tcl_{}_gen".format(flow))

    vivado = cmd_args()
    vivado.add("vivado")
    vivado.add("-mode", "batch")
    vivado.add("-source", vivado_flow_tcl)
    vivado.add("-log", logfile.as_output())
    vivado.add("-journal", journal.as_output())
    vivado.add("-tclargs", 
        bitstream.as_output(),
    )
    # because we're using the inputs to generate a tcl that *just* lists them,
    # irrespective of their content, we make the checkpoint a hidden input
    # so that if it changesthis step is re-run rather than just relying
    # on cache. We need this step to run if the input file content, or
    # constraint file content changes
    vivado.hidden(input_checkpoint)
    
    ctx.actions.run(vivado, category="vivado_{}".format(flow))
    providers.append(DefaultInfo(default_output=bitstream))
    return providers

vivado_bitstream = rule(
    impl=_vivado_bitstream,
    attrs={
        "top_entity_name": attrs.string(),
        "top": attrs.dep(doc="Expected top HDL unit"),
        "part": attrs.string(doc="Vivado-compatible FPGA string"),
        "constraints": attrs.list(attrs.source(doc="Part constraint files"), default=[]),
        "synth_args":  attrs.list(attrs.string(), default = []),
        "max_threads": attrs.int(doc="Max threads for Vivado", default=8),
        "_vivado_gen": attrs.exec_dep(
                doc="Generate a Vivado tcl for this project",
                default="root//tools/vivado_gen:vivado_gen",
            ),
    },
)