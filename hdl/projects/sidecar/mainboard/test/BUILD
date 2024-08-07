# -*- python -*- vim:syntax=python:

bluespec_library('MockTofino2Sequencer',
    sources = [
        'MockTofino2Sequencer.bsv',
    ],
    deps = [
        '//hdl/ip/bsv:CommonFunctions',
        '//hdl/projects/sidecar/mainboard:Tofino2Sequencer',
    ])

bluesim_tests('PCIeEndpointControllerTests',
    suite = 'PCIeEndpointControllerTests.bsv',
    env = '//bluesim_default',
    modules = [
        'mkResetHostControlTest',
        'mkResetSoftwareControlTest',
        'mkSequencerFaultSoftwareOverrideTest',
        'mkSequencerFaultTest',
    ],
    deps = [
        ':MockTofino2Sequencer',
        '//hdl/ip/bsv:PowerRail',
        '//hdl/ip/bsv:Strobe',
        '//hdl/ip/bsv:TestUtils',
        '//hdl/ip/bsv:Debouncer',
        '//hdl/projects/sidecar/mainboard:PCIeEndpointController',
    ])

bluesim_tests('TofinoDebugPortTests',
    suite = 'TofinoDebugPortTests.bsv',
    env = '//bluesim_default',
    modules = [
        'mkClearSendBufferTest',
        'mkAbortRequestOnAddressNackTest',
        'mkLocalReadTest',
        'mkLocalWriteTest',
        'mkDirectReadTest',
        'mkDirectWriteTest',
    ],
    deps = [
        '//hdl/ip/bsv:TestUtils',
        '//hdl/ip/bsv/I2C:I2CPeripheralModel',
        '//hdl/projects/sidecar/mainboard:TofinoDebugPort',
    ])

bluesim_tests('Tofino2SequencerTests',
    suite = 'Tofino2SequencerTests.bsv',
    env = '//bluesim_default',
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
        '//hdl/ip/bsv:PowerRail',
        '//hdl/ip/bsv:Strobe',
        '//hdl/ip/bsv:TestUtils',
        '//hdl/projects/sidecar/mainboard:Tofino2Sequencer',
    ])

bluesim_tests('MainboardControllerTests',
    suite = 'MainboardControllerTests.bsv',
    env = '//bluesim_default',
    modules = [
        'mkFrontIOHSCTest',
    ],
    deps = [
        '//hdl/projects/sidecar/mainboard:SidecarMainboardController',
        '//hdl/ip/bsv:PowerRail',
        '//hdl/ip/bsv:TestUtils',
    ])

bluesim_tests('SpiServerTests',
    suite = 'SidecarMainboardControllerSpiServerTests.bsv',
    env = '//bluesim_default',
    modules = [
        'mkReadIdTest',
        'mkReadIgnitionCounterTest',
        'mkReadIgnitionPortCountTest',
        'mkReadIgnitionPresenceSummaryTest',
        'mkReadIgnitionTargetStatusTest',
        'mkReadIgnitionTransceiverStateTest',
        'mkSetIgnitionTransmitterOutputEnableModeTest',
    ],
    deps = [
        '//hdl/ip/bsv:FanModule',
        '//hdl/ip/bsv:PowerRail',
        '//hdl/ip/bsv:TestUtils',
        '//hdl/ip/bsv/ignition/test:TestHelpers',
        '//hdl/projects/sidecar/mainboard:SidecarMainboardController',
    ])
