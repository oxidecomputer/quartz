package SidecarMainboardMiscSequencers;

import PowerRail::*;

(* always_enabled *)
interface VSC7448Pins;
    interface PowerRail::Pins v1p0;
    interface PowerRail::Pins v1p2;
    interface PowerRail::Pins v2p5;
    method Bool clocks_enable();
    method Bool reset();
    method Action thermal_alert(Bool alert);
endinterface

interface VSC7448Registers;
endinterface

interface VSC7448Sequencer;
    interface VSC7448Pins pins;
    interface VSC7448Registers registers;
    interface PulseWire tick_1ms;
endinterface

module mkVSC7448Sequencer #(Integer power_good_timeout) (VSC7448Sequencer);
    PowerRail#(4) v1p0 <- mkPowerRail(power_good_timeout);
    PowerRail#(4) v1p2 <- mkPowerRail(power_good_timeout);
    PowerRail#(4) v2p5 <- mkPowerRail(power_good_timeout);

    Reg#(Bool) clocks_enabled <-mkReg(True);
    Reg#(Bool) in_reset <- mkReg(True);

    PulseWire tick <- mkPulseWire();

    (* fire_when_enabled *)
    rule do_power_enable;
        v1p0.set_enabled(True);
        v1p2.set_enabled(True);
        v2p5.set_enabled(True);
    endrule

    (* fire_when_enabled *)
    rule do_release_reset (tick);
        in_reset <= !(v1p0.good && v1p2.good && v2p5.good);
    endrule

    interface VSC7448Pins pins;
        interface PowerRail::Pins v1p0 = v1p0.pins;
        interface PowerRail::Pins v1p2 = v1p2.pins;
        interface PowerRail::Pins v2p5 = v2p5.pins;
        method clocks_enable = clocks_enabled;
        method reset = in_reset;
    endinterface

    interface PulseWire tick_1ms = tick;
endmodule

(* always_enabled *)
interface ClockGeneratorPins;
    interface PowerRail::Pins ldo;
    method Bool reset();
endinterface

interface ClockGeneratorRegisters;
endinterface

interface ClockGeneratorSequencer;
    interface ClockGeneratorPins pins;
    interface ClockGeneratorRegisters registers;
    interface PulseWire tick_1ms;
endinterface

module mkClockGeneratorSequencer #(Integer power_good_timeout) (ClockGeneratorSequencer);
    PowerRail#(4) ldo <- mkPowerRail(power_good_timeout);
    Reg#(Bool) in_reset <- mkReg(True);
    PulseWire tick <- mkPulseWire();

    (* fire_when_enabled *)
    rule do_power_enable;
        ldo.set_enabled(True);
    endrule

    (* fire_when_enabled *)
    rule do_release_reset (tick);
        in_reset <= !ldo.good;
    endrule

    interface ClockGeneratorPins pins;
        interface PowerRail::Pins ldo = ldo.pins;
        method reset = in_reset;
    endinterface

    interface PulseWire tick_1ms = tick;
endmodule

endpackage
