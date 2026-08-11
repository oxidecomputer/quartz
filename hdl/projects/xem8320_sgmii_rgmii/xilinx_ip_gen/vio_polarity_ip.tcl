# Virtual I/O core for live control/observation over JTAG (no rebuild needed to
# sweep polarity). probe_out drives the GT serial polarity inverts; probe_in
# mirrors link/frame status so a polarity flip's effect is visible immediately in
# the hardware manager. probe_out0 (invert_rx) powers up at 1 -- the RX P/N is
# known swapped -- and invert_tx at 0.
create_ip -name vio -vendor xilinx.com -library ip -version 3.0 -module_name vio_polarity
set_property -dict [list \
  CONFIG.C_NUM_PROBE_OUT {5} \
  CONFIG.C_PROBE_OUT0_WIDTH {1} \
  CONFIG.C_PROBE_OUT0_INIT_VAL {0x1} \
  CONFIG.C_PROBE_OUT1_WIDTH {1} \
  CONFIG.C_PROBE_OUT1_INIT_VAL {0x0} \
  CONFIG.C_PROBE_OUT2_WIDTH {5} \
  CONFIG.C_PROBE_OUT2_INIT_VAL {0x18} \
  CONFIG.C_PROBE_OUT3_WIDTH {5} \
  CONFIG.C_PROBE_OUT3_INIT_VAL {0x00} \
  CONFIG.C_PROBE_OUT4_WIDTH {5} \
  CONFIG.C_PROBE_OUT4_INIT_VAL {0x00} \
  CONFIG.C_NUM_PROBE_IN {8} \
  CONFIG.C_PROBE_IN0_WIDTH {1} \
  CONFIG.C_PROBE_IN1_WIDTH {1} \
  CONFIG.C_PROBE_IN2_WIDTH {2} \
  CONFIG.C_PROBE_IN3_WIDTH {16} \
  CONFIG.C_PROBE_IN4_WIDTH {16} \
  CONFIG.C_PROBE_IN5_WIDTH {16} \
  CONFIG.C_PROBE_IN6_WIDTH {16} \
  CONFIG.C_PROBE_IN7_WIDTH {16} \
  CONFIG.Component_Name {vio_polarity} \
] [get_ips vio_polarity]
synth_ip [get_ips vio_polarity]
