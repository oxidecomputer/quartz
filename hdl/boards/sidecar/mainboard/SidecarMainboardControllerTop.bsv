package SidecarMainboardControllerTop;

export SidecarMainboardControllerTop(..);
export mkSidecarMainboardControllerTop;

import Clocks::*;
import Connectable::*;

import SyncBits::*;

import PowerRail::*;
import SpiDecode::*;
import SidecarMainboardController::*;
import SidecarMainboardMiscSequencers::*;
import Tofino2Sequencer::*;


(* always_enabled *)
interface SidecarMainboardControllerTop;
    //
    // SPI peripheral
    //

    (* prefix = "" *) method Action spi_sp_to_fpga_cs1_l(Bit#(1) spi_sp_to_fpga_cs1_l);
    (* prefix = "" *) method Action spi_sp_to_fpga_sck(Bit#(1) spi_sp_to_fpga_sck);
    (* prefix = "" *) method Action spi_sp_to_fpga_mosi(Bit#(1) spi_sp_to_fpga_mosi);
    method Bit#(1) spi_sp_to_fpga_miso_r();

    //
    // Debug
    //

    method Bit#(1) fpga_led0();

    //
    // Tofino
    //

    method Bool fpga_to_tf_core_rst_l();
    method Bool fpga_to_tf_pwron_rst_l();
    method Bool fpga_to_tf_pcie_rst_l();
    (* prefix = "" *) method Action tf_to_fpga_vid(Bit#(3) tf_to_fpga_vid);

    // Test (currently unused)
    method Bool fpga_to_tf_test_core_tap_l();
    method Bit#(4) fpga_to_tf_test_jtsel();

    //
    // Tofino PDN
    //

    // V1P8
    method Bool fpga_to_vr_tf_vdd1p8_en();
    (* prefix = "" *) method Action vr_tf_v1p8_to_fpga_vdd1p8_pg(Bool vr_tf_v1p8_to_fpga_vdd1p8_pg);
    (* prefix = "" *) method Action vr_tf_v1p8_to_fpga_fault(Bool vr_tf_v1p8_to_fpga_fault);
    (* prefix = "" *) method Action vr_tf_v1p8_to_fpga_vr_hot_l(Bool vr_tf_v1p8_to_fpga_vr_hot_l);

    // VDDCORE
    method Bool fpga_to_vr_tf_vddcore_en();
    (* prefix = "" *) method Action vr_tf_vddcore_to_fpga_pg(Bool vr_tf_vddcore_to_fpga_pg);
    (* prefix = "" *) method Action vr_tf_vddcore_to_fpga_fault(Bool vr_tf_vddcore_to_fpga_fault);
    (* prefix = "" *) method Action vr_tf_vddcore_to_fpga_vrhot_l(Bool vr_tf_vddcore_to_fpga_vrhot_l);

    // VDDPCIE
    method Bool fpga_to_ldo_v0p75_tf_pcie_en();
    (* prefix = "" *) method Action ldo_to_fpga_v0p75_tf_pcie_pg(Bool ldo_to_fpga_v0p75_tf_pcie_pg);

    // VDDt
    method Bool fpga_to_vr_tf_vddx_en();
    (* prefix = "" *) method Action vr_tf_vddx_to_fpga_vddt_pg(Bool vr_tf_vddx_to_fpga_vddt_pg);
    (* prefix = "" *) method Action vr_tf_vddx_to_fpga_fault(Bool vr_tf_vddx_to_fpga_fault);
    (* prefix = "" *) method Action vr_tf_vddx_to_fpga_vrhot_l(Bool vr_tf_vddx_to_fpga_vrhot_l);

    // VDDA1P5
    (* prefix = "" *) method Action vr_tf_vddx_to_fpga_vdda15_pg(Bool vr_tf_vddx_to_fpga_vdda15_pg);

    // VDDA1P8
    method Bool fpga_to_vr_tf_vdda1p8_en();
    (* prefix = "" *) method Action vr_tf_v1p8_to_fpga_vdda1p8_pg(Bool vr_tf_v1p8_to_fpga_vdda1p8_pg);

    // Power Indicator
    method Bool tf_pg_led();

    // Thermal Alert
    (* prefix = "" *) method Action tf_to_fpga_temp_therm_l(Bool tf_to_fpga_temp_therm_l);

    //
    // Clock Management
    //

    method Bool fpga_to_smu_reset_l();
    method Bool fpga_to_ldo_smu_en();
    (* prefix = "" *) method Action ldo_to_fpga_smu_pg(Bool ldo_to_fpga_smu_pg);

    method Bool fpga_to_smu_tf_clk_en_l();
    method Bool fpga_to_smu_mgmt_clk_en_l();

    //
    // VSC7448 (Management Network)
    //

    method Bool fpga_to_mgmt_reset_l();

    // 1.0V regulator
    method Bool fpga_to_vr_v1p0_mgmt_en();
    (* prefix = "" *) method Action vr_v1p0_mgmt_to_fpga_pg(Bool vr_v1p0_mgmt_to_fpga_pg);

    // 1.2V/2.5V LDOs
    method Bool fpga_to_ldo_v1p2_mgmt_en();
    (* prefix = "" *) method Action ldo_to_fpga_v1p2_mgmt_pg(Bool ldo_to_fpga_v1p2_mgmt_pg);

    method Bool fpga_to_ldo_v2p5_mgmt_en();
    (* prefix = "" *) method Action ldo_to_fpga_v2p5_mgmt_pg(Bool ldo_to_fpga_v2p5_mgmt_pg);

    // Thermal Alert
    (* prefix = "" *) method Action mgmt_to_fpga_temp_therm_l(Bool mgmt_to_fpga_temp_therm_l);
endinterface

(* synthesize,
    default_clock_osc = "clk_50m_fpga_refclk",
    default_reset="sp_to_fpga_design_reset_l" *)
module mkSidecarMainboardControllerTop (SidecarMainboardControllerTop);
    // Synchronize the default reset to the default clock.
    Clock clk_50mhz <- exposeCurrentClock();
    Reset reset_sync <- mkAsyncResetFromCR(2, clk_50mhz);

    MainboardController controller <-
        mkMainboardController(defaultValue, reset_by reset_sync);

    //
    // Sync I/O to the default clock and `reset_sync`. This roughly follows the
    // constraint file.
    //

    //
    // SPI peripheral.
    //

    SyncBitIfc#(Bit#(1)) csn_sync <- mkSyncBitToCC(clk_50mhz, noReset);
    SyncBitIfc#(Bit#(1)) sclk_sync <- mkSyncBitToCC(clk_50mhz, noReset);
    SyncBitIfc#(Bit#(1)) copi_sync <- mkSyncBitToCC(clk_50mhz, noReset);
    ReadOnly#(Bit#(1)) cipo_sync <- mkNullCrossingWire(clk_50mhz, controller.spi_pins.cipo);

    mkConnection(csn_sync.read, controller.spi_pins.csn);
    mkConnection(sclk_sync.read, controller.spi_pins.sclk);
    mkConnection(copi_sync.read, controller.spi_pins.copi);

    //
    // Debug
    //

    ReadOnly#(Bit#(1)) clk_1hz_sync <-
        mkNullCrossingWire(clk_50mhz, controller.status.clk_1hz);

    //
    // Clock Generator Sequencer
    //

    ReadOnly#(Bool) clock_generator_reset_sync <-
        mkNullCrossingWire(clk_50mhz, controller.clock_generator_pins.reset);
    ReadOnly#(Bool) clock_generator_ldo_en_sync <-
        mkNullCrossingWire(clk_50mhz, controller.clock_generator_pins.ldo.en);
    SyncBitIfc#(Bool) clock_generator_ldo_pg_sync <- mkSyncBitToCC(clk_50mhz, noReset);

    mkConnection(clock_generator_ldo_pg_sync.read, controller.clock_generator_pins.ldo.pg);

    //
    // Tofino Sequencer
    //

    ReadOnly#(Tofino2Resets) tofino_resets_sync <-
        mkNullCrossingWire(clk_50mhz, controller.tofino_sequencer_pins.resets);
    SyncBitsIfc#(Bit#(3)) vid_sync <- mkSyncBitsToCC(clk_50mhz, noReset);

    (* fire_when_enabled *)
    rule do_set_vid;
        let vid = vid_sync.read;

        // The VID bits are reversed on the PCB and corrected here.
        controller.tofino_sequencer_pins.vid(
            unpack({vid[0], vid[1], vid[2]}));
    endrule

    SyncBitIfc#(Bool) thermal_alert_sync <- mkSyncBitToCC(clk_50mhz, noReset);
    mkConnection(thermal_alert_sync.read, controller.tofino_sequencer_pins.thermal_alert);

    ReadOnly#(Bool) vdd18_en_sync <-
        mkNullCrossingWire(clk_50mhz, controller.tofino_sequencer_pins.vdd18.en);
    SyncBitIfc#(Bool) vdd18_pg_sync <- mkSyncBitToCC(clk_50mhz, noReset);
    SyncBitIfc#(Bool) vdd18_fault_sync <- mkSyncBitToCC(clk_50mhz, noReset);
    SyncBitIfc#(Bool) vdd18_vrhot_sync <- mkSyncBitToCC(clk_50mhz, noReset);

    mkConnection(vdd18_pg_sync.read, controller.tofino_sequencer_pins.vdd18.pg);
    mkConnection(vdd18_fault_sync.read, controller.tofino_sequencer_pins.vdd18.fault);
    mkConnection(vdd18_vrhot_sync.read, controller.tofino_sequencer_pins.vdd18.vrhot);

    ReadOnly#(Bool) vddcore_en_sync <-
        mkNullCrossingWire(clk_50mhz, controller.tofino_sequencer_pins.vddcore.en);
    SyncBitIfc#(Bool) vddcore_pg_sync <- mkSyncBitToCC(clk_50mhz, noReset);
    SyncBitIfc#(Bool) vddcore_fault_sync <- mkSyncBitToCC(clk_50mhz, noReset);
    SyncBitIfc#(Bool) vddcore_vrhot_sync <- mkSyncBitToCC(clk_50mhz, noReset);

    mkConnection(vddcore_pg_sync.read, controller.tofino_sequencer_pins.vddcore.pg);
    mkConnection(vddcore_fault_sync.read, controller.tofino_sequencer_pins.vddcore.fault);
    mkConnection(vddcore_vrhot_sync.read, controller.tofino_sequencer_pins.vddcore.vrhot);

    ReadOnly#(Bool) vddpcie_en_sync <-
        mkNullCrossingWire(clk_50mhz, controller.tofino_sequencer_pins.vddpcie.en);
    SyncBitIfc#(Bool) vddpcie_pg_sync <- mkSyncBitToCC(clk_50mhz, noReset);

    mkConnection(vddpcie_pg_sync.read, controller.tofino_sequencer_pins.vddpcie.pg);

    // VDDx is a voltage regulator shared between the VDDt and VDDA15 rails. The
    // device signals and interface are wired up accordingly.
    ReadOnly#(Bool) vddx_en_sync <-
        mkNullCrossingWire(clk_50mhz,
            controller.tofino_sequencer_pins.vddt.en ||
            controller.tofino_sequencer_pins.vdda15.en);
    SyncBitIfc#(Bool) vddx_pg_sync <- mkSyncBitToCC(clk_50mhz, noReset);
    SyncBitIfc#(Bool) vddx_fault_sync <- mkSyncBitToCC(clk_50mhz, noReset);
    SyncBitIfc#(Bool) vddx_vrhot_sync <- mkSyncBitToCC(clk_50mhz, noReset);

    mkConnection(vddx_pg_sync.read, controller.tofino_sequencer_pins.vddt.pg);
    mkConnection(vddx_fault_sync.read, controller.tofino_sequencer_pins.vddt.fault);
    mkConnection(vddx_vrhot_sync.read, controller.tofino_sequencer_pins.vddt.vrhot);

    SyncBitIfc#(Bool) vdda15_pg_sync <- mkSyncBitToCC(clk_50mhz, noReset);

    mkConnection(vdda15_pg_sync.read, controller.tofino_sequencer_pins.vdda15.pg);
    mkConnection(vddx_fault_sync.read, controller.tofino_sequencer_pins.vdda15.fault);
    mkConnection(vddx_vrhot_sync.read, controller.tofino_sequencer_pins.vdda15.vrhot);

    // VDDA18 is colocated with VDD18, but has a discrete enable. The device
    // signals and interface are wired up accordingly.
    ReadOnly#(Bool) vdda18_en_sync <-
        mkNullCrossingWire(clk_50mhz, controller.tofino_sequencer_pins.vdda18.en);
    SyncBitIfc#(Bool) vdda18_pg_sync <- mkSyncBitToCC(clk_50mhz, noReset);

    mkConnection(vdda18_pg_sync.read, controller.tofino_sequencer_pins.vdda18.pg);
    mkConnection(vdd18_fault_sync.read, controller.tofino_sequencer_pins.vdda18.fault);
    mkConnection(vdd18_vrhot_sync.read, controller.tofino_sequencer_pins.vdda18.vrhot);

    ReadOnly#(Bool) tofino_clocks_enable_sync <-
        mkNullCrossingWire(clk_50mhz, controller.tofino_sequencer_pins.clocks_enable);

    ReadOnly#(Bool) tofino_in_a0_sync <-
        mkNullCrossingWire(clk_50mhz, controller.status.tofino_in_a0);

    //
    // VSC7448 Sequencer
    //

    ReadOnly#(Bool) vsc7448_reset_sync <-
        mkNullCrossingWire(clk_50mhz, controller.vsc7448_pins.reset);

    ReadOnly#(Bool) vsc7448_v1p0_en_sync <-
        mkNullCrossingWire(clk_50mhz, controller.vsc7448_pins.v1p0.en);
    SyncBitIfc#(Bool) vsc7448_v1p0_pg_sync <- mkSyncBitToCC(clk_50mhz, noReset);

    ReadOnly#(Bool) vsc7448_v1p2_en_sync <-
        mkNullCrossingWire(clk_50mhz, controller.vsc7448_pins.v1p2.en);
    SyncBitIfc#(Bool) vsc7448_v1p2_pg_sync <- mkSyncBitToCC(clk_50mhz, noReset);

    ReadOnly#(Bool) vsc7448_v2p5_en_sync <-
        mkNullCrossingWire(clk_50mhz, controller.vsc7448_pins.v2p5.en);
    SyncBitIfc#(Bool) vsc7448_v2p5_pg_sync <- mkSyncBitToCC(clk_50mhz, noReset);

    ReadOnly#(Bool) vsc7448_clocks_enable_sync <-
        mkNullCrossingWire(clk_50mhz, controller.vsc7448_pins.clocks_enable);

    SyncBitIfc#(Bool) vsc7448_thermal_alert_sync <- mkSyncBitToCC(clk_50mhz, noReset);

    mkConnection(vsc7448_v1p0_pg_sync.read, controller.vsc7448_pins.v1p0.pg);
    mkConnection(vsc7448_v1p2_pg_sync.read, controller.vsc7448_pins.v1p2.pg);
    mkConnection(vsc7448_v2p5_pg_sync.read, controller.vsc7448_pins.v2p5.pg);

    //
    // Interface, wiring up device signals.
    //

    method spi_sp_to_fpga_cs1_l = csn_sync.send;
    method spi_sp_to_fpga_sck = sclk_sync.send;
    method spi_sp_to_fpga_mosi = copi_sync.send;
    method spi_sp_to_fpga_miso_r = cipo_sync;

    method fpga_led0 = clk_1hz_sync;
    method tf_pg_led = tofino_in_a0_sync;

    // Tofino pins
    method fpga_to_tf_core_rst_l = True;
    method fpga_to_tf_pwron_rst_l = !tofino_resets_sync.pwron;
    method fpga_to_tf_pcie_rst_l = !tofino_resets_sync.pcie;
    method tf_to_fpga_vid = vid_sync.send;

    method fpga_to_tf_test_core_tap_l = True;
    method fpga_to_tf_test_jtsel = '0;

    method fpga_to_vr_tf_vdd1p8_en = vdd18_en_sync;
    method vr_tf_v1p8_to_fpga_vdd1p8_pg = vdd18_pg_sync.send;
    method vr_tf_v1p8_to_fpga_fault = vdd18_fault_sync.send;
    method Action vr_tf_v1p8_to_fpga_vr_hot_l(Bool vrhot_l) = vdd18_vrhot_sync.send(!vrhot_l);

    method fpga_to_vr_tf_vddcore_en = vddcore_en_sync;
    method vr_tf_vddcore_to_fpga_pg = vddcore_pg_sync.send;
    method vr_tf_vddcore_to_fpga_fault = vddcore_fault_sync.send;
    method Action vr_tf_vddcore_to_fpga_vrhot_l(Bool vrhot_l) = vddcore_vrhot_sync.send(!vrhot_l);

    method fpga_to_ldo_v0p75_tf_pcie_en = vddpcie_en_sync;
    method ldo_to_fpga_v0p75_tf_pcie_pg = vddpcie_pg_sync.send;

    method fpga_to_vr_tf_vddx_en = vddx_en_sync;
    method vr_tf_vddx_to_fpga_vddt_pg = vddx_pg_sync.send;
    method vr_tf_vddx_to_fpga_fault = vddx_fault_sync.send;
    method Action vr_tf_vddx_to_fpga_vrhot_l(Bool vrhot_l) = vddx_vrhot_sync.send(!vrhot_l);

    method vr_tf_vddx_to_fpga_vdda15_pg = vdda15_pg_sync.send;

    method fpga_to_vr_tf_vdda1p8_en = vdda18_en_sync;
    method vr_tf_v1p8_to_fpga_vdda1p8_pg = vdda18_pg_sync.send;

    method Action tf_to_fpga_temp_therm_l(Bool alert_l) = thermal_alert_sync.send(!alert_l);

    // Clock Generator pins
    method fpga_to_smu_reset_l = !clock_generator_reset_sync;
    method fpga_to_ldo_smu_en = clock_generator_ldo_en_sync;
    method ldo_to_fpga_smu_pg = clock_generator_ldo_pg_sync.send;

    method fpga_to_smu_tf_clk_en_l = !tofino_clocks_enable_sync;
    method fpga_to_smu_mgmt_clk_en_l = !vsc7448_clocks_enable_sync;

    // VSC7448 pins
    method fpga_to_mgmt_reset_l = !vsc7448_reset_sync;

    method fpga_to_vr_v1p0_mgmt_en = vsc7448_v1p0_en_sync;
    method vr_v1p0_mgmt_to_fpga_pg = vsc7448_v1p0_pg_sync.send;

    method fpga_to_ldo_v1p2_mgmt_en = vsc7448_v1p2_en_sync;
    method ldo_to_fpga_v1p2_mgmt_pg = vsc7448_v1p2_pg_sync.send;

    method fpga_to_ldo_v2p5_mgmt_en = vsc7448_v2p5_en_sync;
    method ldo_to_fpga_v2p5_mgmt_pg = vsc7448_v2p5_pg_sync.send;

    method Action mgmt_to_fpga_temp_therm_l(Bool alert_l) = vsc7448_thermal_alert_sync.send(!alert_l);
endmodule

endpackage
