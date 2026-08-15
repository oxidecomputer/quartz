# Bring-up ILA for the managed media converter: link/GT status, the
# management endpoint's link-local address state, forward-path drop count and the SPI
# flash chip select / clock. Probes the mark_debug'd taps in
# xem8320_eth_mgmt_top (clk_125m domain).
#
# The debug core also satisfies this flow's post-synth hook (which requires
# a debug_probes.ltx). The ILA is clocked by clk_125m, found via the txc
# OSERDESE3 clock pin so it doesn't depend on a net name.

set ila_clk [get_nets -of [get_pins -filter {REF_PIN_NAME == CLK} \
    -of [get_cells -hierarchical -filter {REF_NAME == OSERDESE3 && NAME =~ *txc_oddr*}]]]

create_debug_core u_ila_0 ila
set_property C_DATA_DEPTH 8192 [get_debug_cores u_ila_0]
set_property C_TRIGIN_EN false [get_debug_cores u_ila_0]
set_property C_TRIGOUT_EN false [get_debug_cores u_ila_0]
set_property C_ADV_TRIGGER false [get_debug_cores u_ila_0]
set_property C_INPUT_PIPE_STAGES 0 [get_debug_cores u_ila_0]
set_property C_EN_STRG_QUAL false [get_debug_cores u_ila_0]
set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila_0]
set_property ALL_PROBE_SAME_MU_CNT 1 [get_debug_cores u_ila_0]
set_property port_width 1 [get_debug_ports u_ila_0/clk]
connect_debug_port u_ila_0/clk $ila_clk

# probe helper: index, width, net list
proc add_probe {idx width nets} {
    if {$idx != 0} { create_debug_port u_ila_0 probe }
    set_property port_width $width [get_debug_ports u_ila_0/probe$idx]
    set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe$idx]
    connect_debug_port u_ila_0/probe$idx [get_nets $nets]
}

proc vec {name width} {
    set nets {}
    for {set i 0} {$i < $width} {incr i} {
        lappend nets "${name}\[$i\]"
    }
    return $nets
}

add_probe 0 1  [list link_up]
add_probe 1 1  [list gt_ready]
add_probe 2 1  [list dbg_mgmt_valid]
add_probe 3 1  [list dbg_mac_default]
add_probe 4 32 [vec dbg_mgmt_iid 32]
add_probe 5 8  [vec dbg_fwd_drops 8]
add_probe 6 1  [list spi_cs_n]
add_probe 7 1  [list spi_sclk]
