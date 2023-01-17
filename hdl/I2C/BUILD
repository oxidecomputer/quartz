# -*- python -*- vim:syntax=python:

rdl('I2CCoreRegsPkg',
    sources = [
        'I2CCore.rdl'
    ],
    outputs = [
        'I2CCoreRegs.bsv',
        'i2c_core_regs.html',
        'i2c_core_regs.json',
    ])

bluespec_library('I2CCoreRegs',
    sources = [
        ':I2CCoreRegsPkg#I2CCoreRegs.bsv',
    ],
    deps = [
        'cobalt//hdl:RegCommon',
        ':I2CCoreRegsPkg',
    ])

bluespec_library('I2CCommon',
    sources = [
        'I2CCommon.bsv',
    ],
    deps = [
        'cobalt//hdl:Bidirection',
    ])

bluespec_library('I2CBitController',
    sources = [
        'I2CBitController.bsv',
    ],
    deps = [
        ':I2CCommon',
        'cobalt//hdl:Strobe'
    ])

bluespec_library('I2CCore',
    sources = [
        'I2CCore.bsv',
    ],
    deps = [
        ':I2CCommon',
        ':I2CBitController',
    ])

bluespec_library('I2CPeripheralModel',
    sources = [
        'test/I2CPeripheralModel.bsv',
    ],
    deps = [
        ':I2CCommon',
    ])

bluesim_tests('I2CBitControllerTests',
    env = 'cobalt//bluesim_default',
    suite = 'test/I2CBitControllerTests.bsv',
    modules = [
        'mkI2CBitControlOneByteWriteTest',
        'mkI2CBitControlOneByteReadTest',
        'mkI2CBitControlSequentialWriteTest',
        'mkI2CBitControlSequentialReadTest',
        'mkI2CBitControlRandomReadTest',
    ],
    deps = [
        ':I2CBitController',
        ':I2CCommon',
        ':I2CPeripheralModel',
    ])

bluesim_tests('I2CCoreTests',
    env = 'cobalt//bluesim_default',
    suite = 'test/I2CCoreTests.bsv',
    modules = [
        'mkI2CCoreOneByteWriteTest',
        'mkI2CCoreOneByteReadTest',
        'mkI2CCoreSequentialWriteTest',
        'mkI2CCoreSequentialReadTest',
        'mkI2CCoreRandomReadTest',
    ],
    deps = [
        ':I2CBitController',
        ':I2CCommon',
        ':I2CCore',
        ':I2CPeripheralModel',
    ])
