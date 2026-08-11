# Post-synthesis RGMII TX forwarded-clock timing.
#
# txc is DDR-forwarded from the 125 MHz PCS clock by an ODDR (synthesis maps it to
# OSERDESE3, clock pin CLK). This can't go in the pre-synth XDC because that
# internal cell only exists after synth; it is applied here (sourced after
# synth_design, stored in the checkpoint). The ILA in ila.tcl is what satisfies
# this flow's post-synth debug-probe hook.
#
# The DP83867 is programmed for RGMII-ID, so it adds its own TX clock delay and
# samples our edge-aligned TXD. The output-delay numbers are a representative
# DP83867 TXD setup/hold window; finalize from the datasheet (the SZG-ENET1G pod
# is length-matched, so board skew is negligible).

set txc_oddr [get_cells -hierarchical -filter {REF_NAME == OSERDESE3 && NAME =~ *txc_oddr*}]
set txc_clk  [get_pins $txc_oddr/CLK]
create_generated_clock -name rgmii_txc -source $txc_clk -divide_by 1 [get_ports rgmii_txc]

# RGMII-ID: the PHY delays its TX clock internally and samples our edge-aligned
# TXD, so the data-valid window it requires -- referred to the forwarded txc edge
# -- sits ~1-2 ns after the edge (the effective PHY delay). PLACEHOLDER VALUES:
# replace -max/-min with the DP83867 datasheet RGMII-ID TXD setup/hold window
# (pod is length-matched, so board skew is negligible). TX timing closure depends
# on using the real numbers.
set rgmii_tx_ports [get_ports {rgmii_txd[*] rgmii_tx_ctl}]
set_output_delay -clock rgmii_txc -max 2.000 $rgmii_tx_ports
set_output_delay -clock rgmii_txc -min 1.000 $rgmii_tx_ports
set_output_delay -clock rgmii_txc -max 2.000 -clock_fall -add_delay $rgmii_tx_ports
set_output_delay -clock rgmii_txc -min 1.000 -clock_fall -add_delay $rgmii_tx_ports

set_clock_groups -asynchronous -group [get_clocks rgmii_txc] -group [get_clocks rgmii_rxc]
