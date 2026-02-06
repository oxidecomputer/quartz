# BUILD to BUCK Converter

Automated tool for converting cobble BUILD files to Buck2 BUCK files for BSV projects.

## Usage

```bash
python3 tools/build_to_buck_converter.py <BUILD_file> [options]
```

### Options

- `--output PATH`, `-o PATH`: Specify output BUCK file path (default: `BUCK` in same directory)
- `--dry-run`: Print converted output to stdout instead of writing to file

### Examples

```bash
# Convert and save to default location
python3 tools/build_to_buck_converter.py hdl/ip/bsv/MDIO/BUILD

# Preview conversion without writing
python3 tools/build_to_buck_converter.py hdl/ip/bsv/I2C/BUILD --dry-run

# Save to custom location
python3 tools/build_to_buck_converter.py hdl/ip/bsv/ignition/BUILD -o /tmp/BUCK.test
```

## Supported Conversions

| Cobble Rule | Buck2 Rule | Status |
|-------------|------------|--------|
| `bluespec_library` | `bsv_library` | ✅ Fully supported |
| `bluespec_verilog` | `bsv_verilog` | ✅ Fully supported |
| `bluespec_sim` | `bsv_sim` | ✅ Fully supported |
| `bluesim_binary` | `bsv_bluesim_binary` | ⚠️ Requires manual `entry_point` |
| `bluesim_tests` | `bsv_bluesim_tests` | ✅ Fully supported |
| `rdl` | `rdl_file` | ✅ Fully supported |
| `bsv_fpga_version` | N/A | ⚠️ Skipped (needs custom handling) |
| `yosys_design` | N/A | ⚠️ Skipped (out of scope) |
| `c_binary` | N/A | ⚠️ Skipped (out of scope) |

## Attribute Mappings

### General Mappings

- `sources` → `srcs`
- `suite` → `top` (for bluesim_tests)
- Dependency paths preserved: `//hdl/ip/bsv:Target` or `:LocalTarget`

### Removed Attributes

- `env` - Buck2 doesn't use explicit environment names
- `using` - Compiler flags extracted to `bsc_flags`
- `local` - Compiler flags merged into `bsc_flags`
- `extra` - Cobble-specific, not applicable to Buck2

### bsc_flags Extraction

Compiler flags from `using` and `local` dictionaries are automatically extracted:

**Cobble:**
```python
bluespec_library('Target',
    sources = ['Target.bsv'],
    using = {
        'bsc_flags': ['-Xc++', '-Wno-dangling-else'],
    },
    local = {
        'bsc_flags': ['-opt-undetermined-vals'],
    })
```

**Buck2:**
```starlark
bsv_library(
    name = "Target",
    srcs = ["Target.bsv"],
    bsc_flags = [
        "-Xc++",
        "-Wno-dangling-else",
        "-opt-undetermined-vals",
    ],
)
```

## Known Limitations and Manual Adjustments

### 1. RDL Output References

Cobble allows referencing specific RDL outputs using `#` syntax:

```python
# Cobble
sources = [':I2CCoreRegsPkg#I2CCoreRegs.bsv']
```

Buck2 currently requires direct target references:

```starlark
# Buck2 (current)
srcs = [":I2CCoreRegsPkg"]  # References the RDL target directly
```

**Manual Fix**: Currently, remove `#output` references and depend on the RDL target. The BSV file will be available in the search path.

### 2. Entry Points for bluesim_binary

Cobble infers entry points from module references:

```python
# Cobble
bluesim_binary('test',
    top = ':sim_target#mkTestModule',
    ...)
```

Buck2 requires explicit entry_point:

```starlark
# Buck2 - REQUIRES MANUAL ADDITION
bsv_bluesim_binary(
    name = "test",
    top = ":sim_target",
    entry_point = "mkTestModule",  # Must be added manually
    ...)
```

**Manual Fix**: Add `entry_point` attribute with the module name from the original `#moduleName` reference.

### 3. Variable References

Cobble BUILD files may use Python variables:

