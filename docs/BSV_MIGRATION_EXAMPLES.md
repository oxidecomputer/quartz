# BSV Migration Examples: BUILD to BUCK Conversions

This document shows real-world examples of converting BSV projects from cobble BUILD files to Buck2 BUCK files. Each example demonstrates different patterns and complexity levels.

## Table of Contents

1. [Example 1: Simple Module (MDIO)](#example-1-simple-module-mdio)
2. [Example 2: RDL Integration (I2C)](#example-2-rdl-integration-i2c)
3. [Example 3: Complex Project (Ignition)](#example-3-complex-project-ignition)
4. [Migration Checklist](#migration-checklist)
5. [Common Patterns](#common-patterns)

---

## Example 1: Simple Module (MDIO)

### Before: BUILD (cobble)

```python
# -*- python -*- vim:syntax=python:

bluespec_library('MDIO',
    sources = [
        'MDIO.bsv'
    ],
    deps = [
        '//hdl/ip/bsv:Bidirection',
        '//hdl/ip/bsv:Strobe',
    ])

bluespec_library('MDIOPeripheralModel',
    sources = [
        'test/MDIOPeripheralModel.bsv',
    ],
    deps = [
        ':MDIO',
    ])

bluesim_tests('MDIOTests',
    env = '//bluesim_default',
    suite = 'test/MDIOTests.bsv',
    modules = [
        'mkMDIOReadTest',
        'mkMDIOWriteTest',
        'mkMDIOIgnoreWrongPhyAddrTest',
    ],
    deps = [
        ':MDIO',
        ':MDIOPeripheralModel',
    ])
```

### After: BUCK (Buck2)

```starlark
load("//tools:bsv.bzl", "bsv_library", "bsv_bluesim_tests")

bsv_library(
    name = "MDIO",
    srcs = [
        "MDIO.bsv",
    ],
    deps = [
        "//hdl/ip/bsv:Bidirection",
        "//hdl/ip/bsv:Strobe",
    ],
)

bsv_library(
    name = "MDIOPeripheralModel",
    srcs = [
        "test/MDIOPeripheralModel.bsv",
    ],
    deps = [
        ":MDIO",
    ],
)

bsv_bluesim_tests(
    name = "MDIOTests",
    top = "test/MDIOTests.bsv",
    modules = [
        "mkMDIOReadTest",
        "mkMDIOWriteTest",
        "mkMDIOIgnoreWrongPhyAddrTest",
    ],
    deps = [
        ":MDIO",
        ":MDIOPeripheralModel",
    ],
)
```

### Key Changes

1. **Load statement**: Added `load("//tools:bsv.bzl", ...)` to import rules
2. **Rule names**: `bluespec_library` → `bsv_library`, `bluesim_tests` → `bsv_bluesim_tests`
3. **Attribute names**: `sources` → `srcs`, `suite` → `top`
4. **Removed**: `env` parameter (not needed in Buck2)
5. **Syntax**: Python-style quotes changed to Starlark double quotes

### Running Tests

```bash
# Cobble
cd build && ./cobble test //hdl/ip/bsv/MDIO:MDIOTests

# Buck2
buck2 run //hdl/ip/bsv/MDIO:MDIOTests_mkMDIOReadTest
buck2 run //hdl/ip/bsv/MDIO:MDIOTests_mkMDIOWriteTest
buck2 run //hdl/ip/bsv/MDIO:MDIOTests_mkMDIOIgnoreWrongPhyAddrTest
```

---

## Example 2: RDL Integration (I2C)

This example shows how to migrate a project with RDL register generation and multiple interdependent libraries.

### Before: BUILD (cobble)

```python
# -*- python -*- vim:syntax=python:

rdl('I2CCoreRegsPkg',
    sources = [
        'I2CCore.rdl'
    ],
    outputs = [
        'I2CCoreRegs.bsv',
        'i2c_core_regs.html',
        'i2c_core_regs.json',
    ])

bluespec_library('I2CCoreRegs',
    sources = [
        ':I2CCoreRegsPkg#I2CCoreRegs.bsv',
    ],
    deps = [
        '//hdl/ip/bsv:RegCommon',
        ':I2CCoreRegsPkg',
    ])

bluespec_library('I2CCommon',
    sources = [
        'I2CCommon.bsv',
    ],
    deps = [
        '//hdl/ip/bsv:Bidirection',
    ])

bluespec_library('I2CBitController',
    sources = [
        'I2CBitController.bsv',
    ],
    deps = [
        ':I2CCommon',
        '//hdl/ip/bsv:Strobe'
    ])

bluespec_library('I2CCore',
    sources = [
        'I2CCore.bsv',
    ],
    deps = [
        ':I2CCommon',
        ':I2CBitController',
    ])

bluespec_library('I2CPeripheralModel',
    sources = [
        'test/I2CPeripheralModel.bsv',
    ],
    deps = [
        ':I2CCommon',
        '//hdl/ip/bsv:Countdown',
        '//hdl/ip/bsv:Strobe'
    ])

bluesim_tests('I2CBitControllerTests',
    env = '//bluesim_default',
    suite = 'test/I2CBitControllerTests.bsv',
    modules = [
        'mkI2CBitControlOneByteWriteTest',
        'mkI2CBitControlOneByteReadTest',
        'mkI2CBitControlSequentialWriteTest',
        'mkI2CBitControlSequentialReadTest',
        'mkI2CBitControlRandomReadTest',
        'mkI2CBitControlSclStretchTest',
        'mkI2CBitControlSclStretchTimeoutTest',
    ],
    deps = [
        ':I2CBitController',
        ':I2CCommon',
        ':I2CPeripheralModel',
    ])

bluesim_tests('I2CCoreTests',
    env = '//bluesim_default',
    suite = 'test/I2CCoreTests.bsv',
    modules = [
        'mkI2CCoreOneByteWriteTest',
        'mkI2CCoreOneByteReadTest',
        'mkI2CCoreSequentialWriteTest',
        'mkI2CCoreSequentialReadTest',
        'mkI2CCoreRandomReadTest',
        'mkI2CCoreSclStretchTest',
        'mkI2CCoreSclStretchTimeoutTest',
        'mkI2CCoreAbortTest',
    ],
    deps = [
        ':I2CBitController',
        ':I2CCommon',
        ':I2CCore',
        ':I2CPeripheralModel',
    ])
```

### After: BUCK (Buck2)

```starlark
load("//tools:bsv.bzl", "bsv_library", "bsv_bluesim_tests")
load("//tools:rdl.bzl", "rdl_file")

rdl_file(
    name = "I2CCoreRegsPkg",
    src = "I2CCore.rdl",
    outputs = [
        "I2CCoreRegs.bsv",
        "i2c_core_regs.html",
        "i2c_core_regs.json",
    ],
)

bsv_library(
    name = "I2CCoreRegs",
    srcs = [
        ":I2CCoreRegsPkg#I2CCoreRegs.bsv",
    ],
    deps = [
        "//hdl/ip/bsv:RegCommon",
        ":I2CCoreRegsPkg",
    ],
)

bsv_library(
    name = "I2CCommon",
    srcs = [
        "I2CCommon.bsv",
    ],
    deps = [
        "//hdl/ip/bsv:Bidirection",
    ],
)

bsv_library(
    name = "I2CBitController",
    srcs = [
        "I2CBitController.bsv",
    ],
    deps = [
        ":I2CCommon",
        "//hdl/ip/bsv:Strobe",
    ],
)

bsv_library(
    name = "I2CCore",
    srcs = [
        "I2CCore.bsv",
    ],
    deps = [
        ":I2CCommon",
        ":I2CBitController",
    ],
)

bsv_library(
    name = "I2CPeripheralModel",
    srcs = [
        "test/I2CPeripheralModel.bsv",
    ],
    deps = [
        ":I2CCommon",
        "//hdl/ip/bsv:Countdown",
        "//hdl/ip/bsv:Strobe",
    ],
)

bsv_bluesim_tests(
    name = "I2CBitControllerTests",
    top = "test/I2CBitControllerTests.bsv",
    modules = [
        "mkI2CBitControlOneByteWriteTest",
        "mkI2CBitControlOneByteReadTest",
        "mkI2CBitControlSequentialWriteTest",
        "mkI2CBitControlSequentialReadTest",
        "mkI2CBitControlRandomReadTest",
        "mkI2CBitControlSclStretchTest",
        "mkI2CBitControlSclStretchTimeoutTest",
    ],
    deps = [
        ":I2CBitController",
        ":I2CCommon",
        ":I2CPeripheralModel",
    ],
)

bsv_bluesim_tests(
    name = "I2CCoreTests",
    top = "test/I2CCoreTests.bsv",
    modules = [
        "mkI2CCoreOneByteWriteTest",
        "mkI2CCoreOneByteReadTest",
        "mkI2CCoreSequentialWriteTest",
        "mkI2CCoreSequentialReadTest",
        "mkI2CCoreRandomReadTest",
        "mkI2CCoreSclStretchTest",
        "mkI2CCoreSclStretchTimeoutTest",
        "mkI2CCoreAbortTest",
    ],
    deps = [
        ":I2CBitController",
        ":I2CCommon",
        ":I2CCore",
        ":I2CPeripheralModel",
    ],
)
```

### Key Changes

1. **RDL rule**: `rdl()` → `rdl_file()`, `sources` → `src` (singular)
2. **Load statements**: Added both `bsv.bzl` and `rdl.bzl` imports
3. **Dependency structure**: Remains identical (Buck2 handles transitive deps automatically)
4. **Generated files**: Same syntax for referencing generated BSV files (`:I2CCoreRegsPkg#I2CCoreRegs.bsv`)

### Building and Testing

```bash
# Build RDL package
buck2 build //hdl/ip/bsv/I2C:I2CCoreRegsPkg

# Build libraries
buck2 build //hdl/ip/bsv/I2C:I2CCore

# Run specific test
buck2 run //hdl/ip/bsv/I2C:I2CBitControllerTests_mkI2CBitControlOneByteWriteTest

# Run all tests in a suite
for test in mkI2CBitControlOneByteWriteTest mkI2CBitControlOneByteReadTest mkI2CBitControlSequentialWriteTest; do
    buck2 run //hdl/ip/bsv/I2C:I2CBitControllerTests_${test}
done
```

---

## Example 3: Complex Project (Ignition)

This example demonstrates advanced features including custom bsc_flags and Verilog generation.

### Before: BUILD (cobble) - Partial

```python
# -*- python -*- vim:syntax=python:

bluespec_library('Target',
    sources = [
        'IgnitionTarget.bsv',
    ],
    deps = [
        ':Transceiver',
        '//hdl/projects/ignitionlet:Board',
        '//hdl/ip/bsv:Countdown',
        '//hdl/ip/bsv:SchmittReg',
        '//hdl/ip/bsv:Strobe',
    ],
    using = {
        'bsc_flags': [
            # Bluesim generated C++ output seems to trigger compiler warnings.
            # Silence these for now.
            '-Xc++', '-Wno-dangling-else',
            '-Xc++', '-Wno-bool-operation',
        ],
    })

bluespec_library('TargetWrapper',
    sources = [
        'IgnitionTargetTop.bsv',
        'IgnitionTargetWrapper.bsv',
    ],
    deps = [
        ':Target',
        '//hdl/ip/bsv:BitSampling',
        '//hdl/ip/bsv:InitialReset',
        '//hdl/ip/bsv:IOSync',
        '//hdl/ip/bsv:SchmittReg',
        '//hdl/ip/bsv:Strobe',
        '//hdl/ip/bsv/interfaces:ICE40',
    ],
    using = {
        # The folling script is needed to fix the inout syntax used in the
        # generated Verilog.
        'bsc_flags': [
            '-verilog-filter', ROOT + '/vnd/bluespec/basicinout.pl',
        ]
    })

rdl('ignition_controller_registers',
    sources = [
        'ignition_controller.rdl',
    ],
    outputs = [
        'IgnitionControllerRegisters.bsv',
        'ignition_controller.html',
        'ignition_controller.adoc',
        'ignition_controller.json',
    ])

bluespec_library('ControllerRegisters',
    sources = [
        ':ignition_controller_registers#IgnitionControllerRegisters.bsv',
    ],
    deps = [
        ':ignition_controller_registers',
        '//hdl/ip/bsv:RegCommon',
    ])

bluespec_verilog('mkTransceiver',
    env = 'ignition_target',
    top = 'IgnitionTransceiver.bsv',
    modules = [
        'mkTransceiver',
    ],
    deps = [
        ':Transceiver',
    ],
    local = {
        'bsc_flags': [
            '-opt-undetermined-vals',
            '-unspecified-to', 'X',
        ],
    })
```

### After: BUCK (Buck2)

```starlark
load("//tools:bsv.bzl", "bsv_library", "bsv_verilog")
load("//tools:rdl.bzl", "rdl_file")

bsv_library(
    name = "Target",
    srcs = [
        "IgnitionTarget.bsv",
    ],
    deps = [
        ":Transceiver",
        "//hdl/projects/ignitionlet:Board",
        "//hdl/ip/bsv:Countdown",
        "//hdl/ip/bsv:SchmittReg",
        "//hdl/ip/bsv:Strobe",
    ],
    bsc_flags = [
        # Bluesim generated C++ output seems to trigger compiler warnings.
        # Silence these for now.
        "-Xc++",
        "-Wno-dangling-else",
        "-Xc++",
        "-Wno-bool-operation",
    ],
)

bsv_library(
    name = "TargetWrapper",
    srcs = [
        "IgnitionTargetTop.bsv",
        "IgnitionTargetWrapper.bsv",
    ],
    deps = [
        ":Target",
        "//hdl/ip/bsv:BitSampling",
        "//hdl/ip/bsv:InitialReset",
        "//hdl/ip/bsv:IOSync",
        "//hdl/ip/bsv:SchmittReg",
        "//hdl/ip/bsv:Strobe",
        "//hdl/ip/bsv/interfaces:ICE40",
    ],
    bsc_flags = [
        # The following script is needed to fix the inout syntax used in the
        # generated Verilog.
        "-verilog-filter",
        "$(location //vnd/bluespec:basicinout.pl)",
    ],
)

rdl_file(
    name = "ignition_controller_registers",
    src = "ignition_controller.rdl",
    outputs = [
        "IgnitionControllerRegisters.bsv",
        "ignition_controller.html",
        "ignition_controller.adoc",
        "ignition_controller.json",
    ],
)

bsv_library(
    name = "ControllerRegisters",
    srcs = [
        ":ignition_controller_registers#IgnitionControllerRegisters.bsv",
    ],
    deps = [
        ":ignition_controller_registers",
        "//hdl/ip/bsv:RegCommon",
    ],
)

bsv_verilog(
    name = "mkTransceiver",
    top = "IgnitionTransceiver.bsv",
    modules = [
        "mkTransceiver",
    ],
    deps = [
        ":Transceiver",
    ],
    bsc_flags = [
        "-opt-undetermined-vals",
        "-unspecified-to",
        "X",
    ],
)
```

### Key Changes

1. **Custom flags**: `using = {'bsc_flags': [...]}` → direct `bsc_flags = [...]` attribute
2. **Flag format**: Single quotes → double quotes, separate list items
3. **Path references**: `ROOT + '/vnd/bluespec/basicinout.pl'` → `"$(location //vnd/bluespec:basicinout.pl)"`
4. **Verilog generation**: `bluespec_verilog()` → `bsv_verilog()`
5. **Removed parameters**: `env` and `local` are no longer needed

### Important Note: Path References in bsc_flags

When referencing files in `bsc_flags`, use Buck2's location macro:

**Cobble:**
```python
'bsc_flags': ['-verilog-filter', ROOT + '/vnd/bluespec/basicinout.pl']
```

**Buck2:**
```starlark
bsc_flags = ["-verilog-filter", "$(location //vnd/bluespec:basicinout.pl)"]
```

This ensures Buck2 tracks the dependency and uses the correct path.

### Building Verilog

```bash
# Generate Verilog for synthesis
buck2 build //hdl/ip/bsv/ignition:mkTransceiver

# Output location
buck2 build //hdl/ip/bsv/ignition:mkTransceiver --show-output
```

---

## Migration Checklist

Use this checklist when migrating a BSV project:

### Pre-Migration

- [ ] Read the existing BUILD file and understand all rules
- [ ] Identify custom bsc_flags and note any special requirements
- [ ] List all RDL dependencies
- [ ] Document any special build environment requirements

### Rule Conversion

- [ ] Add `load()` statements at the top of BUCK file
- [ ] Convert `bluespec_library` → `bsv_library`
- [ ] Convert `bluesim_tests` → `bsv_bluesim_tests`
- [ ] Convert `bluespec_verilog` → `bsv_verilog`
- [ ] Convert `bluespec_sim` → `bsv_sim` (if used)
- [ ] Convert `rdl` → `rdl_file`

### Attribute Conversion

- [ ] Change `sources` → `srcs`
- [ ] Change `suite` → `top`
- [ ] Move `using = {'bsc_flags': [...]}` → `bsc_flags = [...]`
- [ ] Move `local = {'bsc_flags': [...]}` → `bsc_flags = [...]`
- [ ] Convert path references to use `$(location ...)` macro
- [ ] Remove `env` parameter (not needed)
- [ ] Keep `deps` unchanged

### Syntax Changes

- [ ] Change single quotes to double quotes
- [ ] Remove Python shebang (`# -*- python -*- vim:syntax=python:`)
- [ ] Add trailing commas (Starlark style)
- [ ] Format lists consistently

### Testing

- [ ] Build each library target: `buck2 build //path:target`
- [ ] Run each test: `buck2 run //path:TestSuite_mkTestName`
- [ ] Generate Verilog if applicable: `buck2 build //path:verilog_target`
- [ ] Compare .bo file sizes/checksums with cobble build (optional)
- [ ] Verify all transitive dependencies are resolved

### Documentation

- [ ] Update any project README mentioning build commands
- [ ] Update CI/CD scripts if they reference cobble
- [ ] Document any Buck2-specific quirks or workarounds

---

## Common Patterns

### Pattern 1: Simple Library with Dependencies

**Cobble:**
```python
bluespec_library('MyModule',
    sources = ['MyModule.bsv'],
    deps = ['//hdl/ip/bsv:Countdown'])
```

**Buck2:**
```starlark
bsv_library(
    name = "MyModule",
    srcs = ["MyModule.bsv"],
    deps = ["//hdl/ip/bsv:Countdown"],
)
```

### Pattern 2: Multi-File Library

**Cobble:**
```python
bluespec_library('Protocol',
    sources = [
        'IgnitionProtocol.bsv',
        'IgnitionProtocolDeparser.bsv',
        'IgnitionProtocolParser.bsv',
    ],
    deps = [
        '//hdl/ip/bsv:SettableCRC',
        '//hdl/ip/bsv:Encoding8b10b',
    ])
```

**Buck2:**
```starlark
bsv_library(
    name = "Protocol",
    srcs = [
        "IgnitionProtocol.bsv",
        "IgnitionProtocolDeparser.bsv",
        "IgnitionProtocolParser.bsv",
    ],
    deps = [
        "//hdl/ip/bsv:SettableCRC",
        "//hdl/ip/bsv:Encoding8b10b",
    ],
)
```

### Pattern 3: RDL + BSV Library

**Cobble:**
```python
rdl('my_regs',
    sources = ['my_regs.rdl'],
    outputs = ['MyRegs.bsv', 'my_regs.html'])

bluespec_library('MyRegs',
    sources = [':my_regs#MyRegs.bsv'],
    deps = [':my_regs', '//hdl/ip/bsv:RegCommon'])
```

**Buck2:**
```starlark
rdl_file(
    name = "my_regs",
    src = "my_regs.rdl",
    outputs = ["MyRegs.bsv", "my_regs.html"],
)

bsv_library(
    name = "MyRegs",
    srcs = [":my_regs#MyRegs.bsv"],
    deps = [":my_regs", "//hdl/ip/bsv:RegCommon"],
)
```

### Pattern 4: Test Suite

**Cobble:**
```python
bluesim_tests('MyTests',
    env = '//bluesim_default',
    suite = 'test/MyTests.bsv',
    modules = ['mkTest1', 'mkTest2'],
    deps = [':MyModule'])
```

**Buck2:**
```starlark
bsv_bluesim_tests(
    name = "MyTests",
    top = "test/MyTests.bsv",
    modules = ["mkTest1", "mkTest2"],
    deps = [":MyModule"],
)
```

### Pattern 5: Verilog Generation with Custom Flags

**Cobble:**
```python
bluespec_verilog('my_verilog',
    env = 'my_env',
    top = 'MyTop.bsv',
    modules = ['mkMyTop'],
    deps = [':MyModule'],
    local = {
        'bsc_flags': ['-opt-undetermined-vals', '-unspecified-to', 'X'],
    })
```

**Buck2:**
```starlark
bsv_verilog(
    name = "my_verilog",
    top = "MyTop.bsv",
    modules = ["mkMyTop"],
    deps = [":MyModule"],
    bsc_flags = [
        "-opt-undetermined-vals",
        "-unspecified-to",
        "X",
    ],
)
```

### Pattern 6: Library with Custom Compiler Flags

**Cobble:**
```python
bluespec_library('MyModule',
    sources = ['MyModule.bsv'],
    deps = [],
    using = {
        'bsc_flags': ['-Xc++', '-Wno-dangling-else'],
    })
```

**Buck2:**
```starlark
bsv_library(
    name = "MyModule",
    srcs = ["MyModule.bsv"],
    deps = [],
    bsc_flags = [
        "-Xc++",
        "-Wno-dangling-else",
    ],
)
```

---

## Automated Conversion

For most projects, the automated conversion tool handles the migration:

```bash
# Convert a single BUILD file
python tools/build_to_buck_converter.py hdl/ip/bsv/MDIO/BUILD

# Preview without writing
python tools/build_to_buck_converter.py hdl/ip/bsv/I2C/BUILD --dry-run

# Batch convert all BSV BUILD files
find hdl/ip/bsv -name BUILD -type f -exec \
    python tools/build_to_buck_converter.py {} \;
```

### Manual Review Required

Always review the converted BUCK file for:

1. **Path references in bsc_flags**: May need `$(location ...)` macro
2. **Environment-specific settings**: `env` parameter is removed, verify if needed elsewhere
3. **Comments**: Preserved but may need reformatting
4. **Complex flag combinations**: Verify flag order and format

---

## Troubleshooting Conversions

### Issue: Module not found after conversion

**Problem:** `Error: Module 'MyModule' not found in package path`

**Solution:** Check that dependencies are correctly converted and that transitive dependencies are included.

```bash
# Verify target builds
buck2 build //hdl/ip/bsv:MyModule --verbose 10

# Check dependency graph
buck2 query "deps(//hdl/ip/bsv:MyModule)"
```

### Issue: RDL-generated BSV packages

**Problem:** `Error: Cannot compile RDL-generated package`

**Solution:** Use sub-target syntax `[bsv]` to reference only BSV output:

```starlark
# RDL file generates multiple outputs (.bsv, .html, .json)
rdl_file(
    name = "my_regs_rdl",
    src = "my_regs.rdl",
    outputs = [
        "MyRegs.bsv",
        "my_regs.html",
        "my_regs.json",
    ],
)

# BSV library uses only the .bsv output via sub-target
bsv_library(
    name = "MyRegs",
    srcs = [":my_regs_rdl[bsv]"],  # ← Use [bsv] sub-target, not full target
    deps = ["//hdl/ip/bsv:RegCommon"],
)
```

**Common mistake:** Using the full RDL target causes BSC to try compiling `.html` and `.json` files.

### Issue: Custom bsc_flags not working

**Problem:** `Error: File not found` when using `-verilog-filter`

**Solution:** Use `$(location ...)` macro for file references:

```starlark
bsc_flags = [
    "-verilog-filter",
    "$(location //vnd/bluespec:basicinout.pl)",
],
```

### Issue: Test target not found

**Problem:** `buck2 run //path:MyTests` fails

**Solution:** Use the expanded test name with module suffix:

```bash
# Wrong
buck2 run //hdl/ip/bsv/MDIO:MDIOTests

# Correct
buck2 run //hdl/ip/bsv/MDIO:MDIOTests_mkMDIOReadTest
```

---

## Next Steps After Migration

1. **Update CI/CD**: Modify build scripts to use `buck2` commands
2. **Update Documentation**: Update project README with Buck2 build instructions
3. **Team Communication**: Share migration guide with team
4. **Gradual Rollout**: Migrate projects incrementally, validate each
5. **Remove Cobble**: After all projects migrated and validated, consider removing cobble (optional)

---

## Additional Resources

- [BSV_BUCK2_GUIDE.md](../BSV_BUCK2_GUIDE.md) - Comprehensive Buck2 BSV build system guide
- [BUCK_RULES.md](../BUCK_RULES.md) - Detailed Buck2 rule reference
- [tools/build_to_buck_converter.py](../tools/build_to_buck_converter.py) - Automated conversion tool
- [hdl/ip/bsv/integration_test/](../hdl/ip/bsv/integration_test/) - Example test project
