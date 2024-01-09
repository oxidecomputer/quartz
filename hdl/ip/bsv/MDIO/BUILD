# -*- python -*- vim:syntax=python:

bluespec_library('MDIO',
    sources = [
        'MDIO.bsv'
    ],
    deps = [
        'cobalt//hdl:Bidirection',
        'cobalt//hdl:Strobe',
    ])

bluespec_library('MDIOPeripheralModel',
    sources = [
        'test/MDIOPeripheralModel.bsv',
    ],
    deps = [
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
        ':MDIO',
        ':MDIOPeripheralModel',
    ])
