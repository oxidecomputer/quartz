package SidecarMainboardControllerTop;

export SidecarMainboardControllerTop(..);
export mkSidecarMainboardControllerTop;

import Clocks::*;
import ConfigReg::*;
import Connectable::*;

import SPI::*;
import IOSync::*;

import FanModule::*;
import PCIeEndpointController::*;
import PowerRail::*;
import SidecarMainboardController::*;
import SidecarMainboardControllerSpiServer::*;
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

    // PCIe Endpoint
    method Bool pcie_fpga_to_host_prsnt_l();
    method Bool pcie_fpga_to_host_pwrflt();
    (* prefix = "" *) method Action pcie_host_to_fpga_perst(Bool pcie_host_to_fpga_perst);

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

    method Bool fpga_to_phy4_reset_l();

    //
    // Fans
    //

    method Bool fpga_to_fan0_hsc_en();
    (* prefix = "" *) method Action fan0_hsc_to_fpga_pg(Bool fan0_hsc_to_fpga_pg);
    method Bool fpga_to_fan0_led_l();

    method Bool fpga_to_fan1_hsc_en();
    (* prefix = "" *) method Action fan1_hsc_to_fpga_pg(Bool fan1_hsc_to_fpga_pg);
    method Bool fpga_to_fan1_led_l();

    method Bool fpga_to_fan2_hsc_en();
    (* prefix = "" *) method Action fan2_hsc_to_fpga_pg(Bool fan2_hsc_to_fpga_pg);
    method Bool fpga_to_fan2_led_l();

    method Bool fpga_to_fan3_hsc_en();
    (* prefix = "" *) method Action fan3_hsc_to_fpga_pg(Bool fan3_hsc_to_fpga_pg);
    method Bool fpga_to_fan3_led_l();

    //
    // Front IO
    //

    method Bool fpga_to_front_io_hsc_en();
    (* prefix = "" *) method Action front_io_hsc_to_fpga_pg(Bool front_io_hsc_to_fpga_pg);
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
    // Sync I/O to the default clock and `reset`. This roughly follows the
    // constraint file.
    //

    //
    // Serial interface
    //

    SpiPeripheralPhy spi_phy <- mkSpiPeripheralPhy(reset_by reset_sync);
    SpiDecodeIF spi_decoder <- mkSpiRegDecode(reset_by reset_sync);
    SpiServer spi_server <-
        mkSpiServer(
            controller.registers.tofino,
            controller.registers.pcie,
            reset_by reset_sync);

    Reg#(Bit#(1)) csn <- mkInputSyncFor(spi_phy.pins.csn);
    Reg#(Bit#(1)) sclk <- mkInputSyncFor(spi_phy.pins.sclk);
    Reg#(Bit#(1)) copi <- mkInputSyncFor(spi_phy.pins.copi);
    ReadOnly#(Bit#(1)) cipo <- mkOutputSyncFor(spi_phy.pins.cipo);

    mkConnection(spi_phy.decoder_if, spi_decoder.spi_byte);
    mkConnection(spi_decoder.reg_con, spi_server);

    //
    // Debug
    //

    ReadOnly#(Bit#(1)) clk_1hz <- mkOutputSyncFor(controller.status.clk_1hz);

    //
    // Clock Generator Sequencer
    //

    ReadOnly#(Bool) clocks_reset <- mkOutputSyncFor(controller.pins.clocks.reset);
    ReadOnly#(Bool) clocks_ldo_en <- mkOutputSyncFor(controller.pins.clocks.ldo.en);
    Reg#(Bool) clocks_ldo_pg <- mkInputSyncFor(controller.pins.clocks.ldo.pg);

    //
    // Tofino Sequencer
    //

    ReadOnly#(Tofino2Resets) tofino_resets <-
        mkOutputSyncFor(controller.pins.tofino.resets);

    Reg#(Bit#(3)) vid <- mkInputSync();

    (* fire_when_enabled *)
    rule do_set_vid;
        // The VID bits are reversed on the PCB and corrected here.
        controller.pins.tofino.vid(reverseBits(vid));
    endrule

    Reg#(Bool) tofino_thermal_alert <-
        mkInputSyncFor(controller.pins.tofino.thermal_alert);

    ReadOnly#(Bool) vdd18_en <- mkOutputSyncFor(controller.pins.tofino.vdd18.en);
    Reg#(Bool) vdd18_pg <- mkInputSyncFor(controller.pins.tofino.vdd18.pg);
    Reg#(Bool) vdd18_fault <- mkInputSyncFor(controller.pins.tofino.vdd18.fault);
    Reg#(Bool) vdd18_vrhot <- mkInputSyncFor(controller.pins.tofino.vdd18.vrhot);

    ReadOnly#(Bool) vddcore_en <- mkOutputSyncFor(controller.pins.tofino.vddcore.en);
    Reg#(Bool) vddcore_pg <- mkInputSyncFor(controller.pins.tofino.vddcore.pg);
    Reg#(Bool) vddcore_fault <- mkInputSyncFor(controller.pins.tofino.vddcore.fault);
    Reg#(Bool) vddcore_vrhot <- mkInputSyncFor(controller.pins.tofino.vddcore.vrhot);

    ReadOnly#(Bool) vddpcie_en <- mkOutputSyncFor(controller.pins.tofino.vddpcie.en);
    Reg#(Bool) vddpcie_pg <- mkInputSyncFor(controller.pins.tofino.vddpcie.pg);

    // VDDx is a voltage regulator shared between the VDDt and VDDA15 rails. The
    // device signals and interface are wired up accordingly.
    ReadOnly#(Bool) vddx_en <-
        mkOutputSyncFor(
            controller.pins.tofino.vddt.en ||
            controller.pins.tofino.vdda15.en);
    Reg#(Bool) vddx_pg <- mkInputSyncFor(controller.pins.tofino.vddt.pg);
    Reg#(Bool) vddx_fault <- mkInputSyncFor(controller.pins.tofino.vddt.fault);
    Reg#(Bool) vddx_vrhot <- mkInputSyncFor(controller.pins.tofino.vddt.vrhot);

    Reg#(Bool) vdda15_pg <- mkInputSyncFor(controller.pins.tofino.vdda15.pg);
    mkConnection(vddx_fault, controller.pins.tofino.vdda15.fault);
    mkConnection(vddx_vrhot, controller.pins.tofino.vdda15.vrhot);

    // VDDA18 is colocated with VDD18, but has a discrete enable. The device
    // signals and interface are wired up accordingly.
    ReadOnly#(Bool) vdda18_en <- mkOutputSyncFor(controller.pins.tofino.vdda18.en);
    Reg#(Bool) vdda18_pg <- mkInputSyncFor(controller.pins.tofino.vdda18.pg);
    mkConnection(vdd18_fault, controller.pins.tofino.vdda18.fault);
    mkConnection(vdd18_vrhot, controller.pins.tofino.vdda18.vrhot);

    ReadOnly#(Bool) tofino_clocks_en <-
        mkOutputSyncFor(controller.pins.tofino.clocks_enable);

    ReadOnly#(Bool) tofino_in_a0 <-
        mkOutputSyncFor(controller.status.tofino_in_a0);

    // PCIe Endpoint
    ReadOnly#(Bool) pcie_present <- mkOutputSyncFor(controller.pins.pcie.present);
    ReadOnly#(Bool) pcie_power_fault <- mkOutputSyncFor(controller.pins.pcie.power_fault);
    // TODO (arjen): The PWREN pin was repurposed to ALERT pin between Gimlet
    // Rev A and Rev B. The Sidecar mainboard is still configured as input. Keep
    // this disabled until an MCN has been assigned or Sidecar Mainboard Rev B
    // is released.
    //ReadOnly#(Bool) pcie_alert <- mkOutputSyncFor(controller.pins.pcie.alert);
    Reg#(Bool) pcie_reset <- mkInputSyncFor(controller.pins.pcie.reset);

    //
    // VSC7448 Sequencer
    //

    ReadOnly#(Bool) vsc7448_reset <- mkOutputSyncFor(controller.pins.vsc7448.reset);

    ReadOnly#(Bool) vsc7448_v1p0_en <- mkOutputSyncFor(controller.pins.vsc7448.v1p0.en);
    Reg#(Bool) vsc7448_v1p0_pg <- mkInputSyncFor(controller.pins.vsc7448.v1p0.pg);

    ReadOnly#(Bool) vsc7448_v1p2_en <- mkOutputSyncFor(controller.pins.vsc7448.v1p2.en);
    Reg#(Bool) vsc7448_v1p2_pg <- mkInputSyncFor(controller.pins.vsc7448.v1p2.pg);

    ReadOnly#(Bool) vsc7448_v2p5_en <- mkOutputSyncFor(controller.pins.vsc7448.v2p5.en);
    Reg#(Bool) vsc7448_v2p5_pg <- mkInputSyncFor(controller.pins.vsc7448.v2p5.pg);

    ReadOnly#(Bool) vsc7448_clocks_en <-
        mkOutputSyncFor(controller.pins.vsc7448.clocks_enable);

    Reg#(Bool) vsc7448_thermal_alert <-
        mkInputSyncFor(controller.pins.vsc7448.thermal_alert);

    //
    // Fans
    //

    ReadOnly#(Bool) fan0_en <- mkOutputSyncFor(controller.pins.fans[0].en);
    ReadOnly#(Bool) fan0_led <- mkOutputSyncFor(controller.pins.fans[0].led);
    Reg#(Bool) fan0_pg <- mkInputSyncFor(controller.pins.fans[0].pg);

    ReadOnly#(Bool) fan1_en <- mkOutputSyncFor(controller.pins.fans[1].en);
    ReadOnly#(Bool) fan1_led <- mkOutputSyncFor(controller.pins.fans[1].led);
    Reg#(Bool) fan1_pg <- mkInputSyncFor(controller.pins.fans[1].pg);

    ReadOnly#(Bool) fan2_en <- mkOutputSyncFor(controller.pins.fans[2].en);
    ReadOnly#(Bool) fan2_led <- mkOutputSyncFor(controller.pins.fans[2].led);
    Reg#(Bool) fan2_pg <- mkInputSyncFor(controller.pins.fans[2].pg);

    ReadOnly#(Bool) fan3_en <- mkOutputSyncFor(controller.pins.fans[3].en);
    ReadOnly#(Bool) fan3_led <- mkOutputSyncFor(controller.pins.fans[3].led);
    Reg#(Bool) fan3_pg <- mkInputSyncFor(controller.pins.fans[3].pg);

    //
    // Front IO
    //
    Reg#(Bool) front_io_en <- mkReg(True);
    Reg#(Bool) front_io_pg <- mkRegU();

    //
    // Interface, wiring up device signals.
    //

    method spi_sp_to_fpga_cs1_l = sync(csn);
    method spi_sp_to_fpga_sck = sync(sclk);
    method spi_sp_to_fpga_mosi = sync(copi);
    method spi_sp_to_fpga_miso_r = cipo;

    method fpga_led0 = clk_1hz;
    method tf_pg_led = tofino_in_a0;

    // Tofino pins
    method fpga_to_tf_core_rst_l = True;
    method fpga_to_tf_pwron_rst_l = !tofino_resets.pwron;
    method fpga_to_tf_pcie_rst_l = !tofino_resets.pcie;
    method tf_to_fpga_vid = sync(vid);

    method fpga_to_tf_test_core_tap_l = True;
    method fpga_to_tf_test_jtsel = '0;

    method fpga_to_vr_tf_vdd1p8_en = vdd18_en;
    method vr_tf_v1p8_to_fpga_vdd1p8_pg = sync(vdd18_pg);
    method vr_tf_v1p8_to_fpga_fault = sync(vdd18_fault);
    method vr_tf_v1p8_to_fpga_vr_hot_l = sync_inverted(vdd18_vrhot);

    method fpga_to_vr_tf_vddcore_en = vddcore_en;
    method vr_tf_vddcore_to_fpga_pg = sync(vddcore_pg);
    method vr_tf_vddcore_to_fpga_fault = sync(vddcore_fault);
    method vr_tf_vddcore_to_fpga_vrhot_l = sync_inverted(vddcore_vrhot);

    method fpga_to_ldo_v0p75_tf_pcie_en = vddpcie_en;
    method ldo_to_fpga_v0p75_tf_pcie_pg = sync(vddpcie_pg);

    method fpga_to_vr_tf_vddx_en = vddx_en;
    method vr_tf_vddx_to_fpga_vddt_pg = sync(vddx_pg);
    method vr_tf_vddx_to_fpga_fault = sync(vddx_fault);
    method vr_tf_vddx_to_fpga_vrhot_l = sync_inverted(vddx_vrhot);

    method vr_tf_vddx_to_fpga_vdda15_pg = sync(vdda15_pg);

    method fpga_to_vr_tf_vdda1p8_en = vdda18_en;
    method vr_tf_v1p8_to_fpga_vdda1p8_pg = sync(vdda18_pg);

    method tf_to_fpga_temp_therm_l = sync_inverted(tofino_thermal_alert);

    method pcie_fpga_to_host_prsnt_l = !pcie_present;
    method pcie_fpga_to_host_pwrflt = pcie_power_fault;
    method pcie_host_to_fpga_perst = sync_inverted(pcie_reset);

    // Clock Generator pins
    method fpga_to_smu_reset_l = !clocks_reset;
    method fpga_to_ldo_smu_en = clocks_ldo_en;
    method ldo_to_fpga_smu_pg = sync(clocks_ldo_pg);

    method fpga_to_smu_tf_clk_en_l = !tofino_clocks_en;
    method fpga_to_smu_mgmt_clk_en_l = !vsc7448_clocks_en;

    // VSC7448 pins
    method fpga_to_mgmt_reset_l = !vsc7448_reset;

    method fpga_to_vr_v1p0_mgmt_en = vsc7448_v1p0_en;
    method vr_v1p0_mgmt_to_fpga_pg = sync(vsc7448_v1p0_pg);

    method fpga_to_ldo_v1p2_mgmt_en = vsc7448_v1p2_en;
    method ldo_to_fpga_v1p2_mgmt_pg = sync(vsc7448_v1p2_pg);

    method fpga_to_ldo_v2p5_mgmt_en = vsc7448_v2p5_en;
    method ldo_to_fpga_v2p5_mgmt_pg = sync(vsc7448_v2p5_pg);

    method mgmt_to_fpga_temp_therm_l = sync_inverted(vsc7448_thermal_alert);

    method Bool fpga_to_phy4_reset_l = !vsc7448_reset;

    // Fan pins
    method fpga_to_fan0_hsc_en = fan0_en;
    method fan0_hsc_to_fpga_pg = sync(fan0_pg);
    method fpga_to_fan0_led_l = fan0_led; // Not active low on Fan VPD.

    method fpga_to_fan1_hsc_en = fan1_en;
    method fan1_hsc_to_fpga_pg = sync(fan1_pg);
    method fpga_to_fan1_led_l = fan1_led; // Not active low on Fan VPD.

    method fpga_to_fan2_hsc_en = fan2_en;
    method fan2_hsc_to_fpga_pg = sync(fan2_pg);
    method fpga_to_fan2_led_l = fan2_led; // Not active low on Fan VPD.

    method fpga_to_fan3_hsc_en = fan3_en;
    method fan3_hsc_to_fpga_pg = sync(fan3_pg);
    method fpga_to_fan3_led_l = fan3_led; // Not active low on Fan VPD.

    // Front IO
    method fpga_to_front_io_hsc_en = front_io_en;
    method front_io_hsc_to_fpga_pg = sync(front_io_pg);
endmodule

endpackage
