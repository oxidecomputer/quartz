# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.
#
# Copyright 2024 Oxide Computer Company

load(
    "@prelude//python:toolchain.bzl",
    "PythonToolchainInfo",
)


# Take a TSet and project out the values as names for
# a command-line tool
def project_as_args(value: Artifact):
    return cmd_args(value)


# A TSet for HDL units
UnitTSet = transitive_set(args_projections={"args": project_as_args})

# HDL files can have 0 or more dependencies on other HDL files
# so we return a UnitTSet with the file and any deps (as TSets)
HDLFileInfo = provider(fields={"set": provider_field(UnitTSet)})

# Some build stages generate HDL that we'd like to do something
# with down-stream, so we return them as an Artifact so they can
# be dealt with specially if needed
GenVHDLInfo = provider(fields={"src": provider_field(Artifact)})


def _hdl_unit_impl(ctx: AnalysisContext) -> list[Provider]:
    providers = []

    # Add specified deps to a TSet for these files
    # These are normal vhdl files as dependencies (ie they have an HDLFileInfo provider)
    deps_tset = [x[HDLFileInfo].set for x in ctx.attrs.deps if x.get(HDLFileInfo)]

    # We may also have source files that are generated from something coming in
    # as a dependency.  These are expected to have a GenVHDLInfo provider attached.
    # We filter deps for things that provide GenVHDLInfo and then make a TSet for
    # these and extend the known dependencies for this file with these also.
    gen_deps_tset = [
        ctx.actions.tset(UnitTSet, value=x[GenVHDLInfo].src)
        for x in ctx.attrs.deps
        if x.get(GenVHDLInfo)
    ]
    # Merge all the deps
    deps_tset.extend(gen_deps_tset)

    # Now that we have all the deps, make them children of the tset containing any sources
    # We allow the user to specify multiple sources for convienience so we make all the deps
    # children of *every* source. This is most conservatively safe, and since the TSets are
    # merged in buck2 and shared DAG segments are only emmitted once when projecting, this
    # is pretty in-expensive.
    tops = [
        ctx.actions.tset(UnitTSet, value=x, children=deps_tset) for x in ctx.attrs.srcs
    ]
    top_tset = ctx.actions.tset(UnitTSet, children=tops)

    providers.append(
        HDLFileInfo(
            set=top_tset,
        )
    )

    # do VUnit stuff here if this is a test bench
    # Note that this is not acutally generated in the buck_out/ folder
    # After playing with this a bit, putting the vunitout folder in the
    # buck_out/ folder can be done (see info below) but is annoying since
    # we get a new buck_out/ each time the input changes meaning we have
    # to re-compile everything. We *could* attempt to do more here in buck
    # but it would essentially replace chunks of VUnit functionality and
    # VUnit is that *that* compatible with a flow lik this:
    # https://github.com/VUnit/vunit/pull/734 as an example from an attempted
    # bazel integration requiring some changes to VUnit sources.
    # If we find our current implementation to be limiting, we can look at
    # providing some isolation parameters or doing something different here
    # in the future
    if ctx.attrs.is_tb:
        # Get the vunit_gen python executable since we'll be using it for
        #  for generating our VUnit's run.py (from our toolchains defs)
        vunit_gen = ctx.attrs._bins[RunInfo]

        # Get the file-names in bottom-up order (order doesn't matter for VUnit
        # since it will maintain its own dependency relationships)
        in_args = top_tset.project_as_args("args", ordering="postorder")

        # Generate the VUnit run.py file output in buck_out/ somewhere
        out_run_py = ctx.actions.declare_output("run.py")
        cmd = cmd_args()
        cmd.add(vunit_gen)
        cmd.add("--inputs", in_args)
        cmd.add("--output", out_run_py.as_output())
        if ctx.attrs.simulator:
            cmd.add("--simulator", ctx.attrs.simulator)
        ctx.actions.run(cmd, category="vunit")

        # Left here as an example of how to put the vunit_out
        # folder into buck_out. This turns out to be a bit annoying
        # since the buck_out hashes change when the inputs change
        # making us re-compile everything
        #
        # Run the vunit run.py created above with --compile flag
        # vunit_out= ctx.actions.declare_output("vunit_out", dir=True)
        # compile_only= cmd_args()
        # compile_only.add(python)
        # compile_only.add(out_run_py)
        # ctx.actions.run(compile_only, category="vunit_compile")
        # providers.append(DefaultInfo(default_outputs=[out_run_py,vunit_out]))
        # Push the run.py we generated out as the Default here
        providers.append(DefaultInfo(default_output=out_run_py))

        # Get the system-python executable (from toolchains) since we'll be using it for
        #  for running VUnit itself
        python = ctx.attrs._toolchain[PythonToolchainInfo].interpreter

        #
        # Left here as an example of how set up the `buck2 test` command
        # Build a ExternalRunnerTestInfo to run this file from the command line
        # Test seems to have fewer arguments passing features and I haven't found
        # a reason to prefer that over just the `buck2 run` command
        # test_cmd = [python, out_run_py]
        # providers.append(ExternalRunnerTestInfo("vunit", test_cmd))

        # Build a RunInfo to run this file from the command line
        run_cmd = cmd_args(python, out_run_py)
        providers.append(RunInfo(run_cmd))
    else:
        providers.append(
            DefaultInfo(default_outputs=ctx.attrs.srcs)
        )  # A little unclear that this is correct, but we don't actually use this so :shrug:

    return providers


vhdl_unit = rule(
    impl=_hdl_unit_impl,
    attrs={
        "deps": attrs.list(
            attrs.dep(doc="Dependencies as dep types (ie from another rule)"),
            default=[],
        ),
        "srcs": attrs.list(attrs.source(doc="Expected VHDL sources")),
        "is_tb": attrs.bool(
            doc=(
                "Set to True when this is a top-level VUnit testbench\
            for which a run.py should be generate"
            ),
            default=False,
        ),
        "simulator": attrs.string(
            doc="nvc or ghdl",
            default="",
        ),
        "_toolchain": attrs.toolchain_dep(
            doc="Use system python toolchain for running VUnit",
            default="toolchains//:python",
        ),
        "_bins": attrs.exec_dep(
            doc="Use vunit_gen toolchain for generating VUnit run.pys",
            default="root//tools/vunit_gen:vunit_gen",
        ),
    },
)
