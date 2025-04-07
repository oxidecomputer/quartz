create_debug_core u_ila_0 ila
set_property C_DATA_DEPTH 4096 [get_debug_cores u_ila_0]
set_property C_TRIGIN_EN false [get_debug_cores u_ila_0]
set_property C_TRIGOUT_EN false [get_debug_cores u_ila_0]
set_property C_ADV_TRIGGER false [get_debug_cores u_ila_0]
set_property C_INPUT_PIPE_STAGES 0 [get_debug_cores u_ila_0]
set_property C_EN_STRG_QUAL false [get_debug_cores u_ila_0]
set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila_0]
set_property ALL_PROBE_SAME_MU_CNT 1 [get_debug_cores u_ila_0]
connect_debug_port u_ila_0/clk [get_nets [list fmc_sp_to_fpga1_clk_IBUF_BUFG ]]
set_property port_width 4 [get_debug_ports u_ila_0/probe0]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe0]
connect_debug_port u_ila_0/probe0 [get_nets [list {stm32h7_fmc_target_inst/fmc_state[0]} {stm32h7_fmc_target_inst/fmc_state[1]} {stm32h7_fmc_target_inst/fmc_state[2]} {stm32h7_fmc_target_inst/fmc_state[3]} ]]
create_debug_port u_ila_0 probe
set_property port_width 26 [get_debug_ports u_ila_0/probe1]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe1]
connect_debug_port u_ila_0/probe1 [get_nets [list {stm32h7_fmc_target_inst/txn[addr][0]} {stm32h7_fmc_target_inst/txn[addr][1]} {stm32h7_fmc_target_inst/txn[addr][2]} {stm32h7_fmc_target_inst/txn[addr][3]} {stm32h7_fmc_target_inst/txn[addr][4]} {stm32h7_fmc_target_inst/txn[addr][5]} {stm32h7_fmc_target_inst/txn[addr][6]} {stm32h7_fmc_target_inst/txn[addr][7]} {stm32h7_fmc_target_inst/txn[addr][8]} {stm32h7_fmc_target_inst/txn[addr][9]} {stm32h7_fmc_target_inst/txn[addr][10]} {stm32h7_fmc_target_inst/txn[addr][11]} {stm32h7_fmc_target_inst/txn[addr][12]} {stm32h7_fmc_target_inst/txn[addr][13]} {stm32h7_fmc_target_inst/txn[addr][14]} {stm32h7_fmc_target_inst/txn[addr][15]} {stm32h7_fmc_target_inst/txn[addr][16]} {stm32h7_fmc_target_inst/txn[addr][17]} {stm32h7_fmc_target_inst/txn[addr][18]} {stm32h7_fmc_target_inst/txn[addr][19]} {stm32h7_fmc_target_inst/txn[addr][20]} {stm32h7_fmc_target_inst/txn[addr][21]} {stm32h7_fmc_target_inst/txn[addr][22]} {stm32h7_fmc_target_inst/txn[addr][23]} {stm32h7_fmc_target_inst/txn[addr][24]} {stm32h7_fmc_target_inst/txn[addr][25]} ]]
create_debug_port u_ila_0 probe
set_property port_width 4 [get_debug_ports u_ila_0/probe2]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe2]
connect_debug_port u_ila_0/probe2 [get_nets [list {fmc_sp_to_fpga1_a_IBUF[16]} {fmc_sp_to_fpga1_a_IBUF[17]} {fmc_sp_to_fpga1_a_IBUF[18]} {fmc_sp_to_fpga1_a_IBUF[19]} ]]
create_debug_port u_ila_0 probe
set_property port_width 16 [get_debug_ports u_ila_0/probe3]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe3]
connect_debug_port u_ila_0/probe3 [get_nets [list {fmc_sp_to_fpga1_da_IBUF[0]} {fmc_sp_to_fpga1_da_IBUF[1]} {fmc_sp_to_fpga1_da_IBUF[2]} {fmc_sp_to_fpga1_da_IBUF[3]} {fmc_sp_to_fpga1_da_IBUF[4]} {fmc_sp_to_fpga1_da_IBUF[5]} {fmc_sp_to_fpga1_da_IBUF[6]} {fmc_sp_to_fpga1_da_IBUF[7]} {fmc_sp_to_fpga1_da_IBUF[8]} {fmc_sp_to_fpga1_da_IBUF[9]} {fmc_sp_to_fpga1_da_IBUF[10]} {fmc_sp_to_fpga1_da_IBUF[11]} {fmc_sp_to_fpga1_da_IBUF[12]} {fmc_sp_to_fpga1_da_IBUF[13]} {fmc_sp_to_fpga1_da_IBUF[14]} {fmc_sp_to_fpga1_da_IBUF[15]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe4]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe4]
connect_debug_port u_ila_0/probe4 [get_nets [list {stm32h7_fmc_target_inst/txn[read_not_write]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe5]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe5]
connect_debug_port u_ila_0/probe5 [get_nets [list fmc_sp_to_fpga1_adv_l_IBUF ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe6]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe6]
connect_debug_port u_ila_0/probe6 [get_nets [list fmc_sp_to_fpga1_cs_l_IBUF ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe7]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe7]
connect_debug_port u_ila_0/probe7 [get_nets [list fmc_sp_to_fpga1_oe_l_IBUF ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe8]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe8]
connect_debug_port u_ila_0/probe8 [get_nets [list fmc_sp_to_fpga1_wait_l_OBUF ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe9]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe9]
connect_debug_port u_ila_0/probe9 [get_nets [list fmc_sp_to_fpga1_we_l_IBUF ]]