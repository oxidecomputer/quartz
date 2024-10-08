package SidecarMainboardEmulator;

import BuildVector::*;
import Clocks::*;
import ConfigReg::*;
import Connectable::*;
import GetPut::*;
import TriState::*;
import Vector::*;

import BitSampling::*;
import ECP5::*;
import SerialIO::*;
import SPI::*;
import Strobe::*;

import I2CCommon::*;
import IOSync::*;
import PowerRail::*;
import SidecarMainboardController::*;
import SidecarMainboardControllerSpiServer::*;
import Tofino2Sequencer::*;

import IgnitionController::*;
import IgnitionProtocol::*;
import IgnitionTarget::*;
import IgnitionTransceiver::*;


(* always_enabled *)
interface SidecarMainboardEmulatorTop;
    (* prefix = "" *) method Action spi_csn(Bit#(1) spi_csn);
    (* prefix = "" *) method Action spi_sclk(Bit#(1) spi_sclk);
    (* prefix = "" *) method Action spi_copi(Bit#(1) spi_copi);
    method Bit#(1) spi_cipo;

    method Bit#(8) led();
    method Bit#(1) debug();

    (* prefix = "" *) method Action aux0_rx(Bit#(1) aux0_rx);
    interface Inout#(Bit#(1)) aux0_tx;

    (* prefix = "" *) method Action aux1_rx(Bit#(1) aux1_rx);
    interface Inout#(Bit#(1)) aux1_tx;
endinterface

(* default_clock_osc = "clk_12mhz",
    default_reset = "design_reset_l" *)
module mkSidecarMainboardEmulatorOnEcp5Evn (SidecarMainboardEmulatorTop);
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
    (* hide *) SidecarMainboardEmulatorTop _emulator <-
        mkSidecarMainboardEmulator(
            clocked_by pll.clkos, // 50 MHz
            reset_by reset_sync);

    method spi_csn = _emulator.spi_csn;
    method spi_sclk = _emulator.spi_sclk;
    method spi_copi = _emulator.spi_copi;
    method spi_cipo = _emulator.spi_cipo;

    method led = _emulator.led;
    method debug = _emulator.debug;

    method aux0_rx = _emulator.aux0_rx;
    interface Inout aux0_tx = _emulator.aux0_tx;

    method aux1_rx = _emulator.aux1_rx;
    interface Inout aux1_tx = _emulator.aux1_tx;
endmodule

module mkSidecarMainboardEmulator (SidecarMainboardEmulatorTop)
        provisos (
            NumAlias#(4, n_ignition_controllers));
    Parameters parameters = defaultValue;
    MainboardController#(n_ignition_controllers) controller <-
        mkMainboardController(parameters);

    //
    // SPI peripheral.
    //

    SpiPeripheralPhy spi_phy <- mkSpiPeripheralPhy();
    SpiDecodeIF spi_decoder <- mkSpiRegDecode();
    SpiServer spi_server <-
        mkSpiServer(
            controller.registers.tofino,
            controller.registers.tofino_debug_port,
            controller.registers.pcie,
            IgnitionController::register_pages(controller.ignition_controllers),
            controller.registers.fans,
            controller.registers.front_io_hsc);

    InputReg#(Bit#(1), 2) csn <- mkInputSyncFor(spi_phy.pins.csn);
    InputReg#(Bit#(1), 2) sclk <- mkInputSyncFor(spi_phy.pins.sclk);
    InputReg#(Bit#(1), 2) copi <- mkInputSyncFor(spi_phy.pins.copi);
    ReadOnly#(Bit#(1)) cipo <- mkOutputSyncFor(spi_phy.pins.cipo);

    mkConnection(spi_phy.decoder_if, spi_decoder.spi_byte);
    mkConnection(spi_decoder.reg_con, spi_server);

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

    mkConnection(vdd18.pins, controller.pins.tofino.vdd18);
    mkConnection(vddcore.pins, controller.pins.tofino.vddcore);
    mkConnection(vddpcie.pins, controller.pins.tofino.vddpcie);
    mkConnection(vddt.pins, controller.pins.tofino.vddt);
    mkConnection(vdda15.pins, controller.pins.tofino.vdda15);
    mkConnection(vdda18.pins, controller.pins.tofino.vdda18);

    PowerRailModel#(16) front_io_hsc <- mkDefaultPowerRailModel("FRONT_IO");

    mkConnection(front_io_hsc.pins, controller.pins.front_io_hsc);

    //
    // Tofino bits.
    //

    Reg#(Bit#(3)) vid <- mkReg('b110);

    mkConnection(vid._read, controller.pins.tofino.vid);

    //
    // Ignition
    //

    // Instantiate Transceivers, IO adapters and connect them to the Ignition
    // Controllers.
    Transceivers#(n_ignition_controllers) controller_txrs <- mkTransceivers();

    zipWithM(
        mkConnection,
        controller_txrs.txrs,
        map(transceiver_client,
            controller.ignition_controllers));

    mkConnection(asIfc(tick_1khz), asIfc(controller_txrs.tick_1khz));

    Strobe#(3) controller_tx_strobe <- mkLimitStrobe(1, 5, 0);
    mkFreeRunningStrobe(controller_tx_strobe);

    function to_serial(txr) = txr.serial;

    Vector#(4, SampledSerialIOTxOutputEnable#(5)) controller_io <-
        zipWithM(
            mkSampledSerialIOWithTxStrobeAndOutputEnable(controller_tx_strobe),
            map(tx_enabled, controller.ignition_controllers),
            map(to_serial, controller_txrs.txrs));

    // Make Inouts for the two adapters connecting to the external Targets,
    // allowing them to be connected to the top level.
    Inout#(Bit#(1)) aux0_tx_ <-
        mkOutputWithEnableSyncFor(
            controller_io[2].tx,
            controller_io[2].tx_enabled);

    Inout#(Bit#(1)) aux1_tx_ <-
        mkOutputWithEnableSyncFor(
            controller_io[3].tx,
            controller_io[3].tx_enabled);

    //
    // Ignition Target, connected to Ignition Controllers 0, 1.
    //

    Target target <- mkTarget(default_app_with_reset_button);
    TargetTransceiver target_txr <- mkTargetTransceiver(True);

    mkConnection(asIfc(tick_1khz), asIfc(target.tick_1khz));
    mkConnection(target_txr, target.txr);

    (* fire_when_enabled *)
    rule do_set_target_system_type;
        target.set_system_type(5);
    endrule

    Strobe#(3) target_tx_strobe <- mkLimitStrobe(1, 5, 3);
    mkFreeRunningStrobe(target_tx_strobe);

    SampledSerialIO#(5) target_link0 <-
        mkSampledSerialIOWithTxStrobe(
            target_tx_strobe,
            tuple2(target_txr.to_link, target_txr.from_link[0]));

    SampledSerialIO#(5) target_link1 <-
        mkSampledSerialIOWithPassiveTx(
            tuple2(target_txr.to_link, target_txr.from_link[1]));

    mkConnection(controller_io[0], target_link0);

    // Link 1 has its polarity inverted to show a difference in link state.
    (* fire_when_enabled *)
    rule do_controller1_link_polarity_inverted;
        let controller_to_target =
            controller_io[1].tx_enabled ?
                controller_io[1].tx :
                0;

        target_link1.rx(~(controller_to_target));

        // The Target->Controller direction is not connected, simulating a cable
        // failure and allowing for the `always_transmit` bit to be tested. If
        // this bit is enabled Controller 1 will be marked as present by the
        // Target (and this will be visible on Controller 0) despite the Target
        // not being present for Controller 1.
    endrule

    //
    // LED, add register without reset to avoid warnings about crossing a reset
    // boundary.
    //

    ReadOnly#(Bit#(1)) ignition_link2_status_led <-
        mkLinkStatusLED(
            controller.ignition_controllers[2].status.target_present,
            controller_txrs.txrs[2].status,
            controller_txrs.txrs[2].receiver_locked_timeout,
            False);

    ReadOnly#(Bit#(1)) ignition_link3_status_led <-
        mkLinkStatusLED(
            controller.ignition_controllers[3].status.target_present,
            controller_txrs.txrs[3].status,
            controller_txrs.txrs[3].receiver_locked_timeout,
            False);

    Reg#(Bit#(8)) led_r <- mkConfigRegU();

    (* fire_when_enabled *)
    rule do_set_led;
        led_r <=  ~{
            pack(target.system_power),
            ignition_link3_status_led,
            ignition_link2_status_led,
            pack(front_io_hsc.state.enabled),
            pack(controller.status)};
    endrule

    //
    // Additional debug
    //

    Reg#(Bit#(1)) debug_r <- mkRegU();

    (* fire_when_enabled *)
    rule do_debug;
        debug_r <= 0;
    endrule

    method spi_csn = sync(csn);
    method spi_sclk = sync(sclk);
    method spi_copi = sync(copi);
    method spi_cipo = cipo;

    method led = led_r;
    method debug = debug_r;

    method aux0_rx = controller_io[2].rx;
    interface Inout aux0_tx = aux0_tx_;

    method aux1_rx = controller_io[3].rx;
    interface Inout aux1_tx = aux1_tx_;
endmodule

endpackage
