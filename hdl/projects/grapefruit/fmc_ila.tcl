create_debug_core u_ila_0 ila
set_property C_DATA_DEPTH 4096 [get_debug_cores u_ila_0]
set_property C_TRIGIN_EN false [get_debug_cores u_ila_0]
set_property C_TRIGOUT_EN false [get_debug_cores u_ila_0]
set_property C_ADV_TRIGGER false [get_debug_cores u_ila_0]
set_property C_INPUT_PIPE_STAGES 0 [get_debug_cores u_ila_0]
set_property C_EN_STRG_QUAL false [get_debug_cores u_ila_0]
set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila_0]
set_property ALL_PROBE_SAME_MU_CNT 1 [get_debug_cores u_ila_0]
create_debug_core u_ila_1 ila
set_property C_DATA_DEPTH 4096 [get_debug_cores u_ila_1]
set_property C_TRIGIN_EN false [get_debug_cores u_ila_1]
set_property C_TRIGOUT_EN false [get_debug_cores u_ila_1]
set_property C_ADV_TRIGGER false [get_debug_cores u_ila_1]
set_property C_INPUT_PIPE_STAGES 0 [get_debug_cores u_ila_1]
set_property C_EN_STRG_QUAL false [get_debug_cores u_ila_1]
set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila_1]
set_property ALL_PROBE_SAME_MU_CNT 1 [get_debug_cores u_ila_1]
create_debug_core u_ila_2 ila
set_property C_DATA_DEPTH 4096 [get_debug_cores u_ila_2]
set_property C_TRIGIN_EN false [get_debug_cores u_ila_2]
set_property C_TRIGOUT_EN false [get_debug_cores u_ila_2]
set_property C_ADV_TRIGGER false [get_debug_cores u_ila_2]
set_property C_INPUT_PIPE_STAGES 0 [get_debug_cores u_ila_2]
set_property C_EN_STRG_QUAL false [get_debug_cores u_ila_2]
set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila_2]
set_property ALL_PROBE_SAME_MU_CNT 1 [get_debug_cores u_ila_2]
connect_debug_port u_ila_0/clk [get_nets [list pll/inst/clk_125m ]]
connect_debug_port u_ila_1/clk [get_nets [list pll/inst/clk_200m ]]
connect_debug_port u_ila_2/clk [get_nets [list fmc_sp_to_fpga_clk_IBUF_BUFG ]]
set_property port_width 32 [get_debug_ports u_ila_0/probe0]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe0]
connect_debug_port u_ila_0/probe0 [get_nets [list {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[cur_flash_addr][0]} {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[cur_flash_addr][1]} {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[cur_flash_addr][2]} {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[cur_flash_addr][3]} {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[cur_flash_addr][4]} {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[cur_flash_addr][5]} {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[cur_flash_addr][6]} {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[cur_flash_addr][7]} {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[cur_flash_addr][8]} {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[cur_flash_addr][9]} {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[cur_flash_addr][10]} {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[cur_flash_addr][11]} {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[cur_flash_addr][12]} {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[cur_flash_addr][13]} {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[cur_flash_addr][14]} {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[cur_flash_addr][15]} {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[cur_flash_addr][16]} {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[cur_flash_addr][17]} {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[cur_flash_addr][18]} {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[cur_flash_addr][19]} {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[cur_flash_addr][20]} {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[cur_flash_addr][21]} {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[cur_flash_addr][22]} {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[cur_flash_addr][23]} {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[cur_flash_addr][24]} {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[cur_flash_addr][25]} {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[cur_flash_addr][26]} {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[cur_flash_addr][27]} {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[cur_flash_addr][28]} {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[cur_flash_addr][29]} {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[cur_flash_addr][30]} {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[cur_flash_addr][31]} ]]
create_debug_port u_ila_0 probe
set_property port_width 32 [get_debug_ports u_ila_0/probe1]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe1]
connect_debug_port u_ila_0/probe1 [get_nets [list {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[len][0]} {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[len][1]} {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[len][2]} {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[len][3]} {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[len][4]} {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[len][5]} {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[len][6]} {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[len][7]} {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[len][8]} {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[len][9]} {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[len][10]} {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[len][11]} {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[len][12]} {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[len][13]} {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[len][14]} {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[len][15]} {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[len][16]} {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[len][17]} {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[len][18]} {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[len][19]} {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[len][20]} {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[len][21]} {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[len][22]} {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[len][23]} {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[len][24]} {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[len][25]} {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[len][26]} {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[len][27]} {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[len][28]} {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[len][29]} {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[len][30]} {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[len][31]} ]]
create_debug_port u_ila_0 probe
set_property port_width 9 [get_debug_ports u_ila_0/probe2]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe2]
connect_debug_port u_ila_0/probe2 [get_nets [list {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[data_bytes][0]} {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[data_bytes][1]} {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[data_bytes][2]} {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[data_bytes][3]} {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[data_bytes][4]} {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[data_bytes][5]} {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[data_bytes][6]} {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[data_bytes][7]} {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[data_bytes][8]} ]]
create_debug_port u_ila_0 probe
set_property port_width 9 [get_debug_ports u_ila_0/probe3]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe3]
connect_debug_port u_ila_0/probe3 [get_nets [list {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[dummy_cycles][0]} {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[dummy_cycles][1]} {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[dummy_cycles][2]} {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[dummy_cycles][3]} {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[dummy_cycles][4]} {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[dummy_cycles][5]} {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[dummy_cycles][6]} {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[dummy_cycles][7]} {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[dummy_cycles][8]} ]]
create_debug_port u_ila_0 probe
set_property port_width 32 [get_debug_ports u_ila_0/probe4]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe4]
connect_debug_port u_ila_0/probe4 [get_nets [list {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[next_flash_addr][0]} {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[next_flash_addr][1]} {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[next_flash_addr][2]} {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[next_flash_addr][3]} {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[next_flash_addr][4]} {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[next_flash_addr][5]} {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[next_flash_addr][6]} {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[next_flash_addr][7]} {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[next_flash_addr][8]} {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[next_flash_addr][9]} {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[next_flash_addr][10]} {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[next_flash_addr][11]} {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[next_flash_addr][12]} {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[next_flash_addr][13]} {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[next_flash_addr][14]} {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[next_flash_addr][15]} {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[next_flash_addr][16]} {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[next_flash_addr][17]} {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[next_flash_addr][18]} {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[next_flash_addr][19]} {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[next_flash_addr][20]} {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[next_flash_addr][21]} {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[next_flash_addr][22]} {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[next_flash_addr][23]} {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[next_flash_addr][24]} {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[next_flash_addr][25]} {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[next_flash_addr][26]} {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[next_flash_addr][27]} {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[next_flash_addr][28]} {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[next_flash_addr][29]} {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[next_flash_addr][30]} {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[next_flash_addr][31]} ]]
create_debug_port u_ila_0 probe
set_property port_width 13 [get_debug_ports u_ila_0/probe5]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe5]
connect_debug_port u_ila_0/probe5 [get_nets [list {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[rem_bytes][0]} {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[rem_bytes][1]} {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[rem_bytes][2]} {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[rem_bytes][3]} {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[rem_bytes][4]} {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[rem_bytes][5]} {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[rem_bytes][6]} {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[rem_bytes][7]} {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[rem_bytes][8]} {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[rem_bytes][9]} {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[rem_bytes][10]} {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[rem_bytes][11]} {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[rem_bytes][12]} ]]
create_debug_port u_ila_0 probe
set_property port_width 3 [get_debug_ports u_ila_0/probe6]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe6]
connect_debug_port u_ila_0/probe6 [get_nets [list {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[state][0]} {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[state][1]} {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[state][2]} ]]
create_debug_port u_ila_0 probe
set_property port_width 8 [get_debug_ports u_ila_0/probe7]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe7]
connect_debug_port u_ila_0/probe7 [get_nets [list {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[txn_bytes][0]} {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[txn_bytes][1]} {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[txn_bytes][2]} {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[txn_bytes][3]} {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[txn_bytes][4]} {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[txn_bytes][5]} {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[txn_bytes][6]} {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[txn_bytes][7]} ]]
create_debug_port u_ila_0 probe
set_property port_width 32 [get_debug_ports u_ila_0/probe8]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe8]
connect_debug_port u_ila_0/probe8 [get_nets [list {spi_nor_top_inst/link/dbg_sclk_cnts[0]} {spi_nor_top_inst/link/dbg_sclk_cnts[1]} {spi_nor_top_inst/link/dbg_sclk_cnts[2]} {spi_nor_top_inst/link/dbg_sclk_cnts[3]} {spi_nor_top_inst/link/dbg_sclk_cnts[4]} {spi_nor_top_inst/link/dbg_sclk_cnts[5]} {spi_nor_top_inst/link/dbg_sclk_cnts[6]} {spi_nor_top_inst/link/dbg_sclk_cnts[7]} {spi_nor_top_inst/link/dbg_sclk_cnts[8]} {spi_nor_top_inst/link/dbg_sclk_cnts[9]} {spi_nor_top_inst/link/dbg_sclk_cnts[10]} {spi_nor_top_inst/link/dbg_sclk_cnts[11]} {spi_nor_top_inst/link/dbg_sclk_cnts[12]} {spi_nor_top_inst/link/dbg_sclk_cnts[13]} {spi_nor_top_inst/link/dbg_sclk_cnts[14]} {spi_nor_top_inst/link/dbg_sclk_cnts[15]} {spi_nor_top_inst/link/dbg_sclk_cnts[16]} {spi_nor_top_inst/link/dbg_sclk_cnts[17]} {spi_nor_top_inst/link/dbg_sclk_cnts[18]} {spi_nor_top_inst/link/dbg_sclk_cnts[19]} {spi_nor_top_inst/link/dbg_sclk_cnts[20]} {spi_nor_top_inst/link/dbg_sclk_cnts[21]} {spi_nor_top_inst/link/dbg_sclk_cnts[22]} {spi_nor_top_inst/link/dbg_sclk_cnts[23]} {spi_nor_top_inst/link/dbg_sclk_cnts[24]} {spi_nor_top_inst/link/dbg_sclk_cnts[25]} {spi_nor_top_inst/link/dbg_sclk_cnts[26]} {spi_nor_top_inst/link/dbg_sclk_cnts[27]} {spi_nor_top_inst/link/dbg_sclk_cnts[28]} {spi_nor_top_inst/link/dbg_sclk_cnts[29]} {spi_nor_top_inst/link/dbg_sclk_cnts[30]} {spi_nor_top_inst/link/dbg_sclk_cnts[31]} ]]
create_debug_port u_ila_0 probe
set_property port_width 9 [get_debug_ports u_ila_0/probe9]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe9]
connect_debug_port u_ila_0/probe9 [get_nets [list {spi_nor_top_inst/link/rx_reg[0]} {spi_nor_top_inst/link/rx_reg[1]} {spi_nor_top_inst/link/rx_reg[2]} {spi_nor_top_inst/link/rx_reg[3]} {spi_nor_top_inst/link/rx_reg[4]} {spi_nor_top_inst/link/rx_reg[5]} {spi_nor_top_inst/link/rx_reg[6]} {spi_nor_top_inst/link/rx_reg[7]} {spi_nor_top_inst/link/rx_reg[8]} ]]
create_debug_port u_ila_0 probe
set_property port_width 9 [get_debug_ports u_ila_0/probe10]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe10]
connect_debug_port u_ila_0/probe10 [get_nets [list {spi_nor_top_inst/link/tx_reg[0]} {spi_nor_top_inst/link/tx_reg[1]} {spi_nor_top_inst/link/tx_reg[2]} {spi_nor_top_inst/link/tx_reg[3]} {spi_nor_top_inst/link/tx_reg[4]} {spi_nor_top_inst/link/tx_reg[5]} {spi_nor_top_inst/link/tx_reg[6]} {spi_nor_top_inst/link/tx_reg[7]} {spi_nor_top_inst/link/tx_reg[8]} ]]
create_debug_port u_ila_0 probe
set_property port_width 10 [get_debug_ports u_ila_0/probe11]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe11]
connect_debug_port u_ila_0/probe11 [get_nets [list {spi_nor_top_inst/spi_txn_mgr_inst/r[counter][0]} {spi_nor_top_inst/spi_txn_mgr_inst/r[counter][1]} {spi_nor_top_inst/spi_txn_mgr_inst/r[counter][2]} {spi_nor_top_inst/spi_txn_mgr_inst/r[counter][3]} {spi_nor_top_inst/spi_txn_mgr_inst/r[counter][4]} {spi_nor_top_inst/spi_txn_mgr_inst/r[counter][5]} {spi_nor_top_inst/spi_txn_mgr_inst/r[counter][6]} {spi_nor_top_inst/spi_txn_mgr_inst/r[counter][7]} {spi_nor_top_inst/spi_txn_mgr_inst/r[counter][8]} {spi_nor_top_inst/spi_txn_mgr_inst/r[counter][9]} ]]
create_debug_port u_ila_0 probe
set_property port_width 3 [get_debug_ports u_ila_0/probe12]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe12]
connect_debug_port u_ila_0/probe12 [get_nets [list {spi_nor_top_inst/spi_txn_mgr_inst/r[state][0]} {spi_nor_top_inst/spi_txn_mgr_inst/r[state][1]} {spi_nor_top_inst/spi_txn_mgr_inst/r[state][2]} ]]
create_debug_port u_ila_0 probe
set_property port_width 2 [get_debug_ports u_ila_0/probe13]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe13]
connect_debug_port u_ila_0/probe13 [get_nets [list {spi_nor_top_inst/spi_txn_mgr_inst/r[txn][addr_kind][0]} {spi_nor_top_inst/spi_txn_mgr_inst/r[txn][addr_kind][1]} ]]
create_debug_port u_ila_0 probe
set_property port_width 2 [get_debug_ports u_ila_0/probe14]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe14]
connect_debug_port u_ila_0/probe14 [get_nets [list {spi_nor_top_inst/spi_txn_mgr_inst/r[txn][data_kind][0]} {spi_nor_top_inst/spi_txn_mgr_inst/r[txn][data_kind][1]} ]]
create_debug_port u_ila_0 probe
set_property port_width 2 [get_debug_ports u_ila_0/probe15]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe15]
connect_debug_port u_ila_0/probe15 [get_nets [list {spi_nor_top_inst/spi_txn_mgr_inst/r[txn][data_mode][0]} {spi_nor_top_inst/spi_txn_mgr_inst/r[txn][data_mode][1]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe16]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe16]
connect_debug_port u_ila_0/probe16 [get_nets [list {spi_nor_top_inst/espi_flash_txn_mgr_inst/r[cmd_rdack]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe17]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe17]
connect_debug_port u_ila_0/probe17 [get_nets [list {spi_nor_top_inst/spi_txn_mgr_inst/r[csn]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe18]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe18]
connect_debug_port u_ila_0/probe18 [get_nets [list {spi_nor_top_inst/spi_txn_mgr_inst/r[txn][uses_dummys]} ]]
set_property port_width 8 [get_debug_ports u_ila_1/probe0]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe0]
connect_debug_port u_ila_1/probe0 [get_nets [list {espi_target_top_inst/flash_channel_inst/dpr_wdata[0]} {espi_target_top_inst/flash_channel_inst/dpr_wdata[1]} {espi_target_top_inst/flash_channel_inst/dpr_wdata[2]} {espi_target_top_inst/flash_channel_inst/dpr_wdata[3]} {espi_target_top_inst/flash_channel_inst/dpr_wdata[4]} {espi_target_top_inst/flash_channel_inst/dpr_wdata[5]} {espi_target_top_inst/flash_channel_inst/dpr_wdata[6]} {espi_target_top_inst/flash_channel_inst/dpr_wdata[7]} ]]
create_debug_port u_ila_1 probe
set_property port_width 8 [get_debug_ports u_ila_1/probe1]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe1]
connect_debug_port u_ila_1/probe1 [get_nets [list {espi_target_top_inst/flash_channel_inst/dpr_rdata[0]} {espi_target_top_inst/flash_channel_inst/dpr_rdata[1]} {espi_target_top_inst/flash_channel_inst/dpr_rdata[2]} {espi_target_top_inst/flash_channel_inst/dpr_rdata[3]} {espi_target_top_inst/flash_channel_inst/dpr_rdata[4]} {espi_target_top_inst/flash_channel_inst/dpr_rdata[5]} {espi_target_top_inst/flash_channel_inst/dpr_rdata[6]} {espi_target_top_inst/flash_channel_inst/dpr_rdata[7]} ]]
create_debug_port u_ila_1 probe
set_property port_width 4 [get_debug_ports u_ila_1/probe2]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe2]
connect_debug_port u_ila_1/probe2 [get_nets [list {espi_target_top_inst/flash_channel_inst/r[cmd_queue][0][tag][0]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][0][tag][1]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][0][tag][2]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][0][tag][3]} ]]
create_debug_port u_ila_1 probe
set_property port_width 32 [get_debug_ports u_ila_1/probe3]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe3]
connect_debug_port u_ila_1/probe3 [get_nets [list {espi_target_top_inst/flash_channel_inst/r[cmd_queue][0][sp5_addr][0]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][0][sp5_addr][1]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][0][sp5_addr][2]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][0][sp5_addr][3]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][0][sp5_addr][4]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][0][sp5_addr][5]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][0][sp5_addr][6]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][0][sp5_addr][7]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][0][sp5_addr][8]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][0][sp5_addr][9]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][0][sp5_addr][10]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][0][sp5_addr][11]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][0][sp5_addr][12]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][0][sp5_addr][13]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][0][sp5_addr][14]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][0][sp5_addr][15]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][0][sp5_addr][16]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][0][sp5_addr][17]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][0][sp5_addr][18]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][0][sp5_addr][19]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][0][sp5_addr][20]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][0][sp5_addr][21]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][0][sp5_addr][22]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][0][sp5_addr][23]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][0][sp5_addr][24]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][0][sp5_addr][25]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][0][sp5_addr][26]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][0][sp5_addr][27]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][0][sp5_addr][28]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][0][sp5_addr][29]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][0][sp5_addr][30]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][0][sp5_addr][31]} ]]
create_debug_port u_ila_1 probe
set_property port_width 12 [get_debug_ports u_ila_1/probe4]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe4]
connect_debug_port u_ila_1/probe4 [get_nets [list {espi_target_top_inst/flash_channel_inst/r[cmd_queue][0][ready_bytes][0]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][0][ready_bytes][1]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][0][ready_bytes][2]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][0][ready_bytes][3]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][0][ready_bytes][4]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][0][ready_bytes][5]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][0][ready_bytes][6]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][0][ready_bytes][7]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][0][ready_bytes][8]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][0][ready_bytes][9]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][0][ready_bytes][10]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][0][ready_bytes][11]} ]]
create_debug_port u_ila_1 probe
set_property port_width 12 [get_debug_ports u_ila_1/probe5]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe5]
connect_debug_port u_ila_1/probe5 [get_nets [list {espi_target_top_inst/flash_channel_inst/r[cmd_queue][0][xfr_size_bytes][0]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][0][xfr_size_bytes][1]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][0][xfr_size_bytes][2]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][0][xfr_size_bytes][3]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][0][xfr_size_bytes][4]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][0][xfr_size_bytes][5]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][0][xfr_size_bytes][6]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][0][xfr_size_bytes][7]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][0][xfr_size_bytes][8]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][0][xfr_size_bytes][9]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][0][xfr_size_bytes][10]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][0][xfr_size_bytes][11]} ]]
create_debug_port u_ila_1 probe
set_property port_width 12 [get_debug_ports u_ila_1/probe6]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe6]
connect_debug_port u_ila_1/probe6 [get_nets [list {espi_target_top_inst/flash_channel_inst/r[cmd_queue][1][ready_bytes][0]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][1][ready_bytes][1]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][1][ready_bytes][2]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][1][ready_bytes][3]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][1][ready_bytes][4]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][1][ready_bytes][5]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][1][ready_bytes][6]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][1][ready_bytes][7]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][1][ready_bytes][8]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][1][ready_bytes][9]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][1][ready_bytes][10]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][1][ready_bytes][11]} ]]
create_debug_port u_ila_1 probe
set_property port_width 32 [get_debug_ports u_ila_1/probe7]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe7]
connect_debug_port u_ila_1/probe7 [get_nets [list {espi_target_top_inst/flash_channel_inst/r[cmd_queue][1][sp5_addr][0]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][1][sp5_addr][1]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][1][sp5_addr][2]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][1][sp5_addr][3]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][1][sp5_addr][4]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][1][sp5_addr][5]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][1][sp5_addr][6]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][1][sp5_addr][7]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][1][sp5_addr][8]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][1][sp5_addr][9]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][1][sp5_addr][10]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][1][sp5_addr][11]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][1][sp5_addr][12]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][1][sp5_addr][13]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][1][sp5_addr][14]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][1][sp5_addr][15]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][1][sp5_addr][16]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][1][sp5_addr][17]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][1][sp5_addr][18]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][1][sp5_addr][19]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][1][sp5_addr][20]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][1][sp5_addr][21]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][1][sp5_addr][22]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][1][sp5_addr][23]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][1][sp5_addr][24]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][1][sp5_addr][25]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][1][sp5_addr][26]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][1][sp5_addr][27]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][1][sp5_addr][28]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][1][sp5_addr][29]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][1][sp5_addr][30]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][1][sp5_addr][31]} ]]
create_debug_port u_ila_1 probe
set_property port_width 4 [get_debug_ports u_ila_1/probe8]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe8]
connect_debug_port u_ila_1/probe8 [get_nets [list {espi_target_top_inst/flash_channel_inst/r[cmd_queue][1][tag][0]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][1][tag][1]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][1][tag][2]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][1][tag][3]} ]]
create_debug_port u_ila_1 probe
set_property port_width 12 [get_debug_ports u_ila_1/probe9]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe9]
connect_debug_port u_ila_1/probe9 [get_nets [list {espi_target_top_inst/flash_channel_inst/r[cmd_queue][1][xfr_size_bytes][0]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][1][xfr_size_bytes][1]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][1][xfr_size_bytes][2]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][1][xfr_size_bytes][3]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][1][xfr_size_bytes][4]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][1][xfr_size_bytes][5]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][1][xfr_size_bytes][6]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][1][xfr_size_bytes][7]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][1][xfr_size_bytes][8]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][1][xfr_size_bytes][9]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][1][xfr_size_bytes][10]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][1][xfr_size_bytes][11]} ]]
create_debug_port u_ila_1 probe
set_property port_width 12 [get_debug_ports u_ila_1/probe10]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe10]
connect_debug_port u_ila_1/probe10 [get_nets [list {espi_target_top_inst/flash_channel_inst/r[cmd_queue][2][ready_bytes][0]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][2][ready_bytes][1]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][2][ready_bytes][2]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][2][ready_bytes][3]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][2][ready_bytes][4]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][2][ready_bytes][5]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][2][ready_bytes][6]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][2][ready_bytes][7]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][2][ready_bytes][8]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][2][ready_bytes][9]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][2][ready_bytes][10]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][2][ready_bytes][11]} ]]
create_debug_port u_ila_1 probe
set_property port_width 32 [get_debug_ports u_ila_1/probe11]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe11]
connect_debug_port u_ila_1/probe11 [get_nets [list {espi_target_top_inst/flash_channel_inst/r[cmd_queue][2][sp5_addr][0]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][2][sp5_addr][1]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][2][sp5_addr][2]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][2][sp5_addr][3]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][2][sp5_addr][4]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][2][sp5_addr][5]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][2][sp5_addr][6]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][2][sp5_addr][7]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][2][sp5_addr][8]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][2][sp5_addr][9]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][2][sp5_addr][10]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][2][sp5_addr][11]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][2][sp5_addr][12]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][2][sp5_addr][13]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][2][sp5_addr][14]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][2][sp5_addr][15]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][2][sp5_addr][16]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][2][sp5_addr][17]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][2][sp5_addr][18]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][2][sp5_addr][19]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][2][sp5_addr][20]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][2][sp5_addr][21]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][2][sp5_addr][22]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][2][sp5_addr][23]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][2][sp5_addr][24]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][2][sp5_addr][25]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][2][sp5_addr][26]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][2][sp5_addr][27]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][2][sp5_addr][28]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][2][sp5_addr][29]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][2][sp5_addr][30]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][2][sp5_addr][31]} ]]
create_debug_port u_ila_1 probe
set_property port_width 4 [get_debug_ports u_ila_1/probe12]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe12]
connect_debug_port u_ila_1/probe12 [get_nets [list {espi_target_top_inst/flash_channel_inst/r[cmd_queue][2][tag][0]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][2][tag][1]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][2][tag][2]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][2][tag][3]} ]]
create_debug_port u_ila_1 probe
set_property port_width 12 [get_debug_ports u_ila_1/probe13]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe13]
connect_debug_port u_ila_1/probe13 [get_nets [list {espi_target_top_inst/flash_channel_inst/r[cmd_queue][2][xfr_size_bytes][0]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][2][xfr_size_bytes][1]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][2][xfr_size_bytes][2]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][2][xfr_size_bytes][3]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][2][xfr_size_bytes][4]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][2][xfr_size_bytes][5]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][2][xfr_size_bytes][6]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][2][xfr_size_bytes][7]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][2][xfr_size_bytes][8]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][2][xfr_size_bytes][9]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][2][xfr_size_bytes][10]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][2][xfr_size_bytes][11]} ]]
create_debug_port u_ila_1 probe
set_property port_width 12 [get_debug_ports u_ila_1/probe14]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe14]
connect_debug_port u_ila_1/probe14 [get_nets [list {espi_target_top_inst/flash_channel_inst/r[cmd_queue][3][ready_bytes][0]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][3][ready_bytes][1]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][3][ready_bytes][2]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][3][ready_bytes][3]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][3][ready_bytes][4]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][3][ready_bytes][5]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][3][ready_bytes][6]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][3][ready_bytes][7]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][3][ready_bytes][8]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][3][ready_bytes][9]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][3][ready_bytes][10]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][3][ready_bytes][11]} ]]
create_debug_port u_ila_1 probe
set_property port_width 32 [get_debug_ports u_ila_1/probe15]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe15]
connect_debug_port u_ila_1/probe15 [get_nets [list {espi_target_top_inst/flash_channel_inst/r[cmd_queue][3][sp5_addr][0]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][3][sp5_addr][1]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][3][sp5_addr][2]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][3][sp5_addr][3]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][3][sp5_addr][4]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][3][sp5_addr][5]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][3][sp5_addr][6]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][3][sp5_addr][7]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][3][sp5_addr][8]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][3][sp5_addr][9]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][3][sp5_addr][10]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][3][sp5_addr][11]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][3][sp5_addr][12]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][3][sp5_addr][13]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][3][sp5_addr][14]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][3][sp5_addr][15]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][3][sp5_addr][16]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][3][sp5_addr][17]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][3][sp5_addr][18]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][3][sp5_addr][19]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][3][sp5_addr][20]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][3][sp5_addr][21]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][3][sp5_addr][22]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][3][sp5_addr][23]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][3][sp5_addr][24]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][3][sp5_addr][25]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][3][sp5_addr][26]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][3][sp5_addr][27]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][3][sp5_addr][28]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][3][sp5_addr][29]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][3][sp5_addr][30]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][3][sp5_addr][31]} ]]
create_debug_port u_ila_1 probe
set_property port_width 4 [get_debug_ports u_ila_1/probe16]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe16]
connect_debug_port u_ila_1/probe16 [get_nets [list {espi_target_top_inst/flash_channel_inst/r[cmd_queue][3][tag][0]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][3][tag][1]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][3][tag][2]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][3][tag][3]} ]]
create_debug_port u_ila_1 probe
set_property port_width 12 [get_debug_ports u_ila_1/probe17]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe17]
connect_debug_port u_ila_1/probe17 [get_nets [list {espi_target_top_inst/flash_channel_inst/r[cmd_queue][3][xfr_size_bytes][0]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][3][xfr_size_bytes][1]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][3][xfr_size_bytes][2]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][3][xfr_size_bytes][3]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][3][xfr_size_bytes][4]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][3][xfr_size_bytes][5]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][3][xfr_size_bytes][6]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][3][xfr_size_bytes][7]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][3][xfr_size_bytes][8]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][3][xfr_size_bytes][9]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][3][xfr_size_bytes][10]} {espi_target_top_inst/flash_channel_inst/r[cmd_queue][3][xfr_size_bytes][11]} ]]
create_debug_port u_ila_1 probe
set_property port_width 11 [get_debug_ports u_ila_1/probe18]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe18]
connect_debug_port u_ila_1/probe18 [get_nets [list {espi_target_top_inst/flash_channel_inst/r[compl_side_cntr][0]} {espi_target_top_inst/flash_channel_inst/r[compl_side_cntr][1]} {espi_target_top_inst/flash_channel_inst/r[compl_side_cntr][2]} {espi_target_top_inst/flash_channel_inst/r[compl_side_cntr][3]} {espi_target_top_inst/flash_channel_inst/r[compl_side_cntr][4]} {espi_target_top_inst/flash_channel_inst/r[compl_side_cntr][5]} {espi_target_top_inst/flash_channel_inst/r[compl_side_cntr][6]} {espi_target_top_inst/flash_channel_inst/r[compl_side_cntr][7]} {espi_target_top_inst/flash_channel_inst/r[compl_side_cntr][8]} {espi_target_top_inst/flash_channel_inst/r[compl_side_cntr][9]} {espi_target_top_inst/flash_channel_inst/r[compl_side_cntr][10]} ]]
create_debug_port u_ila_1 probe
set_property port_width 2 [get_debug_ports u_ila_1/probe19]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe19]
connect_debug_port u_ila_1/probe19 [get_nets [list {espi_target_top_inst/flash_channel_inst/r[flash_cmd_state][0]} {espi_target_top_inst/flash_channel_inst/r[flash_cmd_state][1]} ]]
create_debug_port u_ila_1 probe
set_property port_width 11 [get_debug_ports u_ila_1/probe20]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe20]
connect_debug_port u_ila_1/probe20 [get_nets [list {espi_target_top_inst/flash_channel_inst/r[flash_side_cntr][0]} {espi_target_top_inst/flash_channel_inst/r[flash_side_cntr][1]} {espi_target_top_inst/flash_channel_inst/r[flash_side_cntr][2]} {espi_target_top_inst/flash_channel_inst/r[flash_side_cntr][3]} {espi_target_top_inst/flash_channel_inst/r[flash_side_cntr][4]} {espi_target_top_inst/flash_channel_inst/r[flash_side_cntr][5]} {espi_target_top_inst/flash_channel_inst/r[flash_side_cntr][6]} {espi_target_top_inst/flash_channel_inst/r[flash_side_cntr][7]} {espi_target_top_inst/flash_channel_inst/r[flash_side_cntr][8]} {espi_target_top_inst/flash_channel_inst/r[flash_side_cntr][9]} {espi_target_top_inst/flash_channel_inst/r[flash_side_cntr][10]} ]]
create_debug_port u_ila_1 probe
set_property port_width 11 [get_debug_ports u_ila_1/probe21]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe21]
connect_debug_port u_ila_1/probe21 [get_nets [list {espi_target_top_inst/flash_channel_inst/r[flash_write_addr_offset][0]} {espi_target_top_inst/flash_channel_inst/r[flash_write_addr_offset][1]} {espi_target_top_inst/flash_channel_inst/r[flash_write_addr_offset][2]} {espi_target_top_inst/flash_channel_inst/r[flash_write_addr_offset][3]} {espi_target_top_inst/flash_channel_inst/r[flash_write_addr_offset][4]} {espi_target_top_inst/flash_channel_inst/r[flash_write_addr_offset][5]} {espi_target_top_inst/flash_channel_inst/r[flash_write_addr_offset][6]} {espi_target_top_inst/flash_channel_inst/r[flash_write_addr_offset][7]} {espi_target_top_inst/flash_channel_inst/r[flash_write_addr_offset][8]} {espi_target_top_inst/flash_channel_inst/r[flash_write_addr_offset][9]} {espi_target_top_inst/flash_channel_inst/r[flash_write_addr_offset][10]} ]]
create_debug_port u_ila_1 probe
set_property port_width 2 [get_debug_ports u_ila_1/probe22]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe22]
connect_debug_port u_ila_1/probe22 [get_nets [list {espi_target_top_inst/flash_channel_inst/r[head_desc][0]} {espi_target_top_inst/flash_channel_inst/r[head_desc][1]} ]]
create_debug_port u_ila_1 probe
set_property port_width 2 [get_debug_ports u_ila_1/probe23]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe23]
connect_debug_port u_ila_1/probe23 [get_nets [list {espi_target_top_inst/flash_channel_inst/r[issue_desc][0]} {espi_target_top_inst/flash_channel_inst/r[issue_desc][1]} ]]
create_debug_port u_ila_1 probe
set_property port_width 2 [get_debug_ports u_ila_1/probe24]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe24]
connect_debug_port u_ila_1/probe24 [get_nets [list {espi_target_top_inst/flash_channel_inst/r[tail_desc][0]} {espi_target_top_inst/flash_channel_inst/r[tail_desc][1]} ]]
create_debug_port u_ila_1 probe
set_property port_width 8 [get_debug_ports u_ila_1/probe25]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe25]
connect_debug_port u_ila_1/probe25 [get_nets [list {espi_target_top_inst/transaction/command_processor_inst/r[vwire_idx][0]} {espi_target_top_inst/transaction/command_processor_inst/r[vwire_idx][1]} {espi_target_top_inst/transaction/command_processor_inst/r[vwire_idx][2]} {espi_target_top_inst/transaction/command_processor_inst/r[vwire_idx][3]} {espi_target_top_inst/transaction/command_processor_inst/r[vwire_idx][4]} {espi_target_top_inst/transaction/command_processor_inst/r[vwire_idx][5]} {espi_target_top_inst/transaction/command_processor_inst/r[vwire_idx][6]} {espi_target_top_inst/transaction/command_processor_inst/r[vwire_idx][7]} ]]
create_debug_port u_ila_1 probe
set_property port_width 16 [get_debug_ports u_ila_1/probe26]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe26]
connect_debug_port u_ila_1/probe26 [get_nets [list {espi_target_top_inst/transaction/command_processor_inst/r[cfg_addr][0]} {espi_target_top_inst/transaction/command_processor_inst/r[cfg_addr][1]} {espi_target_top_inst/transaction/command_processor_inst/r[cfg_addr][2]} {espi_target_top_inst/transaction/command_processor_inst/r[cfg_addr][3]} {espi_target_top_inst/transaction/command_processor_inst/r[cfg_addr][4]} {espi_target_top_inst/transaction/command_processor_inst/r[cfg_addr][5]} {espi_target_top_inst/transaction/command_processor_inst/r[cfg_addr][6]} {espi_target_top_inst/transaction/command_processor_inst/r[cfg_addr][7]} {espi_target_top_inst/transaction/command_processor_inst/r[cfg_addr][8]} {espi_target_top_inst/transaction/command_processor_inst/r[cfg_addr][9]} {espi_target_top_inst/transaction/command_processor_inst/r[cfg_addr][10]} {espi_target_top_inst/transaction/command_processor_inst/r[cfg_addr][11]} {espi_target_top_inst/transaction/command_processor_inst/r[cfg_addr][12]} {espi_target_top_inst/transaction/command_processor_inst/r[cfg_addr][13]} {espi_target_top_inst/transaction/command_processor_inst/r[cfg_addr][14]} {espi_target_top_inst/transaction/command_processor_inst/r[cfg_addr][15]} ]]
create_debug_port u_ila_1 probe
set_property port_width 32 [get_debug_ports u_ila_1/probe27]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe27]
connect_debug_port u_ila_1/probe27 [get_nets [list {espi_target_top_inst/transaction/command_processor_inst/r[cfg_data][0]} {espi_target_top_inst/transaction/command_processor_inst/r[cfg_data][1]} {espi_target_top_inst/transaction/command_processor_inst/r[cfg_data][2]} {espi_target_top_inst/transaction/command_processor_inst/r[cfg_data][3]} {espi_target_top_inst/transaction/command_processor_inst/r[cfg_data][4]} {espi_target_top_inst/transaction/command_processor_inst/r[cfg_data][5]} {espi_target_top_inst/transaction/command_processor_inst/r[cfg_data][6]} {espi_target_top_inst/transaction/command_processor_inst/r[cfg_data][7]} {espi_target_top_inst/transaction/command_processor_inst/r[cfg_data][8]} {espi_target_top_inst/transaction/command_processor_inst/r[cfg_data][9]} {espi_target_top_inst/transaction/command_processor_inst/r[cfg_data][10]} {espi_target_top_inst/transaction/command_processor_inst/r[cfg_data][11]} {espi_target_top_inst/transaction/command_processor_inst/r[cfg_data][12]} {espi_target_top_inst/transaction/command_processor_inst/r[cfg_data][13]} {espi_target_top_inst/transaction/command_processor_inst/r[cfg_data][14]} {espi_target_top_inst/transaction/command_processor_inst/r[cfg_data][15]} {espi_target_top_inst/transaction/command_processor_inst/r[cfg_data][16]} {espi_target_top_inst/transaction/command_processor_inst/r[cfg_data][17]} {espi_target_top_inst/transaction/command_processor_inst/r[cfg_data][18]} {espi_target_top_inst/transaction/command_processor_inst/r[cfg_data][19]} {espi_target_top_inst/transaction/command_processor_inst/r[cfg_data][20]} {espi_target_top_inst/transaction/command_processor_inst/r[cfg_data][21]} {espi_target_top_inst/transaction/command_processor_inst/r[cfg_data][22]} {espi_target_top_inst/transaction/command_processor_inst/r[cfg_data][23]} {espi_target_top_inst/transaction/command_processor_inst/r[cfg_data][24]} {espi_target_top_inst/transaction/command_processor_inst/r[cfg_data][25]} {espi_target_top_inst/transaction/command_processor_inst/r[cfg_data][26]} {espi_target_top_inst/transaction/command_processor_inst/r[cfg_data][27]} {espi_target_top_inst/transaction/command_processor_inst/r[cfg_data][28]} {espi_target_top_inst/transaction/command_processor_inst/r[cfg_data][29]} {espi_target_top_inst/transaction/command_processor_inst/r[cfg_data][30]} {espi_target_top_inst/transaction/command_processor_inst/r[cfg_data][31]} ]]
create_debug_port u_ila_1 probe
set_property port_width 32 [get_debug_ports u_ila_1/probe28]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe28]
connect_debug_port u_ila_1/probe28 [get_nets [list {espi_target_top_inst/transaction/command_processor_inst/r[ch_addr][0]} {espi_target_top_inst/transaction/command_processor_inst/r[ch_addr][1]} {espi_target_top_inst/transaction/command_processor_inst/r[ch_addr][2]} {espi_target_top_inst/transaction/command_processor_inst/r[ch_addr][3]} {espi_target_top_inst/transaction/command_processor_inst/r[ch_addr][4]} {espi_target_top_inst/transaction/command_processor_inst/r[ch_addr][5]} {espi_target_top_inst/transaction/command_processor_inst/r[ch_addr][6]} {espi_target_top_inst/transaction/command_processor_inst/r[ch_addr][7]} {espi_target_top_inst/transaction/command_processor_inst/r[ch_addr][8]} {espi_target_top_inst/transaction/command_processor_inst/r[ch_addr][9]} {espi_target_top_inst/transaction/command_processor_inst/r[ch_addr][10]} {espi_target_top_inst/transaction/command_processor_inst/r[ch_addr][11]} {espi_target_top_inst/transaction/command_processor_inst/r[ch_addr][12]} {espi_target_top_inst/transaction/command_processor_inst/r[ch_addr][13]} {espi_target_top_inst/transaction/command_processor_inst/r[ch_addr][14]} {espi_target_top_inst/transaction/command_processor_inst/r[ch_addr][15]} {espi_target_top_inst/transaction/command_processor_inst/r[ch_addr][16]} {espi_target_top_inst/transaction/command_processor_inst/r[ch_addr][17]} {espi_target_top_inst/transaction/command_processor_inst/r[ch_addr][18]} {espi_target_top_inst/transaction/command_processor_inst/r[ch_addr][19]} {espi_target_top_inst/transaction/command_processor_inst/r[ch_addr][20]} {espi_target_top_inst/transaction/command_processor_inst/r[ch_addr][21]} {espi_target_top_inst/transaction/command_processor_inst/r[ch_addr][22]} {espi_target_top_inst/transaction/command_processor_inst/r[ch_addr][23]} {espi_target_top_inst/transaction/command_processor_inst/r[ch_addr][24]} {espi_target_top_inst/transaction/command_processor_inst/r[ch_addr][25]} {espi_target_top_inst/transaction/command_processor_inst/r[ch_addr][26]} {espi_target_top_inst/transaction/command_processor_inst/r[ch_addr][27]} {espi_target_top_inst/transaction/command_processor_inst/r[ch_addr][28]} {espi_target_top_inst/transaction/command_processor_inst/r[ch_addr][29]} {espi_target_top_inst/transaction/command_processor_inst/r[ch_addr][30]} {espi_target_top_inst/transaction/command_processor_inst/r[ch_addr][31]} ]]
create_debug_port u_ila_1 probe
set_property port_width 8 [get_debug_ports u_ila_1/probe29]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe29]
connect_debug_port u_ila_1/probe29 [get_nets [list {espi_target_top_inst/transaction/command_processor_inst/r[cmd_header][opcode][value][0]} {espi_target_top_inst/transaction/command_processor_inst/r[cmd_header][opcode][value][1]} {espi_target_top_inst/transaction/command_processor_inst/r[cmd_header][opcode][value][2]} {espi_target_top_inst/transaction/command_processor_inst/r[cmd_header][opcode][value][3]} {espi_target_top_inst/transaction/command_processor_inst/r[cmd_header][opcode][value][4]} {espi_target_top_inst/transaction/command_processor_inst/r[cmd_header][opcode][value][5]} {espi_target_top_inst/transaction/command_processor_inst/r[cmd_header][opcode][value][6]} {espi_target_top_inst/transaction/command_processor_inst/r[cmd_header][opcode][value][7]} ]]
create_debug_port u_ila_1 probe
set_property port_width 8 [get_debug_ports u_ila_1/probe30]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe30]
connect_debug_port u_ila_1/probe30 [get_nets [list {espi_target_top_inst/transaction/command_processor_inst/r[cmd_header][cycle_kind][0]} {espi_target_top_inst/transaction/command_processor_inst/r[cmd_header][cycle_kind][1]} {espi_target_top_inst/transaction/command_processor_inst/r[cmd_header][cycle_kind][2]} {espi_target_top_inst/transaction/command_processor_inst/r[cmd_header][cycle_kind][3]} {espi_target_top_inst/transaction/command_processor_inst/r[cmd_header][cycle_kind][4]} {espi_target_top_inst/transaction/command_processor_inst/r[cmd_header][cycle_kind][5]} {espi_target_top_inst/transaction/command_processor_inst/r[cmd_header][cycle_kind][6]} {espi_target_top_inst/transaction/command_processor_inst/r[cmd_header][cycle_kind][7]} ]]
create_debug_port u_ila_1 probe
set_property port_width 12 [get_debug_ports u_ila_1/probe31]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe31]
connect_debug_port u_ila_1/probe31 [get_nets [list {espi_target_top_inst/transaction/command_processor_inst/r[cmd_header][length][0]} {espi_target_top_inst/transaction/command_processor_inst/r[cmd_header][length][1]} {espi_target_top_inst/transaction/command_processor_inst/r[cmd_header][length][2]} {espi_target_top_inst/transaction/command_processor_inst/r[cmd_header][length][3]} {espi_target_top_inst/transaction/command_processor_inst/r[cmd_header][length][4]} {espi_target_top_inst/transaction/command_processor_inst/r[cmd_header][length][5]} {espi_target_top_inst/transaction/command_processor_inst/r[cmd_header][length][6]} {espi_target_top_inst/transaction/command_processor_inst/r[cmd_header][length][7]} {espi_target_top_inst/transaction/command_processor_inst/r[cmd_header][length][8]} {espi_target_top_inst/transaction/command_processor_inst/r[cmd_header][length][9]} {espi_target_top_inst/transaction/command_processor_inst/r[cmd_header][length][10]} {espi_target_top_inst/transaction/command_processor_inst/r[cmd_header][length][11]} ]]
create_debug_port u_ila_1 probe
set_property port_width 4 [get_debug_ports u_ila_1/probe32]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe32]
connect_debug_port u_ila_1/probe32 [get_nets [list {espi_target_top_inst/transaction/command_processor_inst/r[cmd_header][tag][0]} {espi_target_top_inst/transaction/command_processor_inst/r[cmd_header][tag][1]} {espi_target_top_inst/transaction/command_processor_inst/r[cmd_header][tag][2]} {espi_target_top_inst/transaction/command_processor_inst/r[cmd_header][tag][3]} ]]
create_debug_port u_ila_1 probe
set_property port_width 3 [get_debug_ports u_ila_1/probe33]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe33]
connect_debug_port u_ila_1/probe33 [get_nets [list {espi_target_top_inst/transaction/command_processor_inst/r[hdr_idx][0]} {espi_target_top_inst/transaction/command_processor_inst/r[hdr_idx][1]} {espi_target_top_inst/transaction/command_processor_inst/r[hdr_idx][2]} ]]
create_debug_port u_ila_1 probe
set_property port_width 3 [get_debug_ports u_ila_1/probe34]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe34]
connect_debug_port u_ila_1/probe34 [get_nets [list {espi_target_top_inst/transaction/command_processor_inst/r[rem_addr_bytes][0]} {espi_target_top_inst/transaction/command_processor_inst/r[rem_addr_bytes][1]} {espi_target_top_inst/transaction/command_processor_inst/r[rem_addr_bytes][2]} ]]
create_debug_port u_ila_1 probe
set_property port_width 12 [get_debug_ports u_ila_1/probe35]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe35]
connect_debug_port u_ila_1/probe35 [get_nets [list {espi_target_top_inst/transaction/command_processor_inst/r[rem_data_bytes][0]} {espi_target_top_inst/transaction/command_processor_inst/r[rem_data_bytes][1]} {espi_target_top_inst/transaction/command_processor_inst/r[rem_data_bytes][2]} {espi_target_top_inst/transaction/command_processor_inst/r[rem_data_bytes][3]} {espi_target_top_inst/transaction/command_processor_inst/r[rem_data_bytes][4]} {espi_target_top_inst/transaction/command_processor_inst/r[rem_data_bytes][5]} {espi_target_top_inst/transaction/command_processor_inst/r[rem_data_bytes][6]} {espi_target_top_inst/transaction/command_processor_inst/r[rem_data_bytes][7]} {espi_target_top_inst/transaction/command_processor_inst/r[rem_data_bytes][8]} {espi_target_top_inst/transaction/command_processor_inst/r[rem_data_bytes][9]} {espi_target_top_inst/transaction/command_processor_inst/r[rem_data_bytes][10]} {espi_target_top_inst/transaction/command_processor_inst/r[rem_data_bytes][11]} ]]
create_debug_port u_ila_1 probe
set_property port_width 4 [get_debug_ports u_ila_1/probe36]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe36]
connect_debug_port u_ila_1/probe36 [get_nets [list {espi_target_top_inst/transaction/command_processor_inst/r[state][0]} {espi_target_top_inst/transaction/command_processor_inst/r[state][1]} {espi_target_top_inst/transaction/command_processor_inst/r[state][2]} {espi_target_top_inst/transaction/command_processor_inst/r[state][3]} ]]
create_debug_port u_ila_1 probe
set_property port_width 8 [get_debug_ports u_ila_1/probe37]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe37]
connect_debug_port u_ila_1/probe37 [get_nets [list {espi_target_top_inst/transaction/command_processor_inst/r[vwire_dat][0]} {espi_target_top_inst/transaction/command_processor_inst/r[vwire_dat][1]} {espi_target_top_inst/transaction/command_processor_inst/r[vwire_dat][2]} {espi_target_top_inst/transaction/command_processor_inst/r[vwire_dat][3]} {espi_target_top_inst/transaction/command_processor_inst/r[vwire_dat][4]} {espi_target_top_inst/transaction/command_processor_inst/r[vwire_dat][5]} {espi_target_top_inst/transaction/command_processor_inst/r[vwire_dat][6]} {espi_target_top_inst/transaction/command_processor_inst/r[vwire_dat][7]} ]]
create_debug_port u_ila_1 probe
set_property port_width 4 [get_debug_ports u_ila_1/probe38]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe38]
connect_debug_port u_ila_1/probe38 [get_nets [list {espi_target_top_inst/link_layer_top_inst/qspi_link_layer/io[0]} {espi_target_top_inst/link_layer_top_inst/qspi_link_layer/io[1]} {espi_target_top_inst/link_layer_top_inst/qspi_link_layer/io[2]} {espi_target_top_inst/link_layer_top_inst/qspi_link_layer/io[3]} ]]
create_debug_port u_ila_1 probe
set_property port_width 4 [get_debug_ports u_ila_1/probe39]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe39]
connect_debug_port u_ila_1/probe39 [get_nets [list {espi_target_top_inst/link_layer_top_inst/qspi_link_layer/io_o[0]} {espi_target_top_inst/link_layer_top_inst/qspi_link_layer/io_o[1]} {espi_target_top_inst/link_layer_top_inst/qspi_link_layer/io_o[2]} {espi_target_top_inst/link_layer_top_inst/qspi_link_layer/io_o[3]} ]]
create_debug_port u_ila_1 probe
set_property port_width 9 [get_debug_ports u_ila_1/probe40]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe40]
connect_debug_port u_ila_1/probe40 [get_nets [list {espi_target_top_inst/link_layer_top_inst/qspi_link_layer/rx_reg[0]} {espi_target_top_inst/link_layer_top_inst/qspi_link_layer/rx_reg[1]} {espi_target_top_inst/link_layer_top_inst/qspi_link_layer/rx_reg[2]} {espi_target_top_inst/link_layer_top_inst/qspi_link_layer/rx_reg[3]} {espi_target_top_inst/link_layer_top_inst/qspi_link_layer/rx_reg[4]} {espi_target_top_inst/link_layer_top_inst/qspi_link_layer/rx_reg[5]} {espi_target_top_inst/link_layer_top_inst/qspi_link_layer/rx_reg[6]} {espi_target_top_inst/link_layer_top_inst/qspi_link_layer/rx_reg[7]} {espi_target_top_inst/link_layer_top_inst/qspi_link_layer/rx_reg[8]} ]]
create_debug_port u_ila_1 probe
set_property port_width 4 [get_debug_ports u_ila_1/probe41]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe41]
connect_debug_port u_ila_1/probe41 [get_nets [list {espi_target_top_inst/link_layer_top_inst/qspi_link_layer/io_oe[0]} {espi_target_top_inst/link_layer_top_inst/qspi_link_layer/io_oe[1]} {espi_target_top_inst/link_layer_top_inst/qspi_link_layer/io_oe[2]} {espi_target_top_inst/link_layer_top_inst/qspi_link_layer/io_oe[3]} ]]
create_debug_port u_ila_1 probe
set_property port_width 9 [get_debug_ports u_ila_1/probe42]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe42]
connect_debug_port u_ila_1/probe42 [get_nets [list {espi_target_top_inst/link_layer_top_inst/qspi_link_layer/tx_reg[0]} {espi_target_top_inst/link_layer_top_inst/qspi_link_layer/tx_reg[1]} {espi_target_top_inst/link_layer_top_inst/qspi_link_layer/tx_reg[2]} {espi_target_top_inst/link_layer_top_inst/qspi_link_layer/tx_reg[3]} {espi_target_top_inst/link_layer_top_inst/qspi_link_layer/tx_reg[4]} {espi_target_top_inst/link_layer_top_inst/qspi_link_layer/tx_reg[5]} {espi_target_top_inst/link_layer_top_inst/qspi_link_layer/tx_reg[6]} {espi_target_top_inst/link_layer_top_inst/qspi_link_layer/tx_reg[7]} {espi_target_top_inst/link_layer_top_inst/qspi_link_layer/tx_reg[8]} ]]
create_debug_port u_ila_1 probe
set_property port_width 1 [get_debug_ports u_ila_1/probe43]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe43]
connect_debug_port u_ila_1/probe43 [get_nets [list espi_target_top_inst/link_layer_top_inst/qspi_link_layer/cs_n ]]
create_debug_port u_ila_1 probe
set_property port_width 1 [get_debug_ports u_ila_1/probe44]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe44]
connect_debug_port u_ila_1/probe44 [get_nets [list espi_target_top_inst/flash_channel_inst/dpr_read_ack ]]
create_debug_port u_ila_1 probe
set_property port_width 1 [get_debug_ports u_ila_1/probe45]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe45]
connect_debug_port u_ila_1/probe45 [get_nets [list espi_target_top_inst/flash_channel_inst/dpr_wr_delay ]]
create_debug_port u_ila_1 probe
set_property port_width 1 [get_debug_ports u_ila_1/probe46]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe46]
connect_debug_port u_ila_1/probe46 [get_nets [list {espi_target_top_inst/transaction/command_processor_inst/r[cmd_header][opcode][valid]} ]]
create_debug_port u_ila_1 probe
set_property port_width 1 [get_debug_ports u_ila_1/probe47]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe47]
connect_debug_port u_ila_1/probe47 [get_nets [list {espi_target_top_inst/transaction/command_processor_inst/r[cmd_header][valid]} ]]
create_debug_port u_ila_1 probe
set_property port_width 1 [get_debug_ports u_ila_1/probe48]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe48]
connect_debug_port u_ila_1/probe48 [get_nets [list {espi_target_top_inst/flash_channel_inst/r[cmd_queue][0][active]} ]]
create_debug_port u_ila_1 probe
set_property port_width 1 [get_debug_ports u_ila_1/probe49]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe49]
connect_debug_port u_ila_1/probe49 [get_nets [list {espi_target_top_inst/flash_channel_inst/r[cmd_queue][0][done]} ]]
create_debug_port u_ila_1 probe
set_property port_width 1 [get_debug_ports u_ila_1/probe50]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe50]
connect_debug_port u_ila_1/probe50 [get_nets [list {espi_target_top_inst/flash_channel_inst/r[cmd_queue][0][flash_issued]} ]]
create_debug_port u_ila_1 probe
set_property port_width 1 [get_debug_ports u_ila_1/probe51]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe51]
connect_debug_port u_ila_1/probe51 [get_nets [list {espi_target_top_inst/flash_channel_inst/r[cmd_queue][1][active]} ]]
create_debug_port u_ila_1 probe
set_property port_width 1 [get_debug_ports u_ila_1/probe52]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe52]
connect_debug_port u_ila_1/probe52 [get_nets [list {espi_target_top_inst/flash_channel_inst/r[cmd_queue][1][done]} ]]
create_debug_port u_ila_1 probe
set_property port_width 1 [get_debug_ports u_ila_1/probe53]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe53]
connect_debug_port u_ila_1/probe53 [get_nets [list {espi_target_top_inst/flash_channel_inst/r[cmd_queue][1][flash_issued]} ]]
create_debug_port u_ila_1 probe
set_property port_width 1 [get_debug_ports u_ila_1/probe54]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe54]
connect_debug_port u_ila_1/probe54 [get_nets [list {espi_target_top_inst/flash_channel_inst/r[cmd_queue][2][active]} ]]
create_debug_port u_ila_1 probe
set_property port_width 1 [get_debug_ports u_ila_1/probe55]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe55]
connect_debug_port u_ila_1/probe55 [get_nets [list {espi_target_top_inst/flash_channel_inst/r[cmd_queue][2][done]} ]]
create_debug_port u_ila_1 probe
set_property port_width 1 [get_debug_ports u_ila_1/probe56]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe56]
connect_debug_port u_ila_1/probe56 [get_nets [list {espi_target_top_inst/flash_channel_inst/r[cmd_queue][2][flash_issued]} ]]
create_debug_port u_ila_1 probe
set_property port_width 1 [get_debug_ports u_ila_1/probe57]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe57]
connect_debug_port u_ila_1/probe57 [get_nets [list {espi_target_top_inst/flash_channel_inst/r[cmd_queue][3][active]} ]]
create_debug_port u_ila_1 probe
set_property port_width 1 [get_debug_ports u_ila_1/probe58]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe58]
connect_debug_port u_ila_1/probe58 [get_nets [list {espi_target_top_inst/flash_channel_inst/r[cmd_queue][3][done]} ]]
create_debug_port u_ila_1 probe
set_property port_width 1 [get_debug_ports u_ila_1/probe59]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe59]
connect_debug_port u_ila_1/probe59 [get_nets [list {espi_target_top_inst/flash_channel_inst/r[cmd_queue][3][flash_issued]} ]]
create_debug_port u_ila_1 probe
set_property port_width 1 [get_debug_ports u_ila_1/probe60]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe60]
connect_debug_port u_ila_1/probe60 [get_nets [list {espi_target_top_inst/flash_channel_inst/r[compl_state]} ]]
create_debug_port u_ila_1 probe
set_property port_width 1 [get_debug_ports u_ila_1/probe61]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe61]
connect_debug_port u_ila_1/probe61 [get_nets [list {espi_target_top_inst/transaction/command_processor_inst/r[crc_bad]} ]]
create_debug_port u_ila_1 probe
set_property port_width 1 [get_debug_ports u_ila_1/probe62]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe62]
connect_debug_port u_ila_1/probe62 [get_nets [list {espi_target_top_inst/transaction/command_processor_inst/r[crc_good]} ]]
create_debug_port u_ila_1 probe
set_property port_width 1 [get_debug_ports u_ila_1/probe63]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe63]
connect_debug_port u_ila_1/probe63 [get_nets [list {espi_target_top_inst/flash_channel_inst/r[dpr_write_en]} ]]
create_debug_port u_ila_1 probe
set_property port_width 1 [get_debug_ports u_ila_1/probe64]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe64]
connect_debug_port u_ila_1/probe64 [get_nets [list {espi_target_top_inst/flash_channel_inst/r[flash_c_avail]} ]]
create_debug_port u_ila_1 probe
set_property port_width 1 [get_debug_ports u_ila_1/probe65]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe65]
connect_debug_port u_ila_1/probe65 [get_nets [list {espi_target_top_inst/flash_channel_inst/r[flash_np_free]} ]]
create_debug_port u_ila_1 probe
set_property port_width 1 [get_debug_ports u_ila_1/probe66]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe66]
connect_debug_port u_ila_1/probe66 [get_nets [list {espi_target_top_inst/transaction/command_processor_inst/r[reset_strobe]} ]]
create_debug_port u_ila_1 probe
set_property port_width 1 [get_debug_ports u_ila_1/probe67]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe67]
connect_debug_port u_ila_1/probe67 [get_nets [list {espi_target_top_inst/transaction/command_processor_inst/r[valid_redge]} ]]
create_debug_port u_ila_1 probe
set_property port_width 1 [get_debug_ports u_ila_1/probe68]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe68]
connect_debug_port u_ila_1/probe68 [get_nets [list {espi_target_top_inst/transaction/command_processor_inst/r[vwire_active]} ]]
create_debug_port u_ila_1 probe
set_property port_width 1 [get_debug_ports u_ila_1/probe69]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe69]
connect_debug_port u_ila_1/probe69 [get_nets [list {espi_target_top_inst/transaction/command_processor_inst/r[vwire_wstrobe]} ]]
create_debug_port u_ila_1 probe
set_property port_width 1 [get_debug_ports u_ila_1/probe70]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe70]
connect_debug_port u_ila_1/probe70 [get_nets [list espi_target_top_inst/link_layer_top_inst/qspi_link_layer/sclk ]]
set_property port_width 4 [get_debug_ports u_ila_2/probe0]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_2/probe0]
connect_debug_port u_ila_2/probe0 [get_nets [list {stm32h7_fmc_target_inst/fmc_state[0]} {stm32h7_fmc_target_inst/fmc_state[1]} {stm32h7_fmc_target_inst/fmc_state[2]} {stm32h7_fmc_target_inst/fmc_state[3]} ]]
create_debug_port u_ila_2 probe
set_property port_width 26 [get_debug_ports u_ila_2/probe1]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_2/probe1]
connect_debug_port u_ila_2/probe1 [get_nets [list {stm32h7_fmc_target_inst/txn[addr][0]} {stm32h7_fmc_target_inst/txn[addr][1]} {stm32h7_fmc_target_inst/txn[addr][2]} {stm32h7_fmc_target_inst/txn[addr][3]} {stm32h7_fmc_target_inst/txn[addr][4]} {stm32h7_fmc_target_inst/txn[addr][5]} {stm32h7_fmc_target_inst/txn[addr][6]} {stm32h7_fmc_target_inst/txn[addr][7]} {stm32h7_fmc_target_inst/txn[addr][8]} {stm32h7_fmc_target_inst/txn[addr][9]} {stm32h7_fmc_target_inst/txn[addr][10]} {stm32h7_fmc_target_inst/txn[addr][11]} {stm32h7_fmc_target_inst/txn[addr][12]} {stm32h7_fmc_target_inst/txn[addr][13]} {stm32h7_fmc_target_inst/txn[addr][14]} {stm32h7_fmc_target_inst/txn[addr][15]} {stm32h7_fmc_target_inst/txn[addr][16]} {stm32h7_fmc_target_inst/txn[addr][17]} {stm32h7_fmc_target_inst/txn[addr][18]} {stm32h7_fmc_target_inst/txn[addr][19]} {stm32h7_fmc_target_inst/txn[addr][20]} {stm32h7_fmc_target_inst/txn[addr][21]} {stm32h7_fmc_target_inst/txn[addr][22]} {stm32h7_fmc_target_inst/txn[addr][23]} {stm32h7_fmc_target_inst/txn[addr][24]} {stm32h7_fmc_target_inst/txn[addr][25]} ]]
create_debug_port u_ila_2 probe
set_property port_width 1 [get_debug_ports u_ila_2/probe2]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_2/probe2]
connect_debug_port u_ila_2/probe2 [get_nets [list {stm32h7_fmc_target_inst/txn[read_not_write]} ]]