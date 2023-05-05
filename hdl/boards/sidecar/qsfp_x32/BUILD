# -*- python -*- vim:syntax=python:

rdl('qsfp_x32_controller_registers',
    sources = [
        'VSC8562/vsc8562.rdl',
        '../../../I2C/I2CCore.rdl',
        'QSFPModule/qsfp_modules_top.rdl',
        'qsfp_x32_controller.rdl',
    ],
    outputs = [
        'QsfpX32ControllerRegsPkg.bsv',
        'sidecar_qsfp_x32_controller_regs.html',
        'sidecar_qsfp_x32_controller_regs.adoc',
        'sidecar_qsfp_x32_controller_regs.json',
    ])

bluespec_library('QsfpX32ControllerRegsPkg',
    sources = [
        ':qsfp_x32_controller_registers#QsfpX32ControllerRegsPkg.bsv',
    ],
    deps = [
        ':qsfp_x32_controller_registers',
        'cobalt//hdl:RegCommon',
    ])

bluespec_library('VSC8562',
    sources = [
        'VSC8562/VSC8562.bsv',
    ],
    deps = [
        ':QsfpX32ControllerRegsPkg',
        '//hdl:CommonFunctions',
        '//hdl:PowerRail',
        '//hdl/MDIO:MDIO',
        'cobalt//hdl:Bidirection',
        'cobalt//hdl:Strobe',
    ])

bluespec_library('QsfpX32ControllerTopRegs',
    sources = [
        'QsfpX32ControllerTopRegs.bsv'
    ],
    deps = [
        '//hdl:CommonFunctions',
        ':QsfpX32ControllerRegsPkg',
    ])

bluespec_library('QsfpModuleController',
    sources = [
        'QSFPModule/QsfpModuleController.bsv',
    ],
    deps = [
        ':QsfpX32ControllerRegsPkg',
        '//hdl:CommonFunctions',
        '//hdl:PowerRail',
        '//hdl/I2C:I2CCore',
        'cobalt//hdl:Bidirection',
    ])


bluespec_library('QsfpModulesTop',
    sources = [
        'QSFPModule/QsfpModulesTop.bsv',
    ],
    deps = [
        ':QsfpModuleController',
        ':QsfpX32ControllerRegsPkg',
        '//hdl:CommonFunctions',
        '//hdl:PowerRail',
        '//hdl/I2C:I2CCore',
    ])

bluespec_library('QsfpX32ControllerSpiServer',
    sources = [
         'QsfpX32ControllerSpiServer.bsv',
    ],
    deps = [
        ':QsfpX32ControllerTopRegs',
        ':QsfpX32ControllerRegsPkg',
        ':VSC8562',
        ':QsfpModulesTop',
    ])

bluespec_library('QsfpX32Controller',
    sources = [
        'QsfpX32Controller.bsv',
    ],
    deps = [
        'cobalt//hdl:Strobe',
        'cobalt//hdl/examples:Blinky',
        'cobalt//hdl/interfaces:SPI',
        ':QsfpX32ControllerTopRegs',
        ':QsfpX32ControllerRegsPkg',
        ':QsfpX32ControllerSpiServer',
        ':VSC8562',
        ':QsfpModulesTop',
    ])

bluespec_library('QsfpX32ControllerTop',
    sources = [
        'QsfpX32ControllerTop.bsv',
    ],
    deps = [
        ':QsfpX32Controller',
        '//hdl/I2C:I2CCore',
        'cobalt//hdl:IOSync',
        'cobalt//hdl:Strobe',
    ],
    using = {
        # The folling script is needed to fix the inout syntax used in the generated Verilog.
        # For additonal context, see https://github.com/B-Lang-org/bsc/issues/327#issuecomment-786182555
        'bsc_flags': [
            '-verilog-filter', ROOT + '/vnd/cobalt/vnd/bluespec/basicinout.pl',
        ]
    })

# Bitstreams

bluespec_verilog('QsfpX32ControllerTopV',
    top = 'QsfpX32ControllerTop.bsv',
    modules = [
        'mkQsfpX32ControllerTop',
    ],
    deps = [
        ':QsfpX32ControllerTop',
    ])

yosys_design('sidecar_qsfp_x32_controller_top',
    top_module = 'mkQsfpX32ControllerTop',
    sources = [
        ':QsfpX32ControllerTopV#mkQsfpX32ControllerTop',
        'cobalt//vnd/bluespec:Verilog.v#Verilog.v',
    ],
    deps = [
        ':QsfpX32ControllerTopV',
        'cobalt//vnd/bluespec:Verilog.v',
    ])


nextpnr_ecp5_bitstream('sidecar_qsfp_x32_controller_rev_b_c',
    env = 'sidecar_qsfp_x32_controller',
    design = ':sidecar_qsfp_x32_controller_top#sidecar_qsfp_x32_controller_top.json',
    deps = [
        ':sidecar_qsfp_x32_controller_top',
    ])

# Tests

bluesim_tests('QsfpModuleControllerTests',
    env = 'cobalt//bluesim_default',
    suite = 'QSFPModule/test/QsfpModuleControllerTests.bsv',
    modules = [
        'mkNoModuleTest',
        'mkNoPowerTest',
        'mkRemovePowerEnableTest',
        'mkPowerGoodTimeoutTest',
        'mkPowerGoodLostTest',
        'mkI2CReadTest',
        'mkI2CWriteTest',
        'mkInitializationTest',
        'mkUninitializationAfterRemovalTest',
    ],
    deps = [
        'cobalt//hdl:Strobe',
        'cobalt//hdl:TestUtils',
        '//hdl/I2C:I2CCommon',
        '//hdl/I2C:I2CCore',
        '//hdl/I2C:I2CPeripheralModel',
        '//hdl:CommonFunctions',
        '//hdl:PowerRail',
        ':QsfpModuleController',
        ':QsfpX32ControllerRegsPkg',
    ])

bluesim_tests('VSC8562Tests',
    env = 'cobalt//bluesim_default',
    suite = 'VSC8562/test/VSC8562Tests.bsv',
    modules = [
        'mkPowerOnByDefaultTest',
        'mkComaModeTest',
        'mkPowerDownTest',
        'mkPowerGoodTimeoutTest',
        'mkSmiTest',
        'mkMdintTest',
    ],
    deps = [
        'cobalt//hdl:Bidirection',
        'cobalt//hdl:Strobe',
        'cobalt//hdl:TestUtils',
        '//hdl:PowerRail',
        '//hdl/MDIO:MDIO',
        '//hdl/MDIO:MDIOPeripheralModel',
        ':VSC8562'
    ])
