# -*- vim:syntax=python:

bluespec_library('TestHelpers',
    sources = [
        'IgnitionTestHelpers.bsv',
    ],
    deps = [
        '//hdl/ip/bsv/ignition:Controller',
        '//hdl/ip/bsv/ignition:Protocol',
        '//hdl/ip/bsv/ignition:Transceiver',
        '//hdl/ip/bsv:Encoding8b10b',
        '//hdl/ip/bsv:TestUtils',
        '//hdl/ip/bsv/test:Encoding8b10bReference',
    ])

bluespec_library('Bench',
    sources = [
        'BenchTransceiver.bsv',
        'ControllerBench.bsv',
        'TargetBench.bsv',
    ],
    deps =[
        ':TestHelpers',
        '//hdl/ip/bsv/ignition:Controller',
        '//hdl/ip/bsv/ignition:Target',
        '//hdl/ip/bsv:Strobe',
        '//hdl/ip/bsv:TestUtils',
    ])

bluespec_library('IgnitionControllerAndTargetBench',
    sources = [
        'IgnitionControllerAndTargetBench.bsv',
    ],
    deps = [
        '//hdl/ip/bsv/ignition:Controller',
        '//hdl/ip/bsv/ignition:Target',
        '//hdl/ip/bsv:SerialIO',
        '//hdl/ip/bsv:Strobe',
        '//hdl/ip/bsv:TestUtils',
    ])

bluesim_tests('TargetTests',
    env = '//bluesim_debug',
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
        '//hdl/ip/bsv:TestUtils',
    ])

bluesim_tests('ControllerTests',
    env = '//bluesim_default',
    suite = 'ControllerTests.bsv',
    modules = [
        'mkPeriodicHelloTest',
        'mkReadTargetSystemStatusController0PresentTest',
        'mkReadTargetSystemStatusController1PresentTest',
        'mkReadTargetSystemStatusSystemPowerAbortTest',
        'mkReadTargetSystemStatusSystemPowerEnabledTest',
        'mkReadTargetSystemTypeRegisterTest',
        'mkReceiverResetEventTest',
        'mkSendSystemPowerOffRequestTest',
        'mkSendSystemPowerOnRequestTest',
        'mkSendSystemPowerResetRequestTest',
        'mkTargetLinkEventsTest',
        'mkTargetLinkStatusTest',
        'mkTargetPresentTest',
        'mkTargetStateValidIfPresentTest',
    ],
    deps = [
        ':Bench',
        ':TestHelpers',
        '//hdl/ip/bsv:TestUtils',
    ])

bluesim_tests('MessageParserTests',
    env = '//bluesim_default',
    suite = 'MessageParserTests.bsv',
    modules = [
        'mkParseIdle1Test',
        'mkParseIdle1PolarityInvertedTest',
        'mkParseIdle2Test',
        'mkParseIdle2PolarityInvertedTest',
        'mkParseHelloTest',
        'mkParseSystemPowerOnRequestTest',
        'mkParseSystemPowerOffRequestTest',
        'mkParseSystemPowerResetRequestTest',
        'mkParseStatusTest',
        'mkParseVersionInvalidTest',
        'mkParseMessageTypeInvalidTest',
        'mkParseRequestInvalidTest',
        'mkParseChecksumInvalidTest',
        'mkParseOrderedSetInvalidTest',
    ],
    deps = [
        ':TestHelpers',
        '//hdl/ip/bsv/ignition:Protocol',
        '//hdl/ip/bsv:TestUtils',
    ])

bluesim_tests('ControllerMessageParserTests',
    env = '//bluesim_default',
    suite = 'ControllerMessageParserTests.bsv',
    modules = [
        'mkParseIdle1Test',
        'mkParseIdle1PolarityInvertedTest',
        'mkParseIdle2Test',
        'mkParseIdle2PolarityInvertedTest',
        'mkParseHelloTest',
        'mkParseSystemPowerOnRequestTest',
        'mkParseSystemPowerOffRequestTest',
        'mkParseSystemPowerResetRequestTest',
        'mkParseStatusTest',
        'mkParseVersionInvalidTest',
        'mkParseMessageTypeInvalidTest',
        'mkParseRequestInvalidTest',
        'mkParseChecksumInvalidTest',
        'mkParseOrderedSetInvalidTest',
    ],
    deps = [
        ':TestHelpers',
        '//hdl/ip/bsv/ignition:Protocol',
        '//hdl/ip/bsv:TestUtils',
    ])

bluesim_tests('DeparserTests',
    env = '//bluesim_default',
    suite = 'DeparserTests.bsv',
    modules = [
        'mkDeparseHelloTest',
        'mkDeparseSystemPowerOffRequestTest',
        'mkDeparseSystemPowerOnRequestTest',
        'mkDeparseSystemPowerResetRequestTest',
        'mkDeparseStatusTest',
    ],
    deps = [
        ':TestHelpers',
        '//hdl/ip/bsv/ignition:Protocol',
        '//hdl/ip/bsv:TestUtils',
    ])

bluesim_tests('CRCTests',
    env = '//bluesim_default',
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
        '//hdl/ip/bsv/ignition:Protocol',
        '//hdl/ip/bsv:TestUtils',
    ])

