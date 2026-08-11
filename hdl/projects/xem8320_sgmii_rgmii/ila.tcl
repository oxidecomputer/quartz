# Basic ILA for live debug of the SGMII<->RGMII bridge (cosmo_seq-style).
# Probes the mark_debug'd taps in xem8320_sgmii_rgmii_top (clk_125m domain):
# the SGMII RX/TX code groups and the resolved link status. Add/replace probes
# from the Vivado hardware manager as needed.
#
# The debug core also satisfies this flow's post-synth hook (which requires a
# debug_probes.ltx). The ILA is clocked by clk_125m, found via the txc OSERDESE3
# clock pin so it doesn't depend on a net name.

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

add_probe 0 10 [list {rx_code[0]} {rx_code[1]} {rx_code[2]} {rx_code[3]} {rx_code[4]} \
                     {rx_code[5]} {rx_code[6]} {rx_code[7]} {rx_code[8]} {rx_code[9]}]
add_probe 1 10 [list {tx_code[0]} {tx_code[1]} {tx_code[2]} {tx_code[3]} {tx_code[4]} \
                     {tx_code[5]} {tx_code[6]} {tx_code[7]} {tx_code[8]} {tx_code[9]}]
add_probe 2 1  [list link_up]
add_probe 3 1  [list link_dup]
add_probe 4 1  [list gt_ready]
add_probe 5 2  [list {dbg_speed[0]} {dbg_speed[1]}]
add_probe 6 2  [list {dbg_rgmii_speed[0]} {dbg_rgmii_speed[1]}]
add_probe 7 1  [list dbg_rgmii_link]
add_probe 8 1  [list {dbg_init_done[1]}]
add_probe 9  1 [list dbg_gt_aligned]                       ;# GT byte-aligned
add_probe 10 1 [list dbg_gb_aligned]                       ;# gearbox locked
add_probe 11 3 [list {dbg_bufstatus[0]} {dbg_bufstatus[1]} {dbg_bufstatus[2]}]
add_probe 12 2 [list {dbg_clkcorcnt[0]} {dbg_clkcorcnt[1]}]
proc bus {name n} { set l {}; for {set i 0} {$i < $n} {incr i} { lappend l "$name\[$i\]" }; return $l }
proc busrange {name lo hi} { set l {}; for {set i $lo} {$i <= $hi} {incr i} { lappend l "$name\[$i\]" }; return $l }
add_probe 13 16 [bus dbg_refratio 16]   ;# ~1280 if refclk = 125 MHz
add_probe 14 16 [bus dbg_rxerr 16]      ;# illegal-disparity rx code groups per 65536
# raw GT word before the gearbox, as two 10-bit code groups (check these for valid 8b10b)
add_probe 15 10 [busrange dbg_gt_word 0 9]
add_probe 16 10 [busrange dbg_gt_word 10 19]
# start-of-packet counters: non-zero dbg_txsop = frames reaching the SGMII TX
# (RGMII RX path works); dbg_rxsop = the VSC is sending us frames
add_probe 17 16 [bus dbg_txsop 16]
add_probe 18 16 [bus dbg_rxsop 16]
# RGMII-RX frame localization: rx_ctl pin frame-starts, RGMII MAC recovered dv,
# and dv into the PCS TX. Whichever stays 0 during a ping brackets the loss.
add_probe 19 16 [bus dbg_rxctl_frames 16]
add_probe 20 16 [bus dbg_rgmii_frames 16]
add_probe 21 16 [bus dbg_pcs_frames 16]
# PCS TX visibility: trigger on pcs_tx_dv=1 (a frame at the PCS input) and read
# the state machine. dbg_pcs_state = (1:0)=state 0=QUIET/1=SOP/2=FRAME/3=EPD_R,
# (2)=idle_phase, (3)=frame_start.
add_probe 22 1  [list pcs_tx_dv_i]
add_probe 23 4  [busrange dbg_pcs_state 0 3]
