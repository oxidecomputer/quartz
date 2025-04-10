create_debug_core u_ila_0 ila
set_property C_DATA_DEPTH 4096 [get_debug_cores u_ila_0]
set_property C_TRIGIN_EN false [get_debug_cores u_ila_0]
set_property C_TRIGOUT_EN false [get_debug_cores u_ila_0]
set_property C_ADV_TRIGGER false [get_debug_cores u_ila_0]
set_property C_INPUT_PIPE_STAGES 0 [get_debug_cores u_ila_0]
set_property C_EN_STRG_QUAL false [get_debug_cores u_ila_0]
set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila_0]
set_property ALL_PROBE_SAME_MU_CNT 1 [get_debug_cores u_ila_0]
connect_debug_port u_ila_0/clk [get_nets [list board_support_inst/pll/inst/clk_200m ]]
set_property port_width 4 [get_debug_ports u_ila_0/probe0]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe0]
connect_debug_port u_ila_0/probe0 [get_nets [list {espi0_sp5_to_fpga1_dat_IBUF[0]} {espi0_sp5_to_fpga1_dat_IBUF[1]} {espi0_sp5_to_fpga1_dat_IBUF[2]} {espi0_sp5_to_fpga1_dat_IBUF[3]} ]]
create_debug_port u_ila_0 probe
set_property port_width 4 [get_debug_ports u_ila_0/probe1]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe1]
connect_debug_port u_ila_0/probe1 [get_nets [list {espi0_sp5_to_fpga1_dat_OBUF[0]} {espi0_sp5_to_fpga1_dat_OBUF[1]} {espi0_sp5_to_fpga1_dat_OBUF[2]} {espi0_sp5_to_fpga1_dat_OBUF[3]} ]]
create_debug_port u_ila_0 probe
set_property port_width 8 [get_debug_ports u_ila_0/probe2]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe2]
connect_debug_port u_ila_0/probe2 [get_nets [list {espi_spinor_ss/espi_target_top_inst/qspi_link_layer_inst/rx_reg_reg[7]_0[0]} {espi_spinor_ss/espi_target_top_inst/qspi_link_layer_inst/rx_reg_reg[7]_0[1]} {espi_spinor_ss/espi_target_top_inst/qspi_link_layer_inst/rx_reg_reg[7]_0[2]} {espi_spinor_ss/espi_target_top_inst/qspi_link_layer_inst/rx_reg_reg[7]_0[3]} {espi_spinor_ss/espi_target_top_inst/qspi_link_layer_inst/rx_reg_reg[7]_0[4]} {espi_spinor_ss/espi_target_top_inst/qspi_link_layer_inst/rx_reg_reg[7]_0[5]} {espi_spinor_ss/espi_target_top_inst/qspi_link_layer_inst/rx_reg_reg[7]_0[6]} {espi_spinor_ss/espi_target_top_inst/qspi_link_layer_inst/rx_reg_reg[7]_0[7]} ]]
create_debug_port u_ila_0 probe
set_property port_width 8 [get_debug_ports u_ila_0/probe3]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe3]
connect_debug_port u_ila_0/probe3 [get_nets [list {espi_spinor_ss/espi_target_top_inst/qspi_link_layer_inst/tx_reg_reg[8]_0[0]} {espi_spinor_ss/espi_target_top_inst/qspi_link_layer_inst/tx_reg_reg[8]_0[1]} {espi_spinor_ss/espi_target_top_inst/qspi_link_layer_inst/tx_reg_reg[8]_0[2]} {espi_spinor_ss/espi_target_top_inst/qspi_link_layer_inst/tx_reg_reg[8]_0[3]} {espi_spinor_ss/espi_target_top_inst/qspi_link_layer_inst/tx_reg_reg[8]_0[4]} {espi_spinor_ss/espi_target_top_inst/qspi_link_layer_inst/tx_reg_reg[8]_0[5]} {espi_spinor_ss/espi_target_top_inst/qspi_link_layer_inst/tx_reg_reg[8]_0[6]} {espi_spinor_ss/espi_target_top_inst/qspi_link_layer_inst/tx_reg_reg[8]_0[7]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe4]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe4]
connect_debug_port u_ila_0/probe4 [get_nets [list espi_spinor_ss/espi_target_top_inst/cs_n_syncd ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe5]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe5]
connect_debug_port u_ila_0/probe5 [get_nets [list espi0_sp5_to_fpga1_cs_l_IBUF ]]