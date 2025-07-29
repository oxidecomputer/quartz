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

# SP output a continuous clock here.
# The FMC interface is clocked at 66.67MHz, which is a 15ns period.
# FPGA's input delays have to be low enough that they don't run into the uncertainty region due to any possible skew.
# skew_bre is the shortest trace delay vs the clock, and skew_are is the longest trace delay vs the clock.
# On cosmo, clock trace is 60.787 rev1, 53.026mm rev2 .  
# shortest trace rev1 is FMC_SP_TO_FPGA1_A22 at 58.956, rev2 is FMC_SP_TO_FPGA1_DA14 at 52.54
# longest trace rev1 (ignoring BL) is FMC_SP_TO_FPGA1_DA5 at 61.565, rev2 is FMC_SP_TO_FPGA1_A20 at 54.473

# Max clock delay to FPGA: 60.787mm * 6.8ns/m = 0.4134 ns (rev1 longest)
set max_clock_delay 0.4134
# Min clock delay to FPGA: 53.026mm * 6.8ns/m = 0.3602 ns (rev2 shortest)
set min_clock_delay 0.3602
# Max data delay between SP and FPGA: 61.565mm * 6.8ns/m = 0.4186 ns (rev1 longest)
set max_data_delay 0.4186
# Min data delay between SP and FPGA: 52.54mm * 6.8ns/m = 0.3573 ns (rev2 shortest)
set min_data_delay 0.3573
# Max wait delay between SP and FPGA: 60.787*6.8ns/m = 0.4134 ns (rev1 longest)
set max_wait_delay 0.4134
# Min wait delay between SP and FPGA: 53.467*6.8ns/m = 0.3635 ns (rev1 longest)
set min_wait_delay 0.3635

# #################
# Input constraints.
# Effectively longest data delay, fastest clock arrival at FPGA.
# input_max = clk_ext_delay_max + extTco_max + board_delay_max - fpga_clk_delay_min
# Effectively shortest data delay, slowest clock arrival at FPGA.
# input_min = clk_ext_delay_min + extTco_min + board_delay_min - fpga_clk_delay_max

# For the inputs data valid before rising edge can be calculated based on the SP's datasheet timings and trace delays.
# td(CLKL-NExL) clock to out is max 1ns
# td(CLKH_NExH) is min 
# td(CLKL-AV) 2.5ns
# td(CLKH-AIV) 8ns?
# td(CLKL-NOEL) 1.5ns
# td(CLKH-NOEH) 7.5ns
# td(CLKL-ADV) 3 ns
# td(CLKL-ADIV) 0 ns
# tsu(ADV-CLKH) 3 ns
# th(CLKH-ADV) 0
# tsu(NWAIT-CLKH) 3 ns (worst read timing)
# th(CLKH-NWAIT) 2 ns (worst write timing)

# Source sync so external_clk_delay is 0.
# Setup time is 1ns, and we include the 1/2 period due to SP  shifting the data out on the falling edge.
set sp_output_half_period 7.5
set sp_0_hold 0
set sp_clk_delay 0

# We have our  1/2 period of 7.5 ns due to SP outputting on falling edges, plus the td in the datasheet
set td_clkl_nehl 1
set nl_output_delay [expr {sp_output_half_period + td_clkl_nehl}]
set max_nl expr [expr {$sp_clk_delay + $nl_output_delay + $max_data_delay - $min_clock_delay}]
# latest clock, earliest data. We assume a hold time of 0 for the SP.
# min external: fastest data, slowest clock
set min_nl expr [expr {$sp_clk_delay + $sp_0_hold + $min_data_delay - $max_clock_delay}]\

# Apply to all of these pins with similar or better timing relationships.
set_input_delay -clock fmc_virt_clk -max $max_nl [get_ports fmc_sp_to_fpga1_cs_l]
set_input_delay -clock fmc_virt_clk -min $min_nl [get_ports fmc_sp_to_fpga1_cs_l]
set_input_delay -clock fmc_virt_clk -max $max_nl [get_ports fmc_sp_to_fpga1_we_l]
set_input_delay -clock fmc_virt_clk -min $min_nl [get_ports fmc_sp_to_fpga1_we_l]
set_input_delay -clock fmc_virt_clk -max $max_nl [get_ports fmc_sp_to_fpga1_oe_l]
set_input_delay -clock fmc_virt_clk -min $min_nl [get_ports fmc_sp_to_fpga1_oe_l]
set_input_delay -clock fmc_virt_clk -max $max_nl [get_ports fmc_sp_to_fpga1_adv_l]
set_input_delay -clock fmc_virt_clk -min $min_nl [get_ports fmc_sp_to_fpga1_adv_l]
set_input_delay -clock fmc_virt_clk -max $max_nl [get_ports fmc_sp_to_fpga1_bl_l]
set_input_delay -clock fmc_virt_clk -min $min_nl [get_ports fmc_sp_to_fpga1_bl_l]

