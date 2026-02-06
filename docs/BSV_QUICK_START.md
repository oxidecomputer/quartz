# BSV Buck2 Quick Start Tutorial

This tutorial walks you through creating a new BSV project with Buck2, from initial setup to running simulations. You'll build a simple counter module, write tests, and generate Verilog.

## Prerequisites

- Buck2 installed and in your PATH
- Bluespec Compiler (bsc) installed
- Python 3.8+ with required packages
- Quartz repository cloned

## What You'll Build

By the end of this tutorial, you'll have:

1. A simple `Counter` module that counts from 0 to a configurable maximum
2. A helper library with utility functions
3. Bluesim testbenches to verify functionality
4. Generated Verilog for FPGA synthesis

Estimated time: 15-20 minutes

---

## Step 1: Create Project Structure

Create a new directory for your project:

```bash
cd hdl/ip/bsv/
mkdir my_counter
cd my_counter
```

Create the basic file structure:

```bash
touch BUCK           # Build configuration
touch Counter.bsv    # Main module
touch CounterUtils.bsv  # Helper utilities
mkdir test
touch test/CounterTest.bsv  # Test suite
```

Your directory should look like:

```
my_counter/
├── BUCK
├── Counter.bsv
├── CounterUtils.bsv
└── test/
    └── CounterTest.bsv
```

---

## Step 2: Write the Helper Module

First, create utility functions that other modules can use.

Edit `CounterUtils.bsv`:

```bsv
package CounterUtils;

// Wrap a value to stay within a maximum
function Bit#(n) wrapValue(Bit#(n) value, Bit#(n) maxVal);
    return (value > maxVal) ? 0 : value;
endfunction

// Check if a value is within a range
function Bool inRange(Bit#(n) value, Bit#(n) minVal, Bit#(n) maxVal);
    return (value >= minVal) && (value <= maxVal);
endfunction

endpackage
```

**Key concepts:**
- `package` defines a reusable module
- `function` defines pure combinational logic
- `Bit#(n)` is a parametric type for n-bit values

---

## Step 3: Write the Counter Module

Edit `Counter.bsv`:

```bsv
package Counter;

import CounterUtils::*;

// Counter interface
interface Counter;
    method Bit#(16) value();
    method Action increment();
    method Action reset();
    method Action setMax(Bit#(16) newMax);
endinterface

// Counter implementation
module mkCounter (Counter);
    Reg#(Bit#(16)) count <- mkReg(0);
    Reg#(Bit#(16)) maxVal <- mkReg(100);

    method Bit#(16) value();
        return count;
    endmethod

    method Action increment();
        Bit#(16) nextVal = count + 1;
        count <= wrapValue(nextVal, maxVal);
    endmethod

    method Action reset();
        count <= 0;
    endmethod

    method Action setMax(Bit#(16) newMax);
        maxVal <= newMax;
    endmethod
endmodule

endpackage
```

**Key concepts:**
- `interface` defines the module's methods (API)
- `module` implements the interface
- `Reg#(type)` creates a register (state)
- `method Action` modifies state (sequential logic)
- `method` (without Action) reads state (combinational)
- `<=` is non-blocking assignment (happens at cycle end)

---

## Step 4: Write Test Suite

Edit `test/CounterTest.bsv`:

```bsv
package CounterTest;

import Counter::*;

// Test module for Bluesim
module mkCounterBasicTest (Empty);
    Counter dut <- mkCounter;  // Device Under Test
    Reg#(Bit#(32)) cycle <- mkReg(0);

    rule advanceCycle;
        cycle <= cycle + 1;
    endrule

    rule initialize (cycle == 0);
        $display("[%0d] Test: Basic counter", cycle);
        dut.reset();
    endrule

    rule doIncrements (cycle > 0 && cycle <= 10);
        dut.increment();
        $display("[%0d] Counter value: %0d", cycle, dut.value());
    endrule

    rule checkFinalValue (cycle == 11);
        if (dut.value() == 10) begin
            $display("[%0d] PASS: Counter reached 10", cycle);
        end else begin
            $display("[%0d] FAIL: Counter = %0d, expected 10",
                     cycle, dut.value());
        end
    endrule

    rule finish (cycle == 12);
        $display("[%0d] Test complete", cycle);
        $finish;
    endrule
endmodule

module mkCounterWrapTest (Empty);
    Counter dut <- mkCounter;
    Reg#(Bit#(32)) cycle <- mkReg(0);

    rule advanceCycle;
        cycle <= cycle + 1;
    endrule

    rule initialize (cycle == 0);
        $display("[%0d] Test: Counter wrap at max", cycle);
        dut.reset();
        dut.setMax(5);  // Set max to 5
    endrule

    rule doIncrements (cycle > 0 && cycle <= 8);
        dut.increment();
        $display("[%0d] Counter value: %0d", cycle, dut.value());
    endrule

    rule checkWrapped (cycle == 9);
        if (dut.value() <= 5) begin
            $display("[%0d] PASS: Counter wrapped at max", cycle);
        end else begin
            $display("[%0d] FAIL: Counter = %0d, expected <= 5",
                     cycle, dut.value());
        end
        $finish;
    endrule
endmodule

endpackage
```

