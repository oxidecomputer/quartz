# -*- python -*- vim:syntax=python:

#
# Ignition Target targets.
#

bluespec_verilog('IgnitionTargetTop',
    top = 'IgnitionTargetTop.bsv',
    modules = [
        'mkIgnitionTargetGimletRevA',
    ],
    deps = [
        '//hdl/ignition/target:IgnitionTarget',
        '//hdl/ignition/target:IgnitionTargetWrapper',
    ])

yosys_design('ignition_target_gimlet_rev_a_top',
    top_module = 'mkIgnitionTargetGimletRevA',
    sources = [
        ':IgnitionTargetTop#mkIgnitionTargetGimletRevA',
        'cobalt//vnd/bluespec:Verilog.v#Verilog.v',
        '../../../../vnd/cobalt/hdl/InitialReset.v',
    ],
    deps = [
        ':IgnitionTargetTop',
        'cobalt//vnd/bluespec:Verilog.v',
    ])

nextpnr_ice40_bitstream('ignition_target_gimlet_rev_a',
    env = 'ignition_target_gimlet',
    design = ':ignition_target_gimlet_rev_a_top#ignition_target_gimlet_rev_a_top.json',
    deps = [
        ':ignition_target_gimlet_rev_a_top',
    ])
