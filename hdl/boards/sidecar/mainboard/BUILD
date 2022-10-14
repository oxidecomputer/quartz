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
        ':Tofino2Sequencer',
        ':PCIeEndpointController',
        '//hdl:FanModule',
        '//hdl:PowerRail',
        'cobalt//hdl:GitVersion',
        'cobalt//hdl:RegCommon',
        'cobalt//hdl:WriteOnceReg',
        'cobalt//hdl/interfaces:SPI',
    ])

bluespec_library('SidecarMainboardControllerTop',
    sources = [
        'SidecarMainboardControllerTop.bsv',
    ],
    deps = [
        ':SidecarMainboardController',
        '//hdl:IOSync',
        'cobalt//hdl:SyncBits',
    ])

bluespec_verilog('mkSidecarMainboardControllerTop',
    top = 'SidecarMainboardControllerTop.bsv',
    modules = [
        'mkSidecarMainboardControllerTop',
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

nextpnr_ecp5_bitstream('sidecar_mainboard_controller_rev_a',
    env = 'sidecar_mainboard_controller',
    design = ':sidecar_mainboard_controller_top#sidecar_mainboard_controller_top.json',
    deps = [
        ':sidecar_mainboard_controller_top',
    ],
    local = {
        'nextpnr_constraints': ROOT + '/hdl/boards/sidecar/mainboard/sidecar_mainboard_controller_rev_a.lpf',
        'nextpnr_ecp5_flags': [
            '--um-45k',
        ],
    })

nextpnr_ecp5_bitstream('sidecar_mainboard_controller_rev_b',
    env = 'sidecar_mainboard_controller',
    design = ':sidecar_mainboard_controller_top#sidecar_mainboard_controller_top.json',
    deps = [
        ':sidecar_mainboard_controller_top',
    ],
    local = {
        'nextpnr_constraints': ROOT + '/hdl/boards/sidecar/mainboard/sidecar_mainboard_controller_rev_b.lpf',
        'nextpnr_ecp5_flags': [
            '--45k',
        ],
    })
