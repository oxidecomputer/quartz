# -*- python -*- vim:syntax=python:

bluespec_library('MDIO',
    sources = [
        'MDIO.bsv'
    ],
    deps = [
        '//hdl:CommonInterfaces',
        'cobalt//hdl:Strobe',
    ])

bluespec_library('MDIOPeripheralModel',
    sources = [
        'test/MDIOPeripheralModel.bsv',
    ],
    deps = [
        '//hdl:CommonInterfaces',
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
        '//hdl:CommonInterfaces',
        ':MDIO',
        ':MDIOPeripheralModel',
    ])