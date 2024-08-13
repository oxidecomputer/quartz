# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.
#
# Copyright 2024 Oxide Computer Company

_icepack = select({
    "DEFAULT": "icepack",
    "config//os:windows": "icepack.exe",
})

_nextpnr_ice40 = select({
    "DEFAULT": "nextpnr-ice40",
    "config//os:windows": "nextpnr-ice40.exe",
})


def _generic_toolchain_impl(ctx):
    
    run_args = cmd_args(
        ctx.attrs.exec
    )
    
    return [
        DefaultInfo(),
        RunInfo(args = run_args),
    ]

icepack_toolchain = rule(
    impl = _generic_toolchain_impl,
    attrs = {
        "exec": attrs.string(default = _icepack),
    },
    is_toolchain_rule = True,
)

nextpnr_ice40_toolchain = rule(
    impl = _generic_toolchain_impl,
    attrs = {
        "exec": attrs.string(default = _nextpnr_ice40),
    },
    is_toolchain_rule = True,
)