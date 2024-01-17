load(":rdl.bzl", "rdl_file", "rdl_gen")

rdl_file(
    name = "gimlet_seq_fpga_regs",
    src = "gimlet_seq_fpga_regs.rdl",
    deps = [],
)

rdl_gen(
    name = "gimlet_regs",
    srcs = [":gimlet_seq_fpga_regs"],
    outputs = ["gimlet.vhd", "gimlet.html", "gimlet.json", "gimlet.bsv"]
)

rdl_file(
    name = "demo_rdl",
    src = "demo.rdl",
    deps = [],
)
rdl_file(
    name = "demo_top",
    src = "demo_top.rdl",
    deps = [":demo_rdl"],
)

rdl_gen(
    name = "demo_test",
    srcs = [":demo_top"],
    outputs = ["demo.vhd", "demo.bsv", "demo.json", "demp_test.html"]
 )