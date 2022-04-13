package SidecarMainboardEmulator;

import Clocks::*;
import Connectable::*;

import ECP5::*;
import Strobe::*;

import PowerRail::*;
import SpiDecode::*;
import SidecarMainboardController::*;
import Tofino2Sequencer::*;


(* always_enabled *)
interface SidecarMainboardEmulator;
    (* prefix = "" *) method Action csn(Bit#(1) spi_csn);
    (* prefix = "" *) method Action sclk(Bit#(1) spi_sclk);
    (* prefix = "" *) method Action copi(Bit#(1) spi_copi);
    method Bit#(1) spi_cipo;
    method Bit#(8) led();
endinterface

(* synthesize,
    default_clock_osc = "clk_12mhz",
    default_reset = "design_reset_l" *)
module mkSidecarMainboardEmulatorOnEcp5Evn (SidecarMainboardEmulator);
    // Synchronize the default reset to the default clock.
    Clock clk_12mhz <- exposeCurrentClock();
    Reset reset_sync <- mkAsyncResetFromCR(2, clk_12mhz);

    let pll_parameters = ECP5PLLParameters {
        clki_frequency: 12.0,
        clki_divide: 3,
        // Primary output clock parameters.
        clkop_enable: True,
        clkop_frequency: 100.0,
        clkop_divide: 6,
        clkop_coarse_phase_adjust: 0,
        clkop_fine_phase_adjust: 0,
        // Secondary output clock parameters.
        clkos_enable: True,
        clkos_frequency: 50.0,
        clkos_divide: 12,
        clkos_coarse_phase_adjust: 0,
        clkos_fine_phase_adjust: 0,
        // Secondary output clock 2 parameters.
        clkos2_enable: False,
        clkos2_frequency: 0.0,
        clkos2_divide: 0,
        clkos2_coarse_phase_adjust: 0,
        clkos2_fine_phase_adjust: 0,
        // Secondary output clock 3 parameters.
        clkos3_enable: False,
        clkos3_frequency: 0.0,
        clkos3_divide: 0,
        clkos3_coarse_phase_adjust: 0,
        clkos3_fine_phase_adjust: 0,
        // Feedback parameters.
        feedback_path: "CLKOP",
        feedback_divide: 25};

    ECP5PLL pll <- mkECP5PLL(pll_parameters, clk_12mhz, reset_sync);
    Clock clk_50mhz = pll.clkos;

    Parameters parameters = defaultValue;
    MainboardController controller <-
        mkMainboardController(parameters, clocked_by clk_50mhz);

    //
    // SPI peripheral.
    //

    SyncBitIfc#(Bit#(1)) spi_csn_sync <- mkSyncBit(clk_50mhz, noReset, clk_50mhz);
    SyncBitIfc#(Bit#(1)) spi_sclk_sync <- mkSyncBit(clk_50mhz, noReset, clk_50mhz);
    SyncBitIfc#(Bit#(1)) spi_copi_sync <- mkSyncBit(clk_50mhz, noReset, clk_50mhz);
    ReadOnly#(Bit#(1)) spi_cipo_sync <- mkNullCrossingWire(clk_12mhz, controller.spi_pins.cipo);

    mkConnection(spi_csn_sync.read, controller.spi_pins.csn);
    mkConnection(spi_sclk_sync.read, controller.spi_pins.sclk);
    mkConnection(spi_copi_sync.read, controller.spi_pins.copi);

    //
    // Timing
    //

    let limit_for_1khz = fromInteger(parameters.system_frequency_hz / 1000);

    Strobe#(20) tick_1khz <- mkLimitStrobe(1, limit_for_1khz, 0, clocked_by clk_50mhz);
    mkFreeRunningStrobe(tick_1khz);

    //
    // PDN
    //

    function mkDefaultPowerRailModel(name) =
        mkPowerRailModel(name, tick_1khz, 1, clocked_by clk_50mhz);

    PowerRailModel#(16) vdd18 <- mkDefaultPowerRailModel("VDD18");
    PowerRailModel#(16) vddcore <- mkDefaultPowerRailModel("VDDCORE");
    PowerRailModel#(16) vddpcie <- mkDefaultPowerRailModel("VDDPCIe");
    PowerRailModel#(16) vddt <- mkDefaultPowerRailModel("VDDt");
    PowerRailModel#(16) vdda15 <- mkDefaultPowerRailModel("VDDA15");
    PowerRailModel#(16) vdda18 <- mkDefaultPowerRailModel("VDDA18");

    mkConnection(vdd18.pins, controller.tofino_sequencer_pins.vdd18);
    mkConnection(vddcore.pins, controller.tofino_sequencer_pins.vddcore);
    mkConnection(vddpcie.pins, controller.tofino_sequencer_pins.vddpcie);
    mkConnection(vddt.pins, controller.tofino_sequencer_pins.vddt);
    mkConnection(vdda15.pins, controller.tofino_sequencer_pins.vdda15);
    mkConnection(vdda18.pins, controller.tofino_sequencer_pins.vdda18);

    //
    // Tofino bits.
    //

    Reg#(Bit#(3)) vid <- mkReg('b110);

    mkConnection(vid._read, controller.tofino_sequencer_pins.vid);

    method csn = spi_csn_sync.send;
    method sclk = spi_sclk_sync.send;
    method copi = spi_copi_sync.send;
    method spi_cipo = spi_cipo_sync;

    method led = ~{extend(pack(controller.status))};
endmodule

endpackage
