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
connect_debug_port u_ila_0/clk [get_nets [list fmc_sp_to_fpga_clk_IBUF_BUFG ]]
connect_debug_port u_ila_1/clk [get_nets [list pll/inst/clk_125m ]]
set_property port_width 4 [get_debug_ports u_ila_0/probe0]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe0]
connect_debug_port u_ila_0/probe0 [get_nets [list {stm32h7_fmc_target_inst/fmc_sp_to_fpga_a_IBUF[16]} {stm32h7_fmc_target_inst/fmc_sp_to_fpga_a_IBUF[17]} {stm32h7_fmc_target_inst/fmc_sp_to_fpga_a_IBUF[18]} {stm32h7_fmc_target_inst/fmc_sp_to_fpga_a_IBUF[19]} ]]
create_debug_port u_ila_0 probe
set_property port_width 4 [get_debug_ports u_ila_0/probe1]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe1]
connect_debug_port u_ila_0/probe1 [get_nets [list {stm32h7_fmc_target_inst/fmc_state[0]} {stm32h7_fmc_target_inst/fmc_state[1]} {stm32h7_fmc_target_inst/fmc_state[2]} {stm32h7_fmc_target_inst/fmc_state[3]} ]]
create_debug_port u_ila_0 probe
set_property port_width 26 [get_debug_ports u_ila_0/probe2]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe2]
connect_debug_port u_ila_0/probe2 [get_nets [list {stm32h7_fmc_target_inst/txn[addr][0]} {stm32h7_fmc_target_inst/txn[addr][1]} {stm32h7_fmc_target_inst/txn[addr][2]} {stm32h7_fmc_target_inst/txn[addr][3]} {stm32h7_fmc_target_inst/txn[addr][4]} {stm32h7_fmc_target_inst/txn[addr][5]} {stm32h7_fmc_target_inst/txn[addr][6]} {stm32h7_fmc_target_inst/txn[addr][7]} {stm32h7_fmc_target_inst/txn[addr][8]} {stm32h7_fmc_target_inst/txn[addr][9]} {stm32h7_fmc_target_inst/txn[addr][10]} {stm32h7_fmc_target_inst/txn[addr][11]} {stm32h7_fmc_target_inst/txn[addr][12]} {stm32h7_fmc_target_inst/txn[addr][13]} {stm32h7_fmc_target_inst/txn[addr][14]} {stm32h7_fmc_target_inst/txn[addr][15]} {stm32h7_fmc_target_inst/txn[addr][16]} {stm32h7_fmc_target_inst/txn[addr][17]} {stm32h7_fmc_target_inst/txn[addr][18]} {stm32h7_fmc_target_inst/txn[addr][19]} {stm32h7_fmc_target_inst/txn[addr][20]} {stm32h7_fmc_target_inst/txn[addr][21]} {stm32h7_fmc_target_inst/txn[addr][22]} {stm32h7_fmc_target_inst/txn[addr][23]} {stm32h7_fmc_target_inst/txn[addr][24]} {stm32h7_fmc_target_inst/txn[addr][25]} ]]
create_debug_port u_ila_0 probe
set_property port_width 16 [get_debug_ports u_ila_0/probe3]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe3]
connect_debug_port u_ila_0/probe3 [get_nets [list {fmc_sp_to_fpga_da_IBUF[0]} {fmc_sp_to_fpga_da_IBUF[1]} {fmc_sp_to_fpga_da_IBUF[2]} {fmc_sp_to_fpga_da_IBUF[3]} {fmc_sp_to_fpga_da_IBUF[4]} {fmc_sp_to_fpga_da_IBUF[5]} {fmc_sp_to_fpga_da_IBUF[6]} {fmc_sp_to_fpga_da_IBUF[7]} {fmc_sp_to_fpga_da_IBUF[8]} {fmc_sp_to_fpga_da_IBUF[9]} {fmc_sp_to_fpga_da_IBUF[10]} {fmc_sp_to_fpga_da_IBUF[11]} {fmc_sp_to_fpga_da_IBUF[12]} {fmc_sp_to_fpga_da_IBUF[13]} {fmc_sp_to_fpga_da_IBUF[14]} {fmc_sp_to_fpga_da_IBUF[15]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe4]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe4]
connect_debug_port u_ila_0/probe4 [get_nets [list stm32h7_fmc_target_inst/fmc_sp_to_fpga_adv_l_IBUF ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe5]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe5]
connect_debug_port u_ila_0/probe5 [get_nets [list stm32h7_fmc_target_inst/fmc_sp_to_fpga_cs1_l_IBUF ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe6]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe6]
connect_debug_port u_ila_0/probe6 [get_nets [list {stm32h7_fmc_target_inst/fmc_sp_to_fpga_da_TRI[0]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe7]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe7]
connect_debug_port u_ila_0/probe7 [get_nets [list stm32h7_fmc_target_inst/fmc_sp_to_fpga_oe_l_IBUF ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe8]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe8]
connect_debug_port u_ila_0/probe8 [get_nets [list stm32h7_fmc_target_inst/fmc_sp_to_fpga_we_l_IBUF ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe9]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe9]
connect_debug_port u_ila_0/probe9 [get_nets [list {stm32h7_fmc_target_inst/txn[read_not_write]} ]]
set_property port_width 32 [get_debug_ports u_ila_1/probe0]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe0]
connect_debug_port u_ila_1/probe0 [get_nets [list {spi_nor_top_inst/rx_fifo_wdata32[0]} {spi_nor_top_inst/rx_fifo_wdata32[1]} {spi_nor_top_inst/rx_fifo_wdata32[2]} {spi_nor_top_inst/rx_fifo_wdata32[3]} {spi_nor_top_inst/rx_fifo_wdata32[4]} {spi_nor_top_inst/rx_fifo_wdata32[5]} {spi_nor_top_inst/rx_fifo_wdata32[6]} {spi_nor_top_inst/rx_fifo_wdata32[7]} {spi_nor_top_inst/rx_fifo_wdata32[8]} {spi_nor_top_inst/rx_fifo_wdata32[9]} {spi_nor_top_inst/rx_fifo_wdata32[10]} {spi_nor_top_inst/rx_fifo_wdata32[11]} {spi_nor_top_inst/rx_fifo_wdata32[12]} {spi_nor_top_inst/rx_fifo_wdata32[13]} {spi_nor_top_inst/rx_fifo_wdata32[14]} {spi_nor_top_inst/rx_fifo_wdata32[15]} {spi_nor_top_inst/rx_fifo_wdata32[16]} {spi_nor_top_inst/rx_fifo_wdata32[17]} {spi_nor_top_inst/rx_fifo_wdata32[18]} {spi_nor_top_inst/rx_fifo_wdata32[19]} {spi_nor_top_inst/rx_fifo_wdata32[20]} {spi_nor_top_inst/rx_fifo_wdata32[21]} {spi_nor_top_inst/rx_fifo_wdata32[22]} {spi_nor_top_inst/rx_fifo_wdata32[23]} {spi_nor_top_inst/rx_fifo_wdata32[24]} {spi_nor_top_inst/rx_fifo_wdata32[25]} {spi_nor_top_inst/rx_fifo_wdata32[26]} {spi_nor_top_inst/rx_fifo_wdata32[27]} {spi_nor_top_inst/rx_fifo_wdata32[28]} {spi_nor_top_inst/rx_fifo_wdata32[29]} {spi_nor_top_inst/rx_fifo_wdata32[30]} {spi_nor_top_inst/rx_fifo_wdata32[31]} ]]
create_debug_port u_ila_1 probe
set_property port_width 8 [get_debug_ports u_ila_1/probe1]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe1]
connect_debug_port u_ila_1/probe1 [get_nets [list {spi_nor_top_inst/rx_fifo_wdat8[0]} {spi_nor_top_inst/rx_fifo_wdat8[1]} {spi_nor_top_inst/rx_fifo_wdat8[2]} {spi_nor_top_inst/rx_fifo_wdat8[3]} {spi_nor_top_inst/rx_fifo_wdat8[4]} {spi_nor_top_inst/rx_fifo_wdat8[5]} {spi_nor_top_inst/rx_fifo_wdat8[6]} {spi_nor_top_inst/rx_fifo_wdat8[7]} ]]
create_debug_port u_ila_1 probe
set_property port_width 7 [get_debug_ports u_ila_1/probe2]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe2]
connect_debug_port u_ila_1/probe2 [get_nets [list {spi_nor_top_inst/rd_data_count[0]} {spi_nor_top_inst/rd_data_count[1]} {spi_nor_top_inst/rd_data_count[2]} {spi_nor_top_inst/rd_data_count[3]} {spi_nor_top_inst/rd_data_count[4]} {spi_nor_top_inst/rd_data_count[5]} {spi_nor_top_inst/rd_data_count[6]} ]]
create_debug_port u_ila_1 probe
set_property port_width 8 [get_debug_ports u_ila_1/probe3]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe3]
connect_debug_port u_ila_1/probe3 [get_nets [list {spi_nor_top_inst/link_tx_byte[0]} {spi_nor_top_inst/link_tx_byte[1]} {spi_nor_top_inst/link_tx_byte[2]} {spi_nor_top_inst/link_tx_byte[3]} {spi_nor_top_inst/link_tx_byte[4]} {spi_nor_top_inst/link_tx_byte[5]} {spi_nor_top_inst/link_tx_byte[6]} {spi_nor_top_inst/link_tx_byte[7]} ]]
create_debug_port u_ila_1 probe
set_property port_width 8 [get_debug_ports u_ila_1/probe4]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe4]
connect_debug_port u_ila_1/probe4 [get_nets [list {spi_nor_top_inst/link_rx_byte[0]} {spi_nor_top_inst/link_rx_byte[1]} {spi_nor_top_inst/link_rx_byte[2]} {spi_nor_top_inst/link_rx_byte[3]} {spi_nor_top_inst/link_rx_byte[4]} {spi_nor_top_inst/link_rx_byte[5]} {spi_nor_top_inst/link_rx_byte[6]} {spi_nor_top_inst/link_rx_byte[7]} ]]
create_debug_port u_ila_1 probe
set_property port_width 8 [get_debug_ports u_ila_1/probe5]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe5]
connect_debug_port u_ila_1/probe5 [get_nets [list {spi_nor_top_inst/rx_dcfifo_dut/D[0]} {spi_nor_top_inst/rx_dcfifo_dut/D[1]} {spi_nor_top_inst/rx_dcfifo_dut/D[2]} {spi_nor_top_inst/rx_dcfifo_dut/D[3]} {spi_nor_top_inst/rx_dcfifo_dut/D[4]} {spi_nor_top_inst/rx_dcfifo_dut/D[5]} {spi_nor_top_inst/rx_dcfifo_dut/D[6]} {spi_nor_top_inst/rx_dcfifo_dut/D[7]} ]]
create_debug_port u_ila_1 probe
set_property port_width 9 [get_debug_ports u_ila_1/probe6]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe6]
connect_debug_port u_ila_1/probe6 [get_nets [list {spi_nor_top_inst/link/tx_reg[0]} {spi_nor_top_inst/link/tx_reg[1]} {spi_nor_top_inst/link/tx_reg[2]} {spi_nor_top_inst/link/tx_reg[3]} {spi_nor_top_inst/link/tx_reg[4]} {spi_nor_top_inst/link/tx_reg[5]} {spi_nor_top_inst/link/tx_reg[6]} {spi_nor_top_inst/link/tx_reg[7]} {spi_nor_top_inst/link/tx_reg[8]} ]]
create_debug_port u_ila_1 probe
set_property port_width 9 [get_debug_ports u_ila_1/probe7]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe7]
connect_debug_port u_ila_1/probe7 [get_nets [list {spi_nor_top_inst/link/rx_reg[0]} {spi_nor_top_inst/link/rx_reg[1]} {spi_nor_top_inst/link/rx_reg[2]} {spi_nor_top_inst/link/rx_reg[3]} {spi_nor_top_inst/link/rx_reg[4]} {spi_nor_top_inst/link/rx_reg[5]} {spi_nor_top_inst/link/rx_reg[6]} {spi_nor_top_inst/link/rx_reg[7]} {spi_nor_top_inst/link/rx_reg[8]} ]]
create_debug_port u_ila_1 probe
set_property port_width 2 [get_debug_ports u_ila_1/probe8]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe8]
connect_debug_port u_ila_1/probe8 [get_nets [list {spi_nor_top_inst/spi_txn_mgr_inst/r[txn][data_mode][0]} {spi_nor_top_inst/spi_txn_mgr_inst/r[txn][data_mode][1]} ]]
create_debug_port u_ila_1 probe
set_property port_width 2 [get_debug_ports u_ila_1/probe9]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe9]
connect_debug_port u_ila_1/probe9 [get_nets [list {spi_nor_top_inst/spi_txn_mgr_inst/r[txn][data_kind][0]} {spi_nor_top_inst/spi_txn_mgr_inst/r[txn][data_kind][1]} ]]
create_debug_port u_ila_1 probe
set_property port_width 3 [get_debug_ports u_ila_1/probe10]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe10]
connect_debug_port u_ila_1/probe10 [get_nets [list {spi_nor_top_inst/spi_txn_mgr_inst/r[state][0]} {spi_nor_top_inst/spi_txn_mgr_inst/r[state][1]} {spi_nor_top_inst/spi_txn_mgr_inst/r[state][2]} ]]
create_debug_port u_ila_1 probe
set_property port_width 10 [get_debug_ports u_ila_1/probe11]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe11]
connect_debug_port u_ila_1/probe11 [get_nets [list {spi_nor_top_inst/spi_txn_mgr_inst/r[counter][0]} {spi_nor_top_inst/spi_txn_mgr_inst/r[counter][1]} {spi_nor_top_inst/spi_txn_mgr_inst/r[counter][2]} {spi_nor_top_inst/spi_txn_mgr_inst/r[counter][3]} {spi_nor_top_inst/spi_txn_mgr_inst/r[counter][4]} {spi_nor_top_inst/spi_txn_mgr_inst/r[counter][5]} {spi_nor_top_inst/spi_txn_mgr_inst/r[counter][6]} {spi_nor_top_inst/spi_txn_mgr_inst/r[counter][7]} {spi_nor_top_inst/spi_txn_mgr_inst/r[counter][8]} {spi_nor_top_inst/spi_txn_mgr_inst/r[counter][9]} ]]
create_debug_port u_ila_1 probe
set_property port_width 2 [get_debug_ports u_ila_1/probe12]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe12]
connect_debug_port u_ila_1/probe12 [get_nets [list {spi_nor_top_inst/spi_txn_mgr_inst/r[txn][addr_kind][0]} {spi_nor_top_inst/spi_txn_mgr_inst/r[txn][addr_kind][1]} ]]
create_debug_port u_ila_1 probe
set_property port_width 1 [get_debug_ports u_ila_1/probe13]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe13]
connect_debug_port u_ila_1/probe13 [get_nets [list {spi_nor_top_inst/go_strobe_reg[0]} ]]
create_debug_port u_ila_1 probe
set_property port_width 2 [get_debug_ports u_ila_1/probe14]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe14]
connect_debug_port u_ila_1/probe14 [get_nets [list {spi_nor_top_inst/cur_io_mode[0]} {spi_nor_top_inst/cur_io_mode[1]} ]]
create_debug_port u_ila_1 probe
set_property port_width 1 [get_debug_ports u_ila_1/probe15]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe15]
connect_debug_port u_ila_1/probe15 [get_nets [list {spi_nor_top_inst/spi_txn_mgr_inst/r[csn]} ]]
create_debug_port u_ila_1 probe
set_property port_width 1 [get_debug_ports u_ila_1/probe16]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe16]
connect_debug_port u_ila_1/probe16 [get_nets [list {spi_nor_top_inst/spi_txn_mgr_inst/r[txn][uses_dummys]} ]]
create_debug_port u_ila_1 probe
set_property port_width 1 [get_debug_ports u_ila_1/probe17]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe17]
connect_debug_port u_ila_1/probe17 [get_nets [list spi_nor_top_inst/in_rx_phases ]]
create_debug_port u_ila_1 probe
set_property port_width 1 [get_debug_ports u_ila_1/probe18]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe18]
connect_debug_port u_ila_1/probe18 [get_nets [list spi_nor_top_inst/in_tx_phases ]]
create_debug_port u_ila_1 probe
set_property port_width 1 [get_debug_ports u_ila_1/probe19]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe19]
connect_debug_port u_ila_1/probe19 [get_nets [list spi_nor_top_inst/rx_byte_done ]]
create_debug_port u_ila_1 probe
set_property port_width 1 [get_debug_ports u_ila_1/probe20]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe20]
connect_debug_port u_ila_1/probe20 [get_nets [list spi_nor_top_inst/spi_txn_mgr_inst/sclk ]]
create_debug_port u_ila_1 probe
set_property port_width 1 [get_debug_ports u_ila_1/probe21]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe21]
connect_debug_port u_ila_1/probe21 [get_nets [list spi_nor_top_inst/rx_dcfifo_dut/wr_en ]]