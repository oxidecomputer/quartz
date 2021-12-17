# -*- python -*- vim:syntax=python:

bluespec_library('IgnitionTarget',
    sources = [
        'IgnitionTarget.bsv',
    ],
    deps = [
        '//hdl/boards/ignitionlet:Board',
        'cobalt//hdl:Strobe',
    ])

bluespec_verilog('top',
    top = 'Top.bsv',
    modules = [
        'mkIgnitionTargetTop',
    ],
    deps = [
        ':IgnitionTarget',
        'cobalt//hdl:InitialReset',
        'cobalt//hdl:InputReg',
        'cobalt//hdl:SchmittReg',
        'cobalt//hdl:Strobe',
        'cobalt//hdl/interfaces:ICE40',
    ],
    local = {
        # The folling script is needed to fix the inout syntax used in the generated Verilog.
        'bsc_flags': [
            '-verilog-filter', ROOT + '/vnd/cobalt/vnd/bluespec/basicinout.pl',
        ]
    })
