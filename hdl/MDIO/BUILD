# -*- python -*- vim:syntax=python:

bluespec_library('MDIO',
    sources = [
        'MDIO.bsv'
    ],
    deps = [
        '//hdl:Common',
        'cobalt//hdl:Strobe',
    ])

bluespec_library('MDIOPeripheralModel',
    sources = [
        'test/MDIOPeripheralModel.bsv',
    ],
    deps = [
        '//hdl:Common',
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
        '//hdl:Common',
        ':MDIO',
        ':MDIOPeripheralModel',
    ])