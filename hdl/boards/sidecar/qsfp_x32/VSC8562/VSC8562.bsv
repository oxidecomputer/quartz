// Copyright 2022 Oxide Computer Company
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package VSC8562;

export Parameters(..), Pins(..), Registers(..);
export VSC8562(..), mkVSC8562;

import Assert::*;
import DefaultValue::*;
import DReg::*;
import GetPut::*;
import StmtFSM::*;
import Vector::*;

import Bidirection::*;
import PowerRail::*;
import MDIO::*;

import CommonFunctions::*;
import QsfpX32ControllerRegsPkg::*;

// Parameters used to configure various things within the block
// system_frequency_hz      - main clock domain for the design
// mdc_frequency_hz         - MDC frequency for the SMI interface, max of
//                            12.5MHz per section 3.14 of the VSC8562 datasheet,
//                            but has shown spotty behavior at speeds 8MHz+.
//              see https://github.com/oxidecomputer/hardware-qsfp-x32/issues/22
// power_good_timeout_ms    - how long to wait for PG on the PHY rails before
//                            aborting
// refclk_en_to_stable_ms   - time from refclk enable to a stable output
// reset_release_to_ready_ms- time from reset release to the SMI being ready
typedef struct {
    Integer system_frequency_hz;
    Integer mdc_frequency_hz;
    Integer power_good_timeout_ms;
    Integer refclk_en_to_stable_ms;
    Integer reset_release_to_ready_ms;
} Parameters;

instance DefaultValue#(Parameters);
    defaultValue = Parameters {
        system_frequency_hz: 50_000_000,
        mdc_frequency_hz: 3_000_000,
        power_good_timeout_ms: 0, // TODO: determine what this should be
        refclk_en_to_stable_ms: 5,
        reset_release_to_ready_ms: 120
    };
endinstance

// Serial Management Interface (see section 3.14 Serial Management Interface):
//
// The SMI code presents a register interface, accessible via SPI, that will
// take register contents and manage a SMI transaction with the VSC8562.
//
// PHY_SMI_STATUS       - State of the SMI FSM.
// PHY_SMI_RDATA_{H,L}  - Data read back from the VSC8562.
// PHY_SMI_WDATA_{H,L}  - Data to be written to the VSC8562.
// PHY_SMI_PHY_ADDR     - Address of which PHY to communicate with
// PHY_SMI_REG_ADDR     - Register address for the transaction
// PHY_SMI_CTRL         - Denote Read or Write with the RW bit, begin with START
interface Registers;
    interface ReadOnly#(PhyStatus) phy_status;
    interface Reg#(PhyCtrl) phy_ctrl;
    interface ReadOnly#(PhySmiStatus) phy_smi_status;
    interface Reg#(PhySmiRdataH) phy_smi_rdata_h;
    interface Reg#(PhySmiRdataL) phy_smi_rdata_l;
    interface Reg#(PhySmiWdataH) phy_smi_wdata_h;
    interface Reg#(PhySmiWdataL) phy_smi_wdata_l;
    interface Reg#(PhySmiPhyAddr) phy_smi_phy_addr;
    interface Reg#(PhySmiRegAddr) phy_smi_reg_addr;
    interface Reg#(PhySmiCtrl) phy_smi_ctrl;
endinterface

