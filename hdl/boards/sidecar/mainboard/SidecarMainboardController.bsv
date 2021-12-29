package SidecarMainboardController;

export Parameters(..);
export Pins(..);
export Registers(..);
export Status(..);
export MainboardController(..);
export mkMainboardController;

export IgnitionRegisterPages(..);
export IgnitionTransceiverClients(..);

import DReg::*;
import ClientServer::*;
import ConfigReg::*;
import Connectable::*;
import DefaultValue::*;
import GetPut::*;
import Vector::*;

import SerialIO::*;
import SPI::*;
import Strobe::*;

import FanModule::*;
import IgnitionController::*;
import IgnitionProtocol::*;
import IgnitionTransceiver::*;
import PCIeEndpointController::*;
import SidecarMainboardControllerReg::*;
import SidecarMainboardMiscSequencers::*;
import Tofino2Sequencer::*;
import TofinoDebugPort::*;


typedef struct {
    Integer system_frequency_hz;
    Integer clock_generator_power_good_timeout;
    Integer vsc7448_power_good_timeout;
    Bit#(7) tofino_i2c_address;
    Integer tofino_i2c_frequency_hz;
    Tofino2Sequencer::Parameters tofino_sequencer;
} Parameters;

instance DefaultValue#(Parameters);
    defaultValue =
        Parameters {
            system_frequency_hz: 50_000_000,
            clock_generator_power_good_timeout: 10,
            vsc7448_power_good_timeout: 10,
            tofino_i2c_address: 7'b1011_011, // 5Bh
            tofino_i2c_frequency_hz: 100_000,
            tofino_sequencer: defaultValue};
endinstance

typedef struct {
    Bool ext_ignition_target_present;
    Bool ext_ignition_receiver_locked;
    Bool pcie_present;
    Bool tofino_in_a0;
    Bool tofino_sequencer_running;
    Bit#(1) clk_1hz;
} Status deriving (Bits, Eq, FShow);

typedef Vector#(n, IgnitionController::Registers) IgnitionRegisterPages#(numeric type n);
typedef Vector#(n, IgnitionTransceiver::TransceiverClient) IgnitionTransceiverClients#(numeric type n);

interface Pins #(numeric type n_ignition_controllers);
    interface ClockGeneratorPins clocks;
    interface PCIeEndpointController::Pins pcie;
    interface Tofino2Sequencer::Pins tofino;
    interface I2CCommon::Pins tofino_debug_port;
    interface Vector#(4, FanModule::Pins) fans;
    interface VSC7448Pins vsc7448;
endinterface

interface Registers #(numeric type n_ignition_controllers);
    interface IgnitionRegisterPages#(n_ignition_controllers) ignition_pages;
    interface PCIeEndpointController::Registers pcie;
    interface Tofino2Sequencer::Registers tofino;
    interface TofinoDebugPort::Registers tofino_debug_port;
endinterface

interface MainboardController #(numeric type n_ignition_controllers);
    interface Pins#(n_ignition_controllers) pins;
    interface Registers#(n_ignition_controllers) registers;
    interface IgnitionTransceiverClients#(n_ignition_controllers) ignition_txrs;
    interface ReadOnly#(Status) status;
endinterface

module mkMainboardController #(Parameters parameters)
        (MainboardController#(n_ignition_controllers))
            provisos (
                Add#(TLog#(TAdd#(n_ignition_controllers, 1)), a__, 8));
    //
    // Timing
    //

    Strobe#(20) tick_1khz <-
        mkLimitStrobe(1, (parameters.system_frequency_hz / 1000), 0);
    Strobe#(10) tick_2hz <- mkLimitStrobe(1, 500, 0);

    mkFreeRunningStrobe(tick_1khz);
    mkConnection(asIfc(tick_1khz), asIfc(tick_2hz));

    //
    // Clock Generator sequencer
    //

    ClockGeneratorSequencer clock_generator_sequencer <-
        mkClockGeneratorSequencer(
            parameters.clock_generator_power_good_timeout);

    mkConnection(asIfc(tick_1khz), asIfc(clock_generator_sequencer.tick_1ms));

    //
    // Tofino 2
    //

    Tofino2Sequencer tofino_sequencer <-
        mkTofino2Sequencer(parameters.tofino_sequencer);
    PCIeEndpointController pcie_endpoint <- mkPCIeEndpointController();

    mkConnection(asIfc(tick_1khz), asIfc(tofino_sequencer.tick_1ms));

    // Control the Tofino 2 reset pin based on the state of the PCIe Endpoint
    // Controller.
    (* fire_when_enabled *)
    rule do_tofino_pcie_reset (pcie_endpoint.reset_peripheral);
        tofino_sequencer.pcie_reset();
    endrule

    TofinoDebugPort tofino_debug_port <-
        mkTofinoDebugPort(
            parameters.system_frequency_hz,
            parameters.tofino_i2c_frequency_hz,
            parameters.tofino_i2c_address);

    //
    // VSC7748 sequencer
    //

    VSC7448Sequencer vsc7448_sequencer <-
        mkVSC7448Sequencer(parameters.vsc7448_power_good_timeout);

    mkConnection(asIfc(tick_1khz), asIfc(vsc7448_sequencer.tick_1ms));

    //
    // Fans
    //

    Vector#(4, FanModule) fans <- replicateM(mkFanModule());

    //
    // Ignition Controllers
    //

    Vector#(n_ignition_controllers, IgnitionController::Controller)
        ignition_controllers <- replicateM(mkController(defaultValue));

    // Connect each Controller to the global tick.
    function mk_tick_connection(controller) =
        mkConnection(asIfc(tick_1khz), asIfc(controller.tick_1khz));

    mapM(mk_tick_connection, ignition_controllers);

    // Collect the register pages for all controllers.
    let ignition_pages = map(registers, ignition_controllers);
    // Collect the transceiver clients for all controllers.
    let ignition_txr_clients = map(transceiver_client, ignition_controllers);

    //
    // Debug status
    //

    Reg#(Status) status_r <- mkConfigRegU();

    (* fire_when_enabled *)
    rule do_set_status;
        status_r <= Status{
            clk_1hz: (tick_2hz ? ~status_r.clk_1hz : status_r.clk_1hz),
            tofino_sequencer_running:
                tofino_sequencer.registers.state.state != 0,
            tofino_in_a0: tofino_sequencer.registers.state.state == 2,
            pcie_present: pcie_endpoint.pins.present,
            ext_ignition_receiver_locked: False,
            ext_ignition_target_present:
                ignition_controllers[2].debug.target_present};
    endrule

    //
    // Interfaces
    //

    interface Pins pins;
        interface ClockGeneratorPins clocks = clock_generator_sequencer.pins;
        interface Tofino2Sequencer::Pins tofino = tofino_sequencer.pins;
        interface TofinoDebugPort::Pins tofino_debug_port = tofino_debug_port.pins;
        interface VSC7448Pins vsc7448 = vsc7448_sequencer.pins;
        interface PCIeEndpointController::Pins pcie = pcie_endpoint.pins;
        interface fans = map(FanModule::pins, fans);
    endinterface

    interface Registers registers;
        interface IgnitionRegisterPages ignition_pages = ignition_pages;
        interface PCIeEndpointController::Registers pcie = pcie_endpoint.registers;
        interface Tofino2Sequencer::Registers tofino = tofino_sequencer.registers;
        interface TofinoDebugPort::Registers tofino_debug_port = tofino_debug_port.registers;
    endinterface

    interface IgnitionTransceiverClients ignition_txrs = ignition_txr_clients;
    interface ReadOnly status = regToReadOnly(status_r);
endmodule

endpackage
