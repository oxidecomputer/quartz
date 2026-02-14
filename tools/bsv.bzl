# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.
#
# Copyright 2026 Oxide Computer Company

# BSV (Bluespec SystemVerilog) build rules

load(":bsv_common.bzl", "BSVFileInfo", "BSVLibraryInfo", "BSVVerilogInfo", "BSVSimInfo", "BSVFileInfoTSet")
load(":hdl_common.bzl", "RDLBSVPkgs")
# Toolchain accessed via RunInfo - no custom provider needed

def _bsv_library_impl(ctx: AnalysisContext) -> list[Provider]:
    """Compile BSV sources to .bo object files"""

    # Get toolchain
    bsc = ctx.attrs._toolchain[RunInfo]

    # Collect dependency TSets
    deps_tsets = [
        dep[BSVLibraryInfo].tset
        for dep in ctx.attrs.deps
        if BSVLibraryInfo in dep
    ]

    # Create unique output directory (hash sources to avoid collisions)
    # This prevents stale .bo file issues when sources move between targets
    source_paths = sorted([s.short_path for s in ctx.attrs.srcs])
    source_hash = hash(":".join(source_paths))
    bo_dir_name = "bo_{}".format(abs(source_hash))

    # For multi-source, declare individual .bo files; for single source, declare directory
    bo_dir = None
    bo_artifacts = []
    source_infos = []

    # Declare outputs based on source count
    if len(ctx.attrs.srcs) == 1:
        bo_dir = ctx.actions.declare_output(bo_dir_name, dir = True)
    else:
        # Declare each .bo file individually for multi-source libraries
        for src in ctx.attrs.srcs:
            module_name = src.basename.removesuffix(".bsv").removesuffix(".bs")
            bo_file = ctx.actions.declare_output("{}/{}.bo".format(bo_dir_name, module_name))
            bo_artifacts.append(bo_file)

    # Build bo search path from dependencies using TSet projection
    # The projection will collect all bo_dir artifacts from the transitive closure
    # For sim rule, we need to project from TSets, not just direct deps
    if deps_tsets:
        # Get all bo paths from transitive closure and join with ":"
        # Note: The projection already returns all transitive paths
        all_paths = cmd_args()
        for dep_tset in deps_tsets:
            bo_paths = dep_tset.project_as_args("bo_paths", ordering = "postorder")
            all_paths.add(bo_paths)
        # Join all paths with ":" and prepend with "+:"
        bo_search_cmd = cmd_args(all_paths, delimiter = ":", format = "+:{}")
    else:
        bo_search_cmd = cmd_args("+")

    # Collect all dependency .bo file projections as inputs for proper dependency tracking
    dep_bo_projections = []
    for dep_tset in deps_tsets:
        dep_bo_projections.append(dep_tset.project_as_args("sources", ordering = "postorder"))

    # Also collect RDL-generated BSV files as dependencies
    rdl_bsv_files = []
    for dep in ctx.attrs.deps:
        if RDLBSVPkgs in dep:
            rdl_bsv_files.extend(dep[RDLBSVPkgs].files)

    # Use wrapper script to create directory and run bsc
    wrapper = ctx.attrs._bsv_wrapper[RunInfo]

    # Build hidden dependencies list
    hidden_deps = dep_bo_projections + rdl_bsv_files

    # For single source files, compile directly
    if len(ctx.attrs.srcs) == 1:
        bsc_cmd = cmd_args(wrapper, hidden = [bo_dir.as_output()] + hidden_deps)
        bsc_cmd.add(bsc)  # Path to bsc
        bsc_cmd.add(bo_dir.as_output())  # Output directory
        bsc_cmd.add(ctx.attrs.bsc_flags)
        bsc_cmd.add("-p")
        bsc_cmd.add(bo_search_cmd)
        bsc_cmd.add("-bdir", bo_dir.as_output())
        bsc_cmd.add(ctx.attrs.srcs[0])

        ctx.actions.run(
            bsc_cmd,
            category = "bsv_compile",
        )
    else:
        # For multiple sources, compile each separately with individual .bo outputs (already declared above)
        for idx, src in enumerate(ctx.attrs.srcs):
            module_name = src.basename.removesuffix(".bsv").removesuffix(".bs")
            bo_file = bo_artifacts[idx]

            # Call as_output() only once and reuse the bound output
            bo_output = bo_file.as_output()

            bsc_cmd = cmd_args(wrapper, hidden = hidden_deps + bo_artifacts[:idx])  # Include previous .bo files for intra-library deps
            bsc_cmd.add(bsc)
            bsc_cmd.add(bo_output)  # Specific output file (wrapper creates parent dir)
            bsc_cmd.add(ctx.attrs.bsc_flags)
            bsc_cmd.add("-p")
            # For files after the first, add the current library's bo directory to search path
            # so they can find previously compiled .bo files from the same library
            if idx > 0:
                # Get parent directory of current .bo file (same for all files in this library)
                current_lib_bo_dir = cmd_args(bo_output, parent = 1)
                # Append to search path
                bsc_cmd.add(cmd_args(bo_search_cmd, current_lib_bo_dir, delimiter = ":"))
            else:
                bsc_cmd.add(bo_search_cmd)
            bsc_cmd.add("-bdir", bo_output)  # Wrapper will use parent directory
            bsc_cmd.add(src)

            ctx.actions.run(
                bsc_cmd,
                category = "bsv_compile",
                identifier = module_name,
            )

    # Create BSVFileInfo records for each source
    # For bo_dir in BSVFileInfo, we need an artifact representing the directory
    # For single-source, it's bo_dir; for multi-source, we declare a directory artifact
    if not bo_dir:
        # Multi-source case - create a directory artifact for the TSet projection
        bo_dir_for_info = ctx.actions.symlinked_dir("{}_dir".format(bo_dir_name), {
            bo.basename: bo for bo in bo_artifacts
        })
    else:
        bo_dir_for_info = bo_dir

    for src in ctx.attrs.srcs:
        # Extract module name from filename
        module_name = src.basename.removesuffix(".bsv").removesuffix(".bs")

        source_infos.append(
            BSVFileInfo(
                src = src,
                bo = None,  # .bo files are in the directory, not individual artifacts
                bo_dir = bo_dir_for_info,  # Use dir or symlinked dir
                module = module_name,
                is_synth = ctx.attrs.is_synth,
            ),
        )

    # Build transitive set with this library's sources and deps as children
    local_tsets = [
        ctx.actions.tset(BSVFileInfoTSet, value = info, children = deps_tsets)
        for info in source_infos
    ]
    top_tset = ctx.actions.tset(BSVFileInfoTSet, children = local_tsets)

    # Determine default outputs
    default_outputs = [bo_dir_for_info]

    return [
        BSVLibraryInfo(tset = top_tset, bo_dir = bo_dir_for_info),
        DefaultInfo(default_outputs = default_outputs),
    ]

