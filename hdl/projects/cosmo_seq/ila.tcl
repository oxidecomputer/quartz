create_debug_core u_ila_0 ila
set_property C_DATA_DEPTH 1024 [get_debug_cores u_ila_0]
set_property C_TRIGIN_EN false [get_debug_cores u_ila_0]
set_property C_TRIGOUT_EN false [get_debug_cores u_ila_0]
set_property C_ADV_TRIGGER false [get_debug_cores u_ila_0]
set_property C_INPUT_PIPE_STAGES 0 [get_debug_cores u_ila_0]
set_property C_EN_STRG_QUAL false [get_debug_cores u_ila_0]
set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila_0]
set_property ALL_PROBE_SAME_MU_CNT 1 [get_debug_cores u_ila_0]
create_debug_core u_ila_1 ila
set_property C_DATA_DEPTH 1024 [get_debug_cores u_ila_1]
set_property C_TRIGIN_EN false [get_debug_cores u_ila_1]
set_property C_TRIGOUT_EN false [get_debug_cores u_ila_1]
set_property C_ADV_TRIGGER false [get_debug_cores u_ila_1]
set_property C_INPUT_PIPE_STAGES 0 [get_debug_cores u_ila_1]
set_property C_EN_STRG_QUAL false [get_debug_cores u_ila_1]
set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila_1]
set_property ALL_PROBE_SAME_MU_CNT 1 [get_debug_cores u_ila_1]
connect_debug_port u_ila_0/clk [get_nets [list board_support_inst/pll/inst/clk_125m ]]
connect_debug_port u_ila_1/clk [get_nets [list board_support_inst/pll/inst/clk_200m ]]
set_property port_width 5 [get_debug_ports u_ila_0/probe0]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe0]
connect_debug_port u_ila_0/probe0 [get_nets [list {espi_spinor_ss/espi_target_top_inst/link_to_txn_bridge_inst/cmd_rusedwds[0]} {espi_spinor_ss/espi_target_top_inst/link_to_txn_bridge_inst/cmd_rusedwds[1]} {espi_spinor_ss/espi_target_top_inst/link_to_txn_bridge_inst/cmd_rusedwds[2]} {espi_spinor_ss/espi_target_top_inst/link_to_txn_bridge_inst/cmd_rusedwds[3]} {espi_spinor_ss/espi_target_top_inst/link_to_txn_bridge_inst/cmd_rusedwds[4]} ]]
create_debug_port u_ila_0 probe
set_property port_width 9 [get_debug_ports u_ila_0/probe1]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe1]
connect_debug_port u_ila_0/probe1 [get_nets [list {espi_spinor_ss/espi_target_top_inst/link_to_txn_bridge_inst/resp_wusedwds[0]} {espi_spinor_ss/espi_target_top_inst/link_to_txn_bridge_inst/resp_wusedwds[1]} {espi_spinor_ss/espi_target_top_inst/link_to_txn_bridge_inst/resp_wusedwds[2]} {espi_spinor_ss/espi_target_top_inst/link_to_txn_bridge_inst/resp_wusedwds[3]} {espi_spinor_ss/espi_target_top_inst/link_to_txn_bridge_inst/resp_wusedwds[4]} {espi_spinor_ss/espi_target_top_inst/link_to_txn_bridge_inst/resp_wusedwds[5]} {espi_spinor_ss/espi_target_top_inst/link_to_txn_bridge_inst/resp_wusedwds[6]} {espi_spinor_ss/espi_target_top_inst/link_to_txn_bridge_inst/resp_wusedwds[7]} {espi_spinor_ss/espi_target_top_inst/link_to_txn_bridge_inst/resp_wusedwds[8]} ]]
create_debug_port u_ila_0 probe
set_property port_width 16 [get_debug_ports u_ila_0/probe2]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe2]
connect_debug_port u_ila_0/probe2 [get_nets [list {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[cfg_addr][0]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[cfg_addr][1]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[cfg_addr][2]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[cfg_addr][3]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[cfg_addr][4]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[cfg_addr][5]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[cfg_addr][6]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[cfg_addr][7]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[cfg_addr][8]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[cfg_addr][9]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[cfg_addr][10]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[cfg_addr][11]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[cfg_addr][12]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[cfg_addr][13]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[cfg_addr][14]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[cfg_addr][15]} ]]
create_debug_port u_ila_0 probe
set_property port_width 32 [get_debug_ports u_ila_0/probe3]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe3]
connect_debug_port u_ila_0/probe3 [get_nets [list {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[cfg_data][0]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[cfg_data][1]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[cfg_data][2]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[cfg_data][3]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[cfg_data][4]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[cfg_data][5]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[cfg_data][6]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[cfg_data][7]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[cfg_data][8]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[cfg_data][9]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[cfg_data][10]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[cfg_data][11]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[cfg_data][12]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[cfg_data][13]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[cfg_data][14]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[cfg_data][15]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[cfg_data][16]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[cfg_data][17]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[cfg_data][18]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[cfg_data][19]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[cfg_data][20]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[cfg_data][21]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[cfg_data][22]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[cfg_data][23]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[cfg_data][24]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[cfg_data][25]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[cfg_data][26]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[cfg_data][27]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[cfg_data][28]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[cfg_data][29]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[cfg_data][30]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[cfg_data][31]} ]]
create_debug_port u_ila_0 probe
set_property port_width 32 [get_debug_ports u_ila_0/probe4]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe4]
connect_debug_port u_ila_0/probe4 [get_nets [list {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[ch_addr][0]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[ch_addr][1]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[ch_addr][2]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[ch_addr][3]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[ch_addr][4]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[ch_addr][5]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[ch_addr][6]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[ch_addr][7]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[ch_addr][8]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[ch_addr][9]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[ch_addr][10]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[ch_addr][11]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[ch_addr][12]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[ch_addr][13]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[ch_addr][14]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[ch_addr][15]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[ch_addr][16]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[ch_addr][17]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[ch_addr][18]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[ch_addr][19]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[ch_addr][20]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[ch_addr][21]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[ch_addr][22]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[ch_addr][23]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[ch_addr][24]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[ch_addr][25]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[ch_addr][26]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[ch_addr][27]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[ch_addr][28]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[ch_addr][29]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[ch_addr][30]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[ch_addr][31]} ]]
create_debug_port u_ila_0 probe
set_property port_width 8 [get_debug_ports u_ila_0/probe5]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe5]
connect_debug_port u_ila_0/probe5 [get_nets [list {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[cmd_header][opcode][value][0]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[cmd_header][opcode][value][1]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[cmd_header][opcode][value][2]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[cmd_header][opcode][value][3]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[cmd_header][opcode][value][4]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[cmd_header][opcode][value][5]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[cmd_header][opcode][value][6]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[cmd_header][opcode][value][7]} ]]
create_debug_port u_ila_0 probe
set_property port_width 8 [get_debug_ports u_ila_0/probe6]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe6]
connect_debug_port u_ila_0/probe6 [get_nets [list {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[cmd_header][cycle_kind][0]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[cmd_header][cycle_kind][1]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[cmd_header][cycle_kind][2]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[cmd_header][cycle_kind][3]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[cmd_header][cycle_kind][4]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[cmd_header][cycle_kind][5]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[cmd_header][cycle_kind][6]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[cmd_header][cycle_kind][7]} ]]
create_debug_port u_ila_0 probe
set_property port_width 12 [get_debug_ports u_ila_0/probe7]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe7]
connect_debug_port u_ila_0/probe7 [get_nets [list {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[cmd_header][length][0]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[cmd_header][length][1]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[cmd_header][length][2]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[cmd_header][length][3]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[cmd_header][length][4]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[cmd_header][length][5]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[cmd_header][length][6]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[cmd_header][length][7]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[cmd_header][length][8]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[cmd_header][length][9]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[cmd_header][length][10]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[cmd_header][length][11]} ]]
create_debug_port u_ila_0 probe
set_property port_width 4 [get_debug_ports u_ila_0/probe8]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe8]
connect_debug_port u_ila_0/probe8 [get_nets [list {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[cmd_header][tag][0]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[cmd_header][tag][1]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[cmd_header][tag][2]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[cmd_header][tag][3]} ]]
create_debug_port u_ila_0 probe
set_property port_width 4 [get_debug_ports u_ila_0/probe9]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe9]
connect_debug_port u_ila_0/probe9 [get_nets [list {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[hdr_idx][0]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[hdr_idx][1]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[hdr_idx][2]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[hdr_idx][3]} ]]
create_debug_port u_ila_0 probe
set_property port_width 32 [get_debug_ports u_ila_0/probe10]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe10]
connect_debug_port u_ila_0/probe10 [get_nets [list {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[io_wr_data][0]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[io_wr_data][1]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[io_wr_data][2]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[io_wr_data][3]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[io_wr_data][4]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[io_wr_data][5]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[io_wr_data][6]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[io_wr_data][7]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[io_wr_data][8]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[io_wr_data][9]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[io_wr_data][10]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[io_wr_data][11]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[io_wr_data][12]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[io_wr_data][13]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[io_wr_data][14]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[io_wr_data][15]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[io_wr_data][16]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[io_wr_data][17]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[io_wr_data][18]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[io_wr_data][19]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[io_wr_data][20]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[io_wr_data][21]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[io_wr_data][22]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[io_wr_data][23]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[io_wr_data][24]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[io_wr_data][25]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[io_wr_data][26]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[io_wr_data][27]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[io_wr_data][28]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[io_wr_data][29]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[io_wr_data][30]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[io_wr_data][31]} ]]
create_debug_port u_ila_0 probe
set_property port_width 3 [get_debug_ports u_ila_0/probe11]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe11]
connect_debug_port u_ila_0/probe11 [get_nets [list {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[rem_addr_bytes][0]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[rem_addr_bytes][1]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[rem_addr_bytes][2]} ]]
create_debug_port u_ila_0 probe
set_property port_width 12 [get_debug_ports u_ila_0/probe12]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe12]
connect_debug_port u_ila_0/probe12 [get_nets [list {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[rem_data_bytes][0]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[rem_data_bytes][1]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[rem_data_bytes][2]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[rem_data_bytes][3]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[rem_data_bytes][4]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[rem_data_bytes][5]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[rem_data_bytes][6]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[rem_data_bytes][7]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[rem_data_bytes][8]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[rem_data_bytes][9]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[rem_data_bytes][10]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[rem_data_bytes][11]} ]]
create_debug_port u_ila_0 probe
set_property port_width 4 [get_debug_ports u_ila_0/probe13]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe13]
connect_debug_port u_ila_0/probe13 [get_nets [list {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[state][0]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[state][1]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[state][2]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[state][3]} ]]
create_debug_port u_ila_0 probe
set_property port_width 8 [get_debug_ports u_ila_0/probe14]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe14]
connect_debug_port u_ila_0/probe14 [get_nets [list {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[vwire_dat][0]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[vwire_dat][1]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[vwire_dat][2]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[vwire_dat][3]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[vwire_dat][4]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[vwire_dat][5]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[vwire_dat][6]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[vwire_dat][7]} ]]
create_debug_port u_ila_0 probe
set_property port_width 8 [get_debug_ports u_ila_0/probe15]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe15]
connect_debug_port u_ila_0/probe15 [get_nets [list {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[vwire_idx][0]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[vwire_idx][1]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[vwire_idx][2]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[vwire_idx][3]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[vwire_idx][4]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[vwire_idx][5]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[vwire_idx][6]} {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[vwire_idx][7]} ]]
create_debug_port u_ila_0 probe
set_property port_width 12 [get_debug_ports u_ila_0/probe16]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe16]
connect_debug_port u_ila_0/probe16 [get_nets [list {espi_spinor_ss/espi_target_top_inst/transaction/response_processor_inst/r[payload_cnt][0]} {espi_spinor_ss/espi_target_top_inst/transaction/response_processor_inst/r[payload_cnt][1]} {espi_spinor_ss/espi_target_top_inst/transaction/response_processor_inst/r[payload_cnt][2]} {espi_spinor_ss/espi_target_top_inst/transaction/response_processor_inst/r[payload_cnt][3]} {espi_spinor_ss/espi_target_top_inst/transaction/response_processor_inst/r[payload_cnt][4]} {espi_spinor_ss/espi_target_top_inst/transaction/response_processor_inst/r[payload_cnt][5]} {espi_spinor_ss/espi_target_top_inst/transaction/response_processor_inst/r[payload_cnt][6]} {espi_spinor_ss/espi_target_top_inst/transaction/response_processor_inst/r[payload_cnt][7]} {espi_spinor_ss/espi_target_top_inst/transaction/response_processor_inst/r[payload_cnt][8]} {espi_spinor_ss/espi_target_top_inst/transaction/response_processor_inst/r[payload_cnt][9]} {espi_spinor_ss/espi_target_top_inst/transaction/response_processor_inst/r[payload_cnt][10]} {espi_spinor_ss/espi_target_top_inst/transaction/response_processor_inst/r[payload_cnt][11]} ]]
create_debug_port u_ila_0 probe
set_property port_width 8 [get_debug_ports u_ila_0/probe17]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe17]
connect_debug_port u_ila_0/probe17 [get_nets [list {espi_spinor_ss/espi_target_top_inst/transaction/response_processor_inst/r[cur_data][0]} {espi_spinor_ss/espi_target_top_inst/transaction/response_processor_inst/r[cur_data][1]} {espi_spinor_ss/espi_target_top_inst/transaction/response_processor_inst/r[cur_data][2]} {espi_spinor_ss/espi_target_top_inst/transaction/response_processor_inst/r[cur_data][3]} {espi_spinor_ss/espi_target_top_inst/transaction/response_processor_inst/r[cur_data][4]} {espi_spinor_ss/espi_target_top_inst/transaction/response_processor_inst/r[cur_data][5]} {espi_spinor_ss/espi_target_top_inst/transaction/response_processor_inst/r[cur_data][6]} {espi_spinor_ss/espi_target_top_inst/transaction/response_processor_inst/r[cur_data][7]} ]]
create_debug_port u_ila_0 probe
set_property port_width 32 [get_debug_ports u_ila_0/probe18]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe18]
connect_debug_port u_ila_0/probe18 [get_nets [list {espi_spinor_ss/espi_target_top_inst/transaction/response_processor_inst/r[reg_data][0]} {espi_spinor_ss/espi_target_top_inst/transaction/response_processor_inst/r[reg_data][1]} {espi_spinor_ss/espi_target_top_inst/transaction/response_processor_inst/r[reg_data][2]} {espi_spinor_ss/espi_target_top_inst/transaction/response_processor_inst/r[reg_data][3]} {espi_spinor_ss/espi_target_top_inst/transaction/response_processor_inst/r[reg_data][4]} {espi_spinor_ss/espi_target_top_inst/transaction/response_processor_inst/r[reg_data][5]} {espi_spinor_ss/espi_target_top_inst/transaction/response_processor_inst/r[reg_data][6]} {espi_spinor_ss/espi_target_top_inst/transaction/response_processor_inst/r[reg_data][7]} {espi_spinor_ss/espi_target_top_inst/transaction/response_processor_inst/r[reg_data][8]} {espi_spinor_ss/espi_target_top_inst/transaction/response_processor_inst/r[reg_data][9]} {espi_spinor_ss/espi_target_top_inst/transaction/response_processor_inst/r[reg_data][10]} {espi_spinor_ss/espi_target_top_inst/transaction/response_processor_inst/r[reg_data][11]} {espi_spinor_ss/espi_target_top_inst/transaction/response_processor_inst/r[reg_data][12]} {espi_spinor_ss/espi_target_top_inst/transaction/response_processor_inst/r[reg_data][13]} {espi_spinor_ss/espi_target_top_inst/transaction/response_processor_inst/r[reg_data][14]} {espi_spinor_ss/espi_target_top_inst/transaction/response_processor_inst/r[reg_data][15]} {espi_spinor_ss/espi_target_top_inst/transaction/response_processor_inst/r[reg_data][16]} {espi_spinor_ss/espi_target_top_inst/transaction/response_processor_inst/r[reg_data][17]} {espi_spinor_ss/espi_target_top_inst/transaction/response_processor_inst/r[reg_data][18]} {espi_spinor_ss/espi_target_top_inst/transaction/response_processor_inst/r[reg_data][19]} {espi_spinor_ss/espi_target_top_inst/transaction/response_processor_inst/r[reg_data][20]} {espi_spinor_ss/espi_target_top_inst/transaction/response_processor_inst/r[reg_data][21]} {espi_spinor_ss/espi_target_top_inst/transaction/response_processor_inst/r[reg_data][22]} {espi_spinor_ss/espi_target_top_inst/transaction/response_processor_inst/r[reg_data][23]} {espi_spinor_ss/espi_target_top_inst/transaction/response_processor_inst/r[reg_data][24]} {espi_spinor_ss/espi_target_top_inst/transaction/response_processor_inst/r[reg_data][25]} {espi_spinor_ss/espi_target_top_inst/transaction/response_processor_inst/r[reg_data][26]} {espi_spinor_ss/espi_target_top_inst/transaction/response_processor_inst/r[reg_data][27]} {espi_spinor_ss/espi_target_top_inst/transaction/response_processor_inst/r[reg_data][28]} {espi_spinor_ss/espi_target_top_inst/transaction/response_processor_inst/r[reg_data][29]} {espi_spinor_ss/espi_target_top_inst/transaction/response_processor_inst/r[reg_data][30]} {espi_spinor_ss/espi_target_top_inst/transaction/response_processor_inst/r[reg_data][31]} ]]
create_debug_port u_ila_0 probe
set_property port_width 8 [get_debug_ports u_ila_0/probe19]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe19]
connect_debug_port u_ila_0/probe19 [get_nets [list {espi_spinor_ss/espi_target_top_inst/transaction/response_processor_inst/r[resp_idx][0]} {espi_spinor_ss/espi_target_top_inst/transaction/response_processor_inst/r[resp_idx][1]} {espi_spinor_ss/espi_target_top_inst/transaction/response_processor_inst/r[resp_idx][2]} {espi_spinor_ss/espi_target_top_inst/transaction/response_processor_inst/r[resp_idx][3]} {espi_spinor_ss/espi_target_top_inst/transaction/response_processor_inst/r[resp_idx][4]} {espi_spinor_ss/espi_target_top_inst/transaction/response_processor_inst/r[resp_idx][5]} {espi_spinor_ss/espi_target_top_inst/transaction/response_processor_inst/r[resp_idx][6]} {espi_spinor_ss/espi_target_top_inst/transaction/response_processor_inst/r[resp_idx][7]} ]]
create_debug_port u_ila_0 probe
set_property port_width 4 [get_debug_ports u_ila_0/probe20]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe20]
connect_debug_port u_ila_0/probe20 [get_nets [list {espi_spinor_ss/espi_target_top_inst/transaction/response_processor_inst/r[state][0]} {espi_spinor_ss/espi_target_top_inst/transaction/response_processor_inst/r[state][1]} {espi_spinor_ss/espi_target_top_inst/transaction/response_processor_inst/r[state][2]} {espi_spinor_ss/espi_target_top_inst/transaction/response_processor_inst/r[state][3]} ]]
create_debug_port u_ila_0 probe
set_property port_width 12 [get_debug_ports u_ila_0/probe21]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe21]
connect_debug_port u_ila_0/probe21 [get_nets [list {espi_spinor_ss/espi_target_top_inst/transaction/response_processor_inst/r[temp_length][0]} {espi_spinor_ss/espi_target_top_inst/transaction/response_processor_inst/r[temp_length][1]} {espi_spinor_ss/espi_target_top_inst/transaction/response_processor_inst/r[temp_length][2]} {espi_spinor_ss/espi_target_top_inst/transaction/response_processor_inst/r[temp_length][3]} {espi_spinor_ss/espi_target_top_inst/transaction/response_processor_inst/r[temp_length][4]} {espi_spinor_ss/espi_target_top_inst/transaction/response_processor_inst/r[temp_length][5]} {espi_spinor_ss/espi_target_top_inst/transaction/response_processor_inst/r[temp_length][6]} {espi_spinor_ss/espi_target_top_inst/transaction/response_processor_inst/r[temp_length][7]} {espi_spinor_ss/espi_target_top_inst/transaction/response_processor_inst/r[temp_length][8]} {espi_spinor_ss/espi_target_top_inst/transaction/response_processor_inst/r[temp_length][9]} {espi_spinor_ss/espi_target_top_inst/transaction/response_processor_inst/r[temp_length][10]} {espi_spinor_ss/espi_target_top_inst/transaction/response_processor_inst/r[temp_length][11]} ]]
create_debug_port u_ila_0 probe
set_property port_width 9 [get_debug_ports u_ila_0/probe22]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe22]
connect_debug_port u_ila_0/probe22 [get_nets [list {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[dummy_cycles][0]} {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[dummy_cycles][1]} {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[dummy_cycles][2]} {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[dummy_cycles][3]} {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[dummy_cycles][4]} {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[dummy_cycles][5]} {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[dummy_cycles][6]} {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[dummy_cycles][7]} {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[dummy_cycles][8]} ]]
create_debug_port u_ila_0 probe
set_property port_width 32 [get_debug_ports u_ila_0/probe23]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe23]
connect_debug_port u_ila_0/probe23 [get_nets [list {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[cur_flash_addr][0]} {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[cur_flash_addr][1]} {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[cur_flash_addr][2]} {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[cur_flash_addr][3]} {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[cur_flash_addr][4]} {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[cur_flash_addr][5]} {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[cur_flash_addr][6]} {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[cur_flash_addr][7]} {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[cur_flash_addr][8]} {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[cur_flash_addr][9]} {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[cur_flash_addr][10]} {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[cur_flash_addr][11]} {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[cur_flash_addr][12]} {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[cur_flash_addr][13]} {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[cur_flash_addr][14]} {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[cur_flash_addr][15]} {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[cur_flash_addr][16]} {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[cur_flash_addr][17]} {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[cur_flash_addr][18]} {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[cur_flash_addr][19]} {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[cur_flash_addr][20]} {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[cur_flash_addr][21]} {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[cur_flash_addr][22]} {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[cur_flash_addr][23]} {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[cur_flash_addr][24]} {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[cur_flash_addr][25]} {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[cur_flash_addr][26]} {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[cur_flash_addr][27]} {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[cur_flash_addr][28]} {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[cur_flash_addr][29]} {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[cur_flash_addr][30]} {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[cur_flash_addr][31]} ]]
create_debug_port u_ila_0 probe
set_property port_width 9 [get_debug_ports u_ila_0/probe24]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe24]
connect_debug_port u_ila_0/probe24 [get_nets [list {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[data_bytes][0]} {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[data_bytes][1]} {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[data_bytes][2]} {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[data_bytes][3]} {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[data_bytes][4]} {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[data_bytes][5]} {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[data_bytes][6]} {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[data_bytes][7]} {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[data_bytes][8]} ]]
create_debug_port u_ila_0 probe
set_property port_width 32 [get_debug_ports u_ila_0/probe25]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe25]
connect_debug_port u_ila_0/probe25 [get_nets [list {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[len][0]} {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[len][1]} {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[len][2]} {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[len][3]} {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[len][4]} {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[len][5]} {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[len][6]} {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[len][7]} {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[len][8]} {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[len][9]} {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[len][10]} {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[len][11]} {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[len][12]} {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[len][13]} {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[len][14]} {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[len][15]} {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[len][16]} {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[len][17]} {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[len][18]} {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[len][19]} {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[len][20]} {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[len][21]} {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[len][22]} {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[len][23]} {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[len][24]} {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[len][25]} {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[len][26]} {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[len][27]} {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[len][28]} {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[len][29]} {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[len][30]} {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[len][31]} ]]
create_debug_port u_ila_0 probe
set_property port_width 32 [get_debug_ports u_ila_0/probe26]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe26]
connect_debug_port u_ila_0/probe26 [get_nets [list {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[next_flash_addr][0]} {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[next_flash_addr][1]} {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[next_flash_addr][2]} {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[next_flash_addr][3]} {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[next_flash_addr][4]} {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[next_flash_addr][5]} {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[next_flash_addr][6]} {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[next_flash_addr][7]} {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[next_flash_addr][8]} {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[next_flash_addr][9]} {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[next_flash_addr][10]} {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[next_flash_addr][11]} {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[next_flash_addr][12]} {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[next_flash_addr][13]} {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[next_flash_addr][14]} {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[next_flash_addr][15]} {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[next_flash_addr][16]} {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[next_flash_addr][17]} {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[next_flash_addr][18]} {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[next_flash_addr][19]} {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[next_flash_addr][20]} {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[next_flash_addr][21]} {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[next_flash_addr][22]} {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[next_flash_addr][23]} {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[next_flash_addr][24]} {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[next_flash_addr][25]} {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[next_flash_addr][26]} {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[next_flash_addr][27]} {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[next_flash_addr][28]} {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[next_flash_addr][29]} {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[next_flash_addr][30]} {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[next_flash_addr][31]} ]]
create_debug_port u_ila_0 probe
set_property port_width 13 [get_debug_ports u_ila_0/probe27]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe27]
connect_debug_port u_ila_0/probe27 [get_nets [list {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[rem_bytes][0]} {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[rem_bytes][1]} {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[rem_bytes][2]} {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[rem_bytes][3]} {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[rem_bytes][4]} {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[rem_bytes][5]} {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[rem_bytes][6]} {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[rem_bytes][7]} {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[rem_bytes][8]} {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[rem_bytes][9]} {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[rem_bytes][10]} {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[rem_bytes][11]} {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[rem_bytes][12]} ]]
create_debug_port u_ila_0 probe
set_property port_width 3 [get_debug_ports u_ila_0/probe28]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe28]
connect_debug_port u_ila_0/probe28 [get_nets [list {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[state][0]} {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[state][1]} {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[state][2]} ]]
create_debug_port u_ila_0 probe
set_property port_width 8 [get_debug_ports u_ila_0/probe29]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe29]
connect_debug_port u_ila_0/probe29 [get_nets [list {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[txn_bytes][0]} {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[txn_bytes][1]} {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[txn_bytes][2]} {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[txn_bytes][3]} {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[txn_bytes][4]} {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[txn_bytes][5]} {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[txn_bytes][6]} {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[txn_bytes][7]} ]]
create_debug_port u_ila_0 probe
set_property port_width 32 [get_debug_ports u_ila_0/probe30]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe30]
connect_debug_port u_ila_0/probe30 [get_nets [list {espi_spinor_ss/spi_nor_top_inst/link/dbg_sclk_cnts[0]} {espi_spinor_ss/spi_nor_top_inst/link/dbg_sclk_cnts[1]} {espi_spinor_ss/spi_nor_top_inst/link/dbg_sclk_cnts[2]} {espi_spinor_ss/spi_nor_top_inst/link/dbg_sclk_cnts[3]} {espi_spinor_ss/spi_nor_top_inst/link/dbg_sclk_cnts[4]} {espi_spinor_ss/spi_nor_top_inst/link/dbg_sclk_cnts[5]} {espi_spinor_ss/spi_nor_top_inst/link/dbg_sclk_cnts[6]} {espi_spinor_ss/spi_nor_top_inst/link/dbg_sclk_cnts[7]} {espi_spinor_ss/spi_nor_top_inst/link/dbg_sclk_cnts[8]} {espi_spinor_ss/spi_nor_top_inst/link/dbg_sclk_cnts[9]} {espi_spinor_ss/spi_nor_top_inst/link/dbg_sclk_cnts[10]} {espi_spinor_ss/spi_nor_top_inst/link/dbg_sclk_cnts[11]} {espi_spinor_ss/spi_nor_top_inst/link/dbg_sclk_cnts[12]} {espi_spinor_ss/spi_nor_top_inst/link/dbg_sclk_cnts[13]} {espi_spinor_ss/spi_nor_top_inst/link/dbg_sclk_cnts[14]} {espi_spinor_ss/spi_nor_top_inst/link/dbg_sclk_cnts[15]} {espi_spinor_ss/spi_nor_top_inst/link/dbg_sclk_cnts[16]} {espi_spinor_ss/spi_nor_top_inst/link/dbg_sclk_cnts[17]} {espi_spinor_ss/spi_nor_top_inst/link/dbg_sclk_cnts[18]} {espi_spinor_ss/spi_nor_top_inst/link/dbg_sclk_cnts[19]} {espi_spinor_ss/spi_nor_top_inst/link/dbg_sclk_cnts[20]} {espi_spinor_ss/spi_nor_top_inst/link/dbg_sclk_cnts[21]} {espi_spinor_ss/spi_nor_top_inst/link/dbg_sclk_cnts[22]} {espi_spinor_ss/spi_nor_top_inst/link/dbg_sclk_cnts[23]} {espi_spinor_ss/spi_nor_top_inst/link/dbg_sclk_cnts[24]} {espi_spinor_ss/spi_nor_top_inst/link/dbg_sclk_cnts[25]} {espi_spinor_ss/spi_nor_top_inst/link/dbg_sclk_cnts[26]} {espi_spinor_ss/spi_nor_top_inst/link/dbg_sclk_cnts[27]} {espi_spinor_ss/spi_nor_top_inst/link/dbg_sclk_cnts[28]} {espi_spinor_ss/spi_nor_top_inst/link/dbg_sclk_cnts[29]} {espi_spinor_ss/spi_nor_top_inst/link/dbg_sclk_cnts[30]} {espi_spinor_ss/spi_nor_top_inst/link/dbg_sclk_cnts[31]} ]]
create_debug_port u_ila_0 probe
set_property port_width 9 [get_debug_ports u_ila_0/probe31]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe31]
connect_debug_port u_ila_0/probe31 [get_nets [list {espi_spinor_ss/spi_nor_top_inst/link/rx_reg[0]} {espi_spinor_ss/spi_nor_top_inst/link/rx_reg[1]} {espi_spinor_ss/spi_nor_top_inst/link/rx_reg[2]} {espi_spinor_ss/spi_nor_top_inst/link/rx_reg[3]} {espi_spinor_ss/spi_nor_top_inst/link/rx_reg[4]} {espi_spinor_ss/spi_nor_top_inst/link/rx_reg[5]} {espi_spinor_ss/spi_nor_top_inst/link/rx_reg[6]} {espi_spinor_ss/spi_nor_top_inst/link/rx_reg[7]} {espi_spinor_ss/spi_nor_top_inst/link/rx_reg[8]} ]]
create_debug_port u_ila_0 probe
set_property port_width 9 [get_debug_ports u_ila_0/probe32]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe32]
connect_debug_port u_ila_0/probe32 [get_nets [list {espi_spinor_ss/spi_nor_top_inst/link/tx_reg[0]} {espi_spinor_ss/spi_nor_top_inst/link/tx_reg[1]} {espi_spinor_ss/spi_nor_top_inst/link/tx_reg[2]} {espi_spinor_ss/spi_nor_top_inst/link/tx_reg[3]} {espi_spinor_ss/spi_nor_top_inst/link/tx_reg[4]} {espi_spinor_ss/spi_nor_top_inst/link/tx_reg[5]} {espi_spinor_ss/spi_nor_top_inst/link/tx_reg[6]} {espi_spinor_ss/spi_nor_top_inst/link/tx_reg[7]} {espi_spinor_ss/spi_nor_top_inst/link/tx_reg[8]} ]]
create_debug_port u_ila_0 probe
set_property port_width 10 [get_debug_ports u_ila_0/probe33]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe33]
connect_debug_port u_ila_0/probe33 [get_nets [list {espi_spinor_ss/spi_nor_top_inst/spi_txn_mgr_inst/r[counter][0]} {espi_spinor_ss/spi_nor_top_inst/spi_txn_mgr_inst/r[counter][1]} {espi_spinor_ss/spi_nor_top_inst/spi_txn_mgr_inst/r[counter][2]} {espi_spinor_ss/spi_nor_top_inst/spi_txn_mgr_inst/r[counter][3]} {espi_spinor_ss/spi_nor_top_inst/spi_txn_mgr_inst/r[counter][4]} {espi_spinor_ss/spi_nor_top_inst/spi_txn_mgr_inst/r[counter][5]} {espi_spinor_ss/spi_nor_top_inst/spi_txn_mgr_inst/r[counter][6]} {espi_spinor_ss/spi_nor_top_inst/spi_txn_mgr_inst/r[counter][7]} {espi_spinor_ss/spi_nor_top_inst/spi_txn_mgr_inst/r[counter][8]} {espi_spinor_ss/spi_nor_top_inst/spi_txn_mgr_inst/r[counter][9]} ]]
create_debug_port u_ila_0 probe
set_property port_width 3 [get_debug_ports u_ila_0/probe34]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe34]
connect_debug_port u_ila_0/probe34 [get_nets [list {espi_spinor_ss/spi_nor_top_inst/spi_txn_mgr_inst/r[state][0]} {espi_spinor_ss/spi_nor_top_inst/spi_txn_mgr_inst/r[state][1]} {espi_spinor_ss/spi_nor_top_inst/spi_txn_mgr_inst/r[state][2]} ]]
create_debug_port u_ila_0 probe
set_property port_width 2 [get_debug_ports u_ila_0/probe35]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe35]
connect_debug_port u_ila_0/probe35 [get_nets [list {espi_spinor_ss/spi_nor_top_inst/spi_txn_mgr_inst/r[txn][addr_kind][0]} {espi_spinor_ss/spi_nor_top_inst/spi_txn_mgr_inst/r[txn][addr_kind][1]} ]]
create_debug_port u_ila_0 probe
set_property port_width 2 [get_debug_ports u_ila_0/probe36]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe36]
connect_debug_port u_ila_0/probe36 [get_nets [list {espi_spinor_ss/spi_nor_top_inst/spi_txn_mgr_inst/r[txn][data_kind][0]} {espi_spinor_ss/spi_nor_top_inst/spi_txn_mgr_inst/r[txn][data_kind][1]} ]]
create_debug_port u_ila_0 probe
set_property port_width 2 [get_debug_ports u_ila_0/probe37]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe37]
connect_debug_port u_ila_0/probe37 [get_nets [list {espi_spinor_ss/spi_nor_top_inst/spi_txn_mgr_inst/r[txn][data_mode][0]} {espi_spinor_ss/spi_nor_top_inst/spi_txn_mgr_inst/r[txn][data_mode][1]} ]]
create_debug_port u_ila_0 probe
set_property port_width 8 [get_debug_ports u_ila_0/probe38]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe38]
connect_debug_port u_ila_0/probe38 [get_nets [list {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/dpr_wdata[0]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/dpr_wdata[1]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/dpr_wdata[2]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/dpr_wdata[3]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/dpr_wdata[4]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/dpr_wdata[5]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/dpr_wdata[6]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/dpr_wdata[7]} ]]
create_debug_port u_ila_0 probe
set_property port_width 8 [get_debug_ports u_ila_0/probe39]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe39]
connect_debug_port u_ila_0/probe39 [get_nets [list {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/dpr_rdata[0]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/dpr_rdata[1]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/dpr_rdata[2]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/dpr_rdata[3]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/dpr_rdata[4]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/dpr_rdata[5]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/dpr_rdata[6]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/dpr_rdata[7]} ]]
create_debug_port u_ila_0 probe
set_property port_width 32 [get_debug_ports u_ila_0/probe40]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe40]
connect_debug_port u_ila_0/probe40 [get_nets [list {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][0][sp5_addr][0]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][0][sp5_addr][1]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][0][sp5_addr][2]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][0][sp5_addr][3]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][0][sp5_addr][4]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][0][sp5_addr][5]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][0][sp5_addr][6]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][0][sp5_addr][7]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][0][sp5_addr][8]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][0][sp5_addr][9]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][0][sp5_addr][10]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][0][sp5_addr][11]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][0][sp5_addr][12]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][0][sp5_addr][13]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][0][sp5_addr][14]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][0][sp5_addr][15]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][0][sp5_addr][16]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][0][sp5_addr][17]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][0][sp5_addr][18]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][0][sp5_addr][19]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][0][sp5_addr][20]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][0][sp5_addr][21]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][0][sp5_addr][22]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][0][sp5_addr][23]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][0][sp5_addr][24]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][0][sp5_addr][25]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][0][sp5_addr][26]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][0][sp5_addr][27]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][0][sp5_addr][28]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][0][sp5_addr][29]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][0][sp5_addr][30]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][0][sp5_addr][31]} ]]
create_debug_port u_ila_0 probe
set_property port_width 12 [get_debug_ports u_ila_0/probe41]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe41]
connect_debug_port u_ila_0/probe41 [get_nets [list {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][0][ready_bytes][0]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][0][ready_bytes][1]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][0][ready_bytes][2]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][0][ready_bytes][3]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][0][ready_bytes][4]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][0][ready_bytes][5]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][0][ready_bytes][6]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][0][ready_bytes][7]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][0][ready_bytes][8]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][0][ready_bytes][9]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][0][ready_bytes][10]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][0][ready_bytes][11]} ]]
create_debug_port u_ila_0 probe
set_property port_width 12 [get_debug_ports u_ila_0/probe42]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe42]
connect_debug_port u_ila_0/probe42 [get_nets [list {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][0][xfr_size_bytes][0]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][0][xfr_size_bytes][1]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][0][xfr_size_bytes][2]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][0][xfr_size_bytes][3]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][0][xfr_size_bytes][4]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][0][xfr_size_bytes][5]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][0][xfr_size_bytes][6]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][0][xfr_size_bytes][7]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][0][xfr_size_bytes][8]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][0][xfr_size_bytes][9]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][0][xfr_size_bytes][10]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][0][xfr_size_bytes][11]} ]]
create_debug_port u_ila_0 probe
set_property port_width 12 [get_debug_ports u_ila_0/probe43]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe43]
connect_debug_port u_ila_0/probe43 [get_nets [list {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][1][ready_bytes][0]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][1][ready_bytes][1]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][1][ready_bytes][2]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][1][ready_bytes][3]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][1][ready_bytes][4]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][1][ready_bytes][5]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][1][ready_bytes][6]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][1][ready_bytes][7]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][1][ready_bytes][8]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][1][ready_bytes][9]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][1][ready_bytes][10]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][1][ready_bytes][11]} ]]
create_debug_port u_ila_0 probe
set_property port_width 4 [get_debug_ports u_ila_0/probe44]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe44]
connect_debug_port u_ila_0/probe44 [get_nets [list {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][0][tag][0]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][0][tag][1]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][0][tag][2]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][0][tag][3]} ]]
create_debug_port u_ila_0 probe
set_property port_width 32 [get_debug_ports u_ila_0/probe45]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe45]
connect_debug_port u_ila_0/probe45 [get_nets [list {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][1][sp5_addr][0]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][1][sp5_addr][1]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][1][sp5_addr][2]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][1][sp5_addr][3]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][1][sp5_addr][4]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][1][sp5_addr][5]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][1][sp5_addr][6]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][1][sp5_addr][7]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][1][sp5_addr][8]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][1][sp5_addr][9]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][1][sp5_addr][10]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][1][sp5_addr][11]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][1][sp5_addr][12]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][1][sp5_addr][13]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][1][sp5_addr][14]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][1][sp5_addr][15]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][1][sp5_addr][16]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][1][sp5_addr][17]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][1][sp5_addr][18]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][1][sp5_addr][19]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][1][sp5_addr][20]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][1][sp5_addr][21]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][1][sp5_addr][22]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][1][sp5_addr][23]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][1][sp5_addr][24]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][1][sp5_addr][25]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][1][sp5_addr][26]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][1][sp5_addr][27]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][1][sp5_addr][28]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][1][sp5_addr][29]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][1][sp5_addr][30]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][1][sp5_addr][31]} ]]
create_debug_port u_ila_0 probe
set_property port_width 4 [get_debug_ports u_ila_0/probe46]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe46]
connect_debug_port u_ila_0/probe46 [get_nets [list {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][1][tag][0]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][1][tag][1]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][1][tag][2]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][1][tag][3]} ]]
create_debug_port u_ila_0 probe
set_property port_width 12 [get_debug_ports u_ila_0/probe47]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe47]
connect_debug_port u_ila_0/probe47 [get_nets [list {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][1][xfr_size_bytes][0]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][1][xfr_size_bytes][1]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][1][xfr_size_bytes][2]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][1][xfr_size_bytes][3]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][1][xfr_size_bytes][4]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][1][xfr_size_bytes][5]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][1][xfr_size_bytes][6]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][1][xfr_size_bytes][7]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][1][xfr_size_bytes][8]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][1][xfr_size_bytes][9]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][1][xfr_size_bytes][10]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][1][xfr_size_bytes][11]} ]]
create_debug_port u_ila_0 probe
set_property port_width 12 [get_debug_ports u_ila_0/probe48]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe48]
connect_debug_port u_ila_0/probe48 [get_nets [list {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][2][ready_bytes][0]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][2][ready_bytes][1]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][2][ready_bytes][2]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][2][ready_bytes][3]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][2][ready_bytes][4]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][2][ready_bytes][5]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][2][ready_bytes][6]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][2][ready_bytes][7]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][2][ready_bytes][8]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][2][ready_bytes][9]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][2][ready_bytes][10]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][2][ready_bytes][11]} ]]
create_debug_port u_ila_0 probe
set_property port_width 32 [get_debug_ports u_ila_0/probe49]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe49]
connect_debug_port u_ila_0/probe49 [get_nets [list {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][2][sp5_addr][0]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][2][sp5_addr][1]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][2][sp5_addr][2]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][2][sp5_addr][3]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][2][sp5_addr][4]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][2][sp5_addr][5]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][2][sp5_addr][6]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][2][sp5_addr][7]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][2][sp5_addr][8]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][2][sp5_addr][9]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][2][sp5_addr][10]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][2][sp5_addr][11]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][2][sp5_addr][12]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][2][sp5_addr][13]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][2][sp5_addr][14]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][2][sp5_addr][15]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][2][sp5_addr][16]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][2][sp5_addr][17]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][2][sp5_addr][18]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][2][sp5_addr][19]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][2][sp5_addr][20]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][2][sp5_addr][21]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][2][sp5_addr][22]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][2][sp5_addr][23]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][2][sp5_addr][24]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][2][sp5_addr][25]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][2][sp5_addr][26]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][2][sp5_addr][27]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][2][sp5_addr][28]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][2][sp5_addr][29]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][2][sp5_addr][30]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][2][sp5_addr][31]} ]]
create_debug_port u_ila_0 probe
set_property port_width 4 [get_debug_ports u_ila_0/probe50]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe50]
connect_debug_port u_ila_0/probe50 [get_nets [list {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][2][tag][0]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][2][tag][1]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][2][tag][2]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][2][tag][3]} ]]
create_debug_port u_ila_0 probe
set_property port_width 12 [get_debug_ports u_ila_0/probe51]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe51]
connect_debug_port u_ila_0/probe51 [get_nets [list {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][2][xfr_size_bytes][0]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][2][xfr_size_bytes][1]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][2][xfr_size_bytes][2]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][2][xfr_size_bytes][3]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][2][xfr_size_bytes][4]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][2][xfr_size_bytes][5]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][2][xfr_size_bytes][6]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][2][xfr_size_bytes][7]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][2][xfr_size_bytes][8]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][2][xfr_size_bytes][9]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][2][xfr_size_bytes][10]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][2][xfr_size_bytes][11]} ]]
create_debug_port u_ila_0 probe
set_property port_width 12 [get_debug_ports u_ila_0/probe52]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe52]
connect_debug_port u_ila_0/probe52 [get_nets [list {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][3][ready_bytes][0]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][3][ready_bytes][1]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][3][ready_bytes][2]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][3][ready_bytes][3]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][3][ready_bytes][4]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][3][ready_bytes][5]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][3][ready_bytes][6]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][3][ready_bytes][7]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][3][ready_bytes][8]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][3][ready_bytes][9]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][3][ready_bytes][10]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][3][ready_bytes][11]} ]]
create_debug_port u_ila_0 probe
set_property port_width 32 [get_debug_ports u_ila_0/probe53]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe53]
connect_debug_port u_ila_0/probe53 [get_nets [list {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][3][sp5_addr][0]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][3][sp5_addr][1]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][3][sp5_addr][2]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][3][sp5_addr][3]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][3][sp5_addr][4]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][3][sp5_addr][5]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][3][sp5_addr][6]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][3][sp5_addr][7]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][3][sp5_addr][8]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][3][sp5_addr][9]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][3][sp5_addr][10]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][3][sp5_addr][11]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][3][sp5_addr][12]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][3][sp5_addr][13]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][3][sp5_addr][14]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][3][sp5_addr][15]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][3][sp5_addr][16]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][3][sp5_addr][17]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][3][sp5_addr][18]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][3][sp5_addr][19]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][3][sp5_addr][20]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][3][sp5_addr][21]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][3][sp5_addr][22]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][3][sp5_addr][23]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][3][sp5_addr][24]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][3][sp5_addr][25]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][3][sp5_addr][26]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][3][sp5_addr][27]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][3][sp5_addr][28]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][3][sp5_addr][29]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][3][sp5_addr][30]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][3][sp5_addr][31]} ]]
create_debug_port u_ila_0 probe
set_property port_width 4 [get_debug_ports u_ila_0/probe54]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe54]
connect_debug_port u_ila_0/probe54 [get_nets [list {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][3][tag][0]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][3][tag][1]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][3][tag][2]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][3][tag][3]} ]]
create_debug_port u_ila_0 probe
set_property port_width 12 [get_debug_ports u_ila_0/probe55]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe55]
connect_debug_port u_ila_0/probe55 [get_nets [list {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][3][xfr_size_bytes][0]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][3][xfr_size_bytes][1]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][3][xfr_size_bytes][2]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][3][xfr_size_bytes][3]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][3][xfr_size_bytes][4]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][3][xfr_size_bytes][5]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][3][xfr_size_bytes][6]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][3][xfr_size_bytes][7]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][3][xfr_size_bytes][8]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][3][xfr_size_bytes][9]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][3][xfr_size_bytes][10]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][3][xfr_size_bytes][11]} ]]
create_debug_port u_ila_0 probe
set_property port_width 11 [get_debug_ports u_ila_0/probe56]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe56]
connect_debug_port u_ila_0/probe56 [get_nets [list {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[compl_side_cntr][0]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[compl_side_cntr][1]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[compl_side_cntr][2]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[compl_side_cntr][3]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[compl_side_cntr][4]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[compl_side_cntr][5]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[compl_side_cntr][6]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[compl_side_cntr][7]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[compl_side_cntr][8]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[compl_side_cntr][9]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[compl_side_cntr][10]} ]]
create_debug_port u_ila_0 probe
set_property port_width 8 [get_debug_ports u_ila_0/probe57]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe57]
connect_debug_port u_ila_0/probe57 [get_nets [list {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[dpr_wdata_buf][0]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[dpr_wdata_buf][1]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[dpr_wdata_buf][2]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[dpr_wdata_buf][3]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[dpr_wdata_buf][4]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[dpr_wdata_buf][5]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[dpr_wdata_buf][6]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[dpr_wdata_buf][7]} ]]
create_debug_port u_ila_0 probe
set_property port_width 2 [get_debug_ports u_ila_0/probe58]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe58]
connect_debug_port u_ila_0/probe58 [get_nets [list {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[flash_cmd_state][0]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[flash_cmd_state][1]} ]]
create_debug_port u_ila_0 probe
set_property port_width 11 [get_debug_ports u_ila_0/probe59]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe59]
connect_debug_port u_ila_0/probe59 [get_nets [list {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[flash_side_cntr][0]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[flash_side_cntr][1]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[flash_side_cntr][2]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[flash_side_cntr][3]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[flash_side_cntr][4]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[flash_side_cntr][5]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[flash_side_cntr][6]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[flash_side_cntr][7]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[flash_side_cntr][8]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[flash_side_cntr][9]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[flash_side_cntr][10]} ]]
create_debug_port u_ila_0 probe
set_property port_width 11 [get_debug_ports u_ila_0/probe60]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe60]
connect_debug_port u_ila_0/probe60 [get_nets [list {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[flash_write_addr_offset][0]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[flash_write_addr_offset][1]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[flash_write_addr_offset][2]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[flash_write_addr_offset][3]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[flash_write_addr_offset][4]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[flash_write_addr_offset][5]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[flash_write_addr_offset][6]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[flash_write_addr_offset][7]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[flash_write_addr_offset][8]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[flash_write_addr_offset][9]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[flash_write_addr_offset][10]} ]]
create_debug_port u_ila_0 probe
set_property port_width 2 [get_debug_ports u_ila_0/probe61]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe61]
connect_debug_port u_ila_0/probe61 [get_nets [list {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[head_desc][0]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[head_desc][1]} ]]
create_debug_port u_ila_0 probe
set_property port_width 2 [get_debug_ports u_ila_0/probe62]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe62]
connect_debug_port u_ila_0/probe62 [get_nets [list {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[issue_desc][0]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[issue_desc][1]} ]]
create_debug_port u_ila_0 probe
set_property port_width 2 [get_debug_ports u_ila_0/probe63]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe63]
connect_debug_port u_ila_0/probe63 [get_nets [list {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[tail_desc][0]} {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[tail_desc][1]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe64]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe64]
connect_debug_port u_ila_0/probe64 [get_nets [list espi_spinor_ss/espi_target_top_inst/flash_channel_inst/dpr_read_ack ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe65]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe65]
connect_debug_port u_ila_0/probe65 [get_nets [list espi_spinor_ss/espi_target_top_inst/flash_channel_inst/dpr_wr_delay ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe66]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe66]
connect_debug_port u_ila_0/probe66 [get_nets [list espi_spinor_ss/espi_target_top_inst/link_to_txn_bridge_inst/qspi_resp_slow_write_en ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe67]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe67]
connect_debug_port u_ila_0/probe67 [get_nets [list {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[cmd_header][opcode][valid]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe68]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe68]
connect_debug_port u_ila_0/probe68 [get_nets [list {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[cmd_header][valid]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe69]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe69]
connect_debug_port u_ila_0/probe69 [get_nets [list {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][0][active]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe70]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe70]
connect_debug_port u_ila_0/probe70 [get_nets [list {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][0][done]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe71]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe71]
connect_debug_port u_ila_0/probe71 [get_nets [list {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][0][flash_issued]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe72]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe72]
connect_debug_port u_ila_0/probe72 [get_nets [list {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][1][active]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe73]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe73]
connect_debug_port u_ila_0/probe73 [get_nets [list {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][1][done]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe74]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe74]
connect_debug_port u_ila_0/probe74 [get_nets [list {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][1][flash_issued]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe75]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe75]
connect_debug_port u_ila_0/probe75 [get_nets [list {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][2][active]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe76]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe76]
connect_debug_port u_ila_0/probe76 [get_nets [list {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][2][done]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe77]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe77]
connect_debug_port u_ila_0/probe77 [get_nets [list {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][2][flash_issued]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe78]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe78]
connect_debug_port u_ila_0/probe78 [get_nets [list {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][3][active]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe79]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe79]
connect_debug_port u_ila_0/probe79 [get_nets [list {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][3][done]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe80]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe80]
connect_debug_port u_ila_0/probe80 [get_nets [list {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[cmd_queue][3][flash_issued]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe81]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe81]
connect_debug_port u_ila_0/probe81 [get_nets [list {espi_spinor_ss/spi_nor_top_inst/espi_flash_txn_mgr_inst/r[cmd_rdack]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe82]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe82]
connect_debug_port u_ila_0/probe82 [get_nets [list {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[compl_state]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe83]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe83]
connect_debug_port u_ila_0/probe83 [get_nets [list {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[crc_bad]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe84]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe84]
connect_debug_port u_ila_0/probe84 [get_nets [list {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[crc_good]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe85]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe85]
connect_debug_port u_ila_0/probe85 [get_nets [list {espi_spinor_ss/spi_nor_top_inst/spi_txn_mgr_inst/r[csn]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe86]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe86]
connect_debug_port u_ila_0/probe86 [get_nets [list {espi_spinor_ss/espi_target_top_inst/transaction/response_processor_inst/r[cur_valid]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe87]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe87]
connect_debug_port u_ila_0/probe87 [get_nets [list {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[dpr_write_en]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe88]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe88]
connect_debug_port u_ila_0/probe88 [get_nets [list {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[flash_c_avail]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe89]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe89]
connect_debug_port u_ila_0/probe89 [get_nets [list {espi_spinor_ss/espi_target_top_inst/flash_channel_inst/r[flash_np_free]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe90]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe90]
connect_debug_port u_ila_0/probe90 [get_nets [list {espi_spinor_ss/espi_target_top_inst/transaction/response_processor_inst/r[has_responded]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe91]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe91]
connect_debug_port u_ila_0/probe91 [get_nets [list {espi_spinor_ss/espi_target_top_inst/transaction/response_processor_inst/r[is_flash_response]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe92]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe92]
connect_debug_port u_ila_0/probe92 [get_nets [list {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[reset_strobe]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe93]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe93]
connect_debug_port u_ila_0/probe93 [get_nets [list {espi_spinor_ss/espi_target_top_inst/transaction/response_processor_inst/r[resp_ack]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe94]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe94]
connect_debug_port u_ila_0/probe94 [get_nets [list {espi_spinor_ss/espi_target_top_inst/transaction/response_processor_inst/r[response_done]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe95]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe95]
connect_debug_port u_ila_0/probe95 [get_nets [list {espi_spinor_ss/espi_target_top_inst/transaction/response_processor_inst/r[status][flash_c_avail]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe96]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe96]
connect_debug_port u_ila_0/probe96 [get_nets [list {espi_spinor_ss/espi_target_top_inst/transaction/response_processor_inst/r[status][flash_c_free]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe97]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe97]
connect_debug_port u_ila_0/probe97 [get_nets [list {espi_spinor_ss/espi_target_top_inst/transaction/response_processor_inst/r[status][flash_np_avail]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe98]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe98]
connect_debug_port u_ila_0/probe98 [get_nets [list {espi_spinor_ss/espi_target_top_inst/transaction/response_processor_inst/r[status][flash_np_free]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe99]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe99]
connect_debug_port u_ila_0/probe99 [get_nets [list {espi_spinor_ss/espi_target_top_inst/transaction/response_processor_inst/r[status][np_avail]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe100]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe100]
connect_debug_port u_ila_0/probe100 [get_nets [list {espi_spinor_ss/espi_target_top_inst/transaction/response_processor_inst/r[status][np_free]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe101]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe101]
connect_debug_port u_ila_0/probe101 [get_nets [list {espi_spinor_ss/espi_target_top_inst/transaction/response_processor_inst/r[status][oob_avail]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe102]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe102]
connect_debug_port u_ila_0/probe102 [get_nets [list {espi_spinor_ss/espi_target_top_inst/transaction/response_processor_inst/r[status][oob_free]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe103]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe103]
connect_debug_port u_ila_0/probe103 [get_nets [list {espi_spinor_ss/espi_target_top_inst/transaction/response_processor_inst/r[status][pc_avail]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe104]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe104]
connect_debug_port u_ila_0/probe104 [get_nets [list {espi_spinor_ss/espi_target_top_inst/transaction/response_processor_inst/r[status][pc_free]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe105]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe105]
connect_debug_port u_ila_0/probe105 [get_nets [list {espi_spinor_ss/espi_target_top_inst/transaction/response_processor_inst/r[status][vwire_avail]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe106]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe106]
connect_debug_port u_ila_0/probe106 [get_nets [list {espi_spinor_ss/espi_target_top_inst/transaction/response_processor_inst/r[status][vwire_free]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe107]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe107]
connect_debug_port u_ila_0/probe107 [get_nets [list {espi_spinor_ss/espi_target_top_inst/transaction/response_processor_inst/r[status_idx]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe108]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe108]
connect_debug_port u_ila_0/probe108 [get_nets [list {espi_spinor_ss/spi_nor_top_inst/spi_txn_mgr_inst/r[txn][uses_dummys]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe109]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe109]
connect_debug_port u_ila_0/probe109 [get_nets [list {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[valid_redge]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe110]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe110]
connect_debug_port u_ila_0/probe110 [get_nets [list {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[vwire_active]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe111]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe111]
connect_debug_port u_ila_0/probe111 [get_nets [list {espi_spinor_ss/espi_target_top_inst/transaction/command_processor_inst/r[vwire_wstrobe]} ]]
set_property port_width 8 [get_debug_ports u_ila_1/probe0]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe0]
connect_debug_port u_ila_1/probe0 [get_nets [list {espi_spinor_ss/espi_target_top_inst/qspi_link_layer_inst/size_finder/r[hdr][cycle_type][0]} {espi_spinor_ss/espi_target_top_inst/qspi_link_layer_inst/size_finder/r[hdr][cycle_type][1]} {espi_spinor_ss/espi_target_top_inst/qspi_link_layer_inst/size_finder/r[hdr][cycle_type][2]} {espi_spinor_ss/espi_target_top_inst/qspi_link_layer_inst/size_finder/r[hdr][cycle_type][3]} {espi_spinor_ss/espi_target_top_inst/qspi_link_layer_inst/size_finder/r[hdr][cycle_type][4]} {espi_spinor_ss/espi_target_top_inst/qspi_link_layer_inst/size_finder/r[hdr][cycle_type][5]} {espi_spinor_ss/espi_target_top_inst/qspi_link_layer_inst/size_finder/r[hdr][cycle_type][6]} {espi_spinor_ss/espi_target_top_inst/qspi_link_layer_inst/size_finder/r[hdr][cycle_type][7]} ]]
create_debug_port u_ila_1 probe
set_property port_width 12 [get_debug_ports u_ila_1/probe1]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe1]
connect_debug_port u_ila_1/probe1 [get_nets [list {espi_spinor_ss/espi_target_top_inst/qspi_link_layer_inst/size_finder/r[hdr][len][0]} {espi_spinor_ss/espi_target_top_inst/qspi_link_layer_inst/size_finder/r[hdr][len][1]} {espi_spinor_ss/espi_target_top_inst/qspi_link_layer_inst/size_finder/r[hdr][len][2]} {espi_spinor_ss/espi_target_top_inst/qspi_link_layer_inst/size_finder/r[hdr][len][3]} {espi_spinor_ss/espi_target_top_inst/qspi_link_layer_inst/size_finder/r[hdr][len][4]} {espi_spinor_ss/espi_target_top_inst/qspi_link_layer_inst/size_finder/r[hdr][len][5]} {espi_spinor_ss/espi_target_top_inst/qspi_link_layer_inst/size_finder/r[hdr][len][6]} {espi_spinor_ss/espi_target_top_inst/qspi_link_layer_inst/size_finder/r[hdr][len][7]} {espi_spinor_ss/espi_target_top_inst/qspi_link_layer_inst/size_finder/r[hdr][len][8]} {espi_spinor_ss/espi_target_top_inst/qspi_link_layer_inst/size_finder/r[hdr][len][9]} {espi_spinor_ss/espi_target_top_inst/qspi_link_layer_inst/size_finder/r[hdr][len][10]} {espi_spinor_ss/espi_target_top_inst/qspi_link_layer_inst/size_finder/r[hdr][len][11]} ]]
create_debug_port u_ila_1 probe
set_property port_width 3 [get_debug_ports u_ila_1/probe2]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe2]
connect_debug_port u_ila_1/probe2 [get_nets [list {espi_spinor_ss/espi_target_top_inst/qspi_link_layer_inst/size_finder/r[state][0]} {espi_spinor_ss/espi_target_top_inst/qspi_link_layer_inst/size_finder/r[state][1]} {espi_spinor_ss/espi_target_top_inst/qspi_link_layer_inst/size_finder/r[state][2]} ]]
create_debug_port u_ila_1 probe
set_property port_width 8 [get_debug_ports u_ila_1/probe3]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe3]
connect_debug_port u_ila_1/probe3 [get_nets [list {espi_spinor_ss/espi_target_top_inst/qspi_link_layer_inst/size_finder/r[hdr][opcode][0]} {espi_spinor_ss/espi_target_top_inst/qspi_link_layer_inst/size_finder/r[hdr][opcode][1]} {espi_spinor_ss/espi_target_top_inst/qspi_link_layer_inst/size_finder/r[hdr][opcode][2]} {espi_spinor_ss/espi_target_top_inst/qspi_link_layer_inst/size_finder/r[hdr][opcode][3]} {espi_spinor_ss/espi_target_top_inst/qspi_link_layer_inst/size_finder/r[hdr][opcode][4]} {espi_spinor_ss/espi_target_top_inst/qspi_link_layer_inst/size_finder/r[hdr][opcode][5]} {espi_spinor_ss/espi_target_top_inst/qspi_link_layer_inst/size_finder/r[hdr][opcode][6]} {espi_spinor_ss/espi_target_top_inst/qspi_link_layer_inst/size_finder/r[hdr][opcode][7]} ]]
create_debug_port u_ila_1 probe
set_property port_width 13 [get_debug_ports u_ila_1/probe4]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe4]
connect_debug_port u_ila_1/probe4 [get_nets [list {espi_spinor_ss/espi_target_top_inst/qspi_link_layer_inst/size_finder/r[size_info][size][0]} {espi_spinor_ss/espi_target_top_inst/qspi_link_layer_inst/size_finder/r[size_info][size][1]} {espi_spinor_ss/espi_target_top_inst/qspi_link_layer_inst/size_finder/r[size_info][size][2]} {espi_spinor_ss/espi_target_top_inst/qspi_link_layer_inst/size_finder/r[size_info][size][3]} {espi_spinor_ss/espi_target_top_inst/qspi_link_layer_inst/size_finder/r[size_info][size][4]} {espi_spinor_ss/espi_target_top_inst/qspi_link_layer_inst/size_finder/r[size_info][size][5]} {espi_spinor_ss/espi_target_top_inst/qspi_link_layer_inst/size_finder/r[size_info][size][6]} {espi_spinor_ss/espi_target_top_inst/qspi_link_layer_inst/size_finder/r[size_info][size][7]} {espi_spinor_ss/espi_target_top_inst/qspi_link_layer_inst/size_finder/r[size_info][size][8]} {espi_spinor_ss/espi_target_top_inst/qspi_link_layer_inst/size_finder/r[size_info][size][9]} {espi_spinor_ss/espi_target_top_inst/qspi_link_layer_inst/size_finder/r[size_info][size][10]} {espi_spinor_ss/espi_target_top_inst/qspi_link_layer_inst/size_finder/r[size_info][size][11]} {espi_spinor_ss/espi_target_top_inst/qspi_link_layer_inst/size_finder/r[size_info][size][12]} ]]
create_debug_port u_ila_1 probe
set_property port_width 4 [get_debug_ports u_ila_1/probe5]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe5]
connect_debug_port u_ila_1/probe5 [get_nets [list {espi_spinor_ss/espi_target_top_inst/qspi_link_layer_inst/rem_waits[0]} {espi_spinor_ss/espi_target_top_inst/qspi_link_layer_inst/rem_waits[1]} {espi_spinor_ss/espi_target_top_inst/qspi_link_layer_inst/rem_waits[2]} {espi_spinor_ss/espi_target_top_inst/qspi_link_layer_inst/rem_waits[3]} ]]
create_debug_port u_ila_1 probe
set_property port_width 8 [get_debug_ports u_ila_1/probe6]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe6]
connect_debug_port u_ila_1/probe6 [get_nets [list {espi_spinor_ss/espi_target_top_inst/qspi_link_layer_inst/response_post_mux[data][0]} {espi_spinor_ss/espi_target_top_inst/qspi_link_layer_inst/response_post_mux[data][1]} {espi_spinor_ss/espi_target_top_inst/qspi_link_layer_inst/response_post_mux[data][2]} {espi_spinor_ss/espi_target_top_inst/qspi_link_layer_inst/response_post_mux[data][3]} {espi_spinor_ss/espi_target_top_inst/qspi_link_layer_inst/response_post_mux[data][4]} {espi_spinor_ss/espi_target_top_inst/qspi_link_layer_inst/response_post_mux[data][5]} {espi_spinor_ss/espi_target_top_inst/qspi_link_layer_inst/response_post_mux[data][6]} {espi_spinor_ss/espi_target_top_inst/qspi_link_layer_inst/response_post_mux[data][7]} ]]
create_debug_port u_ila_1 probe
set_property port_width 4 [get_debug_ports u_ila_1/probe7]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe7]
connect_debug_port u_ila_1/probe7 [get_nets [list {espi_spinor_ss/espi_target_top_inst/qspi_link_layer_inst/ta_edge_vec[0]} {espi_spinor_ss/espi_target_top_inst/qspi_link_layer_inst/ta_edge_vec[1]} {espi_spinor_ss/espi_target_top_inst/qspi_link_layer_inst/ta_edge_vec[2]} {espi_spinor_ss/espi_target_top_inst/qspi_link_layer_inst/ta_edge_vec[3]} ]]
create_debug_port u_ila_1 probe
set_property port_width 1 [get_debug_ports u_ila_1/probe8]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe8]
connect_debug_port u_ila_1/probe8 [get_nets [list {espi_spinor_ss/espi_target_top_inst/qspi_link_layer_inst/size_finder/r[espi_reset]} ]]
create_debug_port u_ila_1 probe
set_property port_width 1 [get_debug_ports u_ila_1/probe9]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe9]
connect_debug_port u_ila_1/probe9 [get_nets [list {espi_spinor_ss/espi_target_top_inst/qspi_link_layer_inst/size_finder/r[espi_reset_pend]} ]]
create_debug_port u_ila_1 probe
set_property port_width 1 [get_debug_ports u_ila_1/probe10]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe10]
connect_debug_port u_ila_1/probe10 [get_nets [list {espi_spinor_ss/espi_target_top_inst/qspi_link_layer_inst/size_finder/r[size_info][invalid]} ]]
create_debug_port u_ila_1 probe
set_property port_width 1 [get_debug_ports u_ila_1/probe11]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe11]
connect_debug_port u_ila_1/probe11 [get_nets [list {espi_spinor_ss/espi_target_top_inst/qspi_link_layer_inst/size_finder/r[size_info][valid]} ]]
create_debug_port u_ila_1 probe
set_property port_width 1 [get_debug_ports u_ila_1/probe12]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe12]
connect_debug_port u_ila_1/probe12 [get_nets [list espi_spinor_ss/espi_target_top_inst/qspi_link_layer_inst/response_byte_ack ]]
create_debug_port u_ila_1 probe
set_property port_width 1 [get_debug_ports u_ila_1/probe13]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe13]
connect_debug_port u_ila_1/probe13 [get_nets [list {espi_spinor_ss/espi_target_top_inst/qspi_link_layer_inst/response_post_mux[ready]} ]]
create_debug_port u_ila_1 probe
set_property port_width 1 [get_debug_ports u_ila_1/probe14]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe14]
connect_debug_port u_ila_1/probe14 [get_nets [list {espi_spinor_ss/espi_target_top_inst/qspi_link_layer_inst/response_post_mux[valid]} ]]
create_debug_port u_ila_1 probe
set_property port_width 1 [get_debug_ports u_ila_1/probe15]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe15]
connect_debug_port u_ila_1/probe15 [get_nets [list espi_spinor_ss/espi_target_top_inst/qspi_link_layer_inst/send_waits ]]