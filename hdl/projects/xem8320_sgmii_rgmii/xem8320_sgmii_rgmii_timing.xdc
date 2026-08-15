# Timing constraints for the XEM8320 SGMII<->RGMII bridge.
#
# RGMII input/output delays are derived from the DP83867IR/CR datasheet
# (SNLS484J) section 6.9 together with the delay values dp83867_init programs;
# see the RGMII timing section of hdl/projects/xem8320_eth_mgmt/README.md.

# ----- Primary clocks --------------------------------------------------------
# GT reference clock: onboard 125 MHz on MGTREFCLK0_226 (P7/P6). This is the only
# always-on clock; the free-run (refclk/2 = 62.5 MHz) and
# the IDELAYCTRL 200 MHz ref are all derived from it (GT + MMCM auto-generate
# their downstream clocks).
create_clock -name mgtrefclk -period 8.000 [get_ports mgtrefclk_p]

# RGMII receive clock from the PHY (125 MHz at 1000BASE-T).
create_clock -name rgmii_rxc -period 8.000 [get_ports rgmii_rxc]

# ----- RGMII RX input timing (RGMII-ID) --------------------------------------
# The DP83867 runs in RGMII shift mode with the delays dp83867_init programs
# (RGMIIDCTL 0x0086 = 0x71: TX 2.00 ns, RX 0.50 ns, 0.25 ns per step). The RX
# figure below MUST match RGMII_RX_DELAY in dp83867_init.vhd.
#
# Window from the DP83867IR/CR datasheet (SNLS484J, revised June 2026) section
# 6.9 "RGMII Timing", the internal-delay rows for the device as transmitter --
# which is what it is on this link, driving RXD/RXC into the FPGA:
#
#   TsetupT  Data to Clock output Setup (at Transmitter - internal delay)  1.2 ns min, 2 ns nom
#   TholdT   Clock to Data output Hold  (at Transmitter - internal delay)  1.2 ns min, 2 ns nom
#
# Those are quoted at the 2.00 ns setting, where the nominal position of each
# edge is 2 ns from the data transition -- so the guarantee sits 0.8 ns inside
# nominal. Moving the programmed delay moves the window with it; the 0.8 ns of
# PVT/jitter allowance is assumed not to move, which is the one modelling
# assumption here and what a bench sweep of the delay setting would confirm.
# The datasheet's TskewT/TskewR rows are the *non* internal-delay specs (its
# note 2) and do not apply.
#
# Vivado models input delay as pad arrival measured from the reference edge, so
# for a source-synchronous DDR input: -max = half period - Tsetup, -min = Thold.
set rgmii_half     4.000  ;# 1000BASE-T: 8 ns cycle, data on both edges
set rgmii_rx_delay 0.500  ;# PHY RX clock skew; matches RGMII_RX_DELAY
set rgmii_rx_unc   0.800  ;# datasheet guarantee, relative to nominal
set rgmii_rx_skw   0.100  ;# clock-to-data PCB skew; SZG-ENET1G pod is length-matched

set rgmii_rx_tsu [expr {$rgmii_rx_delay - $rgmii_rx_unc}]
set rgmii_rx_th  [expr {$rgmii_half - $rgmii_rx_delay - $rgmii_rx_unc}]
set rgmii_rx_max [expr {$rgmii_half - $rgmii_rx_tsu + $rgmii_rx_skw}]
set rgmii_rx_min [expr {$rgmii_rx_th - $rgmii_rx_skw}]

set rgmii_rx_ports [get_ports {rgmii_rxd[*] rgmii_rx_ctl}]
set_input_delay -clock rgmii_rxc -max $rgmii_rx_max $rgmii_rx_ports
set_input_delay -clock rgmii_rxc -min $rgmii_rx_min $rgmii_rx_ports
set_input_delay -clock rgmii_rxc -max $rgmii_rx_max -clock_fall -add_delay $rgmii_rx_ports
set_input_delay -clock rgmii_rxc -min $rgmii_rx_min -clock_fall -add_delay $rgmii_rx_ports

# These are the 1000BASE-T numbers. At 100/10 the PHY scales Tcyc to 40 ns and
# 400 ns (datasheet note 4) and duplicates the nibble on the falling edge
# (section 7.4.1.1.3), so the data is stable for a whole 40 ns period there
# while the programmed skew stays a fixed fraction of a nanosecond. Constraining
# against the 8 ns cycle is the strictly harder case and covers all three speeds.

# ----- RGMII TX output timing ------------------------------------------------
# txc is DDR-forwarded from the 125 MHz user clock, so the forwarded-clock
# generated clock has to reference the txc ODDRE1's clock pin -- a cell that
# only exists after synthesis. It, the output delays (from the datasheet's
# receiver-side internal-delay rows) and the DDR edge-pairing false paths all
# live in post_synth_timing.tcl.

# ----- Asynchronous clock-domain boundaries ----------------------------------
# The GT user clock, the system/IDELAY clock, and the RGMII rxc are independent.
# CDC between them is handled structurally (reset bridge, rate-expander FIFO).
set_clock_groups -asynchronous \
    -group [get_clocks rgmii_rxc] \
    -group [get_clocks -include_generated_clocks mgtrefclk]