bsv_library = rule(
    impl = _bsv_library_impl,
    attrs = {
        "srcs": attrs.list(attrs.source(), doc = "BSV source files"),
        "deps": attrs.list(attrs.dep(), default = [], doc = "BSV library dependencies"),
        "bsc_flags": attrs.list(attrs.string(), default = [], doc = "Additional bsc compiler flags"),
        "is_synth": attrs.bool(default = True, doc = "For synthesis vs sim-only"),
        "_toolchain": attrs.toolchain_dep(default = "toolchains//:bsv"),
        "_bsv_wrapper": attrs.exec_dep(default = "//tools:bsv_compile_wrapper"),
    },
)

def _bsv_verilog_impl(ctx: AnalysisContext) -> list[Provider]:
    """Generate Verilog from BSV modules for synthesis"""

    bsc = ctx.attrs._toolchain[RunInfo]
    top_src = ctx.attrs.top

    # Collect dependency TSets
    deps_tsets = [
        dep[BSVLibraryInfo].tset
        for dep in ctx.attrs.deps
        if BSVLibraryInfo in dep
    ]

    # Build bo search path from dependencies using TSet projection
    # This collects ALL transitive dependencies automatically
    if deps_tsets:
        paths_joined = cmd_args()
        for dep_tset in deps_tsets:
            bo_paths = dep_tset.project_as_args("bo_paths", ordering = "postorder")
            paths_joined.add(bo_paths)
        bo_search_cmd = cmd_args(paths_joined, delimiter = ":", format = "+:{}")
    else:
        bo_search_cmd = cmd_args("+")

    verilog_modules = {}

    # Collect all dependency .bo file projections as inputs for proper dependency tracking
    dep_bo_projections = []
    for dep_tset in deps_tsets:
        dep_bo_projections.append(dep_tset.project_as_args("sources", ordering = "postorder"))

    for module_name in ctx.attrs.modules:
        # Output directories
        v_dir = ctx.actions.declare_output("verilog_{}".format(module_name), dir = True)
        temp_bo_dir = ctx.actions.declare_output("bo_verilog_{}".format(module_name), dir = True)

        # Use wrapper script to create directories and run bsc
        wrapper = ctx.attrs._bsv_wrapper[RunInfo]

        # Build hidden dependencies list
        hidden_deps = [v_dir.as_output(), temp_bo_dir.as_output()] + dep_bo_projections

        # Create verilog directory first
        v_wrapper_cmd = cmd_args(wrapper, hidden = hidden_deps)
        v_wrapper_cmd.add(bsc)  # Path to bsc
        v_wrapper_cmd.add(temp_bo_dir.as_output())  # Output directory for wrapper to create
        v_wrapper_cmd.add("--extra-dir", v_dir.as_output())  # Additional directory to create

        # Add verilog-filter if provided
        if ctx.attrs.verilog_filter:
            v_wrapper_cmd.add("-verilog-filter", ctx.attrs.verilog_filter)

        v_wrapper_cmd.add(ctx.attrs.bsc_flags)
        v_wrapper_cmd.add("-verilog")
        v_wrapper_cmd.add("-g", module_name)
        v_wrapper_cmd.add("-p")
        v_wrapper_cmd.add(bo_search_cmd)
        v_wrapper_cmd.add("-bdir", temp_bo_dir.as_output())
        v_wrapper_cmd.add("-vdir", v_dir.as_output())
        v_wrapper_cmd.add(top_src)

        ctx.actions.run(
            v_wrapper_cmd,
            category = "bsv_verilog",
            identifier = module_name,
        )

        verilog_modules[module_name] = v_dir

    return [
        BSVVerilogInfo(modules = verilog_modules),
        DefaultInfo(default_outputs = list(verilog_modules.values())),
    ]

