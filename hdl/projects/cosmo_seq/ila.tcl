create_debug_core u_ila_0 ila
set_property C_DATA_DEPTH 1024 [get_debug_cores u_ila_0]
set_property C_TRIGIN_EN false [get_debug_cores u_ila_0]
set_property C_TRIGOUT_EN false [get_debug_cores u_ila_0]
set_property C_ADV_TRIGGER false [get_debug_cores u_ila_0]
set_property C_INPUT_PIPE_STAGES 0 [get_debug_cores u_ila_0]
set_property C_EN_STRG_QUAL false [get_debug_cores u_ila_0]
set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila_0]
set_property ALL_PROBE_SAME_MU_CNT 1 [get_debug_cores u_ila_0]
connect_debug_port u_ila_0/clk [get_nets [list board_support_inst/pll/inst/clk_125m ]]
set_property port_width 32 [get_debug_ports u_ila_0/probe0]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe0]
connect_debug_port u_ila_0/probe0 [get_nets [list {stm32h7_fmc_target_inst/rdata_dcfifo_dut/xpm_fifo_async_inst/din[0]} {stm32h7_fmc_target_inst/rdata_dcfifo_dut/xpm_fifo_async_inst/din[1]} {stm32h7_fmc_target_inst/rdata_dcfifo_dut/xpm_fifo_async_inst/din[2]} {stm32h7_fmc_target_inst/rdata_dcfifo_dut/xpm_fifo_async_inst/din[3]} {stm32h7_fmc_target_inst/rdata_dcfifo_dut/xpm_fifo_async_inst/din[4]} {stm32h7_fmc_target_inst/rdata_dcfifo_dut/xpm_fifo_async_inst/din[5]} {stm32h7_fmc_target_inst/rdata_dcfifo_dut/xpm_fifo_async_inst/din[6]} {stm32h7_fmc_target_inst/rdata_dcfifo_dut/xpm_fifo_async_inst/din[7]} {stm32h7_fmc_target_inst/rdata_dcfifo_dut/xpm_fifo_async_inst/din[8]} {stm32h7_fmc_target_inst/rdata_dcfifo_dut/xpm_fifo_async_inst/din[9]} {stm32h7_fmc_target_inst/rdata_dcfifo_dut/xpm_fifo_async_inst/din[10]} {stm32h7_fmc_target_inst/rdata_dcfifo_dut/xpm_fifo_async_inst/din[11]} {stm32h7_fmc_target_inst/rdata_dcfifo_dut/xpm_fifo_async_inst/din[12]} {stm32h7_fmc_target_inst/rdata_dcfifo_dut/xpm_fifo_async_inst/din[13]} {stm32h7_fmc_target_inst/rdata_dcfifo_dut/xpm_fifo_async_inst/din[14]} {stm32h7_fmc_target_inst/rdata_dcfifo_dut/xpm_fifo_async_inst/din[15]} {stm32h7_fmc_target_inst/rdata_dcfifo_dut/xpm_fifo_async_inst/din[16]} {stm32h7_fmc_target_inst/rdata_dcfifo_dut/xpm_fifo_async_inst/din[17]} {stm32h7_fmc_target_inst/rdata_dcfifo_dut/xpm_fifo_async_inst/din[18]} {stm32h7_fmc_target_inst/rdata_dcfifo_dut/xpm_fifo_async_inst/din[19]} {stm32h7_fmc_target_inst/rdata_dcfifo_dut/xpm_fifo_async_inst/din[20]} {stm32h7_fmc_target_inst/rdata_dcfifo_dut/xpm_fifo_async_inst/din[21]} {stm32h7_fmc_target_inst/rdata_dcfifo_dut/xpm_fifo_async_inst/din[22]} {stm32h7_fmc_target_inst/rdata_dcfifo_dut/xpm_fifo_async_inst/din[23]} {stm32h7_fmc_target_inst/rdata_dcfifo_dut/xpm_fifo_async_inst/din[24]} {stm32h7_fmc_target_inst/rdata_dcfifo_dut/xpm_fifo_async_inst/din[25]} {stm32h7_fmc_target_inst/rdata_dcfifo_dut/xpm_fifo_async_inst/din[26]} {stm32h7_fmc_target_inst/rdata_dcfifo_dut/xpm_fifo_async_inst/din[27]} {stm32h7_fmc_target_inst/rdata_dcfifo_dut/xpm_fifo_async_inst/din[28]} {stm32h7_fmc_target_inst/rdata_dcfifo_dut/xpm_fifo_async_inst/din[29]} {stm32h7_fmc_target_inst/rdata_dcfifo_dut/xpm_fifo_async_inst/din[30]} {stm32h7_fmc_target_inst/rdata_dcfifo_dut/xpm_fifo_async_inst/din[31]} ]]
create_debug_port u_ila_0 probe
set_property port_width 32 [get_debug_ports u_ila_0/probe1]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe1]
connect_debug_port u_ila_0/probe1 [get_nets [list {stm32h7_fmc_target_inst/wdata_dcfifo_dut/xpm_fifo_async_inst/gnuram_async_fifo.xpm_fifo_base_inst/dout[0]} {stm32h7_fmc_target_inst/wdata_dcfifo_dut/xpm_fifo_async_inst/gnuram_async_fifo.xpm_fifo_base_inst/dout[1]} {stm32h7_fmc_target_inst/wdata_dcfifo_dut/xpm_fifo_async_inst/gnuram_async_fifo.xpm_fifo_base_inst/dout[2]} {stm32h7_fmc_target_inst/wdata_dcfifo_dut/xpm_fifo_async_inst/gnuram_async_fifo.xpm_fifo_base_inst/dout[3]} {stm32h7_fmc_target_inst/wdata_dcfifo_dut/xpm_fifo_async_inst/gnuram_async_fifo.xpm_fifo_base_inst/dout[4]} {stm32h7_fmc_target_inst/wdata_dcfifo_dut/xpm_fifo_async_inst/gnuram_async_fifo.xpm_fifo_base_inst/dout[5]} {stm32h7_fmc_target_inst/wdata_dcfifo_dut/xpm_fifo_async_inst/gnuram_async_fifo.xpm_fifo_base_inst/dout[6]} {stm32h7_fmc_target_inst/wdata_dcfifo_dut/xpm_fifo_async_inst/gnuram_async_fifo.xpm_fifo_base_inst/dout[7]} {stm32h7_fmc_target_inst/wdata_dcfifo_dut/xpm_fifo_async_inst/gnuram_async_fifo.xpm_fifo_base_inst/dout[8]} {stm32h7_fmc_target_inst/wdata_dcfifo_dut/xpm_fifo_async_inst/gnuram_async_fifo.xpm_fifo_base_inst/dout[9]} {stm32h7_fmc_target_inst/wdata_dcfifo_dut/xpm_fifo_async_inst/gnuram_async_fifo.xpm_fifo_base_inst/dout[10]} {stm32h7_fmc_target_inst/wdata_dcfifo_dut/xpm_fifo_async_inst/gnuram_async_fifo.xpm_fifo_base_inst/dout[11]} {stm32h7_fmc_target_inst/wdata_dcfifo_dut/xpm_fifo_async_inst/gnuram_async_fifo.xpm_fifo_base_inst/dout[12]} {stm32h7_fmc_target_inst/wdata_dcfifo_dut/xpm_fifo_async_inst/gnuram_async_fifo.xpm_fifo_base_inst/dout[13]} {stm32h7_fmc_target_inst/wdata_dcfifo_dut/xpm_fifo_async_inst/gnuram_async_fifo.xpm_fifo_base_inst/dout[14]} {stm32h7_fmc_target_inst/wdata_dcfifo_dut/xpm_fifo_async_inst/gnuram_async_fifo.xpm_fifo_base_inst/dout[15]} {stm32h7_fmc_target_inst/wdata_dcfifo_dut/xpm_fifo_async_inst/gnuram_async_fifo.xpm_fifo_base_inst/dout[16]} {stm32h7_fmc_target_inst/wdata_dcfifo_dut/xpm_fifo_async_inst/gnuram_async_fifo.xpm_fifo_base_inst/dout[17]} {stm32h7_fmc_target_inst/wdata_dcfifo_dut/xpm_fifo_async_inst/gnuram_async_fifo.xpm_fifo_base_inst/dout[18]} {stm32h7_fmc_target_inst/wdata_dcfifo_dut/xpm_fifo_async_inst/gnuram_async_fifo.xpm_fifo_base_inst/dout[19]} {stm32h7_fmc_target_inst/wdata_dcfifo_dut/xpm_fifo_async_inst/gnuram_async_fifo.xpm_fifo_base_inst/dout[20]} {stm32h7_fmc_target_inst/wdata_dcfifo_dut/xpm_fifo_async_inst/gnuram_async_fifo.xpm_fifo_base_inst/dout[21]} {stm32h7_fmc_target_inst/wdata_dcfifo_dut/xpm_fifo_async_inst/gnuram_async_fifo.xpm_fifo_base_inst/dout[22]} {stm32h7_fmc_target_inst/wdata_dcfifo_dut/xpm_fifo_async_inst/gnuram_async_fifo.xpm_fifo_base_inst/dout[23]} {stm32h7_fmc_target_inst/wdata_dcfifo_dut/xpm_fifo_async_inst/gnuram_async_fifo.xpm_fifo_base_inst/dout[24]} {stm32h7_fmc_target_inst/wdata_dcfifo_dut/xpm_fifo_async_inst/gnuram_async_fifo.xpm_fifo_base_inst/dout[25]} {stm32h7_fmc_target_inst/wdata_dcfifo_dut/xpm_fifo_async_inst/gnuram_async_fifo.xpm_fifo_base_inst/dout[26]} {stm32h7_fmc_target_inst/wdata_dcfifo_dut/xpm_fifo_async_inst/gnuram_async_fifo.xpm_fifo_base_inst/dout[27]} {stm32h7_fmc_target_inst/wdata_dcfifo_dut/xpm_fifo_async_inst/gnuram_async_fifo.xpm_fifo_base_inst/dout[28]} {stm32h7_fmc_target_inst/wdata_dcfifo_dut/xpm_fifo_async_inst/gnuram_async_fifo.xpm_fifo_base_inst/dout[29]} {stm32h7_fmc_target_inst/wdata_dcfifo_dut/xpm_fifo_async_inst/gnuram_async_fifo.xpm_fifo_base_inst/dout[30]} {stm32h7_fmc_target_inst/wdata_dcfifo_dut/xpm_fifo_async_inst/gnuram_async_fifo.xpm_fifo_base_inst/dout[31]} ]]
create_debug_port u_ila_0 probe
set_property port_width 32 [get_debug_ports u_ila_0/probe2]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe2]
connect_debug_port u_ila_0/probe2 [get_nets [list {stm32h7_fmc_target_inst/txn_dcfifo_dut/xpm_fifo_async_inst/gnuram_async_fifo.xpm_fifo_base_inst/dout[0]} {stm32h7_fmc_target_inst/txn_dcfifo_dut/xpm_fifo_async_inst/gnuram_async_fifo.xpm_fifo_base_inst/dout[1]} {stm32h7_fmc_target_inst/txn_dcfifo_dut/xpm_fifo_async_inst/gnuram_async_fifo.xpm_fifo_base_inst/dout[2]} {stm32h7_fmc_target_inst/txn_dcfifo_dut/xpm_fifo_async_inst/gnuram_async_fifo.xpm_fifo_base_inst/dout[3]} {stm32h7_fmc_target_inst/txn_dcfifo_dut/xpm_fifo_async_inst/gnuram_async_fifo.xpm_fifo_base_inst/dout[4]} {stm32h7_fmc_target_inst/txn_dcfifo_dut/xpm_fifo_async_inst/gnuram_async_fifo.xpm_fifo_base_inst/dout[5]} {stm32h7_fmc_target_inst/txn_dcfifo_dut/xpm_fifo_async_inst/gnuram_async_fifo.xpm_fifo_base_inst/dout[6]} {stm32h7_fmc_target_inst/txn_dcfifo_dut/xpm_fifo_async_inst/gnuram_async_fifo.xpm_fifo_base_inst/dout[7]} {stm32h7_fmc_target_inst/txn_dcfifo_dut/xpm_fifo_async_inst/gnuram_async_fifo.xpm_fifo_base_inst/dout[8]} {stm32h7_fmc_target_inst/txn_dcfifo_dut/xpm_fifo_async_inst/gnuram_async_fifo.xpm_fifo_base_inst/dout[9]} {stm32h7_fmc_target_inst/txn_dcfifo_dut/xpm_fifo_async_inst/gnuram_async_fifo.xpm_fifo_base_inst/dout[10]} {stm32h7_fmc_target_inst/txn_dcfifo_dut/xpm_fifo_async_inst/gnuram_async_fifo.xpm_fifo_base_inst/dout[11]} {stm32h7_fmc_target_inst/txn_dcfifo_dut/xpm_fifo_async_inst/gnuram_async_fifo.xpm_fifo_base_inst/dout[12]} {stm32h7_fmc_target_inst/txn_dcfifo_dut/xpm_fifo_async_inst/gnuram_async_fifo.xpm_fifo_base_inst/dout[13]} {stm32h7_fmc_target_inst/txn_dcfifo_dut/xpm_fifo_async_inst/gnuram_async_fifo.xpm_fifo_base_inst/dout[14]} {stm32h7_fmc_target_inst/txn_dcfifo_dut/xpm_fifo_async_inst/gnuram_async_fifo.xpm_fifo_base_inst/dout[15]} {stm32h7_fmc_target_inst/txn_dcfifo_dut/xpm_fifo_async_inst/gnuram_async_fifo.xpm_fifo_base_inst/dout[16]} {stm32h7_fmc_target_inst/txn_dcfifo_dut/xpm_fifo_async_inst/gnuram_async_fifo.xpm_fifo_base_inst/dout[17]} {stm32h7_fmc_target_inst/txn_dcfifo_dut/xpm_fifo_async_inst/gnuram_async_fifo.xpm_fifo_base_inst/dout[18]} {stm32h7_fmc_target_inst/txn_dcfifo_dut/xpm_fifo_async_inst/gnuram_async_fifo.xpm_fifo_base_inst/dout[19]} {stm32h7_fmc_target_inst/txn_dcfifo_dut/xpm_fifo_async_inst/gnuram_async_fifo.xpm_fifo_base_inst/dout[20]} {stm32h7_fmc_target_inst/txn_dcfifo_dut/xpm_fifo_async_inst/gnuram_async_fifo.xpm_fifo_base_inst/dout[21]} {stm32h7_fmc_target_inst/txn_dcfifo_dut/xpm_fifo_async_inst/gnuram_async_fifo.xpm_fifo_base_inst/dout[22]} {stm32h7_fmc_target_inst/txn_dcfifo_dut/xpm_fifo_async_inst/gnuram_async_fifo.xpm_fifo_base_inst/dout[23]} {stm32h7_fmc_target_inst/txn_dcfifo_dut/xpm_fifo_async_inst/gnuram_async_fifo.xpm_fifo_base_inst/dout[24]} {stm32h7_fmc_target_inst/txn_dcfifo_dut/xpm_fifo_async_inst/gnuram_async_fifo.xpm_fifo_base_inst/dout[25]} {stm32h7_fmc_target_inst/txn_dcfifo_dut/xpm_fifo_async_inst/gnuram_async_fifo.xpm_fifo_base_inst/dout[26]} {stm32h7_fmc_target_inst/txn_dcfifo_dut/xpm_fifo_async_inst/gnuram_async_fifo.xpm_fifo_base_inst/dout[27]} {stm32h7_fmc_target_inst/txn_dcfifo_dut/xpm_fifo_async_inst/gnuram_async_fifo.xpm_fifo_base_inst/dout[28]} {stm32h7_fmc_target_inst/txn_dcfifo_dut/xpm_fifo_async_inst/gnuram_async_fifo.xpm_fifo_base_inst/dout[29]} {stm32h7_fmc_target_inst/txn_dcfifo_dut/xpm_fifo_async_inst/gnuram_async_fifo.xpm_fifo_base_inst/dout[30]} {stm32h7_fmc_target_inst/txn_dcfifo_dut/xpm_fifo_async_inst/gnuram_async_fifo.xpm_fifo_base_inst/dout[31]} ]]
create_debug_port u_ila_0 probe
set_property port_width 3 [get_debug_ports u_ila_0/probe3]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe3]
connect_debug_port u_ila_0/probe3 [get_nets [list {axil_interconnect_inst/responder_sel[0]} {axil_interconnect_inst/responder_sel[1]} {axil_interconnect_inst/responder_sel[2]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe4]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe4]
connect_debug_port u_ila_0/probe4 [get_nets [list sp5_hotplug_subsystem_inst/pca9506_top_inst/pca9506_regs_inst/active_read ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe5]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe5]
connect_debug_port u_ila_0/probe5 [get_nets [list sp5_hotplug_subsystem_inst/pca9506_top_inst/pca9506_regs_inst/active_write ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe6]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe6]
connect_debug_port u_ila_0/probe6 [get_nets [list sp5_hotplug_subsystem_inst/pca9506_top_inst/pca9506_regs_inst/axil_target_txn_inst/debug_active_read ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe7]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe7]
connect_debug_port u_ila_0/probe7 [get_nets [list sp5_hotplug_subsystem_inst/pca9506_top_inst/pca9506_regs_inst/axil_target_txn_inst/debug_active_write ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe8]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe8]
connect_debug_port u_ila_0/probe8 [get_nets [list sp5_hotplug_subsystem_inst/pca9506_top_inst/pca9506_regs_inst/axil_target_txn_inst/debug_rready ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe9]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe9]
connect_debug_port u_ila_0/probe9 [get_nets [list sp5_hotplug_subsystem_inst/pca9506_top_inst/pca9506_regs_inst/axil_target_txn_inst/debug_rvalid ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe10]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe10]
connect_debug_port u_ila_0/probe10 [get_nets [list sp5_hotplug_subsystem_inst/pca9506_top_inst/pca9506_regs_inst/axil_target_txn_inst/debug_wready ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe11]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe11]
connect_debug_port u_ila_0/probe11 [get_nets [list sp5_hotplug_subsystem_inst/pca9506_top_inst/pca9506_regs_inst/axil_target_txn_inst/debug_wvalid ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe12]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe12]
connect_debug_port u_ila_0/probe12 [get_nets [list {axil_interconnect_inst/axil_interconnect_2k8_inst/fmc_axi_if[read_data][ready]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe13]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe13]
connect_debug_port u_ila_0/probe13 [get_nets [list {axil_interconnect_inst/axil_interconnect_2k8_inst/fmc_axi_if[read_data][valid]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe14]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe14]
connect_debug_port u_ila_0/probe14 [get_nets [list {axil_interconnect_inst/axil_interconnect_2k8_inst/fmc_axi_if[write_address][valid]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe15]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe15]
connect_debug_port u_ila_0/probe15 [get_nets [list {axil_interconnect_inst/axil_interconnect_2k8_inst/fmc_axi_if[write_data][valid]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe16]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe16]
connect_debug_port u_ila_0/probe16 [get_nets [list {axil_interconnect_inst/axil_interconnect_2k8_inst/fmc_axi_if[write_response][ready]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe17]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe17]
connect_debug_port u_ila_0/probe17 [get_nets [list {axil_interconnect_inst/axil_interconnect_2k8_inst/fmc_axi_if[write_response][valid]} ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe18]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe18]
connect_debug_port u_ila_0/probe18 [get_nets [list stm32h7_fmc_target_inst/txn_dcfifo_dut/xpm_fifo_async_inst/gnuram_async_fifo.xpm_fifo_base_inst/rd_en ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe19]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe19]
connect_debug_port u_ila_0/probe19 [get_nets [list stm32h7_fmc_target_inst/rdata_dcfifo_dut/xpm_fifo_async_inst/wr_en ]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe20]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe20]
connect_debug_port u_ila_0/probe20 [get_nets [list stm32h7_fmc_target_inst/wdata_dcfifo_dut/xpm_fifo_async_inst/gnuram_async_fifo.xpm_fifo_base_inst/rd_en ]]