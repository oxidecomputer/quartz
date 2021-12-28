# -*- vim:syntax=python:

def ignition_target_test(name, library):
    module = 'mk' + ''.join([fragment.title() for fragment in name.split('_')])
    object_dep = name + '_object'
    bluespec_sim(object_dep,
        top = library + '.bsv',
        modules = [
            module,
        ],
        deps = [
            ':' + library,
        ])
    bluesim_binary(name,
        env = 'cobalt//bluesim_default',
        top = ':%s#%s' % (object_dep, module),
        deps = [
            ':' + object_dep,
        ])

bluespec_library('SystemResetTests',
    sources = [
        'SystemResetTests.bsv',
    ],
    deps = [
        '//hdl/ignition/target:IgnitionTarget',
        'cobalt//hdl:TestUtils',
    ])

ignition_target_test('system_reset_short_button_press_test', 'SystemResetTests')
ignition_target_test('system_reset_long_button_press_test', 'SystemResetTests')