bsv_verilog = rule(
    impl = _bsv_verilog_impl,
    attrs = {
        "top": attrs.source(doc = "Top BSV source file"),
        "modules": attrs.list(attrs.string(), doc = "Module names to generate Verilog for"),
        "deps": attrs.list(attrs.dep(), default = []),
        "bsc_flags": attrs.list(attrs.string(), default = []),
        "verilog_filter": attrs.option(attrs.source(), default = None, doc = "Optional Verilog filter script (e.g., basicinout.pl)"),
        "_toolchain": attrs.toolchain_dep(default = "toolchains//:bsv"),
        "_bsv_wrapper": attrs.exec_dep(default = "//tools:bsv_compile_wrapper"),
    },
)

def _bsv_sim_impl(ctx: AnalysisContext) -> list[Provider]:
    """Generate Bluesim .ba bytecode files"""

    bsc = ctx.attrs._toolchain[RunInfo]
    top_src = ctx.attrs.top

    # Collect deps (same pattern as bsv_verilog)
    deps_tsets = [
        dep[BSVLibraryInfo].tset
        for dep in ctx.attrs.deps
        if BSVLibraryInfo in dep
    ]

    # Build bo search path from dependencies using TSet projection
    # This collects ALL transitive dependencies automatically
    if deps_tsets:
        paths_joined = cmd_args()
        for dep_tset in deps_tsets:
            bo_paths = dep_tset.project_as_args("bo_paths", ordering = "postorder")
            paths_joined.add(bo_paths)
        bo_search_cmd = cmd_args(paths_joined, delimiter = ":", format = "+:{}")
    else:
        bo_search_cmd = cmd_args("+")

    # Collect all dependency .bo file projections as inputs for proper dependency tracking
    dep_bo_projections = []
    for dep_tset in deps_tsets:
        dep_bo_projections.append(dep_tset.project_as_args("sources", ordering = "postorder"))

    ba_files = {}

    for module_name in ctx.attrs.modules:
        # Output directory - bsc will create both .bo and .ba files here
        sim_dir = ctx.actions.declare_output("bluesim_{}".format(module_name), dir = True)

        # Use wrapper script to create directory and run bsc
        wrapper = ctx.attrs._bsv_wrapper[RunInfo]

        # Build hidden dependencies list
        hidden_deps = [sim_dir.as_output()] + dep_bo_projections

        bsc_cmd = cmd_args(wrapper, hidden = hidden_deps)
        bsc_cmd.add(bsc)  # Path to bsc
        bsc_cmd.add(sim_dir.as_output())  # Output directory for wrapper to create
        bsc_cmd.add(ctx.attrs.bsc_flags)
        bsc_cmd.add("-sim")  # Simulation mode (not -verilog)
        bsc_cmd.add("-g", module_name)
        bsc_cmd.add("-p")
        bsc_cmd.add(bo_search_cmd)
        bsc_cmd.add("-bdir", sim_dir.as_output())
        bsc_cmd.add("-simdir", sim_dir.as_output())
        bsc_cmd.add(top_src)

        ctx.actions.run(
            bsc_cmd,
            category = "bsv_sim",
            identifier = module_name,
        )

        # Store the directory containing the .ba file
        ba_files[module_name] = sim_dir

    return [
        DefaultInfo(default_outputs = list(ba_files.values())),
    ]

