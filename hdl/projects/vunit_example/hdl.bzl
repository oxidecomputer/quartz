load("@prelude//utils:utils.bzl", "flatten")

def project_as_args(value: Artifact):
  return cmd_args(value)

UnitTSet = transitive_set(args_projections = { "args": project_as_args })

# HDL files can have 0 or more dependencies on other HDL files
HDLFileInfo = provider(fields = {
    "set": provider_field(UnitTSet)
})

def _hdl_unit_impl(ctx: AnalysisContext) -> list[Provider]:
    providers = []
    # Add the deps to a TSet for these files
    deps_tset = [x[HDLFileInfo].set for x in ctx.attrs.deps]
    
    # Make the deps a child of the tset containing any sources
    tops = [ctx.actions.tset(UnitTSet, value=x, children=deps_tset) for x in ctx.attrs.srcs]
    top_tset = ctx.actions.tset(UnitTSet, children=tops)
    providers.append(
        HDLFileInfo(
            set=top_tset,
        ))

    # do VUnit stuff here
    if ctx.attrs.is_tb:
        # Get the file-names in bottom-up order (doesn't matter for VUnit)
        in_args = top_tset.project_as_args("args", ordering = "postorder")
    
        # Generate the vunit run.py file output
        out_run_py= ctx.actions.declare_output("run.py")
        cmd = cmd_args()
        cmd.add("python3")
        cmd.add("./tools/vunit_gen/vunit_gen_cli.py")
        cmd.add("--inputs", in_args)
        cmd.add("--output", out_run_py.as_output())
        ctx.actions.run(cmd, category="vunit")

        # Left here as an example of how to put the vunit_out
        # folder into buck_out. This turns out to be a bit annoying
        # since the buck_out hashes change when the inputs change
        # making us re-compile everything
        #
        # Run the vunit run.py created above with --compile flag
        #vunit_out= ctx.actions.declare_output("vunit_out", dir=True) 
        #compile_only= cmd_args()
        #compile_only.add("python3")
        #compile_only.add(out_run_py)
        #ctx.actions.run(compile_only, category="vunit_compile")
        #providers.append(DefaultInfo(default_outputs=[out_run_py,vunit_out]))

        providers.append(DefaultInfo(default_output=out_run_py))

        #
        # Left here as an example of how set up the `buck test` command
        # Build a ExternalRunnerTestInfo to run this file from the command line
        #test_cmd = ["python3", out_run_py]
        #providers.append(ExternalRunnerTestInfo("vunit", test_cmd))

         # Build a RunInfo to run this file from the command line
        run_cmd = cmd_args("python3", out_run_py,)
        providers.append(RunInfo(run_cmd))
    else:
      providers.append(DefaultInfo(default_outputs=ctx.attrs.srcs)) # A little unclear that this is correct

    return providers

vhdl_unit = rule(
    impl = _hdl_unit_impl,
    attrs = {
        "deps": attrs.list(attrs.dep(), default=[]),
        "srcs": attrs.list(attrs.source()),
        "is_tb": attrs.bool(default=False),
    }
)
