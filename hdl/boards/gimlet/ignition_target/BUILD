# -*- python -*- vim:syntax=python:

#
# Ignition Target targets.
#

bluespec_verilog('IgnitionTargetTop',
    top = 'IgnitionTargetTop.bsv',
    modules = [
        'mkGimletRevATargetWithResetButton',
        'mkGimletRevATargetWithPowerButton',
        'mkGimletRevBTargetWithResetButton',
        'mkGimletRevBTargetWithPowerButton',
    ],
    deps = [
        '//hdl/ignition/target:IgnitionTarget',
        '//hdl/ignition/target:IgnitionTargetWrapper',
    ])

# Rev A targets

yosys_design('ignition_target_rev_a_reset_button_top',
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

nextpnr_ice40_bitstream('ignition_target_gimlet_rev_a_reset_button',
    env = 'ignition_target_rev_a',
    design = ':ignition_target_rev_a_reset_button_top#' \
                'ignition_target_rev_a_reset_button_top.json',
    deps = [
        ':ignition_target_rev_a_reset_button_top',
    ])

yosys_design('ignition_target_rev_a_power_button_top',
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

nextpnr_ice40_bitstream('ignition_target_gimlet_rev_a_power_button',
    env = 'ignition_target_rev_a',
    design = ':ignition_target_rev_a_power_button_top#' \
                'ignition_target_rev_a_power_button_top.json',
    deps = [
        ':ignition_target_rev_a_power_button_top',
    ])

# Rev B targets

yosys_design('ignition_target_rev_b_reset_button_top',
    top_module = 'mkGimletRevBTargetWithResetButton',
    sources = [
        ':IgnitionTargetTop#mkGimletRevBTargetWithResetButton',
        'cobalt//vnd/bluespec:Verilog.v#Verilog.v',
    ],
    deps = [
        ':IgnitionTargetTop',
        'cobalt//vnd/bluespec:Verilog.v',
    ])

yosys_design('ignition_target_rev_b_power_button_top',
    top_module = 'mkGimletRevBTargetWithPowerButton',
    sources = [
        ':IgnitionTargetTop#mkGimletRevBTargetWithPowerButton',
        'cobalt//vnd/bluespec:Verilog.v#Verilog.v',
    ],
    deps = [
        ':IgnitionTargetTop',
        'cobalt//vnd/bluespec:Verilog.v',
    ])

nextpnr_ice40_bitstream('ignition_target_gimlet_rev_b_reset_button',
    env = 'ignition_target_rev_b',
    design = ':ignition_target_rev_b_reset_button_top#' \
                'ignition_target_rev_b_reset_button_top.json',
    deps = [
        ':ignition_target_rev_b_reset_button_top',
    ])

nextpnr_ice40_bitstream('ignition_target_gimlet_rev_b_power_button',
    env = 'ignition_target_rev_b',
    design = ':ignition_target_rev_b_power_button_top#' \
                'ignition_target_rev_b_power_button_top.json',
    deps = [
        ':ignition_target_rev_b_power_button_top',
    ])
