# -*- python -*- vim:syntax=python:

bluespec_library('SidecarMainboardControllerReg',
    sources = [
        'SidecarMainboardControllerReg.bsv',
    ],
    deps = [
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
