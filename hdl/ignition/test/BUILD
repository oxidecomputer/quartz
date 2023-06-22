# -*- vim:syntax=python:

bluespec_library('TestHelpers',
    sources = [
        'IgnitionTestHelpers.bsv',
    ],
    deps = [
        '//hdl/ignition:Protocol',
        'cobalt//hdl:Encoding8b10b',
        'cobalt//hdl:TestUtils',
        'cobalt//hdl/test:Encoding8b10bReference',
    ])

bluespec_library('Bench',
    sources = [
        'BenchTransceiver.bsv',
        'ControllerBench.bsv',
        'TargetBench.bsv',
    ],
    deps =[
        ':TestHelpers',
        '//hdl/ignition:Controller',
        '//hdl/ignition:Target',
        'cobalt//hdl:Strobe',
        'cobalt//hdl:TestUtils',
    ])

bluespec_library('IgnitionControllerAndTargetBench',
    sources = [
        'IgnitionControllerAndTargetBench.bsv',
    ],
    deps = [
        '//hdl/ignition:Controller',
        '//hdl/ignition:Target',
        'cobalt//hdl:SerialIO',
        'cobalt//hdl:Strobe',
        'cobalt//hdl:TestUtils',
    ])

bluesim_tests('TargetTests',
    env = 'cobalt//bluesim_debug',
    suite = 'TargetTests.bsv',
    modules = [
        'mkPeriodicStatusMessagesTest',
        'mkReportReceiverStatusTest',
        'mkReportLinkEventsTest',
        'mkReportLinkEventsMultipleOccurencesTest',
        'mkReportFaultsTest',
        'mkControllerPresentTest',
        'mkSystemPowerOnRequestTest',
        'mkSystemPowerOffRequestTest',
        'mkSystemResetRequestTest',
        'mkSystemResetShortButtonPressTest',
        'mkSystemResetLongButtonPressTest',
        'mkSystemPowerOnWhenResetButtonPressTest',
        'mkSystemPowerAbortOnA2FaultTest',
        'mkSystemPowerAbortOnA3FaultTest',
        'mkSystemPowerAbortOnA3FaultTimeoutTest',
        'mkRequestRestartAfterSystemPowerAbortTest',
        'mkResetButtonRestartAfterSystemPowerAbortTest',
        'mkPowerButtonRestartAfterSystemPowerAbortTest',
        'mkPowerFaultBitsStickyAfterSystemPowerAbortTest',
        'mkSystemPowerFaultMonitorDisabledDuringResetTest',
        'mkSystemPowerHotswapControllerRestartTest',
    ],
    deps = [
        ':Bench',
        ':TestHelpers',
        'cobalt//hdl:TestUtils',
    ])

bluesim_tests('ControllerTests',
    env = 'cobalt//bluesim_default',
    suite = 'ControllerTests.bsv',
    modules = [
        'mkPeriodicHelloTest',
        'mkTargetPresentTest',
        'mkTargetStateValidIfPresentTest',
        'mkTargetLinkStatusTest',
        'mkSendSystemPowerOffRequestTest',
        'mkSendSystemPowerOnRequestTest',
        'mkSendSystemResetRequestTest',
        'mkDropHelloTest',
        'mkDropRequestTest',
        'mkTargetLinkEventsTest',
    ],
    deps = [
        ':Bench',
        ':TestHelpers',
        'cobalt//hdl:TestUtils',
    ])

bluesim_tests('MessageParserTests',
    env = 'cobalt//bluesim_default',
    suite = 'MessageParserTests.bsv',
    modules = [
        'mkParseIdle1Test',
        'mkParseIdle1PolarityInvertedTest',
        'mkParseIdle2Test',
        'mkParseIdle2PolarityInvertedTest',
        'mkParseHelloTest',
        'mkParseSystemPowerOnRequestTest',
        'mkParseSystemPowerOffRequestTest',
        'mkParseSystemResetRequestTest',
        'mkParseStatusTest',
        'mkParseVersionInvalidTest',
        'mkParseMessageTypeInvalidTest',
        'mkParseRequestInvalidTest',
        'mkParseChecksumInvalidTest',
        'mkParseOrderedSetInvalidTest',
    ],
    deps = [
        ':TestHelpers',
        '//hdl/ignition:Protocol',
        'cobalt//hdl:TestUtils',
    ])

