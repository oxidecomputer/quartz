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

yosys_design('ignition_target_top',
    top_module = 'mkIgnitionTargetTop',
    sources = [
        '//hdl/ignition/target:top#mkIgnitionTargetTop',
        'cobalt//vnd/bluespec:Verilog.v#Verilog.v',
    ],
    deps = [
        '//hdl/ignition/target:top',
        'cobalt//vnd/bluespec:Verilog.v',
    ])

nextpnr_ice40_bitstream('ignition_target',
    env = 'ignitionlet_target',
    design = ':ignition_target_top#ignition_target_top.json',
    deps = [
        ':ignition_target_top',
    ])
