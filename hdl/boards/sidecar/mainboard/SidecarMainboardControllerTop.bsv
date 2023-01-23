package SidecarMainboardControllerTop;

export SidecarMainboardControllerTop(..);
export mkSidecarMainboardControllerTop;

import Clocks::*;
import ConfigReg::*;
import Connectable::*;
import TriState::*;

import Bidirection::*;
import IOSync::*;
import SPI::*;

import FanModule::*;
import PCIeEndpointController::*;
import PowerRail::*;
import SidecarMainboardController::*;
import SidecarMainboardControllerSpiServer::*;
import SidecarMainboardMiscSequencers::*;
import Tofino2Sequencer::*;
import TofinoDebugPort::*;


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
    method Bit#(1) fpga_debug0();
    method Bit#(1) fpga_debug1();

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
    // Tofino Debug Port
    //

    interface Inout#(Bit#(1)) i2c_fpga_to_tf_scl;
    interface Inout#(Bit#(1)) i2c_fpga_to_tf_sda;

    //
    // PCIe Endpoint
    //

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
            controller.registers.tofino_debug_port,
            controller.registers.pcie,
            reset_by reset_sync);

    InputReg#(Bit#(1), 2) csn <- mkInputSyncFor(spi_phy.pins.csn);
    InputReg#(Bit#(1), 2) sclk <- mkInputSyncFor(spi_phy.pins.sclk);
    InputReg#(Bit#(1), 2) copi <- mkInputSyncFor(spi_phy.pins.copi);
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
    InputReg#(Bool, 2) clocks_ldo_pg <- mkInputSyncFor(controller.pins.clocks.ldo.pg);

    //
    // Tofino Sequencer
    //

    ReadOnly#(Tofino2Resets) tofino_resets <-
        mkOutputSyncFor(controller.pins.tofino.resets);

    InputReg#(Bit#(3), 2) vid <- mkInputSync();

    (* fire_when_enabled *)
    rule do_set_vid;
        // The VID bits are reversed on the PCB and corrected here.
        controller.pins.tofino.vid(reverseBits(vid));
    endrule

    InputReg#(Bool, 2) tofino_thermal_alert <-
        mkInputSyncFor(controller.pins.tofino.thermal_alert);

    ReadOnly#(Bool) vdd18_en <- mkOutputSyncFor(controller.pins.tofino.vdd18.en);
    InputReg#(Bool, 2) vdd18_pg <- mkInputSyncFor(controller.pins.tofino.vdd18.pg);
    InputReg#(Bool, 2) vdd18_fault <- mkInputSyncFor(controller.pins.tofino.vdd18.fault);
    InputReg#(Bool, 2) vdd18_vrhot <- mkInputSyncFor(controller.pins.tofino.vdd18.vrhot);

    ReadOnly#(Bool) vddcore_en <- mkOutputSyncFor(controller.pins.tofino.vddcore.en);
    InputReg#(Bool, 2) vddcore_pg <- mkInputSyncFor(controller.pins.tofino.vddcore.pg);
    InputReg#(Bool, 2) vddcore_fault <- mkInputSyncFor(controller.pins.tofino.vddcore.fault);
    InputReg#(Bool, 2) vddcore_vrhot <- mkInputSyncFor(controller.pins.tofino.vddcore.vrhot);

    ReadOnly#(Bool) vddpcie_en <- mkOutputSyncFor(controller.pins.tofino.vddpcie.en);
    InputReg#(Bool, 2) vddpcie_pg <- mkInputSyncFor(controller.pins.tofino.vddpcie.pg);

    // VDDx is a voltage regulator shared between the VDDt and VDDA15 rails. The
    // device signals and interface are wired up accordingly.
    ReadOnly#(Bool) vddx_en <-
        mkOutputSyncFor(
            controller.pins.tofino.vddt.en ||
            controller.pins.tofino.vdda15.en);
    InputReg#(Bool, 2) vddx_pg <- mkInputSyncFor(controller.pins.tofino.vddt.pg);
    InputReg#(Bool, 2) vddx_fault <- mkInputSyncFor(controller.pins.tofino.vddt.fault);
    InputReg#(Bool, 2) vddx_vrhot <- mkInputSyncFor(controller.pins.tofino.vddt.vrhot);

    InputReg#(Bool, 2) vdda15_pg <- mkInputSyncFor(controller.pins.tofino.vdda15.pg);
    mkConnection(vddx_fault, controller.pins.tofino.vdda15.fault);
    mkConnection(vddx_vrhot, controller.pins.tofino.vdda15.vrhot);

    // VDDA18 is colocated with VDD18, but has a discrete enable. The device
    // signals and interface are wired up accordingly.
    ReadOnly#(Bool) vdda18_en <- mkOutputSyncFor(controller.pins.tofino.vdda18.en);
    InputReg#(Bool, 2) vdda18_pg <- mkInputSyncFor(controller.pins.tofino.vdda18.pg);
    mkConnection(vdd18_fault, controller.pins.tofino.vdda18.fault);
    mkConnection(vdd18_vrhot, controller.pins.tofino.vdda18.vrhot);

    ReadOnly#(Bool) tofino_clocks_en <-
        mkOutputSyncFor(controller.pins.tofino.clocks_enable);

    ReadOnly#(Bool) tofino_in_a0 <-
        mkOutputSyncFor(controller.status.tofino_in_a0);

    //
    // Tofino Debug Port
    //

    Inout#(Bit#(1)) tofino_debug_port_scl <-
        mkBidirectionRegSyncFor(controller.pins.tofino_debug_port.scl);
    Inout#(Bit#(1)) tofino_debug_port_sda <-
        mkBidirectionRegSyncFor(controller.pins.tofino_debug_port.sda);

    //
    // PCIe Endpoint
    //

    ReadOnly#(Bool) pcie_present <- mkOutputSyncFor(controller.pins.pcie.present);
    ReadOnly#(Bool) pcie_power_fault <- mkOutputSyncFor(controller.pins.pcie.power_fault);
    // TODO (arjen): The PWREN pin was repurposed to ALERT pin between Gimlet
    // Rev A and Rev B. The Sidecar mainboard is still configured as input. Keep
    // this disabled until an MCN has been assigned or Sidecar Mainboard Rev B
    // is released.
    //ReadOnly#(Bool) pcie_alert <- mkOutputSyncFor(controller.pins.pcie.alert);
    InputReg#(Bool, 2) pcie_reset <- mkInputSyncFor(controller.pins.pcie.reset);

    //
    // VSC7448 Sequencer
    //

    ReadOnly#(Bool) vsc7448_reset <- mkOutputSyncFor(controller.pins.vsc7448.reset);

    ReadOnly#(Bool) vsc7448_v1p0_en <- mkOutputSyncFor(controller.pins.vsc7448.v1p0.en);
    InputReg#(Bool, 2) vsc7448_v1p0_pg <- mkInputSyncFor(controller.pins.vsc7448.v1p0.pg);

    ReadOnly#(Bool) vsc7448_v1p2_en <- mkOutputSyncFor(controller.pins.vsc7448.v1p2.en);
    InputReg#(Bool, 2) vsc7448_v1p2_pg <- mkInputSyncFor(controller.pins.vsc7448.v1p2.pg);

    ReadOnly#(Bool) vsc7448_v2p5_en <- mkOutputSyncFor(controller.pins.vsc7448.v2p5.en);
    InputReg#(Bool, 2) vsc7448_v2p5_pg <- mkInputSyncFor(controller.pins.vsc7448.v2p5.pg);

    ReadOnly#(Bool) vsc7448_clocks_en <-
        mkOutputSyncFor(controller.pins.vsc7448.clocks_enable);

    InputReg#(Bool, 2) vsc7448_thermal_alert <-
        mkInputSyncFor(controller.pins.vsc7448.thermal_alert);

    //
    // Fans
    //

    ReadOnly#(Bool) fan0_en <- mkOutputSyncFor(controller.pins.fans[0].en);
    ReadOnly#(Bool) fan0_led <- mkOutputSyncFor(controller.pins.fans[0].led);
    InputReg#(Bool, 2) fan0_pg <- mkInputSyncFor(controller.pins.fans[0].pg);

    ReadOnly#(Bool) fan1_en <- mkOutputSyncFor(controller.pins.fans[1].en);
    ReadOnly#(Bool) fan1_led <- mkOutputSyncFor(controller.pins.fans[1].led);
    InputReg#(Bool, 2) fan1_pg <- mkInputSyncFor(controller.pins.fans[1].pg);

    ReadOnly#(Bool) fan2_en <- mkOutputSyncFor(controller.pins.fans[2].en);
    ReadOnly#(Bool) fan2_led <- mkOutputSyncFor(controller.pins.fans[2].led);
    InputReg#(Bool, 2) fan2_pg <- mkInputSyncFor(controller.pins.fans[2].pg);

    ReadOnly#(Bool) fan3_en <- mkOutputSyncFor(controller.pins.fans[3].en);
    ReadOnly#(Bool) fan3_led <- mkOutputSyncFor(controller.pins.fans[3].led);
    InputReg#(Bool, 2) fan3_pg <- mkInputSyncFor(controller.pins.fans[3].pg);

    //
    // Front IO
    //
    Reg#(Bool) front_io_en <- mkReg(True);
    InputReg#(Bool, 2) front_io_pg <- mkInputSync();

    //
    // Interface, wiring up device signals.
    //

    method spi_sp_to_fpga_cs1_l = sync(csn);
    method spi_sp_to_fpga_sck = sync(sclk);
    method spi_sp_to_fpga_mosi = sync(copi);
    method spi_sp_to_fpga_miso_r = cipo;

    method fpga_led0 = clk_1hz;
    method fpga_debug0 = 0;
    method fpga_debug1 = 0;

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

    interface Inout i2c_fpga_to_tf_scl = tofino_debug_port_scl;
    interface Inout i2c_fpga_to_tf_sda = tofino_debug_port_sda;

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

