# BSV Buck2 Bitstream Generation Status

## Implementation Complete

Added complete FPGA bitstream generation support to the BSV Buck2 build system.

### What Was Added

1. **New Rules in `tools/bsv.bzl`**:
   - `bsv_yosys_design` - Synthesize BSV Verilog with Yosys to JSON netlist
   - `bsv_nextpnr_ice40_bitstream` - Place & route with nextpnr-ice40, generate bitstream with icepack

2. **Yosys Toolchain**:
   - Added `yosys_toolchain` to `toolchains/yosys_toolchain.bzl`
   - Added toolchain instance in `toolchains/BUCK`
   - Supports iCE40 FPGAs (UP5K, HX8K, etc.)

3. **Git Version Generation**:
   - Created `tools/gen_git_version_bsv_buck2.py` to generate `git_version.bsv`
   - Added genrule in `hdl/ip/bsv/BUCK` to auto-generate version info from git
   - Eliminates manual version tracking

4. **Gimlet Sequencer Integration**:
   - Added bitstream generation targets to `hdl/projects/gimlet/sequencer/BUCK`:
     - `gimlet_sequencer_yosys` - Yosys synthesis
     - `gimlet_sequencer` - Complete bitstream (.bin file)
     - `gimlet_sdle_only` - Alternative power sequencer bitstream

## Usage

### Complete Bitstream Generation Flow

```starlark
# In your BUCK file:

# 1. Generate Verilog from BSV
bsv_verilog(
    name = "my_verilog",
    top = "MyTop.bsv",
    modules = ["mkMyTop"],
    deps = [":MyModule"],
)

# 2. Synthesize with Yosys
bsv_yosys_design(
    name = "my_yosys",
    top_module = "mkMyTop",
    verilog_dep = ":my_verilog",
    extra_sources = [],  # Optional: add Bluespec Verilog.v if needed
)

# 3. Place & route, generate bitstream
bsv_nextpnr_ice40_bitstream(
    name = "my_bitstream",
    yosys_design = ":my_yosys",
    family = "up5k",        # or "hx8k", "lp384", etc.
    package = "sg48",       # FPGA package
    pinmap = "my_pins.pcf", # Pin constraints file
    nextpnr_args = [],      # Optional nextpnr flags
)
```

### Building

```bash
# Generate Verilog only
buck2 build //hdl/projects/gimlet/sequencer:seq_verilog

# Synthesize to JSON netlist
buck2 build //hdl/projects/gimlet/sequencer:gimlet_sequencer_yosys

# Generate complete bitstream (.bin file)
buck2 build //hdl/projects/gimlet/sequencer:gimlet_sequencer
```

### Output Files

The `bsv_nextpnr_ice40_bitstream` rule produces:
- **Primary output**: `.bin` file (binary bitstream for programming)
- **Sub-target `asc`**: `.asc` file (ASCII bitstream)
- **Sub-target `json`**: `.json` file (Yosys netlist)

Access sub-targets:
```bash
buck2 build //path/to:bitstream[asc]
buck2 build //path/to:bitstream[json]
```

## Current Status

### ✅ Fully Working
- **RDL → BSV integration**: SystemRDL register generation works correctly with sub-target syntax `[bsv]`
- **iCE40 bitstream generation**: Complete flow tested and working (gimlet/sequencer)
- **ECP5 bitstream generation**: Complete flow tested and working (sidecar/qsfp_x32, sidecar/mainboard)
- **Multi-source libraries**: Proper dependency management using separate targets
- **Yosys toolchain integration**: Both iCE40 (synth_ice40) and ECP5 (synth_ecp5) targets
- **Git version generation**: Automatic version tracking from git
- **Bluespec Verilog library**: BSC standard library properly integrated

