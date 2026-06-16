# Clocking wizard (MMCM) that derives the IDELAYCTRL reference (200 MHz) from the
# GT refclk-derived free-running clock (refclk / 2 via the IBUFDS_GTE4 ODIV2).
#
# NOTE: PRIM_IN_FREQ must match the free-run frequency, i.e. half the Port E GT
# reference clock (62.5 MHz assuming a 125 MHz refclk). Update if the board
# refclk differs.
create_ip -name clk_wiz -vendor xilinx.com -library ip -version 6.0 -module_name idelay_pll
set_property -dict [list \
  CONFIG.PRIMARY_PORT {clk_in} \
  CONFIG.PRIM_IN_FREQ {62.500} \
  CONFIG.CLK_OUT1_PORT {clk_200m} \
  CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {200.000} \
  CONFIG.NUM_OUT_CLKS {1} \
  CONFIG.RESET_TYPE {ACTIVE_HIGH} \
  CONFIG.RESET_PORT {reset} \
  CONFIG.USE_LOCKED {true} \
  CONFIG.Component_Name {idelay_pll} \
] [get_ips idelay_pll]
synth_ip [get_ips idelay_pll]
