# Clocking wizard (MMCM) that doubles the 62.5 MHz GT user clock to the 125 MHz
# PCS clock. Locking to the GT user clock keeps the two phase-aligned so the
# gearbox can cross 62.5<->125 without an async FIFO. (A 180 deg phase shift was
# tried to widen the gearbox sampling margin, but it also shifts the RGMII
# forwarded clock and blew RGMII I/O timing -- and the crossing already closes at
# 0 deg, so that was the wrong lever; reverted.)
create_ip -name clk_wiz -vendor xilinx.com -library ip -version 6.0 -module_name usrclk_mmcm
set_property -dict [list \
  CONFIG.PRIMARY_PORT {clk_in} \
  CONFIG.PRIM_IN_FREQ {62.500} \
  CONFIG.CLK_OUT1_PORT {clk_125m} \
  CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {125.000} \
  CONFIG.NUM_OUT_CLKS {1} \
  CONFIG.RESET_TYPE {ACTIVE_HIGH} \
  CONFIG.RESET_PORT {reset} \
  CONFIG.USE_LOCKED {true} \
  CONFIG.Component_Name {usrclk_mmcm} \
] [get_ips usrclk_mmcm]
synth_ip [get_ips usrclk_mmcm]
