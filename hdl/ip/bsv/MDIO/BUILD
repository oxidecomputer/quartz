# -*- python -*- vim:syntax=python:

bluespec_library('MDIO',
    sources = [
        'MDIO.bsv'
    ],
    deps = [
        '//hdl/ip/bsv:Bidirection',
        '//hdl/ip/bsv:Strobe',
    ])

bluespec_library('MDIOPeripheralModel',
    sources = [
        'test/MDIOPeripheralModel.bsv',
    ],
    deps = [
        ':MDIO',
    ])

bluesim_tests('MDIOTests',
    env = '//bluesim_default',
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