# Address has diff relationship 2.5ns (max tco)
set td_clkl_av 2.5
set a_output_delay [expr {sp_output_half_period + td_clkl_av}]
set max_a expr [expr {$sp_clk_delay + $a_output_delay + $max_data_delay - $min_clock_delay}]
# Still 0 hold on these pins.
set min_a expr [expr {$sp_clk_delay + $sp_0_hold + $min_data_delay - $max_clock_delay}]
set_input_delay -clock fmc_virt_clk -max $max_a [get_ports fmc_sp_to_fpga1_a[*]]
set_input_delay -clock fmc_virt_clk -min $min_a [get_ports fmc_sp_to_fpga1_a[*]]

# Data in has diff relationship 3ns (max tco)
set  td_clkl_adv 3
set ad_output_delay [expr {sp_output_half_period + td_clkl_adv}]
set max_ad expr [expr {$sp_clk_delay + $ad_output_delay + $max_data_delay - $min_clock_delay}]
# Still 0 hold on these pins.
set min_ad expr [expr {$sp_clk_delay + $sp_0_hold + $min_data_delay - $max_clock_delay}]
set_input_delay -clock fmc_virt_clk -max $max_ad [get_ports fmc_sp_to_fpga1_da[*]]
set_input_delay -clock fmc_virt_clk -min $min_ad [get_ports fmc_sp_to_fpga1_da[*]]

#### END Of inputs

# #################
# Output constraints.
# Effectively need to meet setup time with longest FPGA data delay and fastest clock arrival at other device.
# output_max = fpga_clk_delay_max + board_delay_max + extTsu - ext_clk_delay_min
# Effectively need to meet hold time with shortest FPGA data delay and slowest clock arrival at other device.
# input_min = fpga_clk_delay_min + board_delay_min - extTh - ext_clk_delay_max

# Ext setup time is 3ns
set tsu_nwait_clkh 3
# SP rising edge samples so 0 clock delay at external device.
set max_wait expr [expr {$tsu_nwait_clkh + $max_wait_delay + $max_clock_delay - $sp_clk_delay}]
# Ext hold time is 2ns, still 0 clock delay at external device.
set  th_clkh_nwait  2
set min_wait expr [expr {$min_clock_delay + $min_wait_delay - $th_clkh_nwait - $sp_clk_delay}]
set_output_delay -clock fmc_virt_clk -max max_wait [get_ports fmc_sp_to_fpga1_wait_l]
set_output_delay -clock fmc_virt_clk -min min_wait [get_ports fmc_sp_to_fpga1_wait_l]

# Ext setup time is 3ns
set  tsu_adv_clkh 3
# Ext hold time is 0ns
set th_clkh_adv 0
# Still 0 clk delay at external device
set max_da expr [expr {$tsu_adv_clkh + $max_data_delay + $max_clock_delay - $sp_clk_delay}]
set min_da expr [expr {$min_data_delay - $th_clkh_adv + $min_clock_delay - $sp_clk_delay}]
set_output_delay -clock fmc_virt_clk -max $max_da [get_ports fmc_sp_to_fpga1_da[*]]
set_output_delay -clock fmc_virt_clk -min $min_da[get_ports fmc_sp_to_fpga1_da[*]]


# assuming wait_l works, we have multiple cycles to get the data out. This is likely needed due to the tri-state stuff here
# and it has trouble meeting timing without the additional cycles. The fpga design compensates for this with wait_l.
set_multicycle_path -from [get_pins {stm32h7_fmc_target_inst/data_out*/C}] -to [get_ports {fmc_sp_to_fpga1_da[*]}] -setup 2
set_multicycle_path -from [get_pins {stm32h7_fmc_target_inst/data_out*/C}] -to [get_ports {fmc_sp_to_fpga1_da[*]}] -hold 1
set_multicycle_path -from [get_pins {stm32h7_fmc_target_inst/data_out_en_reg*/C}] -to [get_ports {fmc_sp_to_fpga1_da[*]}] -setup 2
set_multicycle_path -from [get_pins {stm32h7_fmc_target_inst/data_out_en_reg*/C}] -to [get_ports {fmc_sp_to_fpga1_da[*]}] -hold 1

# End FMC

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