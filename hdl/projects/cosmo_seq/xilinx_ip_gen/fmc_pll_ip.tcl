# MMCM on the SP's FMC clock, in phase-alignment (deskew) mode: the feedback
# path through a BUFG zeroes out the clock insertion delay so the FMC-domain
# flops launch and capture aligned to the clock at the pin (plus the phase
# shift below). This is what closes the single-cycle NWAIT and data-out paths
# at 10 ns; a plain IBUF+BUFG eats 3.5-6.5 ns of insertion delay across PVT
# and cannot.
#
# VCO choice (M=12, D=1, O=12): VCO = 12 x f_in, so 600 MHz at a 50 MHz input
# and 1200 MHz at 100 MHz -- exactly the -1 speed grade MMCM limits per
# DS189, and the only M that spans both. One bitstream therefore locks at
# either SP CLKDIV setting, which is what lets this bitstream ship before the
# hubris CLKDIV flip. If a Vivado DRC ever rejects the edge-of-range VCO,
# drop the dual-frequency property and coordinate the rollout as a single
# archive bump instead (the hubris archive carries the bitstream, so the pair
# still moves atomically).
#
# Two output phases:
#  - clk_fmc (+45 deg = +1.25 ns at 10 ns) clocks the FSM and the output
#    flops. Its phase is hold-limited on the NWAIT/data pins (going earlier
#    breaks output hold), so it cannot be pushed later for input margin.
#  - clk_fmc_capture (+135 deg = +3.75 ns) clocks only the dedicated input
#    capture registers. The late phase is what gives the input paths setup
#    margin against STA's uncredited clock-network corner spread; input hold
#    still has a half period of real SP hold behind it. The FSM consumes the
#    captured values a cycle later, which the NWAIT pacing absorbs.
# Sweep either phase in the lab under the fmc_sweep soak to confirm real
# margin exceeds STA margin; the grid is 45/CLKOUT_DIVIDE = 3.75 deg per
# MMCM tap, so +/-5 taps = +/-18.75 deg = ~0.52 ns. Phases are fractions of
# the period, so every hold-side margin only grows at 50 MHz operation.
#
# OVERRIDE_MMCM is required: without it clk_wiz silently recalculates M
# (it picked M=11, whose 550 MHz VCO at a 50 MHz input cannot lock, killing
# the dual-frequency property).
create_ip -name clk_wiz -vendor xilinx.com -library ip -version 6.0 -module_name fmc_pll
set_property -dict [list \
  CONFIG.Component_Name {fmc_pll} \
  CONFIG.PRIM_IN_FREQ {100.000} \
  CONFIG.PRIMARY_PORT {clk_fmc_in} \
  CONFIG.CLK_OUT1_PORT {clk_fmc} \
  CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {100.000} \
  CONFIG.CLKOUT1_REQUESTED_PHASE {45.000} \
  CONFIG.CLKOUT2_USED {true} \
  CONFIG.CLK_OUT2_PORT {clk_fmc_capture} \
  CONFIG.CLKOUT2_REQUESTED_OUT_FREQ {100.000} \
  CONFIG.CLKOUT2_REQUESTED_PHASE {135.000} \
  CONFIG.USE_PHASE_ALIGNMENT {true} \
  CONFIG.JITTER_SEL {Min_O_Jitter} \
  CONFIG.OVERRIDE_MMCM {true} \
  CONFIG.MMCM_DIVCLK_DIVIDE {1} \
  CONFIG.MMCM_CLKFBOUT_MULT_F {12.000} \
  CONFIG.MMCM_CLKIN1_PERIOD {10.000} \
  CONFIG.MMCM_CLKOUT0_DIVIDE_F {12.000} \
  CONFIG.MMCM_CLKOUT0_PHASE {45.000} \
  CONFIG.MMCM_CLKOUT1_DIVIDE {12} \
  CONFIG.MMCM_CLKOUT1_PHASE {135.000} \
  CONFIG.NUM_OUT_CLKS {2} \
] [get_ips fmc_pll]
synth_ip [get_ips fmc_pll]
