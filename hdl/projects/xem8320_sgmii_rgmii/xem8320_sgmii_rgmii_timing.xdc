# Timing constraints for the XEM8320 SGMII<->RGMII bridge.
#
# Trace-delay numbers below are representative starting points; tune the RGMII
# input/output delays against the SZG-ENET1G + board routing during bring-up.

# ----- Primary clocks --------------------------------------------------------
# GT reference clock: onboard 125 MHz on MGTREFCLK0_226 (P7/P6). This is the only
# always-on clock; the free-run (refclk/2 = 62.5 MHz) and
# the IDELAYCTRL 200 MHz ref are all derived from it (GT + MMCM auto-generate
# their downstream clocks).
create_clock -name mgtrefclk -period 8.000 [get_ports mgtrefclk_p]

# RGMII receive clock from the PHY (125 MHz at 1000BASE-T).
create_clock -name rgmii_rxc -period 8.000 [get_ports rgmii_rxc]

# ----- RGMII RX input timing (RGMII-ID / center-aligned) ---------------------
# The DP83867 is programmed for RGMII internal delay at startup, so it centers
# RXC in the RXD eye: data transitions land ~2 ns (half the 4 ns DDR bit period)
# from each RXC edge, with a valid window around the edge. These numbers are a
# representative DP83867-ID output window; finalize from the datasheet's RGMII
# internal-delay data-to-clock spec (the SZG-ENET1G pod is length-matched, so the
# board skew term is negligible).
set rgmii_rx_ports [get_ports {rgmii_rxd[*] rgmii_rx_ctl}]
set_input_delay -clock rgmii_rxc -max 2.600 $rgmii_rx_ports
set_input_delay -clock rgmii_rxc -min 1.400 $rgmii_rx_ports
set_input_delay -clock rgmii_rxc -max 2.600 -clock_fall -add_delay $rgmii_rx_ports
set_input_delay -clock rgmii_rxc -min 1.400 -clock_fall -add_delay $rgmii_rx_ports

# ----- RGMII TX output timing ------------------------------------------------
# txc is DDR-forwarded from the 125 MHz user clock. The forwarded-clock generated
# clock must reference the txc ODDRE1's clock pin, which only exists after
# synthesis -- this project's flow reads XDC pre-synth, so define it in a
# post-synth constraint (a post_synth_tcl_files script) rather than here, e.g.:
#   set txc_oddr [get_cells -hier -filter {REF_NAME==ODDRE1 && NAME=~*txc_oddr*}]
#   create_generated_clock -name rgmii_txc -source [get_pins $txc_oddr/C] \
#       -divide_by 1 [get_ports rgmii_txc]
#   set_output_delay -clock rgmii_txc -max 1.000  [get_ports {rgmii_txd[*] rgmii_tx_ctl}]
#   set_output_delay -clock rgmii_txc -min -0.800 [get_ports {rgmii_txd[*] rgmii_tx_ctl}] ...
# TX output timing is a bring-up item (see README); left unconstrained here.

# ----- Asynchronous clock-domain boundaries ----------------------------------
# The GT user clock, the system/IDELAY clock, and the RGMII rxc are independent.
# CDC between them is handled structurally (reset bridge, rate-expander FIFO).
set_clock_groups -asynchronous \
    -group [get_clocks rgmii_rxc] \
    -group [get_clocks -include_generated_clocks mgtrefclk]