bsv_sim = rule(
    impl = _bsv_sim_impl,
    attrs = {
        "top": attrs.source(doc = "Top BSV source file"),
        "modules": attrs.list(attrs.string(), doc = "Module names to generate Bluesim for"),
        "deps": attrs.list(attrs.dep(), default = []),
        "bsc_flags": attrs.list(attrs.string(), default = []),
        "_toolchain": attrs.toolchain_dep(default = "toolchains//:bsv"),
        "_bsv_wrapper": attrs.exec_dep(default = "//tools:bsv_compile_wrapper"),
    },
)

def _bsv_bluesim_binary_impl(ctx: AnalysisContext) -> list[Provider]:
    """Link Bluesim executable from .ba bytecode directory"""

    bsc = ctx.attrs._toolchain[RunInfo]

    # Get directory containing .ba files from bsv_sim dependency
    sim_dep = ctx.attrs.top[DefaultInfo].default_outputs[0]

    # Construct path to .ba file: <sim_dir>/<entry_point>.ba
    ba_file_path = cmd_args(sim_dep, format = "{}/{}".format("{}", ctx.attrs.entry_point + ".ba"))

    # Output files
    script = ctx.actions.declare_output(ctx.attrs.name)
    so_file = ctx.actions.declare_output("{}.so".format(ctx.attrs.name))

    # Create a temporary directory for the so_file output
    simdir = ctx.actions.declare_output("simdir_{}".format(ctx.attrs.name), dir = True)

    # Use wrapper script to create directory and run bsc link
    wrapper = ctx.attrs._bsv_wrapper[RunInfo]
    bsc_cmd = cmd_args(wrapper, hidden = [sim_dep, script.as_output(), so_file.as_output(), simdir.as_output()])
    bsc_cmd.add(bsc)  # Path to bsc
    bsc_cmd.add(simdir.as_output())  # Output directory for wrapper to create
    bsc_cmd.add("-sim")
    bsc_cmd.add("-e", ctx.attrs.entry_point)
    bsc_cmd.add("-o", script.as_output())
    bsc_cmd.add("-simdir", simdir.as_output())
    bsc_cmd.add(ba_file_path)

    ctx.actions.run(
        bsc_cmd,
        category = "bsv_link_sim",
    )

    # Create RunInfo for executing simulation
    run_cmd = cmd_args(script)

    return [
        BSVSimInfo(script = script, so = so_file),
        DefaultInfo(default_output = script),
        RunInfo(run_cmd),
    ]

bsv_bluesim_binary = rule(
    impl = _bsv_bluesim_binary_impl,
    attrs = {
        "top": attrs.dep(doc = "bsv_sim target that generated .ba files"),
        "entry_point": attrs.string(doc = "Top module name to execute"),
        "deps": attrs.list(attrs.dep(), default = []),
        "_toolchain": attrs.toolchain_dep(default = "toolchains//:bsv"),
        "_bsv_wrapper": attrs.exec_dep(default = "//tools:bsv_compile_wrapper"),
    },
)

