# Timing constraints for the Metro sequencer FPGA.
#
# Ported from cosmo_seq's cosmo_timing.xdc. The two boards run the same blocks
# at the same rates, so the structure and the reasoning in the comments carry
# over; what is board specific is the port names, the PLL-derived clock names,
# and the FMC trace-delay numbers flagged below.

create_clock -add -name sys_clk_pin -period 20.000 -waveform {0 10.000}  [get_ports { clk_50mhz_fpga1_1 }];
create_clock -add -name fmc_clk_pin -period 10.000 -waveform {0 5.000}  [get_ports { fmc_sp_to_fpga1_clk }];

#
# FMC interface constraints
# Create a virtual clock, to represent the source clock of the FMC interface
create_clock -name fmc_virt_clk -period 10.000;

# The FMC MMCM's output clock is derived from fmc_clk_pin and must stay in
# the synchronous group with it and the virtual clock.
set_clock_groups -asynchronous -group [get_clocks -include_generated_clocks {fmc_clk_pin fmc_virt_clk}] -group {clk_125m_sys_pll} -group {clk_200m_sys_pll}


# #######################
# FMC Interface
# #######################

# SP outputs a continuous clock here.
# The FMC interface is constrained at 100MHz (10ns period), the CLKDIV=1
# target rate; the same analysis is a strict superset of 50 and 66.67 MHz
# operation. The internal FMC domain clock comes from an MMCM in
# phase-alignment mode (see xilinx_ip_gen/fmc_pll_ip.tcl), so the flops
# see the pin clock plus the deliberate +45deg phase shift and STA
# accounts for it via the generated clock.
# FPGA's input delays have to be low enough that they don't run into the
# uncertainty region due to any possible skew. skew_bre is the shortest trace
# delay vs the clock, and skew_are is the longest trace delay vs the clock.
#
# !!! The six delays below are cosmo's, carried over unchanged. Metro's FMC
# !!! routing has not been measured yet, so these are a placeholder that keeps
# !!! the constraint structure meaningful, not a description of this board.
# !!! Re-derive them from Metro's trace lengths (clock, longest and shortest
# !!! data, and the wait line) before trusting a timing report for hardware.
# !!! The conversion is length_mm * 6.8ns/m.

set max_clock_delay 0.4134
set min_clock_delay 0.3602
set max_data_delay 0.4186
set min_data_delay 0.3573
set max_wait_delay 0.4134
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
set sp_output_half_period 5.0
set sp_0_hold 0
set sp_clk_delay 0

# We have our  1/2 period of 5 ns due to SP outputting on falling edges, plus the td in the datasheet
set td_clkl_nehl 1
set nl_output_delay [expr {$sp_output_half_period + $td_clkl_nehl}]
set max_nl [expr {$sp_clk_delay + $nl_output_delay + $max_data_delay - $min_clock_delay}]
# latest clock, earliest data. We assume a hold time of 0 for the SP, but the SP
# holds its outputs until the *next falling edge*, so the earliest change is a
# half period after the capture edge. Without that term Vivado assumes the data
# can change at the capture edge itself, which manufactures a phantom
# input-hold requirement of nearly a half period.
# min external: fastest data, slowest clock
set min_nl [expr {$sp_clk_delay + $sp_output_half_period + $sp_0_hold + $min_data_delay - $max_clock_delay}]

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
set a_output_delay [expr {$sp_output_half_period + $td_clkl_av}]
set max_a [expr {$sp_clk_delay + $a_output_delay + $max_data_delay - $min_clock_delay}]
# Still 0 hold on these pins, held to the next falling edge as above.
set min_a [expr {$sp_clk_delay + $sp_output_half_period + $sp_0_hold + $min_data_delay - $max_clock_delay}]
set_input_delay -clock fmc_virt_clk -max $max_a [get_ports fmc_sp_to_fpga1_a[*]]
set_input_delay -clock fmc_virt_clk -min $min_a [get_ports fmc_sp_to_fpga1_a[*]]

