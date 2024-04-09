package SidecarMainboardController;

export Parameters(..);
export Pins(..);
export Registers(..);
export Status(..);
export MainboardController(..);
export mkMainboardController;

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

import IgnitionController::*;
import IgnitionProtocol::*;
import IgnitionTransceiver::*;
import PCIeEndpointController::*;
import PowerRail::*;
import SidecarMainboardControllerReg::*;
import SidecarMainboardMiscSequencers::*;
import Tofino2Sequencer::*;
import TofinoDebugPort::*;


typedef struct {
    Integer system_frequency_hz;
    Integer system_period_ns;
    Integer clock_generator_power_good_timeout;
    Integer vsc7448_power_good_timeout;
    Integer front_io_power_good_timeout;
    Bit#(7) tofino_i2c_address;
    Integer tofino_i2c_frequency_hz;
    Integer tofino_i2c_stretch_timeout_us;
    Tofino2Sequencer::Parameters tofino_sequencer;
} Parameters;

instance DefaultValue#(Parameters);
    defaultValue =
        Parameters {
            system_frequency_hz: 50_000_000,
            system_period_ns: 20,
            clock_generator_power_good_timeout: 10,
            vsc7448_power_good_timeout: 10,
            // The EN->PG time of the front IO hot swap controller was
            // experimentally determined to be 35 ms. A timeout value of 75 ms
            // was chosen to have _a_ timeout but because there are no safety
            // implications if the HSC does not start ample margin is provided.
            front_io_power_good_timeout: 75,
            tofino_i2c_address: 7'b1011_011, // 5Bh
            tofino_i2c_frequency_hz: 100_000,
            // The Tofino has not been observed to clock stretch, but we need a
            // value to give the I2CCore connected to the debug port. Choosing
            // 1 ms arbitrarily.
            tofino_i2c_stretch_timeout_us: 1000,
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
    interface PCIeEndpointController::Pins pcie;
    interface Tofino2Sequencer::Pins tofino;
    interface I2CCommon::Pins tofino_debug_port;
    interface PowerRail::Pins front_io_hsc;
    interface VSC7448Pins vsc7448;
    interface Vector#(4, FanModulePins) fans;
endinterface

interface Registers;
    interface PCIeEndpointController::Registers pcie;
    interface Tofino2Sequencer::Registers tofino;
    interface TofinoDebugPort::Registers tofino_debug_port;
    interface Reg#(PowerRailState) front_io_hsc;
    interface Vector#(4, FanModuleRegisters) fans;
endinterface

interface MainboardController #(numeric type n_ignition_controllers);
    interface Pins pins;
    interface Registers registers;
    interface Controller#(n_ignition_controllers) ignition_controller;
    interface ReadOnly#(Status) status;
endinterface

module mkMainboardController #(Parameters parameters)
        (MainboardController#(n_ignition_controllers));
    //
    // Timing
    //

    let limit_1mhz = fromInteger(parameters.system_frequency_hz / 1_000_000);
    let limit_1khz = fromInteger(1_000_000 / 1000);
    let limit_2hz = fromInteger(1000 / 2);

    Strobe#(6) tick_1mhz <- mkLimitStrobe(1, limit_1mhz, 0);
    Strobe#(10) tick_1khz <- mkLimitStrobe(1, limit_1khz, 0);
    Strobe#(9) tick_2hz <- mkLimitStrobe(1, limit_2hz, 0);

    mkFreeRunningStrobe(tick_1mhz);
    mkConnection(asIfc(tick_1mhz), asIfc(tick_1khz));
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
    PCIeEndpointController pcie_endpoint <-
        mkPCIeEndpointController(tofino_sequencer);

    mkConnection(asIfc(tick_1khz), asIfc(tofino_sequencer.tick_1ms));
    mkConnection(asIfc(tick_1mhz), asIfc(pcie_endpoint.tick_1us));

    TofinoDebugPort tofino_debug_port <-
        mkTofinoDebugPort(
            parameters.system_frequency_hz,
            parameters.system_period_ns,
            parameters.tofino_i2c_frequency_hz,
            parameters.tofino_i2c_address,
            parameters.tofino_i2c_stretch_timeout_us);

    //
    // VSC7748 sequencer
    //

    VSC7448Sequencer vsc7448_sequencer <-
        mkVSC7448Sequencer(parameters.vsc7448_power_good_timeout);

    mkConnection(asIfc(tick_1khz), asIfc(vsc7448_sequencer.tick_1ms));

    //
    // Front IO Hot Swap Controller
    //
    PowerRail#(7) front_io_hsc <-
        mkPowerRailDisableOnAbort(parameters.front_io_power_good_timeout);

    mkConnection(tick_1khz, front_io_hsc);

    //
    // Fans
    //

    Vector#(4, FanModuleSequencer) fans <- replicateM(mkFanModuleSequencer());

    for (int i = 0; i < 4; i = i + 1) begin
        mkConnection(asIfc(tick_1khz), asIfc(fans[i].tick_1ms));
    end

    //
    // Ignition Controllers
    //

    IgnitionController::Controller#(n_ignition_controllers)
            ignition <- mkController(defaultValue, False);

    (* fire_when_enabled *)
    rule do_ignition_controller_tick_1mhz (tick_1mhz);
        ignition.tick_1mhz();
    endrule

    //
    // Debug status
    //

    Reg#(Status) status_r <- mkConfigRegU();

    (* fire_when_enabled *)
    rule do_set_status;
        status_r <= Status {
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
        interface front_io_hsc = front_io_hsc.pins;
        interface VSC7448Pins vsc7448 = vsc7448_sequencer.pins;
        interface PCIeEndpointController::Pins pcie = pcie_endpoint.pins;
        interface fans = map(SidecarMainboardMiscSequencers::fan_pins, fans);
    endinterface

    interface Registers registers;
        interface PCIeEndpointController::Registers pcie = pcie_endpoint.registers;
        interface Tofino2Sequencer::Registers tofino = tofino_sequencer.registers;
        interface TofinoDebugPort::Registers tofino_debug_port = tofino_debug_port.registers;
        interface front_io_hsc = powerRailToReg(front_io_hsc);
        interface fans = map(SidecarMainboardMiscSequencers::fan_registers, fans);
    endinterface

    interface Controller ignition_controller = ignition;

    interface ReadOnly status = regToReadOnly(status_r);
endmodule

endpackage
