package SidecarMainboardControllerSpiServerTests;

import ClientServer::*;
import GetPut::*;
import StmtFSM::*;
import Vector::*;

import RegCommon::*;
import TestUtils::*;

import IgnitionController::*;
import IgnitionProtocol::*;
import IgnitionReceiver::*;
import IgnitionTestHelpers::*;
import IgnitionTransceiver::*;
import PCIeEndpointController::*;
import PowerRail::*;
import SidecarMainboardController::*;
import SidecarMainboardControllerReg::*;
import SidecarMainboardControllerSpiServer::*;
import SidecarMainboardMiscSequencers::*;
import Tofino2Sequencer::*;
import TofinoDebugPort::*;

module mkReadIdTest (Empty);
    match {.spi, .*} <- mkSpiServerBench();

    mkAutoFSM(seq
        assert_read_of_eq(spi, 'h0000, Id0'(defaultValue), "expected Id0");
        assert_read_of_eq(spi, 'h0001, Id1'(defaultValue), "expected Id1");
        assert_read_of_eq(spi, 'h0002, Id2'(defaultValue), "expected Id2");
        assert_read_of_eq(spi, 'h0003, Id3'(defaultValue), "expected Id3");
    endseq);

    mkTestWatchdog(50);
endmodule

module mkReadIgnitionPortCountTest (Empty);
    match {.spi, .*} <- mkSpiServerBench();

    mkAutoFSM(seq
        assert_read_of_eq(spi, 'h0300, 8'h2, "expected a port count of 2");
    endseq);

    mkTestWatchdog(50);
endmodule

module mkReadIgnitionPresenceSummaryTest (Empty);
    match {.spi, .ignition} <- mkSpiServerBench();

    mkAutoFSM(seq
        // Read the presence vector, asserting that none of the present bits are
        // set.
        await(ignition.idle);
        assert_read_of_eq(spi, 'h0301, 8'h0, "expected no Target present");
        assert_read_of_eq(spi, 'h0302, 8'h0, "expected no Target present");
        assert_read_of_eq(spi, 'h0303, 8'h0, "expected no Target present");
        assert_read_of_eq(spi, 'h0304, 8'h0, "expected no Target present");
        assert_read_of_eq(spi, 'h0305, 8'h0, "expected no Target present");

        controller_receive_status_message(
                ignition, 0,
                message_status_system_powered_on_link0_connected);

        await(ignition.idle);
        assert_read_of_eq(spi, 'h0301, 8'h1, "expected Target 0 present");
        assert_read_of_eq(spi, 'h0302, 8'h0, "expected no Target present");
        assert_read_of_eq(spi, 'h0303, 8'h0, "expected no Target present");
        assert_read_of_eq(spi, 'h0304, 8'h0, "expected no Target present");
        assert_read_of_eq(spi, 'h0305, 8'h0, "expected no Target present");
    endseq);

    mkTestWatchdog(200);
endmodule

module mkReadIgnitionTransceiverStateTest (Empty);
    match {.spi, .ignition} <- mkSpiServerBench();

    mkAutoFSM(seq
        await(ignition.idle); // Complete init.
        assert_read_of_eq(spi,
                'h4000, link_status_none,
                "expected receiver not aligned or locked");

        ignition.txr.rx.put(ReceiverEvent {
                id: 0,
                ev: tagged ReceiverStatusChange link_status_aligned});

        await(ignition.idle);
        assert_read_of_eq(spi,
                'h4000, link_status_aligned,
                "expected receiver aligned");

        ignition.txr.rx.put(ReceiverEvent {
                id: 0,
                ev: tagged ReceiverStatusChange link_status_locked});

        await(ignition.idle);
        assert_read_of_eq(spi,
                'h4000, link_status_locked,
                "expected receiver locked");

        ignition.txr.rx.put(ReceiverEvent {
                id: 0,
                ev: tagged ReceiverStatusChange link_status_polarity_inverted});

        await(ignition.idle);
        assert_read_of_eq(spi,
                'h4000, link_status_polarity_inverted,
                "expected receiver polarity inverted");

        ignition.txr.rx.put(ReceiverEvent {
                id: 0,
                ev: tagged ReceiverReset});

        await(ignition.idle);
        assert_read_of_eq(spi,
                'h4000, link_status_none,
                "expected receiver not aligned or locked");
    endseq);

    mkTestWatchdog(200);