bluesim_tests('ControllerMessageParserTests',
    env = 'cobalt//bluesim_default',
    suite = 'ControllerMessageParserTests.bsv',
    modules = [
        'mkParseIdle1Test',
        'mkParseIdle1PolarityInvertedTest',
        'mkParseIdle2Test',
        'mkParseIdle2PolarityInvertedTest',
        'mkParseHelloTest',
        'mkParseSystemPowerOnRequestTest',
        'mkParseSystemPowerOffRequestTest',
        'mkParseSystemResetRequestTest',
        'mkParseStatusTest',
        'mkParseVersionInvalidTest',
        'mkParseMessageTypeInvalidTest',
        'mkParseRequestInvalidTest',
        'mkParseChecksumInvalidTest',
        'mkParseOrderedSetInvalidTest',
    ],
    deps = [
        ':TestHelpers',
        '//hdl/ignition:Protocol',
        'cobalt//hdl:TestUtils',
    ])

bluesim_tests('DeparserTests',
    env = 'cobalt//bluesim_default',
    suite = 'DeparserTests.bsv',
    modules = [
        'mkDeparseHelloTest',
        'mkDeparseSystemPowerOffRequestTest',
        'mkDeparseSystemPowerOnRequestTest',
        'mkDeparseSystemResetRequestTest',
        'mkDeparseStatusTest',
    ],
    deps = [
        ':TestHelpers',
        '//hdl/ignition:Protocol',
        'cobalt//hdl:TestUtils',
    ])

bluesim_tests('CRCTests',
    env = 'cobalt//bluesim_default',
    suite = 'CRCTests.bsv',
    modules = [
        'mkPattern1Test',
        'mkPattern2Test',
        'mkPattern3Test',
        'mkPattern4Test',
        'mkPattern5Test',
        'mkPattern6Test',
        'mkPattern7Test',
        'mkHelloTest',
        'mkSystemPowerOffRequestTest',
        'mkSystemPowerOnRequestTest',
        'mkSystemResetRequestTest',
    ],
    deps = [
        ':TestHelpers',
        '//hdl/ignition:Protocol',
        'cobalt//hdl:TestUtils',
    ])

bluesim_tests('ReceiverTests',
    env = 'cobalt//bluesim_default',
    suite = 'ReceiverTests.bsv',
    modules = [
        'mkStartUpFromIdleTest',
        'mkStartUpFromIdlePolarityInvertedTest',
        'mkResetAfterInvalidCommaLikeCharacter',
        'mkLockedTimeoutTest',
        'mkNoLockedTimeoutIfReceiverLockedTest',
    ],
    deps = [
        ':TestHelpers',
        '//hdl/ignition:Protocol',
        '//hdl/ignition:Transceiver',
        'cobalt//hdl:TestUtils',
        'cobalt//hdl/test:Encoding8b10bReference',
    ])

bluesim_tests('TransmitterTests',
    env = 'cobalt//bluesim_default',
    suite = 'TransmitterTests.bsv',
    modules = [
        'mkTransmitIdleTest',
        'mkTransmitIdle1HelloEndOfMessage2Idle1Test',
        'mkTransmitIdle1RequestIdle2Test',
        'mkTransmitIdleBetweenBackToBackHelloTest',
    ],
    deps = [
        ':TestHelpers',
        '//hdl/ignition:Protocol',
        '//hdl/ignition:Transceiver',
        'cobalt//hdl:TestUtils',
    ])

bluesim_tests('TransceiverTests',
    env = 'cobalt//bluesim_default',
    suite = 'TransceiverTests.bsv',
    modules = [
        'mkStartUpTest',
        'mkStartUpPolarityInvertedTest',
        'mkReceiveHelloTest',
        'mkRestartFromIdleLowTest',
        'mkRestartFromIdleHighTest',
        'mkRestartFromAlmostCommaPatternTest',
    ],
    deps = [
        ':TestHelpers',
        '//hdl/ignition:Protocol',
        '//hdl/ignition:Transceiver',
        'cobalt//hdl:TestUtils',
    ])

