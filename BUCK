load("//tools:rdl.bzl", "rdl_file")

rdl_file(
    name = "gimlet_seq_fpga_regs",
    src = "gimlet_seq_fpga_regs.rdl",
    deps = [],
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
    outputs = ["demo.vhd", "demo.bsv", "demo.json", "demp_test.html"]
)