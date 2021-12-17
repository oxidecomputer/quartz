package Tofino2PowerCtrlTest;

// BSV
import Assert::*;
import ClientServer::*;
import Clocks::*;
import Connectable::*;
import GetPut::*;
import StmtFSM::*;

// Oxide
import Tofino2PowerCtrl::*;
import TestUtils::*;

instance Connectable#(PulseWire, PulseWire);
    module mkConnection#(PulseWire a, PulseWire b)(Empty);
        (* fire_when_enabled *)
        rule do_pulse(a);
            b.send();
        endrule
    endmodule
endinstance

(* synthesize *)
module mkTofino2PowerCtrlTestTop(Empty);
    let parameters =
        Tofino2SequenceControlParameters {
            power_good_timeout: 10,
            power_good_delay: 2,
            vid_delay: 10,
            pcie_delay: 20};
    Tofino2SequenceControl tf2 <- mkTofino2SequenceControl(parameters);

    Reg#(Bit#(1)) vdd18_pg <- mkReg(0);
    Reg#(Bit#(1)) core_pg <- mkReg(0);
    Reg#(Bit#(1)) pcie_pg <- mkReg(0);
    Reg#(Bit#(1)) vddt_pg <- mkReg(0);
    Reg#(Bit#(1)) vdda15_pg <- mkReg(0);
    Reg#(Bit#(1)) vdda18_pg <- mkReg(0);
    PulseWire tick_1ms <- mkPulseWire();
    Reg#(UInt#(2)) tick_cntr <- mkReg(0);
    Reg#(Bit#(8)) seq_state <- mkReg(0);
    Reg#(Bit#(8)) seq_error <- mkReg(0);

    mkConnection(vdd18_pg, tf2.vdd18.pins.pg);
    mkConnection(core_pg, tf2.vddcore.pins.pg);
    mkConnection(pcie_pg, tf2.vddpcie.pins.pg);
    mkConnection(vddt_pg, tf2.vddt.pins.pg);
    mkConnection(vdda15_pg, tf2.vdda15.pins.pg);
    mkConnection(vdda18_pg, tf2.vdda18.pins.pg);
    mkConnection(asIfc(tick_1ms), asIfc(tf2.tick_1ms));

    function Action assert_rail_enabled(PowerRail rail, String s) =
        dynamicAssert(rail.pins.en == 1, s);

    (* fire_when_enabled *)
    rule tick_count_down(tick_cntr > 0);
        tick_cntr <= satMinus(Sat_Zero, tick_cntr, 1);
    endrule

    (* fire_when_enabled *)
    rule tick_fire(tick_cntr == 0);
        tick_1ms.send();
        tick_cntr <= 3;
    endrule

    (* fire_when_enabled, no_implicit_conditions *)
    rule do_update_seq_regs;
        seq_state   <= {'0, pack(tf2.regs.state)};
        seq_error   <= {'0, pack(tf2.regs.error)};
    endrule

    Stmt powerSequence =
    (seq
        tf2.start_power_up();
        await(tf2.vdd18.enabled);
        vdd18_pg <= 1;
        await(tf2.vddcore.enabled);
        core_pg <= 1;
        await(tf2.vddpcie.enabled);
        pcie_pg <= 1;
        await(tf2.vddt.enabled);
        vddt_pg <= 1;
        await(tf2.vdda15.enabled);
        vdda15_pg <= 1;
        await(tf2.vdda18.enabled);
        vdda18_pg <= 1;
        await(tf2.pwron_rst_l == 1);
        await(tf2.pcie_rst_l == 1);
        await(tf2.tofino_power_good == 1);
        await(tf2.regs.state == AwaitPowerDown);
        $display("Tofino 2 powered up!");

        tf2.start_power_down();
        await(tf2.tofino_power_good == 0);
        await(tf2.pcie_rst_l == 0);
        await(tf2.pwron_rst_l == 0);
        await(!tf2.vdda18.enabled);
        vdda18_pg <= 0;
        await(!tf2.vdda15.enabled);
        vdda15_pg <= 0;
        await(!tf2.vddt.enabled);
        vddt_pg <= 0;
        await(!tf2.vddpcie.enabled);
        pcie_pg <= 0;
        await(!tf2.vddcore.enabled);
        core_pg <= 0;
        await(!tf2.vdd18.enabled);
        vdd18_pg <= 0;
        await(tf2.regs.state == AwaitPowerUp);
        $display("Tofino 2 powered down");
    endseq);

    mkAutoFSM(powerSequence);

    mkTestWatchdog(10_000);
endmodule

endpackage: Tofino2PowerCtrlTest