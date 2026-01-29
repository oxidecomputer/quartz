// Integration test: Module combining Counter and CounterHelpers
package CounterWithHelpers;

import Counter::*;
import CounterHelpers::*;
import counter_regs_pkg::*;
import DefaultValue::*;

// Extended counter interface with helper methods
interface CounterWithHelpers;
    method Bit#(16) value();
    method Bool overflow();
    method Bool underflow();
    method Action setControl(Ctrl ctrl);
    method Action setMaxValue(Bit#(16) max);
    method Bool isInRange(Bit#(16) min, Bit#(16) max);
endinterface

// Implementation using both Counter and CounterHelpers
module mkCounterWithHelpers (CounterWithHelpers);
    Counter counter <- mkCounter;

    method Bit#(16) value() = counter.value();
    method Bool overflow() = counter.overflow();
    method Bool underflow() = counter.underflow();
    method Action setControl(Ctrl ctrl) = counter.setControl(ctrl);
    method Action setMaxValue(Bit#(16) max) = counter.setMaxValue(max);

    method Bool isInRange(Bit#(16) min, Bit#(16) max);
        return inRange(counter.value(), min, max);
    endmethod
endmodule

endpackage: CounterWithHelpers
