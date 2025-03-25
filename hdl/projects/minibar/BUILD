bluespec_library('MinibarTop',
    sources = [
        'MinibarTop.bsv'
    ],
    deps = [
        '//hdl/ip/bsv/examples:Blinky',
    ],
    using = {
        # The folling script is needed to fix the inout syntax used in the generated Verilog.
        # For additonal context, see https://github.com/B-Lang-org/bsc/issues/327#issuecomment-786182555
        'bsc_flags': [
            '-verilog-filter', ROOT + '//vnd/bluespec/basicinout.pl',
        ]
    })

bluespec_verilog('mkMinibarTop',
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
        ':mkMinibarTop#mkMinibarTop',
        '//vnd/bluespec:Verilog.v#Verilog.v',
    ],
    deps = [
        ':mkMinibarTop',
        '//vnd/bluespec:Verilog.v',
    ])

nextpnr_ecp5_bitstream('minibar_hcv_a',
    env = 'minibar',
    design = ':minibar_top#minibar_top.json',
    deps = [
        ':minibar_top',
    ])