package PowerRail;

// BSV Core
import ConfigReg::*;
import Connectable::*;
import DReg::*;

(* always_enabled *)
interface Pins;
    method Bit#(1) en();
    method Action pg(Bit#(1) pg);
endinterface

interface PowerRail;
    interface Pins pins;
    method Action set_enabled(Bool en);

    method Bool enabled();
    method Bool good();
    method Bool fault();
    method Bool timedout();
    method Integer timeout();
endinterface

module mkPowerRail #(Integer timeout_, Bool defaultEnable) (PowerRail);
    Reg#(Bool) been_ok_r        <- mkReg(False);
    Reg#(Bool) faulted_r        <- mkReg(False);
    Reg#(UInt#(24)) timeout_counter <- mkReg(fromInteger(0));
    ConfigReg#(Bool) enabled_r  <- mkReg(defaultEnable);
    Wire#(Bool) good_           <- mkDWire(False);
    Wire#(Bool) timedout_       <- mkDWire(False);

    // We need to know if we've ever been ok in order to 
    // disambiguate timeout fault and the ramp time vs
    // an actual timeout.
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
    rule faulted_logic;
        if (!enabled_r) begin
            faulted_r <= False;
        end else if (been_ok_r && !good_) begin
            faulted_r <= True;
        end
    endrule

    //
    // Monitor for timeout
    //
    rule do_timeout_counts;
        if (!enabled_r) begin
            timeout_counter <= 0;
        end else if (enabled_r && !good_ && timeout_counter < fromInteger(timeout_)) begin
            timeout_counter <= timeout_counter + 1;
        end

        timedout_ <= timeout_counter >= fromInteger(timeout_);
    endrule

    interface Pins pins;
        method en = pack(enabled_r);
        method Action pg(Bit#(1) val) = good_._write(unpack(val));
    endinterface
    
    method Action set_enabled(Bool en);
        enabled_r <= en;
    endmethod

    method good = good_;
    method enabled = enabled_r;
    method fault = faulted_r;
    method timedout = timedout_;
    method timeout = timeout_;

    
endmodule

function Bool enabled(PowerRail r) = r.enabled;
function Bool good(PowerRail r) = r.good;
function Bool fault(PowerRail r) = r.fault;

//
// Test bench stuff
//

(* always_enabled *)
interface ModelPins;
    method Action en(Bit#(1) val);
    method Bit#(1) pg();
endinterface

instance Connectable#(ModelPins, Pins);
    module mkConnection #(ModelPins a, Pins b) (Empty);
        mkConnection(a.en, b.en);
        mkConnection(a.pg, b.pg);
    endmodule
endinstance

interface PowerRailModel;
    interface ModelPins pins;
    method Action force_enable(Bool value);
    method Action force_disable(Bool value);
    method Bool enabled;
endinterface

module mkPowerRailModel #(
    String name) (PowerRailModel);

    ConfigReg#(Bool) enabled_ <- mkConfigReg(False);
    ConfigReg#(Bool) force_enable_ <- mkConfigReg(False);
    ConfigReg#(Bool) force_disable_ <- mkConfigReg(False);
    ConfigReg#(Bool) pin_enable <- mkConfigReg(False);

    rule do_make_enabled;
        enabled_ <= (pin_enable || force_enable_) && !force_disable_;
    endrule

    interface ModelPins pins;
        method Action en(Bit#(1) val);
            pin_enable <= (val == 1);
        endmethod
        method Bit#(1) pg();
            if (enabled_) begin
                return 1;
            end else begin
                return 0;
            end
        endmethod
        
    endinterface
    method force_enable = force_enable_._write;
    method force_disable = force_disable_._write;
    method enabled = enabled_;
    
    // method force_enable = force_enable_._write;
endmodule

endpackage