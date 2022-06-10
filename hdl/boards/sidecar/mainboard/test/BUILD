# -*- python -*- vim:syntax=python:

bluesim_tests('PCIeEndpointControllerTests',
    suite = 'PCIeEndpointControllerTests.bsv',
    env = 'cobalt//bluesim_default',
    modules = [
        'mkResetHostControlTest',
        'mkResetSoftwareControlTest',
    ],
    deps = [
        '//hdl:PowerRail',
        '//hdl/boards/sidecar/mainboard:PCIeEndpointController',
        'cobalt//hdl:Strobe',
        'cobalt//hdl:TestUtils',
    ])

bluesim_tests('Tofino2SequencerTests',
    suite = 'Tofino2SequencerTests.bsv',
    env = 'cobalt//bluesim_default',
    modules = [
        'mkPowerUpTest',
        'mkPowerDownTest',
        'mkPowerUpAbortTest',
        'mkPowerGoodTimeoutTest',
        'mkPowerDisabledDuringPowerUpTest',
        'mkPowerDisabledInA0Test',
        'mkAckVidTimeoutTest',
        'mkPowerFaultDuringPowerUpTest',
        'mkVrHotDuringPowerUpTest',
        'mkPowerFaultInA0Test',
        'mkVrHotInA0Test',
        'mkPCIeResetHeldOnPowerUpTest',
        'mkPCIeResetInA0Test',
        'mkThermalAlertDuringPowerUpTest',
        'mkThermalAlertInA0Test',
        'mkCtrlEnClearedOnFault',
    ],
    deps = [
        '//hdl:PowerRail',
        '//hdl/boards/sidecar/mainboard:Tofino2Sequencer',
        'cobalt//hdl:Strobe',
        'cobalt//hdl:TestUtils',
    ])
