create_debug_core u_ila_0 ila
set_property C_DATA_DEPTH 8192 [get_debug_cores u_ila_0]
set_property C_TRIGIN_EN false [get_debug_cores u_ila_0]
set_property C_TRIGOUT_EN false [get_debug_cores u_ila_0]
set_property C_ADV_TRIGGER false [get_debug_cores u_ila_0]
set_property C_INPUT_PIPE_STAGES 0 [get_debug_cores u_ila_0]
set_property C_EN_STRG_QUAL false [get_debug_cores u_ila_0]
set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila_0]
set_property ALL_PROBE_SAME_MU_CNT 1 [get_debug_cores u_ila_0]
startgroup 
set_property C_EN_STRG_QUAL true [get_debug_cores u_ila_0 ]
set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila_0 ]
set_property ALL_PROBE_SAME_MU_CNT 2 [get_debug_cores u_ila_0 ]
endgroup
create_debug_core u_ila_1 ila
set_property C_DATA_DEPTH 8192 [get_debug_cores u_ila_1]
set_property C_TRIGIN_EN false [get_debug_cores u_ila_1]
set_property C_TRIGOUT_EN false [get_debug_cores u_ila_1]
set_property C_ADV_TRIGGER false [get_debug_cores u_ila_1]
set_property C_INPUT_PIPE_STAGES 0 [get_debug_cores u_ila_1]
set_property C_EN_STRG_QUAL false [get_debug_cores u_ila_1]
set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila_1]
set_property ALL_PROBE_SAME_MU_CNT 1 [get_debug_cores u_ila_1]
startgroup 
set_property C_EN_STRG_QUAL true [get_debug_cores u_ila_1 ]
set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila_1 ]
set_property ALL_PROBE_SAME_MU_CNT 2 [get_debug_cores u_ila_1 ]
endgroup
connect_debug_port u_ila_0/clk [get_nets [list pll/inst/clk_125m ]]
connect_debug_port u_ila_1/clk [get_nets [list fmc_sp_to_fpga_clk_IBUF_BUFG ]]
set_property port_width 9 [get_debug_ports u_ila_0/probe0]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe0]
connect_debug_port u_ila_0/probe0 [get_nets [list {spi_nor_top_inst/link/tx_reg[0]} {spi_nor_top_inst/link/tx_reg[1]} {spi_nor_top_inst/link/tx_reg[2]} {spi_nor_top_inst/link/tx_reg[3]} {spi_nor_top_inst/link/tx_reg[4]} {spi_nor_top_inst/link/tx_reg[5]} {spi_nor_top_inst/link/tx_reg[6]} {spi_nor_top_inst/link/tx_reg[7]} {spi_nor_top_inst/link/tx_reg[8]} ]]
create_debug_port u_ila_0 probe
set_property port_width 9 [get_debug_ports u_ila_0/probe1]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe1]
connect_debug_port u_ila_0/probe1 [get_nets [list {spi_nor_top_inst/link/rx_reg[0]} {spi_nor_top_inst/link/rx_reg[1]} {spi_nor_top_inst/link/rx_reg[2]} {spi_nor_top_inst/link/rx_reg[3]} {spi_nor_top_inst/link/rx_reg[4]} {spi_nor_top_inst/link/rx_reg[5]} {spi_nor_top_inst/link/rx_reg[6]} {spi_nor_top_inst/link/rx_reg[7]} {spi_nor_top_inst/link/rx_reg[8]} ]]
create_debug_port u_ila_0 probe
set_property port_width 9 [get_debug_ports u_ila_0/probe2]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe2]
connect_debug_port u_ila_0/probe2 [get_nets [list {spi_nor_top_inst/spi_txn_mgr_inst/spi_cmd[data_bytes][0]} {spi_nor_top_inst/spi_txn_mgr_inst/spi_cmd[data_bytes][1]} {spi_nor_top_inst/spi_txn_mgr_inst/spi_cmd[data_bytes][2]} {spi_nor_top_inst/spi_txn_mgr_inst/spi_cmd[data_bytes][3]} {spi_nor_top_inst/spi_txn_mgr_inst/spi_cmd[data_bytes][4]} {spi_nor_top_inst/spi_txn_mgr_inst/spi_cmd[data_bytes][5]} {spi_nor_top_inst/spi_txn_mgr_inst/spi_cmd[data_bytes][6]} {spi_nor_top_inst/spi_txn_mgr_inst/spi_cmd[data_bytes][7]} {spi_nor_top_inst/spi_txn_mgr_inst/spi_cmd[data_bytes][8]} ]]
create_debug_port u_ila_0 probe
set_property port_width 32 [get_debug_ports u_ila_0/probe3]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe3]
connect_debug_port u_ila_0/probe3 [get_nets [list {spi_nor_top_inst/spi_txn_mgr_inst/spi_cmd[addr][0]} {spi_nor_top_inst/spi_txn_mgr_inst/spi_cmd[addr][1]} {spi_nor_top_inst/spi_txn_mgr_inst/spi_cmd[addr][2]} {spi_nor_top_inst/spi_txn_mgr_inst/spi_cmd[addr][3]} {spi_nor_top_inst/spi_txn_mgr_inst/spi_cmd[addr][4]} {spi_nor_top_inst/spi_txn_mgr_inst/spi_cmd[addr][5]} {spi_nor_top_inst/spi_txn_mgr_inst/spi_cmd[addr][6]} {spi_nor_top_inst/spi_txn_mgr_inst/spi_cmd[addr][7]} {spi_nor_top_inst/spi_txn_mgr_inst/spi_cmd[addr][8]} {spi_nor_top_inst/spi_txn_mgr_inst/spi_cmd[addr][9]} {spi_nor_top_inst/spi_txn_mgr_inst/spi_cmd[addr][10]} {spi_nor_top_inst/spi_txn_mgr_inst/spi_cmd[addr][11]} {spi_nor_top_inst/spi_txn_mgr_inst/spi_cmd[addr][12]} {spi_nor_top_inst/spi_txn_mgr_inst/spi_cmd[addr][13]} {spi_nor_top_inst/spi_txn_mgr_inst/spi_cmd[addr][14]} {spi_nor_top_inst/spi_txn_mgr_inst/spi_cmd[addr][15]} {spi_nor_top_inst/spi_txn_mgr_inst/spi_cmd[addr][16]} {spi_nor_top_inst/spi_txn_mgr_inst/spi_cmd[addr][17]} {spi_nor_top_inst/spi_txn_mgr_inst/spi_cmd[addr][18]} {spi_nor_top_inst/spi_txn_mgr_inst/spi_cmd[addr][19]} {spi_nor_top_inst/spi_txn_mgr_inst/spi_cmd[addr][20]} {spi_nor_top_inst/spi_txn_mgr_inst/spi_cmd[addr][21]} {spi_nor_top_inst/spi_txn_mgr_inst/spi_cmd[addr][22]} {spi_nor_top_inst/spi_txn_mgr_inst/spi_cmd[addr][23]} {spi_nor_top_inst/spi_txn_mgr_inst/spi_cmd[addr][24]} {spi_nor_top_inst/spi_txn_mgr_inst/spi_cmd[addr][25]} {spi_nor_top_inst/spi_txn_mgr_inst/spi_cmd[addr][26]} {spi_nor_top_inst/spi_txn_mgr_inst/spi_cmd[addr][27]} {spi_nor_top_inst/spi_txn_mgr_inst/spi_cmd[addr][28]} {spi_nor_top_inst/spi_txn_mgr_inst/spi_cmd[addr][29]} {spi_nor_top_inst/spi_txn_mgr_inst/spi_cmd[addr][30]} {spi_nor_top_inst/spi_txn_mgr_inst/spi_cmd[addr][31]} ]]
create_debug_port u_ila_0 probe
set_property port_width 2 [get_debug_ports u_ila_0/probe4]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe4]
connect_debug_port u_ila_0/probe4 [get_nets [list {spi_nor_top_inst/spi_txn_mgr_inst/r[txn][data_mode][0]} {spi_nor_top_inst/spi_txn_mgr_inst/r[txn][data_mode][1]} ]]
create_debug_port u_ila_0 probe
set_property port_width 2 [get_debug_ports u_ila_0/probe5]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe5]
connect_debug_port u_ila_0/probe5 [get_nets [list {spi_nor_top_inst/spi_txn_mgr_inst/r[txn][data_kind][0]} {spi_nor_top_inst/spi_txn_mgr_inst/r[txn][data_kind][1]} ]]
create_debug_port u_ila_0 probe
set_property port_width 2 [get_debug_ports u_ila_0/probe6]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe6]
connect_debug_port u_ila_0/probe6 [get_nets [list {spi_nor_top_inst/spi_txn_mgr_inst/r[txn][addr_kind][0]} {spi_nor_top_inst/spi_txn_mgr_inst/r[txn][addr_kind][1]} ]]
create_debug_port u_ila_0 probe
set_property port_width 3 [get_debug_ports u_ila_0/probe7]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe7]
connect_debug_port u_ila_0/probe7 [get_nets [list {spi_nor_top_inst/spi_txn_mgr_inst/r[state][0]} {spi_nor_top_inst/spi_txn_mgr_inst/r[state][1]} {spi_nor_top_inst/spi_txn_mgr_inst/r[state][2]} ]]
create_debug_port u_ila_0 probe
set_property port_width 10 [get_debug_ports u_ila_0/probe8]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe8]
connect_debug_port u_ila_0/probe8 [get_nets [list {spi_nor_top_inst/spi_txn_mgr_inst/r[counter][0]} {spi_nor_top_inst/spi_txn_mgr_inst/r[counter][1]} {spi_nor_top_inst/spi_txn_mgr_inst/r[counter][2]} {spi_nor_top_inst/spi_txn_mgr_inst/r[counter][3]} {spi_nor_top_inst/spi_txn_mgr_inst/r[counter][4]} {spi_nor_top_inst/spi_txn_mgr_inst/r[counter][5]} {spi_nor_top_inst/spi_txn_mgr_inst/r[counter][6]} {spi_nor_top_inst/spi_txn_mgr_inst/r[counter][7]} {spi_nor_top_inst/spi_txn_mgr_inst/r[counter][8]} {spi_nor_top_inst/spi_txn_mgr_inst/r[counter][9]} ]]
create_debug_port u_ila_0 probe
set_property port_width 8 [get_debug_ports u_ila_0/probe9]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe9]
connect_debug_port u_ila_0/probe9 [get_nets [list {spi_nor_top_inst/spi_txn_mgr_inst/spi_cmd[instr][0]} {spi_nor_top_inst/spi_txn_mgr_inst/spi_cmd[instr][1]} {spi_nor_top_inst/spi_txn_mgr_inst/spi_cmd[instr][2]} {spi_nor_top_inst/spi_txn_mgr_inst/spi_cmd[instr][3]} {spi_nor_top_inst/spi_txn_mgr_inst/spi_cmd[instr][4]} {spi_nor_top_inst/spi_txn_mgr_inst/spi_cmd[instr][5]} {spi_nor_top_inst/spi_txn_mgr_inst/spi_cmd[instr][6]} {spi_nor_top_inst/spi_txn_mgr_inst/spi_cmd[instr][7]} ]]
create_debug_port u_ila_0 probe
set_property port_width 8 [get_debug_ports u_ila_0/probe10]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe10]
connect_debug_port u_ila_0/probe10 [get_nets [list {spi_nor_top_inst/spi_txn_mgr_inst/spi_cmd[dummy_cycles][0]} {spi_nor_top_inst/spi_txn_mgr_inst/spi_cmd[dummy_cycles][1]} {spi_nor_top_inst/spi_txn_mgr_inst/spi_cmd[dummy_cycles][2]} {spi_nor_top_inst/spi_txn_mgr_inst/spi_cmd[dummy_cycles][3]} {spi_nor_top_inst/spi_txn_mgr_inst/spi_cmd[dummy_cycles][4]} {spi_nor_top_inst/spi_txn_mgr_inst/spi_cmd[dummy_cycles][5]} {spi_nor_top_inst/spi_txn_mgr_inst/spi_cmd[dummy_cycles][6]} {spi_nor_top_inst/spi_txn_mgr_inst/spi_cmd[dummy_cycles][7]} ]]
create_debug_port u_ila_0 probe
set_property port_width 32 [get_debug_ports u_ila_0/probe11]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe11]
connect_debug_port u_ila_0/probe11 [get_nets [list {spi_nor_top_inst/link/dbg_sclk_cnts[0]} {spi_nor_top_inst/link/dbg_sclk_cnts[1]} {spi_nor_top_inst/link/dbg_sclk_cnts[2]} {spi_nor_top_inst/link/dbg_sclk_cnts[3]} {spi_nor_top_inst/link/dbg_sclk_cnts[4]} {spi_nor_top_inst/link/dbg_sclk_cnts[5]} {spi_nor_top_inst/link/dbg_sclk_cnts[6]} {spi_nor_top_inst/link/dbg_sclk_cnts[7]} {spi_nor_top_inst/link/dbg_sclk_cnts[8]} {spi_nor_top_inst/link/dbg_sclk_cnts[9]} {spi_nor_top_inst/link/dbg_sclk_cnts[10]} {spi_nor_top_inst/link/dbg_sclk_cnts[11]} {spi_nor_top_inst/link/dbg_sclk_cnts[12]} {spi_nor_top_inst/link/dbg_sclk_cnts[13]} {spi_nor_top_inst/link/dbg_sclk_cnts[14]} {spi_nor_top_inst/link/dbg_sclk_cnts[15]} {spi_nor_top_inst/link/dbg_sclk_cnts[16]} {spi_nor_top_inst/link/dbg_sclk_cnts[17]} {spi_nor_top_inst/link/dbg_sclk_cnts[18]} {spi_nor_top_inst/link/dbg_sclk_cnts[19]} {spi_nor_top_inst/link/dbg_sclk_cnts[20]} {spi_nor_top_inst/link/dbg_sclk_cnts[21]} {spi_nor_top_inst/link/dbg_sclk_cnts[22]} {spi_nor_top_inst/link/dbg_sclk_cnts[23]} {spi_nor_top_inst/link/dbg_sclk_cnts[24]} {spi_nor_top_inst/link/dbg_sclk_cnts[25]} {spi_nor_top_inst/link/dbg_sclk_cnts[26]} {spi_nor_top_inst/link/dbg_sclk_cnts[27]} {spi_nor_top_inst/link/dbg_sclk_cnts[28]} {spi_nor_top_inst/link/dbg_sclk_cnts[29]} {spi_nor_top_inst/link/dbg_sclk_cnts[30]} {spi_nor_top_inst/link/dbg_sclk_cnts[31]} ]]
create_debug_port u_ila_0 probe
set_property port_width 4 [get_debug_ports u_ila_0/probe12]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe12]
connect_debug_port u_ila_0/probe12 [get_nets [list {spi_nor_top_inst/link/io[0]} {spi_nor_top_inst/link/io[1]} {spi_nor_top_inst/link/io[2]} {spi_nor_top_inst/link/io[3]} ]]
create_debug_port u_ila_0 probe
set_property port_width 3 [get_debug_ports u_ila_0/probe13]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe13]
connect_debug_port u_ila_0/probe13 [get_nets [list {spi_nor_top_inst/link/io_o[0]} {spi_nor_top_inst/link/io_o[1]} {spi_nor_top_inst/link/io_o[3]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe14]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe14]
connect_debug_port u_ila_0/probe14 [get_nets [list {spi_nor_top_inst/spi_txn_mgr_inst/r[csn]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe15]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe15]
connect_debug_port u_ila_0/probe15 [get_nets [list {spi_nor_top_inst/spi_txn_mgr_inst/r[txn][uses_dummys]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe16]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe16]
connect_debug_port u_ila_0/probe16 [get_nets [list spi_nor_top_inst/tx_byte_done ]]
set_property port_width 4 [get_debug_ports u_ila_1/probe0]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe0]
connect_debug_port u_ila_1/probe0 [get_nets [list {stm32h7_fmc_target_inst/fmc_state[0]} {stm32h7_fmc_target_inst/fmc_state[1]} {stm32h7_fmc_target_inst/fmc_state[2]} {stm32h7_fmc_target_inst/fmc_state[3]} ]]
create_debug_port u_ila_1 probe
set_property port_width 26 [get_debug_ports u_ila_1/probe1]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe1]
connect_debug_port u_ila_1/probe1 [get_nets [list {stm32h7_fmc_target_inst/txn[addr][0]} {stm32h7_fmc_target_inst/txn[addr][1]} {stm32h7_fmc_target_inst/txn[addr][2]} {stm32h7_fmc_target_inst/txn[addr][3]} {stm32h7_fmc_target_inst/txn[addr][4]} {stm32h7_fmc_target_inst/txn[addr][5]} {stm32h7_fmc_target_inst/txn[addr][6]} {stm32h7_fmc_target_inst/txn[addr][7]} {stm32h7_fmc_target_inst/txn[addr][8]} {stm32h7_fmc_target_inst/txn[addr][9]} {stm32h7_fmc_target_inst/txn[addr][10]} {stm32h7_fmc_target_inst/txn[addr][11]} {stm32h7_fmc_target_inst/txn[addr][12]} {stm32h7_fmc_target_inst/txn[addr][13]} {stm32h7_fmc_target_inst/txn[addr][14]} {stm32h7_fmc_target_inst/txn[addr][15]} {stm32h7_fmc_target_inst/txn[addr][16]} {stm32h7_fmc_target_inst/txn[addr][17]} {stm32h7_fmc_target_inst/txn[addr][18]} {stm32h7_fmc_target_inst/txn[addr][19]} {stm32h7_fmc_target_inst/txn[addr][20]} {stm32h7_fmc_target_inst/txn[addr][21]} {stm32h7_fmc_target_inst/txn[addr][22]} {stm32h7_fmc_target_inst/txn[addr][23]} {stm32h7_fmc_target_inst/txn[addr][24]} {stm32h7_fmc_target_inst/txn[addr][25]} ]]
create_debug_port u_ila_1 probe
set_property port_width 1 [get_debug_ports u_ila_1/probe2]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe2]
connect_debug_port u_ila_1/probe2 [get_nets [list {stm32h7_fmc_target_inst/txn[read_not_write]} ]]