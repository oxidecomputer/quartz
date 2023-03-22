# -*- python -*- vim:syntax=python:

rdl('sidecar_mainboard_controller_registers',
    sources = [
        'sidecar_mainboard_controller.rdl',
    ],
    outputs = [
        'SidecarMainboardControllerReg.bsv',
        'sidecar_mainboard_controller.html',
        'sidecar_mainboard_controller.adoc',
        'sidecar_mainboard_controller.json',
    ])

bluespec_library('SidecarMainboardControllerReg',
    sources = [
        ':sidecar_mainboard_controller_registers#SidecarMainboardControllerReg.bsv',
    ],
    deps = [
        ':sidecar_mainboard_controller_registers',
        'cobalt//hdl:RegCommon',
    ])

bluespec_library('TofinoDebugPort',
    sources = [
        'TofinoDebugPort.bsv',
    ],
    deps = [
        ':SidecarMainboardControllerReg',
        '//hdl:CommonFunctions',
        '//hdl/I2C:I2CCore',
    ])

bluespec_library('Tofino2Sequencer',
    sources = [
        'Tofino2Sequencer.bsv',
    ],
    deps = [
        ':SidecarMainboardControllerReg',
        '//hdl:PowerRail',
    ])

bluespec_library('PCIeEndpointController',
    sources = [
        'PCIeEndpointController.bsv',
    ],
    deps = [
        ':SidecarMainboardControllerReg',
    ])

bluespec_library('SidecarMainboardController',
    sources = [
        'SidecarMainboardController.bsv',
        'SidecarMainboardControllerSpiServer.bsv',
        'SidecarMainboardMiscSequencers.bsv',
    ],
    deps = [
        ':PCIeEndpointController',
        ':Tofino2Sequencer',
        ':TofinoDebugPort',
        '//hdl:FanModule',
        '//hdl:PowerRail',
        '//hdl/ignition:Controller',
        '//hdl/ignition:ControllerRegisters',
        '//hdl/ignition:Transceiver',
        'cobalt//hdl:GitVersion',
        'cobalt//hdl:RegCommon',
        'cobalt//hdl:WriteOnceReg',
        'cobalt//hdl/interfaces:SPI',
    ],
    using = {
        'bsc_flags': [
            '+RTS', '-K0', '-RTS',
        ]
    })

bluespec_library('SidecarMainboardControllerTop',
    sources = [
        'SidecarMainboardControllerTop.bsv',
    ],
    deps = [
        ':SidecarMainboardController',
        'cobalt//hdl:IOSync',
        'cobalt//hdl:SerialIO',
    ],
    using = {
        'bsc_flags': [
            # The folling script is needed to fix the inout syntax used in the
            # generated Verilog. For additonal context, see
            # https://github.com/B-Lang-org/bsc/issues/327#issuecomment-786182555
            '-verilog-filter', ROOT + '/vnd/cobalt/vnd/bluespec/basicinout.pl',
            '-opt-undetermined-vals',
            '-unspecified-to X',
            '-steps-warn-interval 1000000',
            '-steps-max-intervals 3',
        ]
    })

bluespec_verilog('mkSidecarMainboardControllerTop',
    top = 'SidecarMainboardControllerTop.bsv',
    modules = [
        'mkSidecarMainboardControllerTop',
        'mkSidecarMainboardControllerTopRevB',
    ],
    deps = [
        ':SidecarMainboardControllerTop',
    ])

yosys_design('sidecar_mainboard_controller_top',
    top_module = 'mkSidecarMainboardControllerTop',
    sources = [
        ':mkSidecarMainboardControllerTop#mkSidecarMainboardControllerTop',
        'cobalt//vnd/bluespec:Verilog.v#Verilog.v',
    ],
    deps = [
        ':mkSidecarMainboardControllerTop',
        'cobalt//vnd/bluespec:Verilog.v',
    ])


nextpnr_ecp5_bitstream('sidecar_mainboard_controller_rev_c',
    env = 'sidecar_mainboard_controller',
    design = ':sidecar_mainboard_controller_top#sidecar_mainboard_controller_top.json',
    deps = [
        ':sidecar_mainboard_controller_top',
    ])

yosys_design('sidecar_mainboard_controller_top_rev_b',
    top_module = 'mkSidecarMainboardControllerTopRevB',
    sources = [
        ':mkSidecarMainboardControllerTop#mkSidecarMainboardControllerTopRevB',
        'cobalt//vnd/bluespec:Verilog.v#Verilog.v',
    ],
    deps = [
        ':mkSidecarMainboardControllerTop',
        'cobalt//vnd/bluespec:Verilog.v',
    ])


nextpnr_ecp5_bitstream('sidecar_mainboard_controller_rev_b',
    env = 'sidecar_mainboard_controller',
    design = ':sidecar_mainboard_controller_top_rev_b#sidecar_mainboard_controller_top_rev_b.json',
    deps = [
        ':sidecar_mainboard_controller_top_rev_b',
    ],
    local = {
        'nextpnr_constraints': ROOT + '/hdl/boards/sidecar/mainboard/sidecar_mainboard_controller_rev_b.lpf',
    })
