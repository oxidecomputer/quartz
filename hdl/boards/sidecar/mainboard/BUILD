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
        '//hdl/boards/gimlet/sequencer:RegCommon',
    ])

bluespec_library('Tofino2Sequencer',
    sources = [
        'Tofino2Sequencer.bsv',
    ],
    deps = [
        ':SidecarMainboardControllerReg',
        '//hdl:PowerRail',
    ])
