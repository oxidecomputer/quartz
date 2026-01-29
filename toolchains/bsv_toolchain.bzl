# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.
#
# Copyright 2024 Oxide Computer Company

# BSV (Bluespec SystemVerilog) toolchain definition

def _bsv_toolchain_impl(ctx):
    """BSV toolchain provider implementation"""

    # Use attributes directly (config should be read at rule invocation)
    bsc_path = ctx.attrs.bsc

    # Create RunInfo for bsc compiler
    # Note: libdir is stored as an attribute and accessed via ctx.attrs._toolchain.libdir
    bsc_run = RunInfo(args = cmd_args(bsc_path))

    return [
        DefaultInfo(),
        bsc_run,
    ]

bsv_toolchain = rule(
    impl = _bsv_toolchain_impl,
    attrs = {
        "bsc": attrs.string(
            default = "bsc",
            doc = "Path to bsc compiler executable",
        ),
        "libdir": attrs.string(
            default = "/usr/local/lib/bluespec",
            doc = "Path to Bluespec standard library",
        ),
    },
    is_toolchain_rule = True,
)
