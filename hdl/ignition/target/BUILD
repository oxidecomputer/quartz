# -*- python -*- vim:syntax=python:

bluespec_library('IgnitionTarget',
    sources = [
        'IgnitionTarget.bsv',
    ],
    deps = [
        '//hdl/boards/ignitionlet:Board',
        'cobalt//hdl:Strobe',
    ])

bluespec_library('IgnitionTargetWrapper',
    sources = [
        'IgnitionTargetWrapper.bsv',
    ],
    deps = [
        ':IgnitionTarget',
        'cobalt//hdl:InitialReset',
        'cobalt//hdl:SchmittReg',
        'cobalt//hdl:Strobe',
        'cobalt//hdl:SyncBits',
        'cobalt//hdl/interfaces:ICE40',
    ],
    local = {
        'bsc_flags': [
            # Warning about local Connectable implementation.
            '-suppress-warnings', 'T0127'
        ],
    },
    using = {
        # The folling script is needed to fix the inout syntax used in the generated Verilog.
        'bsc_flags': [
            '-verilog-filter', ROOT + '/vnd/cobalt/vnd/bluespec/basicinout.pl',
        ]
    })
