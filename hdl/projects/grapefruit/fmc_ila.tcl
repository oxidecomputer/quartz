create_debug_core u_ila_0 ila
set_property C_DATA_DEPTH 4096 [get_debug_cores u_ila_0]
set_property C_TRIGIN_EN false [get_debug_cores u_ila_0]
set_property C_TRIGOUT_EN false [get_debug_cores u_ila_0]
set_property C_ADV_TRIGGER false [get_debug_cores u_ila_0]
set_property C_INPUT_PIPE_STAGES 0 [get_debug_cores u_ila_0]
set_property C_EN_STRG_QUAL false [get_debug_cores u_ila_0]
set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila_0]
set_property ALL_PROBE_SAME_MU_CNT 1 [get_debug_cores u_ila_0]
connect_debug_port u_ila_0/clk [get_nets [list pll/inst/clk_200m ]]
set_property port_width 4 [get_debug_ports u_ila_0/probe0]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe0]
connect_debug_port u_ila_0/probe0 [get_nets [list {espi_target_top_inst/link_layer_top_inst/qspi_link_layer/io[0]} {espi_target_top_inst/link_layer_top_inst/qspi_link_layer/io[1]} {espi_target_top_inst/link_layer_top_inst/qspi_link_layer/io[2]} {espi_target_top_inst/link_layer_top_inst/qspi_link_layer/io[3]} ]]
create_debug_port u_ila_0 probe
set_property port_width 4 [get_debug_ports u_ila_0/probe1]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe1]
connect_debug_port u_ila_0/probe1 [get_nets [list {espi_target_top_inst/link_layer_top_inst/qspi_link_layer/io_o[0]} {espi_target_top_inst/link_layer_top_inst/qspi_link_layer/io_o[1]} {espi_target_top_inst/link_layer_top_inst/qspi_link_layer/io_o[2]} {espi_target_top_inst/link_layer_top_inst/qspi_link_layer/io_o[3]} ]]
create_debug_port u_ila_0 probe
set_property port_width 4 [get_debug_ports u_ila_0/probe2]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe2]
connect_debug_port u_ila_0/probe2 [get_nets [list {espi_target_top_inst/link_layer_top_inst/qspi_link_layer/io_oe[0]} {espi_target_top_inst/link_layer_top_inst/qspi_link_layer/io_oe[1]} {espi_target_top_inst/link_layer_top_inst/qspi_link_layer/io_oe[2]} {espi_target_top_inst/link_layer_top_inst/qspi_link_layer/io_oe[3]} ]]
create_debug_port u_ila_0 probe
set_property port_width 9 [get_debug_ports u_ila_0/probe3]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe3]
connect_debug_port u_ila_0/probe3 [get_nets [list {espi_target_top_inst/link_layer_top_inst/qspi_link_layer/tx_reg[0]} {espi_target_top_inst/link_layer_top_inst/qspi_link_layer/tx_reg[1]} {espi_target_top_inst/link_layer_top_inst/qspi_link_layer/tx_reg[2]} {espi_target_top_inst/link_layer_top_inst/qspi_link_layer/tx_reg[3]} {espi_target_top_inst/link_layer_top_inst/qspi_link_layer/tx_reg[4]} {espi_target_top_inst/link_layer_top_inst/qspi_link_layer/tx_reg[5]} {espi_target_top_inst/link_layer_top_inst/qspi_link_layer/tx_reg[6]} {espi_target_top_inst/link_layer_top_inst/qspi_link_layer/tx_reg[7]} {espi_target_top_inst/link_layer_top_inst/qspi_link_layer/tx_reg[8]} ]]
create_debug_port u_ila_0 probe
set_property port_width 9 [get_debug_ports u_ila_0/probe4]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe4]
connect_debug_port u_ila_0/probe4 [get_nets [list {espi_target_top_inst/link_layer_top_inst/qspi_link_layer/rx_reg[0]} {espi_target_top_inst/link_layer_top_inst/qspi_link_layer/rx_reg[1]} {espi_target_top_inst/link_layer_top_inst/qspi_link_layer/rx_reg[2]} {espi_target_top_inst/link_layer_top_inst/qspi_link_layer/rx_reg[3]} {espi_target_top_inst/link_layer_top_inst/qspi_link_layer/rx_reg[4]} {espi_target_top_inst/link_layer_top_inst/qspi_link_layer/rx_reg[5]} {espi_target_top_inst/link_layer_top_inst/qspi_link_layer/rx_reg[6]} {espi_target_top_inst/link_layer_top_inst/qspi_link_layer/rx_reg[7]} {espi_target_top_inst/link_layer_top_inst/qspi_link_layer/rx_reg[8]} ]]
create_debug_port u_ila_0 probe
set_property port_width 16 [get_debug_ports u_ila_0/probe5]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe5]
connect_debug_port u_ila_0/probe5 [get_nets [list {espi_target_top_inst/transaction/command_processor_inst/r[cfg_addr][0]} {espi_target_top_inst/transaction/command_processor_inst/r[cfg_addr][1]} {espi_target_top_inst/transaction/command_processor_inst/r[cfg_addr][2]} {espi_target_top_inst/transaction/command_processor_inst/r[cfg_addr][3]} {espi_target_top_inst/transaction/command_processor_inst/r[cfg_addr][4]} {espi_target_top_inst/transaction/command_processor_inst/r[cfg_addr][5]} {espi_target_top_inst/transaction/command_processor_inst/r[cfg_addr][6]} {espi_target_top_inst/transaction/command_processor_inst/r[cfg_addr][7]} {espi_target_top_inst/transaction/command_processor_inst/r[cfg_addr][8]} {espi_target_top_inst/transaction/command_processor_inst/r[cfg_addr][9]} {espi_target_top_inst/transaction/command_processor_inst/r[cfg_addr][10]} {espi_target_top_inst/transaction/command_processor_inst/r[cfg_addr][11]} {espi_target_top_inst/transaction/command_processor_inst/r[cfg_addr][12]} {espi_target_top_inst/transaction/command_processor_inst/r[cfg_addr][13]} {espi_target_top_inst/transaction/command_processor_inst/r[cfg_addr][14]} {espi_target_top_inst/transaction/command_processor_inst/r[cfg_addr][15]} ]]
create_debug_port u_ila_0 probe
set_property port_width 32 [get_debug_ports u_ila_0/probe6]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe6]
connect_debug_port u_ila_0/probe6 [get_nets [list {espi_target_top_inst/transaction/command_processor_inst/r[cfg_data][0]} {espi_target_top_inst/transaction/command_processor_inst/r[cfg_data][1]} {espi_target_top_inst/transaction/command_processor_inst/r[cfg_data][2]} {espi_target_top_inst/transaction/command_processor_inst/r[cfg_data][3]} {espi_target_top_inst/transaction/command_processor_inst/r[cfg_data][4]} {espi_target_top_inst/transaction/command_processor_inst/r[cfg_data][5]} {espi_target_top_inst/transaction/command_processor_inst/r[cfg_data][6]} {espi_target_top_inst/transaction/command_processor_inst/r[cfg_data][7]} {espi_target_top_inst/transaction/command_processor_inst/r[cfg_data][8]} {espi_target_top_inst/transaction/command_processor_inst/r[cfg_data][9]} {espi_target_top_inst/transaction/command_processor_inst/r[cfg_data][10]} {espi_target_top_inst/transaction/command_processor_inst/r[cfg_data][11]} {espi_target_top_inst/transaction/command_processor_inst/r[cfg_data][12]} {espi_target_top_inst/transaction/command_processor_inst/r[cfg_data][13]} {espi_target_top_inst/transaction/command_processor_inst/r[cfg_data][14]} {espi_target_top_inst/transaction/command_processor_inst/r[cfg_data][15]} {espi_target_top_inst/transaction/command_processor_inst/r[cfg_data][16]} {espi_target_top_inst/transaction/command_processor_inst/r[cfg_data][17]} {espi_target_top_inst/transaction/command_processor_inst/r[cfg_data][18]} {espi_target_top_inst/transaction/command_processor_inst/r[cfg_data][19]} {espi_target_top_inst/transaction/command_processor_inst/r[cfg_data][20]} {espi_target_top_inst/transaction/command_processor_inst/r[cfg_data][21]} {espi_target_top_inst/transaction/command_processor_inst/r[cfg_data][22]} {espi_target_top_inst/transaction/command_processor_inst/r[cfg_data][23]} {espi_target_top_inst/transaction/command_processor_inst/r[cfg_data][24]} {espi_target_top_inst/transaction/command_processor_inst/r[cfg_data][25]} {espi_target_top_inst/transaction/command_processor_inst/r[cfg_data][26]} {espi_target_top_inst/transaction/command_processor_inst/r[cfg_data][27]} {espi_target_top_inst/transaction/command_processor_inst/r[cfg_data][28]} {espi_target_top_inst/transaction/command_processor_inst/r[cfg_data][29]} {espi_target_top_inst/transaction/command_processor_inst/r[cfg_data][30]} {espi_target_top_inst/transaction/command_processor_inst/r[cfg_data][31]} ]]
create_debug_port u_ila_0 probe
set_property port_width 32 [get_debug_ports u_ila_0/probe7]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe7]
connect_debug_port u_ila_0/probe7 [get_nets [list {espi_target_top_inst/transaction/command_processor_inst/r[ch_addr][0]} {espi_target_top_inst/transaction/command_processor_inst/r[ch_addr][1]} {espi_target_top_inst/transaction/command_processor_inst/r[ch_addr][2]} {espi_target_top_inst/transaction/command_processor_inst/r[ch_addr][3]} {espi_target_top_inst/transaction/command_processor_inst/r[ch_addr][4]} {espi_target_top_inst/transaction/command_processor_inst/r[ch_addr][5]} {espi_target_top_inst/transaction/command_processor_inst/r[ch_addr][6]} {espi_target_top_inst/transaction/command_processor_inst/r[ch_addr][7]} {espi_target_top_inst/transaction/command_processor_inst/r[ch_addr][8]} {espi_target_top_inst/transaction/command_processor_inst/r[ch_addr][9]} {espi_target_top_inst/transaction/command_processor_inst/r[ch_addr][10]} {espi_target_top_inst/transaction/command_processor_inst/r[ch_addr][11]} {espi_target_top_inst/transaction/command_processor_inst/r[ch_addr][12]} {espi_target_top_inst/transaction/command_processor_inst/r[ch_addr][13]} {espi_target_top_inst/transaction/command_processor_inst/r[ch_addr][14]} {espi_target_top_inst/transaction/command_processor_inst/r[ch_addr][15]} {espi_target_top_inst/transaction/command_processor_inst/r[ch_addr][16]} {espi_target_top_inst/transaction/command_processor_inst/r[ch_addr][17]} {espi_target_top_inst/transaction/command_processor_inst/r[ch_addr][18]} {espi_target_top_inst/transaction/command_processor_inst/r[ch_addr][19]} {espi_target_top_inst/transaction/command_processor_inst/r[ch_addr][20]} {espi_target_top_inst/transaction/command_processor_inst/r[ch_addr][21]} {espi_target_top_inst/transaction/command_processor_inst/r[ch_addr][22]} {espi_target_top_inst/transaction/command_processor_inst/r[ch_addr][23]} {espi_target_top_inst/transaction/command_processor_inst/r[ch_addr][24]} {espi_target_top_inst/transaction/command_processor_inst/r[ch_addr][25]} {espi_target_top_inst/transaction/command_processor_inst/r[ch_addr][26]} {espi_target_top_inst/transaction/command_processor_inst/r[ch_addr][27]} {espi_target_top_inst/transaction/command_processor_inst/r[ch_addr][28]} {espi_target_top_inst/transaction/command_processor_inst/r[ch_addr][29]} {espi_target_top_inst/transaction/command_processor_inst/r[ch_addr][30]} {espi_target_top_inst/transaction/command_processor_inst/r[ch_addr][31]} ]]
create_debug_port u_ila_0 probe
set_property port_width 8 [get_debug_ports u_ila_0/probe8]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe8]
connect_debug_port u_ila_0/probe8 [get_nets [list {espi_target_top_inst/transaction/command_processor_inst/r[cmd_header][opcode][value][0]} {espi_target_top_inst/transaction/command_processor_inst/r[cmd_header][opcode][value][1]} {espi_target_top_inst/transaction/command_processor_inst/r[cmd_header][opcode][value][2]} {espi_target_top_inst/transaction/command_processor_inst/r[cmd_header][opcode][value][3]} {espi_target_top_inst/transaction/command_processor_inst/r[cmd_header][opcode][value][4]} {espi_target_top_inst/transaction/command_processor_inst/r[cmd_header][opcode][value][5]} {espi_target_top_inst/transaction/command_processor_inst/r[cmd_header][opcode][value][6]} {espi_target_top_inst/transaction/command_processor_inst/r[cmd_header][opcode][value][7]} ]]
create_debug_port u_ila_0 probe
set_property port_width 8 [get_debug_ports u_ila_0/probe9]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe9]
connect_debug_port u_ila_0/probe9 [get_nets [list {espi_target_top_inst/transaction/command_processor_inst/r[cmd_header][cycle_kind][0]} {espi_target_top_inst/transaction/command_processor_inst/r[cmd_header][cycle_kind][1]} {espi_target_top_inst/transaction/command_processor_inst/r[cmd_header][cycle_kind][2]} {espi_target_top_inst/transaction/command_processor_inst/r[cmd_header][cycle_kind][3]} {espi_target_top_inst/transaction/command_processor_inst/r[cmd_header][cycle_kind][4]} {espi_target_top_inst/transaction/command_processor_inst/r[cmd_header][cycle_kind][5]} {espi_target_top_inst/transaction/command_processor_inst/r[cmd_header][cycle_kind][6]} {espi_target_top_inst/transaction/command_processor_inst/r[cmd_header][cycle_kind][7]} ]]
create_debug_port u_ila_0 probe
set_property port_width 12 [get_debug_ports u_ila_0/probe10]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe10]
connect_debug_port u_ila_0/probe10 [get_nets [list {espi_target_top_inst/transaction/command_processor_inst/r[cmd_header][length][0]} {espi_target_top_inst/transaction/command_processor_inst/r[cmd_header][length][1]} {espi_target_top_inst/transaction/command_processor_inst/r[cmd_header][length][2]} {espi_target_top_inst/transaction/command_processor_inst/r[cmd_header][length][3]} {espi_target_top_inst/transaction/command_processor_inst/r[cmd_header][length][4]} {espi_target_top_inst/transaction/command_processor_inst/r[cmd_header][length][5]} {espi_target_top_inst/transaction/command_processor_inst/r[cmd_header][length][6]} {espi_target_top_inst/transaction/command_processor_inst/r[cmd_header][length][7]} {espi_target_top_inst/transaction/command_processor_inst/r[cmd_header][length][8]} {espi_target_top_inst/transaction/command_processor_inst/r[cmd_header][length][9]} {espi_target_top_inst/transaction/command_processor_inst/r[cmd_header][length][10]} {espi_target_top_inst/transaction/command_processor_inst/r[cmd_header][length][11]} ]]
create_debug_port u_ila_0 probe
set_property port_width 4 [get_debug_ports u_ila_0/probe11]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe11]
connect_debug_port u_ila_0/probe11 [get_nets [list {espi_target_top_inst/transaction/command_processor_inst/r[cmd_header][tag][0]} {espi_target_top_inst/transaction/command_processor_inst/r[cmd_header][tag][1]} {espi_target_top_inst/transaction/command_processor_inst/r[cmd_header][tag][2]} {espi_target_top_inst/transaction/command_processor_inst/r[cmd_header][tag][3]} ]]
create_debug_port u_ila_0 probe
set_property port_width 3 [get_debug_ports u_ila_0/probe12]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe12]
connect_debug_port u_ila_0/probe12 [get_nets [list {espi_target_top_inst/transaction/command_processor_inst/r[hdr_idx][0]} {espi_target_top_inst/transaction/command_processor_inst/r[hdr_idx][1]} {espi_target_top_inst/transaction/command_processor_inst/r[hdr_idx][2]} ]]
create_debug_port u_ila_0 probe
set_property port_width 3 [get_debug_ports u_ila_0/probe13]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe13]
connect_debug_port u_ila_0/probe13 [get_nets [list {espi_target_top_inst/transaction/command_processor_inst/r[rem_addr_bytes][0]} {espi_target_top_inst/transaction/command_processor_inst/r[rem_addr_bytes][1]} {espi_target_top_inst/transaction/command_processor_inst/r[rem_addr_bytes][2]} ]]
create_debug_port u_ila_0 probe
set_property port_width 12 [get_debug_ports u_ila_0/probe14]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe14]
connect_debug_port u_ila_0/probe14 [get_nets [list {espi_target_top_inst/transaction/command_processor_inst/r[rem_data_bytes][0]} {espi_target_top_inst/transaction/command_processor_inst/r[rem_data_bytes][1]} {espi_target_top_inst/transaction/command_processor_inst/r[rem_data_bytes][2]} {espi_target_top_inst/transaction/command_processor_inst/r[rem_data_bytes][3]} {espi_target_top_inst/transaction/command_processor_inst/r[rem_data_bytes][4]} {espi_target_top_inst/transaction/command_processor_inst/r[rem_data_bytes][5]} {espi_target_top_inst/transaction/command_processor_inst/r[rem_data_bytes][6]} {espi_target_top_inst/transaction/command_processor_inst/r[rem_data_bytes][7]} {espi_target_top_inst/transaction/command_processor_inst/r[rem_data_bytes][8]} {espi_target_top_inst/transaction/command_processor_inst/r[rem_data_bytes][9]} {espi_target_top_inst/transaction/command_processor_inst/r[rem_data_bytes][10]} {espi_target_top_inst/transaction/command_processor_inst/r[rem_data_bytes][11]} ]]
create_debug_port u_ila_0 probe
set_property port_width 4 [get_debug_ports u_ila_0/probe15]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe15]
connect_debug_port u_ila_0/probe15 [get_nets [list {espi_target_top_inst/transaction/command_processor_inst/r[state][0]} {espi_target_top_inst/transaction/command_processor_inst/r[state][1]} {espi_target_top_inst/transaction/command_processor_inst/r[state][2]} {espi_target_top_inst/transaction/command_processor_inst/r[state][3]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe16]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe16]
connect_debug_port u_ila_0/probe16 [get_nets [list espi_target_top_inst/link_layer_top_inst/qspi_link_layer/cs_n ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe17]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe17]
connect_debug_port u_ila_0/probe17 [get_nets [list {espi_target_top_inst/transaction/command_processor_inst/r[cmd_header][opcode][valid]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe18]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe18]
connect_debug_port u_ila_0/probe18 [get_nets [list {espi_target_top_inst/transaction/command_processor_inst/r[cmd_header][valid]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe19]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe19]
connect_debug_port u_ila_0/probe19 [get_nets [list {espi_target_top_inst/transaction/command_processor_inst/r[crc_bad]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe20]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe20]
connect_debug_port u_ila_0/probe20 [get_nets [list {espi_target_top_inst/transaction/command_processor_inst/r[crc_good]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe21]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe21]
connect_debug_port u_ila_0/probe21 [get_nets [list {espi_target_top_inst/transaction/command_processor_inst/r[reset_strobe]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe22]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe22]
connect_debug_port u_ila_0/probe22 [get_nets [list {espi_target_top_inst/transaction/command_processor_inst/r[valid_redge]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe23]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe23]
connect_debug_port u_ila_0/probe23 [get_nets [list espi_target_top_inst/link_layer_top_inst/qspi_link_layer/sclk ]]