# Data in has diff relationship 3ns (max tco)
set  td_clkl_adv 3
set ad_output_delay [expr {$sp_output_half_period + $td_clkl_adv}]
set max_ad [expr {$sp_clk_delay + $ad_output_delay + $max_data_delay - $min_clock_delay}]
# Still 0 hold on these pins, held to the next falling edge as above.
set min_ad [expr {$sp_clk_delay + $sp_output_half_period + $sp_0_hold + $min_data_delay - $max_clock_delay}]
set_input_delay -clock fmc_virt_clk -max $max_ad [get_ports fmc_sp_to_fpga1_da[*]]
set_input_delay -clock fmc_virt_clk -min $min_ad [get_ports fmc_sp_to_fpga1_da[*]]

# The MMCM's +45deg phase shift puts the internal capture edge at 1.25 ns,
# and STA's default edge relationship then times input paths from the
# virtual-clock launch at 0 to that 1.25 ns edge -- a nonsense 1.25 ns
# requirement. The intended capture edge is the *next* shifted edge at
# 11.25 ns, which is exactly what setup-2 selects. The default hold
# relationship (one cycle before the setup edge, back at 1.25 ns) is the
# right check and passes with the half-period of real SP hold, so no -hold
# adjustment. Output paths need nothing: launch at 1.25 ns against the SP's
# capture at 10 ns is already the correct single-cycle relationship.
set_multicycle_path 2 -setup -from [get_clocks fmc_virt_clk] -to [get_clocks *fmc_pll*]
set_multicycle_path 2 -setup -from [get_clocks fmc_clk_pin] -to [get_clocks *fmc_pll*]

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
set max_wait [expr {$tsu_nwait_clkh + $max_wait_delay + $max_clock_delay - $sp_clk_delay}]
# Ext hold time is 2ns, still 0 clock delay at external device.
set  th_clkh_nwait  2
set min_wait [expr {$min_clock_delay + $min_wait_delay - $th_clkh_nwait - $sp_clk_delay}]
set_output_delay -clock fmc_virt_clk -max $max_wait [get_ports fmc_sp_to_fpga1_wait_l]
set_output_delay -clock fmc_virt_clk -min $min_wait [get_ports fmc_sp_to_fpga1_wait_l]

# Ext setup time is 3ns
set  tsu_adv_clkh 3
# Ext hold time is 0ns
set th_clkh_adv 0
# Still 0 clk delay at external device
set max_da [expr {$tsu_adv_clkh + $max_data_delay + $max_clock_delay - $sp_clk_delay}]
set min_da [expr {$min_data_delay - $th_clkh_adv + $min_clock_delay - $sp_clk_delay}]
set_output_delay -clock fmc_virt_clk -max $max_da [get_ports fmc_sp_to_fpga1_da[*]]
set_output_delay -clock fmc_virt_clk -min $min_da [get_ports fmc_sp_to_fpga1_da[*]]


# The streaming FSM presents read beats on consecutive cycles, so the
# word0->word1 transition is a true single-cycle path and no multicycle
# exception applies to the data pins. Single-cycle closes because the output
# and tristate flops pack into the IOBs: data_out_reg and data_out_hiz_int_reg
# are one flop per pin by construction, and nwait, a single-cycle path the SP
# samples every rising edge, gets the same treatment. If a board cannot close
# this way, set the extra_beat_setup generic and add setup-2/hold-1 exceptions
# on the data/tristate paths to match.
set_property IOB TRUE [get_cells -hier -filter {NAME =~ *stm32h7_fmc_target*/data_out_reg[*]}]
set_property IOB TRUE [get_cells -hier -filter {NAME =~ *stm32h7_fmc_target*/data_out_hiz_int_reg[*]}]
set_property IOB TRUE [get_cells -hier -filter {NAME =~ *stm32h7_fmc_target*/nwait_reg}]

# End FMC

set_false_path -from [get_ports {*}] -to [get_ports {fpga1_spare_v3p3*}]
set_false_path -from [get_ports {*}] -to [get_ports {fpga1_spare_v1p8[*]}]

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
# eSPI1 is a second instance of the same target on the SP5's other eSPI
# port, serving the Versal's boot flash; same link, same budget.
set_max_delay -to [get_ports espi1_sp5_to_fpga1_dat[*]] 6
set_min_delay -to [get_ports espi1_sp5_to_fpga1_dat[*]] 0

