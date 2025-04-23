create_debug_core u_ila_0 ila
set_property C_DATA_DEPTH 4096 [get_debug_cores u_ila_0]
set_property C_TRIGIN_EN false [get_debug_cores u_ila_0]
set_property C_TRIGOUT_EN false [get_debug_cores u_ila_0]
set_property C_ADV_TRIGGER false [get_debug_cores u_ila_0]
set_property C_INPUT_PIPE_STAGES 0 [get_debug_cores u_ila_0]
set_property C_EN_STRG_QUAL false [get_debug_cores u_ila_0]
set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila_0]
set_property ALL_PROBE_SAME_MU_CNT 1 [get_debug_cores u_ila_0]
connect_debug_port u_ila_0/clk [get_nets [list fmc_sp_to_fpga_clk_IBUF_BUFG ]]
set_property port_width 4 [get_debug_ports u_ila_0/probe0]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe0]
connect_debug_port u_ila_0/probe0 [get_nets [list {fmc_sp_to_fpga_a_IBUF[16]} {fmc_sp_to_fpga_a_IBUF[17]} {fmc_sp_to_fpga_a_IBUF[18]} {fmc_sp_to_fpga_a_IBUF[19]} ]]
create_debug_port u_ila_0 probe
set_property port_width 16 [get_debug_ports u_ila_0/probe1]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe1]
connect_debug_port u_ila_0/probe1 [get_nets [list {fmc_sp_to_fpga_da_IBUF[0]} {fmc_sp_to_fpga_da_IBUF[1]} {fmc_sp_to_fpga_da_IBUF[2]} {fmc_sp_to_fpga_da_IBUF[3]} {fmc_sp_to_fpga_da_IBUF[4]} {fmc_sp_to_fpga_da_IBUF[5]} {fmc_sp_to_fpga_da_IBUF[6]} {fmc_sp_to_fpga_da_IBUF[7]} {fmc_sp_to_fpga_da_IBUF[8]} {fmc_sp_to_fpga_da_IBUF[9]} {fmc_sp_to_fpga_da_IBUF[10]} {fmc_sp_to_fpga_da_IBUF[11]} {fmc_sp_to_fpga_da_IBUF[12]} {fmc_sp_to_fpga_da_IBUF[13]} {fmc_sp_to_fpga_da_IBUF[14]} {fmc_sp_to_fpga_da_IBUF[15]} ]]
create_debug_port u_ila_0 probe
set_property port_width 16 [get_debug_ports u_ila_0/probe2]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe2]
connect_debug_port u_ila_0/probe2 [get_nets [list {fmc_sp_to_fpga_da_OBUF[0]} {fmc_sp_to_fpga_da_OBUF[1]} {fmc_sp_to_fpga_da_OBUF[2]} {fmc_sp_to_fpga_da_OBUF[3]} {fmc_sp_to_fpga_da_OBUF[4]} {fmc_sp_to_fpga_da_OBUF[5]} {fmc_sp_to_fpga_da_OBUF[6]} {fmc_sp_to_fpga_da_OBUF[7]} {fmc_sp_to_fpga_da_OBUF[8]} {fmc_sp_to_fpga_da_OBUF[9]} {fmc_sp_to_fpga_da_OBUF[10]} {fmc_sp_to_fpga_da_OBUF[11]} {fmc_sp_to_fpga_da_OBUF[12]} {fmc_sp_to_fpga_da_OBUF[13]} {fmc_sp_to_fpga_da_OBUF[14]} {fmc_sp_to_fpga_da_OBUF[15]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe3]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe3]
connect_debug_port u_ila_0/probe3 [get_nets [list fmc_sp_to_fpga_adv_l_IBUF ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe4]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe4]
connect_debug_port u_ila_0/probe4 [get_nets [list fmc_sp_to_fpga_cs1_l_IBUF ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe5]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe5]
connect_debug_port u_ila_0/probe5 [get_nets [list fmc_sp_to_fpga_oe_l_IBUF ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe6]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe6]
connect_debug_port u_ila_0/probe6 [get_nets [list fmc_sp_to_fpga_we_l_IBUF ]]