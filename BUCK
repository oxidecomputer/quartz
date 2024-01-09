load(":rdl.bzl", "rdl_file", "rdl_gen")
rdl_file(
    name = "gimlet_regs_rdl",
    src = "gimlet_seq_fpga_regs.rdl"
)

rdl_gen(
   name = "rdl_test",
   srcs = [":gimlet_regs_rdl"],
   outputs = ["test_pkg.vhd", "test.html"]
)