# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.
#
# Copyright 2024 Oxide Computer Company

_VSG = select({
    "DEFAULT": "vsg",
    "config//os:windows": "vsg.exe",
})

def _vsg_toolchain_impl(ctx):
    
    run_args = cmd_args(
        ctx.attrs.exec
    )
    
    return [
        DefaultInfo(),
        RunInfo(args = run_args),
    ]

vsg_toolchain = rule(
    impl = _vsg_toolchain_impl,
    attrs = {
        "exec": attrs.string(default = _VSG),
    },
    is_toolchain_rule = True,
)