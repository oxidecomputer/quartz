// Copyright 2022 Oxide Computer Company
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
package QsfpX32ControllerTop;

// BSV Core
import Clocks::*;
import Connectable::*;
import GetPut::*;
import StmtFSM::*;
import TriState::*;
import Vector::*;

// Oxide
import Blinky::*;
import I2CCommon::*;
import I2CCore::*;
import I2CBitController::*;
import IOSync::*;
import SPI::*;
import Strobe::*;
import PowerRail::*;

import CommonInterfaces::*;
import MDIO::*;

// QSFP
import QsfpModuleController::*;
import QsfpModulesTop::*;
import QsfpX32Controller::*;
import QsfpX32ControllerTopRegs::*;
import VSC8562::*;

(* always_enabled *)
interface QsfpControllerTop;
    //
    // QSFP Ports
    //
    method Bool fpga_to_qsfp_en_0;
    method Bit#(1) fpga_to_qsfp_lpmode_0;
    method Bit#(1) fpga_to_qsfp_reset_l_0;
    (* prefix = "" *) method Action qsfp_to_fpga_pg_0(Bool qsfp_to_fpga_pg_0);
    (* prefix = "" *) method Action qsfp_to_fpga_irq_l_0(Bit#(1) qsfp_to_fpga_irq_l_0);
    (* prefix = "" *) method Action qsfp_to_fpga_present_l_0(Bit#(1) qsfp_to_fpga_present_l_0);
    interface Inout#(Bit#(1)) i2c_fpga_to_qsfp_scl_0;
    interface Inout#(Bit#(1)) i2c_fpga_to_qsfp_sda_0;

    method Bool fpga_to_qsfp_en_1;
    method Bit#(1) fpga_to_qsfp_lpmode_1;
    method Bit#(1) fpga_to_qsfp_reset_l_1;
    (* prefix = "" *) method Action qsfp_to_fpga_pg_1(Bool qsfp_to_fpga_pg_1);
    (* prefix = "" *) method Action qsfp_to_fpga_irq_l_1(Bit#(1) qsfp_to_fpga_irq_l_1);
    (* prefix = "" *) method Action qsfp_to_fpga_present_l_1(Bit#(1) qsfp_to_fpga_present_l_1);
    interface Inout#(Bit#(1)) i2c_fpga_to_qsfp_scl_1;
    interface Inout#(Bit#(1)) i2c_fpga_to_qsfp_sda_1;

    method Bool fpga_to_qsfp_en_2;
    method Bit#(1) fpga_to_qsfp_lpmode_2;
    method Bit#(1) fpga_to_qsfp_reset_l_2;
    (* prefix = "" *) method Action qsfp_to_fpga_pg_2(Bool qsfp_to_fpga_pg_2);
    (* prefix = "" *) method Action qsfp_to_fpga_irq_l_2(Bit#(1) qsfp_to_fpga_irq_l_2);
    (* prefix = "" *) method Action qsfp_to_fpga_present_l_2(Bit#(1) qsfp_to_fpga_present_l_2);
    interface Inout#(Bit#(1)) i2c_fpga_to_qsfp_scl_2;
    interface Inout#(Bit#(1)) i2c_fpga_to_qsfp_sda_2;

    method Bool fpga_to_qsfp_en_3;
    method Bit#(1) fpga_to_qsfp_lpmode_3;
    method Bit#(1) fpga_to_qsfp_reset_l_3;
    (* prefix = "" *) method Action qsfp_to_fpga_pg_3(Bool qsfp_to_fpga_pg_3);
    (* prefix = "" *) method Action qsfp_to_fpga_irq_l_3(Bit#(1) qsfp_to_fpga_irq_l_3);
    (* prefix = "" *) method Action qsfp_to_fpga_present_l_3(Bit#(1) qsfp_to_fpga_present_l_3);
    interface Inout#(Bit#(1)) i2c_fpga_to_qsfp_scl_3;
    interface Inout#(Bit#(1)) i2c_fpga_to_qsfp_sda_3;

    method Bool fpga_to_qsfp_en_4;
    method Bit#(1) fpga_to_qsfp_lpmode_4;
    method Bit#(1) fpga_to_qsfp_reset_l_4;
    (* prefix = "" *) method Action qsfp_to_fpga_pg_4(Bool qsfp_to_fpga_pg_4);
    (* prefix = "" *) method Action qsfp_to_fpga_irq_l_4(Bit#(1) qsfp_to_fpga_irq_l_4);
    (* prefix = "" *) method Action qsfp_to_fpga_present_l_4(Bit#(1) qsfp_to_fpga_present_l_4);
    interface Inout#(Bit#(1)) i2c_fpga_to_qsfp_scl_4;
    interface Inout#(Bit#(1)) i2c_fpga_to_qsfp_sda_4;

    method Bool fpga_to_qsfp_en_5;
    method Bit#(1) fpga_to_qsfp_lpmode_5;
    method Bit#(1) fpga_to_qsfp_reset_l_5;
    (* prefix = "" *) method Action qsfp_to_fpga_pg_5(Bool qsfp_to_fpga_pg_5);
    (* prefix = "" *) method Action qsfp_to_fpga_irq_l_5(Bit#(1) qsfp_to_fpga_irq_l_5);
    (* prefix = "" *) method Action qsfp_to_fpga_present_l_5(Bit#(1) qsfp_to_fpga_present_l_5);
    interface Inout#(Bit#(1)) i2c_fpga_to_qsfp_scl_5;
    interface Inout#(Bit#(1)) i2c_fpga_to_qsfp_sda_5;

    method Bool fpga_to_qsfp_en_6;
    method Bit#(1) fpga_to_qsfp_lpmode_6;
    method Bit#(1) fpga_to_qsfp_reset_l_6;
    (* prefix = "" *) method Action qsfp_to_fpga_pg_6(Bool qsfp_to_fpga_pg_6);
    (* prefix = "" *) method Action qsfp_to_fpga_irq_l_6(Bit#(1) qsfp_to_fpga_irq_l_6);
    (* prefix = "" *) method Action qsfp_to_fpga_present_l_6(Bit#(1) qsfp_to_fpga_present_l_6);
    interface Inout#(Bit#(1)) i2c_fpga_to_qsfp_scl_6;
    interface Inout#(Bit#(1)) i2c_fpga_to_qsfp_sda_6;

    method Bool fpga_to_qsfp_en_7;
    method Bit#(1) fpga_to_qsfp_lpmode_7;
    method Bit#(1) fpga_to_qsfp_reset_l_7;
    (* prefix = "" *) method Action qsfp_to_fpga_pg_7(Bool qsfp_to_fpga_pg_7);
    (* prefix = "" *) method Action qsfp_to_fpga_irq_l_7(Bit#(1) qsfp_to_fpga_irq_l_7);
    (* prefix = "" *) method Action qsfp_to_fpga_present_l_7(Bit#(1) qsfp_to_fpga_present_l_7);
    interface Inout#(Bit#(1)) i2c_fpga_to_qsfp_scl_7;
    interface Inout#(Bit#(1)) i2c_fpga_to_qsfp_sda_7;

    method Bool fpga_to_qsfp_en_8;
    method Bit#(1) fpga_to_qsfp_lpmode_8;
    method Bit#(1) fpga_to_qsfp_reset_l_8;
    (* prefix = "" *) method Action qsfp_to_fpga_pg_8(Bool qsfp_to_fpga_pg_8);
    (* prefix = "" *) method Action qsfp_to_fpga_irq_l_8(Bit#(1) qsfp_to_fpga_irq_l_8);
    (* prefix = "" *) method Action qsfp_to_fpga_present_l_8(Bit#(1) qsfp_to_fpga_present_l_8);
    interface Inout#(Bit#(1)) i2c_fpga_to_qsfp_scl_8;
    interface Inout#(Bit#(1)) i2c_fpga_to_qsfp_sda_8;

    method Bool fpga_to_qsfp_en_9;
    method Bit#(1) fpga_to_qsfp_lpmode_9;
    method Bit#(1) fpga_to_qsfp_reset_l_9;
    (* prefix = "" *) method Action qsfp_to_fpga_pg_9(Bool qsfp_to_fpga_pg_9);
    (* prefix = "" *) method Action qsfp_to_fpga_irq_l_9(Bit#(1) qsfp_to_fpga_irq_l_9);
    (* prefix = "" *) method Action qsfp_to_fpga_present_l_9(Bit#(1) qsfp_to_fpga_present_l_9);
    interface Inout#(Bit#(1)) i2c_fpga_to_qsfp_scl_9;
    interface Inout#(Bit#(1)) i2c_fpga_to_qsfp_sda_9;

    method Bool fpga_to_qsfp_en_10;
    method Bit#(1) fpga_to_qsfp_lpmode_10;
    method Bit#(1) fpga_to_qsfp_reset_l_10;
    (* prefix = "" *) method Action qsfp_to_fpga_pg_10(Bool qsfp_to_fpga_pg_10);
    (* prefix = "" *) method Action qsfp_to_fpga_irq_l_10(Bit#(1) qsfp_to_fpga_irq_l_10);
    (* prefix = "" *) method Action qsfp_to_fpga_present_l_10(Bit#(1) qsfp_to_fpga_present_l_10);
    interface Inout#(Bit#(1)) i2c_fpga_to_qsfp_scl_10;
    interface Inout#(Bit#(1)) i2c_fpga_to_qsfp_sda_10;

    method Bool fpga_to_qsfp_en_11;
    method Bit#(1) fpga_to_qsfp_lpmode_11;
    method Bit#(1) fpga_to_qsfp_reset_l_11;
    (* prefix = "" *) method Action qsfp_to_fpga_pg_11(Bool qsfp_to_fpga_pg_11);
    (* prefix = "" *) method Action qsfp_to_fpga_irq_l_11(Bit#(1) qsfp_to_fpga_irq_l_11);
    (* prefix = "" *) method Action qsfp_to_fpga_present_l_11(Bit#(1) qsfp_to_fpga_present_l_11);
    interface Inout#(Bit#(1)) i2c_fpga_to_qsfp_scl_11;
    interface Inout#(Bit#(1)) i2c_fpga_to_qsfp_sda_11;

    method Bool fpga_to_qsfp_en_12;
    method Bit#(1) fpga_to_qsfp_lpmode_12;
    method Bit#(1) fpga_to_qsfp_reset_l_12;
    (* prefix = "" *) method Action qsfp_to_fpga_pg_12(Bool qsfp_to_fpga_pg_12);
    (* prefix = "" *) method Action qsfp_to_fpga_irq_l_12(Bit#(1) qsfp_to_fpga_irq_l_12);
    (* prefix = "" *) method Action qsfp_to_fpga_present_l_12(Bit#(1) qsfp_to_fpga_present_l_12);
    interface Inout#(Bit#(1)) i2c_fpga_to_qsfp_scl_12;
    interface Inout#(Bit#(1)) i2c_fpga_to_qsfp_sda_12;

    method Bool fpga_to_qsfp_en_13;
    method Bit#(1) fpga_to_qsfp_lpmode_13;
    method Bit#(1) fpga_to_qsfp_reset_l_13;
    (* prefix = "" *) method Action qsfp_to_fpga_pg_13(Bool qsfp_to_fpga_pg_13);
    (* prefix = "" *) method Action qsfp_to_fpga_irq_l_13(Bit#(1) qsfp_to_fpga_irq_l_13);
    (* prefix = "" *) method Action qsfp_to_fpga_present_l_13(Bit#(1) qsfp_to_fpga_present_l_13);
    interface Inout#(Bit#(1)) i2c_fpga_to_qsfp_scl_13;
    interface Inout#(Bit#(1)) i2c_fpga_to_qsfp_sda_13;

    method Bool fpga_to_qsfp_en_14;
    method Bit#(1) fpga_to_qsfp_lpmode_14;
    method Bit#(1) fpga_to_qsfp_reset_l_14;
    (* prefix = "" *) method Action qsfp_to_fpga_pg_14(Bool qsfp_to_fpga_pg_14);
    (* prefix = "" *) method Action qsfp_to_fpga_irq_l_14(Bit#(1) qsfp_to_fpga_irq_l_14);
    (* prefix = "" *) method Action qsfp_to_fpga_present_l_14(Bit#(1) qsfp_to_fpga_present_l_14);
    interface Inout#(Bit#(1)) i2c_fpga_to_qsfp_scl_14;
    interface Inout#(Bit#(1)) i2c_fpga_to_qsfp_sda_14;

    method Bool fpga_to_qsfp_en_15;
    method Bit#(1) fpga_to_qsfp_lpmode_15;
    method Bit#(1) fpga_to_qsfp_reset_l_15;
    (* prefix = "" *) method Action qsfp_to_fpga_pg_15(Bool qsfp_to_fpga_pg_15);
    (* prefix = "" *) method Action qsfp_to_fpga_irq_l_15(Bit#(1) qsfp_to_fpga_irq_l_15);
    (* prefix = "" *) method Action qsfp_to_fpga_present_l_15(Bit#(1) qsfp_to_fpga_present_l_15);
    interface Inout#(Bit#(1)) i2c_fpga_to_qsfp_scl_15;
    interface Inout#(Bit#(1)) i2c_fpga_to_qsfp_sda_15;

    //
    // SPI Peripheral
    //

    method Bit#(1) spi_main_to_fpga_miso_r();
    (* prefix = "" *) method Action spi_main_to_fpga_cs1_l(Bit#(1) spi_main_to_fpga_cs1_l);
    (* prefix = "" *) method Action spi_main_to_fpga_sck(Bit#(1) spi_main_to_fpga_sck);
    (* prefix = "" *) method Action spi_main_to_fpga_mosi(Bit#(1) spi_main_to_fpga_mosi);

    //
    // Power
    //

    method Bit#(1) fpga_to_vr_v3p3_qsfp_en();
    (* prefix = "" *) method Action vr_v3p3_qsfp_to_fpga_pg(Bit#(1) vr_v3p3_qsfp_to_fpga_pg);
    (* prefix = "" *) method Action pmbus_v3p3_qsfp_to_fpga_alert(Bit#(1) pmbus_v3p3_qsfp_to_fpga_alert);

    //
    // PHY
    //

    method Bool fpga_to_vr_phy_en();
    (* prefix = "" *) method Action vr_v1p0_phy_to_fpga_pg(Bool vr_v1p0_phy_to_fpga_pg);
    (* prefix = "" *) method Action vr_v2p5_phy_to_fpga_pg(Bool vr_v2p5_phy_to_fpga_pg);
    method Bit#(1) fpga_to_phy_refclk_en();
    method Bit#(1) fpga_to_phy_coma_mode();
    method Bit#(1) fpga_to_phy_reset_l();
    method Bit#(1) miim_fpga_to_phy_mdc();
    (* prefix = "" *) method Action miim_phy_to_fpga_mdint_l(Bit#(1) miim_phy_to_fpga_mdint_l);
    interface Inout#(Bit#(1)) miim_fpga_to_phy_mdio;

    //
    // Miscellaneous
    //

    method Bit#(1) fpga_to_main_irq_r_l();
    method Bit#(1) fpga_led();
    method Bit#(1) fpga_to_leds0_reset_l();
    method Bit#(1) fpga_to_leds0_oe_l();
    method Bit#(8) debug_fpga_io();
    (* prefix = "" *) method Action fpga_app_id_r(Bit#(1) fpga_app_id_r);
endinterface

function Inout#(Bit#(1)) inout_from_tristate(TriState#(Bit#(1)) tristate) = tristate.io;

(*  synthesize,
    default_clock_osc="clk_50m_fpga",
    default_reset="gpio_to_fpga_design_reset_l" *)
module mkQsfpX32ControllerTop (QsfpControllerTop);
    // Synchronize the default reset to the default clock
    Clock cur_clk       <- exposeCurrentClock();
    Reset reset_synced  <- mkAsyncResetFromCR(2, cur_clk);

    QsfpX32Controller controller    <-
        mkQsfpX32Controller(defaultValue, reset_by reset_synced);

    //
    // QSFP Ports
    //

    // P0
    ReadOnly#(Bool) qsfp0_hsc_en        <- mkOutputSyncFor(controller.qsfp[0].hsc.en);
    ReadOnly#(Bit#(1)) qsfp0_lpmode        <- mkOutputSyncFor(controller.qsfp[0].lpmode);
    ReadOnly#(Bit#(1)) qsfp0_reset         <- mkOutputSyncFor(controller.qsfp[0].reset_);
    Reg#(Bool) qsfp0_hsc_pg        <- mkInputSyncFor(controller.qsfp[0].hsc.pg);
    Reg#(Bit#(1)) qsfp0_irq           <- mkInputSyncFor(controller.qsfp[0].irq);
    Reg#(Bit#(1)) qsfp0_prs           <- mkInputSyncFor(controller.qsfp[0].present);
    ReadOnly#(Bool) qsfp0_scl_out_en    <- mkOutputSyncFor(unpack(controller.qsfp[0].scl.out_en));
    ReadOnly#(Bit#(1)) qsfp0_scl_out     <- mkOutputSyncFor(controller.qsfp[0].scl.out);
    Reg#(Bit#(1)) qsfp0_scl_in           <- mkInputSyncFor(controller.qsfp[0].scl.in);
    TriState#(Bit#(1)) qsfp0_scl         <- mkTriState(qsfp0_scl_out_en, qsfp0_scl_out);
    mkConnection(sync(qsfp0_scl_in), qsfp0_scl._read);
    ReadOnly#(Bool) qsfp0_sda_out_en    <- mkOutputSyncFor(unpack(controller.qsfp[0].sda.out_en));
    ReadOnly#(Bit#(1)) qsfp0_sda_out     <- mkOutputSyncFor(controller.qsfp[0].sda.out);
    Reg#(Bit#(1)) qsfp0_sda_in           <- mkInputSyncFor(controller.qsfp[0].sda.in);
    TriState#(Bit#(1)) qsfp0_sda         <- mkTriState(qsfp0_sda_out_en, qsfp0_sda_out);
    mkConnection(sync(qsfp0_sda_in), qsfp0_sda._read);

    // P1
    ReadOnly#(Bool) qsfp1_hsc_en        <- mkOutputSyncFor(controller.qsfp[1].hsc.en);
    ReadOnly#(Bit#(1)) qsfp1_lpmode        <- mkOutputSyncFor(controller.qsfp[1].lpmode);
    ReadOnly#(Bit#(1)) qsfp1_reset         <- mkOutputSyncFor(controller.qsfp[1].reset_);
    Reg#(Bool) qsfp1_hsc_pg        <- mkInputSyncFor(controller.qsfp[1].hsc.pg);
    Reg#(Bit#(1)) qsfp1_irq           <- mkInputSyncFor(controller.qsfp[1].irq);
    Reg#(Bit#(1)) qsfp1_prs           <- mkInputSyncFor(controller.qsfp[1].present);
    ReadOnly#(Bool) qsfp1_scl_out_en    <- mkOutputSyncFor(unpack(controller.qsfp[1].scl.out_en));
    ReadOnly#(Bit#(1)) qsfp1_scl_out     <- mkOutputSyncFor(controller.qsfp[1].scl.out);
    Reg#(Bit#(1)) qsfp1_scl_in           <- mkInputSyncFor(controller.qsfp[1].scl.in);
    TriState#(Bit#(1)) qsfp1_scl         <- mkTriState(qsfp1_scl_out_en, qsfp1_scl_out);
    mkConnection(sync(qsfp1_scl_in), qsfp1_scl._read);
    ReadOnly#(Bool) qsfp1_sda_out_en    <- mkOutputSyncFor(unpack(controller.qsfp[1].sda.out_en));
    ReadOnly#(Bit#(1)) qsfp1_sda_out     <- mkOutputSyncFor(controller.qsfp[1].sda.out);
    Reg#(Bit#(1)) qsfp1_sda_in           <- mkInputSyncFor(controller.qsfp[1].sda.in);
    TriState#(Bit#(1)) qsfp1_sda         <- mkTriState(qsfp1_sda_out_en, qsfp1_sda_out);
    mkConnection(sync(qsfp1_sda_in), qsfp1_sda._read);

    // P2
    ReadOnly#(Bool) qsfp2_hsc_en        <- mkOutputSyncFor(controller.qsfp[2].hsc.en);
    ReadOnly#(Bit#(1)) qsfp2_lpmode        <- mkOutputSyncFor(controller.qsfp[2].lpmode);
    ReadOnly#(Bit#(1)) qsfp2_reset         <- mkOutputSyncFor(controller.qsfp[2].reset_);
    Reg#(Bool) qsfp2_hsc_pg        <- mkInputSyncFor(controller.qsfp[2].hsc.pg);
    Reg#(Bit#(1)) qsfp2_irq           <- mkInputSyncFor(controller.qsfp[2].irq);
    Reg#(Bit#(1)) qsfp2_prs           <- mkInputSyncFor(controller.qsfp[2].present);
    ReadOnly#(Bool) qsfp2_scl_out_en    <- mkOutputSyncFor(unpack(controller.qsfp[2].scl.out_en));
    ReadOnly#(Bit#(1)) qsfp2_scl_out     <- mkOutputSyncFor(controller.qsfp[2].scl.out);
    Reg#(Bit#(1)) qsfp2_scl_in           <- mkInputSyncFor(controller.qsfp[2].scl.in);
    TriState#(Bit#(1)) qsfp2_scl         <- mkTriState(qsfp2_scl_out_en, qsfp2_scl_out);
    mkConnection(sync(qsfp2_scl_in), qsfp2_scl._read);
    ReadOnly#(Bool) qsfp2_sda_out_en    <- mkOutputSyncFor(unpack(controller.qsfp[2].sda.out_en));
    ReadOnly#(Bit#(1)) qsfp2_sda_out     <- mkOutputSyncFor(controller.qsfp[2].sda.out);
    Reg#(Bit#(1)) qsfp2_sda_in           <- mkInputSyncFor(controller.qsfp[2].sda.in);
    TriState#(Bit#(1)) qsfp2_sda         <- mkTriState(qsfp2_sda_out_en, qsfp2_sda_out);
    mkConnection(sync(qsfp2_sda_in), qsfp2_sda._read);

    // P3
    ReadOnly#(Bool) qsfp3_hsc_en        <- mkOutputSyncFor(controller.qsfp[3].hsc.en);
    ReadOnly#(Bit#(1)) qsfp3_lpmode        <- mkOutputSyncFor(controller.qsfp[3].lpmode);
    ReadOnly#(Bit#(1)) qsfp3_reset         <- mkOutputSyncFor(controller.qsfp[3].reset_);
    Reg#(Bool) qsfp3_hsc_pg        <- mkInputSyncFor(controller.qsfp[3].hsc.pg);
    Reg#(Bit#(1)) qsfp3_irq           <- mkInputSyncFor(controller.qsfp[3].irq);
    Reg#(Bit#(1)) qsfp3_prs           <- mkInputSyncFor(controller.qsfp[3].present);
    ReadOnly#(Bool) qsfp3_scl_out_en    <- mkOutputSyncFor(unpack(controller.qsfp[3].scl.out_en));
    ReadOnly#(Bit#(1)) qsfp3_scl_out     <- mkOutputSyncFor(controller.qsfp[3].scl.out);
    Reg#(Bit#(1)) qsfp3_scl_in           <- mkInputSyncFor(controller.qsfp[3].scl.in);
    TriState#(Bit#(1)) qsfp3_scl         <- mkTriState(qsfp3_scl_out_en, qsfp3_scl_out);
    mkConnection(sync(qsfp3_scl_in), qsfp3_scl._read);
    ReadOnly#(Bool) qsfp3_sda_out_en    <- mkOutputSyncFor(unpack(controller.qsfp[3].sda.out_en));
    ReadOnly#(Bit#(1)) qsfp3_sda_out     <- mkOutputSyncFor(controller.qsfp[3].sda.out);
    Reg#(Bit#(1)) qsfp3_sda_in           <- mkInputSyncFor(controller.qsfp[3].sda.in);
    TriState#(Bit#(1)) qsfp3_sda         <- mkTriState(qsfp3_sda_out_en, qsfp3_sda_out);
    mkConnection(sync(qsfp3_sda_in), qsfp3_sda._read);

    // P4
    ReadOnly#(Bool) qsfp4_hsc_en        <- mkOutputSyncFor(controller.qsfp[4].hsc.en);
    ReadOnly#(Bit#(1)) qsfp4_lpmode        <- mkOutputSyncFor(controller.qsfp[4].lpmode);
    ReadOnly#(Bit#(1)) qsfp4_reset         <- mkOutputSyncFor(controller.qsfp[4].reset_);
    Reg#(Bool) qsfp4_hsc_pg        <- mkInputSyncFor(controller.qsfp[4].hsc.pg);
    Reg#(Bit#(1)) qsfp4_irq           <- mkInputSyncFor(controller.qsfp[4].irq);
    Reg#(Bit#(1)) qsfp4_prs           <- mkInputSyncFor(controller.qsfp[4].present);
    ReadOnly#(Bool) qsfp4_scl_out_en    <- mkOutputSyncFor(unpack(controller.qsfp[4].scl.out_en));
    ReadOnly#(Bit#(1)) qsfp4_scl_out     <- mkOutputSyncFor(controller.qsfp[4].scl.out);
    Reg#(Bit#(1)) qsfp4_scl_in           <- mkInputSyncFor(controller.qsfp[4].scl.in);
    TriState#(Bit#(1)) qsfp4_scl         <- mkTriState(qsfp4_scl_out_en, qsfp4_scl_out);
    mkConnection(sync(qsfp4_scl_in), qsfp4_scl._read);
    ReadOnly#(Bool) qsfp4_sda_out_en    <- mkOutputSyncFor(unpack(controller.qsfp[4].sda.out_en));
    ReadOnly#(Bit#(1)) qsfp4_sda_out     <- mkOutputSyncFor(controller.qsfp[4].sda.out);
    Reg#(Bit#(1)) qsfp4_sda_in           <- mkInputSyncFor(controller.qsfp[4].sda.in);
    TriState#(Bit#(1)) qsfp4_sda         <- mkTriState(qsfp4_sda_out_en, qsfp4_sda_out);
    mkConnection(sync(qsfp4_sda_in), qsfp4_sda._read);

    // P5
    ReadOnly#(Bool) qsfp5_hsc_en        <- mkOutputSyncFor(controller.qsfp[5].hsc.en);
    ReadOnly#(Bit#(1)) qsfp5_lpmode        <- mkOutputSyncFor(controller.qsfp[5].lpmode);
    ReadOnly#(Bit#(1)) qsfp5_reset         <- mkOutputSyncFor(controller.qsfp[5].reset_);
    Reg#(Bool) qsfp5_hsc_pg        <- mkInputSyncFor(controller.qsfp[5].hsc.pg);
    Reg#(Bit#(1)) qsfp5_irq           <- mkInputSyncFor(controller.qsfp[5].irq);
    Reg#(Bit#(1)) qsfp5_prs           <- mkInputSyncFor(controller.qsfp[5].present);
    ReadOnly#(Bool) qsfp5_scl_out_en    <- mkOutputSyncFor(unpack(controller.qsfp[5].scl.out_en));
    ReadOnly#(Bit#(1)) qsfp5_scl_out     <- mkOutputSyncFor(controller.qsfp[5].scl.out);
    Reg#(Bit#(1)) qsfp5_scl_in           <- mkInputSyncFor(controller.qsfp[5].scl.in);
    TriState#(Bit#(1)) qsfp5_scl         <- mkTriState(qsfp5_scl_out_en, qsfp5_scl_out);
    mkConnection(sync(qsfp5_scl_in), qsfp5_scl._read);
    ReadOnly#(Bool) qsfp5_sda_out_en    <- mkOutputSyncFor(unpack(controller.qsfp[5].sda.out_en));
    ReadOnly#(Bit#(1)) qsfp5_sda_out     <- mkOutputSyncFor(controller.qsfp[5].sda.out);
    Reg#(Bit#(1)) qsfp5_sda_in           <- mkInputSyncFor(controller.qsfp[5].sda.in);
    TriState#(Bit#(1)) qsfp5_sda         <- mkTriState(qsfp5_sda_out_en, qsfp5_sda_out);
    mkConnection(sync(qsfp5_sda_in), qsfp5_sda._read);

    // P6
    ReadOnly#(Bool) qsfp6_hsc_en        <- mkOutputSyncFor(controller.qsfp[6].hsc.en);
    ReadOnly#(Bit#(1)) qsfp6_lpmode        <- mkOutputSyncFor(controller.qsfp[6].lpmode);
    ReadOnly#(Bit#(1)) qsfp6_reset         <- mkOutputSyncFor(controller.qsfp[6].reset_);
    Reg#(Bool) qsfp6_hsc_pg        <- mkInputSyncFor(controller.qsfp[6].hsc.pg);
    Reg#(Bit#(1)) qsfp6_irq           <- mkInputSyncFor(controller.qsfp[6].irq);
    Reg#(Bit#(1)) qsfp6_prs           <- mkInputSyncFor(controller.qsfp[6].present);
    ReadOnly#(Bool) qsfp6_scl_out_en    <- mkOutputSyncFor(unpack(controller.qsfp[6].scl.out_en));
    ReadOnly#(Bit#(1)) qsfp6_scl_out     <- mkOutputSyncFor(controller.qsfp[6].scl.out);
    Reg#(Bit#(1)) qsfp6_scl_in           <- mkInputSyncFor(controller.qsfp[6].scl.in);
    TriState#(Bit#(1)) qsfp6_scl         <- mkTriState(qsfp6_scl_out_en, qsfp6_scl_out);
    mkConnection(sync(qsfp6_scl_in), qsfp6_scl._read);
    ReadOnly#(Bool) qsfp6_sda_out_en    <- mkOutputSyncFor(unpack(controller.qsfp[6].sda.out_en));
    ReadOnly#(Bit#(1)) qsfp6_sda_out     <- mkOutputSyncFor(controller.qsfp[6].sda.out);
    Reg#(Bit#(1)) qsfp6_sda_in           <- mkInputSyncFor(controller.qsfp[6].sda.in);
    TriState#(Bit#(1)) qsfp6_sda         <- mkTriState(qsfp6_sda_out_en, qsfp6_sda_out);
    mkConnection(sync(qsfp6_sda_in), qsfp6_sda._read);

    // P7
    ReadOnly#(Bool) qsfp7_hsc_en        <- mkOutputSyncFor(controller.qsfp[7].hsc.en);
    ReadOnly#(Bit#(1)) qsfp7_lpmode        <- mkOutputSyncFor(controller.qsfp[7].lpmode);
    ReadOnly#(Bit#(1)) qsfp7_reset         <- mkOutputSyncFor(controller.qsfp[7].reset_);
    Reg#(Bool) qsfp7_hsc_pg        <- mkInputSyncFor(controller.qsfp[7].hsc.pg);
    Reg#(Bit#(1)) qsfp7_irq           <- mkInputSyncFor(controller.qsfp[7].irq);
    Reg#(Bit#(1)) qsfp7_prs           <- mkInputSyncFor(controller.qsfp[7].present);
    ReadOnly#(Bool) qsfp7_scl_out_en    <- mkOutputSyncFor(unpack(controller.qsfp[7].scl.out_en));
    ReadOnly#(Bit#(1)) qsfp7_scl_out     <- mkOutputSyncFor(controller.qsfp[7].scl.out);
    Reg#(Bit#(1)) qsfp7_scl_in           <- mkInputSyncFor(controller.qsfp[7].scl.in);
    TriState#(Bit#(1)) qsfp7_scl         <- mkTriState(qsfp7_scl_out_en, qsfp7_scl_out);
    mkConnection(sync(qsfp7_scl_in), qsfp7_scl._read);
    ReadOnly#(Bool) qsfp7_sda_out_en    <- mkOutputSyncFor(unpack(controller.qsfp[7].sda.out_en));
    ReadOnly#(Bit#(1)) qsfp7_sda_out     <- mkOutputSyncFor(controller.qsfp[7].sda.out);
    Reg#(Bit#(1)) qsfp7_sda_in           <- mkInputSyncFor(controller.qsfp[7].sda.in);
    TriState#(Bit#(1)) qsfp7_sda         <- mkTriState(qsfp7_sda_out_en, qsfp7_sda_out);
    mkConnection(sync(qsfp7_sda_in), qsfp7_sda._read);

    // P8
    ReadOnly#(Bool) qsfp8_hsc_en        <- mkOutputSyncFor(controller.qsfp[8].hsc.en);
    ReadOnly#(Bit#(1)) qsfp8_lpmode        <- mkOutputSyncFor(controller.qsfp[8].lpmode);
    ReadOnly#(Bit#(1)) qsfp8_reset         <- mkOutputSyncFor(controller.qsfp[8].reset_);
    Reg#(Bool) qsfp8_hsc_pg        <- mkInputSyncFor(controller.qsfp[8].hsc.pg);
    Reg#(Bit#(1)) qsfp8_irq           <- mkInputSyncFor(controller.qsfp[8].irq);
    Reg#(Bit#(1)) qsfp8_prs           <- mkInputSyncFor(controller.qsfp[8].present);
    ReadOnly#(Bool) qsfp8_scl_out_en    <- mkOutputSyncFor(unpack(controller.qsfp[8].scl.out_en));
    ReadOnly#(Bit#(1)) qsfp8_scl_out     <- mkOutputSyncFor(controller.qsfp[8].scl.out);
    Reg#(Bit#(1)) qsfp8_scl_in           <- mkInputSyncFor(controller.qsfp[8].scl.in);
    TriState#(Bit#(1)) qsfp8_scl         <- mkTriState(qsfp8_scl_out_en, qsfp8_scl_out);
    mkConnection(sync(qsfp8_scl_in), qsfp8_scl._read);
    ReadOnly#(Bool) qsfp8_sda_out_en    <- mkOutputSyncFor(unpack(controller.qsfp[8].sda.out_en));
    ReadOnly#(Bit#(1)) qsfp8_sda_out     <- mkOutputSyncFor(controller.qsfp[8].sda.out);
    Reg#(Bit#(1)) qsfp8_sda_in           <- mkInputSyncFor(controller.qsfp[8].sda.in);
    TriState#(Bit#(1)) qsfp8_sda         <- mkTriState(qsfp8_sda_out_en, qsfp8_sda_out);
    mkConnection(sync(qsfp8_sda_in), qsfp8_sda._read);

    // P9
    ReadOnly#(Bool) qsfp9_hsc_en        <- mkOutputSyncFor(controller.qsfp[9].hsc.en);
    ReadOnly#(Bit#(1)) qsfp9_lpmode        <- mkOutputSyncFor(controller.qsfp[9].lpmode);
    ReadOnly#(Bit#(1)) qsfp9_reset         <- mkOutputSyncFor(controller.qsfp[9].reset_);
    Reg#(Bool) qsfp9_hsc_pg        <- mkInputSyncFor(controller.qsfp[9].hsc.pg);
    Reg#(Bit#(1)) qsfp9_irq           <- mkInputSyncFor(controller.qsfp[9].irq);
    Reg#(Bit#(1)) qsfp9_prs           <- mkInputSyncFor(controller.qsfp[9].present);
    ReadOnly#(Bool) qsfp9_scl_out_en    <- mkOutputSyncFor(unpack(controller.qsfp[9].scl.out_en));
    ReadOnly#(Bit#(1)) qsfp9_scl_out     <- mkOutputSyncFor(controller.qsfp[9].scl.out);
    Reg#(Bit#(1)) qsfp9_scl_in           <- mkInputSyncFor(controller.qsfp[9].scl.in);
    TriState#(Bit#(1)) qsfp9_scl         <- mkTriState(qsfp9_scl_out_en, qsfp9_scl_out);
    mkConnection(sync(qsfp9_scl_in), qsfp9_scl._read);
    ReadOnly#(Bool) qsfp9_sda_out_en    <- mkOutputSyncFor(unpack(controller.qsfp[9].sda.out_en));
    ReadOnly#(Bit#(1)) qsfp9_sda_out     <- mkOutputSyncFor(controller.qsfp[9].sda.out);
    Reg#(Bit#(1)) qsfp9_sda_in           <- mkInputSyncFor(controller.qsfp[9].sda.in);
    TriState#(Bit#(1)) qsfp9_sda         <- mkTriState(qsfp9_sda_out_en, qsfp9_sda_out);
    mkConnection(sync(qsfp9_sda_in), qsfp9_sda._read);

    // P10
    ReadOnly#(Bool) qsfp10_hsc_en        <- mkOutputSyncFor(controller.qsfp[10].hsc.en);
    ReadOnly#(Bit#(1)) qsfp10_lpmode        <- mkOutputSyncFor(controller.qsfp[10].lpmode);
    ReadOnly#(Bit#(1)) qsfp10_reset         <- mkOutputSyncFor(controller.qsfp[10].reset_);
    Reg#(Bool) qsfp10_hsc_pg        <- mkInputSyncFor(controller.qsfp[10].hsc.pg);
    Reg#(Bit#(1)) qsfp10_irq           <- mkInputSyncFor(controller.qsfp[10].irq);
    Reg#(Bit#(1)) qsfp10_prs           <- mkInputSyncFor(controller.qsfp[10].present);
    ReadOnly#(Bool) qsfp10_scl_out_en    <- mkOutputSyncFor(unpack(controller.qsfp[10].scl.out_en));
    ReadOnly#(Bit#(1)) qsfp10_scl_out     <- mkOutputSyncFor(controller.qsfp[10].scl.out);
    Reg#(Bit#(1)) qsfp10_scl_in           <- mkInputSyncFor(controller.qsfp[10].scl.in);
    TriState#(Bit#(1)) qsfp10_scl         <- mkTriState(qsfp10_scl_out_en, qsfp10_scl_out);
    mkConnection(sync(qsfp10_scl_in), qsfp10_scl._read);
    ReadOnly#(Bool) qsfp10_sda_out_en    <- mkOutputSyncFor(unpack(controller.qsfp[10].sda.out_en));
    ReadOnly#(Bit#(1)) qsfp10_sda_out     <- mkOutputSyncFor(controller.qsfp[10].sda.out);
    Reg#(Bit#(1)) qsfp10_sda_in           <- mkInputSyncFor(controller.qsfp[10].sda.in);
    TriState#(Bit#(1)) qsfp10_sda         <- mkTriState(qsfp10_sda_out_en, qsfp10_sda_out);
    mkConnection(sync(qsfp10_sda_in), qsfp10_sda._read);

    // P11
    ReadOnly#(Bool) qsfp11_hsc_en        <- mkOutputSyncFor(controller.qsfp[11].hsc.en);
    ReadOnly#(Bit#(1)) qsfp11_lpmode        <- mkOutputSyncFor(controller.qsfp[11].lpmode);
    ReadOnly#(Bit#(1)) qsfp11_reset         <- mkOutputSyncFor(controller.qsfp[11].reset_);
    Reg#(Bool) qsfp11_hsc_pg        <- mkInputSyncFor(controller.qsfp[11].hsc.pg);
    Reg#(Bit#(1)) qsfp11_irq           <- mkInputSyncFor(controller.qsfp[11].irq);
    Reg#(Bit#(1)) qsfp11_prs           <- mkInputSyncFor(controller.qsfp[11].present);
    ReadOnly#(Bool) qsfp11_scl_out_en    <- mkOutputSyncFor(unpack(controller.qsfp[11].scl.out_en));
    ReadOnly#(Bit#(1)) qsfp11_scl_out     <- mkOutputSyncFor(controller.qsfp[11].scl.out);
    Reg#(Bit#(1)) qsfp11_scl_in           <- mkInputSyncFor(controller.qsfp[11].scl.in);
    TriState#(Bit#(1)) qsfp11_scl         <- mkTriState(qsfp11_scl_out_en, qsfp11_scl_out);
    mkConnection(sync(qsfp11_scl_in), qsfp11_scl._read);
    ReadOnly#(Bool) qsfp11_sda_out_en    <- mkOutputSyncFor(unpack(controller.qsfp[11].sda.out_en));
    ReadOnly#(Bit#(1)) qsfp11_sda_out     <- mkOutputSyncFor(controller.qsfp[11].sda.out);
    Reg#(Bit#(1)) qsfp11_sda_in           <- mkInputSyncFor(controller.qsfp[11].sda.in);
    TriState#(Bit#(1)) qsfp11_sda         <- mkTriState(qsfp11_sda_out_en, qsfp11_sda_out);
    mkConnection(sync(qsfp11_sda_in), qsfp11_sda._read);

    // P12
    ReadOnly#(Bool) qsfp12_hsc_en        <- mkOutputSyncFor(controller.qsfp[12].hsc.en);
    ReadOnly#(Bit#(1)) qsfp12_lpmode        <- mkOutputSyncFor(controller.qsfp[12].lpmode);
    ReadOnly#(Bit#(1)) qsfp12_reset         <- mkOutputSyncFor(controller.qsfp[12].reset_);
    Reg#(Bool) qsfp12_hsc_pg        <- mkInputSyncFor(controller.qsfp[12].hsc.pg);
    Reg#(Bit#(1)) qsfp12_irq           <- mkInputSyncFor(controller.qsfp[12].irq);
    Reg#(Bit#(1)) qsfp12_prs           <- mkInputSyncFor(controller.qsfp[12].present);
    ReadOnly#(Bool) qsfp12_scl_out_en    <- mkOutputSyncFor(unpack(controller.qsfp[12].scl.out_en));
    ReadOnly#(Bit#(1)) qsfp12_scl_out     <- mkOutputSyncFor(controller.qsfp[12].scl.out);
    Reg#(Bit#(1)) qsfp12_scl_in           <- mkInputSyncFor(controller.qsfp[12].scl.in);
    TriState#(Bit#(1)) qsfp12_scl         <- mkTriState(qsfp12_scl_out_en, qsfp12_scl_out);
    mkConnection(sync(qsfp12_scl_in), qsfp12_scl._read);
    ReadOnly#(Bool) qsfp12_sda_out_en    <- mkOutputSyncFor(unpack(controller.qsfp[12].sda.out_en));
    ReadOnly#(Bit#(1)) qsfp12_sda_out     <- mkOutputSyncFor(controller.qsfp[12].sda.out);
    Reg#(Bit#(1)) qsfp12_sda_in           <- mkInputSyncFor(controller.qsfp[12].sda.in);
    TriState#(Bit#(1)) qsfp12_sda         <- mkTriState(qsfp12_sda_out_en, qsfp12_sda_out);
    mkConnection(sync(qsfp12_sda_in), qsfp12_sda._read);

    // P13
    ReadOnly#(Bool) qsfp13_hsc_en        <- mkOutputSyncFor(controller.qsfp[13].hsc.en);
    ReadOnly#(Bit#(1)) qsfp13_lpmode        <- mkOutputSyncFor(controller.qsfp[13].lpmode);
    ReadOnly#(Bit#(1)) qsfp13_reset         <- mkOutputSyncFor(controller.qsfp[13].reset_);
    Reg#(Bool) qsfp13_hsc_pg        <- mkInputSyncFor(controller.qsfp[13].hsc.pg);
    Reg#(Bit#(1)) qsfp13_irq           <- mkInputSyncFor(controller.qsfp[13].irq);
    Reg#(Bit#(1)) qsfp13_prs           <- mkInputSyncFor(controller.qsfp[13].present);
    ReadOnly#(Bool) qsfp13_scl_out_en    <- mkOutputSyncFor(unpack(controller.qsfp[13].scl.out_en));
    ReadOnly#(Bit#(1)) qsfp13_scl_out     <- mkOutputSyncFor(controller.qsfp[13].scl.out);
    Reg#(Bit#(1)) qsfp13_scl_in           <- mkInputSyncFor(controller.qsfp[13].scl.in);
    TriState#(Bit#(1)) qsfp13_scl         <- mkTriState(qsfp13_scl_out_en, qsfp13_scl_out);
    mkConnection(sync(qsfp13_scl_in), qsfp13_scl._read);
    ReadOnly#(Bool) qsfp13_sda_out_en    <- mkOutputSyncFor(unpack(controller.qsfp[13].sda.out_en));
    ReadOnly#(Bit#(1)) qsfp13_sda_out     <- mkOutputSyncFor(controller.qsfp[13].sda.out);
    Reg#(Bit#(1)) qsfp13_sda_in           <- mkInputSyncFor(controller.qsfp[13].sda.in);
    TriState#(Bit#(1)) qsfp13_sda         <- mkTriState(qsfp13_sda_out_en, qsfp13_sda_out);
    mkConnection(sync(qsfp13_sda_in), qsfp13_sda._read);

    // P14
    ReadOnly#(Bool) qsfp14_hsc_en        <- mkOutputSyncFor(controller.qsfp[14].hsc.en);
    ReadOnly#(Bit#(1)) qsfp14_lpmode        <- mkOutputSyncFor(controller.qsfp[14].lpmode);
    ReadOnly#(Bit#(1)) qsfp14_reset         <- mkOutputSyncFor(controller.qsfp[14].reset_);
    Reg#(Bool) qsfp14_hsc_pg        <- mkInputSyncFor(controller.qsfp[14].hsc.pg);
    Reg#(Bit#(1)) qsfp14_irq           <- mkInputSyncFor(controller.qsfp[14].irq);
    Reg#(Bit#(1)) qsfp14_prs           <- mkInputSyncFor(controller.qsfp[14].present);
    ReadOnly#(Bool) qsfp14_scl_out_en    <- mkOutputSyncFor(unpack(controller.qsfp[14].scl.out_en));
    ReadOnly#(Bit#(1)) qsfp14_scl_out     <- mkOutputSyncFor(controller.qsfp[14].scl.out);
    Reg#(Bit#(1)) qsfp14_scl_in           <- mkInputSyncFor(controller.qsfp[14].scl.in);
    TriState#(Bit#(1)) qsfp14_scl         <- mkTriState(qsfp14_scl_out_en, qsfp14_scl_out);
    mkConnection(sync(qsfp14_scl_in), qsfp14_scl._read);
    ReadOnly#(Bool) qsfp14_sda_out_en    <- mkOutputSyncFor(unpack(controller.qsfp[14].sda.out_en));
    ReadOnly#(Bit#(1)) qsfp14_sda_out     <- mkOutputSyncFor(controller.qsfp[14].sda.out);
    Reg#(Bit#(1)) qsfp14_sda_in           <- mkInputSyncFor(controller.qsfp[14].sda.in);
    TriState#(Bit#(1)) qsfp14_sda         <- mkTriState(qsfp14_sda_out_en, qsfp14_sda_out);
    mkConnection(sync(qsfp14_sda_in), qsfp14_sda._read);

    // P15
    ReadOnly#(Bool) qsfp15_hsc_en        <- mkOutputSyncFor(controller.qsfp[15].hsc.en);
    ReadOnly#(Bit#(1)) qsfp15_lpmode        <- mkOutputSyncFor(controller.qsfp[15].lpmode);
    ReadOnly#(Bit#(1)) qsfp15_reset         <- mkOutputSyncFor(controller.qsfp[15].reset_);
    Reg#(Bool) qsfp15_hsc_pg        <- mkInputSyncFor(controller.qsfp[15].hsc.pg);
    Reg#(Bit#(1)) qsfp15_irq           <- mkInputSyncFor(controller.qsfp[15].irq);
    Reg#(Bit#(1)) qsfp15_prs           <- mkInputSyncFor(controller.qsfp[15].present);
    ReadOnly#(Bool) qsfp15_scl_out_en    <- mkOutputSyncFor(unpack(controller.qsfp[15].scl.out_en));
    ReadOnly#(Bit#(1)) qsfp15_scl_out     <- mkOutputSyncFor(controller.qsfp[15].scl.out);
    Reg#(Bit#(1)) qsfp15_scl_in           <- mkInputSyncFor(controller.qsfp[15].scl.in);
    TriState#(Bit#(1)) qsfp15_scl         <- mkTriState(qsfp15_scl_out_en, qsfp15_scl_out);
    mkConnection(sync(qsfp15_scl_in), qsfp15_scl._read);
    ReadOnly#(Bool) qsfp15_sda_out_en    <- mkOutputSyncFor(unpack(controller.qsfp[15].sda.out_en));
    ReadOnly#(Bit#(1)) qsfp15_sda_out     <- mkOutputSyncFor(controller.qsfp[15].sda.out);
    Reg#(Bit#(1)) qsfp15_sda_in           <- mkInputSyncFor(controller.qsfp[15].sda.in);
    TriState#(Bit#(1)) qsfp15_sda         <- mkTriState(qsfp15_sda_out_en, qsfp15_sda_out);
    mkConnection(sync(qsfp15_sda_in), qsfp15_sda._read);

    //
    // SPI Peripheral
    //

    Reg#(Bit#(1)) csn       <- mkInputSyncFor(controller.spi.csn);
    Reg#(Bit#(1)) sclk      <- mkInputSyncFor(controller.spi.sclk);
    Reg#(Bit#(1)) copi      <- mkInputSyncFor(controller.spi.copi);
    ReadOnly#(Bit#(1)) cipo <- mkOutputSyncFor(controller.spi.cipo);

    //
    // Power
    //

    //
    // PHY
    //
    ReadOnly#(Bool) phy_vr_en        <- mkOutputSyncFor(controller.vsc8562.v1p0.en);
    Reg#(Bool) phy_v1p0_pg           <- mkInputSyncFor(controller.vsc8562.v1p0.pg);
    Reg#(Bool) phy_v2p5_pg           <- mkInputSyncFor(controller.vsc8562.v2p5.pg);

    ReadOnly#(Bit#(1)) phy_coma_mode    <- mkOutputSyncFor(controller.vsc8562.coma_mode);
    ReadOnly#(Bit#(1)) phy_refclk_en    <- mkOutputSyncFor(controller.vsc8562.refclk_en);
    ReadOnly#(Bit#(1)) phy_reset_       <- mkOutputSyncFor(controller.vsc8562.reset_);

    ReadOnly#(Bit#(1)) phy_mdc          <- mkOutputSyncFor(controller.vsc8562.smi.mdc);
    Reg#(Bit#(1)) phy_mdint             <- mkInputSyncFor(controller.vsc8562.mdint);
    ReadOnly#(Bool) phy_mdio_out_en     <- mkOutputSyncFor(unpack(controller.vsc8562.smi.mdio.out_en));
    ReadOnly#(Bit#(1)) phy_mdio_out     <- mkOutputSyncFor(controller.vsc8562.smi.mdio.out);
    Reg#(Bit#(1)) phy_mdio_in           <- mkInputSyncFor(controller.vsc8562.smi.mdio.in);
    TriState#(Bit#(1)) phy_mdio         <- mkTriState(phy_mdio_out_en, phy_mdio_out);
    mkConnection(sync(phy_mdio_in), phy_mdio._read);

    //
    // Miscellaneous
    //
    ReadOnly#(Bit#(1)) fpga_led_blinky  <- mkOutputSyncFor(controller.blinky.led[0]);
    Reg#(Bit#(1)) fpga_app_id           <- mkInputSyncFor(controller.top.fpga_app_id);
    ReadOnly#(Bit#(1)) led_reset        <- mkOutputSyncFor(controller.top.led_controller_reset);
    ReadOnly#(Bit#(1)) led_oe           <- mkOutputSyncFor(controller.top.led_controller_output_en);
    Reg#(Bit#(1)) pmbus_v3p3_alert      <- mkInputSync();
    Reg#(Bit#(1)) vr_v3p3_pg            <- mkInputSync();

    //
    // Wire design out to the device pins
    //

    //
    // QSFP Ports
    //
    method fpga_to_qsfp_en_0            = qsfp0_hsc_en;
    method fpga_to_qsfp_lpmode_0        = qsfp0_lpmode;
    method fpga_to_qsfp_reset_l_0       = ~qsfp0_reset;
    method qsfp_to_fpga_pg_0            = sync(qsfp0_hsc_pg);
    method qsfp_to_fpga_irq_l_0         = sync_inverted(qsfp0_irq);
    method qsfp_to_fpga_present_l_0     = sync_inverted(qsfp0_prs);
    interface i2c_fpga_to_qsfp_scl_0    = qsfp0_scl.io;
    interface i2c_fpga_to_qsfp_sda_0    = qsfp0_sda.io;

    method fpga_to_qsfp_en_1            = qsfp1_hsc_en;
    method fpga_to_qsfp_lpmode_1        = qsfp1_lpmode;
    method fpga_to_qsfp_reset_l_1       = ~qsfp1_reset;
    method qsfp_to_fpga_pg_1            = sync(qsfp1_hsc_pg);
    method qsfp_to_fpga_irq_l_1         = sync_inverted(qsfp1_irq);
    method qsfp_to_fpga_present_l_1     = sync_inverted(qsfp1_prs);
    interface i2c_fpga_to_qsfp_scl_1    = qsfp1_scl.io;
    interface i2c_fpga_to_qsfp_sda_1    = qsfp1_sda.io;

    method fpga_to_qsfp_en_2            = qsfp2_hsc_en;
    method fpga_to_qsfp_lpmode_2        = qsfp2_lpmode;
    method fpga_to_qsfp_reset_l_2       = ~qsfp2_reset;
    method qsfp_to_fpga_pg_2            = sync(qsfp2_hsc_pg);
    method qsfp_to_fpga_irq_l_2         = sync_inverted(qsfp2_irq);
    method qsfp_to_fpga_present_l_2     = sync_inverted(qsfp2_prs);
    interface i2c_fpga_to_qsfp_scl_2    = qsfp2_scl.io;
    interface i2c_fpga_to_qsfp_sda_2    = qsfp2_sda.io;

    method fpga_to_qsfp_en_3            = qsfp3_hsc_en;
    method fpga_to_qsfp_lpmode_3        = qsfp3_lpmode;
    method fpga_to_qsfp_reset_l_3       = ~qsfp3_reset;
    method qsfp_to_fpga_pg_3            = sync(qsfp3_hsc_pg);
    method qsfp_to_fpga_irq_l_3         = sync_inverted(qsfp3_irq);
    method qsfp_to_fpga_present_l_3     = sync_inverted(qsfp3_prs);
    interface i2c_fpga_to_qsfp_scl_3    = qsfp3_scl.io;
    interface i2c_fpga_to_qsfp_sda_3    = qsfp3_sda.io;

    method fpga_to_qsfp_en_4            = qsfp4_hsc_en;
    method fpga_to_qsfp_lpmode_4        = qsfp4_lpmode;
    method fpga_to_qsfp_reset_l_4       = ~qsfp4_reset;
    method qsfp_to_fpga_pg_4            = sync(qsfp4_hsc_pg);
    method qsfp_to_fpga_irq_l_4         = sync_inverted(qsfp4_irq);
    method qsfp_to_fpga_present_l_4     = sync_inverted(qsfp4_prs);
    interface i2c_fpga_to_qsfp_scl_4    = qsfp4_scl.io;
    interface i2c_fpga_to_qsfp_sda_4    = qsfp4_sda.io;

    method fpga_to_qsfp_en_5            = qsfp5_hsc_en;
    method fpga_to_qsfp_lpmode_5        = qsfp5_lpmode;
    method fpga_to_qsfp_reset_l_5       = ~qsfp5_reset;
    method qsfp_to_fpga_pg_5            = sync(qsfp5_hsc_pg);
    method qsfp_to_fpga_irq_l_5         = sync_inverted(qsfp5_irq);
    method qsfp_to_fpga_present_l_5     = sync_inverted(qsfp5_prs);
    interface i2c_fpga_to_qsfp_scl_5    = qsfp5_scl.io;
    interface i2c_fpga_to_qsfp_sda_5    = qsfp5_sda.io;

    method fpga_to_qsfp_en_6            = qsfp6_hsc_en;
    method fpga_to_qsfp_lpmode_6        = qsfp6_lpmode;
    method fpga_to_qsfp_reset_l_6       = ~qsfp6_reset;
    method qsfp_to_fpga_pg_6            = sync(qsfp6_hsc_pg);
    method qsfp_to_fpga_irq_l_6         = sync_inverted(qsfp6_irq);
    method qsfp_to_fpga_present_l_6     = sync_inverted(qsfp6_prs);
    interface i2c_fpga_to_qsfp_scl_6    = qsfp6_scl.io;
    interface i2c_fpga_to_qsfp_sda_6    = qsfp6_sda.io;

    method fpga_to_qsfp_en_7            = qsfp7_hsc_en;
    method fpga_to_qsfp_lpmode_7        = qsfp7_lpmode;
    method fpga_to_qsfp_reset_l_7       = ~qsfp7_reset;
    method qsfp_to_fpga_pg_7            = sync(qsfp7_hsc_pg);
    method qsfp_to_fpga_irq_l_7         = sync_inverted(qsfp7_irq);
    method qsfp_to_fpga_present_l_7     = sync_inverted(qsfp7_prs);
    interface i2c_fpga_to_qsfp_scl_7    = qsfp7_scl.io;
    interface i2c_fpga_to_qsfp_sda_7    = qsfp7_sda.io;

    method fpga_to_qsfp_en_8            = qsfp8_hsc_en;
    method fpga_to_qsfp_lpmode_8        = qsfp8_lpmode;
    method fpga_to_qsfp_reset_l_8       = ~qsfp8_reset;
    method qsfp_to_fpga_pg_8            = sync(qsfp8_hsc_pg);
    method qsfp_to_fpga_irq_l_8         = sync_inverted(qsfp8_irq);
    method qsfp_to_fpga_present_l_8     = sync_inverted(qsfp8_prs);
    interface i2c_fpga_to_qsfp_scl_8    = qsfp8_scl.io;
    interface i2c_fpga_to_qsfp_sda_8    = qsfp8_sda.io;

    method fpga_to_qsfp_en_9            = qsfp9_hsc_en;
    method fpga_to_qsfp_lpmode_9        = qsfp9_lpmode;
    method fpga_to_qsfp_reset_l_9       = ~qsfp9_reset;
    method qsfp_to_fpga_pg_9            = sync(qsfp9_hsc_pg);
    method qsfp_to_fpga_irq_l_9         = sync_inverted(qsfp9_irq);
    method qsfp_to_fpga_present_l_9     = sync_inverted(qsfp9_prs);
    interface i2c_fpga_to_qsfp_scl_9    = qsfp9_scl.io;
    interface i2c_fpga_to_qsfp_sda_9    = qsfp9_sda.io;

    method fpga_to_qsfp_en_10            = qsfp10_hsc_en;
    method fpga_to_qsfp_lpmode_10        = qsfp10_lpmode;
    method fpga_to_qsfp_reset_l_10       = ~qsfp10_reset;
    method qsfp_to_fpga_pg_10            = sync(qsfp10_hsc_pg);
    method qsfp_to_fpga_irq_l_10         = sync_inverted(qsfp10_irq);
    method qsfp_to_fpga_present_l_10     = sync_inverted(qsfp10_prs);
    interface i2c_fpga_to_qsfp_scl_10    = qsfp10_scl.io;
    interface i2c_fpga_to_qsfp_sda_10    = qsfp10_sda.io;

    method fpga_to_qsfp_en_11            = qsfp11_hsc_en;
    method fpga_to_qsfp_lpmode_11        = qsfp11_lpmode;
    method fpga_to_qsfp_reset_l_11       = ~qsfp11_reset;
    method qsfp_to_fpga_pg_11            = sync(qsfp11_hsc_pg);
    method qsfp_to_fpga_irq_l_11         = sync_inverted(qsfp11_irq);
    method qsfp_to_fpga_present_l_11     = sync_inverted(qsfp11_prs);
    interface i2c_fpga_to_qsfp_scl_11    = qsfp11_scl.io;
    interface i2c_fpga_to_qsfp_sda_11    = qsfp11_sda.io;

    method fpga_to_qsfp_en_12            = qsfp12_hsc_en;
    method fpga_to_qsfp_lpmode_12        = qsfp12_lpmode;
    method fpga_to_qsfp_reset_l_12       = ~qsfp12_reset;
    method qsfp_to_fpga_pg_12            = sync(qsfp12_hsc_pg);
    method qsfp_to_fpga_irq_l_12         = sync_inverted(qsfp12_irq);
    method qsfp_to_fpga_present_l_12     = sync_inverted(qsfp12_prs);
    interface i2c_fpga_to_qsfp_scl_12    = qsfp12_scl.io;
    interface i2c_fpga_to_qsfp_sda_12    = qsfp12_sda.io;

    method fpga_to_qsfp_en_13            = qsfp13_hsc_en;
    method fpga_to_qsfp_lpmode_13        = qsfp13_lpmode;
    method fpga_to_qsfp_reset_l_13       = ~qsfp13_reset;
    method qsfp_to_fpga_pg_13            = sync(qsfp13_hsc_pg);
    method qsfp_to_fpga_irq_l_13         = sync_inverted(qsfp13_irq);
    method qsfp_to_fpga_present_l_13     = sync_inverted(qsfp13_prs);
    interface i2c_fpga_to_qsfp_scl_13    = qsfp13_scl.io;
    interface i2c_fpga_to_qsfp_sda_13    = qsfp13_sda.io;

    method fpga_to_qsfp_en_14            = qsfp14_hsc_en;
    method fpga_to_qsfp_lpmode_14        = qsfp14_lpmode;
    method fpga_to_qsfp_reset_l_14       = ~qsfp14_reset;
    method qsfp_to_fpga_pg_14            = sync(qsfp14_hsc_pg);
    method qsfp_to_fpga_irq_l_14         = sync_inverted(qsfp14_irq);
    method qsfp_to_fpga_present_l_14     = sync_inverted(qsfp14_prs);
    interface i2c_fpga_to_qsfp_scl_14    = qsfp14_scl.io;
    interface i2c_fpga_to_qsfp_sda_14    = qsfp14_sda.io;

    method fpga_to_qsfp_en_15            = qsfp15_hsc_en;
    method fpga_to_qsfp_lpmode_15        = qsfp15_lpmode;
    method fpga_to_qsfp_reset_l_15       = ~qsfp15_reset;
    method qsfp_to_fpga_pg_15            = sync(qsfp15_hsc_pg);
    method qsfp_to_fpga_irq_l_15         = sync_inverted(qsfp15_irq);
    method qsfp_to_fpga_present_l_15     = sync_inverted(qsfp15_prs);
    interface i2c_fpga_to_qsfp_scl_15    = qsfp15_scl.io;
    interface i2c_fpga_to_qsfp_sda_15    = qsfp15_sda.io;

    //
    // SPI Peripheral
    //

    method spi_main_to_fpga_cs1_l   = sync(csn);
    method spi_main_to_fpga_sck     = sync(sclk);
    method spi_main_to_fpga_mosi    = sync(copi);
    method spi_main_to_fpga_miso_r  = cipo;

    //
    // Power
    //

    //
    // PHY
    //

    method fpga_to_vr_phy_en        = phy_vr_en;
    method vr_v1p0_phy_to_fpga_pg   = sync(phy_v1p0_pg);
    method vr_v2p5_phy_to_fpga_pg   = sync(phy_v2p5_pg);

    method fpga_to_phy_refclk_en    = phy_refclk_en;
    method fpga_to_phy_coma_mode    = phy_coma_mode;
    method fpga_to_phy_reset_l      = ~phy_reset_;

    method miim_fpga_to_phy_mdc     = phy_mdc;
    method miim_phy_to_fpga_mdint_l = sync_inverted(phy_mdint);
    interface miim_fpga_to_phy_mdio = phy_mdio.io;

    //
    // Miscellaneous
    //

    method Bit#(1)  fpga_to_vr_v3p3_qsfp_en = 1;
    method vr_v3p3_qsfp_to_fpga_pg          = sync(vr_v3p3_pg);
    method pmbus_v3p3_qsfp_to_fpga_alert    = sync(pmbus_v3p3_alert);

    method Bit#(1) fpga_to_main_irq_r_l     = 1;
    method Bit#(1) fpga_led                 = fpga_led_blinky;
    method Bit#(1) fpga_to_leds0_reset_l    = ~led_reset;
    method Bit#(1) fpga_to_leds0_oe_l       = ~led_oe;
    method fpga_app_id_r                    = sync(fpga_app_id);
    method Bit#(8) debug_fpga_io            = {
                        1'b0,   // Bit 7, J31 pin 10
                        1'b0,   // Bit 6, J31 pin 9
                        1'b0,   // Bit 5, J31 pin 8
                        1'b0,   // Bit 4, J31 pin 7
                        qsfp1_sda,   // Bit 3, J31 pin 4
                        qsfp1_scl,   // Bit 2, J31 pin 3
                        qsfp0_sda,   // Bit 1, J31 pin 2
                        qsfp0_scl};  // Bit 0, J31 pin 1
endmodule

endpackage: QsfpX32ControllerTop