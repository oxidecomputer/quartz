# -*- python -*- vim:syntax=python:

bluespec_library('Board',
    sources = [
        'Board.bsv',
    ],
    deps = [
        'cobalt//hdl:InitialReset',
        'cobalt//hdl:TestUtils',
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
        'mkIgnitionletTargetDebug',
    ],
    deps = [
        '//hdl/ip/bsv/ignition:Target',
        '//hdl/ip/bsv/ignition:TargetWrapper',
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
    env = 'ignition_target',
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
    env = 'ignition_target',
    design = ':ignitionlet_target_reset_button_top#ignitionlet_target_reset_button_top.json',
    deps = [
        ':ignitionlet_target_reset_button_top',
    ])

bluespec_verilog('TransceiverDebugTop',
    top = 'TransceiverDebugTop.bsv',
    modules = [
        'mkTransceiverDebugTop',
    ],
    deps = [
        ':Board',
        '//hdl/ip/bsv/ignition:Transceiver',
        'cobalt//hdl:InitialReset',
        'cobalt//hdl:IOSync',
        'cobalt//hdl/interfaces:ICE40',
    ],
    local = {
        'bsc_flags': [
            # The folling script is needed to fix the inout syntax used in the
            # generated Verilog.
            '-verilog-filter', ROOT + '/vnd/cobalt/vnd/bluespec/basicinout.pl',
        ],
    })

yosys_design('transceiver_debug_top',
    top_module = 'mkTransceiverDebugTop',
    sources = [
        ':TransceiverDebugTop#mkTransceiverDebugTop',
        'cobalt//vnd/bluespec:Verilog.v#Verilog.v',
        '../../../vnd/cobalt/hdl/InitialReset.v',
    ],
    deps = [
        ':TransceiverDebugTop',
        'cobalt//vnd/bluespec:Verilog.v',
    ])

nextpnr_ice40_bitstream('transceiver_debug',
    env = 'ignition_target',
    design = ':transceiver_debug_top#transceiver_debug_top.json',
    deps = [
        ':transceiver_debug_top',
    ],
    local = {
        'nextpnr_constraints':
            ROOT + '/hdl/ip/bsv/ignition/ignition_target_debug.pcf',
    })