bluesim_tests('ReceiverTests',
    env = '//bluesim_default',
    suite = 'ReceiverTests.bsv',
    modules = [
        'mkStartUpFromIdleTest',
        'mkStartUpFromIdlePolarityInvertedTest',
        'mkResetAfterInvalidCommaLikeCharacter',
        'mkLockedTimeoutTest',
        'mkNoLockedTimeoutIfReceiverLockedTest',
        'mkControllerReceiverTest',
    ],
    deps = [
        ':TestHelpers',
        '//hdl/ip/bsv/ignition:Protocol',
        '//hdl/ip/bsv/ignition:Transceiver',
        '//hdl/ip/bsv:TestUtils',
        '//hdl/ip/bsv/test:Encoding8b10bReference',
    ])

bluesim_tests('TransmitterTests',
    env = '//bluesim_default',
    suite = 'TransmitterTests.bsv',
    modules = [
        'mkTransmitIdleTest',
        'mkTransmitIdle1HelloEndOfMessage2Idle1Test',
        'mkTransmitIdle1RequestIdle2Test',
        'mkTransmitIdleBetweenBackToBackHelloTest',
    ],
    deps = [
        ':TestHelpers',
        '//hdl/ip/bsv/ignition:Protocol',
        '//hdl/ip/bsv/ignition:Transceiver',
        '//hdl/ip/bsv:TestUtils',
    ])

bluesim_tests('TransceiverTests',
    env = '//bluesim_default',
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
        '//hdl/ip/bsv/ignition:Protocol',
        '//hdl/ip/bsv/ignition:Transceiver',
        '//hdl/ip/bsv:TestUtils',
    ])

bluesim_tests('TargetTransceiverTests',
    env = '//bluesim_debug',
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
        '//hdl/ip/bsv/ignition:Protocol',
        '//hdl/ip/bsv/ignition:Transceiver',
        '//hdl/ip/bsv:TestUtils',
    ],
    local = {
        #'bsc_flags': [
        #    '-show-schedule',
        #],
    })

bluesim_tests('IntegrationTests',
    env = '//bluesim_default',
    suite = 'IntegrationTests.bsv',
    modules = [
        'mkControllerAlwaysTransmitOverrideTest',
        'mkControllerTargetPresentTest',
        'mkNoLockedTimeoutIfReceiversLockedTest',
        'mkReceiversLockedTimeoutTest',
        'mkTargetLinkErrorEventsTest',
        'mkTargetRoTFaultTest',
        'mkTargetSystemPowerResetTest',
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
#         '//hdl/ip/bsv/ignition:Transceiver',
#         '//hdl/projects/ecp5_evn:Board',
#     ])

# yosys_design('transceiver_loopback_ecp5_evn_test_top',
#     top_module = 'mkTransceiverLoopbackEcp5EvnTestTop',
#     sources = [
#         ':TransceiverEcp5EvnTests#mkTransceiverLoopbackEcp5EvnTestTop',
#         '//vnd/bluespec:Verilog.v#Verilog.v',
#         '../../../vnd/cobalt/hdl/InitialReset.v',
#     ],
#     deps = [
#         ':TransceiverEcp5EvnTests',
#         '//vnd/bluespec:Verilog.v',
#     ])

# nextpnr_ecp5_bitstream('transceiver_loopback_ecp5_evn_test',
#     env = '//ecp5_evn_test',
#     design = ':transceiver_loopback_ecp5_evn_test_top#transceiver_loopback_ecp5_evn_test_top.json',
#     deps = [
#         ':transceiver_loopback_ecp5_evn_test_top',
#     ])

# bluesim_tests('IgnitionletTransceiverLoopbackTest',
#     env = '//bluesim_default',
#     suite = 'IgnitionletTransceiverLoopbackTest.bsv',
#     modules = [
#         'mkIgnitionletTransceiverLoopbackTest',
#     ],
#     deps = [
#         ':TestHelpers',
#         '//hdl/ip/bsv/ignition:Transceiver',
#         '//hdl/projects/ignitionlet:Board',
#     ])

# bluespec_verilog('IgnitionletTransceiverLoopbackTest_verilog',
#     top = 'IgnitionletTransceiverLoopbackTest.bsv',
#     modules = [
#         'mkIgnitionletTransceiverLoopbackTestTop',
#     ],
#     deps = [
#         ':TestHelpers',
#         '//hdl/ip/bsv/ignition:Transceiver',
#         '//hdl/projects/ignitionlet:Board',
#     ])

# yosys_design('ignitionlet_transceiver_loopback_test_top',
#     top_module = 'mkIgnitionletTransceiverLoopbackTestTop',
#     sources = [
#         ':IgnitionletTransceiverLoopbackTest_verilog#mkIgnitionletTransceiverLoopbackTestTop',
#         '//vnd/bluespec:Verilog.v#Verilog.v',
#         '../../../vnd/cobalt/hdl/InitialReset.v',
#     ],
#     deps = [
#         ':IgnitionletTransceiverLoopbackTest_verilog',
#         '//vnd/bluespec:Verilog.v',
#     ])

# nextpnr_ice40_bitstream('igntionlet_transceiver_loopback_test',
#     env = '//ignitionlet_sequencer',
#     design = ':ignitionlet_transceiver_loopback_test_top#ignitionlet_transceiver_loopback_test_top.json',
#     deps = [
#         ':ignitionlet_transceiver_loopback_test_top',
#     ])
