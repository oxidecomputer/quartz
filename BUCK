load(":rdl.bzl", "rdl_file", "rdl_gen")
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

rdl_file(
    name = "gimlet_regs_rdl",
    src = "gimlet_seq_fpga_regs.rdl",
    deps = [],
)

rdl_gen(
   name = "rdl_test",
   srcs = [":gimlet_regs_rdl"],
   outputs = ["test_pkg.vhd", "test.html"]
)

rdl_gen(
    name = "demo_test",
    srcs = [":demo_top"],
    outputs = ["demo_test_pkg.vhd", "demp_test.html"]
 )