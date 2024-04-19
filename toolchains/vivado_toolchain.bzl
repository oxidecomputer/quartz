# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.
#
# Copyright 2024 Oxide Computer Company

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