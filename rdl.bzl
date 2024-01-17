# RDL files can have 0 or more dependencies on other RDL files
RDLFileInfo = provider(fields = {
    "src": provider_field(typing.Any, default = None),
    "deps":provider_field(typing.Any, default = None),
})

def _rdl_file_impl(ctx):
    
    return [
        DefaultInfo(default_output=ctx.attrs.src.without_associated_artifacts()),
        RDLFileInfo(
            src=ctx.attrs.src.without_associated_artifacts(),
            deps=ctx.attrs.deps,
        )
    ]

rdl_file = rule(
    impl = _rdl_file_impl,
    attrs = {
        "src": attrs.source(),
        "deps": attrs.list(attrs.dep()),
    }
)

def _rdl_gen_impl(ctx: AnalysisContext) -> list[Provider]:
    # need to put the deps first
    deps = []
    tops = []
    info = [x[RDLFileInfo] for x in ctx.attrs.srcs]
    # TODO: this is not as recursive as it would need to be to support
    # arbitrary dependency nesting.
    #
    # The RDL compiler needs to see dependencies before the 
    # sources that use them so we put the deps first and then the 
    # top level units
    for x in info:
        deps.extend([y[RDLFileInfo].src for y in x.deps])
        tops.append(x.src)
    ins = deps + tops
    outs = [ctx.actions.declare_output(out) for out in ctx.attrs.outputs]
    ctx.actions.run([
        "python3", 
        "./tools/site_cobble/rdl_pkg/rdl_cli.py", 
        "--inputs", ins, 
        "--outputs", [x.as_output() for x in outs],
        ],
        category="rdl",
        
    )
    return [
        DefaultInfo(default_output=outs[0])
    ]

rdl_gen = rule(
    impl = _rdl_gen_impl,
    attrs = {
        "srcs": attrs.list(attrs.dep()),
        "outputs": attrs.list(attrs.string())
    }
)