# -*- python -*- vim:syntax=python:

bluespec_library('Board',
    sources = [
        'Board.bsv',
    ],
    deps = [
        '//hdl/ip/bsv:InitialReset',
        '//hdl/ip/bsv:TestUtils',
        # TODO (arjen): error on this: '//vnd/cobalt/hdl/ip/bsv/interfaces:ICE40',
        '//hdl/ip/bsv/interfaces:ICE40',
    ])

bluespec_verilog('examples',
    top = 'Examples.bsv',
    modules = [
        'mkSequencerBlinky',
    ],
    deps = [
        ':Board',
        '//hdl/ip/bsv/examples:Blinky',
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
        '//vnd/bluespec:Verilog.v#Verilog.v',
        '../../ip/bsv/InitialReset.v',
    ],
    deps = [
        ':IgnitionletTargetTop',
        '//vnd/bluespec:Verilog.v',
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
        '//vnd/bluespec:Verilog.v#Verilog.v',
        '../../ip/bsv/InitialReset.v',
    ],
    deps = [
        ':IgnitionletTargetTop',
        '//vnd/bluespec:Verilog.v',
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
        '//hdl/ip/bsv:InitialReset',
        '//hdl/ip/bsv:IOSync',
        '//hdl/ip/bsv/interfaces:ICE40',
    ],
    local = {
        'bsc_flags': [
            # The folling script is needed to fix the inout syntax used in the
            # generated Verilog.
            '-verilog-filter', ROOT + '/vnd/bluespec/basicinout.pl',
        ],
    })

yosys_design('transceiver_debug_top',
    top_module = 'mkTransceiverDebugTop',
    sources = [
        ':TransceiverDebugTop#mkTransceiverDebugTop',
        '//vnd/bluespec:Verilog.v#Verilog.v',
        '../../ip/bsv/InitialReset.v',
    ],
    deps = [
        ':TransceiverDebugTop',
        '//vnd/bluespec:Verilog.v',
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
