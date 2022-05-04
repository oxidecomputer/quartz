# -*- python -*- vim:syntax=python:

bluesim_tests('SystemResetTests',
    env = 'cobalt//bluesim_default',
    suite = 'SystemResetTests.bsv',
    modules = [
        'mkSystemResetShortButtonPressTest',
        'mkSystemResetLongButtonPressTest',
    ],
    deps = [
        '//hdl/ignition/target:IgnitionTarget',
        'cobalt//hdl:TestUtils',
    ])
