# RDL files can have 0 or more dependencies on other RDL files
load(
    "@prelude//python:toolchain.bzl",
    "PythonToolchainInfo",
)
load(":hdl.bzl", "GenVHDLInfo")


def project_as_args(value: Artifact):
    return cmd_args(value)


RDLTSet = transitive_set(args_projections={"args": project_as_args})

# RDL files can have 0 or more dependencies on other RDL files
RDLFileInfo = provider(fields={"set": provider_field(RDLTSet)})


def _rdl_file_impl(ctx):
    providers = []
    # Add the deps to a TSet for these files
    deps_tset = [x[RDLFileInfo].set for x in ctx.attrs.deps]

    # Make the deps a child of the tset containing any sources
    top_tset = ctx.actions.tset(RDLTSet, ctx.attrs.src, children=deps_tset)

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
        for out in outs:
            if out.extension in [".vhd", ".vhdl"]:
                providers.append(GenVHDLInfo(src=out))
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
        "deps": attrs.list(attrs.dep()),
        "outputs": attrs.list(attrs.string(), default=[]),
        "_rdl_gen": attrs.exec_dep(default="root//tools/site_cobble/rdl_pkg:rdl_cli"),
    },
)
