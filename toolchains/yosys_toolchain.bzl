# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.
#
# Copyright 202 Oxide Computer Company

_yosys = select({
    "DEFAULT": "yosys",
    "config//os:windows": "yosys.exe",
})

_icepack = select({
    "DEFAULT": "icepack",
    "config//os:windows": "icepack.exe",
})

_nextpnr_ice40 = select({
    "DEFAULT": "nextpnr-ice40",
    "config//os:windows": "nextpnr-ice40.exe",
})

_nextpnr_ecp5 = select({
    "DEFAULT": "nextpnr-ecp5",
    "config//os:windows": "nextpnr-ecp5.exe",
})

_ecppack = select({
    "DEFAULT": "ecppack",
    "config//os:windows": "ecppack.exe",
})

_icebram = select({
    "DEFAULT": "icebram",
    "config//os:windows": "icebram.exe",
})

_ecpbram = select({
    "DEFAULT": "ecpbram",
    "config//os:windows": "ecpbram.exe",
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

nextpnr_ecp5_toolchain = rule(
    impl = _generic_toolchain_impl,
    attrs = {
        "exec": attrs.string(default = _nextpnr_ecp5),
    },
    is_toolchain_rule = True,
)

ecppack_toolchain = rule(
    impl = _generic_toolchain_impl,
    attrs = {
        "exec": attrs.string(default = _ecppack),
    },
    is_toolchain_rule = True,
)

icebram_toolchain = rule(
    impl = _generic_toolchain_impl,
    attrs = {
        "exec": attrs.string(default = _icebram),
    },
    is_toolchain_rule = True,
)

ecpbram_toolchain = rule(
    impl = _generic_toolchain_impl,
    attrs = {
        "exec": attrs.string(default = _ecpbram),
    },
    is_toolchain_rule = True,
)

yosys_toolchain = rule(
    impl = _generic_toolchain_impl,
    attrs = {
        "exec": attrs.string(default = _yosys),
    },
    is_toolchain_rule = True,
)
