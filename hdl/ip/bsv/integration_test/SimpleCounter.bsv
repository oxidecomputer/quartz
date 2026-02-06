// Integration test: Simple counter without RDL dependencies
package SimpleCounter;

import CounterHelpers::*;

// Simple counter interface
interface SimpleCounter;
    method Bit#(16) value();
    method Action increment();
    method Action reset();
endinterface

// Simple counter implementation
module mkSimpleCounter (SimpleCounter);
    Reg#(Bit#(16)) counter <- mkReg(0);
    Reg#(Bit#(16)) maxVal <- mkReg(100);

    method Bit#(16) value();
        return counter;
    endmethod

    method Action increment();
        Bit#(16) newVal = counter + 1;
        // Use helper function from CounterHelpers
        counter <= wrapValue(newVal, maxVal);
    endmethod

    method Action reset();
        counter <= 0;
    endmethod
endmodule

// Test module for Bluesim
module mkSimpleCounterTest (Empty);
    SimpleCounter dut <- mkSimpleCounter;
    Reg#(Bit#(32)) cycle <- mkReg(0);

    rule incrementCycle;
        cycle <= cycle + 1;
    endrule

    rule startTest (cycle == 0);
        $display("[%0d] Starting simple counter integration test", cycle);
        dut.reset();
    endrule

    rule countUp (cycle > 0 && cycle <= 10);
        dut.increment();
        $display("[%0d] Counter value: %0d", cycle, dut.value());
    endrule

    rule checkValue (cycle == 11);
        if (dut.value() == 10) begin
            $display("[%0d] SUCCESS: Counter reached expected value 10", cycle);
        end else begin
            $display("[%0d] FAIL: Counter value %0d != 10", cycle, dut.value());
        end
    endrule

    rule testReset (cycle == 12);
        $display("[%0d] Testing reset...", cycle);
        dut.reset();
    endrule

    rule checkReset (cycle == 13);
        if (dut.value() == 0) begin
            $display("[%0d] SUCCESS: Counter reset to 0", cycle);
        end else begin
            $display("[%0d] FAIL: Counter not reset, value = %0d", cycle, dut.value());
        end
        $display("[%0d] Integration test complete", cycle);
        $finish;
    endrule
endmodule

endpackage: SimpleCounter
