# -*- python -*- vim:syntax=python:

bluespec_library('Board',
    sources = [
        'Board.bsv',
    ],
    deps = [
        # TODO (arjen): error on this: '//vnd/cobalt/hdl/interfaces:ICE40',
        'cobalt//hdl/interfaces:ICE40',
    ])

bluespec_verilog('examples',
    top = 'Examples.bsv',
    modules = [
        'mkSequencerBlinky',
    ],
    deps = [
        ':Board',
        'cobalt//hdl/examples:Blinky',
    ])

#
# Blinky design targets.
#

yosys_design('sequencer_blinky',
    top_module = 'mkSequencerBlinky',
    sources = [
        ':examples#mkSequencerBlinky',
    ],
    deps = [
        ':examples',
    ])

nextpnr_ice40_bitstream('ignitionlet_sequencer_blinky',
    env = 'ignitionlet_sequencer',
    design = ':sequencer_blinky#sequencer_blinky.json',
    deps = [
        ':sequencer_blinky',
    ])

#
# Ignition Target targets.
#

bluespec_verilog('IgnitionletTargetTop',
    top = 'IgnitionletTargetTop.bsv',
    modules = [
        'mkIgnitionletTargetWithPowerButton',
        'mkIgnitionletTargetWithResetButton',
        'mkIgnitionletTargetWithResetButtonAndAuxLoopbackIndicators',
    ],
    deps = [
        '//hdl/ignition/target:IgnitionTarget',
        '//hdl/ignition/target:IgnitionTargetWrapper',
    ])

yosys_design('ignitionlet_target_power_button_top',
    top_module = 'mkIgnitionletTargetWithPowerButton',
    sources = [
        ':IgnitionletTargetTop#mkIgnitionletTargetWithPowerButton',
        'cobalt//vnd/bluespec:Verilog.v#Verilog.v',
        '../../../vnd/cobalt/hdl/InitialReset.v',
    ],
    deps = [
        ':IgnitionletTargetTop',
        'cobalt//vnd/bluespec:Verilog.v',
    ])

nextpnr_ice40_bitstream('ignitionlet_target_power_button',
    env = 'ignitionlet_target',
    design = ':ignitionlet_target_power_button_top#ignitionlet_target_power_button_top.json',
    deps = [
        ':ignitionlet_target_power_button_top',
    ])

yosys_design('ignitionlet_target_reset_button_top',
    top_module = 'mkIgnitionletTargetWithResetButton',
    sources = [
        ':IgnitionletTargetTop#mkIgnitionletTargetWithResetButton',
        'cobalt//vnd/bluespec:Verilog.v#Verilog.v',
        '../../../vnd/cobalt/hdl/InitialReset.v',
    ],
    deps = [
        ':IgnitionletTargetTop',
        'cobalt//vnd/bluespec:Verilog.v',
    ])

nextpnr_ice40_bitstream('ignitionlet_target_reset_button',
    env = 'ignitionlet_target',
    design = ':ignitionlet_target_reset_button_top#ignitionlet_target_reset_button_top.json',
    deps = [
        ':ignitionlet_target_reset_button_top',
    ])

yosys_design('ignitionlet_target_reset_button_aux_loopback_indicators_top',
    top_module = 'mkIgnitionletTargetWithResetButtonAndAuxLoopbackIndicators',
    sources = [
        ':IgnitionletTargetTop#mkIgnitionletTargetWithResetButtonAndAuxLoopbackIndicators',
        'cobalt//vnd/bluespec:Verilog.v#Verilog.v',
        '../../../vnd/cobalt/hdl/InitialReset.v',
    ],
    deps = [
        ':IgnitionletTargetTop',
        'cobalt//vnd/bluespec:Verilog.v',
    ])

nextpnr_ice40_bitstream('ignitionlet_target_reset_button_aux_loopback_indicators',
    env = 'ignitionlet_target',
    design = ':ignitionlet_target_reset_button_aux_loopback_indicators_top#ignitionlet_target_reset_button_aux_loopback_indicators_top.json',
    deps = [
        ':ignitionlet_target_reset_button_aux_loopback_indicators_top',
    ])
