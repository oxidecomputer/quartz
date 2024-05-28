set_property -dict { PACKAGE_PIN L8    IOSTANDARD LVCMOS33 } [get_ports { clk }]; # FPGA_50MHz_CLK2
set_property -dict { PACKAGE_PIN N15   IOSTANDARD LVCMOS33 } [get_ports { reset_l }]; # SP_TO_FPGA_LOGIC_RESET_L
set_property -dict { PACKAGE_PIN C22   IOSTANDARD LVCMOS33 } [get_ports { ledn }]; # FPGA_SPARE_3V3_1
