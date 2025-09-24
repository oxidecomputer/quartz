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
        '//hdl/ip/bsv:RegCommon',
        ':regs_pkg',
    ])

bluespec_library('GimletRegs',
    sources = [
        'GimletRegs.bsv',
    ],
    deps = [
        '//hdl/ip/bsv:GitVersion',
        ':IrqBlock',
        '//hdl/ip/bsv:RegCommon',
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
        '//hdl/ip/bsv:RegCommon',
    ])

bluespec_library('PowerRail',
    sources = [
        'PowerRail.bsv',
    ],
)

bluespec_library('NicBlock',
    sources = [
        'NicBlock.bsv',

    ],
    deps = [
        ':GimletSeqFpgaRegs',
        ':PowerRail',
        '//hdl/ip/bsv:TestUtils',
    ])
bluesim_tests('NICTests',
    env = '//bluesim_default',
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
         '//hdl/ip/bsv:TestUtils',
    ])

bluesim_tests('A1Tests',
    env = '//bluesim_default',
    suite = "A1Block.bsv",
    modules = [
        'mkA1PowerUpTest',
        'mkA1PowerDownTest',
        'mkA1MAPOTest',
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
         '//hdl/ip/bsv:TestUtils',
    ])
bluesim_tests('A0Tests',
    env = '//bluesim_default',
    suite = "A0Block.bsv",
    modules = [
        'mkA0PowerUpTest',
        'mkA0FakeSP3Test',
        'mkA0MAPOTest',
        'mkA0ThermtripTest',
        'mkA0DebugBrokenTest',
        'mkA0PowerErrorsTest',
        'mkFsrReqGpioToggleTest',
    ],
    deps = [
        ':A0Block'
    ]
)
bluesim_tests('TopTests',
    env = '//bluesim_default',
    suite = "GimletSeqTop.bsv",
    modules = [
        'mkGimletTopTest',
        'mkGimletThermtripTopTest',
        'mkGimletAMDResetTripTest',
        'mkGimletAMDPWROKTripTest',
    ],
    deps = [
        ':GimletSeqTop',
    ]
)

bluespec_library('GimletSeqTop',
    sources = [
        'GimletSeqTop.bsv',
    ],
    deps = [
        '//hdl/ip/bsv/interfaces:SPI',
        '//hdl/ip/bsv:TestUtils',
        ':NicBlock',
        ':GimletRegs',
        ':GimletSeqFpgaRegs',
        ':PowerRail',
        ':A1Block',
        ':A0Block',

        # ':MiscIO',
    ],
    )

bluespec_library('GimletTopIOSync',
    sources = [
        'GimletTopIOSync.bsv',
    ],
    deps = [
        '//hdl/ip/bsv/interfaces:ICE40',
        ':GimletSeqTop',
    ],
    using = {
        # The folling script is needed to fix the inout syntax used in the generated Verilog.
        'bsc_flags': [
            '-verilog-filter', ROOT + '/vnd/bluespec/basicinout.pl',
        ]
    }
)

bluespec_verilog('seq_verilog',
    top = 'GimletTopIOSync.bsv',
    modules = [
        'mkGimletSeqTop',
    ],
    deps = [
        ':GimletTopIOSync',
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
#         '//vnd/bluespec:Verilog.v#Verilog.v',
#     ],
#     deps = [
#         ':ign_verilog',
#         '//vnd/bluespec:Verilog.v',
#     ])

yosys_design('gimlet_sequencer_yosys',
    top_module = 'mkGimletSeqTop',
    sources = [
        ':seq_verilog#mkGimletSeqTop',
        '//vnd/bluespec:Verilog.v#Verilog.v',
    ],
    deps = [
        ':seq_verilog',
        '//vnd/bluespec:Verilog.v',
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
         '//hdl/ip/bsv/interfaces:SPI',
         '//hdl/ip/bsv/interfaces:ICE40',
        ':GimletRegs',
    ],
    using = {
        # The following script is needed to fix the inout syntax used in the generated Verilog.
        'bsc_flags': [
            '-verilog-filter', ROOT + '/vnd/bluespec/basicinout.pl',
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
yosys_design('gimlet_sdle_yosys',
    top_module = 'mkGimletPowerSeqTop',
    sources = [
        ':pwr_seq_verilog#mkGimletPowerSeqTop',
        '//vnd/bluespec:Verilog.v#Verilog.v',
    ],
    deps = [
        ':pwr_seq_verilog',
        '//vnd/bluespec:Verilog.v',
    ])
nextpnr_ice40_bitstream('gimlet_sdle_only',
    env = 'gimlet_sequencer',
    design = ':gimlet_sdle_yosys#gimlet_sdle_yosys.json',
    deps = [
        ':gimlet_sdle_yosys',
    ])
