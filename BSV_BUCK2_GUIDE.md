# BSV Buck2 Build System - Complete Guide

Comprehensive documentation for building Bluespec SystemVerilog (BSV) projects with Buck2 in the Quartz repository.

## Table of Contents

1. [Overview](#overview)
2. [Quick Start](#quick-start)
3. [Build Rules Reference](#build-rules-reference)
4. [Migration from Cobble](#migration-from-cobble)
5. [Best Practices](#best-practices)
6. [Troubleshooting](#troubleshooting)
7. [Advanced Topics](#advanced-topics)
8. [Additional Resources](#additional-resources)

---

## Overview

The BSV Buck2 build system provides a modern, efficient build infrastructure for Bluespec SystemVerilog projects, replacing the legacy cobble system. It offers:

- **Fast Incremental Builds** - Buck2's caching means rebuilds are nearly instant
- **Parallel Execution** - Multiple targets build simultaneously
- **Transitive Dependencies** - Automatic dependency graph resolution
- **RDL Integration** - SystemRDL register definitions generate BSV packages
- **Simulation Support** - Bluesim testbenches build and run seamlessly
- **Verilog Generation** - Synthesizable Verilog output for FPGA tools

### Architecture

```
BSV Source Files (.bsv)
         ↓
   [bsv_library]  ← Compiles to .bo (Bluespec Object) files
         ↓
    ┌────┴────┐
    ↓         ↓
[bsv_verilog] [bsv_sim]  ← Generate Verilog or Bluesim bytecode
    ↓         ↓
  .v files  [bsv_bluesim_binary]  ← Link executable testbench
            ↓
        Run simulation

RDL Files (.rdl)
    ↓
[rdl_file]  ← Generate BSV packages, HTML docs, JSON
    ↓
BSV Package (.bsv)
```

---

## Quick Start

### Prerequisites

```bash
# Buck2 installed
cargo +nightly-2024-10-13 install --git https://github.com/facebook/buck2.git --tag "2025-02-01" buck2

# Bluespec compiler in PATH
which bsc

# Python packages for RDL
pip install -r tools/requirements.txt

# Optional: Set custom Bluespec library directory
# export BSV_LIB_DIR=/path/to/bluespec/lib
# (See "Toolchain Configuration" in Advanced Topics for details)
```

### Your First Build

1. **Create a simple BSV module:**

```bsv
// MyModule.bsv
package MyModule;

function Bit#(8) addOne(Bit#(8) x);
    return x + 1;
endfunction

endpackage
```

2. **Create a BUCK file:**

```starlark
load("//tools:bsv.bzl", "bsv_library")

bsv_library(
    name = "MyModule",
    srcs = ["MyModule.bsv"],
    deps = [],
)
```

3. **Build it:**

```bash
buck2 build //path/to:MyModule
```

4. **Success!** Your module is now compiled to a .bo file.

### Adding a Testbench

1. **Add a test module:**

```bsv
// MyModuleTest.bsv (add to MyModule.bsv)
module mkMyModuleTest (Empty);
    Reg#(Bit#(32)) cycle <- mkReg(0);

    rule run;
        cycle <= cycle + 1;
        if (cycle < 10) begin
            $display("Result: %0d", addOne(truncate(cycle)));
        end else begin
            $finish;
        end
    endrule
endmodule
```

2. **Update BUCK file:**

```starlark
load("//tools:bsv.bzl", "bsv_library", "bsv_sim", "bsv_bluesim_binary")

bsv_library(
    name = "MyModule",
    srcs = ["MyModule.bsv"],
    deps = [],
)

bsv_sim(
    name = "mymodule_sim",
    top = "MyModule.bsv",
    modules = ["mkMyModuleTest"],
    deps = [":MyModule"],
)

bsv_bluesim_binary(
    name = "mymodule_test",
    top = ":mymodule_sim",
    entry_point = "mkMyModuleTest",
    deps = [":MyModule"],
)
```

3. **Run the test:**

```bash
buck2 run //path/to:mymodule_test
```

---

## Build Rules Reference

### bsv_library

Compiles BSV source files into .bo (Bluespec Object) files.

```starlark
bsv_library(
    name = "LibraryName",
    srcs = ["File1.bsv", "File2.bsv"],
    deps = [
        ":OtherLibrary",
        "//hdl/ip/bsv:CommonFunctions",
    ],
    bsc_flags = ["-opt-undetermined-vals"],
    is_synth = True,
)
```

**Attributes:**
- `name` (required): Target name
- `srcs` (required): List of .bsv source files
- `deps` (optional): List of library dependencies
- `bsc_flags` (optional): Additional compiler flags
- `is_synth` (optional): Whether for synthesis (default: True)

**Outputs:**
- `.bo` files in a unique output directory
- Cached for incremental builds

**Example:**
```starlark
bsv_library(
    name = "I2CController",
    srcs = ["I2CController.bsv"],
    deps = [
        ":I2CCommon",
        "//hdl/ip/bsv:Strobe",
    ],
)
```

### bsv_verilog

Generates synthesizable Verilog from BSV modules.

```starlark
bsv_verilog(
    name = "verilog_output",
    top = "TopModule.bsv",
    modules = ["mkModuleA", "mkModuleB"],
    deps = [":LibraryName"],
    bsc_flags = [
        "-opt-undetermined-vals",
        "-unspecified-to", "X",
    ],
)
```

**Attributes:**
- `name` (required): Target name
- `top` (required): Top-level BSV file
- `modules` (required): List of module names to generate
- `deps` (required): Library dependencies
- `bsc_flags` (optional): Verilog generation flags

**Outputs:**
- `.v` Verilog files (one per module)
- Separate directories for each module

**Example:**
```starlark
bsv_verilog(
    name = "transceiver_verilog",
    top = "IgnitionTransceiver.bsv",
    modules = ["mkTransceiver"],
    deps = [":Transceiver"],
    bsc_flags = ["-opt-undetermined-vals"],
)
```

### bsv_sim

Generates Bluesim bytecode for simulation.

```starlark
bsv_sim(
    name = "simulation",
    top = "TestBench.bsv",
    modules = ["mkTestBench"],
    deps = [":LibraryName"],
    bsc_flags = [],
)
```

**Attributes:**
- `name` (required): Target name
- `top` (required): Top-level BSV file with testbench
- `modules` (required): List of testbench module names
- `deps` (required): Library dependencies
- `bsc_flags` (optional): Simulation compiler flags

**Outputs:**
- `.ba` Bluesim bytecode files
- Used by `bsv_bluesim_binary` for linking

**Example:**
```starlark
bsv_sim(
    name = "i2c_controller_sim",
    top = "test/I2CControllerTests.bsv",
    modules = ["mkI2CReadTest", "mkI2CWriteTest"],
    deps = [":I2CController", ":I2CModel"],
)
```

### bsv_bluesim_binary

Links Bluesim bytecode into an executable testbench.

```starlark
bsv_bluesim_binary(
    name = "test_executable",
    top = ":simulation",
    entry_point = "mkTestBench",
    deps = [":LibraryName"],
)
```

**Attributes:**
- `name` (required): Executable name
- `top` (required): Reference to `bsv_sim` target
- `entry_point` (required): Top module name to execute
- `deps` (required): Library dependencies

**Outputs:**
- Executable shell script
- `.so` shared library

**Usage:**
```bash
buck2 run //path/to:test_executable
```

**Example:**
```starlark
bsv_bluesim_binary(
    name = "mdio_test",
    top = ":mdio_sim",
    entry_point = "mkMDIOReadTest",
    deps = [":MDIO", ":MDIOModel"],
)
```

### bsv_bluesim_tests (Macro)

Convenience macro that creates both `bsv_sim` and multiple `bsv_bluesim_binary` targets.

```starlark
load("//tools:bsv.bzl", "bsv_bluesim_tests")

bsv_bluesim_tests(
    name = "MyTests",
    top = "test/MyTests.bsv",
    modules = [
        "mkTest1",
        "mkTest2",
        "mkTest3",
    ],
    deps = [":MyLibrary"],
)
```

**Generates:**
- One `bsv_sim` target named `MyTests`
- Individual `bsv_bluesim_binary` targets: `MyTests_mkTest1`, `MyTests_mkTest2`, `MyTests_mkTest3`

**Run all tests:**
```bash
buck2 run //path/to:MyTests_mkTest1
buck2 run //path/to:MyTests_mkTest2
buck2 run //path/to:MyTests_mkTest3
```

### rdl_file

Generates BSV packages and documentation from SystemRDL register definitions.

```starlark
load("//tools:rdl.bzl", "rdl_file")

rdl_file(
    name = "my_regs_rdl",
    src = "my_regs.rdl",
    outputs = [
        "my_regs_pkg.bsv",
        "my_regs.html",
        "my_regs.json",
    ],
    deps = [],
)
```

**Attributes:**
- `name` (required): Target name (must end with `_rdl`)
- `src` (required): Single .rdl source file
- `outputs` (required): List of output files to generate
- `deps` (optional): Other RDL file dependencies

**Output Formats:**
- `.bsv` - BSV package with registers, structs, and helper functions
- `.html` - Interactive HTML documentation
- `.json` - JSON metadata for tooling

**Naming Convention:**
- Target name must end with `_rdl`
- Source file must match: `<target_name_without_rdl>.rdl`
- BSV output: `<target_name_without_rdl>_pkg.bsv`

**Example:**
```starlark
rdl_file(
    name = "sequencer_regs_rdl",
    src = "sequencer_regs.rdl",
    outputs = [
        "sequencer_regs_pkg.bsv",
        "sequencer_regs.html",
        "sequencer_regs.json",
    ],
)
```

---

## Migration from Cobble

### Rule Mapping

| Cobble Rule | Buck2 Rule | Notes |
|-------------|------------|-------|
| `bluespec_library` | `bsv_library` | Direct mapping |
| `bluespec_verilog` | `bsv_verilog` | Remove `env` attribute |
| `bluespec_sim` | `bsv_sim` | Direct mapping |
| `bluesim_binary` | `bsv_bluesim_binary` | Add explicit `entry_point` |
| `bluesim_tests` | `bsv_bluesim_tests` | Direct mapping |
| `rdl` | `rdl_file` | Target name must end with `_rdl` |

### Attribute Changes

| Cobble | Buck2 | Change |
|--------|-------|--------|
| `sources` | `srcs` | Renamed |
| `suite` | `top` | Renamed (for tests) |
| `env` | *(removed)* | No longer needed |
| `using` | `bsc_flags` | Extract from dict |
| `local` | `bsc_flags` | Extract from dict |

### Automated Conversion

Use the conversion tool:

```bash
python3 tools/build_to_buck_converter.py hdl/ip/bsv/MyModule/BUILD
```

This generates a BUCK file automatically. Review and adjust:
- Add `entry_point` to `bsv_bluesim_binary` rules
- Verify dependency paths
- Check for `<expression>` placeholders

### Manual Migration Example

**Before (Cobble BUILD):**
```python
bluespec_library('I2CController',
    sources = ['I2CController.bsv'],
    deps = [
        ':I2CCommon',
        '//hdl/ip/bsv:Strobe',
    ])

bluesim_tests('I2CTests',
    env = '//bluesim_default',
    suite = 'test/I2CTests.bsv',
    modules = [
        'mkI2CReadTest',
        'mkI2CWriteTest',
    ],
    deps = [':I2CController'])
```

**After (Buck2 BUCK):**
```starlark
load("//tools:bsv.bzl", "bsv_library", "bsv_bluesim_tests")

bsv_library(
    name = "I2CController",
    srcs = ["I2CController.bsv"],
    deps = [
        ":I2CCommon",
        "//hdl/ip/bsv:Strobe",
    ],
)

bsv_bluesim_tests(
    name = "I2CTests",
    top = "test/I2CTests.bsv",
    modules = [
        "mkI2CReadTest",
        "mkI2CWriteTest",
    ],
    deps = [":I2CController"],
)
```

**Key Changes:**
1. Python → Starlark syntax
2. `sources` → `srcs`
3. `suite` → `top`
4. Removed `env` attribute
5. Added `load()` statement at top

---

## Best Practices

### Project Structure

```
hdl/ip/bsv/
├── MyProject/
│   ├── BUCK                    # Build definitions
│   ├── MyModule.bsv            # Main module
│   ├── MyHelper.bsv            # Helper modules
│   ├── my_regs.rdl             # Register definitions (if needed)
│   └── test/
│       ├── MyModuleTest.bsv    # Test benches
│       └── MyModel.bsv         # Simulation models
```

### Naming Conventions

- **Library targets**: Use module name (e.g., `"I2CController"`)
- **Verilog targets**: Append `_verilog` (e.g., `"controller_verilog"`)
- **Simulation targets**: Append `_sim` (e.g., `"controller_sim"`)
- **Test executables**: Append `_test` (e.g., `"controller_test"`)
- **RDL targets**: Must end with `_rdl` (e.g., `"my_regs_rdl"`)

### Dependency Management

1. **Use local references** for targets in the same BUCK file:
   ```starlark
   deps = [":LocalTarget"]
   ```

2. **Use absolute paths** for cross-directory dependencies:
   ```starlark
   deps = ["//hdl/ip/bsv:CommonFunctions"]
   ```

3. **Order matters**: List direct dependencies only; transitive deps are automatic

4. **Avoid circular dependencies**: Refactor shared code into a common library

### Compiler Flags

Common BSV compiler flags:

```starlark
bsc_flags = [
    "-opt-undetermined-vals",     # Optimize undetermined values
    "-unspecified-to", "X",       # Set unspecified values to X
    "-aggressive-conditions",      # Optimize conditions
    "-check-assert",              # Enable assertion checking
]
```

For Verilog generation:
```starlark
bsc_flags = [
    "-opt-undetermined-vals",
    "-unspecified-to", "X",
    "-remove-dollar",             # Remove $ from identifiers
]
```

### Testing Strategy

1. **Unit Tests**: One test per module function
   ```starlark
   bsv_bluesim_tests(
       name = "UnitTests",
       top = "test/UnitTests.bsv",
       modules = ["mkAddTest", "mkSubTest", "mkMulTest"],
       deps = [":MathModule"],
   )
   ```

2. **Integration Tests**: Test module interactions
   ```starlark
   bsv_bluesim_binary(
       name = "integration_test",
       top = ":integration_sim",
       entry_point = "mkIntegrationTest",
       deps = [":ModuleA", ":ModuleB", ":ModuleC"],
   )
   ```

3. **Run tests regularly**:
   ```bash
   buck2 run //path/to:UnitTests_mkAddTest
   ```

---

## Troubleshooting

### Common Errors

#### Error: "Cannot find the binary file `Module.bo`"

**Cause**: Dependency not in search path

**Solution**: Add missing dependency to `deps`:
```starlark
deps = [":MissingModule"]
```

#### Error: "entry_point attribute required"

**Cause**: `bsv_bluesim_binary` needs explicit entry point

**Solution**: Add `entry_point` parameter:
```starlark
bsv_bluesim_binary(
    name = "test",
    top = ":sim",
    entry_point = "mkTestModule",  # Add this
    deps = [":Library"],
)
```

#### Error: "Target name must end with '_rdl'"

**Cause**: RDL target doesn't follow naming convention

**Solution**: Rename target to end with `_rdl`:
```starlark
rdl_file(
    name = "my_regs_rdl",  # Must end with _rdl
    src = "my_regs.rdl",
    ...
)
```

### Build Issues

#### Slow Builds

1. Check Buck2 daemon status:
   ```bash
   buck2 status
   ```

2. Restart daemon if needed:
   ```bash
   buck2 kill
   buck2 build //your/target
   ```

3. Check for excessive dependencies

#### Cache Issues

Clear Buck2 cache:
```bash
buck2 clean
```

Full rebuild:
```bash
buck2 clean && buck2 build //your/target
```

### Debugging Techniques

1. **View build commands**:
   ```bash
   buck2 build //your/target -v 5
   ```

2. **Check target outputs**:
   ```bash
   buck2 targets //your/path: --show-output
   ```

3. **Inspect dependencies**:
   ```bash
   buck2 query "deps(//your:target)"
   ```

4. **Find reverse dependencies**:
   ```bash
   buck2 query "rdeps(//..., //your:target)"
   ```

---

## Advanced Topics

### RDL Integration

RDL files generate BSV packages automatically:

```systemrdl
// my_regs.rdl
addrmap my_regs {
    reg {
        field { desc = "Enable bit"; } EN[0:0] = 0;
    } CTRL @ 0x0;
};
```

Generated BSV usage:
```bsv
import my_regs_pkg::*;

Reg#(Ctrl) ctrlReg <- mkReg(defaultValue);

ctrlReg.en <= 1'b1;  // Set enable bit
```

### Custom bsc Flags

Project-specific flags:

```starlark
bsv_library(
    name = "CustomModule",
    srcs = ["CustomModule.bsv"],
    bsc_flags = [
        "-D", "CUSTOM_WIDTH=32",     # Define macro
        "-Xc++", "-Wno-unused",      # C++ compiler flags
    ],
)
```

### Toolchain Configuration

#### BSV Library Directory

The BSV toolchain can be configured to use a custom Bluespec library directory via the `BSV_LIB_DIR` environment variable:

```bash
# Set custom Bluespec library path
export BSV_LIB_DIR=/path/to/custom/bluespec/lib

# Build with custom library path
buck2 build //hdl/ip/bsv:YourModule
```

**Configuration Details:**

- **Environment Variable**: `BSV_LIB_DIR`
- **Default Value**: `/usr/local/bluespec/lib` (if not set)
- **Config Location**: `.buckconfig` section `[bsv]`
- **Toolchain File**: `toolchains/bsv_toolchain.bzl`

The toolchain reads this value through Buck2's configuration system:

```ini
# .buckconfig
[bsv]
libdir = ${env.BSV_LIB_DIR:/opt/bsc-2022.01/lib}
```

**Override in BUCK files** (if needed):

```starlark
# toolchains/BUCK
bsv_toolchain(
    name = "bsv",
    libdir = "/custom/bluespec/path",
    visibility = ["PUBLIC"],
)
```

This is useful when:
- Using non-standard Bluespec installations
- Testing with different Bluespec versions
- Working in environments with custom toolchain paths

### Parallel Builds

Buck2 automatically parallelizes:

```bash
# Build multiple targets in parallel
buck2 build //path/to:target1 //path/to:target2 //path/to:target3
```

### Cross-Project Dependencies

Reference targets in other projects:

```starlark
deps = [
    "//hdl/ip/bsv:CommonFunctions",
    "//hdl/projects/ignition:Protocol",
]
```

---

## Additional Resources

- **Quick Start Tutorial**: [docs/BSV_QUICK_START.md](docs/BSV_QUICK_START.md) - Step-by-step guide to creating your first BSV project
- **Migration Examples**: [docs/BSV_MIGRATION_EXAMPLES.md](docs/BSV_MIGRATION_EXAMPLES.md) - Real project conversions from BUILD to BUCK
- **Optimization Guide**: [docs/BSV_OPTIMIZATION_GUIDE.md](docs/BSV_OPTIMIZATION_GUIDE.md) - Performance tuning and advanced features
- **Integration Tests**: See `hdl/ip/bsv/integration_test/` for working examples
- **Conversion Tool**: `tools/build_to_buck_converter.py` - Automated BUILD→BUCK conversion
- **Test Discovery**: `tools/bsv-tests.bxl` - BXL script for finding and running tests
- **Benchmarking**: `tools/bsv_benchmark.sh` - Compare Buck2 vs cobble performance
- **Rule Definitions**: `tools/bsv.bzl` - BSV build rule implementations
- **Buck2 Documentation**: https://buck2.build/

---

## Getting Help

1. **Check integration tests**: `hdl/ip/bsv/integration_test/`
2. **Review this guide**: Re-read relevant sections
3. **Examine working examples**: Look at existing BUCK files
4. **Use conversion tool**: `python3 tools/build_to_buck_converter.py --dry-run BUILD`

---

*Last Updated: Phase 6 - Documentation & Migration*
