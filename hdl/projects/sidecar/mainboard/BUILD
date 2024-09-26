# -*- python -*- vim:syntax=python:

rdl('sidecar_mainboard_controller_registers',
    sources = [
        '../../../ip/bsv/power_rail/power_rail.rdl',
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
        '//hdl/ip/bsv:RegCommon',
    ])

bluespec_library('TofinoDebugPort',
    sources = [
        'TofinoDebugPort.bsv',
    ],
    deps = [
        ':SidecarMainboardControllerReg',
        '//hdl/ip/bsv:CommonFunctions',
        '//hdl/ip/bsv/I2C:I2CCore',
    ])

bluespec_library('Tofino2Sequencer',
    sources = [
        'Tofino2Sequencer.bsv',
    ],
    deps = [
        ':SidecarMainboardControllerReg',
        '//hdl/ip/bsv:PowerRail',
    ])

bluespec_library('PCIeEndpointController',
    sources = [
        'PCIeEndpointController.bsv',
    ],
    deps = [
        ':SidecarMainboardControllerReg',
        ':Tofino2Sequencer',
        '//hdl/ip/bsv:CommonFunctions',
        '//hdl/ip/bsv:Debouncer',
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
        '//hdl/ip/bsv:PowerRail',
        '//hdl/ip/bsv/ignition:Controller',
        '//hdl/ip/bsv/ignition:ControllerRegisters',
        '//hdl/ip/bsv/ignition:Transceiver',
        '//hdl/ip/bsv:Debouncer',
        '//hdl/ip/bsv:GitVersion',
        '//hdl/ip/bsv:RegCommon',
        '//hdl/ip/bsv:WriteOnceReg',
        '//hdl/ip/bsv/interfaces:SPI',
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
        '//hdl/ip/bsv:IOSync',
        '//hdl/ip/bsv:SerialIO',
    ],
    using = {
        'bsc_flags': [
            # The folling script is needed to fix the inout syntax used in the
            # generated Verilog. For additonal context, see
            # https://github.com/B-Lang-org/bsc/issues/327#issuecomment-786182555
            '-verilog-filter', ROOT + '/vnd/bluespec/basicinout.pl',
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
        '//vnd/bluespec:Verilog.v#Verilog.v',
    ],
    deps = [
        ':mkSidecarMainboardControllerTop',
        '//vnd/bluespec:Verilog.v',
    ])


nextpnr_ecp5_bitstream('sidecar_mainboard_controller_rev_c_d',
    env = 'sidecar_mainboard_controller',
    design = ':sidecar_mainboard_controller_top#sidecar_mainboard_controller_top.json',
    deps = [
        ':sidecar_mainboard_controller_top',
    ])

yosys_design('sidecar_mainboard_controller_top_rev_b',
    top_module = 'mkSidecarMainboardControllerTopRevB',
    sources = [
        ':mkSidecarMainboardControllerTop#mkSidecarMainboardControllerTopRevB',
        '//vnd/bluespec:Verilog.v#Verilog.v',
    ],
    deps = [
        ':mkSidecarMainboardControllerTop',
        '//vnd/bluespec:Verilog.v',
    ])


nextpnr_ecp5_bitstream('sidecar_mainboard_controller_rev_b',
    env = 'sidecar_mainboard_controller',
    design = ':sidecar_mainboard_controller_top_rev_b#sidecar_mainboard_controller_top_rev_b.json',
    deps = [
        ':sidecar_mainboard_controller_top_rev_b',
    ],
    local = {
        'nextpnr_constraints': ROOT + '/hdl/projects/sidecar/mainboard/sidecar_mainboard_controller_rev_b.lpf',
    })
