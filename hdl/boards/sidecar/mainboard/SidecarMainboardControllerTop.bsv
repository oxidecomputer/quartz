package SidecarMainboardControllerTop;

export SidecarMainboardControllerTop(..);
export SidecarMainboardControllerTopRevB(..);
export mkSidecarMainboardControllerTop;
export mkSidecarMainboardControllerTopRevB;

import BuildVector::*;
import Clocks::*;
import ConfigReg::*;
import Connectable::*;
import GetPut::*;
import TriState::*;
import Vector::*;

import Bidirection::*;
import BitSampling::*;
import IOSync::*;
import SerialIO::*;
import SPI::*;
import Strobe::*;

import IgnitionController::*;
import IgnitionTransceiver::*;
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

    //
    // PHY4 (Management Network, QSGMII to 4x SGMII port expander)
    //

    method Bool fpga_to_ldo_phy4_en();
    (* prefix = "" *) method Action ldo_to_fpga_v1p0_phy4_pg(Bool ldo_to_fpga_v1p0_phy4_pg);
    (* prefix = "" *) method Action ldo_to_fpga_v2p5_phy4_pg(Bool ldo_to_fpga_v2p5_phy4_pg);

    method Bool fpga_to_phy4_reset_l();

    //
    // Fans
    //

    method Bool fpga_to_fan0_hsc_en();
    (* prefix = "" *) method Action fan0_hsc_to_fpga_pg(Bool fan0_hsc_to_fpga_pg);
    method Bool fpga_to_fan0_led_l();
    (* prefix = "" *) method Action fan0_to_fpga_present(Bool fan0_to_fpga_present);

    method Bool fpga_to_fan1_hsc_en();
    (* prefix = "" *) method Action fan1_hsc_to_fpga_pg(Bool fan1_hsc_to_fpga_pg);
    method Bool fpga_to_fan1_led_l();
    (* prefix = "" *) method Action fan1_to_fpga_present(Bool fan1_to_fpga_present);

    method Bool fpga_to_fan2_hsc_en();
    (* prefix = "" *) method Action fan2_hsc_to_fpga_pg(Bool fan2_hsc_to_fpga_pg);
    method Bool fpga_to_fan2_led_l();
    (* prefix = "" *) method Action fan2_to_fpga_present(Bool fan2_to_fpga_present);

    method Bool fpga_to_fan3_hsc_en();
    (* prefix = "" *) method Action fan3_hsc_to_fpga_pg(Bool fan3_hsc_to_fpga_pg);
    method Bool fpga_to_fan3_led_l();
    (* prefix = "" *) method Action fan3_to_fpga_present(Bool fan3_to_fpga_present);

    //
    // Front IO
    //

    method Bool fpga_to_front_io_hsc_en();
    (* prefix = "" *) method Action front_io_hsc_to_fpga_pg(Bool front_io_hsc_to_fpga_pg);

    //
    // Ignition
    //

    (* prefix = "" *) method Action s0_rsw_aux_p(Bit#(1) s0_rsw_aux_p);
    interface Inout#(Bit#(1)) rsw_s0_aux_dc_p;

    (* prefix = "" *) method Action s1_rsw_aux_p(Bit#(1) s1_rsw_aux_p);
    interface Inout#(Bit#(1)) rsw_s1_aux_dc_p;

    (* prefix = "" *) method Action s2_rsw_aux_p(Bit#(1) s2_rsw_aux_p);
    interface Inout#(Bit#(1)) rsw_s2_aux_dc_p;

    (* prefix = "" *) method Action s3_rsw_aux_p(Bit#(1) s3_rsw_aux_p);
    interface Inout#(Bit#(1)) rsw_s3_aux_dc_p;

    (* prefix = "" *) method Action s4_rsw_aux_p(Bit#(1) s4_rsw_aux_p);
    interface Inout#(Bit#(1)) rsw_s4_aux_dc_p;

    (* prefix = "" *) method Action s5_rsw_aux_p(Bit#(1) s5_rsw_aux_p);
    interface Inout#(Bit#(1)) rsw_s5_aux_dc_p;

    (* prefix = "" *) method Action s6_rsw_aux_p(Bit#(1) s6_rsw_aux_p);
    interface Inout#(Bit#(1)) rsw_s6_aux_dc_p;

    (* prefix = "" *) method Action s7_rsw_aux_p(Bit#(1) s7_rsw_aux_p);
    interface Inout#(Bit#(1)) rsw_s7_aux_dc_p;

    (* prefix = "" *) method Action s8_rsw_aux_p(Bit#(1) s8_rsw_aux_p);
    interface Inout#(Bit#(1)) rsw_s8_aux_dc_p;

    (* prefix = "" *) method Action s9_rsw_aux_p(Bit#(1) s9_rsw_aux_p);
    interface Inout#(Bit#(1)) rsw_s9_aux_dc_p;

    (* prefix = "" *) method Action s10_rsw_aux_p(Bit#(1) s10_rsw_aux_p);
    interface Inout#(Bit#(1)) rsw_s10_aux_dc_p;

    (* prefix = "" *) method Action s11_rsw_aux_p(Bit#(1) s11_rsw_aux_p);
    interface Inout#(Bit#(1)) rsw_s11_aux_dc_p;

    (* prefix = "" *) method Action s12_rsw_aux_p(Bit#(1) s12_rsw_aux_p);
    interface Inout#(Bit#(1)) rsw_s12_aux_dc_p;

    (* prefix = "" *) method Action s13_rsw_aux_p(Bit#(1) s13_rsw_aux_p);
    interface Inout#(Bit#(1)) rsw_s13_aux_dc_p;

    (* prefix = "" *) method Action s14_rsw_aux_p(Bit#(1) s14_rsw_aux_p);
    interface Inout#(Bit#(1)) rsw_s14_aux_dc_p;

    (* prefix = "" *) method Action s15_rsw_aux_p(Bit#(1) s15_rsw_aux_p);
    interface Inout#(Bit#(1)) rsw_s15_aux_dc_p;

    (* prefix = "" *) method Action s16_rsw_aux_p(Bit#(1) s16_rsw_aux_p);
    interface Inout#(Bit#(1)) rsw_s16_aux_dc_p;

    (* prefix = "" *) method Action s17_rsw_aux_p(Bit#(1) s17_rsw_aux_p);
    interface Inout#(Bit#(1)) rsw_s17_aux_dc_p;

    (* prefix = "" *) method Action s18_rsw_aux_p(Bit#(1) s18_rsw_aux_p);
    interface Inout#(Bit#(1)) rsw_s18_aux_dc_p;

    (* prefix = "" *) method Action s19_rsw_aux_p(Bit#(1) s19_rsw_aux_p);
    interface Inout#(Bit#(1)) rsw_s19_aux_dc_p;

    (* prefix = "" *) method Action s20_rsw_aux_p(Bit#(1) s20_rsw_aux_p);
    interface Inout#(Bit#(1)) rsw_s20_aux_dc_p;

    (* prefix = "" *) method Action s21_rsw_aux_p(Bit#(1) s21_rsw_aux_p);
    interface Inout#(Bit#(1)) rsw_s21_aux_dc_p;

    (* prefix = "" *) method Action s22_rsw_aux_p(Bit#(1) s22_rsw_aux_p);
    interface Inout#(Bit#(1)) rsw_s22_aux_dc_p;

    (* prefix = "" *) method Action s23_rsw_aux_p(Bit#(1) s23_rsw_aux_p);
    interface Inout#(Bit#(1)) rsw_s23_aux_dc_p;

    (* prefix = "" *) method Action s24_rsw_aux_p(Bit#(1) s24_rsw_aux_p);
    interface Inout#(Bit#(1)) rsw_s24_aux_dc_p;

    (* prefix = "" *) method Action s25_rsw_aux_p(Bit#(1) s25_rsw_aux_p);
    interface Inout#(Bit#(1)) rsw_s25_aux_dc_p;

    (* prefix = "" *) method Action s26_rsw_aux_p(Bit#(1) s26_rsw_aux_p);
    interface Inout#(Bit#(1)) rsw_s26_aux_dc_p;

    (* prefix = "" *) method Action s27_rsw_aux_p(Bit#(1) s27_rsw_aux_p);
    interface Inout#(Bit#(1)) rsw_s27_aux_dc_p;

    (* prefix = "" *) method Action s28_rsw_aux_p(Bit#(1) s28_rsw_aux_p);
    interface Inout#(Bit#(1)) rsw_s28_aux_dc_p;

    (* prefix = "" *) method Action s29_rsw_aux_p(Bit#(1) s29_rsw_aux_p);
    interface Inout#(Bit#(1)) rsw_s29_aux_dc_p;

    (* prefix = "" *) method Action s30_rsw_aux_p(Bit#(1) s30_rsw_aux_p);
    interface Inout#(Bit#(1)) rsw_s30_aux_dc_p;

    (* prefix = "" *) method Action s31_rsw_aux_p(Bit#(1) s31_rsw_aux_p);
    interface Inout#(Bit#(1)) rsw_s31_aux_dc_p;

    (* prefix = "" *) method Action ignition_psc0_to_ctrl_p(Bit#(1) ignition_psc0_to_ctrl_p);
    interface Inout#(Bit#(1)) ignition_ctrl_to_psc0_dc_p;

    (* prefix = "" *) method Action ignition_psc1_to_ctrl_p(Bit#(1) ignition_psc1_to_ctrl_p);
    interface Inout#(Bit#(1)) ignition_ctrl_to_psc1_dc_p;

    (* prefix = "" *) method Action ignition_rsw_b_to_ctrl_p(Bit#(1) ignition_rsw_b_to_ctrl_p);
    interface Inout#(Bit#(1)) ignition_ctrl_to_rsw_b_dc_p;

    (* prefix = "" *) method Action ignition_target_to_self_p(Bit#(1) ignition_target_to_self_p);
    interface Inout#(Bit#(1)) ignition_ctrl_to_self_dc_p;
endinterface

// A convenience wrapper which
typedef SampledSerialIOTxInout#(5) IgnitionIO;

module mkIgnitionIOs #(
        Integer bank_id,
        Vector#(n, IgnitionController::Controller) controllers)
            (Vector#(n, IgnitionIO));
    // The modulo 5 causes the strobe instances for different banks to be offset
    // in phase. This avoids all transceivers switching at once and instead
    // spreads out the transmit activity.
    Strobe#(3) tx_strobe <- mkLimitStrobe(1, 5, fromInteger(bank_id % 5));

    function to_serial(txr) = txr.serial;

    Transceivers#(n) txrs <- mkTransceivers();
    Vector#(n, IgnitionIO) io <- zipWithM(
        mkSampledSerialIOWithTxStrobeInout(tx_strobe),
        map(tx_enabled, controllers),
        map(to_serial, txrs.txrs));

    mkFreeRunningStrobe(tx_strobe);
    zipWithM(mkConnection, map(transceiver_client, controllers), txrs.txrs);

    // Create a registered copy of the first Controller tick to help P&R.
    Reg#(Bool) watchdog_tick <- mkRegU();

    (* fire_when_enabled *)
    rule do_receiver_watchdog;
        watchdog_tick <= controllers[0].tick_1khz;
        if (watchdog_tick) txrs.tick_1khz();
    endrule

    return io;
endmodule

(* default_clock_osc = "clk_50m_fpga_refclk",
    default_reset="sp_to_fpga_design_reset_l" *)
module mkSidecarMainboardControllerTop
        (SidecarMainboardControllerTop)
            provisos (
                NumAlias#(36, n_ignition_controllers));
    // Synchronize the default reset to the default clock.
    Clock clk_50mhz <- exposeCurrentClock();
    Reset reset_sync <- mkAsyncResetFromCR(2, clk_50mhz);

    MainboardController#(n_ignition_controllers) controller <-
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
            register_pages(controller.ignition_controllers),
            controller.registers.fans,
            asIfc(controller.registers.front_io_hsc),
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
    Reg#(Bit#(1)) debug0 <- mkRegU();
    Reg#(Bit#(1)) debug1 <- mkRegU();

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

    ReadOnly#(Bool) fan0_en <- mkOutputSyncFor(controller.pins.fans[0].hsc.en);
    ReadOnly#(Bool) fan0_led <- mkOutputSyncFor(controller.pins.fans[0].led);
    InputReg#(Bool, 2) fan0_pg <- mkInputSyncFor(controller.pins.fans[0].hsc.pg);
    InputReg#(Bool, 2) fan0_present <- mkInputSyncFor(controller.pins.fans[0].present);

    ReadOnly#(Bool) fan1_en <- mkOutputSyncFor(controller.pins.fans[1].hsc.en);
    ReadOnly#(Bool) fan1_led <- mkOutputSyncFor(controller.pins.fans[1].led);
    InputReg#(Bool, 2) fan1_pg <- mkInputSyncFor(controller.pins.fans[1].hsc.pg);
    InputReg#(Bool, 2) fan1_present <- mkInputSyncFor(controller.pins.fans[1].present);

    ReadOnly#(Bool) fan2_en <- mkOutputSyncFor(controller.pins.fans[2].hsc.en);
    ReadOnly#(Bool) fan2_led <- mkOutputSyncFor(controller.pins.fans[2].led);
    InputReg#(Bool, 2) fan2_pg <- mkInputSyncFor(controller.pins.fans[2].hsc.pg);
    InputReg#(Bool, 2) fan2_present <- mkInputSyncFor(controller.pins.fans[2].present);

    ReadOnly#(Bool) fan3_en <- mkOutputSyncFor(controller.pins.fans[3].hsc.en);
    ReadOnly#(Bool) fan3_led <- mkOutputSyncFor(controller.pins.fans[3].led);
    InputReg#(Bool, 2) fan3_pg <- mkInputSyncFor(controller.pins.fans[3].hsc.pg);
    InputReg#(Bool, 2) fan3_present <- mkInputSyncFor(controller.pins.fans[3].present);

    //
    // Front IO
    //
    ReadOnly#(Bool) front_io_hsc_en <- mkOutputSyncFor(controller.pins.front_io_hsc.en);
    InputReg#(Bool, 2) front_io_hsc_pg <- mkInputSyncFor(controller.pins.front_io_hsc.pg);

    //
    // Ignition
    //
    //
    // Connect Transceivers to their Clients. This is done in a specific order
    // to maintain a logical channel order in the register interface. See
    // further down in this module how the transceiver channels map to device
    // pins.
    //
    // Cubbies
    //
    Vector#(8, IgnitionController::Controller)
        ignition_bank2 = vec(
            controller.ignition_controllers[15],
            controller.ignition_controllers[14],
            controller.ignition_controllers[13],
            controller.ignition_controllers[12],
            controller.ignition_controllers[11],
            controller.ignition_controllers[10],
            controller.ignition_controllers[9],
            controller.ignition_controllers[19]);
    Vector#(6, IgnitionController::Controller)
        ignition_bank3_0 = vec(
            controller.ignition_controllers[18],
            controller.ignition_controllers[17],
            controller.ignition_controllers[16],
            controller.ignition_controllers[8],
            controller.ignition_controllers[4],
            controller.ignition_controllers[7]);
    Vector#(6, IgnitionController::Controller)
        ignition_bank3_1 = vec(
            controller.ignition_controllers[1],
            controller.ignition_controllers[0],
            controller.ignition_controllers[6],
            controller.ignition_controllers[5],
            controller.ignition_controllers[3],
            controller.ignition_controllers[2]);
    Vector#(6, IgnitionController::Controller)
        ignition_bank6_0 = vec(
            controller.ignition_controllers[20],
            controller.ignition_controllers[21],
            controller.ignition_controllers[22],
            controller.ignition_controllers[23],
            controller.ignition_controllers[24],
            controller.ignition_controllers[25]);
    Vector#(6, IgnitionController::Controller)
        ignition_bank6_1 = vec(
            controller.ignition_controllers[30],
            controller.ignition_controllers[31],
            controller.ignition_controllers[27],
            controller.ignition_controllers[26],
            controller.ignition_controllers[28],
            controller.ignition_controllers[29]);
    //
    // PSC 0/1, Sidecar B, local Target
    //
    Vector#(4, IgnitionController::Controller)
        ignition_bank7 = vec(
            controller.ignition_controllers[32],
            controller.ignition_controllers[33],
            controller.ignition_controllers[34],
            controller.ignition_controllers[35]);

    // Allocate the Transceivers and IO adapters for the banks of Controllers.
    // The bank id passed to `mkIgnitionIOs(..)` is used to derive a TX strobe
    // with different phase offsets to reduce the effect of all transmitters
    // switching at the same time.
    Vector#(8, IgnitionIO) ignition_io_bank2 <-
        mkIgnitionIOs(0, ignition_bank2, reset_by reset_sync);
    Vector#(6, IgnitionIO) ignition_io_bank3_0 <-
        mkIgnitionIOs(1, ignition_bank3_0, reset_by reset_sync);
    Vector#(6, IgnitionIO) ignition_io_bank3_1 <-
        mkIgnitionIOs(2, ignition_bank3_1, reset_by reset_sync);
    Vector#(6, IgnitionIO) ignition_io_bank6_0 <-
        mkIgnitionIOs(3, ignition_bank6_0, reset_by reset_sync);
    Vector#(6, IgnitionIO) ignition_io_bank6_1 <-
        mkIgnitionIOs(4, ignition_bank6_1, reset_by reset_sync);
    Vector#(4, IgnitionIO) ignition_io_bank7 <-
        mkIgnitionIOs(5, ignition_bank7, reset_by reset_sync);

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

    // PHY4 pins
    method Bool fpga_to_ldo_phy4_en = True;

    method Action ldo_to_fpga_v1p0_phy4_pg(Bool _pg);
    endmethod

    method Action ldo_to_fpga_v2p5_phy4_pg(Bool _pg);
    endmethod

    method Bool fpga_to_phy4_reset_l = !vsc7448_reset;

    // Fan pins
    method fpga_to_fan0_hsc_en = fan0_en;
    method fan0_hsc_to_fpga_pg = sync(fan0_pg);
    method fpga_to_fan0_led_l = fan0_led; // Not active low on Fan VPD.
    method fan0_to_fpga_present = sync(fan0_present);

    method fpga_to_fan1_hsc_en = fan1_en;
    method fan1_hsc_to_fpga_pg = sync(fan1_pg);
    method fpga_to_fan1_led_l = fan1_led; // Not active low on Fan VPD.
    method fan1_to_fpga_present = sync(fan1_present);

    method fpga_to_fan2_hsc_en = fan2_en;
    method fan2_hsc_to_fpga_pg = sync(fan2_pg);
    method fpga_to_fan2_led_l = fan2_led; // Not active low on Fan VPD.
    method fan2_to_fpga_present = sync(fan2_present);

    method fpga_to_fan3_hsc_en = fan3_en;
    method fan3_hsc_to_fpga_pg = sync(fan3_pg);
    method fpga_to_fan3_led_l = fan3_led; // Not active low on Fan VPD.
    method fan3_to_fpga_present = sync(fan3_present);

    // Front IO
    method fpga_to_front_io_hsc_en = front_io_hsc_en;
    method front_io_hsc_to_fpga_pg = sync(front_io_hsc_pg);

    // Ignition
    //
    // Groups of Ignition SerDes pins are mapped on specific Transceivers in
    // order to try and reduce routing latency and placement pressure. IO tiles
    // in the ECP5 family seem to be placed in a single row at the north side of
    // the die and linear distance is used as a proxy to bundle the IO pins.
    //
    // Please do not change the grouping/assignment order unless data shows that
    // the change improves placement of the design.
    //
    //
    // Bank 7
    //
    // pin 'ignition_psc0_to_ctrl_p$tr_io' constrained to Bel 'X0/Y11/PIOC'.
    // pin 'ignition_psc1_to_ctrl_p$tr_io' constrained to Bel 'X0/Y14/PIOC'.
    // pin 'ignition_rsw_b_to_ctrl_p$tr_io' constrained to Bel 'X0/Y17/PIOC'.
    // pin 'ignition_target_to_self_p$tr_io' constrained to Bel 'X0/Y32/PIOC'.
    //
    method ignition_psc0_to_ctrl_p = ignition_io_bank7[0].rx;
    method ignition_ctrl_to_psc0_dc_p = ignition_io_bank7[0].tx;

    method ignition_psc1_to_ctrl_p = ignition_io_bank7[1].rx;
    method ignition_ctrl_to_psc1_dc_p = ignition_io_bank7[1].tx;

    method ignition_rsw_b_to_ctrl_p = ignition_io_bank7[2].rx;
    method ignition_ctrl_to_rsw_b_dc_p = ignition_io_bank7[2].tx;

    method ignition_target_to_self_p = ignition_io_bank7[3].rx;
    method ignition_ctrl_to_self_dc_p = ignition_io_bank7[3].tx;

    //
    // Bank 6
    //
    // pin 's20_rsw_aux_p$tr_io' constrained to Bel 'X0/Y35/PIOC'.
    // pin 's21_rsw_aux_p$tr_io' constrained to Bel 'X0/Y38/PIOC'.
    // pin 's22_rsw_aux_p$tr_io' constrained to Bel 'X0/Y41/PIOC'.
    // pin 's23_rsw_aux_p$tr_io' constrained to Bel 'X0/Y44/PIOC'.
    // pin 's24_rsw_aux_p$tr_io' constrained to Bel 'X0/Y47/PIOC'.
    // pin 's25_rsw_aux_p$tr_io' constrained to Bel 'X0/Y50/PIOC'.
    //
    method s20_rsw_aux_p = ignition_io_bank6_0[0].rx;
    method rsw_s20_aux_dc_p = ignition_io_bank6_0[0].tx;

    method s21_rsw_aux_p = ignition_io_bank6_0[1].rx;
    method rsw_s21_aux_dc_p = ignition_io_bank6_0[1].tx;

    method s22_rsw_aux_p = ignition_io_bank6_0[2].rx;
    method rsw_s22_aux_dc_p = ignition_io_bank6_0[2].tx;

    method s23_rsw_aux_p = ignition_io_bank6_0[3].rx;
    method rsw_s23_aux_dc_p = ignition_io_bank6_0[3].tx;

    method s24_rsw_aux_p = ignition_io_bank6_0[4].rx;
    method rsw_s24_aux_dc_p = ignition_io_bank6_0[4].tx;

    method s25_rsw_aux_p = ignition_io_bank6_0[5].rx;
    method rsw_s25_aux_dc_p = ignition_io_bank6_0[5].tx;

    //
    // pin 's30_rsw_aux_p$tr_io' constrained to Bel 'X0/Y53/PIOC'.
    // pin 's31_rsw_aux_p$tr_io' constrained to Bel 'X0/Y56/PIOC'.
    // pin 's27_rsw_aux_p$tr_io' constrained to Bel 'X0/Y59/PIOC'.
    // pin 's26_rsw_aux_p$tr_io' constrained to Bel 'X0/Y62/PIOC'.
    // pin 's28_rsw_aux_p$tr_io' constrained to Bel 'X0/Y65/PIOC'.
    // pin 's29_rsw_aux_p$tr_io' constrained to Bel 'X0/Y68/PIOC'.
    //
    method s30_rsw_aux_p = ignition_io_bank6_1[0].rx;
    method rsw_s30_aux_dc_p = ignition_io_bank6_1[0].tx;

    method s31_rsw_aux_p = ignition_io_bank6_1[1].rx;
    method rsw_s31_aux_dc_p = ignition_io_bank6_1[1].tx;

    method s27_rsw_aux_p = ignition_io_bank6_1[2].rx;
    method rsw_s27_aux_dc_p = ignition_io_bank6_1[2].tx;

    method s26_rsw_aux_p = ignition_io_bank6_1[3].rx;
    method rsw_s26_aux_dc_p = ignition_io_bank6_1[3].tx;

    method s28_rsw_aux_p = ignition_io_bank6_1[4].rx;
    method rsw_s28_aux_dc_p = ignition_io_bank6_1[4].tx;

    method s29_rsw_aux_p = ignition_io_bank6_1[5].rx;
    method rsw_s29_aux_dc_p = ignition_io_bank6_1[5].tx;

    //
    // Bank 2
    //
    // pin 's15_rsw_aux_p$tr_io' constrained to Bel 'X90/Y11/PIOC'.
    // pin 's14_rsw_aux_p$tr_io' constrained to Bel 'X90/Y14/PIOC'.
    // pin 's13_rsw_aux_p$tr_io' constrained to Bel 'X90/Y17/PIOC'.
    // pin 's12_rsw_aux_p$tr_io' constrained to Bel 'X90/Y20/PIOC'.
    // pin 's11_rsw_aux_p$tr_io' constrained to Bel 'X90/Y23/PIOC'.
    // pin 's10_rsw_aux_p$tr_io' constrained to Bel 'X90/Y26/PIOC'.
    // pin 's9_rsw_aux_p$tr_io' constrained to Bel 'X90/Y29/PIOC'.
    // pin 's19_rsw_aux_p$tr_io' constrained to Bel 'X90/Y32/PIOC'.
    //
    method s15_rsw_aux_p = ignition_io_bank2[0].rx;
    method rsw_s15_aux_dc_p = ignition_io_bank2[0].tx;

    method s14_rsw_aux_p = ignition_io_bank2[1].rx;
    method rsw_s14_aux_dc_p = ignition_io_bank2[1].tx;

    method s13_rsw_aux_p = ignition_io_bank2[2].rx;
    method rsw_s13_aux_dc_p = ignition_io_bank2[2].tx;

    method s12_rsw_aux_p = ignition_io_bank2[3].rx;
    method rsw_s12_aux_dc_p = ignition_io_bank2[3].tx;

    method s11_rsw_aux_p = ignition_io_bank2[4].rx;
    method rsw_s11_aux_dc_p = ignition_io_bank2[4].tx;

    method s10_rsw_aux_p = ignition_io_bank2[5].rx;
    method rsw_s10_aux_dc_p = ignition_io_bank2[5].tx;

    method s9_rsw_aux_p = ignition_io_bank2[6].rx;
    method rsw_s9_aux_dc_p = ignition_io_bank2[6].tx;

    method s19_rsw_aux_p = ignition_io_bank2[7].rx;
    method rsw_s19_aux_dc_p = ignition_io_bank2[7].tx;

    //
    // Bank 3
    //
    // pin 's18_rsw_aux_p$tr_io' constrained to Bel 'X90/Y35/PIOC'.
    // pin 's17_rsw_aux_p$tr_io' constrained to Bel 'X90/Y38/PIOC'.
    // pin 's16_rsw_aux_p$tr_io' constrained to Bel 'X90/Y41/PIOC'.
    // pin 's8_rsw_aux_p$tr_io' constrained to Bel 'X90/Y44/PIOC'.
    // pin 's4_rsw_aux_p$tr_io' constrained to Bel 'X90/Y47/PIOC'.
    // pin 's7_rsw_aux_p$tr_io' constrained to Bel 'X90/Y50/PIOC'.
    //
    method s18_rsw_aux_p = ignition_io_bank3_0[0].rx;
    method rsw_s18_aux_dc_p = ignition_io_bank3_0[0].tx;

    method s17_rsw_aux_p = ignition_io_bank3_0[1].rx;
    method rsw_s17_aux_dc_p = ignition_io_bank3_0[1].tx;

    method s16_rsw_aux_p = ignition_io_bank3_0[2].rx;
    method rsw_s16_aux_dc_p = ignition_io_bank3_0[2].tx;

    method s8_rsw_aux_p = ignition_io_bank3_0[3].rx;
    method rsw_s8_aux_dc_p = ignition_io_bank3_0[3].tx;

    method s4_rsw_aux_p = ignition_io_bank3_0[4].rx;
    method rsw_s4_aux_dc_p = ignition_io_bank3_0[4].tx;

    method s7_rsw_aux_p = ignition_io_bank3_0[5].rx;
    method rsw_s7_aux_dc_p = ignition_io_bank3_0[5].tx;

    //
    // pin 's1_rsw_aux_p$tr_io' constrained to Bel 'X90/Y53/PIOC'.
    // pin 's0_rsw_aux_p$tr_io' constrained to Bel 'X90/Y56/PIOC'.
    // pin 's6_rsw_aux_p$tr_io' constrained to Bel 'X90/Y59/PIOC'.
    // pin 's5_rsw_aux_p$tr_io' constrained to Bel 'X90/Y62/PIOC'.
    // pin 's3_rsw_aux_p$tr_io' constrained to Bel 'X90/Y65/PIOC'.
    // pin 's2_rsw_aux_p$tr_io' constrained to Bel 'X90/Y68/PIOC'.
    //
    method s1_rsw_aux_p = ignition_io_bank3_1[0].rx;
    method rsw_s1_aux_dc_p = ignition_io_bank3_1[0].tx;

    method s0_rsw_aux_p = ignition_io_bank3_1[1].rx;
    method rsw_s0_aux_dc_p = ignition_io_bank3_1[1].tx;

    method s6_rsw_aux_p = ignition_io_bank3_1[2].rx;
    method rsw_s6_aux_dc_p = ignition_io_bank3_1[2].tx;

    method s5_rsw_aux_p = ignition_io_bank3_1[3].rx;
    method rsw_s5_aux_dc_p = ignition_io_bank3_1[3].tx;

    method s3_rsw_aux_p = ignition_io_bank3_1[4].rx;
    method rsw_s3_aux_dc_p = ignition_io_bank3_1[4].tx;

    method s2_rsw_aux_p = ignition_io_bank3_1[5].rx;
    method rsw_s2_aux_dc_p = ignition_io_bank3_1[5].tx;
endmodule

//
// Rev C and beyond reuse several pins which were tied to I2C interfaces in rev
// B (see for example `I2C_FPGA_TO_TF_SDA_O_R` in the rev B schematic) for power
// control of PHY4.
//
// This is a modified top which omits the Ignition link to the local Target on
// the board, and those PHY4 power control pins in order to not break the I2C
// links.
//

(* always_enabled *)
interface SidecarMainboardControllerTopRevB;
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
    (* prefix = "" *) method Action fan0_to_fpga_present(Bool fan0_to_fpga_present);

    method Bool fpga_to_fan1_hsc_en();
    (* prefix = "" *) method Action fan1_hsc_to_fpga_pg(Bool fan1_hsc_to_fpga_pg);
    method Bool fpga_to_fan1_led_l();
    (* prefix = "" *) method Action fan1_to_fpga_present(Bool fan1_to_fpga_present);

    method Bool fpga_to_fan2_hsc_en();
    (* prefix = "" *) method Action fan2_hsc_to_fpga_pg(Bool fan2_hsc_to_fpga_pg);
    method Bool fpga_to_fan2_led_l();
    (* prefix = "" *) method Action fan2_to_fpga_present(Bool fan2_to_fpga_present);

    method Bool fpga_to_fan3_hsc_en();
    (* prefix = "" *) method Action fan3_hsc_to_fpga_pg(Bool fan3_hsc_to_fpga_pg);
    method Bool fpga_to_fan3_led_l();
    (* prefix = "" *) method Action fan3_to_fpga_present(Bool fan3_to_fpga_present);

    //
    // Front IO
    //

    method Bool fpga_to_front_io_hsc_en();
    (* prefix = "" *) method Action front_io_hsc_to_fpga_pg(Bool front_io_hsc_to_fpga_pg);

    //
    // Ignition
    //

    (* prefix = "" *) method Action s0_rsw_aux_p(Bit#(1) s0_rsw_aux_p);
    interface Inout#(Bit#(1)) rsw_s0_aux_dc_p;

    (* prefix = "" *) method Action s1_rsw_aux_p(Bit#(1) s1_rsw_aux_p);
    interface Inout#(Bit#(1)) rsw_s1_aux_dc_p;

    (* prefix = "" *) method Action s2_rsw_aux_p(Bit#(1) s2_rsw_aux_p);
    interface Inout#(Bit#(1)) rsw_s2_aux_dc_p;

    (* prefix = "" *) method Action s3_rsw_aux_p(Bit#(1) s3_rsw_aux_p);
    interface Inout#(Bit#(1)) rsw_s3_aux_dc_p;

    (* prefix = "" *) method Action s4_rsw_aux_p(Bit#(1) s4_rsw_aux_p);
    interface Inout#(Bit#(1)) rsw_s4_aux_dc_p;

    (* prefix = "" *) method Action s5_rsw_aux_p(Bit#(1) s5_rsw_aux_p);
    interface Inout#(Bit#(1)) rsw_s5_aux_dc_p;

    (* prefix = "" *) method Action s6_rsw_aux_p(Bit#(1) s6_rsw_aux_p);
    interface Inout#(Bit#(1)) rsw_s6_aux_dc_p;

    (* prefix = "" *) method Action s7_rsw_aux_p(Bit#(1) s7_rsw_aux_p);
    interface Inout#(Bit#(1)) rsw_s7_aux_dc_p;

    (* prefix = "" *) method Action s8_rsw_aux_p(Bit#(1) s8_rsw_aux_p);
    interface Inout#(Bit#(1)) rsw_s8_aux_dc_p;

    (* prefix = "" *) method Action s9_rsw_aux_p(Bit#(1) s9_rsw_aux_p);
    interface Inout#(Bit#(1)) rsw_s9_aux_dc_p;

    (* prefix = "" *) method Action s10_rsw_aux_p(Bit#(1) s10_rsw_aux_p);
    interface Inout#(Bit#(1)) rsw_s10_aux_dc_p;

    (* prefix = "" *) method Action s11_rsw_aux_p(Bit#(1) s11_rsw_aux_p);
    interface Inout#(Bit#(1)) rsw_s11_aux_dc_p;

    (* prefix = "" *) method Action s12_rsw_aux_p(Bit#(1) s12_rsw_aux_p);
    interface Inout#(Bit#(1)) rsw_s12_aux_dc_p;

    (* prefix = "" *) method Action s13_rsw_aux_p(Bit#(1) s13_rsw_aux_p);
    interface Inout#(Bit#(1)) rsw_s13_aux_dc_p;

    (* prefix = "" *) method Action s14_rsw_aux_p(Bit#(1) s14_rsw_aux_p);
    interface Inout#(Bit#(1)) rsw_s14_aux_dc_p;

    (* prefix = "" *) method Action s15_rsw_aux_p(Bit#(1) s15_rsw_aux_p);
    interface Inout#(Bit#(1)) rsw_s15_aux_dc_p;

    (* prefix = "" *) method Action s16_rsw_aux_p(Bit#(1) s16_rsw_aux_p);
    interface Inout#(Bit#(1)) rsw_s16_aux_dc_p;

    (* prefix = "" *) method Action s17_rsw_aux_p(Bit#(1) s17_rsw_aux_p);
    interface Inout#(Bit#(1)) rsw_s17_aux_dc_p;

    (* prefix = "" *) method Action s18_rsw_aux_p(Bit#(1) s18_rsw_aux_p);
    interface Inout#(Bit#(1)) rsw_s18_aux_dc_p;

    (* prefix = "" *) method Action s19_rsw_aux_p(Bit#(1) s19_rsw_aux_p);
    interface Inout#(Bit#(1)) rsw_s19_aux_dc_p;

    (* prefix = "" *) method Action s20_rsw_aux_p(Bit#(1) s20_rsw_aux_p);
    interface Inout#(Bit#(1)) rsw_s20_aux_dc_p;

    (* prefix = "" *) method Action s21_rsw_aux_p(Bit#(1) s21_rsw_aux_p);
    interface Inout#(Bit#(1)) rsw_s21_aux_dc_p;

    (* prefix = "" *) method Action s22_rsw_aux_p(Bit#(1) s22_rsw_aux_p);
    interface Inout#(Bit#(1)) rsw_s22_aux_dc_p;

    (* prefix = "" *) method Action s23_rsw_aux_p(Bit#(1) s23_rsw_aux_p);
    interface Inout#(Bit#(1)) rsw_s23_aux_dc_p;

    (* prefix = "" *) method Action s24_rsw_aux_p(Bit#(1) s24_rsw_aux_p);
    interface Inout#(Bit#(1)) rsw_s24_aux_dc_p;

    (* prefix = "" *) method Action s25_rsw_aux_p(Bit#(1) s25_rsw_aux_p);
    interface Inout#(Bit#(1)) rsw_s25_aux_dc_p;

    (* prefix = "" *) method Action s26_rsw_aux_p(Bit#(1) s26_rsw_aux_p);
    interface Inout#(Bit#(1)) rsw_s26_aux_dc_p;

    (* prefix = "" *) method Action s27_rsw_aux_p(Bit#(1) s27_rsw_aux_p);
    interface Inout#(Bit#(1)) rsw_s27_aux_dc_p;

    (* prefix = "" *) method Action s28_rsw_aux_p(Bit#(1) s28_rsw_aux_p);
    interface Inout#(Bit#(1)) rsw_s28_aux_dc_p;

    (* prefix = "" *) method Action s29_rsw_aux_p(Bit#(1) s29_rsw_aux_p);
    interface Inout#(Bit#(1)) rsw_s29_aux_dc_p;

    (* prefix = "" *) method Action s30_rsw_aux_p(Bit#(1) s30_rsw_aux_p);
    interface Inout#(Bit#(1)) rsw_s30_aux_dc_p;

    (* prefix = "" *) method Action s31_rsw_aux_p(Bit#(1) s31_rsw_aux_p);
    interface Inout#(Bit#(1)) rsw_s31_aux_dc_p;

    (* prefix = "" *) method Action ignition_psc0_to_ctrl_p(Bit#(1) ignition_psc0_to_ctrl_p);
    interface Inout#(Bit#(1)) ignition_ctrl_to_psc0_dc_p;

    (* prefix = "" *) method Action ignition_psc1_to_ctrl_p(Bit#(1) ignition_psc1_to_ctrl_p);
    interface Inout#(Bit#(1)) ignition_ctrl_to_psc1_dc_p;

    (* prefix = "" *) method Action ignition_rsw_b_to_ctrl_p(Bit#(1) ignition_rsw_b_to_ctrl_p);
    interface Inout#(Bit#(1)) ignition_ctrl_to_rsw_b_dc_p;
endinterface

(* default_clock_osc = "clk_50m_fpga_refclk",
    default_reset="sp_to_fpga_design_reset_l" *)
module mkSidecarMainboardControllerTopRevB (SidecarMainboardControllerTopRevB);
    (* hide *) SidecarMainboardControllerTop _top <- mkSidecarMainboardControllerTop();

    (* fire_when_enabled *)
    rule do_set_phy4_ldo_pg;
        _top.ldo_to_fpga_v1p0_phy4_pg(False);
        _top.ldo_to_fpga_v2p5_phy4_pg(False);
    endrule

    //
    // SPI peripheral
    //

    method spi_sp_to_fpga_cs1_l = _top.spi_sp_to_fpga_cs1_l;
    method spi_sp_to_fpga_sck = _top.spi_sp_to_fpga_sck;
    method spi_sp_to_fpga_mosi = _top.spi_sp_to_fpga_mosi;
    method spi_sp_to_fpga_miso_r = _top.spi_sp_to_fpga_miso_r;

    //
    // Debug
    //

    method fpga_led0 = _top.fpga_led0;
    method fpga_debug0 = _top.fpga_debug0;
    method fpga_debug1 = _top.fpga_debug1;

    //
    // Tofino
    //

    method fpga_to_tf_core_rst_l = _top.fpga_to_tf_core_rst_l;
    method fpga_to_tf_pwron_rst_l = _top.fpga_to_tf_pwron_rst_l;
    method fpga_to_tf_pcie_rst_l = _top.fpga_to_tf_pcie_rst_l;
    method tf_to_fpga_vid = _top.tf_to_fpga_vid;

    // Test (currently unused)
    method fpga_to_tf_test_core_tap_l = _top.fpga_to_tf_test_core_tap_l;
    method fpga_to_tf_test_jtsel = _top.fpga_to_tf_test_jtsel;

    //
    // Tofino PDN
    //

    // V1P8
    method fpga_to_vr_tf_vdd1p8_en = _top.fpga_to_vr_tf_vdd1p8_en;
    method vr_tf_v1p8_to_fpga_vdd1p8_pg = _top.vr_tf_v1p8_to_fpga_vdd1p8_pg;
    method vr_tf_v1p8_to_fpga_fault = _top.vr_tf_v1p8_to_fpga_fault;
    method vr_tf_v1p8_to_fpga_vr_hot_l = _top.vr_tf_v1p8_to_fpga_vr_hot_l;

    // VDDCORE
    method fpga_to_vr_tf_vddcore_en = _top.fpga_to_vr_tf_vddcore_en;
    method vr_tf_vddcore_to_fpga_pg = _top.vr_tf_vddcore_to_fpga_pg;
    method vr_tf_vddcore_to_fpga_fault = _top.vr_tf_vddcore_to_fpga_fault;
    method vr_tf_vddcore_to_fpga_vrhot_l = _top.vr_tf_vddcore_to_fpga_vrhot_l;

    // VDDPCIE
    method fpga_to_ldo_v0p75_tf_pcie_en = _top.fpga_to_ldo_v0p75_tf_pcie_en;
    method ldo_to_fpga_v0p75_tf_pcie_pg = _top.ldo_to_fpga_v0p75_tf_pcie_pg;

    // VDDt
    method fpga_to_vr_tf_vddx_en = _top.fpga_to_vr_tf_vddx_en;
    method vr_tf_vddx_to_fpga_vddt_pg = _top.vr_tf_vddx_to_fpga_vddt_pg;
    method vr_tf_vddx_to_fpga_fault = _top.vr_tf_vddx_to_fpga_fault;
    method vr_tf_vddx_to_fpga_vrhot_l = _top.vr_tf_vddx_to_fpga_vrhot_l;

    // VDDA1P5
    method vr_tf_vddx_to_fpga_vdda15_pg = _top.vr_tf_vddx_to_fpga_vdda15_pg;

    // VDDA1P8
    method fpga_to_vr_tf_vdda1p8_en = _top.fpga_to_vr_tf_vdda1p8_en;
    method vr_tf_v1p8_to_fpga_vdda1p8_pg = _top.vr_tf_v1p8_to_fpga_vdda1p8_pg;

    // Power Indicator
    method tf_pg_led = _top.tf_pg_led;

    // Thermal Alert
    method tf_to_fpga_temp_therm_l = _top.tf_to_fpga_temp_therm_l;

    //
    // Tofino Debug Port
    //

    interface Inout i2c_fpga_to_tf_scl = _top.i2c_fpga_to_tf_scl;
    interface Inout i2c_fpga_to_tf_sda = _top.i2c_fpga_to_tf_sda;

    //
    // PCIe Endpoint
    //

    method pcie_fpga_to_host_prsnt_l = _top.pcie_fpga_to_host_prsnt_l;
    method pcie_fpga_to_host_pwrflt = _top.pcie_fpga_to_host_pwrflt;
    method pcie_host_to_fpga_perst = _top.pcie_host_to_fpga_perst;

    //
    // Clock Management
    //

    method fpga_to_smu_reset_l = _top.fpga_to_smu_reset_l;
    method fpga_to_ldo_smu_en = _top.fpga_to_ldo_smu_en;
    method ldo_to_fpga_smu_pg = _top.ldo_to_fpga_smu_pg;

    method fpga_to_smu_tf_clk_en_l = _top.fpga_to_smu_tf_clk_en_l;
    method fpga_to_smu_mgmt_clk_en_l = _top.fpga_to_smu_mgmt_clk_en_l;

    //
    // VSC7448 (Management Network)
    //

    method fpga_to_mgmt_reset_l = _top.fpga_to_mgmt_reset_l;

    // 1.0V regulator
    method fpga_to_vr_v1p0_mgmt_en = _top.fpga_to_vr_v1p0_mgmt_en;
    method vr_v1p0_mgmt_to_fpga_pg = _top.vr_v1p0_mgmt_to_fpga_pg;

    // 1.2V/2.5V LDOs
    method fpga_to_ldo_v1p2_mgmt_en = _top.fpga_to_ldo_v1p2_mgmt_en;
    method ldo_to_fpga_v1p2_mgmt_pg = _top.ldo_to_fpga_v1p2_mgmt_pg;

    method fpga_to_ldo_v2p5_mgmt_en = _top.fpga_to_ldo_v2p5_mgmt_en;
    method ldo_to_fpga_v2p5_mgmt_pg = _top.ldo_to_fpga_v2p5_mgmt_pg;

    // Thermal Alert
    method mgmt_to_fpga_temp_therm_l = _top.mgmt_to_fpga_temp_therm_l;

    method fpga_to_phy4_reset_l = _top.fpga_to_phy4_reset_l;

    //
    // Fans
    //

    method fpga_to_fan0_hsc_en = _top.fpga_to_fan0_hsc_en;
    method fan0_hsc_to_fpga_pg = _top.fan0_hsc_to_fpga_pg;
    method fpga_to_fan0_led_l = _top.fpga_to_fan0_led_l;
    method fan0_to_fpga_present = _top.fan0_to_fpga_present;

    method fpga_to_fan1_hsc_en = _top.fpga_to_fan1_hsc_en;
    method fan1_hsc_to_fpga_pg = _top.fan1_hsc_to_fpga_pg;
    method fpga_to_fan1_led_l = _top.fpga_to_fan1_led_l;
    method fan1_to_fpga_present = _top.fan1_to_fpga_present;

    method fpga_to_fan2_hsc_en = _top.fpga_to_fan2_hsc_en;
    method fan2_hsc_to_fpga_pg = _top.fan2_hsc_to_fpga_pg;
    method fpga_to_fan2_led_l = _top.fpga_to_fan2_led_l;
    method fan2_to_fpga_present = _top.fan2_to_fpga_present;

    method fpga_to_fan3_hsc_en = _top.fpga_to_fan3_hsc_en;
    method fan3_hsc_to_fpga_pg = _top.fan3_hsc_to_fpga_pg;
    method fpga_to_fan3_led_l = _top.fpga_to_fan3_led_l;
    method fan3_to_fpga_present = _top.fan3_to_fpga_present;

    //
    // Front IO
    //

    method fpga_to_front_io_hsc_en = _top.fpga_to_front_io_hsc_en;
    method front_io_hsc_to_fpga_pg = _top.front_io_hsc_to_fpga_pg;

    //
    // Ignition
    //

    method s0_rsw_aux_p = _top.s0_rsw_aux_p;
    interface Inout rsw_s0_aux_dc_p = _top.rsw_s0_aux_dc_p;

    method s1_rsw_aux_p = _top.s1_rsw_aux_p;
    interface Inout rsw_s1_aux_dc_p = _top.rsw_s1_aux_dc_p;

    method s2_rsw_aux_p = _top.s2_rsw_aux_p;
    interface Inout rsw_s2_aux_dc_p = _top.rsw_s2_aux_dc_p;

    method s3_rsw_aux_p = _top.s3_rsw_aux_p;
    interface Inout rsw_s3_aux_dc_p = _top.rsw_s3_aux_dc_p;

    method s4_rsw_aux_p = _top.s4_rsw_aux_p;
    interface Inout rsw_s4_aux_dc_p = _top.rsw_s4_aux_dc_p;

    method s5_rsw_aux_p = _top.s5_rsw_aux_p;
    interface Inout rsw_s5_aux_dc_p = _top.rsw_s5_aux_dc_p;

    method s6_rsw_aux_p = _top.s6_rsw_aux_p;
    interface Inout rsw_s6_aux_dc_p = _top.rsw_s6_aux_dc_p;

    method s7_rsw_aux_p = _top.s7_rsw_aux_p;
    interface Inout rsw_s7_aux_dc_p = _top.rsw_s7_aux_dc_p;

    method s8_rsw_aux_p = _top.s8_rsw_aux_p;
    interface Inout rsw_s8_aux_dc_p = _top.rsw_s8_aux_dc_p;

    method s9_rsw_aux_p = _top.s9_rsw_aux_p;
    interface Inout rsw_s9_aux_dc_p = _top.rsw_s9_aux_dc_p;

    method s10_rsw_aux_p = _top.s10_rsw_aux_p;
    interface Inout rsw_s10_aux_dc_p = _top.rsw_s10_aux_dc_p;

    method s11_rsw_aux_p = _top.s11_rsw_aux_p;
    interface Inout rsw_s11_aux_dc_p = _top.rsw_s11_aux_dc_p;

    method s12_rsw_aux_p = _top.s12_rsw_aux_p;
    interface Inout rsw_s12_aux_dc_p = _top.rsw_s12_aux_dc_p;

    method s13_rsw_aux_p = _top.s13_rsw_aux_p;
    interface Inout rsw_s13_aux_dc_p = _top.rsw_s13_aux_dc_p;

    method s14_rsw_aux_p = _top.s14_rsw_aux_p;
    interface Inout rsw_s14_aux_dc_p = _top.rsw_s14_aux_dc_p;

    method s15_rsw_aux_p = _top.s15_rsw_aux_p;
    interface Inout rsw_s15_aux_dc_p = _top.rsw_s15_aux_dc_p;

    method s16_rsw_aux_p = _top.s16_rsw_aux_p;
    interface Inout rsw_s16_aux_dc_p = _top.rsw_s16_aux_dc_p;

    method s17_rsw_aux_p = _top.s17_rsw_aux_p;
    interface Inout rsw_s17_aux_dc_p = _top.rsw_s17_aux_dc_p;

    method s18_rsw_aux_p = _top.s18_rsw_aux_p;
    interface Inout rsw_s18_aux_dc_p = _top.rsw_s18_aux_dc_p;

    method s19_rsw_aux_p = _top.s19_rsw_aux_p;
    interface Inout rsw_s19_aux_dc_p = _top.rsw_s19_aux_dc_p;

    method s20_rsw_aux_p = _top.s20_rsw_aux_p;
    interface Inout rsw_s20_aux_dc_p = _top.rsw_s20_aux_dc_p;

    method s21_rsw_aux_p = _top.s21_rsw_aux_p;
    interface Inout rsw_s21_aux_dc_p = _top.rsw_s21_aux_dc_p;

    method s22_rsw_aux_p = _top.s22_rsw_aux_p;
    interface Inout rsw_s22_aux_dc_p = _top.rsw_s22_aux_dc_p;

    method s23_rsw_aux_p = _top.s23_rsw_aux_p;
    interface Inout rsw_s23_aux_dc_p = _top.rsw_s23_aux_dc_p;

    method s24_rsw_aux_p = _top.s24_rsw_aux_p;
    interface Inout rsw_s24_aux_dc_p = _top.rsw_s24_aux_dc_p;

    method s25_rsw_aux_p = _top.s25_rsw_aux_p;
    interface Inout rsw_s25_aux_dc_p = _top.rsw_s25_aux_dc_p;

    method s26_rsw_aux_p = _top.s26_rsw_aux_p;
    interface Inout rsw_s26_aux_dc_p = _top.rsw_s26_aux_dc_p;

    method s27_rsw_aux_p = _top.s27_rsw_aux_p;
    interface Inout rsw_s27_aux_dc_p = _top.rsw_s27_aux_dc_p;

    method s28_rsw_aux_p = _top.s28_rsw_aux_p;
    interface Inout rsw_s28_aux_dc_p = _top.rsw_s28_aux_dc_p;

    method s29_rsw_aux_p = _top.s29_rsw_aux_p;
    interface Inout rsw_s29_aux_dc_p = _top.rsw_s29_aux_dc_p;

    method s30_rsw_aux_p = _top.s30_rsw_aux_p;
    interface Inout rsw_s30_aux_dc_p = _top.rsw_s30_aux_dc_p;

    method s31_rsw_aux_p = _top.s31_rsw_aux_p;
    interface Inout rsw_s31_aux_dc_p = _top.rsw_s31_aux_dc_p;

    method ignition_psc0_to_ctrl_p = _top.ignition_psc0_to_ctrl_p;
    interface Inout ignition_ctrl_to_psc0_dc_p = _top.ignition_ctrl_to_psc0_dc_p;

    method ignition_psc1_to_ctrl_p = _top.ignition_psc1_to_ctrl_p;
    interface Inout ignition_ctrl_to_psc1_dc_p = _top.ignition_ctrl_to_psc1_dc_p;

    method ignition_rsw_b_to_ctrl_p = _top.ignition_rsw_b_to_ctrl_p;
    interface Inout ignition_ctrl_to_rsw_b_dc_p = _top.ignition_ctrl_to_rsw_b_dc_p;
endmodule

endpackage