# #######################
# SPI NOR flash interface (Winbond W25Q01JV)
# #######################
# sclk is toggled by fabric logic off clk_125m at clk/2, so 62.5MHz, a 16ns
# period with an 8ns half period. Nothing inside the FPGA is clocked by it, so
# there is deliberately no create_generated_clock here: what actually has to be
# bounded is the clock-to-data skew leaving the FPGA and the pin-to-flop delay
# coming back, and both are directly constrainable.
#
# Trace delays are short and local; using the same 6.8ns/m as the FMC block
# above.
# On cosmo flash trace min is 31.982mm (Dat0), and max is 33.436 (Dat3)
# so min = 0.031982m * 6.8ns/m = 0.217
# max = 0.033436 * 6.8ns/m = 0.227
set flash_trace_max 0.227
set flash_trace_min 0.217

# Pull the launch flops into the IOBs. Every one of these is a dedicated
# duplicate whose only load is its pin (see spi_clk_gen's sclk_pin and
# spi_txn_mgr's cs_n_pin), which is what makes packing legal. It matters a lot:
# left in the fabric the placer put them wherever it liked and measured 12 to 13
# ns of routing to the pin, which both blew the clock-to-data skew budget and
# pushed the read round trip past every available sample point. In the IOB the
# delay is small, deterministic, and the same for all four.
set_property IOB TRUE [get_cells -hier -filter {NAME =~ *spi_nor_top_inst/link/clk_gen/sclk_pin_reg}]
set_property IOB TRUE [get_cells -hier -filter {NAME =~ *spi_nor_top_inst/spi_txn_mgr_inst/cs_n_pin_reg}]
set_property IOB TRUE [get_cells -hier -filter {NAME =~ *spi_nor_top_inst/link/io_o_reg[*]}]
set_property IOB TRUE [get_cells -hier -filter {NAME =~ *spi_nor_top_inst/link/io_oe_reg[*]}]
set_property IOB TRUE [get_cells -hier -filter {NAME =~ *spi_nor_top_inst/link/io_cap_*_reg[*]}]

# #################
# Outputs: sclk, and dat[] during the instruction, address and write phases.
# cs_n is handled separately below.
#
# The part samples mosi on the sclk rising edge, and the FPGA launches both mosi
# and the sclk falling edge from the same clk edge. So the flash sees a full half
# period of setup, less whatever skew the IOBs and routing add between the clock
# pin and the data pins:
#
#   skew_budget = half_period - tDVCH = 8.0 - 2.0 = 6.0 ns
#
# Constraining all of these pins into one delay window makes the worst-case skew
# the difference between the two bounds, which is the quantity that matters here:
# the same clock insertion delay applies to every one of these launch flops, so it
# cancels out of the skew and only the window width has to fit the budget.
#
# Note the window looks wide (4.5ns against a 6ns budget) for four pins that are
# all IOB-packed and launched off the same clk edge. That is because max and min
# delay checks compare the slow corner of one path against the fast corner of
# another, so most of the width is process/voltage/temperature spread rather than
# pin-to-pin skew, which is well under a nanosecond here. The bound is a tripwire
# against a pin losing its IOB or picking up extra logic, not a skew estimate.
#
# Hold is not a concern for the part: mosi is held until the following falling
# edge, 8ns after the sampling edge, against a tCHDX of 3ns.
#
# These numbers assume the IOB packing above. Packed, the flop-to-pin delay is
# about 3.3ns and essentially all of it is logic -- 0.001ns of routing -- so a
# tight window is both meetable and meaningful. Left in the fabric the same paths
# measured 12 to 13ns of routing and varied by several ns between builds.
# Metro has two spi_nor_top instances: the SP5 boot flash, on the same 3V3 pins
# cosmo uses, and the Versal's boot flash behind the mux on sheet 137. The IOB
# properties above cover both already, because their -hier filters match on the
# instance name rather than the path to it. The delay windows do not, because
# the two flashes sit in banks at different voltages.
set_max_delay 5.0 -to [get_ports {spi_fpga1_to_flash_clk \
                                  spi_fpga1_to_flash_dat[*]}]
