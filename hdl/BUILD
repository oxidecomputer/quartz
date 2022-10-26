# -*- python -*- vim:syntax=python:

bluespec_library('Bidirection',
    sources = [
        'Bidirection.bsv',
    ])

bluespec_library('CommonFunctions',
    sources = [
        'CommonFunctions.bsv',
    ])

bluespec_library('FanModule',
    sources = [
        'FanModule.bsv',
    ])

bluespec_library('IOSync',
    sources = [
        'IOSync.bsv',
    ],
    deps = [
        ':Bidirection',
    ])

bluespec_library('PowerRail',
    sources = [
        'PowerRail.bsv',
    ],
    deps = [
        'cobalt//hdl:Countdown',
        'cobalt//hdl:Strobe',
    ])
