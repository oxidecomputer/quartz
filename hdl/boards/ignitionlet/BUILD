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
