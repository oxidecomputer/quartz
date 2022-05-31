package FanModule;

(* always_enabled *)
interface Pins;
    method Bool en();
    method Bool led();
    method Action pg(Bool val);
endinterface

interface FanModule;
    interface Pins pins;
endinterface

module mkFanModule (FanModule);
    Reg#(Bool) enabled <- mkReg(True);

    interface Pins pins;
        method en = enabled;
        method led = enabled;
        method Action pg(Bool val);
        endmethod
    endinterface
endmodule

function Pins pins(FanModule m) = m.pins;

endpackage
