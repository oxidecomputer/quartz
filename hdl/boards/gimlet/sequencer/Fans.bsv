// Copyright 2021 Oxide Computer Company

package Fans;

import GetPut::*;
import StmtFSM::*;

interface FansPinsIfc;
    // Fans interface
    method Bit#(1) seq_to_fanhp_restart_l();  // Strobe low
    (* prefix = "" *)
    method Action fanhp_to_seq_fault_l((* port = "fanhp_to_seq_fault_l" *) Bit#(1) val);
    method Bit#(1) seq_to_fan_hp_en();
    (* prefix = "" *)
    method Action fan_to_seq_fan_fail((* port = "fan_to_seq_fan_fail" *) Bit#(1) val);
    method Action fanhp_to_seq_pwrgd(Bit#(1) val);
endinterface

interface FansRegsIfc;
    interface Put#(FanControl) control;
    interface Get#(FanStatus) status;
endinterface

interface FansBlockIfc;
    interface FansRegsIfc regs;
    interface FansPinsIfc pins;
endinterface

typedef struct {
    Bit#(1) restart;
    Bit#(1) enable;
} FanControl deriving (Bits);
typedef struct {
    Bit#(1) fanhp_fault;
    Bit#(1) fan_fail;
    Bit#(1) fanhp_pwrgd;
    Bool fan_pwr_ok;
} FanStatus deriving (Bits);
// Fan control block.
// Fans_ok feeds the A0 and A1 domain state machines since fans ok is a prereq
// Fan fault/fail to register block.
module mkFansBlock(FansBlockIfc);
    // Block Input
    Reg#(Bit#(1)) fan_fail <- mkReg(0);
    Reg#(Bit#(1)) fanhp_fault <- mkReg(0);
    Reg#(Bit#(1)) fanhp_pwrgd <- mkReg(0);
    RWire#(FanControl) in_ctrl <- mkRWire();

    // Block Output
    Reg#(Bit#(1)) restart_l_pin <- mkReg(1);
    Reg#(Bit#(1)) fanhp_en <- mkReg(0);
    RWire#(FanStatus) out_status <- mkRWire();

    // Deal with block outputs.
    (* no_implicit_conditions, fire_when_enabled *)
    rule do_enable;
        // Hold our current value or pick up a new command from the register block
      let next_enable = isValid(in_ctrl.wget()) ? fromMaybe(?, in_ctrl.wget()).enable : fanhp_en;
      fanhp_en <= next_enable;
    endrule
    // TODO: deal with pulsing restart if we want it

    // deal with status
    (* no_implicit_conditions, fire_when_enabled *)
    rule do_status;
        let fan_pwr_ok = (fanhp_fault == 0) && (fan_fail == 0) && (fanhp_pwrgd == 1) && (fanhp_en == 1);
        let next_status = FanStatus {fanhp_fault: fanhp_fault, fan_fail: fan_fail, fanhp_pwrgd: fanhp_pwrgd, fan_pwr_ok: fan_pwr_ok};
        out_status.wset(next_status);
    endrule

    // Do the pins interface
    interface FansPinsIfc pins;
        method Bit#(1) seq_to_fanhp_restart_l();
            return restart_l_pin;
        endmethod
        
        method Action fanhp_to_seq_fault_l(Bit#(1) val);
            fanhp_fault <= ~val;
        endmethod
        
        method Bit#(1) seq_to_fan_hp_en();
            return fanhp_en;
        endmethod

        method Action fan_to_seq_fan_fail(Bit#(1) val);
            fan_fail <= val;
        endmethod

        method Action fanhp_to_seq_pwrgd(Bit#(1) val);
            fanhp_pwrgd <= val;
        endmethod
    endinterface

    // Do the regs interface
    interface FansRegsIfc regs;
        interface Put control;
            method Action put(FanControl d);
                in_ctrl.wset(d);
            endmethod
        endinterface
            
        interface Get status;
            method ActionValue#(FanStatus) get();
                return fromMaybe(?, out_status.wget());
            endmethod
        endinterface
    endinterface

endmodule

module mkFansBlockSimpleTest(Empty);
    FansBlockIfc fans <- mkFansBlock();
    Reg#(UInt#(4)) cntr <- mkReg(0);

    rule do_counter;
        cntr <= cntr + 1;
    endrule

    rule do_reset (cntr == 0);
        fans.pins.fanhp_to_seq_fault_l(1);
        fans.pins.fan_to_seq_fan_fail(0);
        fans.pins.fanhp_to_seq_pwrgd(0);

        
    endrule
    rule do_enable (cntr == 1);
        let ctrl = FanControl {restart: 0, enable: 1};
        fans.regs.control.put(ctrl);
    endrule
    rule do_fail (cntr == 8);
        fans.pins.fan_to_seq_fan_fail(1);
    endrule

    rule do_disable( cntr == 10);
          let ctrl = FanControl {restart: 0, enable: 0};
        fans.regs.control.put(ctrl);
    endrule

    rule do_finish (cntr == 15);
        $finish;
    endrule

    rule do_pwr_gd (cntr > 0);
      fans.pins.fanhp_to_seq_pwrgd(fans.pins.seq_to_fan_hp_en());
    endrule

endmodule

endpackage: Fans