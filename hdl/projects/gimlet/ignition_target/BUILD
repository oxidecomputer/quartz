# -*- python -*- vim:syntax=python:

#
# Ignition Target targets.
#

bluespec_verilog('IgnitionTargetGimlet',
    top = 'IgnitionTargetGimlet.bsv',
    modules = [
        'mkGimletRevBTargetWithResetButton',
        'mkGimletRevBTargetWithPowerButton',
        'mkGimletRevBTarget'
    ],
    deps = [
        '//hdl/ip/bsv/ignition:Target',
        '//hdl/ip/bsv/ignition:TargetWrapper',
    ])

# Rev B, C, D compatible targets

yosys_design('ignition_target_rev_b_reset_button_top',
    top_module = 'mkGimletRevBTargetWithResetButton',
    sources = [
        ':IgnitionTargetGimlet#mkGimletRevBTargetWithResetButton',
        '//vnd/bluespec:Verilog.v#Verilog.v',
    ],
    deps = [
        ':IgnitionTargetGimlet',
        '//vnd/bluespec:Verilog.v',
    ])

yosys_design('ignition_target_rev_b_power_button_top',
    top_module = 'mkGimletRevBTargetWithPowerButton',
    sources = [
        ':IgnitionTargetGimlet#mkGimletRevBTargetWithPowerButton',
        '//vnd/bluespec:Verilog.v#Verilog.v',
    ],
    deps = [
        ':IgnitionTargetGimlet',
        '//vnd/bluespec:Verilog.v',
    ])

yosys_design('ignition_target_rev_b_top',
    top_module = 'mkGimletRevBTarget',
    sources = [
        ':IgnitionTargetGimlet#mkGimletRevBTarget',
        '//vnd/bluespec:Verilog.v#Verilog.v',
    ],
    deps = [
        ':IgnitionTargetGimlet',
        '//vnd/bluespec:Verilog.v',
    ])

nextpnr_ice40_bitstream('ignition_target_gimlet_rev_b_c_d_reset_button',
    env = 'ignition_target',
    design = ':ignition_target_rev_b_reset_button_top#' \
                'ignition_target_rev_b_reset_button_top.json',
    deps = [
        ':ignition_target_rev_b_reset_button_top',
    ])

nextpnr_ice40_bitstream('ignition_target_gimlet_rev_b_c_d_power_button',
    env = 'ignition_target',
    design = ':ignition_target_rev_b_power_button_top#' \
                'ignition_target_rev_b_power_button_top.json',
    deps = [
        ':ignition_target_rev_b_power_button_top',
    ])

nextpnr_ice40_bitstream('ignition_target_gimlet_rev_b_c_d',
    env = 'ignition_target',
    design = ':ignition_target_rev_b_top#' \
                'ignition_target_rev_b_top.json',
    deps = [
        ':ignition_target_rev_b_top',
    ])
