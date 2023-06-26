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

bluesim_tests('TofinoDebugPortTests',
    suite = 'TofinoDebugPortTests.bsv',
    env = 'cobalt//bluesim_default',
    modules = [
        'mkClearSendBufferTest',
        'mkAbortRequestOnAddressNackTest',
        'mkLocalReadTest',
        'mkLocalWriteTest',
        'mkDirectReadTest',
        'mkDirectWriteTest',
    ],
    deps = [
        '//hdl/boards/sidecar/mainboard:TofinoDebugPort',
        '//hdl/I2C:I2CPeripheralModel',
        'cobalt//hdl:TestUtils',
    ])

bluesim_tests('Tofino2SequencerTests',
    suite = 'Tofino2SequencerTests.bsv',
    env = 'cobalt//bluesim_default',
    modules = [
        'mkAckVidTimeoutTest',
        'mkCtrlEnNotSetAfterClearError',
        'mkPCIeResetHeldOnPowerUpTest',
        'mkPCIeResetInA0Test',
        'mkPowerDisabledDuringPowerUpTest',
        'mkPowerDisabledInA0Test',
        'mkPowerDownTest',
        'mkPowerFaultDuringPowerUpTest',
        'mkPowerFaultInA0Test',
        'mkPowerGoodTimeoutTest',
        'mkPowerUpTest',
        'mkSoftwareAbortDuringPowerUpTest',
        'mkThermalAlertDuringPowerUpTest',
        'mkThermalAlertInA0Test',
        'mkVddPcieDisabledOnFaultDuringPowerUpTest',
        'mkVddPcieDisabledOnFaultInA0Test',
        'mkVrHotDuringPowerUpTest',
        'mkVrHotInA0Test',
    ],
    deps = [
        '//hdl:PowerRail',
        '//hdl/boards/sidecar/mainboard:Tofino2Sequencer',
        'cobalt//hdl:Strobe',
        'cobalt//hdl:TestUtils',
    ])

bluesim_tests('MainboardControllerTests',
    suite = 'MainboardControllerTests.bsv',
    env = 'cobalt//bluesim_default',
    modules = [
        'mkFrontIOHSCTest',
    ],
    deps = [
        '//hdl:PowerRail',
        '//hdl/boards/sidecar/mainboard:SidecarMainboardController',
        'cobalt//hdl:TestUtils',
    ])
