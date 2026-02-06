// Integration test: Counter module using RDL-generated registers
package Counter;

import counter_regs_pkg::*;
import DefaultValue::*;

// Simple counter interface
interface Counter;
    method Bit#(16) value();
    method Bool overflow();
    method Bool underflow();
    method Action setControl(Ctrl ctrl);
    method Action setMaxValue(Bit#(16) max);
endinterface

// Counter implementation using RDL-generated types
module mkCounter (Counter);
    // Registers
    Reg#(Ctrl) ctrlReg <- mkReg(defaultValue);
    Reg#(Status) statusReg <- mkReg(defaultValue);
    Reg#(Bit#(16)) maxValReg <- mkReg(16'hFFFF);
    Reg#(Bit#(16)) counterReg <- mkReg(0);

    // Counter logic
    rule doCount (ctrlReg.enable == 1'b1 && ctrlReg.reset == 1'b0);
        Bit#(16) step = zeroExtend(ctrlReg.step);
        Bit#(16) newValue;
        Status newStatus = statusReg;

        // Count up or down based on direction bit
        if (ctrlReg.dir == 1'b0) begin
            // Count up
            newValue = counterReg + step;
            if (newValue > maxValReg) begin
                newStatus.overflow = 1'b1;
                newValue = 0;
            end
        end else begin
            // Count down
            if (counterReg < step) begin
                newStatus.underflow = 1'b1;
                newValue = maxValReg;
            end else begin
                newValue = counterReg - step;
            end
        end

        counterReg <= newValue;
        newStatus.value = newValue;
        statusReg <= newStatus;
    endrule

    // Reset logic
    rule doReset (ctrlReg.reset == 1'b1);
        counterReg <= 0;
        let newStatus = statusReg;
        newStatus.value = 0;
        newStatus.overflow = 1'b0;
        newStatus.underflow = 1'b0;
        statusReg <= newStatus;
    endrule

    // Interface methods
    method Bit#(16) value();
        return statusReg.value;
    endmethod

    method Bool overflow();
        return statusReg.overflow == 1'b1;
    endmethod

    method Bool underflow();
        return statusReg.underflow == 1'b1;
    endmethod

    method Action setControl(Ctrl ctrl);
        ctrlReg <= ctrl;
    endmethod

    method Action setMaxValue(Bit#(16) max);
        maxValReg <= max;
    endmethod
endmodule

// Simple test module for simulation
module mkCounterTest (Empty);
    Counter dut <- mkCounter;
    Reg#(Bit#(32)) cycle <- mkReg(0);

    rule incrementCycle;
        cycle <= cycle + 1;
    endrule

    rule startTest (cycle == 0);
        $display("[%0d] Starting counter integration test", cycle);
        Ctrl ctrl = defaultValue;
        ctrl.enable = 1'b1;
        ctrl.step = 4'd1;  // Count by 1
        dut.setControl(ctrl);
        dut.setMaxValue(16'd10);  // Overflow at 10
    endrule

    rule checkProgress (cycle > 0 && cycle < 15);
        $display("[%0d] Counter value: %0d, overflow: %b, underflow: %b",
                 cycle, dut.value(), dut.overflow(), dut.underflow());
    endrule

    rule testOverflow (cycle == 15);
        if (dut.overflow()) begin
            $display("[%0d] SUCCESS: Overflow detected as expected", cycle);
        end else begin
            $display("[%0d] FAIL: Overflow not detected", cycle);
        end
    endrule

    rule testCountDown (cycle == 16);
        $display("[%0d] Changing direction to count down", cycle);
        Ctrl ctrl = defaultValue;
        ctrl.enable = 1'b1;
        ctrl.dir = 1'b1;  // Count down
        ctrl.step = 4'd1;
        dut.setControl(ctrl);
    endrule

    rule checkCountDown (cycle > 16 && cycle < 30);
        $display("[%0d] Counter value: %0d", cycle, dut.value());
    endrule

    rule testUnderflow (cycle == 30);
        if (dut.underflow()) begin
            $display("[%0d] SUCCESS: Underflow detected as expected", cycle);
        end else begin
            $display("[%0d] FAIL: Underflow not detected", cycle);
        end
        $display("[%0d] Integration test complete", cycle);
        $finish;
    endrule
endmodule

endpackage: Counter
