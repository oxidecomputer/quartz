# -*- python -*- vim:syntax=python:

bluespec_library('ECP5',
    sources = [
        'ECP5.bsv',
    ],
    deps = [
        '//hdl/ip/bsv:PLL',
    ])

bluespec_library('ICE40',
    sources = [
        'ICE40.bsv',
    ])

#
# UART package and unit tests.
#

bluespec_library('UART',
    sources = [
        'UART.bsv',
    ],
    deps = [
        '//hdl/ip/bsv:BitSampling',
        '//hdl/ip/bsv:SerialIO',
        '//hdl/ip/bsv:Strobe',
        '//hdl/ip/bsv:TestUtils',
    ])

bluesim_tests('UARTTests',
    env = 'bluesim_default',
    suite = 'UART.bsv',
    modules = [
        'mkSerializerTest',
        'mkDeserializerTest',
        'mkDeserializerStopMissingTest',
        'mkDeserializerOverflowTest',
        'mkSerializerDeserializerTest',
    ],
    deps = [
        ':UART',
    ])

#
# SPI package and unit tests.
#

bluespec_library('SPI',
    sources = [
        'SPI.bsv',
    ],
    deps = [
        '//hdl/ip/bsv:RegCommon',
    ])

bluesim_tests('SPITests',
    env = 'bluesim_default',
    suite = 'SPI.bsv',
    modules = [
        'mkSpiDecodeTest',
        'mkSpiPhyTest',
    ],
    deps = [
        ':SPI',
        '//hdl/ip/bsv:TestUtils',
    ])