def bsv_bluesim_tests(name, suite, modules, deps = [], **kwargs):
    """
    Create Bluesim test targets (convenience macro that mimics cobble bluesim_tests).

    This macro generates:
    1. A bsv_sim rule to compile test modules to .ba bytecode
    2. A bsv_bluesim_binary rule for each test module to create runnable executables

    Args:
        name: Base name for the test suite
        suite: BSV source file containing test modules
        modules: List of test module names to compile
        deps: BSV library dependencies
        **kwargs: Additional arguments passed to bsv_sim

    Usage:
        bsv_bluesim_tests(
            name = "CountdownTests",
            suite = "Countdown.bsv",
            modules = ["mkCountdownTest"],
            deps = [":Countdown"],
        )

        # Run with: buck2 run //path/to:CountdownTests_mkCountdownTest
    """

    # Create separate bsv_sim and bsv_bluesim_binary targets for each test module
    for module in modules:
        sim_name = "{}_{}_sim".format(name, module)
        test_name = "{}_{}".format(name, module)

        # Generate .ba file for this specific module
        bsv_sim(
            name = sim_name,
            top = suite,
            modules = [module],  # Only generate this one module
            deps = deps,
            **kwargs
        )

        # Create executable binary for this test module
        bsv_bluesim_binary(
            name = test_name,
            top = ":{}".format(sim_name),
            entry_point = module,
            deps = [":{}".format(sim_name)],
        )

# ==============================================================================
# FPGA Bitstream Generation Rules
# ==============================================================================

def _bsv_yosys_design_impl(ctx: AnalysisContext) -> list[Provider]:
    """Synthesize BSV-generated Verilog with Yosys to create JSON netlist"""

    # Get BSV Verilog output
    verilog_provider = ctx.attrs.verilog_dep[BSVVerilogInfo]

    # Get the specific module's verilog directory
    if ctx.attrs.top_module not in verilog_provider.modules:
        fail("Module '{}' not found in verilog_dep. Available modules: {}".format(
            ctx.attrs.top_module,
            list(verilog_provider.modules.keys())
        ))

    verilog_dir = verilog_provider.modules[ctx.attrs.top_module]

    # Collect all Verilog sources (BSV-generated + dependencies)
    verilog_sources = [verilog_dir]

    # Add any additional Verilog sources (like Bluespec Verilog.v)
    for src_dep in ctx.attrs.extra_sources:
        verilog_sources.append(src_dep)

    # Output JSON file from Yosys
    yosys_json = ctx.actions.declare_output("{}.json".format(ctx.attrs.name))
    yosys_log = ctx.actions.declare_output("{}.log".format(ctx.attrs.name))

    # Run Yosys synthesis
    yosys_cmd = cmd_args()
    yosys_cmd.add(ctx.attrs._yosys[RunInfo])

    # Read Verilog files - use cmd_args to properly handle artifact path
    # Define SYNTHESIS to skip simulation-only blocks
    read_verilog_cmd = cmd_args(verilog_dir, format="-p read_verilog -sv -D SYNTHESIS {}/*.v")
    yosys_cmd.add(read_verilog_cmd)

    # Add extra sources (also with SYNTHESIS define)
    for extra_src in ctx.attrs.extra_sources:
        yosys_cmd.add("-p", cmd_args("read_verilog -sv -D SYNTHESIS ", extra_src, delimiter=""))

    # Synthesis command - support both ice40 and ecp5
    target = ctx.attrs.target if ctx.attrs.target else "ice40"  # Default for backward compatibility
    synth_cmd = cmd_args(yosys_json.as_output(), format="-p synth_{} -top {} -json {{}}".format(target, ctx.attrs.top_module))
    yosys_cmd.add(synth_cmd)

    # Log output
    yosys_cmd.add("-l", yosys_log.as_output())

    ctx.actions.run(
        yosys_cmd,
        category = "yosys_synth",
    )

    return [
        DefaultInfo(default_output = yosys_json),
    ]

bsv_yosys_design = rule(
    impl = _bsv_yosys_design_impl,
    attrs = {
        "top_module": attrs.string(doc = "Top module name for synthesis"),
        "verilog_dep": attrs.dep(doc = "bsv_verilog rule that generates the Verilog"),
        "extra_sources": attrs.list(attrs.source(), default = [], doc = "Additional Verilog sources (e.g., Bluespec Verilog.v)"),
        "target": attrs.option(attrs.string(), default = None, doc = "Synthesis target (ice40, ecp5, etc.). Defaults to ice40."),
        "_yosys": attrs.toolchain_dep(default = "toolchains//:yosys"),
    },
)

