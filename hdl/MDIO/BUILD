# -*- python -*- vim:syntax=python:

bluespec_library('MDIO',
    sources = [
        'MDIO.bsv'
    ],
    deps = [
        '//hdl:Bidirection',
        'cobalt//hdl:Strobe',
    ])

bluespec_library('MDIOPeripheralModel',
    sources = [
        'test/MDIOPeripheralModel.bsv',
    ],
    deps = [
        '//hdl:Bidirection',
        ':MDIO',
    ])

bluesim_tests('MDIOTests',
    env = 'cobalt//bluesim_default',
    suite = 'test/MDIOTests.bsv',
    modules = [
        'mkMDIOReadTest',
        'mkMDIOWriteTest',
        'mkMDIOIgnoreWrongPhyAddrTest',
    ],
    deps = [
        '//hdl:Bidirection',
        ':MDIO',
        ':MDIOPeripheralModel',
    ])