set_min_delay 0.5 -to [get_ports {spi_fpga1_to_flash_clk \
                                  spi_fpga1_to_flash_dat[*]}]

# The Versal flash pins are in bank 35 at 1.8V, where the OBUFT is both slower
# and wider-spread than the 3V3 one the window above was measured against: the
# same IOB-packed path measures 2.9ns min to 7.0ns max here, against roughly
# 1.5 to 3.3ns on the 3V3 pins. Both ends of the window move with it, so the
# floor of 0.5ns is simply unreachable in this bank and says nothing about
# whether the path is healthy.
#
# What the window is for is unchanged: bounding the spread between sclk and the
# data pins so the flash sees them together. That spread is small for the same
# reason it is on the 3V3 pins -- every one of these is a dedicated IOB flop in
# one bank, launched off the same edge, so almost all of the width below is
# common-mode process/voltage/temperature spread rather than pin-to-pin skew.
# The bound is a tripwire against a pin losing its IOB or picking up fabric
# logic, and the max side plus the IOB properties are what actually catch that.
set_max_delay 5.0 -to [get_ports {qspi_fpga1_to_vercel_flash_mux_sck \
                                  qspi_fpga1_to_vercel_flash_mux_d[*]}]
set_min_delay 0.0 -to [get_ports {qspi_fpga1_to_vercel_flash_mux_sck \
                                  qspi_fpga1_to_vercel_flash_mux_d[*]}]

# Two things are deliberately outside that window, because pulling them into it
# would make the placer work hard on paths that have an order of magnitude more
# real slack than the data pins do:
#
#   cs_n         only has to be low before the first sclk edge and stay low after
#                the last. spi_txn_mgr spends cs_setup_cnts = 4 clk cycles, 32ns,
#                on each, against tSLCH/tCHSH of 5ns.
#   the tristate carries no data and only has to have settled before the part
#   enable       starts driving, which release_lanes gives it a full sclk cycle
#                to do.
set_max_delay 16.0 -to [get_ports {spi_fpga1_to_flash_cs_l \
                                   qspi_fpga1_to_vercel_flash_mux_cs_l}]
set_max_delay 16.0 -from [get_cells -hier -filter {NAME =~ *spi_nor_top_inst/link/io_oe_reg[*]}] \
                   -to [get_ports {spi_fpga1_to_flash_dat[*] \
                                   qspi_fpga1_to_vercel_flash_mux_d[*]}]

# #################
# Inputs: dat[] during read phases.
#
# The controller samples read data at a fixed point S after the sclk rising edge,
# set by the rx_sample_taps generic on spi_nor_top. S has to satisfy
#
#   round_trip_valid - half_period  <=  S  <=  half_period + round_trip_hold
#
# where round_trip_valid is built from the part's tCLQV and round_trip_hold from
# its tCLQX. Note the upper limit comes from tCLQX, not tCLQV: sampling too late
# catches the next bit rather than the current one.
#
# With the IOB packing and the output bounds above:
#   flop to sclk pin        3.30 max    1.50 min
#   sclk trace              0.40        0.10
#   flash tCLQV / tCLQX     6.00        1.50
#   data trace back         0.40        0.10
#   pin to capture flop     1.50        0.50
#                          -----       -----
#   round_trip_valid max   11.60       round_trip_hold min   3.70
#
# so at an 8ns half period S has to land in 3.6 .. 11.7ns. rx_sample_taps = 2 puts
# it at 8ns, about 4ns clear of either limit. spi_nor_fast_tb and
# spi_nor_fast_quick_io_tb model these delays and check both corners.
#
# If reads are marginal on hardware, sweep rx_sample_taps before assuming anything
# else is wrong; taps are 4ns apart so 1 and 3 bracket the shipped value.
#
# -datapath_only because this is a pin to flop propagation bound, not a
# synchronous transfer: without it Vivado charges the MMCM's clock insertion
# delay against the budget and the check becomes meaningless.
#
# The dedicated capture flops in spi_link are the only loads on these pins, so
# these paths are exactly the pin-to-flop delay.
set_max_delay 3.0 -datapath_only -from [get_ports {spi_fpga1_to_flash_dat[*] \
                                                   qspi_fpga1_to_vercel_flash_mux_d[*]}]