**Key concepts:**
- `module` with `Empty` interface is a top-level testbench
- `rule` executes when condition is true
- `$display` prints to console (like printf)
- `$finish` ends simulation
- Rules fire in parallel when conditions allow

---

## Step 5: Create BUCK Build File

Edit `BUCK`:

```starlark
load("//tools:bsv.bzl", "bsv_library", "bsv_bluesim_tests", "bsv_verilog")

# Helper utilities library
bsv_library(
    name = "CounterUtils",
    srcs = ["CounterUtils.bsv"],
    deps = [],
)

# Main counter library
bsv_library(
    name = "Counter",
    srcs = ["Counter.bsv"],
    deps = [":CounterUtils"],
)

# Bluesim test suite
bsv_bluesim_tests(
    name = "CounterTests",
    top = "test/CounterTest.bsv",
    modules = [
        "mkCounterBasicTest",
        "mkCounterWrapTest",
    ],
    deps = [":Counter"],
)

# Verilog generation for synthesis
bsv_verilog(
    name = "counter_verilog",
    top = "Counter.bsv",
    modules = ["mkCounter"],
    deps = [":Counter"],
)
```

**What this does:**
1. **CounterUtils**: Builds `CounterUtils.bsv` to object file
2. **Counter**: Builds `Counter.bsv` (depends on CounterUtils)
3. **CounterTests**: Creates two test executables from test modules
4. **counter_verilog**: Generates synthesizable Verilog from mkCounter

---

## Step 6: Build and Test

### Build the libraries

```bash
# Build helper utilities
buck2 build //hdl/ip/bsv/my_counter:CounterUtils

# Build main counter (includes dependencies)
buck2 build //hdl/ip/bsv/my_counter:Counter
```

Expected output:
```
Build ID: ...
Network: ...
Jobs completed: 4. Time elapsed: 0.5s.
BUILD SUCCEEDED
```

### Run tests

```bash
# Run basic counter test
buck2 run //hdl/ip/bsv/my_counter:CounterTests_mkCounterBasicTest
```

Expected output:
```
[0] Test: Basic counter
[1] Counter value: 1
[2] Counter value: 2
[3] Counter value: 3
...
[10] Counter value: 10
[11] PASS: Counter reached 10
[12] Test complete
```

```bash
# Run wrap test
buck2 run //hdl/ip/bsv/my_counter:CounterTests_mkCounterWrapTest
```

Expected output:
```
[0] Test: Counter wrap at max
[1] Counter value: 1
[2] Counter value: 2
...
[6] Counter value: 0  # Wrapped!
[7] Counter value: 1
[8] Counter value: 2
[9] PASS: Counter wrapped at max
```

### Generate Verilog

```bash
# Generate Verilog for FPGA synthesis
buck2 build //hdl/ip/bsv/my_counter:counter_verilog

# View the generated Verilog
buck2 build //hdl/ip/bsv/my_counter:counter_verilog --show-output
```

This produces `mkCounter.v` which can be used in FPGA synthesis tools.

---

## Step 7: Explore the Build Outputs

### Locate build artifacts

```bash
# Find the Verilog output
buck2 build //hdl/ip/bsv/my_counter:counter_verilog --show-output
# Example output: //hdl/ip/bsv/my_counter:counter_verilog buck-out/v2/.../verilog/mkCounter.v

# View the generated Verilog
cat $(buck2 build //hdl/ip/bsv/my_counter:counter_verilog --show-output | awk '{print $2}')
```

### Check dependencies

```bash
# See what Counter depends on
buck2 query "deps(//hdl/ip/bsv/my_counter:Counter)"

# See what depends on CounterUtils
buck2 query "rdeps(//hdl/ip/bsv/my_counter:..., //hdl/ip/bsv/my_counter:CounterUtils)"
```

### Incremental builds

Make a small change to `CounterUtils.bsv`:

```bsv
// Add a new function
function Bool isZero(Bit#(n) value);
    return value == 0;
endfunction
```

Rebuild:

```bash
buck2 build //hdl/ip/bsv/my_counter:Counter
```

Notice how Buck2 only rebuilds what changed - should be much faster!

---

## Step 8: Add RDL Register Integration (Optional)

Let's add a register interface using SystemRDL.

### Create RDL file

Create `counter_regs.rdl`:

```systemrdl
addrmap counter_regs {
    name = "Counter Registers";
    desc = "Register interface for Counter module";

    reg {
        name = "Control Register";
        field {
            name = "Enable";
            desc = "Enable counting";
        } enable = 0;

        field {
            name = "Reset";
            desc = "Reset counter to 0";
            sw = rw;
            hw = r;
        } reset = 0;
    } CTRL @ 0x00;

    reg {
        name = "Maximum Value";
        field {
            name = "Max";
            desc = "Maximum count value";
        } max[15:0] = 100;
    } MAX_VAL @ 0x04;

    reg {
        name = "Counter Value";
        field {
            name = "Count";
            desc = "Current counter value";
            sw = r;
            hw = w;
        } count[15:0] = 0;
    } VALUE @ 0x08;
};
```

