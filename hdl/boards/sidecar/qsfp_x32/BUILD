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
        'qsfp_x32_controller_regs.html',
        'qsfp_x32_controller_regs.adoc',
        'qsfp_x32_controller_regs.json',
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
        'cobalt//hdl:Strobe',
        '//hdl:CommonFunctions',
        '//hdl:Bidirection',
        ':QsfpX32ControllerRegsPkg',
        '//hdl:PowerRail',
        '//hdl/MDIO:MDIO',
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
        '//hdl/I2C:I2CCore',
        '//hdl:PowerRail',
        '//hdl:CommonFunctions',
        '//hdl:Bidirection',
        ':QsfpX32ControllerRegsPkg',
    ])


bluespec_library('QsfpModulesTop',
    sources = [
        'QSFPModule/QsfpModulesTop.bsv',
    ],
    deps = [
        '//hdl/I2C:I2CCore',
        '//hdl:PowerRail',
        '//hdl:CommonFunctions',
        '//hdl:Bidirection',
        ':QsfpModuleController',
        ':QsfpX32ControllerRegsPkg',
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
        '//hdl:Bidirection',
        ':QsfpX32Controller',
        '//hdl:IOSync',
        '//hdl/I2C:I2CCore',
    ],
    using = {
        # The folling script is needed to fix the inout syntax used in the generated Verilog.
        # For additonal context, see https://github.com/B-Lang-org/bsc/issues/327#issuecomment-786182555
        'bsc_flags': [
            '-verilog-filter', ROOT + '/vnd/cobalt/vnd/bluespec/basicinout.pl',
        ]
    })

bluespec_verilog('QsfpX32ControllerTopV',
    top = 'QsfpX32ControllerTop.bsv',
    modules = [
        'mkQsfpX32ControllerTop',
    ],
    deps = [
        ':QsfpX32ControllerTop',
    ])

yosys_design('qsfp_x32_top',
    top_module = 'mkQsfpX32ControllerTop',
    sources = [
        ':QsfpX32ControllerTopV#mkQsfpX32ControllerTop',
        'cobalt//vnd/bluespec:Verilog.v#Verilog.v',
    ],
    deps = [
        ':QsfpX32ControllerTopV',
        'cobalt//vnd/bluespec:Verilog.v',
    ])

# Rev A uses a LFE45UM device and requires a different device ID. This target
# can be removed once rev A boards have been phased out.
nextpnr_ecp5_bitstream('qsfp_x32_rev_a',
    env = 'qsfp_x32',
    design = ':qsfp_x32_top#qsfp_x32_top.json',
    deps = [
        ':qsfp_x32_top',
    ],
    local = {
        'nextpnr_ecp5_flags': [
            '--um-45k',
        ]
    })

nextpnr_ecp5_bitstream('qsfp_x32_rev_b',
    env = 'qsfp_x32',
    design = ':qsfp_x32_top#qsfp_x32_top.json',
    deps = [
        ':qsfp_x32_top',
    ])

bluesim_tests('QsfpModuleControllerTests',
    env = 'cobalt//bluesim_default',
    suite = 'QSFPModule/test/QsfpModuleControllerTests.bsv',
    modules = [
        'mkQsfpModuleControllerReadTest',
        'mkQsfpModuleControllerWriteTest',
    ],
    deps = [
        '//hdl/I2C:I2CCommon',
        '//hdl/I2C:I2CCore',
        '//hdl/I2C:I2CPeripheralModel',
        ':QsfpModuleController',
    ])
