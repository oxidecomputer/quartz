# -*- python -*- vim:syntax=python:

bluespec_library('IrqBlock',
    sources = [
        'IrqBlock.bsv',
    ])

rdl('regs_pkg',
    sources = [
        'gimlet_seq_fpga_regs.rdl'
    ],
    outputs = [
        'GimletSeqFpgaRegs.bsv',
        'gimlet_regs.html',
        'gimlet_regs.json',
    ]
)

bluespec_library('GimletSeqFpgaRegs',
    sources = [
        ':regs_pkg#GimletSeqFpgaRegs.bsv',
    ],
    deps = [
        'cobalt//hdl:RegCommon',
        ':regs_pkg',
    ])

bluespec_library('GimletRegs',
    sources = [
        'GimletRegs.bsv',
    ],
    deps = [
        'cobalt//hdl:GitVersion',
        ':IrqBlock',
        'cobalt//hdl:RegCommon',
        ':GimletSeqFpgaRegs',
        ':NicBlock',
        # ':EarlyPowerBlock',
        ':A1Block',
        ':A0Block',
        # ':MiscIO',
    ])

bluespec_library('Regs',
    sources = [
        'Regs.bsv',
    ],
    deps = [
        'cobalt//hdl:RegCommon',
    ])

bluespec_library('PowerRail',
    sources = [
        'PowerRail.bsv',
         'cobalt//hdl:TestUtils',
    ],
)

bluespec_library('NicBlock',
    sources = [
        'NicBlock.bsv',

    ],
    deps = [
        ':GimletSeqFpgaRegs',
        ':PowerRail',
        'cobalt//hdl:TestUtils',
    ])
bluesim_tests('NICTests',
    env = 'cobalt//bluesim_default',
    suite = "NicBlock.bsv",
    modules = [
        'mkPowerUpNicTest',
    ],
    deps = [
        ':NicBlock'
    ]
)

bluespec_library('A1Block',
    sources = [
        'A1Block.bsv',
    ],
    deps = [
         ':GimletSeqFpgaRegs',
         ':PowerRail',
         'cobalt//hdl:TestUtils',
    ])

bluesim_tests('A1Tests',
    env = 'cobalt//bluesim_default',
    suite = "A1Block.bsv",
    modules = [
        'mkA1PowerUpTest',
        'mkA1PowerDownTest',
        'mkA1MAPOTest',
        'mkA1PowerDownA0InteractionTest',
    ],
    deps = [
        ':A1Block'
    ]
)
bluespec_library('A0Block',
    sources = [
        'A0Block.bsv',
    ],
    deps = [
         ':GimletSeqFpgaRegs',
         ':PowerRail',
         'cobalt//hdl:TestUtils',
    ])
bluesim_tests('A0Tests',
    env = 'cobalt//bluesim_default',
    suite = "A0Block.bsv",
    modules = [
        'mkA0PowerUpTest',
        'mkA0FakeSP3Test',
        'mkA0MAPOTest',
    ],
    deps = [
        ':A0Block'
    ]
)
bluesim_tests('TopTests',
    env = 'cobalt//bluesim_default',
    suite = "GimletSeqTop.bsv",
    modules = [
        'mkGimletTestTop',
    ],
    deps = [
        ':GimletSeqTop',
        'cobalt//hdl:TestUtils',
    ]
)
# bluespec_library('MiscIO',
#     sources = [
#         'MiscIO.bsv',
#     ],
#     deps = [
#          ':GimletSeqFpgaRegs',
#     ])
# bluespec_library('EarlyPowerBlock',
#     sources = [
#         'EarlyPowerBlock.bsv',
#     ],
#     deps = [
#          ':GimletSeqFpgaRegs',
#     ])

bluespec_library('GimletSeqTop',
    sources = [
        'GimletSeqTop.bsv',
    ],
    deps = [
        'cobalt//hdl/interfaces:SPI',
        ':NicBlock',
        ':GimletRegs',
        ':GimletSeqFpgaRegs',
        # ':EarlyPowerBlock',
        ':A1Block',
        ':A0Block',
        # ':MiscIO',
    ],
    )

bluespec_library('GimletIOSync',
    sources = [
        'GimletIOSync.bsv',
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

bluespec_verilog('seq_verilog',
    top = 'GimletIOSync.bsv',
    modules = [
        'mkGimletSeqTop',
    ],
    deps = [
        ':GimletIOSync',
    ],
    # This suppresses the reset sync errors at the top (and seemingly any below also)
    # In this design, that is not a problem since this is a single clock, single reset domain design.
    local = {
        'bsc_flags': ['-suppress-warnings', 'G0046']
    }
    )

# yosys_design('ignitionlet_spi_yosys',
#     top_module = 'mkIgnitionletTop',
#     sources = [
#         ':ign_verilog#mkIgnitionletTop',
#         'cobalt//vnd/bluespec:Verilog.v#Verilog.v',
#     ],
#     deps = [
#         ':ign_verilog',
#         'cobalt//vnd/bluespec:Verilog.v',
#     ])

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

# nextpnr_ice40_bitstream('ignitionlet_spi',
#     env = 'ignitionlet_spi',
#     design = ':ignitionlet_spi_yosys#ignitionlet_spi_yosys.json',
#     deps = [
#         ':ignitionlet_spi_yosys',
#     ])
nextpnr_ice40_bitstream('gimlet_sequencer',
    env = 'gimlet_sequencer',
    design = ':gimlet_sequencer_yosys#gimlet_sequencer_yosys.json',
    deps = [
        ':gimlet_sequencer_yosys',
    ])

bluespec_library('AllEnable',
    sources = [
        'AllEnable.bsv',
    ],
    deps = [
         'cobalt//hdl/interfaces:SPI',
         'cobalt//hdl/interfaces:ICE40',
        ':GimletRegs',
    ],
    using = {
        # The folling script is needed to fix the inout syntax used in the generated Verilog.
        'bsc_flags': [
            '-verilog-filter', ROOT + '/vnd/cobalt/vnd/bluespec/basicinout.pl',
        ]
    }
    )
bluespec_verilog('pwr_seq_verilog',
    top = 'AllEnable.bsv',
    modules = [
        'mkGimletPowerSeqTop',
    ],
    deps = [
        ':AllEnable',
    ],
    # This suppresses the reset sync errors at the top (and seemingly any below also)
    # In this design, that is not a problem since this is a single clock, single reset domain design.
    local = {
        'bsc_flags': ['-suppress-warnings', 'G0046']
    }
    )
yosys_design('gimlet_power_seq_yosys',
    top_module = 'mkGimletPowerSeqTop',
    sources = [
        ':pwr_seq_verilog#mkGimletPowerSeqTop',
        'cobalt//vnd/bluespec:Verilog.v#Verilog.v',
    ],
    deps = [
        ':pwr_seq_verilog',
        'cobalt//vnd/bluespec:Verilog.v',
    ])
nextpnr_ice40_bitstream('gimlet_power_seq',
    env = 'gimlet_sequencer',
    design = ':gimlet_power_seq_yosys#gimlet_power_seq_yosys.json',
    deps = [
        ':gimlet_power_seq_yosys',
    ])