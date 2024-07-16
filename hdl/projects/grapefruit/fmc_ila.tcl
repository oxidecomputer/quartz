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
connect_debug_port u_ila_0/clk [get_nets [list fmc_sp_to_fpga_clk_IBUF_BUFG ]]
connect_debug_port u_ila_1/clk [get_nets [list pll/inst/clk_125m ]]
set_property port_width 32 [get_debug_ports u_ila_0/probe0]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe0]
connect_debug_port u_ila_0/probe0 [get_nets [list {stm32h7_fmc_target_inst/rdata_dcfifo_dut/axi_fifo_rd_path_rdata[0]} {stm32h7_fmc_target_inst/rdata_dcfifo_dut/axi_fifo_rd_path_rdata[1]} {stm32h7_fmc_target_inst/rdata_dcfifo_dut/axi_fifo_rd_path_rdata[2]} {stm32h7_fmc_target_inst/rdata_dcfifo_dut/axi_fifo_rd_path_rdata[3]} {stm32h7_fmc_target_inst/rdata_dcfifo_dut/axi_fifo_rd_path_rdata[4]} {stm32h7_fmc_target_inst/rdata_dcfifo_dut/axi_fifo_rd_path_rdata[5]} {stm32h7_fmc_target_inst/rdata_dcfifo_dut/axi_fifo_rd_path_rdata[6]} {stm32h7_fmc_target_inst/rdata_dcfifo_dut/axi_fifo_rd_path_rdata[7]} {stm32h7_fmc_target_inst/rdata_dcfifo_dut/axi_fifo_rd_path_rdata[8]} {stm32h7_fmc_target_inst/rdata_dcfifo_dut/axi_fifo_rd_path_rdata[9]} {stm32h7_fmc_target_inst/rdata_dcfifo_dut/axi_fifo_rd_path_rdata[10]} {stm32h7_fmc_target_inst/rdata_dcfifo_dut/axi_fifo_rd_path_rdata[11]} {stm32h7_fmc_target_inst/rdata_dcfifo_dut/axi_fifo_rd_path_rdata[12]} {stm32h7_fmc_target_inst/rdata_dcfifo_dut/axi_fifo_rd_path_rdata[13]} {stm32h7_fmc_target_inst/rdata_dcfifo_dut/axi_fifo_rd_path_rdata[14]} {stm32h7_fmc_target_inst/rdata_dcfifo_dut/axi_fifo_rd_path_rdata[15]} {stm32h7_fmc_target_inst/rdata_dcfifo_dut/axi_fifo_rd_path_rdata[16]} {stm32h7_fmc_target_inst/rdata_dcfifo_dut/axi_fifo_rd_path_rdata[17]} {stm32h7_fmc_target_inst/rdata_dcfifo_dut/axi_fifo_rd_path_rdata[18]} {stm32h7_fmc_target_inst/rdata_dcfifo_dut/axi_fifo_rd_path_rdata[19]} {stm32h7_fmc_target_inst/rdata_dcfifo_dut/axi_fifo_rd_path_rdata[20]} {stm32h7_fmc_target_inst/rdata_dcfifo_dut/axi_fifo_rd_path_rdata[21]} {stm32h7_fmc_target_inst/rdata_dcfifo_dut/axi_fifo_rd_path_rdata[22]} {stm32h7_fmc_target_inst/rdata_dcfifo_dut/axi_fifo_rd_path_rdata[23]} {stm32h7_fmc_target_inst/rdata_dcfifo_dut/axi_fifo_rd_path_rdata[24]} {stm32h7_fmc_target_inst/rdata_dcfifo_dut/axi_fifo_rd_path_rdata[25]} {stm32h7_fmc_target_inst/rdata_dcfifo_dut/axi_fifo_rd_path_rdata[26]} {stm32h7_fmc_target_inst/rdata_dcfifo_dut/axi_fifo_rd_path_rdata[27]} {stm32h7_fmc_target_inst/rdata_dcfifo_dut/axi_fifo_rd_path_rdata[28]} {stm32h7_fmc_target_inst/rdata_dcfifo_dut/axi_fifo_rd_path_rdata[29]} {stm32h7_fmc_target_inst/rdata_dcfifo_dut/axi_fifo_rd_path_rdata[30]} {stm32h7_fmc_target_inst/rdata_dcfifo_dut/axi_fifo_rd_path_rdata[31]} ]]
create_debug_port u_ila_0 probe
set_property port_width 16 [get_debug_ports u_ila_0/probe1]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe1]
connect_debug_port u_ila_0/probe1 [get_nets [list {stm32h7_fmc_target_inst/fmc_sp_to_fpga_da_IBUF[0]} {stm32h7_fmc_target_inst/fmc_sp_to_fpga_da_IBUF[1]} {stm32h7_fmc_target_inst/fmc_sp_to_fpga_da_IBUF[2]} {stm32h7_fmc_target_inst/fmc_sp_to_fpga_da_IBUF[3]} {stm32h7_fmc_target_inst/fmc_sp_to_fpga_da_IBUF[4]} {stm32h7_fmc_target_inst/fmc_sp_to_fpga_da_IBUF[5]} {stm32h7_fmc_target_inst/fmc_sp_to_fpga_da_IBUF[6]} {stm32h7_fmc_target_inst/fmc_sp_to_fpga_da_IBUF[7]} {stm32h7_fmc_target_inst/fmc_sp_to_fpga_da_IBUF[8]} {stm32h7_fmc_target_inst/fmc_sp_to_fpga_da_IBUF[9]} {stm32h7_fmc_target_inst/fmc_sp_to_fpga_da_IBUF[10]} {stm32h7_fmc_target_inst/fmc_sp_to_fpga_da_IBUF[11]} {stm32h7_fmc_target_inst/fmc_sp_to_fpga_da_IBUF[12]} {stm32h7_fmc_target_inst/fmc_sp_to_fpga_da_IBUF[13]} {stm32h7_fmc_target_inst/fmc_sp_to_fpga_da_IBUF[14]} {stm32h7_fmc_target_inst/fmc_sp_to_fpga_da_IBUF[15]} ]]
create_debug_port u_ila_0 probe
set_property port_width 4 [get_debug_ports u_ila_0/probe2]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe2]
connect_debug_port u_ila_0/probe2 [get_nets [list {stm32h7_fmc_target_inst/fmc_sp_to_fpga_a_IBUF[16]} {stm32h7_fmc_target_inst/fmc_sp_to_fpga_a_IBUF[17]} {stm32h7_fmc_target_inst/fmc_sp_to_fpga_a_IBUF[18]} {stm32h7_fmc_target_inst/fmc_sp_to_fpga_a_IBUF[19]} ]]
create_debug_port u_ila_0 probe
set_property port_width 4 [get_debug_ports u_ila_0/probe3]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe3]
connect_debug_port u_ila_0/probe3 [get_nets [list {stm32h7_fmc_target_inst/dbg_state[0]} {stm32h7_fmc_target_inst/dbg_state[1]} {stm32h7_fmc_target_inst/dbg_state[2]} {stm32h7_fmc_target_inst/dbg_state[3]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe4]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe4]
connect_debug_port u_ila_0/probe4 [get_nets [list stm32h7_fmc_target_inst/fmc_data_out_enable ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe5]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe5]
connect_debug_port u_ila_0/probe5 [get_nets [list stm32h7_fmc_target_inst/fmc_sp_to_fpga_adv_l_IBUF ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe6]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe6]
connect_debug_port u_ila_0/probe6 [get_nets [list stm32h7_fmc_target_inst/fmc_sp_to_fpga_cs1_l_IBUF ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe7]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe7]
connect_debug_port u_ila_0/probe7 [get_nets [list {stm32h7_fmc_target_inst/fmc_sp_to_fpga_da_TRI[0]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe8]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe8]
connect_debug_port u_ila_0/probe8 [get_nets [list stm32h7_fmc_target_inst/fmc_sp_to_fpga_oe_l_IBUF ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe9]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe9]
connect_debug_port u_ila_0/probe9 [get_nets [list stm32h7_fmc_target_inst/fmc_sp_to_fpga_wait_l_OBUF ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe10]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe10]
connect_debug_port u_ila_0/probe10 [get_nets [list stm32h7_fmc_target_inst/fmc_sp_to_fpga_we_l_IBUF ]]
set_property port_width 3 [get_debug_ports u_ila_1/probe0]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe0]
connect_debug_port u_ila_1/probe0 [get_nets [list {stm32h7_fmc_target_inst/axi_state[0]} {stm32h7_fmc_target_inst/axi_state[1]} {stm32h7_fmc_target_inst/axi_state[2]} ]]
create_debug_port u_ila_1 probe
set_property port_width 32 [get_debug_ports u_ila_1/probe1]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe1]
connect_debug_port u_ila_1/probe1 [get_nets [list {stm32h7_fmc_target_inst/wdata_dcfifo_dut/dout[0]} {stm32h7_fmc_target_inst/wdata_dcfifo_dut/dout[1]} {stm32h7_fmc_target_inst/wdata_dcfifo_dut/dout[2]} {stm32h7_fmc_target_inst/wdata_dcfifo_dut/dout[3]} {stm32h7_fmc_target_inst/wdata_dcfifo_dut/dout[4]} {stm32h7_fmc_target_inst/wdata_dcfifo_dut/dout[5]} {stm32h7_fmc_target_inst/wdata_dcfifo_dut/dout[6]} {stm32h7_fmc_target_inst/wdata_dcfifo_dut/dout[7]} {stm32h7_fmc_target_inst/wdata_dcfifo_dut/dout[8]} {stm32h7_fmc_target_inst/wdata_dcfifo_dut/dout[9]} {stm32h7_fmc_target_inst/wdata_dcfifo_dut/dout[10]} {stm32h7_fmc_target_inst/wdata_dcfifo_dut/dout[11]} {stm32h7_fmc_target_inst/wdata_dcfifo_dut/dout[12]} {stm32h7_fmc_target_inst/wdata_dcfifo_dut/dout[13]} {stm32h7_fmc_target_inst/wdata_dcfifo_dut/dout[14]} {stm32h7_fmc_target_inst/wdata_dcfifo_dut/dout[15]} {stm32h7_fmc_target_inst/wdata_dcfifo_dut/dout[16]} {stm32h7_fmc_target_inst/wdata_dcfifo_dut/dout[17]} {stm32h7_fmc_target_inst/wdata_dcfifo_dut/dout[18]} {stm32h7_fmc_target_inst/wdata_dcfifo_dut/dout[19]} {stm32h7_fmc_target_inst/wdata_dcfifo_dut/dout[20]} {stm32h7_fmc_target_inst/wdata_dcfifo_dut/dout[21]} {stm32h7_fmc_target_inst/wdata_dcfifo_dut/dout[22]} {stm32h7_fmc_target_inst/wdata_dcfifo_dut/dout[23]} {stm32h7_fmc_target_inst/wdata_dcfifo_dut/dout[24]} {stm32h7_fmc_target_inst/wdata_dcfifo_dut/dout[25]} {stm32h7_fmc_target_inst/wdata_dcfifo_dut/dout[26]} {stm32h7_fmc_target_inst/wdata_dcfifo_dut/dout[27]} {stm32h7_fmc_target_inst/wdata_dcfifo_dut/dout[28]} {stm32h7_fmc_target_inst/wdata_dcfifo_dut/dout[29]} {stm32h7_fmc_target_inst/wdata_dcfifo_dut/dout[30]} {stm32h7_fmc_target_inst/wdata_dcfifo_dut/dout[31]} ]]
create_debug_port u_ila_1 probe
set_property port_width 1 [get_debug_ports u_ila_1/probe2]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe2]
connect_debug_port u_ila_1/probe2 [get_nets [list stm32h7_fmc_target_inst/sp_arvalid ]]
create_debug_port u_ila_1 probe
set_property port_width 1 [get_debug_ports u_ila_1/probe3]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe3]
connect_debug_port u_ila_1/probe3 [get_nets [list stm32h7_fmc_target_inst/sp_awvalid ]]
create_debug_port u_ila_1 probe
set_property port_width 1 [get_debug_ports u_ila_1/probe4]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe4]
connect_debug_port u_ila_1/probe4 [get_nets [list stm32h7_fmc_target_inst/sp_bready ]]
create_debug_port u_ila_1 probe
set_property port_width 1 [get_debug_ports u_ila_1/probe5]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe5]
connect_debug_port u_ila_1/probe5 [get_nets [list stm32h7_fmc_target_inst/sp_bvalid ]]
create_debug_port u_ila_1 probe
set_property port_width 1 [get_debug_ports u_ila_1/probe6]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe6]
connect_debug_port u_ila_1/probe6 [get_nets [list stm32h7_fmc_target_inst/sp_rready ]]
create_debug_port u_ila_1 probe
set_property port_width 1 [get_debug_ports u_ila_1/probe7]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe7]
connect_debug_port u_ila_1/probe7 [get_nets [list stm32h7_fmc_target_inst/sp_rvalid ]]
create_debug_port u_ila_1 probe
set_property port_width 1 [get_debug_ports u_ila_1/probe8]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe8]
connect_debug_port u_ila_1/probe8 [get_nets [list stm32h7_fmc_target_inst/sp_wready ]]
create_debug_port u_ila_1 probe
set_property port_width 1 [get_debug_ports u_ila_1/probe9]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe9]
connect_debug_port u_ila_1/probe9 [get_nets [list stm32h7_fmc_target_inst/sp_wvalid ]]