# -*- python -*- vim:syntax=python:

#
# Ignition Target targets.
#

bluespec_verilog('IgnitionTargetTop',
    top = 'IgnitionTargetTop.bsv',
    modules = [
        'mkGimletRevATargetWithResetButton',
        'mkGimletRevATargetWithPowerButton',
    ],
    deps = [
        '//hdl/ignition/target:IgnitionTarget',
        '//hdl/ignition/target:IgnitionTargetWrapper',
    ])

yosys_design('gimlet_rev_a_target_reset_button_top',
    top_module = 'mkGimletRevATargetWithResetButton',
    sources = [
        ':IgnitionTargetTop#mkGimletRevATargetWithResetButton',
        'cobalt//vnd/bluespec:Verilog.v#Verilog.v',
        '../../../../vnd/cobalt/hdl/InitialReset.v',
    ],
    deps = [
        ':IgnitionTargetTop',
        'cobalt//vnd/bluespec:Verilog.v',
    ])

yosys_design('gimlet_rev_a_target_power_button_top',
    top_module = 'mkGimletRevATargetWithPowerButton',
    sources = [
        ':IgnitionTargetTop#mkGimletRevATargetWithPowerButton',
        'cobalt//vnd/bluespec:Verilog.v#Verilog.v',
        '../../../../vnd/cobalt/hdl/InitialReset.v',
    ],
    deps = [
        ':IgnitionTargetTop',
        'cobalt//vnd/bluespec:Verilog.v',
    ])

nextpnr_ice40_bitstream('gimlet_rev_a_target_reset_button',
    env = 'ignition_target_gimlet',
    design = ':gimlet_rev_a_target_reset_button_top#gimlet_rev_a_target_reset_button_top.json',
    deps = [
        ':gimlet_rev_a_target_reset_button_top',
    ])

nextpnr_ice40_bitstream('gimlet_rev_a_target_power_button',
    env = 'ignition_target_gimlet',
    design = ':gimlet_rev_a_target_power_button_top#gimlet_rev_a_target_power_button_top.json',
    deps = [
        ':gimlet_rev_a_target_power_button_top',
    ])
