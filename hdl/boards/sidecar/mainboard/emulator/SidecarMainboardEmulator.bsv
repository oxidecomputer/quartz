package SidecarMainboardEmulator;

import Clocks::*;
import Connectable::*;

import ECP5::*;
import SPI::*;
import Strobe::*;

import IOSync::*;
import PowerRail::*;
import SidecarMainboardController::*;
import Tofino2Sequencer::*;


(* always_enabled *)
interface SidecarMainboardEmulator;
    (* prefix = "" *) method Action spi_csn(Bit#(1) spi_csn);
    (* prefix = "" *) method Action spi_sclk(Bit#(1) spi_sclk);
    (* prefix = "" *) method Action spi_copi(Bit#(1) spi_copi);
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
    (* hide *) SidecarMainboardEmulator _emulator <-
        mkSidecarMainboardEmulatorOnEcp5EvnWrapper(
            clocked_by pll.clkos, // 50 MHz
            reset_by reset_sync);

    return _emulator;
endmodule

module mkSidecarMainboardEmulatorOnEcp5EvnWrapper (SidecarMainboardEmulator);
    Parameters parameters = defaultValue;
    MainboardController controller <- mkMainboardController(parameters);

    //
    // SPI peripheral.
    //

    Reg#(Bit#(1)) csn <- mkInputSyncFor(controller.spi.csn);
    Reg#(Bit#(1)) sclk <- mkInputSyncFor(controller.spi.sclk);
    Reg#(Bit#(1)) copi <- mkInputSyncFor(controller.spi.copi);
    ReadOnly#(Bit#(1)) cipo <- mkOutputSyncFor(controller.spi.cipo);

    //
    // Timing
    //

    let limit_for_1khz = fromInteger(parameters.system_frequency_hz / 1000);

    Strobe#(20) tick_1khz <- mkLimitStrobe(1, limit_for_1khz, 0);
    mkFreeRunningStrobe(tick_1khz);

    //
    // PDN
    //

    function mkDefaultPowerRailModel(name) =
        mkPowerRailModel(name, tick_1khz, 1);

    PowerRailModel#(16) vdd18 <- mkDefaultPowerRailModel("VDD18");
    PowerRailModel#(16) vddcore <- mkDefaultPowerRailModel("VDDCORE");
    PowerRailModel#(16) vddpcie <- mkDefaultPowerRailModel("VDDPCIe");
    PowerRailModel#(16) vddt <- mkDefaultPowerRailModel("VDDt");
    PowerRailModel#(16) vdda15 <- mkDefaultPowerRailModel("VDDA15");
    PowerRailModel#(16) vdda18 <- mkDefaultPowerRailModel("VDDA18");

    mkConnection(vdd18.pins, controller.tofino.vdd18);
    mkConnection(vddcore.pins, controller.tofino.vddcore);
    mkConnection(vddpcie.pins, controller.tofino.vddpcie);
    mkConnection(vddt.pins, controller.tofino.vddt);
    mkConnection(vdda15.pins, controller.tofino.vdda15);
    mkConnection(vdda18.pins, controller.tofino.vdda18);

    //
    // Tofino bits.
    //

    Reg#(Bit#(3)) vid <- mkReg('b110);

    mkConnection(vid._read, controller.tofino.vid);

    method spi_csn = sync(csn);
    method spi_sclk = sync(sclk);
    method spi_copi = sync(copi);
    method spi_cipo = cipo;

    method led = ~{extend(pack(controller.status))};
endmodule

endpackage
