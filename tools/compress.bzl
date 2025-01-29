
load(
    "@prelude//python:toolchain.bzl",
    "PythonToolchainInfo",
)


def compress_bitstream(ctx, bitstream_providers):
    compressed = ctx.actions.declare_output("{}.bz2".format(ctx.attrs.name))
    bz2compress = cmd_args(ctx.attrs._bz2compress[RunInfo])
    bz2compress.add("--input", bitstream_providers[0].default_outputs[0])
    bz2compress.add("--output", compressed.as_output())
    ctx.actions.run(bz2compress, category="bitstream_compress")
    return [DefaultInfo(default_output=compressed)]