def _bsv_nextpnr_ice40_bitstream_impl(ctx: AnalysisContext) -> list[Provider]:
    """Place and route with nextpnr-ice40 and generate bitstream with icepack"""

    # Get Yosys JSON from dependency
    yosys_json = ctx.attrs.yosys_design[DefaultInfo].default_outputs[0]

    # Output files
    asc_file = ctx.actions.declare_output("{}.asc".format(ctx.attrs.name))
    bit_file = ctx.actions.declare_output("{}.bin".format(ctx.attrs.name))
    pnr_log = ctx.actions.declare_output("nextpnr.log")

    # Run nextpnr-ice40
    pnr_cmd = cmd_args()
    pnr_cmd.add(ctx.attrs._nextpnr_ice40[RunInfo])
    pnr_cmd.add("--{}".format(ctx.attrs.family))  # e.g., --up5k
    pnr_cmd.add("--package", ctx.attrs.package)   # e.g., sg48
    pnr_cmd.add("--pcf", ctx.attrs.pinmap)        # Pin constraints
    pnr_cmd.add("--json", yosys_json)
    pnr_cmd.add("--asc", asc_file.as_output())
    pnr_cmd.add("--log", pnr_log.as_output())

    # Add any additional nextpnr arguments
    for arg in ctx.attrs.nextpnr_args:
        pnr_cmd.add(arg)

    ctx.actions.run(
        pnr_cmd,
        category = "nextpnr",
    )

    # Version stamping: patch BRAM init data with real git version
    icepack_input = asc_file
    if ctx.attrs.version_template_hex and ctx.attrs.version_replacement_hex:
        stamped_asc = ctx.actions.declare_output("{}_stamped.asc".format(ctx.attrs.name))
        stamp_cmd = cmd_args()
        stamp_cmd.add("python3", ctx.attrs._icebram_wrapper)
        stamp_cmd.add(ctx.attrs._icebram[RunInfo])
        stamp_cmd.add(ctx.attrs.version_template_hex)
        stamp_cmd.add(ctx.attrs.version_replacement_hex)
        stamp_cmd.add(asc_file)
        stamp_cmd.add(stamped_asc.as_output())

        ctx.actions.run(
            stamp_cmd,
            category = "icebram",
        )
        icepack_input = stamped_asc

    # Run icepack to create bitstream
    icepack_cmd = cmd_args()
    icepack_cmd.add(ctx.attrs._icepack[RunInfo])
    icepack_cmd.add(icepack_input)
    icepack_cmd.add(bit_file.as_output())

    ctx.actions.run(
        icepack_cmd,
        category = "icepack",
    )

    return [
        DefaultInfo(
            default_output = bit_file,
            sub_targets = {
                "asc": [DefaultInfo(default_output = asc_file)],
                "json": [DefaultInfo(default_output = yosys_json)],
            }
        ),
    ]

bsv_nextpnr_ice40_bitstream = rule(
    impl = _bsv_nextpnr_ice40_bitstream_impl,
    attrs = {
        "yosys_design": attrs.dep(doc = "bsv_yosys_design rule that produces JSON netlist"),
        "family": attrs.string(doc = "FPGA family (e.g., 'up5k', 'hx8k')"),
        "package": attrs.string(doc = "FPGA package (e.g., 'sg48', 'ct256')"),
        "pinmap": attrs.source(doc = "Pin constraints file (.pcf)"),
        "nextpnr_args": attrs.list(attrs.string(), default = [], doc = "Additional nextpnr arguments"),
        "version_template_hex": attrs.option(attrs.source(), default = None, doc = "Template hex for icebram (from pattern)"),
        "version_replacement_hex": attrs.option(attrs.source(), default = None, doc = "Replacement hex for icebram (volatile, git data)"),
        "_nextpnr_ice40": attrs.toolchain_dep(default = "toolchains//:nextpnr-ice40"),
        "_icepack": attrs.toolchain_dep(default = "toolchains//:icepack"),
        "_icebram": attrs.toolchain_dep(default = "toolchains//:icebram"),
        "_icebram_wrapper": attrs.source(default = "//tools:icebram_wrapper"),
    },
)

# ==============================================================================
# ECP5 Bitstream Generation
# ==============================================================================

