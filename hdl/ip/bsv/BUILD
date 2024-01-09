# -*- python -*- vim:syntax=python:

bluespec_library('CommonFunctions',
    sources = [
        'CommonFunctions.bsv',
    ])

bluespec_library('FanModule',
    sources = [
        'FanModule.bsv',
    ])

bluespec_library('PowerRail',
    sources = [
        'power_rail/PowerRail.bsv',
    ],
    deps = [
        'cobalt//hdl:Countdown',
        'cobalt//hdl:Strobe',
    ])

bluespec_library('SettableCRC',
    sources = [
        'SettableCRC.bsv',
    ])
