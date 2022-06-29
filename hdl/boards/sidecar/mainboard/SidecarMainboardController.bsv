package SidecarMainboardController;

export Parameters(..);
export Status(..);
export MainboardController(..), mkMainboardController;

import ClientServer::*;
import ConfigReg::*;
import Connectable::*;
import DefaultValue::*;
import GetPut::*;
import Vector::*;

import SPI::*;
import Strobe::*;

import FanModule::*;
import SidecarMainboardControllerReg::*;
import SidecarMainboardControllerSpiServer::*;
import SidecarMainboardMiscSequencers::*;
import Tofino2Sequencer::*;


typedef struct {
    Integer system_frequency_hz;
    Integer clock_generator_power_good_timeout;
    Integer vsc7448_power_good_timeout;
    Tofino2Sequencer::Parameters tofino_sequencer;
} Parameters;

instance DefaultValue#(Parameters);
    defaultValue =
        Parameters {
            system_frequency_hz: 50_000_000,
            clock_generator_power_good_timeout: 10,
            vsc7448_power_good_timeout: 10,
            tofino_sequencer: defaultValue};
endinstance

typedef struct {
    Bool tofino_in_a0;
    Bool tofino_sequencer_running;
    Bit#(1) clk_1hz;
} Status deriving (Bits, Eq, FShow);

interface MainboardController;
    interface SpiPeripheralPins spi;
    interface ClockGeneratorPins clocks;
    interface Tofino2Sequencer::Pins tofino;
    interface VSC7448Pins vsc7448;
    interface Vector#(4, FanModule::Pins) fan;
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
        mkClockGeneratorSequencer(parameters.clock_generator_power_good_timeout);

    mkConnection(asIfc(tick_1khz), asIfc(clock_generator_sequencer.tick_1ms));

    //
    // Tofino 2 sequencer
    //

    Tofino2Sequencer tofino_sequencer <-
        mkTofino2Sequencer(parameters.tofino_sequencer);

    mkConnection(asIfc(tick_1khz), asIfc(tofino_sequencer.tick_1ms));

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
    // SPI peripheral
    //

    SpiPeripheralPhy spi_phy <- mkSpiPeripheralPhy();
    SpiDecodeIF spi_decoder <- mkSpiRegDecode();
    SpiServer spi_server <- mkSpiServer(tofino_sequencer);

    mkConnection(spi_phy.decoder_if, spi_decoder.spi_byte);
    mkConnection(spi_decoder.reg_con, spi_server);

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
            tofino_in_a0: tofino_sequencer.registers.state.state == 2};
    endrule

    //
    // Interfaces
    //

    interface SpiPeripheralPins spi = spi_phy.pins;
    interface ClockGeneratorPins clocks = clock_generator_sequencer.pins;
    interface Tofino2Sequencer::Pins tofino = tofino_sequencer.pins;
    interface VSC7448Pins vsc7448 = vsc7448_sequencer.pins;
    interface fan = map(FanModule::pins, fans);
    interface ReadOnly status = regToReadOnly(status_r);
endmodule

endpackage
