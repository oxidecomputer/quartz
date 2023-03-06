# -*- python -*- vim:syntax=python:

#
# Ignition Target targets.
#

bluespec_verilog('IgnitionTargetTop',
    top = 'IgnitionTargetTop.bsv',
    modules = [
        'mkPSCRevAResetButton',
        'mkPSCRevBResetButton',
        'mkPSCRevBResetButtonNoPowerFaultMonitor',
    ],
    deps = [
        '//hdl/ignition:Target',
        '//hdl/ignition:TargetWrapper',
    ])

yosys_design('ignition_target_psc_rev_a_reset_button_top',
    top_module = 'mkPSCRevAResetButton',
    sources = [
        ':IgnitionTargetTop#mkPSCRevAResetButton',
        'cobalt//vnd/bluespec:Verilog.v#Verilog.v',
        '../../../vnd/cobalt/hdl/InitialReset.v',
    ],
    deps = [
        ':IgnitionTargetTop',
        'cobalt//vnd/bluespec:Verilog.v',
    ])

nextpnr_ice40_bitstream('ignition_target_psc_rev_a_reset_button',
    env = 'ignition_target_rev_a',
    design = ':ignition_target_psc_rev_a_reset_button_top#' \
                'ignition_target_psc_rev_a_reset_button_top.json',
    deps = [
        ':ignition_target_psc_rev_a_reset_button_top',
    ])

# Rev B targets

yosys_design('ignition_target_psc_rev_b_reset_button_top',
    top_module = 'mkPSCRevBResetButton',
    sources = [
        ':IgnitionTargetTop#mkPSCRevBResetButton',
        'cobalt//vnd/bluespec:Verilog.v#Verilog.v',
    ],
    deps = [
        ':IgnitionTargetTop',
        'cobalt//vnd/bluespec:Verilog.v',
    ])

nextpnr_ice40_bitstream('ignition_target_psc_rev_b_reset_button',
    env = 'ignition_target_rev_b',
    design = ':ignition_target_psc_rev_b_reset_button_top#' \
                'ignition_target_psc_rev_b_reset_button_top.json',
    deps = [
        ':ignition_target_psc_rev_b_reset_button_top',
    ])

yosys_design('ignition_target_psc_rev_b_reset_button_no_power_fault_monitor_top',
    top_module = 'mkPSCRevBResetButtonNoPowerFaultMonitor',
    sources = [
        ':IgnitionTargetTop#mkPSCRevBResetButtonNoPowerFaultMonitor',
        'cobalt//vnd/bluespec:Verilog.v#Verilog.v',
    ],
    deps = [
        ':IgnitionTargetTop',
        'cobalt//vnd/bluespec:Verilog.v',
    ])

nextpnr_ice40_bitstream('ignition_target_psc_rev_b_reset_button_no_power_fault_monitor',
    env = 'ignition_target_rev_b',
    design = ':ignition_target_psc_rev_b_reset_button_no_power_fault_monitor_top#' \
                'ignition_target_psc_rev_b_reset_button_no_power_fault_monitor_top.json',
    deps = [
        ':ignition_target_psc_rev_b_reset_button_no_power_fault_monitor_top',
    ])