bluesim_tests('TargetTransceiverTests',
    env = 'cobalt//bluesim_debug',
    suite = 'TargetTransceiverTests.bsv',
    modules = [
        'mkStartUpLink0Test',
        'mkStartUpLink0PolarityInvertedTest',
        'mkStartUpLink1Test',
        'mkStartUpLink1PolarityInvertedTest',
        'mkStartUpLink0Link1Test',
        'mkStartUpLink0PolarityInvertedLink1Test',
        'mkStartUpLink0Link1PolarityInvertedTest',
        'mkStartUpLink0PolarityInvertedLink1PolarityInvertedTest',
        'mkReceiveHelloLink0Test',
        'mkReceiveHelloLink1Test',
        'mkReceiveHelloLink0Link1Test',
        'mkRestartLink0FromIdleLowTest',
        'mkRestartLink1FromIdleLowTest',
    ],
    deps = [
        ':TestHelpers',
        '//hdl/ignition:Protocol',
        '//hdl/ignition:Transceiver',
        'cobalt//hdl:TestUtils',
    ],
    local = {
        #'bsc_flags': [
        #    '-show-schedule',
        #],
    })

bluesim_tests('IntegrationTests',
    env = 'cobalt//bluesim_default',
    suite = 'IntegrationTests.bsv',
    modules = [
        'mkControllerAlwaysTransmitOverrideTest',
        'mkControllerTargetPresentTest',
        'mkNoLockedTimeoutIfReceiversLockedTest',
        'mkReceiversLockedTimeoutTest',
        'mkTargetLinkEventsTest',
        'mkTargetRoTFaultTest',
        'mkTargetSystemResetTest',
    ],
    deps = [
        ':IgnitionControllerAndTargetBench',
        ':TestHelpers',
    ])

# bluespec_verilog('TransceiverEcp5EvnTests',
#     top = 'TransceiverEcp5EvnTests.bsv',
#     modules = [
#         'mkTransceiverLoopbackEcp5EvnTestTop',
#     ],
#     deps = [
#         ':TestHelpers',
#         '//hdl/ignition:Transceiver',
#         'cobalt//hdl/boards/ecp5_evn:Board',
#     ])

# yosys_design('transceiver_loopback_ecp5_evn_test_top',
#     top_module = 'mkTransceiverLoopbackEcp5EvnTestTop',
#     sources = [
#         ':TransceiverEcp5EvnTests#mkTransceiverLoopbackEcp5EvnTestTop',
#         'cobalt//vnd/bluespec:Verilog.v#Verilog.v',
#         '../../../vnd/cobalt/hdl/InitialReset.v',
#     ],
#     deps = [
#         ':TransceiverEcp5EvnTests',
#         'cobalt//vnd/bluespec:Verilog.v',
#     ])

# nextpnr_ecp5_bitstream('transceiver_loopback_ecp5_evn_test',
#     env = 'cobalt//ecp5_evn_test',
#     design = ':transceiver_loopback_ecp5_evn_test_top#transceiver_loopback_ecp5_evn_test_top.json',
#     deps = [
#         ':transceiver_loopback_ecp5_evn_test_top',
#     ])

# bluesim_tests('IgnitionletTransceiverLoopbackTest',
#     env = 'cobalt//bluesim_default',
#     suite = 'IgnitionletTransceiverLoopbackTest.bsv',
#     modules = [
#         'mkIgnitionletTransceiverLoopbackTest',
#     ],
#     deps = [
#         ':TestHelpers',
#         '//hdl/ignition:Transceiver',
#         '//hdl/boards/ignitionlet:Board',
#     ])

# bluespec_verilog('IgnitionletTransceiverLoopbackTest_verilog',
#     top = 'IgnitionletTransceiverLoopbackTest.bsv',
#     modules = [
#         'mkIgnitionletTransceiverLoopbackTestTop',
#     ],
#     deps = [
#         ':TestHelpers',
#         '//hdl/ignition:Transceiver',
#         '//hdl/boards/ignitionlet:Board',
#     ])

# yosys_design('ignitionlet_transceiver_loopback_test_top',
#     top_module = 'mkIgnitionletTransceiverLoopbackTestTop',
#     sources = [
#         ':IgnitionletTransceiverLoopbackTest_verilog#mkIgnitionletTransceiverLoopbackTestTop',
#         'cobalt//vnd/bluespec:Verilog.v#Verilog.v',
#         '../../../vnd/cobalt/hdl/InitialReset.v',
#     ],
#     deps = [
#         ':IgnitionletTransceiverLoopbackTest_verilog',
#         'cobalt//vnd/bluespec:Verilog.v',
#     ])

# nextpnr_ice40_bitstream('igntionlet_transceiver_loopback_test',
#     env = '//ignitionlet_sequencer',
#     design = ':ignitionlet_transceiver_loopback_test_top#ignitionlet_transceiver_loopback_test_top.json',
#     deps = [
#         ':ignitionlet_transceiver_loopback_test_top',
#     ])