def _bsv_nextpnr_ecp5_bitstream_impl(ctx: AnalysisContext) -> list[Provider]:
    """Place and route with nextpnr-ecp5 and generate bitstream with ecppack"""

    # Get Yosys JSON from dependency
    yosys_json = ctx.attrs.yosys_design[DefaultInfo].default_outputs[0]

    # Output files
    config_file = ctx.actions.declare_output("{}.config".format(ctx.attrs.name))
    bit_file = ctx.actions.declare_output("{}.bit".format(ctx.attrs.name))
    pnr_log = ctx.actions.declare_output("nextpnr.log")

    # Run nextpnr-ecp5
    pnr_cmd = cmd_args()
    pnr_cmd.add(ctx.attrs._nextpnr_ecp5[RunInfo])
    pnr_cmd.add("--{}".format(ctx.attrs.family))  # e.g., --25k, --45k, --85k
    pnr_cmd.add("--package", ctx.attrs.package)   # e.g., CABGA381, CSFBGA285
    pnr_cmd.add("--lpf", ctx.attrs.pinmap)        # Pin constraints (.lpf file)
    pnr_cmd.add("--json", yosys_json)
    pnr_cmd.add("--textcfg", config_file.as_output())
    pnr_cmd.add("--log", pnr_log.as_output())

    # Add any additional nextpnr arguments
    for arg in ctx.attrs.nextpnr_args:
        pnr_cmd.add(arg)

    ctx.actions.run(
        pnr_cmd,
        category = "nextpnr_ecp5",
    )

    # Version stamping: patch BRAM init data with real git version
    ecppack_input = config_file
    if ctx.attrs.version_template_hex and ctx.attrs.version_replacement_hex:
        stamped_config = ctx.actions.declare_output("{}_stamped.config".format(ctx.attrs.name))
        stamp_cmd = cmd_args()
        stamp_cmd.add("python3", ctx.attrs._ecpbram_wrapper)
        stamp_cmd.add(ctx.attrs._ecpbram[RunInfo])
        stamp_cmd.add(ctx.attrs.version_template_hex)
        stamp_cmd.add(ctx.attrs.version_replacement_hex)
        stamp_cmd.add(config_file)
        stamp_cmd.add(stamped_config.as_output())

        ctx.actions.run(
            stamp_cmd,
            category = "ecpbram",
        )
        ecppack_input = stamped_config

    # Run ecppack to create bitstream
    ecppack_cmd = cmd_args()
    ecppack_cmd.add(ctx.attrs._ecppack[RunInfo])
    ecppack_cmd.add(ecppack_input)
    ecppack_cmd.add(bit_file.as_output())

    ctx.actions.run(
        ecppack_cmd,
        category = "ecppack",
    )

    return [
        DefaultInfo(
            default_output = bit_file,
            sub_targets = {
                "config": [DefaultInfo(default_output = config_file)],
                "json": [DefaultInfo(default_output = yosys_json)],
            }
        ),
    ]

bsv_nextpnr_ecp5_bitstream = rule(
    impl = _bsv_nextpnr_ecp5_bitstream_impl,
    attrs = {
        "yosys_design": attrs.dep(doc = "bsv_yosys_design rule that produces JSON netlist"),
        "family": attrs.string(doc = "FPGA family (e.g., '25k', '45k', '85k')"),
        "package": attrs.string(doc = "FPGA package (e.g., 'CABGA381', 'CSFBGA285')"),
        "pinmap": attrs.source(doc = "Pin constraints file (.lpf)"),
        "nextpnr_args": attrs.list(attrs.string(), default = [], doc = "Additional nextpnr arguments"),
        "version_template_hex": attrs.option(attrs.source(), default = None, doc = "Template hex for ecpbram (from pattern)"),
        "version_replacement_hex": attrs.option(attrs.source(), default = None, doc = "Replacement hex for ecpbram (volatile, git data)"),
        "_nextpnr_ecp5": attrs.toolchain_dep(default = "toolchains//:nextpnr-ecp5"),
        "_ecppack": attrs.toolchain_dep(default = "toolchains//:ecppack"),
        "_ecpbram": attrs.toolchain_dep(default = "toolchains//:ecpbram"),
        "_ecpbram_wrapper": attrs.source(default = "//tools:icebram_wrapper"),
    },
)
