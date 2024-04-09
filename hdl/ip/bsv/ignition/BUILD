# -*- python -*- vim:syntax=python:

bluespec_library('Protocol',
    sources = [
        'IgnitionProtocol.bsv',
        'IgnitionProtocolDeparser.bsv',
        'IgnitionProtocolParser.bsv',
    ],
    deps = [
        '//hdl/ip/bsv:SettableCRC',
        '//hdl/ip/bsv:Encoding8b10b',
    ])

bluespec_library('Transceiver',
    sources = [
        'IgnitionReceiver.bsv',
        'IgnitionTransceiver.bsv',
        'IgnitionTransmitter.bsv',
    ],
    deps = [
        ':Protocol',
        '//hdl/ip/bsv:SerialIO',
    ])

bluespec_library('Target',
    sources = [
        'IgnitionTarget.bsv',
    ],
    deps = [
        ':Transceiver',
        '//hdl/projects/ignitionlet:Board',
        '//hdl/ip/bsv:Countdown',
        '//hdl/ip/bsv:SchmittReg',
        '//hdl/ip/bsv:Strobe',
    ],
    using = {
        # Bluesim generated C++ output seems to trigger compiler warnings.
        # Silence these for now.
        'bsc_flags': [
            '-Xc++', '-Wno-dangling-else',
            '-Xc++', '-Wno-bool-operation',
        ],
    })

bluespec_library('TargetWrapper',
    sources = [
        'IgnitionTargetTop.bsv',
        'IgnitionTargetWrapper.bsv',
    ],
    deps = [
        ':Target',
        '//hdl/ip/bsv:BitSampling',
        '//hdl/ip/bsv:InitialReset',
        '//hdl/ip/bsv:IOSync',
        '//hdl/ip/bsv:SchmittReg',
        '//hdl/ip/bsv:Strobe',
        '//hdl/ip/bsv/interfaces:ICE40',
    ],
    using = {
        # The folling script is needed to fix the inout syntax used in the
        # generated Verilog.
        'bsc_flags': [
            '-verilog-filter', ROOT + '/vnd/bluespec/basicinout.pl',
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
        '//hdl/ip/bsv:CounterRAM',
        '//hdl/ip/bsv:Strobe',
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
        '//hdl/ip/bsv:RegCommon',
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

bluespec_verilog('mkController',
    env = 'ecp5',
    top = 'IgnitionController.bsv',
    modules = [
        'mkDefaultController',
        'mkDefaultControllerUsingBRAM',
    ],
    deps = [
        ':Controller',
    ],
    local = {
        'bsc_flags': [
            '-opt-undetermined-vals',
            '-unspecified-to', 'X',
        ],
    })

bluespec_verilog('mkTransceivers',
    env = 'ecp5',
    top = 'IgnitionTransceiver.bsv',
    modules = [
        'mkTransceivers6',
        'mkTransceivers8',
        'mkControllerTransceiver36',
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
