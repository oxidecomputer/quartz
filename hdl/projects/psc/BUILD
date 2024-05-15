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
        'mkPSCRevB',
    ],
    deps = [
        '//hdl/ip/bsv/ignition:Target',
        '//hdl/ip/bsv/ignition:TargetWrapper',
    ])

yosys_design('ignition_target_psc_rev_a_reset_button_top',
    top_module = 'mkPSCRevAResetButton',
    sources = [
        ':IgnitionTargetPSC#mkPSCRevAResetButton',
        '//vnd/bluespec:Verilog.v#Verilog.v',
        '../../ip/bsv/InitialReset.v',
    ],
    deps = [
        ':IgnitionTargetPSC',
        '//vnd/bluespec:Verilog.v',
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
        '//vnd/bluespec:Verilog.v#Verilog.v',
    ],
    deps = [
        ':IgnitionTargetPSC',
        '//vnd/bluespec:Verilog.v',
    ])

yosys_design('ignition_target_psc_rev_b_top',
    top_module = 'mkPSCRevB',
    sources = [
        ':IgnitionTargetPSC#mkPSCRevB',
        '//vnd/bluespec:Verilog.v#Verilog.v',
    ],
    deps = [
        ':IgnitionTargetPSC',
        '//vnd/bluespec:Verilog.v',
    ])

nextpnr_ice40_bitstream('ignition_target_psc_rev_b_reset_button',
    env = 'ignition_target',
    design = ':ignition_target_psc_rev_b_reset_button_top#' \
                'ignition_target_psc_rev_b_reset_button_top.json',
    deps = [
        ':ignition_target_psc_rev_b_reset_button_top',
    ])

nextpnr_ice40_bitstream('ignition_target_psc_rev_b',
    env = 'ignition_target',
    design = ':ignition_target_psc_rev_b_top#' \
                'ignition_target_psc_rev_b_top.json',
    deps = [
        ':ignition_target_psc_rev_b_top',
    ])
