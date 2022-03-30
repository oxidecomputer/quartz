package PowerRailPrimatives;

// BSV Core
import ConfigReg::*;
import Connectable::*;
import DefaultVaule::*;
import DReg::*;
import StmtFSM::*;

interface PowerCtrlPins;
    method Bit#(1) en();
    method Action pg(Bit#(1) pg);
endinterface

interface PowerRail;
    interface PowerCtrlPins pins;
    method Action set_enabled(Bool en);

    method Bool enabled();
    method Bool good();
    method Bool fault();
    method Integer timeout();
endinterface

module mkPowerRail #(Integer timeout_, Bool defaultEnable) (PowerRail);
    Reg#(Bool) been_ok_r        <- mkReg(False);
    Reg#(Bool) faulted_r        <- mkReg(False);
    ConfigReg#(Bool) enabled_r  <- mkReg(defaultEnable);
    Wire#(Bool) good_           <- mkDWire(False);
    
    interface PowerCtrlPins pins;
        method en = pack(enabled_r);
        method Action pg(Bit#(1) val) = good_._write(unpack(val));
    endinterface

    method enabled = enabled_r;

    method Action set_enabled(Bool en);
        enabled_r <= en;
    endmethod

    method good = good_;
    method timeout = timeout_;

    rule been_ok_logic;
        if (enabled_r && good_) begin
            been_ok_r <= True;
        end else if (!enabled_r) begin
            been_ok_r <= False;
        end
    endrule

    // Faulted will mean we've been enabled, have seen power good and then
    // lost it, or have been enabled and timed out without power good.
    // Disabling will reset fault logic
    // TODO: timeout case?
    rule faulted_logic;
        if (!enabled_r) begin
            faulted_r <= False;
        end else if (been_ok && !good_) begin
            faulted_r <= True;
        end
    endrule

endmodule

endpackage