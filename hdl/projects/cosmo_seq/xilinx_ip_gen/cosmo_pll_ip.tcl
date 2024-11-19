# Generate the PLL (copied from tcl console using the IP generator)
create_ip -name clk_wiz -vendor xilinx.com -library ip -version 6.0 -module_name cosmo_pll
set_property -dict [list \
  CONFIG.CLKIN1_JITTER_PS {200.0} \
  CONFIG.CLKOUT1_JITTER {154.207} \
  CONFIG.CLKOUT1_PHASE_ERROR {164.985} \
  CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {125.000} \
  CONFIG.CLKOUT2_JITTER {142.107} \
  CONFIG.CLKOUT2_PHASE_ERROR {164.985} \
  CONFIG.CLKOUT2_REQUESTED_OUT_FREQ {200} \
  CONFIG.CLKOUT2_USED {true} \
  CONFIG.CLK_OUT1_PORT {clk_125m} \
  CONFIG.CLK_OUT2_PORT {clk_200m} \
  CONFIG.Component_Name {cosmo_pll} \
  CONFIG.MMCM_CLKFBOUT_MULT_F {20.000} \
  CONFIG.MMCM_CLKIN1_PERIOD {20.000} \
  CONFIG.MMCM_CLKIN2_PERIOD {10.0} \
  CONFIG.MMCM_CLKOUT0_DIVIDE_F {8.000} \
  CONFIG.MMCM_CLKOUT1_DIVIDE {5} \
  CONFIG.NUM_OUT_CLKS {2} \
  CONFIG.PRIMARY_PORT {clk_50m} \
  CONFIG.PRIM_IN_FREQ {50} \
] [get_ips cosmo_pll]
synth_ip [get_ips cosmo_pll]