### Update BUCK file

Add to `BUCK`:

```starlark
load("//tools:rdl.bzl", "rdl_file")

# Generate BSV register package from RDL
rdl_file(
    name = "counter_regs_rdl",
    src = "counter_regs.rdl",
    outputs = [
        "counter_regs_pkg.bsv",
        "counter_regs.html",
        "counter_regs.json",
    ],
)

# Make registers available as a library
bsv_library(
    name = "CounterRegs",
    srcs = [":counter_regs_rdl#counter_regs_pkg.bsv"],
    deps = [
        ":counter_regs_rdl",
        "//hdl/ip/bsv:RegCommon",
    ],
)
```

### Build the registers

```bash
# Generate RDL outputs
buck2 build //hdl/ip/bsv/my_counter:counter_regs_rdl

# View HTML documentation
buck2 build //hdl/ip/bsv/my_counter:counter_regs_rdl --show-output
# Open the .html file in a browser

# Build the BSV register package
buck2 build //hdl/ip/bsv/my_counter:CounterRegs
```

---

## Step 9: Common Development Workflow

### Typical development cycle

1. **Edit BSV source** - Modify `.bsv` files
2. **Quick build check** - `buck2 build //path:target`
3. **Run tests** - `buck2 run //path:TestSuite_mkTestName`
4. **Debug failures** - Add `$display` statements, rebuild, rerun
5. **Generate Verilog** - `buck2 build //path:verilog_target`
6. **Integrate** - Use Verilog in FPGA project

### Useful commands

```bash
# Build everything in your project
buck2 build //hdl/ip/bsv/my_counter:

# Clean build (rarely needed)
buck2 clean

# Watch build output verbosely
buck2 build //hdl/ip/bsv/my_counter:Counter --verbose 5

# List all targets in your project
buck2 targets //hdl/ip/bsv/my_counter:

# Run all tests in a suite
for test in mkCounterBasicTest mkCounterWrapTest; do
    buck2 run //hdl/ip/bsv/my_counter:CounterTests_${test}
done
```

---

## Step 10: Next Steps

Congratulations! You've created a working BSV project with Buck2. Here are some ways to expand:

### Add complexity

1. **More interfaces**: Add AXI, APB, or custom interfaces
2. **State machines**: Implement complex control logic
3. **FIFOs**: Add buffering between modules
4. **Multiple modules**: Create hierarchical designs

### Improve testing

1. **More test cases**: Add edge cases (overflow, underflow)
2. **Randomization**: Use `$random` for fuzz testing
3. **Assertions**: Add checks within your design
4. **Coverage**: Track which code paths are tested

### Integration

1. **Connect to other modules**: Use your counter in larger designs
2. **Add to FPGA project**: Include in a top-level design
3. **Document**: Write comments and README files
4. **Version control**: Commit your working code

---

## Troubleshooting

### Build fails with "Module not found"

**Problem:** `Error: cannot find module 'CounterUtils'`

**Solution:**
- Check that module is in `deps = [...]`
- Verify package name matches filename
- Build dependency first: `buck2 build //path:CounterUtils`

### Test doesn't finish

**Problem:** Test runs forever, doesn't call `$finish`

**Solution:**
- Add a timeout rule: `rule timeout (cycle > 1000); $finish; endrule`
- Check that your test conditions eventually become true
- Add debug `$display` to see what cycle you're stuck on

### Simulation output not appearing

**Problem:** No console output when running test

**Solution:**
- Use `$display` instead of `$write`
- Make sure rules are firing (add displays in rules)
- Check Buck2 isn't suppressing output (run with `--verbose`)

### Verilog looks wrong

**Problem:** Generated Verilog doesn't match expectations

**Solution:**
- Check module interface carefully
- Review bsc compiler flags
- Try different flags like `-opt-undetermined-vals`
- Compare with working examples

---

## Summary

You've learned:

✅ How to structure a BSV project with Buck2
✅ How to write BSV modules with interfaces and implementations
✅ How to create helper libraries and manage dependencies
✅ How to write Bluesim testbenches with rules
✅ How to generate Verilog for FPGA synthesis
✅ How to integrate SystemRDL register definitions
✅ How to use Buck2 commands for building and testing

### Complete Project Files

All tutorial files are available in `hdl/ip/bsv/integration_test/` as working examples:
- `SimpleCounter.bsv` - Similar counter implementation
- `CounterHelpers.bsv` - Helper utilities
- `BUCK` - Complete build configuration

---

## Additional Resources

- **Main Guide**: [BSV_BUCK2_GUIDE.md](../BSV_BUCK2_GUIDE.md) - Comprehensive reference
- **Migration Examples**: [BSV_MIGRATION_EXAMPLES.md](./BSV_MIGRATION_EXAMPLES.md) - Convert existing projects
- **Integration Tests**: `hdl/ip/bsv/integration_test/` - Working example projects
- **Buck2 Docs**: https://buck2.build/ - Official Buck2 documentation
- **BSV Reference**: Bluespec SystemVerilog User Guide - Language reference

---

*Tutorial created for Quartz BSV Buck2 build system - Phase 6 Documentation*
