create_clock -add -name sys_clk_pin -period 20.000 -waveform {0 10.000}  [get_ports { clk }];
create_clock -add -name fmc_clk_pin -period 8.000 -waveform {0 4.000}  [get_ports { fmc_clk }];

#
# FMC interface constraints
#
# FPGA inputs first
# Edge-Aligned Rising Edge Source Synchronous Inputs 
# (Using a direct FF connection)
#
# For an edge-aligned Source Synchronous interface, the clock
# transition occurs at the same time as the data transitions.
# In this template, the clock is aligned with the beginning of the
# data. The constraints below rely on the default timing
# analysis (setup = 1 cycle, hold = 0 cycle).
#
# input    __________                  ________________
# clock              |________________|                |__________
#                                     |
#                             skew_bre|skew_are 
#                             <------>|<------> 
#             ________________        |        ________________
# data     XXX________________XXXXXXXXXXXXXXXXX____Rise_Data___XXX
#

set input_clock         fmc_clk_pin;      # Name of input clock
set input_clock_period  8.0;    # Period of input clock
set skew_bre            0.000;             # Data invalid before the rising clock edge
set skew_are            0.000;             # Data invalid after the rising clock edge
set input_ports         <input_ports>;     # List of input ports


# Input Delay Constraint
set_input_delay -clock $input_clock -max [expr $input_clock_period + $skew_are] [get_ports $input_ports];
set_input_delay -clock $input_clock -min [expr $input_clock_period - $skew_bre] [get_ports $input_ports];

# Report Timing Template
# report_timing -from [get_ports $input_ports] -max_paths 20 -nworst 1 -delay_type min_max -name src_sync_edge_rise_in  -file src_sync_edge_rise_in.txt;

#
# End of FMC interface constraints
#