create_debug_core u_ila_0 ila
set_property C_DATA_DEPTH 1024 [get_debug_cores u_ila_0]
set_property C_TRIGIN_EN false [get_debug_cores u_ila_0]
set_property C_TRIGOUT_EN false [get_debug_cores u_ila_0]
set_property C_ADV_TRIGGER false [get_debug_cores u_ila_0]
set_property C_INPUT_PIPE_STAGES 0 [get_debug_cores u_ila_0]
set_property C_EN_STRG_QUAL false [get_debug_cores u_ila_0]
set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila_0]
set_property ALL_PROBE_SAME_MU_CNT 1 [get_debug_cores u_ila_0]
connect_debug_port u_ila_0/clk [get_nets [list pll/inst/clk_125m ]]
set_property port_width 1 [get_debug_ports u_ila_0/probe0]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe0]
connect_debug_port u_ila_0/probe0 [get_nets [list {axil_interconnect_inst/responder_sel[0]} ]]
create_debug_port u_ila_0 probe
set_property port_width 32 [get_debug_ports u_ila_0/probe1]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe1]
connect_debug_port u_ila_0/probe1 [get_nets [list {spi_nor_top_inst/rx_dcfifo_dut/din[0]} {spi_nor_top_inst/rx_dcfifo_dut/din[1]} {spi_nor_top_inst/rx_dcfifo_dut/din[2]} {spi_nor_top_inst/rx_dcfifo_dut/din[3]} {spi_nor_top_inst/rx_dcfifo_dut/din[4]} {spi_nor_top_inst/rx_dcfifo_dut/din[5]} {spi_nor_top_inst/rx_dcfifo_dut/din[6]} {spi_nor_top_inst/rx_dcfifo_dut/din[7]} {spi_nor_top_inst/rx_dcfifo_dut/din[8]} {spi_nor_top_inst/rx_dcfifo_dut/din[9]} {spi_nor_top_inst/rx_dcfifo_dut/din[10]} {spi_nor_top_inst/rx_dcfifo_dut/din[11]} {spi_nor_top_inst/rx_dcfifo_dut/din[12]} {spi_nor_top_inst/rx_dcfifo_dut/din[13]} {spi_nor_top_inst/rx_dcfifo_dut/din[14]} {spi_nor_top_inst/rx_dcfifo_dut/din[15]} {spi_nor_top_inst/rx_dcfifo_dut/din[16]} {spi_nor_top_inst/rx_dcfifo_dut/din[17]} {spi_nor_top_inst/rx_dcfifo_dut/din[18]} {spi_nor_top_inst/rx_dcfifo_dut/din[19]} {spi_nor_top_inst/rx_dcfifo_dut/din[20]} {spi_nor_top_inst/rx_dcfifo_dut/din[21]} {spi_nor_top_inst/rx_dcfifo_dut/din[22]} {spi_nor_top_inst/rx_dcfifo_dut/din[23]} {spi_nor_top_inst/rx_dcfifo_dut/din[24]} {spi_nor_top_inst/rx_dcfifo_dut/din[25]} {spi_nor_top_inst/rx_dcfifo_dut/din[26]} {spi_nor_top_inst/rx_dcfifo_dut/din[27]} {spi_nor_top_inst/rx_dcfifo_dut/din[28]} {spi_nor_top_inst/rx_dcfifo_dut/din[29]} {spi_nor_top_inst/rx_dcfifo_dut/din[30]} {spi_nor_top_inst/rx_dcfifo_dut/din[31]} ]]
create_debug_port u_ila_0 probe
set_property port_width 32 [get_debug_ports u_ila_0/probe2]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe2]
connect_debug_port u_ila_0/probe2 [get_nets [list {axil_interconnect_inst/responders[0][read_data][data][0]} {axil_interconnect_inst/responders[0][read_data][data][1]} {axil_interconnect_inst/responders[0][read_data][data][2]} {axil_interconnect_inst/responders[0][read_data][data][3]} {axil_interconnect_inst/responders[0][read_data][data][4]} {axil_interconnect_inst/responders[0][read_data][data][5]} {axil_interconnect_inst/responders[0][read_data][data][6]} {axil_interconnect_inst/responders[0][read_data][data][7]} {axil_interconnect_inst/responders[0][read_data][data][8]} {axil_interconnect_inst/responders[0][read_data][data][9]} {axil_interconnect_inst/responders[0][read_data][data][10]} {axil_interconnect_inst/responders[0][read_data][data][11]} {axil_interconnect_inst/responders[0][read_data][data][12]} {axil_interconnect_inst/responders[0][read_data][data][13]} {axil_interconnect_inst/responders[0][read_data][data][14]} {axil_interconnect_inst/responders[0][read_data][data][15]} {axil_interconnect_inst/responders[0][read_data][data][16]} {axil_interconnect_inst/responders[0][read_data][data][17]} {axil_interconnect_inst/responders[0][read_data][data][18]} {axil_interconnect_inst/responders[0][read_data][data][19]} {axil_interconnect_inst/responders[0][read_data][data][20]} {axil_interconnect_inst/responders[0][read_data][data][21]} {axil_interconnect_inst/responders[0][read_data][data][22]} {axil_interconnect_inst/responders[0][read_data][data][23]} {axil_interconnect_inst/responders[0][read_data][data][24]} {axil_interconnect_inst/responders[0][read_data][data][25]} {axil_interconnect_inst/responders[0][read_data][data][26]} {axil_interconnect_inst/responders[0][read_data][data][27]} {axil_interconnect_inst/responders[0][read_data][data][28]} {axil_interconnect_inst/responders[0][read_data][data][29]} {axil_interconnect_inst/responders[0][read_data][data][30]} {axil_interconnect_inst/responders[0][read_data][data][31]} ]]
create_debug_port u_ila_0 probe
set_property port_width 32 [get_debug_ports u_ila_0/probe3]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe3]
connect_debug_port u_ila_0/probe3 [get_nets [list {axil_interconnect_inst/responders[1][read_data][data][0]} {axil_interconnect_inst/responders[1][read_data][data][1]} {axil_interconnect_inst/responders[1][read_data][data][2]} {axil_interconnect_inst/responders[1][read_data][data][3]} {axil_interconnect_inst/responders[1][read_data][data][4]} {axil_interconnect_inst/responders[1][read_data][data][5]} {axil_interconnect_inst/responders[1][read_data][data][6]} {axil_interconnect_inst/responders[1][read_data][data][7]} {axil_interconnect_inst/responders[1][read_data][data][8]} {axil_interconnect_inst/responders[1][read_data][data][9]} {axil_interconnect_inst/responders[1][read_data][data][10]} {axil_interconnect_inst/responders[1][read_data][data][11]} {axil_interconnect_inst/responders[1][read_data][data][12]} {axil_interconnect_inst/responders[1][read_data][data][13]} {axil_interconnect_inst/responders[1][read_data][data][14]} {axil_interconnect_inst/responders[1][read_data][data][15]} {axil_interconnect_inst/responders[1][read_data][data][16]} {axil_interconnect_inst/responders[1][read_data][data][17]} {axil_interconnect_inst/responders[1][read_data][data][18]} {axil_interconnect_inst/responders[1][read_data][data][19]} {axil_interconnect_inst/responders[1][read_data][data][20]} {axil_interconnect_inst/responders[1][read_data][data][21]} {axil_interconnect_inst/responders[1][read_data][data][22]} {axil_interconnect_inst/responders[1][read_data][data][23]} {axil_interconnect_inst/responders[1][read_data][data][24]} {axil_interconnect_inst/responders[1][read_data][data][25]} {axil_interconnect_inst/responders[1][read_data][data][26]} {axil_interconnect_inst/responders[1][read_data][data][27]} {axil_interconnect_inst/responders[1][read_data][data][28]} {axil_interconnect_inst/responders[1][read_data][data][29]} {axil_interconnect_inst/responders[1][read_data][data][30]} {axil_interconnect_inst/responders[1][read_data][data][31]} ]]
create_debug_port u_ila_0 probe
set_property port_width 3 [get_debug_ports u_ila_0/probe4]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe4]
connect_debug_port u_ila_0/probe4 [get_nets [list {spi_nor_top_inst/link/state[0]} {spi_nor_top_inst/link/state[1]} {spi_nor_top_inst/link/state[2]} ]]
create_debug_port u_ila_0 probe
set_property port_width 30 [get_debug_ports u_ila_0/probe5]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe5]
connect_debug_port u_ila_0/probe5 [get_nets [list {spi_nor_top_inst/addr_reg[addr][31][0]} {spi_nor_top_inst/addr_reg[addr][31][1]} {spi_nor_top_inst/addr_reg[addr][31][2]} {spi_nor_top_inst/addr_reg[addr][31][3]} {spi_nor_top_inst/addr_reg[addr][31][4]} {spi_nor_top_inst/addr_reg[addr][31][5]} {spi_nor_top_inst/addr_reg[addr][31][6]} {spi_nor_top_inst/addr_reg[addr][31][7]} {spi_nor_top_inst/addr_reg[addr][31][8]} {spi_nor_top_inst/addr_reg[addr][31][9]} {spi_nor_top_inst/addr_reg[addr][31][10]} {spi_nor_top_inst/addr_reg[addr][31][11]} {spi_nor_top_inst/addr_reg[addr][31][12]} {spi_nor_top_inst/addr_reg[addr][31][13]} {spi_nor_top_inst/addr_reg[addr][31][14]} {spi_nor_top_inst/addr_reg[addr][31][15]} {spi_nor_top_inst/addr_reg[addr][31][16]} {spi_nor_top_inst/addr_reg[addr][31][17]} {spi_nor_top_inst/addr_reg[addr][31][18]} {spi_nor_top_inst/addr_reg[addr][31][19]} {spi_nor_top_inst/addr_reg[addr][31][20]} {spi_nor_top_inst/addr_reg[addr][31][21]} {spi_nor_top_inst/addr_reg[addr][31][22]} {spi_nor_top_inst/addr_reg[addr][31][23]} {spi_nor_top_inst/addr_reg[addr][31][24]} {spi_nor_top_inst/addr_reg[addr][31][25]} {spi_nor_top_inst/addr_reg[addr][31][26]} {spi_nor_top_inst/addr_reg[addr][31][27]} {spi_nor_top_inst/addr_reg[addr][31][28]} {spi_nor_top_inst/addr_reg[addr][31][29]} ]]
create_debug_port u_ila_0 probe
set_property port_width 8 [get_debug_ports u_ila_0/probe6]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe6]
connect_debug_port u_ila_0/probe6 [get_nets [list {spi_nor_top_inst/link/rx_reg[0]} {spi_nor_top_inst/link/rx_reg[1]} {spi_nor_top_inst/link/rx_reg[2]} {spi_nor_top_inst/link/rx_reg[3]} {spi_nor_top_inst/link/rx_reg[4]} {spi_nor_top_inst/link/rx_reg[5]} {spi_nor_top_inst/link/rx_reg[6]} {spi_nor_top_inst/link/rx_reg[7]} ]]
create_debug_port u_ila_0 probe
set_property port_width 4 [get_debug_ports u_ila_0/probe7]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe7]
connect_debug_port u_ila_0/probe7 [get_nets [list {spi_nor_top_inst/spi_txn_mgr_inst/spi_fpga_to_flash2_dat_IBUF[0]} {spi_nor_top_inst/spi_txn_mgr_inst/spi_fpga_to_flash2_dat_IBUF[1]} {spi_nor_top_inst/spi_txn_mgr_inst/spi_fpga_to_flash2_dat_IBUF[2]} {spi_nor_top_inst/spi_txn_mgr_inst/spi_fpga_to_flash2_dat_IBUF[3]} ]]
create_debug_port u_ila_0 probe
set_property port_width 2 [get_debug_ports u_ila_0/probe8]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe8]
connect_debug_port u_ila_0/probe8 [get_nets [list {spi_nor_top_inst/spi_txn_mgr_inst/r_reg[txn][addr_kind][0]} {spi_nor_top_inst/spi_txn_mgr_inst/r_reg[txn][addr_kind][1]} ]]
create_debug_port u_ila_0 probe
set_property port_width 8 [get_debug_ports u_ila_0/probe9]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe9]
connect_debug_port u_ila_0/probe9 [get_nets [list {spi_nor_top_inst/data_bytes_reg[count][0]} {spi_nor_top_inst/data_bytes_reg[count][1]} {spi_nor_top_inst/data_bytes_reg[count][2]} {spi_nor_top_inst/data_bytes_reg[count][3]} {spi_nor_top_inst/data_bytes_reg[count][4]} {spi_nor_top_inst/data_bytes_reg[count][5]} {spi_nor_top_inst/data_bytes_reg[count][6]} {spi_nor_top_inst/data_bytes_reg[count][7]} ]]
create_debug_port u_ila_0 probe
set_property port_width 8 [get_debug_ports u_ila_0/probe10]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe10]
connect_debug_port u_ila_0/probe10 [get_nets [list {spi_nor_top_inst/spi_nor_regs_inst/data_bytes_reg[count][0]} {spi_nor_top_inst/spi_nor_regs_inst/data_bytes_reg[count][1]} {spi_nor_top_inst/spi_nor_regs_inst/data_bytes_reg[count][2]} {spi_nor_top_inst/spi_nor_regs_inst/data_bytes_reg[count][3]} {spi_nor_top_inst/spi_nor_regs_inst/data_bytes_reg[count][4]} {spi_nor_top_inst/spi_nor_regs_inst/data_bytes_reg[count][5]} {spi_nor_top_inst/spi_nor_regs_inst/data_bytes_reg[count][6]} {spi_nor_top_inst/spi_nor_regs_inst/data_bytes_reg[count][7]} ]]
create_debug_port u_ila_0 probe
set_property port_width 8 [get_debug_ports u_ila_0/probe11]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe11]
connect_debug_port u_ila_0/probe11 [get_nets [list {spi_nor_top_inst/spi_nor_regs_inst/dummy_cycles_reg[count][0]} {spi_nor_top_inst/spi_nor_regs_inst/dummy_cycles_reg[count][1]} {spi_nor_top_inst/spi_nor_regs_inst/dummy_cycles_reg[count][2]} {spi_nor_top_inst/spi_nor_regs_inst/dummy_cycles_reg[count][3]} {spi_nor_top_inst/spi_nor_regs_inst/dummy_cycles_reg[count][4]} {spi_nor_top_inst/spi_nor_regs_inst/dummy_cycles_reg[count][5]} {spi_nor_top_inst/spi_nor_regs_inst/dummy_cycles_reg[count][6]} {spi_nor_top_inst/spi_nor_regs_inst/dummy_cycles_reg[count][7]} ]]
create_debug_port u_ila_0 probe
set_property port_width 32 [get_debug_ports u_ila_0/probe12]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe12]
connect_debug_port u_ila_0/probe12 [get_nets [list {spi_nor_top_inst/responders[1][read_data][data][0]} {spi_nor_top_inst/responders[1][read_data][data][1]} {spi_nor_top_inst/responders[1][read_data][data][2]} {spi_nor_top_inst/responders[1][read_data][data][3]} {spi_nor_top_inst/responders[1][read_data][data][4]} {spi_nor_top_inst/responders[1][read_data][data][5]} {spi_nor_top_inst/responders[1][read_data][data][6]} {spi_nor_top_inst/responders[1][read_data][data][7]} {spi_nor_top_inst/responders[1][read_data][data][8]} {spi_nor_top_inst/responders[1][read_data][data][9]} {spi_nor_top_inst/responders[1][read_data][data][10]} {spi_nor_top_inst/responders[1][read_data][data][11]} {spi_nor_top_inst/responders[1][read_data][data][12]} {spi_nor_top_inst/responders[1][read_data][data][13]} {spi_nor_top_inst/responders[1][read_data][data][14]} {spi_nor_top_inst/responders[1][read_data][data][15]} {spi_nor_top_inst/responders[1][read_data][data][16]} {spi_nor_top_inst/responders[1][read_data][data][17]} {spi_nor_top_inst/responders[1][read_data][data][18]} {spi_nor_top_inst/responders[1][read_data][data][19]} {spi_nor_top_inst/responders[1][read_data][data][20]} {spi_nor_top_inst/responders[1][read_data][data][21]} {spi_nor_top_inst/responders[1][read_data][data][22]} {spi_nor_top_inst/responders[1][read_data][data][23]} {spi_nor_top_inst/responders[1][read_data][data][24]} {spi_nor_top_inst/responders[1][read_data][data][25]} {spi_nor_top_inst/responders[1][read_data][data][26]} {spi_nor_top_inst/responders[1][read_data][data][27]} {spi_nor_top_inst/responders[1][read_data][data][28]} {spi_nor_top_inst/responders[1][read_data][data][29]} {spi_nor_top_inst/responders[1][read_data][data][30]} {spi_nor_top_inst/responders[1][read_data][data][31]} ]]
create_debug_port u_ila_0 probe
set_property port_width 8 [get_debug_ports u_ila_0/probe13]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe13]
connect_debug_port u_ila_0/probe13 [get_nets [list {spi_nor_top_inst/dummy_cycles_reg[count][0]} {spi_nor_top_inst/dummy_cycles_reg[count][1]} {spi_nor_top_inst/dummy_cycles_reg[count][2]} {spi_nor_top_inst/dummy_cycles_reg[count][3]} {spi_nor_top_inst/dummy_cycles_reg[count][4]} {spi_nor_top_inst/dummy_cycles_reg[count][5]} {spi_nor_top_inst/dummy_cycles_reg[count][6]} {spi_nor_top_inst/dummy_cycles_reg[count][7]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe14]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe14]
connect_debug_port u_ila_0/probe14 [get_nets [list axil_interconnect_inst/awready_reg ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe15]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe15]
connect_debug_port u_ila_0/probe15 [get_nets [list axil_interconnect_inst/awready_reg_0 ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe16]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe16]
connect_debug_port u_ila_0/probe16 [get_nets [list axil_interconnect_inst/awvalid_reg ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe17]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe17]
connect_debug_port u_ila_0/probe17 [get_nets [list spi_nor_top_inst/bvalid_reg ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe18]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe18]
connect_debug_port u_ila_0/probe18 [get_nets [list axil_interconnect_inst/bvalid_reg ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe19]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe19]
connect_debug_port u_ila_0/probe19 [get_nets [list {axil_interconnect_inst/fmc_axi_if[read_address][valid]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe20]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe20]
connect_debug_port u_ila_0/probe20 [get_nets [list {axil_interconnect_inst/fmc_axi_if[read_data][ready]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe21]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe21]
connect_debug_port u_ila_0/probe21 [get_nets [list {axil_interconnect_inst/fmc_axi_if[write_address][valid]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe22]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe22]
connect_debug_port u_ila_0/probe22 [get_nets [list {axil_interconnect_inst/fmc_axi_if[write_data][valid]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe23]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe23]
connect_debug_port u_ila_0/probe23 [get_nets [list {spi_nor_top_inst/fmc_axi_if[write_response][ready]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe24]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe24]
connect_debug_port u_ila_0/probe24 [get_nets [list {axil_interconnect_inst/fmc_axi_if[write_response][ready]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe25]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe25]
connect_debug_port u_ila_0/probe25 [get_nets [list spi_nor_top_inst/spi_nor_regs_inst/go_strobe ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe26]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe26]
connect_debug_port u_ila_0/probe26 [get_nets [list spi_nor_top_inst/link/in_tx_phases ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe27]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe27]
connect_debug_port u_ila_0/probe27 [get_nets [list {spi_nor_top_inst/spi_txn_mgr_inst/info[uses_dummys]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe28]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe28]
connect_debug_port u_ila_0/probe28 [get_nets [list {axil_interconnect_inst/responders[0][read_address][ready]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe29]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe29]
connect_debug_port u_ila_0/probe29 [get_nets [list {axil_interconnect_inst/responders[0][read_data][valid]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe30]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe30]
connect_debug_port u_ila_0/probe30 [get_nets [list {axil_interconnect_inst/responders[0][write_data][ready]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe31]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe31]
connect_debug_port u_ila_0/probe31 [get_nets [list {axil_interconnect_inst/responders[0][write_response][valid]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe32]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe32]
connect_debug_port u_ila_0/probe32 [get_nets [list {axil_interconnect_inst/responders[1][read_address][ready]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe33]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe33]
connect_debug_port u_ila_0/probe33 [get_nets [list {spi_nor_top_inst/responders[1][read_data][valid]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe34]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe34]
connect_debug_port u_ila_0/probe34 [get_nets [list {axil_interconnect_inst/responders[1][read_data][valid]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe35]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe35]
connect_debug_port u_ila_0/probe35 [get_nets [list {spi_nor_top_inst/responders[1][write_data][ready]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe36]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe36]
connect_debug_port u_ila_0/probe36 [get_nets [list {axil_interconnect_inst/responders[1][write_data][ready]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe37]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe37]
connect_debug_port u_ila_0/probe37 [get_nets [list {spi_nor_top_inst/responders[1][write_response][valid]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe38]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe38]
connect_debug_port u_ila_0/probe38 [get_nets [list {axil_interconnect_inst/responders[1][write_response][valid]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe39]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe39]
connect_debug_port u_ila_0/probe39 [get_nets [list axil_interconnect_inst/rready_reg ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe40]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe40]
connect_debug_port u_ila_0/probe40 [get_nets [list spi_nor_top_inst/rvalid_reg ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe41]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe41]
connect_debug_port u_ila_0/probe41 [get_nets [list spi_nor_top_inst/spi_fpga_to_flash2_clk_OBUF ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe42]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe42]
connect_debug_port u_ila_0/probe42 [get_nets [list spi_nor_top_inst/spi_fpga_to_flash2_cs_l_OBUF ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe43]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe43]
connect_debug_port u_ila_0/probe43 [get_nets [list {spi_nor_top_inst/spi_fpga_to_flash2_dat_TRI[0]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe44]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe44]
connect_debug_port u_ila_0/probe44 [get_nets [list {spi_nor_top_inst/spi_fpga_to_flash2_dat_TRI[1]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe45]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe45]
connect_debug_port u_ila_0/probe45 [get_nets [list {spi_nor_top_inst/spi_fpga_to_flash2_dat_TRI[2]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe46]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe46]
connect_debug_port u_ila_0/probe46 [get_nets [list spi_nor_top_inst/mixed_width_adaptor_inst/rx_byte_done ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe47]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe47]
connect_debug_port u_ila_0/probe47 [get_nets [list spi_nor_top_inst/rx_dcfifo_dut/wr_en ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe48]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe48]
connect_debug_port u_ila_0/probe48 [get_nets [list spi_nor_top_inst/rx_dcfifo_dut/rd_en ]]