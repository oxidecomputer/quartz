# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Quartz is a collection of soft-logic designs and hardware abstraction libraries (HALs) for various subsystems found in Oxide hardware. This includes components such as Ignition, power sequencing for system boards, and QSFP interface management.

## Build System

Quartz uses two build systems in parallel:

### Buck2 (Primary/Modern)
- Used for VHDL, BSV, and RDL flows
- Supports VUnit simulations for VHDL and Bluesim for BSV
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

### BSV with Buck2

BSV (Bluespec SystemVerilog) projects can now use Buck2 for builds:

```bash
# Build BSV library
buck2 build //hdl/ip/bsv:MyModule

# Run Bluesim test
buck2 run //hdl/ip/bsv:MyTests_mkTestName

# Generate Verilog for synthesis
buck2 build //hdl/ip/bsv:my_verilog

# Optional: Set custom Bluespec library directory
export BSV_LIB_DIR=/path/to/bluespec/lib
```

**Environment Variables:**
- `BSV_LIB_DIR` - Custom Bluespec library directory (defaults to `/usr/local/lib/bluespec`)

**Documentation:**
- [BSV_BUCK2_GUIDE.md](BSV_BUCK2_GUIDE.md) - Complete Buck2 BSV build system reference
- [docs/BSV_QUICK_START.md](docs/BSV_QUICK_START.md) - Tutorial for new BSV projects
- [docs/BSV_MIGRATION_EXAMPLES.md](docs/BSV_MIGRATION_EXAMPLES.md) - Migration from cobble BUILD to BUCK

**Key BSV Build Rules:**
- `bsv_library()` - Compile BSV sources to .bo object files
- `bsv_verilog()` - Generate synthesizable Verilog from BSV modules
- `bsv_bluesim_tests()` - Create Bluesim test executables
- `rdl_file()` - Generate BSV register packages from SystemRDL

### Cobble (Legacy)
- Legacy build system for BSV designs
- Still supported for backward compatibility
- Requires BUILD.vars configuration (copy BUILD.vars.example and adapt paths)
- See COBALT_README.md for detailed instructions
- **Recommended**: Migrate BSV projects to Buck2 for better performance

## Architecture

### Directory Structure
- `hdl/ip/` - Reusable IP blocks
  - `bsv/` - Bluespec SystemVerilog IP (BUCK-based, legacy BUILD files for cobble)
  - `vhd/` - VHDL IP modules (BUCK-based)
- `hdl/projects/` - Complete FPGA designs for specific hardware
  - Each project contains top-level designs, constraints, and project-specific modules
- `tools/` - Build system utilities and custom tools
- `prelude/` - Buck2 build rules and configurations
- `vnd/` - Vendor/third-party dependencies
- `docs/` - Additional documentation including BSV guides

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

**Note:** After making changes to VHDL code or SystemRDL files, run this command to:
- Refresh the language server configuration
- Regenerate RDL packages (creates updated `*_regs_pkg.vhd` files from `.rdl` sources)
- Update LSP understanding of dependencies and types

This resolves LSP errors about missing packages or unresolved references after adding new files or modifying RDL definitions.

### Release Tool
For FPGA releases:
```bash
buck2 run //tools/fpga_releaser:cli -- --fpga <fpga-name> --hubris <hubris-path>
```

## Important Files
- `BUILD.vars` - Machine-specific tool paths (copy from BUILD.vars.example)
- `BUCK_RULES.md` - Detailed BUCK rule documentation
- `BSV_BUCK2_GUIDE.md` - Complete BSV Buck2 build system reference
- `docs/BSV_QUICK_START.md` - BSV Buck2 tutorial
- `docs/BSV_MIGRATION_EXAMPLES.md` - BSV migration from cobble to Buck2
- `RDL_EXAMPLES.md` - SystemRDL usage examples
- `vsg_config.json` - VHDL formatting rules
- `tools/requirements.txt` - Python dependencies

## Testing

### VUnit Testing Framework

VUnit is used for VHDL testbenches with a standardized structure:
- `*_tb.vhd` - Testbench file containing test cases
- `*_th.vhd` - Test harness instantiating the DUT and verification components
- BSV uses built-in Bluesim for simulation

#### Testbench Structure

A typical VUnit testbench follows this pattern:

```vhdl
library vunit_lib;
    context vunit_lib.com_context;
    context vunit_lib.vunit_context;
    context vunit_lib.vc_context;

entity my_tb is
    generic (
        runner_cfg : string
    );
end entity;

architecture tb of my_tb is
begin
    th: entity work.my_th;

    bench: process
        alias reset is << signal th.reset : std_logic >>;
        -- Declare variables and constants here
        variable read_data : std_logic_vector(31 downto 0);
    begin
        test_runner_setup(runner, runner_cfg);
        wait until reset = '0';
        wait for 500 ns;  -- Let resets propagate

        while test_suite loop
            if run("test_case_1") then
                -- Test case 1 implementation
            elsif run("test_case_2") then
                -- Test case 2 implementation
            end if;
        end loop;

        wait for 2 us;
        test_runner_cleanup(runner);
        wait;
    end process;

    test_runner_watchdog(runner, 10 ms);
end tb;
```

#### Running Specific Test Cases

```bash
# Run all tests in a testbench
buck2 run //path/to:testbench_name

# Run a specific test case
buck2 run //path/to:testbench_name -- --test-case="test_case_name"
```

### VUnit Message Passing

VUnit provides a message passing system for communication between testbenches and verification components (VCs). This is useful for controlling simulation models and injecting faults.

#### Creating a Message Package

Message packages define message types and helper procedures:

```vhdl
library vunit_lib;
    context vunit_lib.vunit_context;
    context vunit_lib.com_context;

package my_model_msg_pkg is
    -- Define message types
    constant enable_msg  : msg_type_t := new_msg_type("enable");
    constant disable_msg : msg_type_t := new_msg_type("disable");

    -- Helper procedures for testbenches
    procedure enable_feature (
        signal net     : inout network_t;
        constant actor : actor_t
    );

    procedure disable_feature (
        signal net     : inout network_t;
        constant actor : actor_t
    );
end package;

package body my_model_msg_pkg is
    procedure enable_feature (
        signal net     : inout network_t;
        constant actor : actor_t
    ) is
        variable request_msg : msg_t := new_msg(enable_msg);
    begin
        send(net, actor, request_msg);
    end;

    procedure disable_feature (
        signal net     : inout network_t;
        constant actor : actor_t
    ) is
        variable request_msg : msg_t := new_msg(disable_msg);
    begin
        send(net, actor, request_msg);
    end;
end package body;
```

#### Implementing Message Handler in Models

Models receive and process messages in a dedicated process:

```vhdl
library vunit_lib;
    context vunit_lib.vunit_context;
    context vunit_lib.com_context;

use work.my_model_msg_pkg.all;

entity my_model is
    generic (
        actor_name : string := "my_model"
    );
    port (
        clk   : in std_logic;
        -- other ports
    );
end entity;

architecture model of my_model is
    signal feature_enabled : boolean := true;
begin
    -- Message handler process
    msg_handler : process
        variable self        : actor_t;
        variable msg_type    : msg_type_t;
        variable request_msg : msg_t;
    begin
        self := new_actor(actor_name);
        loop
            receive(net, self, request_msg);
            msg_type := message_type(request_msg);
            if msg_type = enable_msg then
                info("Feature enabled");
                feature_enabled <= true;
            elsif msg_type = disable_msg then
                info("Feature disabled");
                feature_enabled <= false;
            else
                unexpected_msg_type(msg_type);
            end if;
        end loop;
        wait;
    end process;

    -- Model behavior uses feature_enabled signal
end model;
```

#### Using Messages in Testbenches

```vhdl
-- In test harness, instantiate model with unique actor name
my_model_inst: entity work.my_model
    generic map(
        actor_name => "my_model_inst"
    )
    port map(
        clk => clk,
        -- other ports
    );

-- In testbench, find actor and send messages
bench: process
    constant model_actor : actor_t := find("my_model_inst");
begin
    test_runner_setup(runner, runner_cfg);
    -- ...

    while test_suite loop
        if run("fault_injection_test") then
            -- Disable feature to inject fault
            disable_feature(net, model_actor);
            wait for 100 us;

            -- Re-enable feature
            enable_feature(net, model_actor);
        end if;
    end loop;

    test_runner_cleanup(runner);
    wait;
end process;
```

### SystemRDL Register Access in Testbenches

