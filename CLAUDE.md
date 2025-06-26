# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Quartz is a collection of soft-logic designs and hardware abstraction libraries (HALs) for various subsystems found in Oxide hardware. This includes components such as Ignition, power sequencing for system boards, and QSFP interface management.

## Build System

Quartz uses two build systems in parallel:

### Buck2 (Primary/Modern)
- Used for VHDL and RDL flows with VUnit simulations
- Supports Xilinx FPGA toolchain integration
- Supports Lattice FPGAs via Yosys and GDHL VHDL plugin

#### Prerequisites
- Buck2 installed: `cargo +nightly-2024-10-13 install --git https://github.com/facebook/buck2.git --tag "2025-02-01" buck2`
- Python 3.10+ with packages: `pip install -r tools/requirements.txt`
- NVC simulator (minimum version 1.13.1)
- Vivado on PATH for Xilinx designs

#### Key Commands
- `buck2 ctargets /...` - List all available targets
- `buck2 run <target>` - Run a simulation
- `buck2 bxl //tools/vunit-sims.bxl:vunit_sim_gen` - List all simulation testbenches
- `buck2 run //tools/multitool:multitool -- lsp-toml` - Generate vhdl_ls.toml for LSP
- `buck2 run //tools/multitool:multitool -- format` - Auto-format VHDL code
- `buck2 run //tools/multitool:multitool -- tb-gen --name <name> --path <path>` - Generate testbench boilerplate

#### Running All Simulations
```bash
buck2 bxl //tools/vunit-sims.bxl:vunit_sim_gen | while IFS= read -r line; do eval "$line" ; done
```

### Cobble (Legacy)
- Used for BSV designs and RDL generation targeting yosys toolchain
- Requires BUILD.vars configuration (copy BUILD.vars.example and adapt paths)
- See COBALT_README.md for detailed instructions

## Architecture

### Directory Structure
- `hdl/ip/` - Reusable IP blocks
  - `bsv/` - Bluespec SystemVerilog IP (BUILD-based)
  - `vhd/` - VHDL IP modules (BUCK-based)
- `hdl/projects/` - Complete FPGA designs for specific hardware
  - Each project contains top-level designs, constraints, and project-specific modules
- `tools/` - Build system utilities and custom tools
- `prelude/` - Buck2 build rules and configurations
- `vnd/` - Vendor/third-party dependencies

### VHDL Module Organization
Each VHDL module should have its own `vhdl_unit` rule in BUCK files. Package files that are reused across modules should be in separate rules. Dependencies are specified via the `deps` attribute.

### SystemRDL Integration
- Each RDL file gets its own `rdl_file` rule
- Generates VHDL packages, BSV modules, JSON, HTML documentation
- Address maps with nested instances require bottom-to-top ordering

## Key Hardware Projects
- **cosmo_seq** - SP5 sequencer for Oxide systems
- **cosmo_hp** - Hot plug controller
- **grapefruit** - FPGA design with ESPI and peripheral interfaces
- **gimlet** - System sequencer with ignition support
- **sidecar** - Network switch controller with QSFP management

## Development Tools

### Code Formatting
VHDL code uses vhdl-style-guide with custom rules in `vsg_config.json`. Format code with:
```bash
buck2 run //tools/multitool:multitool -- format
```

### LSP Support
Generate vhdl_ls.toml for VHDL language server:
```bash
buck2 run //tools/multitool:multitool -- lsp-toml
```

### Release Tool
For FPGA releases:
```bash
buck2 run //tools/fpga_releaser:cli -- --fpga <fpga-name> --hubris <hubris-path>
```

## Important Files
- `BUILD.vars` - Machine-specific tool paths (copy from BUILD.vars.example)
- `BUCK_RULES.md` - Detailed BUCK rule documentation
- `RDL_EXAMPLES.md` - SystemRDL usage examples
- `vsg_config.json` - VHDL formatting rules
- `tools/requirements.txt` - Python dependencies

## Testing
- VUnit is used for VHDL testbenches
- BSV uses built-in Bluesim for simulation
- Testbenches follow naming convention: `*_tb.vhd` (testbench), `*_th.vhd` (test harness)