(* default_clock_osc = "clk_50m_fpga_refclk",
    default_reset="sp_to_fpga_design_reset_l" *)
module mkSidecarMainboardControllerRevB (SidecarMainboardControllerTop);
    (* hide *) SidecarMainboardControllerTop _top <- mkSidecarMainboardControllerTop();
    return _top;
endmodule

//
// Rev A top
//
// Rev A differs from rev B by a few pins. Rev A boards should be phased out
// soon, so for now a separate interface and module are used for rev A. This can
// be removed as soon as rev A boards are deprecated.
//

(* always_enabled *)
interface SidecarMainboardControllerTopRevA;
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
    // Tofino Debug Port
    //

    interface Inout#(Bit#(1)) i2c_fpga_to_tf_scl;
    interface Inout#(Bit#(1)) i2c_fpga_to_tf_sda;

    //
    // PCIe Endpoint
    //

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

(* default_clock_osc = "clk_50m_fpga_refclk",
    default_reset="sp_to_fpga_design_reset_l" *)
module mkSidecarMainboardControllerRevA (SidecarMainboardControllerTopRevA);
    (* hide *) SidecarMainboardControllerTop _top <- mkSidecarMainboardControllerTop();

    method spi_sp_to_fpga_cs1_l = _top.spi_sp_to_fpga_cs1_l;
    method spi_sp_to_fpga_sck = _top.spi_sp_to_fpga_sck;
    method spi_sp_to_fpga_mosi = _top.spi_sp_to_fpga_mosi;
    method spi_sp_to_fpga_miso_r = _top.spi_sp_to_fpga_miso_r;

    method fpga_led0 = _top.fpga_led0;
    method tf_pg_led = _top.tf_pg_led;

    method fpga_to_tf_core_rst_l = _top.fpga_to_tf_core_rst_l;
    method fpga_to_tf_pwron_rst_l = _top.fpga_to_tf_pwron_rst_l;
    method fpga_to_tf_pcie_rst_l = _top.fpga_to_tf_pcie_rst_l;
    method tf_to_fpga_vid = _top.tf_to_fpga_vid;
    method fpga_to_tf_test_core_tap_l = _top.fpga_to_tf_test_core_tap_l;
    method fpga_to_tf_test_jtsel = _top.fpga_to_tf_test_jtsel;

    method fpga_to_vr_tf_vdd1p8_en = _top.fpga_to_vr_tf_vdd1p8_en;
    method vr_tf_v1p8_to_fpga_vdd1p8_pg = _top.vr_tf_v1p8_to_fpga_vdd1p8_pg;
    method vr_tf_v1p8_to_fpga_fault = _top.vr_tf_v1p8_to_fpga_fault;
    method vr_tf_v1p8_to_fpga_vr_hot_l = _top.vr_tf_v1p8_to_fpga_vr_hot_l;
    method fpga_to_vr_tf_vddcore_en = _top.fpga_to_vr_tf_vddcore_en;
    method vr_tf_vddcore_to_fpga_pg = _top.vr_tf_vddcore_to_fpga_pg;
    method vr_tf_vddcore_to_fpga_fault = _top.vr_tf_vddcore_to_fpga_fault;
    method vr_tf_vddcore_to_fpga_vrhot_l = _top.vr_tf_vddcore_to_fpga_vrhot_l;
    method fpga_to_ldo_v0p75_tf_pcie_en = _top.fpga_to_ldo_v0p75_tf_pcie_en;
    method ldo_to_fpga_v0p75_tf_pcie_pg = _top.ldo_to_fpga_v0p75_tf_pcie_pg;
    method fpga_to_vr_tf_vddx_en = _top.fpga_to_vr_tf_vddx_en;
    method vr_tf_vddx_to_fpga_vddt_pg = _top.vr_tf_vddx_to_fpga_vddt_pg;
    method vr_tf_vddx_to_fpga_fault = _top.vr_tf_vddx_to_fpga_fault;
    method vr_tf_vddx_to_fpga_vrhot_l = _top.vr_tf_vddx_to_fpga_vrhot_l;
    method vr_tf_vddx_to_fpga_vdda15_pg = _top.vr_tf_vddx_to_fpga_vdda15_pg;
    method fpga_to_vr_tf_vdda1p8_en = _top.fpga_to_vr_tf_vdda1p8_en;
    method vr_tf_v1p8_to_fpga_vdda1p8_pg = _top.vr_tf_v1p8_to_fpga_vdda1p8_pg;

    method tf_to_fpga_temp_therm_l = _top.tf_to_fpga_temp_therm_l;

    method i2c_fpga_to_tf_scl = _top.i2c_fpga_to_tf_scl;
    method i2c_fpga_to_tf_sda = _top.i2c_fpga_to_tf_sda;

    method pcie_fpga_to_host_prsnt_l = _top.pcie_fpga_to_host_prsnt_l;
    method pcie_fpga_to_host_pwrflt = _top.pcie_fpga_to_host_pwrflt;
    method pcie_host_to_fpga_perst = _top.pcie_host_to_fpga_perst;

    method fpga_to_smu_reset_l = _top.fpga_to_smu_reset_l;
    method fpga_to_ldo_smu_en = _top.fpga_to_ldo_smu_en;
    method ldo_to_fpga_smu_pg = _top.ldo_to_fpga_smu_pg;
    method fpga_to_smu_tf_clk_en_l = _top.fpga_to_smu_tf_clk_en_l;
    method fpga_to_smu_mgmt_clk_en_l = _top.fpga_to_smu_mgmt_clk_en_l;

    method fpga_to_mgmt_reset_l = _top.fpga_to_mgmt_reset_l;
    method fpga_to_vr_v1p0_mgmt_en = _top.fpga_to_vr_v1p0_mgmt_en;
    method vr_v1p0_mgmt_to_fpga_pg = _top.vr_v1p0_mgmt_to_fpga_pg;
    method fpga_to_ldo_v1p2_mgmt_en = _top.fpga_to_ldo_v1p2_mgmt_en;
    method ldo_to_fpga_v1p2_mgmt_pg = _top.ldo_to_fpga_v1p2_mgmt_pg;
    method fpga_to_ldo_v2p5_mgmt_en = _top.fpga_to_ldo_v2p5_mgmt_en;
    method ldo_to_fpga_v2p5_mgmt_pg = _top.ldo_to_fpga_v2p5_mgmt_pg;
    method mgmt_to_fpga_temp_therm_l = _top.mgmt_to_fpga_temp_therm_l;

    method fpga_to_fan0_hsc_en = _top.fpga_to_fan0_hsc_en;
    method fan0_hsc_to_fpga_pg = _top.fan0_hsc_to_fpga_pg;
    method fpga_to_fan0_led_l = _top.fpga_to_fan0_led_l;

    method fpga_to_fan1_hsc_en = _top.fpga_to_fan1_hsc_en;
    method fan1_hsc_to_fpga_pg = _top.fan1_hsc_to_fpga_pg;
    method fpga_to_fan1_led_l = _top.fpga_to_fan1_led_l;

    method fpga_to_fan2_hsc_en = _top.fpga_to_fan2_hsc_en;
    method fan2_hsc_to_fpga_pg = _top.fan2_hsc_to_fpga_pg;
    method fpga_to_fan2_led_l = _top.fpga_to_fan2_led_l;

    method fpga_to_fan3_hsc_en = _top.fpga_to_fan3_hsc_en;
    method fan3_hsc_to_fpga_pg = _top.fan3_hsc_to_fpga_pg;
    method fpga_to_fan3_led_l = _top.fpga_to_fan3_led_l;

    method fpga_to_front_io_hsc_en = _top.fpga_to_front_io_hsc_en;
    method front_io_hsc_to_fpga_pg = _top.front_io_hsc_to_fpga_pg;
endmodule

endpackage
