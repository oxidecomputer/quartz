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

# ----- RGMII RX input timing -------------------------------------------------
# rxc is delayed on-chip (IDELAYE3) to sample inside the data eye, so the data
# is treated as edge-aligned to the un-delayed rxc here. Adjust to the measured
# clock-to-data window of the DP83867 (or once its internal RX delay is enabled).
set rgmii_rx_ports [get_ports {rgmii_rxd[*] rgmii_rx_ctl}]
set_input_delay -clock rgmii_rxc -max 1.500 $rgmii_rx_ports
set_input_delay -clock rgmii_rxc -min -0.500 $rgmii_rx_ports
set_input_delay -clock rgmii_rxc -max 1.500 -clock_fall -add_delay $rgmii_rx_ports
set_input_delay -clock rgmii_rxc -min -0.500 -clock_fall -add_delay $rgmii_rx_ports

# ----- RGMII TX output timing ------------------------------------------------
# txc is DDR-forwarded from the 125 MHz user clock; constrain txd/tx_ctl to it.
create_generated_clock -name rgmii_txc -source [get_pins -hier -filter {NAME =~ *txc_oddr*/C}] \
    -divide_by 1 [get_ports rgmii_txc]
set rgmii_tx_ports [get_ports {rgmii_txd[*] rgmii_tx_ctl}]
set_output_delay -clock rgmii_txc -max 1.000 $rgmii_tx_ports
set_output_delay -clock rgmii_txc -min -0.800 $rgmii_tx_ports
set_output_delay -clock rgmii_txc -max 1.000 -clock_fall -add_delay $rgmii_tx_ports
set_output_delay -clock rgmii_txc -min -0.800 -clock_fall -add_delay $rgmii_tx_ports

# ----- Asynchronous clock-domain boundaries ----------------------------------
# The GT user clock, the system/IDELAY clock, and the RGMII rxc are independent.
# CDC between them is handled structurally (reset bridge, rate-expander FIFO).
set_clock_groups -asynchronous \
    -group [get_clocks rgmii_rxc] \
    -group [get_clocks -include_generated_clocks mgtrefclk]
