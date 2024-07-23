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
connect_debug_port u_ila_0/probe0 [get_nets [list {axil_interconnect_inst/axi_state[0]} ]]
create_debug_port u_ila_0 probe
set_property port_width 7 [get_debug_ports u_ila_0/probe1]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe1]
connect_debug_port u_ila_0/probe1 [get_nets [list {axil_interconnect_inst/responders[0][read_data][data][0]} {axil_interconnect_inst/responders[0][read_data][data][1]} {axil_interconnect_inst/responders[0][read_data][data][2]} {axil_interconnect_inst/responders[0][read_data][data][3]} {axil_interconnect_inst/responders[0][read_data][data][4]} {axil_interconnect_inst/responders[0][read_data][data][5]} {axil_interconnect_inst/responders[0][read_data][data][6]} ]]
create_debug_port u_ila_0 probe
set_property port_width 26 [get_debug_ports u_ila_0/probe2]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe2]
connect_debug_port u_ila_0/probe2 [get_nets [list {stm32h7_fmc_target_inst/axi_fifo_txn_path_rdata[0]} {stm32h7_fmc_target_inst/axi_fifo_txn_path_rdata[1]} {stm32h7_fmc_target_inst/axi_fifo_txn_path_rdata[2]} {stm32h7_fmc_target_inst/axi_fifo_txn_path_rdata[3]} {stm32h7_fmc_target_inst/axi_fifo_txn_path_rdata[4]} {stm32h7_fmc_target_inst/axi_fifo_txn_path_rdata[5]} {stm32h7_fmc_target_inst/axi_fifo_txn_path_rdata[6]} {stm32h7_fmc_target_inst/axi_fifo_txn_path_rdata[7]} {stm32h7_fmc_target_inst/axi_fifo_txn_path_rdata[8]} {stm32h7_fmc_target_inst/axi_fifo_txn_path_rdata[9]} {stm32h7_fmc_target_inst/axi_fifo_txn_path_rdata[10]} {stm32h7_fmc_target_inst/axi_fifo_txn_path_rdata[11]} {stm32h7_fmc_target_inst/axi_fifo_txn_path_rdata[12]} {stm32h7_fmc_target_inst/axi_fifo_txn_path_rdata[13]} {stm32h7_fmc_target_inst/axi_fifo_txn_path_rdata[14]} {stm32h7_fmc_target_inst/axi_fifo_txn_path_rdata[15]} {stm32h7_fmc_target_inst/axi_fifo_txn_path_rdata[16]} {stm32h7_fmc_target_inst/axi_fifo_txn_path_rdata[17]} {stm32h7_fmc_target_inst/axi_fifo_txn_path_rdata[18]} {stm32h7_fmc_target_inst/axi_fifo_txn_path_rdata[19]} {stm32h7_fmc_target_inst/axi_fifo_txn_path_rdata[20]} {stm32h7_fmc_target_inst/axi_fifo_txn_path_rdata[21]} {stm32h7_fmc_target_inst/axi_fifo_txn_path_rdata[22]} {stm32h7_fmc_target_inst/axi_fifo_txn_path_rdata[23]} {stm32h7_fmc_target_inst/axi_fifo_txn_path_rdata[24]} {stm32h7_fmc_target_inst/axi_fifo_txn_path_rdata[25]} ]]
create_debug_port u_ila_0 probe
set_property port_width 2 [get_debug_ports u_ila_0/probe3]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe3]
connect_debug_port u_ila_0/probe3 [get_nets [list {stm32h7_fmc_target_inst/axi_state[0]} {stm32h7_fmc_target_inst/axi_state[1]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe4]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe4]
connect_debug_port u_ila_0/probe4 [get_nets [list {axil_interconnect_inst/responder_sel_reg[0]_0} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe5]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe5]
connect_debug_port u_ila_0/probe5 [get_nets [list {axil_interconnect_inst/responder_sel_reg[0]_1} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe6]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe6]
connect_debug_port u_ila_0/probe6 [get_nets [list {axil_interconnect_inst/responders[0][read_address][ready]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe7]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe7]
connect_debug_port u_ila_0/probe7 [get_nets [list {axil_interconnect_inst/responders[0][read_data][valid]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe8]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe8]
connect_debug_port u_ila_0/probe8 [get_nets [list {axil_interconnect_inst/responders[0][write_data][ready]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe9]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe9]
connect_debug_port u_ila_0/probe9 [get_nets [list {axil_interconnect_inst/responders[0][write_response][valid]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe10]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe10]
connect_debug_port u_ila_0/probe10 [get_nets [list {axil_interconnect_inst/responder_sel_reg[0]_2} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe11]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe11]
connect_debug_port u_ila_0/probe11 [get_nets [list axil_interconnect_inst/rd_en ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe12]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe12]
connect_debug_port u_ila_0/probe12 [get_nets [list axil_interconnect_inst/in_txn ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe13]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe13]
connect_debug_port u_ila_0/probe13 [get_nets [list {axil_interconnect_inst/fmc_axi_if[write_data][valid]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe14]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe14]
connect_debug_port u_ila_0/probe14 [get_nets [list {axil_interconnect_inst/fmc_axi_if[read_data][ready]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe15]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe15]
connect_debug_port u_ila_0/probe15 [get_nets [list {axil_interconnect_inst/fmc_axi_if[read_address][valid]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe16]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe16]
connect_debug_port u_ila_0/probe16 [get_nets [list axil_interconnect_inst/awready_reg ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe17]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe17]
connect_debug_port u_ila_0/probe17 [get_nets [list axil_interconnect_inst/awready0 ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe18]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe18]
connect_debug_port u_ila_0/probe18 [get_nets [list stm32h7_fmc_target_inst/arvalid_i_1_n_0 ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe19]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe19]
connect_debug_port u_ila_0/probe19 [get_nets [list stm32h7_fmc_target_inst/arvalid_reg_0 ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe20]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe20]
connect_debug_port u_ila_0/probe20 [get_nets [list stm32h7_fmc_target_inst/arvalid_reg_1 ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe21]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe21]
connect_debug_port u_ila_0/probe21 [get_nets [list stm32h7_fmc_target_inst/awvalid_i_1_n_0 ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe22]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe22]
connect_debug_port u_ila_0/probe22 [get_nets [list {stm32h7_fmc_target_inst/fmc_axi_if[read_address][valid]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe23]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe23]
connect_debug_port u_ila_0/probe23 [get_nets [list {stm32h7_fmc_target_inst/fmc_axi_if[read_data][ready]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe24]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe24]
connect_debug_port u_ila_0/probe24 [get_nets [list {stm32h7_fmc_target_inst/fmc_axi_if[write_address][valid]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe25]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe25]
connect_debug_port u_ila_0/probe25 [get_nets [list {stm32h7_fmc_target_inst/fmc_axi_if[write_data][valid]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe26]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe26]
connect_debug_port u_ila_0/probe26 [get_nets [list {stm32h7_fmc_target_inst/responder_sel_reg[0]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe27]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe27]
connect_debug_port u_ila_0/probe27 [get_nets [list {stm32h7_fmc_target_inst/responder_sel_reg[0]_0} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe28]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe28]
connect_debug_port u_ila_0/probe28 [get_nets [list {stm32h7_fmc_target_inst/responders[0][read_address][ready]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe29]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe29]
connect_debug_port u_ila_0/probe29 [get_nets [list {stm32h7_fmc_target_inst/responders[0][read_data][valid]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe30]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe30]
connect_debug_port u_ila_0/probe30 [get_nets [list {stm32h7_fmc_target_inst/responders[0][write_data][ready]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe31]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe31]
connect_debug_port u_ila_0/probe31 [get_nets [list {stm32h7_fmc_target_inst/responders[0][write_response][valid]} ]]