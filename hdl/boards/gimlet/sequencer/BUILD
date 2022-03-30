# -*- python -*- vim:syntax=python:

bluespec_library('IrqBlock',
    sources = [
        'IrqBlock.bsv',
    ])

bluespec_library('RegCommon',
    sources = [
        'RegCommon.bsv',
    ])


bluespec_library('GimletSeqFpgaRegs',
    sources = [
        'GimletSeqFpgaRegs.bsv',
    ],
    deps = [
        ':RegCommon',
    ])
bluespec_library('GimletRegs',
    sources = [
        'GimletRegs.bsv',
    ],
    deps = [
        ':IrqBlock',
        ':RegCommon',
        ':GimletSeqFpgaRegs',
        ':NicBlock',
        ':EarlyPowerBlock',
        ':A1Block',
        ':A0Block',
        ':MiscIO',
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

bluespec_sim('gimlet_regs_sim',
    top = 'GimletRegs.bsv',
    modules = [
        'mkSimpleTest',
    ],
    deps = [
        ':GimletRegs',
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

bluespec_library('NicBlock',
    sources = [
        'NicBlock.bsv',
    ],
    deps = [
         ':GimletSeqFpgaRegs',
    ])
bluespec_library('A1Block',
    sources = [
        'A1Block.bsv',
    ],
    deps = [
         ':GimletSeqFpgaRegs',
    ])
bluespec_library('A0Block',
    sources = [
        'A0Block.bsv',
    ],
    deps = [
         ':GimletSeqFpgaRegs',
    ])
bluespec_library('MiscIO',
    sources = [
        'MiscIO.bsv',
    ],
    deps = [
         ':GimletSeqFpgaRegs',
    ])
bluespec_library('EarlyPowerBlock',
    sources = [
        'EarlyPowerBlock.bsv',
    ],
    deps = [
         ':GimletSeqFpgaRegs',
    ])

bluespec_library('GimletSeqTop',
    sources = [
        'GimletSeqTop.bsv',
    ],
    deps = [
        ':SpiDecode',
        ':NicBlock',
        ':GimletRegs',
        ':EarlyPowerBlock',
        ':A1Block',
        ':A0Block',
        ':MiscIO',
    ],
    )

bluespec_library('GimletSeqTopWrapper',
    sources = [
        'GimletSeqTopWrapper.bsv',
    ],
    deps = [
        'cobalt//hdl/interfaces:ICE40',
        ':GimletSeqTop',
    ],
    using = {
        # The folling script is needed to fix the inout syntax used in the generated Verilog.
        'bsc_flags': [
            '-verilog-filter', ROOT + '/vnd/cobalt/vnd/bluespec/basicinout.pl',
        ]
    }
)

bluespec_sim('gimlet_sim_top',
    top = 'GimletSeqTop.bsv',
    modules = [
        'mkGimletTestTop',
    ],
    deps = [
        ':GimletSeqTop',
    ],
    local = {
        'bsc_flags': ['-suppress-warnings', 'G0046']
    }
    )

bluesim_binary('gimlet_test',
    env = 'cobalt//bluesim_default',
    top = ':gimlet_sim_top#mkGimletTestTop',
    deps = [
        ':gimlet_sim_top',
    ],
    )

bluesim_binary('gimlet_regs_test',
    env = 'cobalt//bluesim_default',
    top = ':gimlet_regs_sim#mkSimpleTest',
    deps = [
        ':gimlet_regs_sim',
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
    env = 'cobalt//bluesim_default',
    top = ':regs_sim#mkTestBenchSimpleReg',
    deps = [
        ':regs_sim',
    ])

bluesim_binary('spi_phy_test',
    env = 'cobalt//bluesim_default',
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

bluespec_verilog('seq_verilog',
    top = 'GimletSeqTopWrapper.bsv',
    modules = [
        'mkGimletSeqTop',
    ],
    deps = [
        ':GimletSeqTopWrapper',
    ],
    # This suppresses the reset sync errors at the top (and seemingly any below also)
    # In this design, that is not a problem since this is a single clock, single reset domain design.
    local = {
        'bsc_flags': ['-suppress-warnings', 'G0046']
    }
    )

yosys_design('ignitionlet_spi_yosys',
    top_module = 'mkIgnitionletTop',
    sources = [
        ':ign_verilog#mkIgnitionletTop',
        'cobalt//vnd/bluespec:Verilog.v#Verilog.v',
    ],
    deps = [
        ':ign_verilog',
        'cobalt//vnd/bluespec:Verilog.v',
    ])

yosys_design('gimlet_sequencer_yosys',
    top_module = 'mkGimletSeqTop',
    sources = [
        ':seq_verilog#mkGimletSeqTop',
        'cobalt//vnd/bluespec:Verilog.v#Verilog.v',
    ],
    deps = [
        ':seq_verilog',
        'cobalt//vnd/bluespec:Verilog.v',
    ])

nextpnr_ice40_bitstream('ignitionlet_spi',
    env = 'ignitionlet_spi',
    design = ':ignitionlet_spi_yosys#ignitionlet_spi_yosys.json',
    deps = [
        ':ignitionlet_spi_yosys',
    ])
nextpnr_ice40_bitstream('gimlet_sequencer',
    env = 'gimlet_sequencer',
    design = ':gimlet_sequencer_yosys#gimlet_sequencer_yosys.json',
    deps = [
        ':gimlet_sequencer_yosys',
    ])