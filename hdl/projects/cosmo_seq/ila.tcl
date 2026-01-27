create_debug_core u_ila_0 ila
set_property C_DATA_DEPTH 8192 [get_debug_cores u_ila_0]
set_property C_TRIGIN_EN false [get_debug_cores u_ila_0]
set_property C_TRIGOUT_EN false [get_debug_cores u_ila_0]
set_property C_ADV_TRIGGER false [get_debug_cores u_ila_0]
set_property C_INPUT_PIPE_STAGES 0 [get_debug_cores u_ila_0]
set_property C_EN_STRG_QUAL false [get_debug_cores u_ila_0]
set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila_0]
set_property ALL_PROBE_SAME_MU_CNT 1 [get_debug_cores u_ila_0]
connect_debug_port u_ila_0/clk [get_nets [list board_support_inst/pll/inst/clk_125m ]]
set_property port_width 5 [get_debug_ports u_ila_0/probe0]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe0]
connect_debug_port u_ila_0/probe0 [get_nets [list {dimm_spd_proxy_top_inst/proxy_channel_top_bus0/sm_reg_reg[rx_data][6][0]} {dimm_spd_proxy_top_inst/proxy_channel_top_bus0/sm_reg_reg[rx_data][6][1]} {dimm_spd_proxy_top_inst/proxy_channel_top_bus0/sm_reg_reg[rx_data][6][2]} {dimm_spd_proxy_top_inst/proxy_channel_top_bus0/sm_reg_reg[rx_data][6][3]} {dimm_spd_proxy_top_inst/proxy_channel_top_bus0/sm_reg_reg[rx_data][6][4]} ]]
create_debug_port u_ila_0 probe
set_property port_width 2 [get_debug_ports u_ila_0/probe1]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe1]
connect_debug_port u_ila_0/probe1 [get_nets [list {dimm_spd_proxy_top_inst/proxy_channel_top_bus0/sm_reg_reg[cmd][op][1][0]} {dimm_spd_proxy_top_inst/proxy_channel_top_bus0/sm_reg_reg[cmd][op][1][1]} ]]
create_debug_port u_ila_0 probe
set_property port_width 2 [get_debug_ports u_ila_0/probe2]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe2]
connect_debug_port u_ila_0/probe2 [get_nets [list {dimm_spd_proxy_top_inst/proxy_channel_top_bus0/sm_reg_reg[cmd][len][7][0]} {dimm_spd_proxy_top_inst/proxy_channel_top_bus0/sm_reg_reg[cmd][len][7][1]} ]]
create_debug_port u_ila_0 probe
set_property port_width 6 [get_debug_ports u_ila_0/probe3]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe3]
connect_debug_port u_ila_0/probe3 [get_nets [list {dimm_spd_proxy_top_inst/proxy_channel_top_bus0/sm_reg_reg[cmd][len][6][0]} {dimm_spd_proxy_top_inst/proxy_channel_top_bus0/sm_reg_reg[cmd][len][6][1]} {dimm_spd_proxy_top_inst/proxy_channel_top_bus0/sm_reg_reg[cmd][len][6][2]} {dimm_spd_proxy_top_inst/proxy_channel_top_bus0/sm_reg_reg[cmd][len][6][3]} {dimm_spd_proxy_top_inst/proxy_channel_top_bus0/sm_reg_reg[cmd][len][6][4]} {dimm_spd_proxy_top_inst/proxy_channel_top_bus0/sm_reg_reg[cmd][len][6][5]} ]]
create_debug_port u_ila_0 probe
set_property port_width 5 [get_debug_ports u_ila_0/probe4]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe4]
connect_debug_port u_ila_0/probe4 [get_nets [list {dimm_spd_proxy_top_inst/proxy_channel_top_bus0/sm_reg_reg[cmd][addr][6][0]} {dimm_spd_proxy_top_inst/proxy_channel_top_bus0/sm_reg_reg[cmd][addr][6][1]} {dimm_spd_proxy_top_inst/proxy_channel_top_bus0/sm_reg_reg[cmd][addr][6][2]} {dimm_spd_proxy_top_inst/proxy_channel_top_bus0/sm_reg_reg[cmd][addr][6][3]} {dimm_spd_proxy_top_inst/proxy_channel_top_bus0/sm_reg_reg[cmd][addr][6][4]} ]]
create_debug_port u_ila_0 probe
set_property port_width 4 [get_debug_ports u_ila_0/probe5]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe5]
connect_debug_port u_ila_0/probe5 [get_nets [list {dimm_spd_proxy_top_inst/proxy_channel_top_bus0/spd_i2c_proxy_inst/i2c_ctrl_txn_layer_inst/i2c_ctrl_link_layer_inst/sm_reg_reg[state]__0[0]} {dimm_spd_proxy_top_inst/proxy_channel_top_bus0/spd_i2c_proxy_inst/i2c_ctrl_txn_layer_inst/i2c_ctrl_link_layer_inst/sm_reg_reg[state]__0[1]} {dimm_spd_proxy_top_inst/proxy_channel_top_bus0/spd_i2c_proxy_inst/i2c_ctrl_txn_layer_inst/i2c_ctrl_link_layer_inst/sm_reg_reg[state]__0[2]} {dimm_spd_proxy_top_inst/proxy_channel_top_bus0/spd_i2c_proxy_inst/i2c_ctrl_txn_layer_inst/i2c_ctrl_link_layer_inst/sm_reg_reg[state]__0[3]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe6]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe6]
connect_debug_port u_ila_0/probe6 [get_nets [list {dimm_spd_proxy_top_inst/proxy_channel_top_bus0/arbiter_inst/FSM_sequential_sm_reg[state][0]_i_12[0]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe7]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe7]
connect_debug_port u_ila_0/probe7 [get_nets [list {dimm_spd_proxy_top_inst/proxy_channel_top_bus0/arbiter_inst/requests[0]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe8]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe8]
connect_debug_port u_ila_0/probe8 [get_nets [list {dimm_spd_proxy_top_inst/proxy_channel_top_bus0/arbiter_inst/Q[0]} ]]
create_debug_port u_ila_0 probe
set_property port_width 4 [get_debug_ports u_ila_0/probe9]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe9]
connect_debug_port u_ila_0/probe9 [get_nets [list {dimm_spd_proxy_top_inst/proxy_channel_top_bus0/spd_i2c_proxy_inst/i2c_ctrl_txn_layer_inst/sm_reg_reg[state]__0[0]} {dimm_spd_proxy_top_inst/proxy_channel_top_bus0/spd_i2c_proxy_inst/i2c_ctrl_txn_layer_inst/sm_reg_reg[state]__0[1]} {dimm_spd_proxy_top_inst/proxy_channel_top_bus0/spd_i2c_proxy_inst/i2c_ctrl_txn_layer_inst/sm_reg_reg[state]__0[2]} {dimm_spd_proxy_top_inst/proxy_channel_top_bus0/spd_i2c_proxy_inst/i2c_ctrl_txn_layer_inst/sm_reg_reg[state]__0[3]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe10]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe10]
connect_debug_port u_ila_0/probe10 [get_nets [list dimm_spd_proxy_top_inst/proxy_channel_top_bus0/spd_i2c_proxy_inst/i2c_ctrl_txn_layer_inst/cpu_busy ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe11]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe11]
connect_debug_port u_ila_0/probe11 [get_nets [list dimm_spd_proxy_top_inst/proxy_channel_top_bus0/spd_i2c_proxy_inst/i2c_ctrl_txn_layer_inst/cpu_busy_reg ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe12]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe12]
connect_debug_port u_ila_0/probe12 [get_nets [list dimm_spd_proxy_top_inst/proxy_channel_top_bus0/spd_i2c_proxy_inst/i2c_ctrl_txn_layer_inst/cpu_has_sda ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe13]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe13]
connect_debug_port u_ila_0/probe13 [get_nets [list dimm_spd_proxy_top_inst/proxy_channel_top_bus0/spd_i2c_proxy_inst/i2c_ctrl_txn_layer_inst/cpu_scl_filt ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe14]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe14]
connect_debug_port u_ila_0/probe14 [get_nets [list {dimm_spd_proxy_top_inst/proxy_channel_top_bus0/cpu_scl_if[i]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe15]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe15]
connect_debug_port u_ila_0/probe15 [get_nets [list dimm_spd_proxy_top_inst/proxy_channel_top_bus0/spd_i2c_proxy_inst/i2c_ctrl_txn_layer_inst/cpu_sda_filt ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe16]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe16]
connect_debug_port u_ila_0/probe16 [get_nets [list {dimm_spd_proxy_top_inst/proxy_channel_top_bus0/cpu_sda_if[i]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe17]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe17]
connect_debug_port u_ila_0/probe17 [get_nets [list {dimm_spd_proxy_top_inst/proxy_channel_top_bus0/spd_i2c_proxy_inst/i2c_ctrl_txn_layer_inst/FSM_onehot_r_reg[state][3]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe18]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe18]
connect_debug_port u_ila_0/probe18 [get_nets [list {dimm_spd_proxy_top_inst/proxy_channel_top_bus0/spd_i2c_proxy_inst/i2c_ctrl_txn_layer_inst/FSM_sequential_sm_reg_reg[state][0]_0} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe19]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe19]
connect_debug_port u_ila_0/probe19 [get_nets [list {dimm_spd_proxy_top_inst/proxy_channel_top_bus0/spd_i2c_proxy_inst/i2c_ctrl_txn_layer_inst/FSM_sequential_sm_reg_reg[state][1]_0} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe20]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe20]
connect_debug_port u_ila_0/probe20 [get_nets [list {dimm_spd_proxy_top_inst/proxy_channel_top_bus0/spd_i2c_proxy_inst/i2c_ctrl_txn_layer_inst/FSM_sequential_sm_reg_reg[state][2]_0} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe21]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe21]
connect_debug_port u_ila_0/probe21 [get_nets [list {dimm_spd_proxy_top_inst/proxy_channel_top_bus0/spd_i2c_proxy_inst/i2c_ctrl_txn_layer_inst/i2c_ctrlr_status[busy]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe22]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe22]
connect_debug_port u_ila_0/probe22 [get_nets [list {dimm_spd_proxy_top_inst/proxy_channel_top_bus0/i2c_ctrlr_status[busy]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe23]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe23]
connect_debug_port u_ila_0/probe23 [get_nets [list dimm_spd_proxy_top_inst/proxy_channel_top_bus0/i3c_fpga1_to_dimm_abcdef_sda_TRI ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe24]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe24]
connect_debug_port u_ila_0/probe24 [get_nets [list dimm_spd_proxy_top_inst/proxy_channel_top_bus0/i3c_sp5_to_fpga1_abcdef_sda_TRI ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe25]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe25]
connect_debug_port u_ila_0/probe25 [get_nets [list dimm_spd_proxy_top_inst/proxy_channel_top_bus0/spd_i2c_proxy_inst/i2c_ctrl_txn_layer_inst/need_start ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe26]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe26]
connect_debug_port u_ila_0/probe26 [get_nets [list {dimm_spd_proxy_top_inst/proxy_channel_top_bus0/arbiter_inst/requests_last_reg[0]_0} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe27]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe27]
connect_debug_port u_ila_0/probe27 [get_nets [list {dimm_spd_proxy_top_inst/proxy_channel_top_bus0/arbiter_inst/requests_last_reg[0]_1} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe28]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe28]
connect_debug_port u_ila_0/probe28 [get_nets [list dimm_spd_proxy_top_inst/i3c_fpga1_to_dimm_abcdef_scl_OBUF ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe29]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe29]
connect_debug_port u_ila_0/probe29 [get_nets [list dimm_spd_proxy_top_inst/i3c_fpga1_to_dimm_abcdef_sda_OBUF ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe30]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe30]
connect_debug_port u_ila_0/probe30 [get_nets [list {dimm_spd_proxy_top_inst/proxy_channel_top_bus0/dimm_scl_if[i]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe31]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe31]
connect_debug_port u_ila_0/probe31 [get_nets [list dimm_spd_proxy_top_inst/proxy_channel_top_bus0/i2c_command_sm_valid ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe32]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe32]
connect_debug_port u_ila_0/probe32 [get_nets [list dimm_spd_proxy_top_inst/proxy_channel_top_bus0/raw_sda ]]