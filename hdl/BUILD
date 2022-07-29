# -*- python -*- vim:syntax=python:

bluespec_library('Common',
    sources = [
        'Common.bsv',
    ])

bluespec_library('FanModule',
    sources = [
        'FanModule.bsv',
    ])

bluespec_library('IOSync',
    sources = [
        'IOSync.bsv',
    ])

bluespec_library('PowerRail',
    sources = [
        'PowerRail.bsv',
    ],
    deps = [
        'cobalt//hdl:Countdown',
        'cobalt//hdl:Strobe',
    ])
