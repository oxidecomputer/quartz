# Post-synthesis RGMII TX forwarded-clock timing.
#
# txc is DDR-forwarded from the 125 MHz PCS clock by an ODDR (synthesis maps it to
# OSERDESE3, clock pin CLK). This can't go in the pre-synth XDC because that
# internal cell only exists after synth; it is applied here (sourced after
# synth_design, stored in the checkpoint). The ILA in ila.tcl is what satisfies
# this flow's post-synth debug-probe hook.
#
# The DP83867 is programmed for RGMII-ID, so it applies its own 2.00 ns delay to
# the TX clock internally and samples our edge-aligned TXD with it.

set txc_oddr [get_cells -hierarchical -filter {REF_NAME == OSERDESE3 && NAME =~ *txc_oddr*}]
set txc_clk  [get_pins $txc_oddr/CLK]
create_generated_clock -name rgmii_txc -source $txc_clk -divide_by 1 [get_ports rgmii_txc]

# Window from the DP83867IR/CR datasheet (SNLS484J, revised June 2026) section
# 6.9 "RGMII Timing", the internal-delay rows for the device as receiver -- which
# is what it is for this direction, sampling TXD/TXC from the FPGA:
#
#   TsetupR  Data to Clock input Setup (at Receiver - internal delay)  1.0 ns min
#   TholdR   Clock to Data input Hold  (at Receiver - internal delay)  1.0 ns min
#
# rgmii_tx launches TXD and TXC edge-aligned from the same clock through matched
# output DDR primitives; the PHY's internal delay is what moves its capture edge
# into the eye. So this is an edge-aligned (system-synchronous) output and the
# PHY's setup/hold numbers are a +/-1 ns skew tolerance about the forwarded edge:
# -max is the allowed late skew, -min the allowed early skew, negative.
#
# The earlier placeholder used -max 2.0 / -min +1.0, which describes a
# center-aligned output -- data deliberately offset into the second half of the
# bit period. That is not what this block does, so the constraint was not just
# imprecise but the wrong shape.
set rgmii_tx_tsu 1.000  ;# TsetupR min, internal delay
set rgmii_tx_th  1.000  ;# TholdR  min, internal delay
set rgmii_tx_skw 0.100  ;# clock-to-data PCB skew; SZG-ENET1G pod is length-matched

set rgmii_tx_max [expr {$rgmii_tx_tsu + $rgmii_tx_skw}]
set rgmii_tx_min [expr {-1.0 * ($rgmii_tx_th + $rgmii_tx_skw)}]

set rgmii_tx_ports [get_ports {rgmii_txd[*] rgmii_tx_ctl}]
set_output_delay -clock rgmii_txc -max $rgmii_tx_max $rgmii_tx_ports
set_output_delay -clock rgmii_txc -min $rgmii_tx_min $rgmii_tx_ports
set_output_delay -clock rgmii_txc -max $rgmii_tx_max -clock_fall -add_delay $rgmii_tx_ports
set_output_delay -clock rgmii_txc -min $rgmii_tx_min -clock_fall -add_delay $rgmii_tx_ports

# DDR forwarded clock: txd and txc are launched by the same edge of the same
# clock, so only same-edge launch/capture pairs are real relationships. Without
# this Vivado also analyses rise-against-fall, comparing data with a txc edge
# half a period away, and reports a ~1.7 ns hold violation on an interface whose
# measured pad skew is +0.19 ns against the PHY's +/-1.0 ns tolerance.
set rgmii_tx_src [get_clocks -of_objects [get_pins $txc_oddr/CLK]]
set_false_path -setup -rise_from $rgmii_tx_src -fall_to [get_clocks rgmii_txc]
set_false_path -setup -fall_from $rgmii_tx_src -rise_to [get_clocks rgmii_txc]
set_false_path -hold  -rise_from $rgmii_tx_src -rise_to [get_clocks rgmii_txc]
set_false_path -hold  -fall_from $rgmii_tx_src -fall_to [get_clocks rgmii_txc]

set_clock_groups -asynchronous -group [get_clocks rgmii_txc] -group [get_clocks rgmii_rxc]