interface Pins;
    interface PowerRail::Pins v1p0;
    interface PowerRail::Pins v2p5;
    interface MDIO::Pins smi;
    method Bit#(1) coma_mode;
    method Bit#(1) refclk_en;
    method Bit#(1) reset_;
    method Action mdint(Bit#(1) val);
endinterface

interface VSC8562;
    interface Pins pins;
    interface Registers registers;
    method Action tick_1ms(Bool val);
endinterface

// mkVSC8562
//
// Implementation of the sequencing and Serial Management Interface (SMI) for a
// VSC8562-11 ethernet PHY/MAC.
//
// Sequencing (essentially steps 1 through 5 in datasheet section 3.21
//  Configuration) occurs when the EN bit in the PHY_CTRL register is set:
//
//  1. Drive coma_mode high
//  2. Enable 1.0V VR (whose PG signal cascades to the EN pin on the 2.5V VR)
//      - Wait for PG from both 1.0V and 2.5V VRs
//      - TODO: as it stands the sequencing FSM will just hang here if PG does
//          not go high for both rails, requiring the clear/set of PHY_CTRL.EN
//  3. Drive refclk_en high, wait for it to stabilize
//  4. Now that power and clock are stable, release reset
//  5. Wait a delay after reset release before releasing device to software
//
// The PHY_STATUS register has bits to show the status of sequencing.
//
module mkVSC8562 #(Parameters parameters) (VSC8562);
    staticAssert(parameters.mdc_frequency_hz <= 12_500_000,
        "Maximum MDC frequency is 12.5 MHz");

    PowerRail#(5) v1p0 <-
        mkPowerRailLeaveEnabledOnAbort(parameters.power_good_timeout_ms);
    PowerRail#(5) v2p5 <-
        mkPowerRailLeaveEnabledOnAbort(parameters.power_good_timeout_ms);

    // Serial Management Interface (see section 3.14 of datasheet)
    MDIO smi <- mkMDIO(MDIO::Parameters{
        system_frequency_hz: parameters.system_frequency_hz,
        mdc_frequency_hz: parameters.mdc_frequency_hz
    });

    // SPI register interface
    Reg#(PhyCtrl) phy_ctrl              <- mkReg(defaultValue);
    Reg#(PhySmiRdataH) smi_rdata_h      <- mkReg(defaultValue);
    Reg#(PhySmiRdataL) smi_rdata_l      <- mkReg(defaultValue);
    Reg#(PhySmiWdataH) smi_wdata_h      <- mkReg(defaultValue);
    Reg#(PhySmiWdataL) smi_wdata_l      <- mkReg(defaultValue);
    Reg#(PhySmiPhyAddr) smi_phy_addr    <- mkReg(defaultValue);
    Reg#(PhySmiRegAddr) smi_reg_addr    <- mkReg(defaultValue);
    Reg#(PhySmiCtrl) smi_ctrl           <- mkDReg(defaultValue);

    // True after the PHY has gone through initial sequencing
    Reg#(Bool) phy_ready        <- mkReg(False);
    PulseWire phy_abort         <- mkPulseWire();

    // Configuration pin registers
    Reg#(Bit#(1)) coma_mode     <- mkReg(0);
    Reg#(Bit#(1)) refclk_en     <- mkReg(0);
    Reg#(Bit#(1)) reset_        <- mkReg(1);

    // SMI interrupt pin regsiter
    Reg#(Bit#(1)) mdint         <- mkReg(0);

    // Logic for rough counting by milliseconds. Since this is configured
    // external to this module, there is not really a way to tell how long until
    // the next 1 ms pulse occurs (could be next clock cycle, could be 1 ms),
    // but given how nothing here is that fine grained this is OK
    Wire#(Bool) tick_1ms_       <- mkWire();
    Reg#(UInt#(7)) ms_cntr      <- mkReg(0);
    PulseWire reset_ms_cntr     <- mkPulseWire();

    Reg#(Bool) coma_mode_hw     <- mkReg(True);
    Reg#(Bool) smi_busy         <- mkReg(False);
    Reg#(Bit#(16)) read_data_r  <- mkReg(0);

    // The hot swaps expected a tick to correspond with its timeout
    (* fire_when_enabled *)
    rule do_hot_swap_tick (tick_1ms_);
        v1p0.send();
        v2p5.send();
    endrule

    // VSC8562 power-on sequence
    // On the physical board, the V2P5 regulator enable is wired to the power
    // good of the V1P0 regulator. This means that v2p5.set_enable(True) does
    // not actually do anything physically on the board, but it does modify the
    // internal state of the v2p5 PowerRail instance so it will start to monitor
    // the V2P5 power good signal.
    // TODO: verify timeout duration and await on the PowerRails' enabled method
    FSM vsc8562_power_on_seq <- mkFSMWithPred(seq
            coma_mode_hw    <= True;
            v1p0.set_enable(True);
            await(v1p0.pin_state.enable && v1p0.pin_state.good);
            v2p5.set_enable(True);
            await(v2p5.pin_state.enable && v2p5.pin_state.good);
            refclk_en       <= 1;
            await(ms_cntr == fromInteger(parameters.refclk_en_to_stable_ms + 1));
            reset_ms_cntr.send();
            reset_          <= 0;
            await(ms_cntr == fromInteger(parameters.reset_release_to_ready_ms + 1));
            reset_ms_cntr.send();
            coma_mode_hw    <= False;   // relinquish COMA_MODE control to SW
            phy_ready       <= True;
        endseq, phy_ctrl.en == 1);

    // VSC8562 power down sequence (no special requirements noted in datasheet)
    FSM vsc8562_power_down_seq <- mkFSMWithPred(seq
            phy_ready       <= False;
            reset_          <= 1;
            refclk_en       <= 0;
            coma_mode_hw    <= False;
            v1p0.set_enable(False);
        endseq, phy_ctrl.en == 0);

    // This allows hardware to override COMA_MODE control during initial
    // power-on sequencing and then hand it over to software control after
    (* fire_when_enabled, no_implicit_conditions *)
    rule do_coma_mode_comb;
        coma_mode   <= pack(coma_mode_hw ||
                            (unpack(phy_ctrl.coma_mode) && phy_ready));
    endrule

    (* fire_when_enabled *)
    rule do_power_up_vsc8562(phy_ctrl.en == 1 && !phy_ready);
        vsc8562_power_on_seq.start();
    endrule

    (* fire_when_enabled *)
    rule do_power_down_vsc8562(phy_ctrl.en == 0);
        vsc8562_power_on_seq.abort();
        vsc8562_power_down_seq.start();
    endrule

    (* fire_when_enabled *)
    rule do_ms_cntr(!vsc8562_power_on_seq.done());
        if (reset_ms_cntr) begin
            ms_cntr <= 0;
        end else if (tick_1ms_) begin
            ms_cntr <= ms_cntr + 1;
        end
    endrule

    (* fire_when_enabled *)
    rule do_smi_busy;
        smi_busy    <= smi.busy;
    endrule

    (* fire_when_enabled *)
    rule do_start_smi_transaction (phy_ready && smi_ctrl.start == 1);
        smi.command.put(Command {
            read: unpack(~smi_ctrl.rw),
            phy_addr: smi_phy_addr.addr,
            reg_addr: smi_reg_addr.addr,
            write_data: {smi_wdata_h.data, smi_wdata_l.data}
        });
    endrule

    (* fire_when_enabled *)
    rule do_handle_smi_read_data (phy_ready);
        let read_data       <- smi.read_data.get();
        smi_rdata_h.data    <= read_data[15:8];
        smi_rdata_l.data    <= read_data[7:0];
    endrule

    interface Registers registers;
        interface ReadOnly phy_status   = valueToReadOnly(
            PhyStatus{
                en_v1p0: pack(v1p0.pin_state.enable),
                pg_v1p0: pack(v1p0.pin_state.good),
                pg_v2p5: pack(v2p5.pin_state.good),
                coma_mode: coma_mode,
                refclk_en: refclk_en,
                reset: ~reset_,
                ready: pack(phy_ready)
            });
        interface Reg phy_ctrl          = phy_ctrl;
        interface ReadOnly phy_smi_status   = valueToReadOnly(
            PhySmiStatus{
                busy: pack(smi_busy),
                mdint: mdint
            });
        interface Reg phy_smi_rdata_h       = smi_rdata_h;
        interface Reg phy_smi_rdata_l       = smi_rdata_l;
        interface Reg phy_smi_wdata_h       = smi_wdata_h;
        interface Reg phy_smi_wdata_l       = smi_wdata_l;
        interface Reg phy_smi_phy_addr      = smi_phy_addr;
        interface Reg phy_smi_reg_addr      = smi_reg_addr;
        interface Reg phy_smi_ctrl          = smi_ctrl;
    endinterface

    interface Pins pins;
        interface PowerRail::Pins v1p0 = v1p0.pins;
        interface PowerRail::Pins v2p5 = v2p5.pins;
        interface MDIO::Pins smi = smi.pins;

        method coma_mode    = coma_mode;
        method refclk_en    = refclk_en;
        method reset_       = reset_;
        method mdint        = mdint._write;
    endinterface

    method tick_1ms = tick_1ms_._write;
endmodule

endpackage: VSC8562
