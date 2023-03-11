# -*- python -*- vim:syntax=python:

#
# Ignition Target targets.
#

bluespec_verilog('IgnitionTargetPSC',
    top = 'IgnitionTargetPSC.bsv',
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
        ':IgnitionTargetPSC#mkPSCRevAResetButton',
        'cobalt//vnd/bluespec:Verilog.v#Verilog.v',
        '../../../vnd/cobalt/hdl/InitialReset.v',
    ],
    deps = [
        ':IgnitionTargetPSC',
        'cobalt//vnd/bluespec:Verilog.v',
    ])

nextpnr_ice40_bitstream('ignition_target_psc_rev_a_reset_button',
    env = 'ignition_target',
    design = ':ignition_target_psc_rev_a_reset_button_top#' \
                'ignition_target_psc_rev_a_reset_button_top.json',
    deps = [
        ':ignition_target_psc_rev_a_reset_button_top',
    ])

# Rev B targets

yosys_design('ignition_target_psc_rev_b_reset_button_top',
    top_module = 'mkPSCRevBResetButton',
    sources = [
        ':IgnitionTargetPSC#mkPSCRevBResetButton',
        'cobalt//vnd/bluespec:Verilog.v#Verilog.v',
    ],
    deps = [
        ':IgnitionTargetPSC',
        'cobalt//vnd/bluespec:Verilog.v',
    ])

nextpnr_ice40_bitstream('ignition_target_psc_rev_b_reset_button',
    env = 'ignition_target',
    design = ':ignition_target_psc_rev_b_reset_button_top#' \
                'ignition_target_psc_rev_b_reset_button_top.json',
    deps = [
        ':ignition_target_psc_rev_b_reset_button_top',
    ])
