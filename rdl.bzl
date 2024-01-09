def _rdl_file_impl(ctx):
    return [DefaultInfo(default_output=ctx.attrs.src.without_associated_artifacts())]

rdl_file = rule(
    impl = _rdl_file_impl,
    attrs = {
        "src": attrs.source()
    }
)

def _rdl_gen_impl(ctx):
    outs = [ctx.actions.declare_output(out) for out in ctx.attrs.outputs]
    print(ctx.attrs.srcs)
    ctx.actions.run([
        "python3", 
        "../cobalt/tools/site_cobble/rdl_pkg/rdl_cli.py", 
        "--inputs", [x for x in ctx.attrs.srcs], 
        "--outputs", [x.as_output() for x in outs],
        ],
        category="rdl",
        
    )

    return [DefaultInfo(default_outputs=outs)]

rdl_gen = rule(
    impl = _rdl_gen_impl,
    attrs = {
        "srcs": attrs.list(attrs.source()),
        "outputs": attrs.list(attrs.string())
    }
)