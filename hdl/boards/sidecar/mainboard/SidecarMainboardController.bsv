package SidecarMainboardController;

export Parameters(..);
export Pins(..);
export Registers(..);
export Status(..);
export MainboardController(..);
export mkMainboardController;

import ClientServer::*;
import ConfigReg::*;
import Connectable::*;
import DefaultValue::*;
import GetPut::*;
import Vector::*;

import SPI::*;
import Strobe::*;

import FanModule::*;
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
    Bool pcie_present;
    Bool tofino_in_a0;
    Bool tofino_sequencer_running;
    Bit#(1) clk_1hz;
} Status deriving (Bits, Eq, FShow);

interface Pins;
    interface ClockGeneratorPins clocks;
    interface Tofino2Sequencer::Pins tofino;
    interface I2CCommon::Pins tofino_debug_port;
    interface PCIeEndpointController::Pins pcie;
    interface VSC7448Pins vsc7448;
    interface Vector#(4, FanModule::Pins) fans;
endinterface

interface Registers;
    interface Tofino2Sequencer::Registers tofino;
    interface TofinoDebugPort::Registers tofino_debug_port;
    interface PCIeEndpointController::Registers pcie;
endinterface

interface MainboardController;
    interface Pins pins;
    interface Registers registers;
    interface ReadOnly#(Status) status;
endinterface

module mkMainboardController #(Parameters parameters) (MainboardController);
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
            pcie_present: pcie_endpoint.pins.present};
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
        interface Tofino2Sequencer::Registers tofino = tofino_sequencer.registers;
        interface TofinoDebugPort::Registers tofino_debug_port = tofino_debug_port.registers;
        interface PCIeEndpointController::Registers pcie = pcie_endpoint.registers;
    endinterface

    interface ReadOnly status = regToReadOnly(status_r);
endmodule

endpackage
