# GTY transceiver wizard for the SGMII line side.
# Endpoint: onboard SMA connectors J15-J18 = GTY quad 226, channel 2.
# Reference clock: onboard 125 MHz on MGTREFCLK0_226 (P7/P6), the quad's REFCLK0.
#
# The soft SGMII PCS owns 8b10b and ordered sets, so the GT runs raw (8b10b
# bypassed), 20-bit @ 62.5 MHz, single channel X0Y10.
#
# RX comma detect/align (on the K28.5 comma, both disparities) + RX buffer clock
# correction are enabled so that, talking to an independent-ppm link partner, the
# GT adds/removes idle ordered sets in its elastic buffer to keep the RX data in
# the single 62.5 MHz TX user-clock domain. The clock-correction sequence is a
# comma-led pair (K28.5 + any) of length 2 = one full ordered set = 20 bits = one
# sgmii_gearbox word, so a correction does not shift the gearbox framing.
#
# Comma/CC values are in transmission (a..j) bit order and match the soft codec
# (see sgmii_gearbox / mdio unit tests). Confirm the sequence in the GUI for the
# exact idle your partner emits if you tighten it beyond "comma-led".

create_ip -name gtwizard_ultrascale -vendor xilinx.com -library ip \
  -version 1.7 -module_name gtwizard_sgmii

set_property -dict [list \
  CONFIG.CHANNEL_ENABLE {X0Y10} \
  CONFIG.RX_LINE_RATE {1.25} \
  CONFIG.RX_PLL_TYPE {QPLL0} \
  CONFIG.RX_REFCLK_FREQUENCY {125} \
  CONFIG.RX_REFCLK_SOURCE {X0Y10 clk0} \
  CONFIG.RX_USER_DATA_WIDTH {20} \
  CONFIG.TX_LINE_RATE {1.25} \
  CONFIG.TX_PLL_TYPE {QPLL0} \
  CONFIG.TX_REFCLK_FREQUENCY {125} \
  CONFIG.TX_REFCLK_SOURCE {X0Y10 clk0} \
  CONFIG.TX_USER_DATA_WIDTH {20} \
  CONFIG.RX_COMMA_M_ENABLE {true} \
  CONFIG.RX_COMMA_P_ENABLE {true} \
  CONFIG.RX_COMMA_M_VAL {1010000011} \
  CONFIG.RX_COMMA_P_VAL {0101111100} \
  CONFIG.RX_CC_NUM_SEQ {2} \
  CONFIG.RX_CC_LEN_SEQ {2} \
  CONFIG.RX_CC_PERIODICITY {5000} \
  CONFIG.RX_CC_VAL_0_0 {0101111100} \
  CONFIG.RX_CC_MASK_0_1 {true} \
  CONFIG.RX_CC_VAL_1_0 {1010000011} \
  CONFIG.RX_CC_MASK_1_1 {true} \
  CONFIG.ENABLE_OPTIONAL_PORTS {txdiffctrl_in txprecursor_in txpostcursor_in} \
  CONFIG.Component_Name {gtwizard_sgmii} \
] [get_ips gtwizard_sgmii]

synth_ip [get_ips gtwizard_sgmii]