endmodule

module mkReadIgnitionTargetStatusTest (Empty);
    match {.spi, .ignition} <- mkSpiServerBench();

    mkAutoFSM(seq
        await(ignition.idle); // Complete init.

        controller_receive_status_message(
                ignition, 0,
                message_status_system_powered_on_link0_connected);
        await(ignition.idle);

        assert_read_of_eq(spi,
                'h4001, True,
                "expected Target present");
        assert_read_of_eq(spi,
                'h4002, target_system_type,
                "expected Target system type");
        assert_read_of_eq(spi,
                'h4003, system_status_system_power_enabled,
                "expected Target system status power enabled");
        assert_read_of_eq(spi,
                'h4004, system_faults_none,
                "expected no Target system faults");
        assert_read_of_eq(spi,
                'h4005, request_status_none,
                "expected no Target system power requests in progress");
        assert_read_of_eq(spi,
                'h4006, link_status_connected,
                "expected Target link 0 connected");
        assert_read_of_eq(spi,
                'h4007, link_status_disconnected,
                "expected Target link 1 disconnected");
    endseq);

    mkTestWatchdog(200);
endmodule

module mkReadIgnitionCounterTest (Empty);
    match {.spi, .ignition} <- mkSpiServerBench();

    function assert_counter_eq(address, expected_value, msg) =
            assert_read_of_eq(spi, address, Counter'(expected_value), msg);

    mkAutoFSM(seq
        await(ignition.idle);
        // Clear counters because the counter RAM is not explicitly initialized.
        read_and_discard(spi, 'h4080);
        read_and_discard(spi, 'h4082);

        controller_receive_status_message(
                ignition, 0,
                message_status_system_powered_on_link0_connected);
        await(ignition.idle);

        assert_counter_eq('h4080, 1, "expected Target present count 1");
        assert_counter_eq('h4080, 0, "expected Target present cleared");
        assert_counter_eq('h4082, 1, "expected Status received count 1");
    endseq);

    mkTestWatchdog(200);
endmodule

module mkSpiServerBench
        (Tuple2#(SpiServer, IgnitionController::Controller#(2)));
    let parameters = SidecarMainboardController::Parameters'(defaultValue);

    Tofino2Sequencer tofino_sequencer <- mkTofino2Sequencer(defaultValue);
    TofinoDebugPort tofino_debug_port <- mkTofinoDebugPort(
            parameters.system_frequency_hz,
            parameters.system_period_ns,
            parameters.tofino_i2c_frequency_hz,
            parameters.tofino_i2c_address,
            parameters.tofino_i2c_stretch_timeout_us);
    PCIeEndpointController pcie_endpoint <-
            mkPCIeEndpointController(tofino_sequencer);
    IgnitionController::Controller#(2) ignition <-
            IgnitionController::mkController(defaultValue, True);
    Vector#(4, FanModuleSequencer) fans <- replicateM(mkFanModuleSequencer);
    PowerRail#(7) front_io_hsc <-
            mkPowerRailDisableOnAbort(parameters.front_io_power_good_timeout);

    (* fire_when_enabled *)
    rule do_tick_ignition;
        ignition.tick_1mhz();
    endrule

    SpiServer spi <- mkSpiServer(
            tofino_sequencer.registers,
            tofino_debug_port.registers,
            pcie_endpoint.registers,
            ignition,
            map(SidecarMainboardMiscSequencers::fan_registers, fans),
            powerRailToReg(front_io_hsc));

    return tuple2(spi, ignition);
endmodule

function SpiResponse as_response(t data)
        provisos (Bits#(t, t_sz), Add#(t_sz, _, 8));
    return unpack(extend(pack(data)));
endfunction

function Stmt read_and_discard(SpiServer spi, Bit#(16) address);
    return seq
        spi.request.put(SpiRequest {op: READ, address: address, wdata: ?});
        assert_get_any(spi.response);
    endseq;
endfunction

function Stmt assert_read_of_eq(
        SpiServer spi,
        Bit#(16) address,
        t expected_response,
        String msg)
            provisos (
                Bits#(t, t_sz),
                Add#(t_sz, a__, 8));
    return seq
        spi.request.put(SpiRequest {op: READ, address: address, wdata: ?});
        assert_get_bits_eq(spi.response, as_response(expected_response), msg);
    endseq;
endfunction

endpackage
