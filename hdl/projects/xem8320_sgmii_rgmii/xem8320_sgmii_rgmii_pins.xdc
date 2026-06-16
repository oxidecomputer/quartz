# Pin constraints for the XEM8320 SGMII<->RGMII bridge.
#
# Package pins are the intersection of two authoritative sources:
#   - XEM8320 pin list   : SYZYGY net name -> FPGA package pin
#                          (https://pins.opalkelly.com/pin_list/XEM8320)
#   - SZG-ENET1G pinout  : DP83867 RGMII signal -> SYZYGY connector signal
#                          (https://docs.opalkelly.com/syzygy-peripherals/szg-enet1g/)
#
#   RGMII (SZG-ENET1G) : SYZYGY Port A (J5), HP bank 66, 1.8 V
#   SGMII serial       : onboard SMA connectors J15-J18, GTY quad 226 channel 2
#   SGMII refclk       : onboard 125 MHz, MGTREFCLK0_226 (P7/P6)
#                        (MGTREFCLK1_226 M7/M6 is the external SMA refclk J19/J20)
#
# The XEM8320 has no fabric oscillator and no dedicated LEDs; all clocking is
# derived from the GT reference clock and status is brought out on Port A pins
# left unused by the pod (probe on a logic analyzer / breakout).
#
# RGMII signal -> SYZYGY signal -> FPGA pin:
#   RX_CLK  P2C_CLKp J23 | GTX_CLK C2P_CLKp H26
#   RX_CTL  D0P      L18 | TX_CTL  D0N      K18
#   RXD0    D4N      J20 | TXD0    D3P      L24
#   RXD1    D4P      J19 | TXD1    D3N      L25
#   RXD2    D2N      M21 | TXD2    D5P      K25
#   RXD3    D2P      M20 | TXD3    D5N      K26
#   RESET_N D1P      M25 | (INT_N D1N M26, MDC D7P K22, MDIO D7N K23: unused)

# ===== SGMII serial + GT reference clock (SMA J15-J18, GTY quad 226 ch 2) =====
# GT pins are located by the transceiver channel; no IOSTANDARD.
set_property PACKAGE_PIN H2 [get_ports gt_rxp]        ;# J15 MGTYRXP2_226
set_property PACKAGE_PIN H1 [get_ports gt_rxn]        ;# J16 MGTYRXN2_226
set_property PACKAGE_PIN J5 [get_ports gt_txp]        ;# J17 MGTYTXP2_226
set_property PACKAGE_PIN J4 [get_ports gt_txn]        ;# J18 MGTYTXN2_226
set_property PACKAGE_PIN P7 [get_ports mgtrefclk_p]   ;# MGTREFCLK0P_226 (onboard 125 MHz)
set_property PACKAGE_PIN P6 [get_ports mgtrefclk_n]   ;# MGTREFCLK0N_226 (onboard 125 MHz)

# ===== RGMII to SZG-ENET1G (Port A, HP bank 66, 1.8 V) ========================
# clocks on the SYZYGY clock-capable pins
set_property PACKAGE_PIN J23 [get_ports rgmii_rxc]       ;# RX_CLK  / P2C_CLKp (GC)
set_property PACKAGE_PIN H26 [get_ports rgmii_txc]       ;# GTX_CLK / C2P_CLKp

# receive data / control
set_property PACKAGE_PIN L18 [get_ports rgmii_rx_ctl]    ;# RX_CTL / D0P
set_property PACKAGE_PIN J20 [get_ports {rgmii_rxd[0]}]  ;# RXD0   / D4N
set_property PACKAGE_PIN J19 [get_ports {rgmii_rxd[1]}]  ;# RXD1   / D4P
set_property PACKAGE_PIN M21 [get_ports {rgmii_rxd[2]}]  ;# RXD2   / D2N
set_property PACKAGE_PIN M20 [get_ports {rgmii_rxd[3]}]  ;# RXD3   / D2P

# transmit data / control
set_property PACKAGE_PIN K18 [get_ports rgmii_tx_ctl]    ;# TX_CTL / D0N
set_property PACKAGE_PIN L24 [get_ports {rgmii_txd[0]}]  ;# TXD0   / D3P
set_property PACKAGE_PIN L25 [get_ports {rgmii_txd[1]}]  ;# TXD1   / D3N
set_property PACKAGE_PIN K25 [get_ports {rgmii_txd[2]}]  ;# TXD2   / D5P
set_property PACKAGE_PIN K26 [get_ports {rgmii_txd[3]}]  ;# TXD3   / D5N

# PHY hardware reset (active-low)
set_property PACKAGE_PIN M25 [get_ports phy_resetn]      ;# RESET_N / D1P

set_property IOSTANDARD LVCMOS18 [get_ports {rgmii_txc rgmii_tx_ctl rgmii_txd[*]}]
set_property SLEW FAST            [get_ports {rgmii_txc rgmii_tx_ctl rgmii_txd[*]}]
set_property IOSTANDARD LVCMOS18 [get_ports {rgmii_rxc rgmii_rx_ctl rgmii_rxd[*]}]
set_property IOSTANDARD LVCMOS18 [get_ports phy_resetn]

# ===== Status (Port A pins unused by the SZG-ENET1G, active-high) =============
# D6 pair + two upper single-ended STD pins; the pod uses only D0-D5, D7, D1 and
# the clock pairs, so these are not driven by the peripheral.
set_property PACKAGE_PIN L22 [get_ports {status[0]}]     ;# D6P  / SZG_PORTA_S12
set_property PACKAGE_PIN L23 [get_ports {status[1]}]     ;# D6N  / SZG_PORTA_S14
set_property PACKAGE_PIN H24 [get_ports {status[2]}]     ;# SZG_PORTA_S16
set_property PACKAGE_PIN J21 [get_ports {status[3]}]     ;# SZG_PORTA_S18
set_property IOSTANDARD LVCMOS18 [get_ports {status[*]}]
