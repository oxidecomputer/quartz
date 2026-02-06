// Test module that uses RDL-generated register package
package TestRegsUser;

import test_regs_pkg::*;
import DefaultValue::*;

// Simple module that demonstrates using RDL-generated types
module mkTestRegsUser (Empty);
    // Create a register with default reset value
    Reg#(Ctrl) ctrlReg <- mkReg(defaultValue);
    Reg#(Status) statusReg <- mkReg(defaultValue);

    rule test_ctrl;
        // Test setting control register fields
        Ctrl ctrl = defaultValue;
        ctrl.enable = 1'b1;
        ctrl.mode = 2'b10;
        ctrlReg <= ctrl;
        $display("Control register: enable=%b, mode=%b, reset=%b",
                 ctrl.enable, ctrl.mode, ctrl.reset);
        $finish;
    endrule
endmodule

endpackage: TestRegsUser
