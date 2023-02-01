// Copyright 2023 Oxide Computer Company
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package VSC8562Tests;

import Connectable::*;
import GetPut::*;
import StmtFSM::*;

import Bidirection::*;
import PowerRail::*;
import Strobe::*;
import TestUtils::*;

import VSC8562::*;
import QsfpX32ControllerRegsPkg::*;
import MDIO::*;
import MDIOPeripheralModel::*;

VSC8562::Parameters test_params = Parameters {
    system_frequency_hz: 50_000,
    mdc_frequency_hz: 3_000,
    power_good_timeout_ms: defaultValue.power_good_timeout_ms,
    refclk_en_to_stable_ms: defaultValue.refclk_en_to_stable_ms,
    reset_release_to_ready_ms: defaultValue.reset_release_to_ready_ms
};

// Arbitrary PHY Address
Bit#(5) model_phy_addr = 5'h1D;

interface Bench;
    // The SPI register interface for this peripheral
    interface VSC8562::Registers registers;

    // inputs from VSC8562 power supplies
    method Action v1p0_pg(Bool v);
    method Action v2p5_pg(Bool v);

    // inputs from VSC8562 PHY
    method Action mdint(Bit#(1) v);

    // outputs to VSC8562 PHY
    method Bit#(1) refclk_en;
    method Bit#(1) reset_;
    method Bit#(1) coma_mode;
endinterface

module mkBench (Bench);

    // Intiatiation of the VSC8562 block as the DUT
    VSC8562 dut <- mkVSC8562(test_params);
    MDIOPeripheralModel model
        <- mkMDIOPeripheralModel(model_phy_addr);

    // wire the DUT to the model
    mkConnection(dut.pins.smi.mdc, model.pins.mdc);
    mkConnection(dut.pins.smi.mdio.out, model.pins.mdio.in);
    mkConnection(dut.pins.smi.mdio.in, model.pins.mdio.out);
    // Since bluesim cannot simulate tristates, use the out_en pin of the
    // controller to squelch the output of the model
    mkConnection(dut.pins.smi.mdio.out_en, model.mdio_ctrl_out_en);

    // Registers for power good inputs. These are open-drain and thus pulled up
    // on the board, but will be set low out of reset just to simulate the
    // device behavior.
    Reg#(Bool) v1p0_pg_r <- mkReg(False);
    Reg#(Bool) v2p5_pg_r <- mkReg(False);

    // Register for mdint from the PHY
    Reg#(Bit#(1)) mdint_r <- mkReg(0);

    Strobe#(16) tick_1khz   <-
        mkLimitStrobe(1, test_params.system_frequency_hz / 1000, 0);
    mkFreeRunningStrobe(tick_1khz);

    // Wire test bench signals into the DUT
    mkConnection(tick_1khz._read, dut.tick_1ms);
    mkConnection(dut.pins.v1p0.pg, v1p0_pg_r);
    mkConnection(dut.pins.v2p5.pg, v2p5_pg_r);
    mkConnection(dut.pins.mdint, mdint_r);

    // Not paying attention to these details events so just drop them, allowing
    // the internal model logic to continue to fire
    rule do_drop_model_events;
        let _ <- model.events.get();
    endrule

    method v1p0_pg = v1p0_pg_r._write;
    method v2p5_pg = v2p5_pg_r._write;
    method mdint = mdint_r._write;

    method refclk_en = dut.pins.refclk_en;
    method reset_ = dut.pins.reset_;
    method coma_mode = dut.pins.coma_mode;

    interface registers = dut.registers;
endmodule

// helper sequence to get through the power up sequence in the module
function Stmt power_up_sequence(Bench bench);
    return (seq
        bench.v1p0_pg(True);
        bench.v2p5_pg(True);
        await(bench.reset_ == 0);
        await(bench.registers.phy_status.ready == 1);
        assert_not_set(bench.registers.phy_status.pg_timed_out,
            "PG timeout should not have ocurred during a successful power up");
    endseq);
endfunction

// mkPowerOnByDefaultTest
//
// This test verifies that the PHY power supplies are enabled by default. The
// design does this by having the reset value of the PHY_CTRL.EN bit be 1'b1.
module mkPowerOnByDefaultTest (Empty);
    Bench bench <- mkBench();

    mkAutoFSM(seq
        delay(5);
        assert_set(bench.coma_mode(),
            "Coma mode should not be released until the PHY is powered");
        assert_not_set(bench.refclk_en(),
            "Refclk should not be enabled until the PHY is powered");
        assert_set(bench.reset_(),
            "Reset should not be released until the PHY is powered");
        bench.v1p0_pg(True);
        delay(3);
        bench.v2p5_pg(True);
        delay(3);
        assert_set(bench.coma_mode(),
            "Coma mode should not be released until refclk is stable");
        assert_set(bench.refclk_en(),
            "Refclk should be enabled after supplies are up");
        assert_set(bench.reset_(),
            "Reset should not be released until refclk is stable");
        await(bench.reset_ == 0);
        await(bench.registers.phy_status.ready == 1);
        delay(5);
    endseq);
endmodule

// mkComaModeTest
//
// This test verifies that the software/hardware control around the PHY's coma
// mode pin work as intended. That is, that hardware holds the pin asserted
// until the PHY has been properly initialized, at which point it releases
// further control of the pin to the PHY_CTRL.COMA_MODE bit.
module mkComaModeTest (Empty);
    Bench bench <- mkBench();

    mkAutoFSM(seq
        delay(5);
        assert_set(bench.coma_mode(),
            "Coma mode should be asserted while the PHY is not sequenced");
        bench.registers.phy_ctrl.coma_mode <= 0;
        assert_set(bench.coma_mode(),
            "Coma mode ignores the software register until PHY is sequenced");
        power_up_sequence(bench);
        assert_not_set(bench.coma_mode(),
            "Coma mode should reflect the software register after the PHY is sequenced");
        delay(5);
    endseq);
endmodule

// mkPowerDownTest
//
// This test verifies that the power down sequence is follows should PHY_CTRL.EN
// be cleared.
module mkPowerDownTest (Empty);
    Bench bench <- mkBench();

    mkAutoFSM(seq
        delay(5);
        power_up_sequence(bench);
        bench.registers.phy_ctrl.en <= 0;
        delay(5);
        assert_not_set(bench.registers.phy_status.ready,
            "PHY should not be ready when disabled");
        assert_not_set(bench.coma_mode(),
            "Coma mode should be released until the PHY is enabled");
        assert_not_set(bench.refclk_en(),
            "Refclk should not be enabled until the PHY is enabled");
        assert_set(bench.reset_(),
            "Reset should not be released until the PHY is enabled");
        bench.v1p0_pg(False);
        bench.v2p5_pg(False);
        delay(5);
    endseq);
endmodule

// mkPowerGoodTimeoutTest
//
// This test verifies that the power good timeout will abort power sequencing
// and prevent it from starting until the timed out fault has been cleared.
module mkPowerGoodTimeoutTest (Empty);
    Bench bench <- mkBench();

    mkAutoFSM(seq
        assert_not_set(bench.registers.phy_status.pg_timed_out,
            "PG timeout should not have ocurred immediately after reset");
        await(bench.registers.phy_status.pg_timed_out == 1);
        delay(1); // need a cycle for the power down sequence to kick off
        assert_not_set(bench.registers.phy_status.ready,
            "PHY should not be ready when unpowered");
        assert_not_set(bench.coma_mode(),
            "Coma mode should be released until the PHY is unpowered");
        assert_not_set(bench.refclk_en(),
            "Refclk should not be enabled until the PHY is unpowered");
        assert_set(bench.reset_(),
            "Reset should not be released until the PHY is unpowered");
        bench.registers.phy_ctrl.clear_power_fault <= 1;
        assert_not_set(bench.registers.phy_status.pg_timed_out,
            "PG timeout should not be present after it was just cleared");
        power_up_sequence(bench);
        delay(5);
    endseq);
endmodule

// mkSmiTest
//
// This test verifies that SMI (MDIO) transactions work via the exposed SPI
// register interface;
module mkSmiTest (Empty);
    Bench bench <- mkBench();

    mkAutoFSM(seq
        delay(5);
        bench.registers.phy_smi_wdata1 <= PhySmiWdata1 {data: 8'hDE};
        bench.registers.phy_smi_wdata0 <= PhySmiWdata0 {data: 8'hAF};
        bench.registers.phy_smi_phy_addr <= PhySmiPhyAddr {
            addr: model_phy_addr};
        bench.registers.phy_smi_ctrl <= PhySmiCtrl {
            rw: 1'b1, // write
            start: 1'b1};
        assert_not_set(bench.registers.phy_smi_status.busy,
            "SMI status should not show as busy when PHY is unpowered");

        power_up_sequence(bench);
        assert_not_set(bench.registers.phy_smi_status.busy,
            "SMI status should not show as busy when prior to a transaction");
        bench.registers.phy_smi_ctrl <= PhySmiCtrl {
            rw: 1'b1, // write
            start: 1'b1};
        delay(4); // wait for transaction to start and busy to propagate
        assert_set(bench.registers.phy_smi_status.busy,
            "SMI status should show as busy when executing a transaction");
        // wait for the transaction to finish
        await(bench.registers.phy_smi_status.busy == 0());

        bench.registers.phy_smi_ctrl <= PhySmiCtrl {
            rw: 1'b0, // read
            start: 1'b1};
        delay(4);
        assert_set(bench.registers.phy_smi_status.busy,
            "SMI status should show as busy when executing a transaction");
        // wait for the transaction to finish
        await(bench.registers.phy_smi_status.busy == 0);
        assert_eq(pack(bench.registers.phy_smi_rdata1),
                pack(bench.registers.phy_smi_wdata1),
                "Data read back should match what was written");
        assert_eq(pack(bench.registers.phy_smi_rdata0),
                pack(bench.registers.phy_smi_wdata0),
                "Data read back should match what was written");
        delay(5);
    endseq);
endmodule

// mkMdintTest
//
// This test verifies that the MDINT input shows up in the approriate
// SPI-exposed register (PHY_SMI_STATUS.MDINT).
module mkMdintTest (Empty);
    Bench bench <- mkBench();

    mkAutoFSM(seq
        delay(5);
        bench.mdint(0);
        assert_not_set(bench.registers.phy_smi_status.mdint,
            "MDINT should not be asserted when the input pin is not asserted");
        bench.mdint(1);
        delay(1); // let the signal propagate through the bench register stage
        assert_set(bench.registers.phy_smi_status.mdint,
            "MDINT should be asserted when the input pin asserted");
        delay(5);
    endseq);
endmodule

endpackage
