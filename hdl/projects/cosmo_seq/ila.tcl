create_debug_core u_ila_0 ila
set_property C_DATA_DEPTH 4096 [get_debug_cores u_ila_0]
set_property C_TRIGIN_EN false [get_debug_cores u_ila_0]
set_property C_TRIGOUT_EN false [get_debug_cores u_ila_0]
set_property C_ADV_TRIGGER false [get_debug_cores u_ila_0]
set_property C_INPUT_PIPE_STAGES 0 [get_debug_cores u_ila_0]
set_property C_EN_STRG_QUAL false [get_debug_cores u_ila_0]
set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila_0]
set_property ALL_PROBE_SAME_MU_CNT 1 [get_debug_cores u_ila_0]
connect_debug_port u_ila_0/clk [get_nets [list board_support_inst/pll/inst/clk_125m ]]
set_property port_width 8 [get_debug_ports u_ila_0/probe0]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe0]
connect_debug_port u_ila_0/probe0 [get_nets [list {sp5_uart_ss/sp_uart1/pre_fifo_rx_data[0]} {sp5_uart_ss/sp_uart1/pre_fifo_rx_data[1]} {sp5_uart_ss/sp_uart1/pre_fifo_rx_data[2]} {sp5_uart_ss/sp_uart1/pre_fifo_rx_data[3]} {sp5_uart_ss/sp_uart1/pre_fifo_rx_data[4]} {sp5_uart_ss/sp_uart1/pre_fifo_rx_data[5]} {sp5_uart_ss/sp_uart1/pre_fifo_rx_data[6]} {sp5_uart_ss/sp_uart1/pre_fifo_rx_data[7]} ]]
create_debug_port u_ila_0 probe
set_property port_width 7 [get_debug_ports u_ila_0/probe1]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe1]
connect_debug_port u_ila_0/probe1 [get_nets [list {sp5_uart_ss/sp_uart1/tx_fifo_rdata[0]} {sp5_uart_ss/sp_uart1/tx_fifo_rdata[1]} {sp5_uart_ss/sp_uart1/tx_fifo_rdata[2]} {sp5_uart_ss/sp_uart1/tx_fifo_rdata[3]} {sp5_uart_ss/sp_uart1/tx_fifo_rdata[4]} {sp5_uart_ss/sp_uart1/tx_fifo_rdata[5]} {sp5_uart_ss/sp_uart1/tx_fifo_rdata[6]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe2]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe2]
connect_debug_port u_ila_0/probe2 [get_nets [list sp5_uart_ss/sp_uart1/ipcc_from_sp ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe3]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe3]
connect_debug_port u_ila_0/probe3 [get_nets [list sp5_uart_ss/sp_uart1/ipcc_from_sp_rts_l ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe4]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe4]
connect_debug_port u_ila_0/probe4 [get_nets [list sp5_uart_ss/sp_uart1/ipcc_to_sp ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe5]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe5]
connect_debug_port u_ila_0/probe5 [get_nets [list sp5_uart_ss/sp_uart1/ipcc_to_sp_rts_l ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe6]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe6]
connect_debug_port u_ila_0/probe6 [get_nets [list sp5_uart_ss/sp_uart1/uart_tx_ready ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe7]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe7]
connect_debug_port u_ila_0/probe7 [get_nets [list sp5_uart_ss/sp_uart1/pre_fifo_rx_valid ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe8]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe8]
connect_debug_port u_ila_0/probe8 [get_nets [list sp5_uart_ss/sp_uart1/cts_pin_syncd ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe9]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe9]
connect_debug_port u_ila_0/probe9 [get_nets [list sp5_uart_ss/sp_uart1/rx_fifo/wr_en ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe10]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe10]
connect_debug_port u_ila_0/probe10 [get_nets [list sp5_uart_ss/sp_uart1/rx_fifo/rx_fifo_rempty ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe11]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe11]
connect_debug_port u_ila_0/probe11 [get_nets [list sp5_uart_ss/sp_uart1/tx_fifo/empty ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe12]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe12]
connect_debug_port u_ila_0/probe12 [get_nets [list sp5_uart_ss/sp_uart1/tx_fifo/tx_fifo_wfull ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe13]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe13]
connect_debug_port u_ila_0/probe13 [get_nets [list sp5_uart_ss/sp_uart1/tx_fifo/uart_tx_ready ]]