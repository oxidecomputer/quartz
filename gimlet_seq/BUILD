# -*- python -*- vim:syntax=python:

bluespec_library('RegCommon',
    sources = [
        'RegCommon.bsv',
    ])

bluespec_library('Regs',
    sources = [
        'Regs.bsv',
    ],
    deps = [
        ':RegCommon',
    ])

bluespec_sim('regs_sim',
    top = 'Regs.bsv',
    modules = [
        'mkTestBenchSimpleReg',
    ],
    deps = [
        ':Regs',
    ],)

bluespec_library('SpiDecode',
    sources = [
        'SpiDecode.bsv',
    ],
    # modules = [
    #     'mkTestBenchSpiPhy',
    #     'mkTestSpiDecode',
    # ],
    deps = [
        ':RegCommon',
    ])

bluespec_sim('decode_sim',
    top = 'SpiDecode.bsv',
    modules = [
        'mkTestBenchSpiPhy',
    ],
    deps = [
        ':SpiDecode',
    ],)

bluespec_library('IgnitionletTop',
    sources = [
        'IgnitionletTop.bsv',
    ],
    deps = [
        ':SpiDecode',
        ':Regs',
    ])

bluesim_binary('reg_test',
    env = 'bluesim_default',
    top = ':regs_sim#mkTestBenchSimpleReg',
    deps = [
        ':regs_sim',
    ])

bluesim_binary('spi_phy_test',
    env = 'bluesim_default',
    top = ':decode_sim#mkTestBenchSpiPhy',
    deps = [
        ':decode_sim',
    ])

bluespec_verilog('ign_verilog',
    top = 'IgnitionletTop.bsv',
    modules = [
        'mkIgnitionletTop',
    ],
    deps = [
        ':IgnitionletTop',
    ])

yosys_design('ignitionlet_yosys',
    top_module = 'mkIgnitionletTop',
    sources = [
        ':ign_verilog#mkIgnitionletTop',
        '//vnd/bluespec:Verilog.v#Verilog.v',
    ],
    deps = [
        ':ign_verilog',
        '//vnd/bluespec:Verilog.v',
    ])

nextpnr_ice40_bitstream('ignitionlet_spi',
    env = 'ignitionlet',
    design = ':ignitionlet_yosys#ignitionlet_yosys.json',
    deps = [
        ':ignitionlet_yosys',
    ])