SystemRDL files generate VHDL packages with register offsets, field masks, and type definitions. Use these in testbenches for register access.

#### Reading RDL-Generated Constants

RDL files generate packages like `<module>_regs_pkg.vhd` with:
- Register offsets: `<REG_NAME>_OFFSET`
- Field masks: `<REG_NAME>_<FIELD_NAME>_MASK`
- Enumeration types for state machines and fields
- Record types for structured register access

Example usage:

```vhdl
use work.sequencer_regs_pkg.all;

bench: process
    variable read_data : std_logic_vector(31 downto 0);
begin
    -- Write to a register
    write_bus(net, bus_handle,
              To_StdLogicVector(POWER_CTRL_OFFSET, bus_handle.p_address_length),
              POWER_CTRL_A0_EN_MASK);

    -- Read from a register
    read_bus(net, bus_handle,
             To_StdLogicVector(IFR_OFFSET, bus_handle.p_address_length),
             read_data);

    -- Check specific bits using masks
    check_equal((read_data and IFR_A0MAPO_MASK) /= x"00000000",
                true,
                "Expected A0MAPO bit to be set");

    -- Check state machine values (encoded as hex)
    -- State values are documented in the RDL file
    check_equal(unsigned(read_data(7 downto 0)),
                to_unsigned(16#09#, 8),
                "Expected DONE state (0x09)");
end process;
```

#### Common Patterns

**Testing State Machines:**
```vhdl
-- Read state register
read_bus(net, bus_handle,
         To_StdLogicVector(SEQ_API_STATUS_OFFSET, bus_handle.p_address_length),
         read_data);

-- Check for IDLE state (0x00)
check_equal(unsigned(read_data(7 downto 0)), to_unsigned(16#00#, 8),
            "Expected IDLE state");
```

**Testing Interrupt Flags:**
```vhdl
-- Read interrupt flag register
read_bus(net, bus_handle,
         To_StdLogicVector(IFR_OFFSET, bus_handle.p_address_length),
         read_data);

-- Check if specific interrupt flag is set
check_equal((read_data and IFR_A0MAPO_MASK) /= x"00000000",
            true,
            "Expected MAPO interrupt flag");
```

**Fault Injection Pattern:**
```vhdl
elsif run("fault_injection_test") then
    -- 1. Run normal sequence
    write_bus(net, bus_handle,
              To_StdLogicVector(POWER_CTRL_OFFSET, bus_handle.p_address_length),
              POWER_CTRL_A0_EN_MASK);
    wait for 1 ms;

    -- 2. Verify normal state
    read_bus(net, bus_handle,
             To_StdLogicVector(STATUS_OFFSET, bus_handle.p_address_length),
             read_data);
    check_equal(unsigned(read_data(7 downto 0)), to_unsigned(16#09#, 8),
                "Expected DONE state");

    -- 3. Inject fault using message passing
    disable_power_good(net, rail_actor);
    wait for 100 us;

    -- 4. Verify fault detection
    read_bus(net, bus_handle,
             To_StdLogicVector(IFR_OFFSET, bus_handle.p_address_length),
             read_data);
    check_equal((read_data and IFR_FAULT_MASK) /= x"00000000",
                true,
                "Expected fault flag");

    -- 5. Verify fault handling (e.g., return to IDLE)
    read_bus(net, bus_handle,
             To_StdLogicVector(STATUS_OFFSET, bus_handle.p_address_length),
             read_data);
    check_equal(unsigned(read_data(7 downto 0)), to_unsigned(16#00#, 8),
                "Expected IDLE state after fault");

    -- 6. Clean up
    enable_power_good(net, rail_actor);
end if;
```

### VUnit Verification Components (VCs)

Existing VUnit VCs are located in `hdl/ip/vhd/vunit_components/`:
- `sim_gpio` - GPIO stimulus and monitoring
- `i2c_controller_vc` - I2C master verification component
- `i2c_target_vc` - I2C slave verification component
- `spi_controller` - SPI master/slave verification components
- `qspi_controller_vc` - QSPI verification component
- `basic_stream` - Simple streaming interface

When creating new VCs or simulation models:
1. Create a message package (`*_msg_pkg.vhd`) for the interface
2. Implement the model with message handler process
3. Add `actor_name` generic for identification
4. Provide helper procedures for common operations
5. Document message types and usage patterns