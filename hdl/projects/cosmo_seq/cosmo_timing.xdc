create_clock -add -name sys_clk_pin -period 20.000 -waveform {0 10.000}  [get_ports { clk_50mhz_fpga1_1 }];
create_clock -add -name fmc_clk_pin -period 15.000 -waveform {0 7.500}  [get_ports { fmc_sp_to_fpga1_clk }];

#
# FMC interface constraints
# Create a virtual clock, to represent the source clock of the FMC interface
create_clock -name fmc_virt_clk -period 15.000;

set_clock_groups -asynchronous -group {fmc_clk_pin fmc_virt_clk} -group {clk_125m_cosmo_pll} -group {clk_200m_cosmo_pll}


# #######################
# FMC Interface
# #######################

# FPGA's input delays have to be low enough that they don't run into the uncertainty region due to any possible skew.
# skew_bre is the shortests trace delay vs the clock, and skew_are is the longest trace delay vs the clock.
# On grapefruit, clock trace is 61.195mm.  shortest trace is FMC_SP_TO_FPGA_BL1_L at 60.504mm, longest is FMC_SP_TO_FPGA_BL0_L at 65.116mm
# 6.8ns per m so 61.195-60.504 = 0.691mm * 6.8ns/m = 0.0047ns skew_bre
# 65.116-61.195 = 3.921mm * 6.8ns/m = 0.0266ns skew_are

# Also note that the SP changes outputs only on the *falling* edge of the fmc clock, which means there's a phase-shift

# in delay max = tco_ext to max delay ext to fpga
# in delay min = minTco_ext to min delay ext to fpga
# chipsel example: 
# Since data comes out on the falling edge, but we didn't shift the clock,
# we need to add an additional 1/2 period to the TCO_exts so
# max= 7.5ns (1/2 period) + 1ns (maxreal tco) + 0.0266ns max skew
# min= 7.5ns (1/2 period) + 0ns (min real tco) + 0.0047 min skew
set_input_delay -clock fmc_virt_clk -max 8.527 [get_ports fmc_sp_to_fpga1_cs_l]
set_input_delay -clock fmc_virt_clk -min 7.505 [get_ports fmc_sp_to_fpga1_cs_l]
set_input_delay -clock fmc_virt_clk -max 8.527 [get_ports fmc_sp_to_fpga1_we_l]
set_input_delay -clock fmc_virt_clk -min 7.505 [get_ports fmc_sp_to_fpga1_we_l]
set_input_delay -clock fmc_virt_clk -max 8.527 [get_ports fmc_sp_to_fpga1_oe_l]
set_input_delay -clock fmc_virt_clk -min 7.505 [get_ports fmc_sp_to_fpga1_oe_l]
set_input_delay -clock fmc_virt_clk -max 8.527 [get_ports fmc_sp_to_fpga1_adv_l]
set_input_delay -clock fmc_virt_clk -min 7.505 [get_ports fmc_sp_to_fpga1_adv_l]
set_input_delay -clock fmc_virt_clk -max 8.527 [get_ports fmc_sp_to_fpga1_bl_l]
set_input_delay -clock fmc_virt_clk -min 7.005 [get_ports fmc_sp_to_fpga1_bl_l]
# Address has diff relationship
# max= 7.5ns (1/2 period) + 2.5ns (maxreal tco) + 0.0266ns max skew
# min= 7.5ns (1/2 period) + 0ns (min real tco) + 0.0047ns max skew
set_input_delay -clock fmc_virt_clk -max 10.027 [get_ports fmc_sp_to_fpga1_a[*]]
set_input_delay -clock fmc_virt_clk -min 7.505 [get_ports fmc_sp_to_fpga1_a[*]]
# Data in has diff relationship
# max= 7.5ns (1/2 period) + 3ns (maxreal tco) + 0.0266ns max skew
# min= 7.5ns (1/2 period) + 0ns (min real tco) + 0.0047ns max skew
set_input_delay -clock fmc_virt_clk -max 10.527 [get_ports fmc_sp_to_fpga1_da[*]]
set_input_delay -clock fmc_virt_clk -min 7.505 [get_ports fmc_sp_to_fpga1_da[*]]

# out delay max = ext setup + max delay fpga to external
# out delay min = ext hold + min delay fpga to external

# max = 3ns (SP's needed setup time) + return delay (60.797mm)
# max = 3ns (SP's needed setup time) + 0.414 ns
# min = 1 ns (SP's needed hold time) + 0.414 ns
set_output_delay -clock fmc_virt_clk -max 3.414 [get_ports fmc_sp_to_fpga1_wait_l]
set_output_delay -clock fmc_virt_clk -min 1.414 [get_ports fmc_sp_to_fpga1_wait_l]

# max = 3ns (SP's needed setup time) + clock delay to FPGA (61.195mm) + return delay (63.985mm)
# max = 3ns (SP's needed setup time) + 0.851 ns
# min = 0 ns (SP's needed hold time) + 0.851 ns
set_output_delay -clock fmc_virt_clk -max 3.851 [get_ports fmc_sp_to_fpga1_da[*]]
set_output_delay -clock fmc_virt_clk -min 0.830 [get_ports fmc_sp_to_fpga1_da[*]]

set_multicycle_path -from [get_pins {stm32h7_fmc_target_inst/data_out*/C}] -to [get_ports {fmc_sp_to_fpga1_da[*]}] -setup 2
set_multicycle_path -from [get_pins {stm32h7_fmc_target_inst/data_out*/C}] -to [get_ports {fmc_sp_to_fpga1_da[*]}] -hold 1
set_multicycle_path -from [get_pins {stm32h7_fmc_target_inst/data_out_en_reg*/C}] -to [get_ports {fmc_sp_to_fpga1_da[*]}] -setup 2
set_multicycle_path -from [get_pins {stm32h7_fmc_target_inst/data_out_en_reg*/C}] -to [get_ports {fmc_sp_to_fpga1_da[*]}] -hold 1

set_false_path -from [get_nets *] -to [get_ports {fpga1_spare_v3p3*}]
set_false_path -from [get_nets *] -to [get_ports {fpga1_spare_v1p8[*]}]

# #######################
# eSPI Interface
# #######################
# TODO: This is likely not correct but I need to re-write the link-layer logic again
# and then re-constrain
# 20MHz espi constraints, 50ns clock periods.
# ESPI interface has 2.2ns of trace delay
# AMD says 7ns of data setup
# AMD says 0.3ns of data hold
# AMD Data output valid time min 1 max 3
# in delay max = tco_ext to max delay ext to fpga
# in delay min = minTco_ext to min delay ext to fpga
# out delay max = ext setup + max delay fpga to external
# out delay min = ext hold + min delay fpga to external

# when sending to the SP5, it's going to take 2.2ns of trace time, and it needs to be there
# Clock took 2.2 ns to get to us, it's going to take 2.2ns of trace time to get back to the SP5
# and SP5 wants 7 ns of setup time. We also eat ~4ns by syncing the espi clock.

# outputs
# max = 7ns (SP5's needed setup time) + clock delay to FPGA (2.2ns) + return delay (2.2ns)
# min = .3ns (SP5's needed hold time) + clock delay to FPGA (2.2ns) + return delay (2.2ns)


# Data 
# max= 7.5ns (1/2 period) + 3ns (maxreal tco)
# min= 7.5ns (1/2 period) + 1ns (min real tco)

# This is a stop-gap to provide some kind of output timing constraints per the eSPI base spec
set_max_delay -to [get_ports espi0_sp5_to_fpga1_dat[*]] 6
set_min_delay -to [get_ports espi0_sp5_to_fpga1_dat[*]] 0