_VIVADO = select({
    "DEFAULT": "vivado",
    "config//os:windows": "vivado.bat",
})

def _vivado_toolchain_impl(ctx):
    
    run_args = cmd_args(
        ctx.attrs.exec
    )
    
    return [
        DefaultInfo(),
        RunInfo(args = run_args),
    ]

vivado_toolchain = rule(
    impl = _vivado_toolchain_impl,
    attrs = {
        "exec": attrs.string(default = _VIVADO),
    },
    is_toolchain_rule = True,
)