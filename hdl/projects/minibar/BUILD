rdl('minibar_controller_registers',
    sources = [
        '../../ip/bsv/ignition/ignition_controller.rdl',
        'minibar_controller.rdl',
    ],
    outputs = [
        'MinibarRegsPkg.bsv',
        'minibar_regs.html',
        'minibar_regs.adoc',
        'minibar_regs.json',
    ])

bluespec_library('MinibarRegsPkg',
    sources = [
        ':minibar_controller_registers#MinibarRegsPkg.bsv',
    ],
    deps = [
        ':minibar_controller_registers',
        '//hdl/ip/bsv:RegCommon',
    ])

bluespec_library('MinibarMiscRegs',
    sources = [
        'MinibarMiscRegs.bsv',
    ],
    deps = [
        ':MinibarRegsPkg',
        '//hdl/ip/bsv:CommonFunctions',
        '//hdl/ip/bsv:Debouncer',
        '//hdl/ip/bsv:PowerRail',
    ])

bluespec_library('MinibarPcie',
    sources = [
        'MinibarPcie.bsv',
    ],
    deps = [
        ':MinibarRegsPkg',
        '//hdl/ip/bsv:CommonFunctions',
        '//hdl/ip/bsv:PowerRail',
    ])

bluespec_library('MinibarSpiServer',
    sources = [
        'MinibarSpiServer.bsv',
    ],
    deps = [
        ':MinibarRegsPkg',
        ':MinibarMiscRegs',
        ':MinibarPcie',
        '//hdl/ip/bsv:CommonInterfaces',
        '//hdl/ip/bsv:GitVersion',
        '//hdl/ip/bsv:RegCommon',
        '//hdl/ip/bsv/ignition:Controller',
        '//hdl/ip/bsv/ignition:ControllerRegisters',
    ])

bluespec_library('MinibarController',
    sources = [
        'MinibarController.bsv',
    ],
    deps = [
        ':MinibarSpiServer',
        '//hdl/ip/bsv:Strobe',
        '//hdl/ip/bsv/examples:Blinky',
        '//hdl/ip/bsv/ignition:Controller',
        '//hdl/ip/bsv/ignition:Transceiver',
        '//hdl/ip/bsv/interfaces:SPI',
    ])

bluespec_library('MinibarTop',
    sources = [
        'MinibarTop.bsv'
    ],
    deps = [
        ':MinibarController',
        '//hdl/ip/bsv:IOSync',
        '//hdl/ip/bsv:SerialIO',
        '//hdl/ip/bsv:Strobe',
        '//hdl/ip/bsv/ignition:Transceiver',
    ],
    using = {
        # The folling script is needed to fix the inout syntax used in the generated Verilog.
        # For additonal context, see https://github.com/B-Lang-org/bsc/issues/327#issuecomment-786182555
        'bsc_flags': [
            '-verilog-filter', ROOT + '//vnd/bluespec/basicinout.pl',
        ]
    })

# Bitstream

bluespec_verilog('mkMinibarTopV',
    top = 'MinibarTop.bsv',
    modules = [
        'mkMinibarTop',
    ],
    deps = [
        ':MinibarTop',
    ])

yosys_design('minibar_top',
    top_module = 'mkMinibarTop',
    sources = [
        ':mkMinibarTopV#mkMinibarTop',
        '//vnd/bluespec:Verilog.v#Verilog.v',
    ],
    deps = [
        ':mkMinibarTopV',
        '//vnd/bluespec:Verilog.v',
    ])

nextpnr_ecp5_bitstream('minibar_controller_hcv_a',
    env = 'minibar',
    design = ':minibar_top#minibar_top.json',
    deps = [
        ':minibar_top',
    ])