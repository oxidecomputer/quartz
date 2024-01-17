# -*- python -*- vim:syntax=python:

#
# Ignition Target targets.
#

bluespec_verilog('IgnitionTargetSidecar',
    top = 'IgnitionTargetSidecar.bsv',
    modules = [
        'mkSidecarRevATargetWithResetButton',
        'mkSidecarRevATargetWithPowerButton',
        'mkSidecarRevBTargetWithResetButton',
        'mkSidecarRevBTargetWithPowerButton',
    ],
    deps = [
        '//hdl/ip/bsv/ignition:Target',
        '//hdl/ip/bsv/ignition:TargetWrapper',
    ])

# Rev A targets

yosys_design('ignition_target_rev_a_reset_button_top',
    top_module = 'mkSidecarRevATargetWithResetButton',
    sources = [
        ':IgnitionTargetSidecar#mkSidecarRevATargetWithResetButton',
        '//vnd/bluespec:Verilog.v#Verilog.v',
        '../../../ip/bsv/InitialReset.v',
    ],
    deps = [
        ':IgnitionTargetSidecar',
        '//vnd/bluespec:Verilog.v',
    ])

nextpnr_ice40_bitstream('ignition_target_sidecar_rev_a_reset_button',
    env = 'ignition_target',
    design = ':ignition_target_rev_a_reset_button_top#' \
                'ignition_target_rev_a_reset_button_top.json',
    deps = [
        ':ignition_target_rev_a_reset_button_top',
    ])

yosys_design('ignition_target_rev_a_power_button_top',
    top_module = 'mkSidecarRevATargetWithPowerButton',
    sources = [
        ':IgnitionTargetSidecar#mkSidecarRevATargetWithPowerButton',
        '//vnd/bluespec:Verilog.v#Verilog.v',
        '../../../ip/bsv/InitialReset.v',
    ],
    deps = [
        ':IgnitionTargetSidecar',
        '//vnd/bluespec:Verilog.v',
    ])

nextpnr_ice40_bitstream('ignition_target_sidecar_rev_a_power_button',
    env = 'ignition_target',
    design = ':ignition_target_rev_a_power_button_top#' \
                'ignition_target_rev_a_power_button_top.json',
    deps = [
        ':ignition_target_rev_a_power_button_top',
    ])

# Rev B, C targets

yosys_design('ignition_target_rev_b_reset_button_top',
    top_module = 'mkSidecarRevBTargetWithResetButton',
    sources = [
        ':IgnitionTargetSidecar#mkSidecarRevBTargetWithResetButton',
        '//vnd/bluespec:Verilog.v#Verilog.v',
    ],
    deps = [
        ':IgnitionTargetSidecar',
        '//vnd/bluespec:Verilog.v',
    ])

yosys_design('ignition_target_rev_b_power_button_top',
    top_module = 'mkSidecarRevBTargetWithPowerButton',
    sources = [
        ':IgnitionTargetSidecar#mkSidecarRevBTargetWithPowerButton',
        '//vnd/bluespec:Verilog.v#Verilog.v',
    ],
    deps = [
        ':IgnitionTargetSidecar',
        '//vnd/bluespec:Verilog.v',
    ])

nextpnr_ice40_bitstream('ignition_target_sidecar_rev_b_c_reset_button',
    env = 'ignition_target',
    design = ':ignition_target_rev_b_reset_button_top#' \
                'ignition_target_rev_b_reset_button_top.json',
    deps = [
        ':ignition_target_rev_b_reset_button_top',
    ])

nextpnr_ice40_bitstream('ignition_target_sidecar_rev_b_c_power_button',
    env = 'ignition_target',
    design = ':ignition_target_rev_b_power_button_top#' \
                'ignition_target_rev_b_power_button_top.json',
    deps = [
        ':ignition_target_rev_b_power_button_top',
    ])