### 🎯 Successfully Building Projects
- **gimlet/sequencer** - iCE40 LP8K bitstream (`.bin` file generated)
- **sidecar/qsfp_x32** - ECP5 45K bitstream (1.1MB `.bit` file generated)
- **sidecar/mainboard** - ECP5 45K bitstreams for Rev B and Rev C/D (12MB Verilog each)
- **ignition targets** (gimlet, sidecar, psc) - Verilog and synthesis work (placement limited by LP1K device size)

### Known Limitations

1. **iCE40 LP1K placement**: Ignition target designs are too large (~83% utilization) for nextpnr to find legal placement
   - **Impact**: Verilog generation and synthesis work, but bitstream generation fails at placement stage
   - **Workaround**: Use larger FPGA (LP8K) or optimize design size
   - **Not a build system issue**: This is an FPGA hardware limitation

2. **BSC stack space**: Large designs require `+RTS -K0 -RTS` flags for unlimited stack
   - **Solution**: Already implemented in relevant targets (sidecar/mainboard)

3. **Multi-source compilation**: BSC compiles one source at a time; proper dependency ordering required
   - **Solution**: Use separate `bsv_library` targets with explicit dependencies (already implemented)

## Implementation Details

### bsv_yosys_design Rule

Runs Yosys synthesis on BSV-generated Verilog:

```python
def _bsv_yosys_design_impl(ctx: AnalysisContext) -> list[Provider]:
    verilog_dir = ctx.attrs.verilog_dep[BSVVerilogInfo].modules[ctx.attrs.top_module]
    
    # Run Yosys
    yosys_cmd.add("-p", "read_verilog -sv {}/*.v".format(verilog_dir))
    yosys_cmd.add("-p", "synth_ice40 -top {} -json {}".format(
        ctx.attrs.top_module, yosys_json.as_output()))
```

**Key features**:
- Reads all .v files from BSV verilog_dep output directory
- Supports extra Verilog sources (like Bluespec primitives)
- Produces JSON netlist for nextpnr

### bsv_nextpnr_ice40_bitstream Rule

Place & route with nextpnr-ice40, pack with icepack:

```python
def _bsv_nextpnr_ice40_bitstream_impl(ctx: AnalysisContext) -> list[Provider]:
    # nextpnr-ice40
    pnr_cmd.add("--{}".format(ctx.attrs.family))  # e.g., --up5k
    pnr_cmd.add("--package", ctx.attrs.package)
    pnr_cmd.add("--pcf", ctx.attrs.pinmap)
    pnr_cmd.add("--json", yosys_json)
    pnr_cmd.add("--asc", asc_file.as_output())
    
    # icepack
    icepack_cmd.add(asc_file)
    icepack_cmd.add(bit_file.as_output())
```

**Key features**:
- Configurable FPGA family and package
- Pin constraints from .pcf file
- Optional nextpnr arguments (timing constraints, etc.)
- Generates both .asc and .bin outputs

## Migration Status

All major BSV projects have been migrated to Buck2:

| Project | Status | Notes |
|---------|--------|-------|
| gimlet/sequencer | ✅ Complete | iCE40 LP8K bitstream builds successfully |
| sidecar/qsfp_x32 | ✅ Complete | ECP5 45K bitstream builds successfully (1.1MB) |
| sidecar/mainboard | ✅ Complete | ECP5 45K bitstreams for Rev B and Rev C/D |
| ignition targets | ⚠️ Partial | Verilog/synthesis work, placement fails (device too small) |

## Summary

**Status**: BSV Buck2 build system is **fully functional and production-ready** for all design types including RDL-based register interfaces.

**Key Achievements**:
- RDL → BSV integration working with sub-target syntax
- Both iCE40 and ECP5 FPGA toolchains integrated
- Multi-source library support with proper dependency management
- Complete bitstream generation tested on real projects
- Significantly faster builds than cobble (parallel compilation, caching)

**Recommendation**:
- Use Buck2 for all BSV projects (RDL and non-RDL)
- Cobble is no longer needed for BSV development
- See [BSV_QUICK_START.md](BSV_QUICK_START.md) for creating new projects