```python
# Cobble
sources = [ROOT + '/path/to/file.bsv']
```

Converter marks these as `<expression>` for manual review:

```starlark
# Buck2 (needs manual fix)
srcs = ["<expression>"]
```

**Manual Fix**: Replace with actual file path or Buck2 target reference.

### 4. Environment-Specific Targets

Cobble uses named environments for concrete builds:

```python
# Cobble
bluespec_verilog('mkModule',
    env = 'ignition_target',
    ...)
```

Buck2 handles this through platform constraints (not currently implemented):

```starlark
# Buck2 (environment removed)
bsv_verilog(
    name = "mkModule",
    # env attribute removed
    ...)
```

**Manual Fix**: If environment-specific flags are needed, add them to `bsc_flags`.

## Workflow

### Step 1: Convert

```bash
cd /path/to/quartz
python3 tools/build_to_buck_converter.py hdl/ip/bsv/MDIO/BUILD
```

### Step 2: Review

Open the generated `BUCK` file and check for:
- `<expression>` placeholders
- Skipped rules (listed at bottom of file)
- Missing `entry_point` in `bsv_bluesim_binary` rules
- RDL output references with `#`

### Step 3: Test

```bash
buck2 build //hdl/ip/bsv/MDIO:
```

### Step 4: Fix Issues

Address any build errors:
- Add missing `entry_point` attributes
- Resolve `#output` references
- Add any missing dependencies

## Batch Conversion

To convert all BUILD files in a directory tree:

```bash
#!/bin/bash
# Find all BUILD files and convert them
find hdl/ip/bsv -name BUILD -type f | while read build_file; do
    echo "Converting $build_file..."
    python3 tools/build_to_buck_converter.py "$build_file"
done
```

## Testing Converted Files

After conversion, test the BUCK file:

```bash
# List all targets
buck2 targets //hdl/ip/bsv/MDIO:

# Build all targets
buck2 build //hdl/ip/bsv/MDIO:

# Run tests
buck2 test //hdl/ip/bsv/MDIO:
```

## Implementation Details

The converter uses Python's `ast` module to parse cobble BUILD files as Python AST, extracting function calls and their arguments. It then generates Starlark-compatible syntax for Buck2.

### Key Files

- `tools/build_to_buck_converter.py` - Main converter script
- `tools/bsv.bzl` - Buck2 BSV build rules
- `tools/rdl.bzl` - Buck2 RDL build rules

### Architecture

1. **Parse**: Read BUILD file and parse as Python AST
2. **Extract**: Walk AST to find rule calls (bluespec_library, rdl, etc.)
3. **Map**: Convert cobble rules to Buck2 rules using mapping table
4. **Transform**: Convert attributes (sources→srcs, extract bsc_flags, etc.)
5. **Generate**: Output Starlark-formatted BUCK file

## Troubleshooting

### Error: "Unrecognized rule"

Some cobble rules are not yet supported. Check the "Skipped rules" section at the bottom of generated BUCK files.

### Error: "Cannot find module"

RDL-generated BSV packages may need the RDL target as a dependency. Ensure RDL targets are built before libraries that use them.

### Error: "entry_point attribute required"

Add the module name to `bsv_bluesim_binary` rules:

```starlark
bsv_bluesim_binary(
    name = "test",
    top = ":sim_target",
    entry_point = "mkTestModule",  # Add this
)
```

## Future Enhancements

- [ ] Automatic entry_point inference from `#moduleName` references
- [ ] Handle `#output` references by generating intermediate targets
- [ ] Support `bsv_fpga_version` rule
- [ ] Variable resolution for `ROOT` and other BUILD variables
- [ ] Batch conversion with dependency ordering
- [ ] Validation mode (check for common issues)
- [ ] Platform/constraint handling for environment-specific builds

## Contributing

To add support for new rules:

1. Add mapping to `RULE_MAPPING` dict in converter
2. Add attribute transformation in `_convert_*_attrs()` methods
3. Update documentation
4. Test on real BUILD files
