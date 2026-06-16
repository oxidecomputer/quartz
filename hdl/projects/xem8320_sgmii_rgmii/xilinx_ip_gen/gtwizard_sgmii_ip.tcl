# GTY transceiver wizard for the SGMII line side.
# Endpoint: onboard SMA connectors J15-J18 = GTY quad 226, channel 2.
# Reference clock: onboard 125 MHz on MGTREFCLK0_226 (P7/P6). In the wizard,
# select the quad's REFCLK0 (not REFCLK1, which is the external SMA input) as the
# TX/RX reference-clock source. 125 MHz is exactly the SGMII line-rate/10.
#
# Target configuration (the soft SGMII PCS owns 8b10b and ordered sets, so the
# GT runs raw):
#   - 1 GTY channel, line rate 1.25 Gb/s
#   - 8B10B encode/decode BYPASSED (raw datapath)
#   - RX comma detect + align on the K28.5 comma (0011111010 / complement)
#   - RX buffer ENABLED with clock correction on the K28.5 idle sequence, so the
#     tx and rx user logic share one 125 MHz user-clock domain (the soft PCS does
#     no clock correction of its own)
#   - reset-FSM free-running clock = 100 MHz (matches idelay_pll clk_freerun)
#
# IMPORTANT / TO RECONCILE in the GT wizard before a real build:
#   * GT reference-clock frequency for Port E REFCLK0 (set CONFIG below to match
#     the board; 125 MHz assumed here).
#   * The raw user-data width the wizard allows (commonly 20 bits @ 62.5 MHz). If
#     it is not 10 bits @ 125 MHz, add a 2:1 gearbox + alignment in gt/sgmii_gt.vhd
#     so the bridge still sees one 10-bit code group per 125 MHz clock.
#   * The GTYE4_CHANNEL site for quad 226 channel 2 on this part/package (set
#     CHANNEL_ENABLE to the matching X0Yn site in the GUI; the value below is a
#     placeholder).
#   * After generating, reconcile the core's port list with
#     black_box_entities/gtwizard_sgmii.vhd and gt/sgmii_gt.vhd.

create_ip -name gtwizard_ultrascale -vendor xilinx.com -library ip \
  -version 1.7 -module_name gtwizard_sgmii

set_property -dict [list \
  CONFIG.preset {GTY-1000BASE-X} \
  CONFIG.CHANNEL_ENABLE {X0Y10} \
  CONFIG.TX_LINE_RATE {1.25} \
  CONFIG.RX_LINE_RATE {1.25} \
  CONFIG.TX_REFCLK_FREQUENCY {125} \
  CONFIG.RX_REFCLK_FREQUENCY {125} \
  CONFIG.TX_DATA_ENCODING {RAW} \
  CONFIG.RX_DATA_DECODING {RAW} \
  CONFIG.TX_USER_DATA_WIDTH {10} \
  CONFIG.RX_USER_DATA_WIDTH {10} \
  CONFIG.RX_COMMA_ALIGN_WORD {1} \
  CONFIG.RX_COMMA_M_ENABLE {true} \
  CONFIG.RX_COMMA_P_ENABLE {true} \
  CONFIG.RX_COMMA_M_VAL {1010000011} \
  CONFIG.RX_COMMA_P_VAL {0101111100} \
  CONFIG.RX_BUFFER_MODE {1} \
  CONFIG.RX_CC_ENABLE {true} \
  CONFIG.FREERUN_FREQUENCY {62.5} \
  CONFIG.Component_Name {gtwizard_sgmii} \
] [get_ips gtwizard_sgmii]

synth_ip [get_ips gtwizard_sgmii]
