# -*- python -*- vim:syntax=python:

bluespec_library('Board',
    sources = [
        'Board.bsv',
    ],
    deps = [
        '//hdl/ip/bsv/interfaces:ECP5',
    ])

bluespec_verilog('examples',
    top = 'Examples.bsv',
    modules = [
        'mkBlinky',
        'mkLoopbackUART',
        'mkClocks',
    ],
    deps = [
        ':Board',
        '//hdl/ip/bsv/examples:Blinky',
        '//hdl/ip/bsv/examples:LoopbackUART',
    ])

# Blinky design targets

yosys_design('blinky',
    top_module = 'mkBlinky',
    sources = [
        ':examples#mkBlinky',
    ],
    deps = [
        ':examples',
    ])

nextpnr_ecp5_bitstream('blinky_ecp5_evn',
    env = 'ecp5_evn',
    design = ':blinky#blinky.json',
    deps = [
        ':blinky',
    ])

# UART loopback design targets

yosys_design('loopback_uart',
    top_module = 'mkLoopbackUART',
    sources = [
        ':examples#mkLoopbackUART',
        '//vnd/bluespec:Verilog.v#Verilog.v',
    ],
    deps = [
        ':examples',
        '//vnd/bluespec:Verilog.v',
    ])

nextpnr_ecp5_bitstream('loopback_uart_ecp5_evn',
    env = 'ecp5_evn',
    design = ':loopback_uart#loopback_uart.json',
    deps = [
        ':loopback_uart',
    ])

# Clocks/PLL design targets

yosys_design('clocks',
    top_module = 'mkClocks',
    sources = [
        ':examples#mkClocks',
        '../../ip/bsv/interfaces/ECP5PLL.v', # This is a hack, we should improve this
        '//vnd/bluespec:Verilog.v#Verilog.v',
    ],
    deps = [
        ':examples',
        '//vnd/bluespec:Verilog.v',
    ])

nextpnr_ecp5_bitstream('clocks_ecp5_evn',
    env = 'ecp5_evn',
    design = ':clocks#clocks.json',
    deps = [
        ':clocks',
    ])
