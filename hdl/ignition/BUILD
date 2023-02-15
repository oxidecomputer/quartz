# -*- python -*- vim:syntax=python:

bluespec_library('Protocol',
    sources = [
        'IgnitionProtocol.bsv',
        'IgnitionProtocolDeparser.bsv',
        'IgnitionProtocolParser.bsv',
    ],
    deps = [
        '//hdl:SettableCRC',
        'cobalt//hdl:Encoding8b10b',
    ])

bluespec_library('Transceiver',
    sources = [
        'IgnitionReceiver.bsv',
        'IgnitionTransceiver.bsv',
        'IgnitionTransmitter.bsv',
    ],
    deps = [
        ':Protocol',
        'cobalt//hdl:SerialIO',
    ])

bluespec_library('Target',
    sources = [
        'IgnitionTarget.bsv',
    ],
    deps = [
        ':Transceiver',
        '//hdl/boards/ignitionlet:Board',
        'cobalt//hdl:Countdown',
        'cobalt//hdl:SchmittReg',
        'cobalt//hdl:Strobe',
    ],
    using = {
        'bsc_flags': [
            # Bluesim generated C++ output seems to trigger compiler warnings.
            # Silence these for now.
            '-Xc++', '-Wno-dangling-else',
            '-Xc++', '-Wno-bool-operation',
        ],
    })

bluespec_library('TargetWrapper',
    sources = [
        'IgnitionTargetWrapper.bsv',
    ],
    deps = [
        ':Target',
        'cobalt//hdl:BitSampling',
        'cobalt//hdl:InitialReset',
        'cobalt//hdl:IOSync',
        'cobalt//hdl:SchmittReg',
        'cobalt//hdl:Strobe',
        'cobalt//hdl/interfaces:ICE40',
    ],
    using = {
        'bsc_flags': [
            # The folling script is needed to fix the inout syntax used in the
            # generated Verilog.
            '-verilog-filter', ROOT + '/vnd/cobalt/vnd/bluespec/basicinout.pl',
        ]
    })

bluespec_library('Controller',
    sources = [
        'IgnitionController.bsv',
        'IgnitionEventCounter.bsv',
    ],
    deps = [
        ':ControllerRegisters',
        ':Protocol',
        ':Transceiver',
        'cobalt//hdl:Countdown',
        'cobalt//hdl:SchmittReg',
        'cobalt//hdl:Strobe',
    ],
    using = {
        # Bluesim generated C++ output seems to trigger compiler warnings.
        # Silence these for now.
        'bsc_flags': [
            '-Xc++', '-Wno-dangling-else',
            '-Xc++', '-Wno-bool-operation',
        ],
    })

rdl('ignition_controller_registers',
    sources = [
        'ignition_controller.rdl',
    ],
    outputs = [
        'IgnitionControllerRegisters.bsv',
        'ignition_controller.html',
        'ignition_controller.adoc',
        'ignition_controller.json',
    ])

bluespec_library('ControllerRegisters',
    sources = [
        ':ignition_controller_registers#IgnitionControllerRegisters.bsv',
    ],
    deps = [
        ':ignition_controller_registers',
        'cobalt//hdl:RegCommon',
    ])

bluespec_verilog('mkParser',
    env = 'ignition_target',
    top = 'IgnitionProtocolParser.bsv',
    modules = [
        'mkParser',
    ],
    deps = [
        ':Protocol',
    ],
    local = {
        'bsc_flags': [
            '-opt-undetermined-vals',
            '-unspecified-to', 'X',
        ],
    })

bluespec_verilog('mkTransceiver',
    env = 'ignition_target',
    top = 'IgnitionTransceiver.bsv',
    modules = [
        'mkTransceiver',
    ],
    deps = [
        ':Transceiver',
    ],
    local = {
        'bsc_flags': [
            '-opt-undetermined-vals',
            '-unspecified-to', 'X',
        ],
    })

bluespec_verilog('mkTargetTransceiver',
    env = 'ignition_target',
    top = 'IgnitionTransceiver.bsv',
    modules = [
        'mkTargetTransceiver',
    ],
    deps = [
        ':Transceiver',
    ],
    local = {
        'bsc_flags': [
            '-opt-undetermined-vals',
            '-unspecified-to', 'X',
        ],
    })
