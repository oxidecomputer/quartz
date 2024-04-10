# Quartz

Quartz is a collection of soft-logic designs and hardware abstraction libraries
(HALs) for various subsystems found in Oxide hardware. This includes components
such as Ignition, power sequencing for system boards and QSFP interface
management.

# Cloning instructions
Note that cobble is a submodule of cobalt which is used as a submodule here.
```sh
git clone --recursive
```
or if already checked out:

```sh
 git submodule update --init --recursive
 or
 git pull recurse-submodules
```

# Build system help
In the long-term, we're migrating to buck2 as out build system but until we have
reached parity, we are supporting designs that started using cobble still with
cobble and new design flows using buck2.

## Cobble-based builds
Currently the cobble build chain supports BSV designs and RDL generate
targetting the yosys toolchain.

If you're looking for getting started with a cobble-based build see
[instructions](COBALT_README.md) as well as some further tips
[here](hdl/projects/gimlet/sequencer/README.md) At the root of the Quartz
directory, the BUILD.vars file controls machine-specific paths. It is
recommended that you copy the BUILD.vars.example and adapt for your system
paths. Typically this involves adjusting the [bluespec] [yosys] [nextpnr]
sections to point to the tooling in your environment.

### Adding new source files
In each folder that is scanned, there is a BUILD file that includes the
information for cobble to determine build targets and a complete dependency
tree. In general, bluespec files get added as individual bluespec libraries,
bluespec simulation targets get added as a bluespec_sim target, and
bluesim_binary target.

For top-level designs that would synthesize to an FPGA, a bluespec_verilog
target, a yosys_design target and a nextpnr target are needed to properly
generate bitstreams.

### Adding new hardware targets
To add support for a totally new chip design, a new "environment" in cobble
parlance has to be created. This is done up at the root of the quartz repo in
the BUILD.conf file.

## buck2 builds
This area is under active development, currently supporting VHDL and RDL flows
into VUnit simulations.  FPGA toolchain support, and BSV support needs to be
fleshed out.

The docker image does not currently contain buck2 executables.

For information on building `BUCK` files see [here](BUCK_RULES.md)

### Prerequisites
- You need a copy of buck2 built locally. [Instructions](https://buck2.build/docs/getting_started/)
- You'll need python3/pip installed and accessible on your path. We have python 3.10
working in linux, and python 3.12 working in windows. Python 3.9 did not work in 
windows at least, we have no other data points on other python versions.
- You'll need to install required python packages `pip install -r tools/requirements.txt`
- You'll need to have nvc (https://github.com/nickg/nvc). For linux, this can be obtained as a .deb
from the releases section, for windows there are also compiled binaries in the releases section.

:warning: **Windows Users**: You need to be in Developer Mode for buck2 to be
able to use symlinks, and should consider setting `LongPathsEnabled` in regedit at
`HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\FileSystem` to 1 and rebooting.

### vivado macros
There are simulation-only XPM macros available in the `vnd/xpm/xpm_vhdl` submodule, provided
by the https://github.com/fransschreuder/xpm_vhdl project.
There is a BUCK file at vnd/xpm so you can add `//vnd/xpm:xpm` as a dependency to any
module that needs to use the XPM library.

### buck2 run
Comprehensive buck2 command line guidance is out of the scope of this document
but if you want to see a list of all available buck2 targets you can do: `buck2 ctargets /...`

To run a simulation, pick one of the testbench targets and `buck2 run <target>` you may do
`-- <vunit args>` if you need to pass arguments into VUnit.

## VHDL editor environment
There is basic support for generating vhdl_ls.toml files from the BUCK files.  This is tested and
is working with the https://github.com/VHDL-LS/rust_hdl_vscode vscode extension.

Right now, the management of this file relies on a user re-generating it as new files are
added to the BUCK files.  To generate the file in the workspace root (note that this relies
on https://crates.io/crates/convfmt tool to convert the stdout json to a toml file. 
`cargo install convfmt` to install).

Using bxl, the following command queries the build graph for VHDL files, outputs a
json blob to stdout which is then converted into vhdl_ls.toml.  Ideally we'd have an
editor hook do this and have it be a little more standalone.

`buck2 bxl //tools/vhdl-ls.bxl:vhdl_ls_toml_gen | convfmt -f json -t toml > vhdl_ls.toml`

Note that the vunit sources are not currently enumerated in BUCK files as their installation
location can vary.  I have solved this by creating a .vhdl_ls.toml in my *home* directory that
specifies vunit_lib as such, but your paths may differ.  The vscode extension will read both the 
home directory file and the workspace root file and merge them.

```
[libraries]
vunit_lib.files = [
  '.local/lib/python3.10/site-packages/vunit/vhdl/vunit_context.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/vunit_run_context.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/path/src/path.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/path/test/tb_path.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/verification_components/src/wishbone_slave.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/verification_components/src/signal_checker_pkg.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/verification_components/src/axi_read_slave.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/verification_components/src/avalon_sink.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/verification_components/src/axi_lite_master_pkg.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/verification_components/src/avalon_slave.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/verification_components/src/ram_master.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/verification_components/src/avalon_stream_pkg.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/verification_components/src/std_logic_checker.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/verification_components/src/axi_stream_protocol_checker.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/verification_components/src/axi_statistics_pkg.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/verification_components/src/sync_pkg.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/verification_components/src/uart_master.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/verification_components/src/bus_master_pkg.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/verification_components/src/stream_slave_pkg-body.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/verification_components/src/axi_stream_slave.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/verification_components/src/axi_slave_private_pkg.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/verification_components/src/axi_slave_pkg.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/verification_components/src/axi_stream_private_pkg.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/verification_components/src/stream_slave_pkg.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/verification_components/src/avalon_master.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/verification_components/src/memory_utils_pkg.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/verification_components/src/avalon_source.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/verification_components/src/vc_context.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/verification_components/src/avalon_pkg.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/verification_components/src/axi_pkg.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/verification_components/src/wishbone_master.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/verification_components/src/wishbone_pkg.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/verification_components/src/axi_stream_pkg.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/verification_components/src/memory_pkg-body.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/verification_components/src/bus_master_pkg-body.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/verification_components/src/sync_pkg-body.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/verification_components/src/axi_stream_master.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/verification_components/src/axi_write_slave.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/verification_components/src/uart_pkg.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/verification_components/src/axi_lite_master.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/verification_components/src/memory_pkg.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/verification_components/src/stream_master_pkg.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/verification_components/src/uart_slave.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/verification_components/src/axi_stream_monitor.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/verification_components/src/stream_master_pkg-body.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/verification_components/src/bus2memory.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/verification_components/test/tb_memory.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/verification_components/test/tb_memory_utils_pkg.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/verification_components/test/tb_avalon_slave.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/verification_components/test/tb_avalon_stream.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/verification_components/test/tb_avalon_stream_pkg.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/verification_components/test/tb_wishbone_slave.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/verification_components/test/tb_avalon_master.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/verification_components/test/tb_axi_stream.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/verification_components/test/tb_axi_write_slave.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/verification_components/test/tb_ram_master.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/verification_components/test/tb_avalon.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/verification_components/test/tb_axi_slave_private_pkg.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/verification_components/test/tb_axi_lite_master.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/verification_components/test/tb_uart.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/verification_components/test/tb_axi_read_slave.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/verification_components/test/tb_axi_statistics_pkg.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/verification_components/test/tb_sync_pkg.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/verification_components/test/tb_bus_master_pkg.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/verification_components/test/tb_std_logic_checker.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/verification_components/test/tb_axi_stream_protocol_checker.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/verification_components/test/tb_wishbone_master.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/core/src/stop_body_93-2002.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/core/src/stop_body_2008p.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/core/src/core_pkg.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/core/src/stop_pkg.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/com/src/com_support.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/com/src/com_common.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/com/src/com_deprecated.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/com/src/com_string.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/com/src/com_messenger.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/com/src/com_context.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/com/src/com_types.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/com/src/com.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/com/src/com_debug_codec_builder.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/com/src/com_api.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/com/test/tb_com_codec.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/com/test/tb_com.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/com/test/tb_com_msg_building.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/com/test/more_constants.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/com/test/custom_types.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/com/test/constants.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/run/src/run_deprecated_pkg.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/run/src/run_types.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/run/src/run_api.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/run/src/run.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/run/src/runner_pkg.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/run/test/tb_watchdog.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/run/test/tb_run.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/run/test/run_tests.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/check/src/check_api.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/check/src/check_deprecated_pkg.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/check/src/checker_pkg.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/check/src/check.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/check/src/checker_pkg-body.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/check/test/tb_check_equal_real.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/check/test/test_support.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/check/test/tb_checker.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/check/test/tb_check_failed.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/check/test/tb_check_stable.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/check/test/tb_check_passed.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/check/test/tb_check_implication.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/check/test/tb_check_sequence.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/check/test/tb_check_zero_one_hot.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/check/test/tb_result.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/check/test/tb_check_next.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/check/test/tb_check.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/check/test/tb_check_one_hot.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/check/test/tb_check_false.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/check/test/tb_check_relation_2008p.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/check/test/tb_check_not_unknown.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/check/test/tb_check_relation.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/osvvm/OsvvmContext.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/osvvm/ReportPkg.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/osvvm/MessagePkg.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/osvvm/NameStorePkg.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/osvvm/RandomProcedurePkg.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/osvvm/TranscriptPkg.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/osvvm/VendorCovApiPkg.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/osvvm/ScoreboardPkg_int.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/osvvm/ResolutionPkg.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/osvvm/MemoryPkg.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/osvvm/ScoreboardPkg_slv.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/osvvm/OsvvmGlobalPkg.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/osvvm/TbUtilPkg.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/osvvm/TextUtilPkg.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/osvvm/ScoreboardPkg_slv_c.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/osvvm/ScoreboardGenericPkg.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/osvvm/RandomPkg.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/osvvm/ResizePkg.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/osvvm/AlertLogPkg.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/osvvm/VendorCovApiPkg_Aldec.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/osvvm/SortListPkg_int.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/osvvm/ScoreboardPkg_int_c.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/osvvm/RandomBasePkg.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/osvvm/MessageListPkg.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/osvvm/CoveragePkg.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/osvvm/NamePkg.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/osvvm/demo/Demo_Rand.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/osvvm/demo/AlertLog_Demo_Global.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/osvvm/demo/AlertLog_Demo_Hierarchy.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/string_ops/src/string_ops.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/string_ops/test/tb_string_ops.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/random/src/random_pkg.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/random/test/tb_random_pkg.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/logging/src/location_pkg-body-2019p.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/logging/src/print_pkg-body.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/logging/src/print_pkg.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/logging/src/log_handler_pkg.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/logging/src/log_levels_pkg.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/logging/src/log_handler_pkg-body.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/logging/src/log_deprecated_pkg.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/logging/src/logger_pkg.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/logging/src/file_pkg.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/logging/src/ansi_pkg.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/logging/src/logger_pkg-body.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/logging/src/log_levels_pkg-body.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/logging/src/location_pkg.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/logging/test/tb_log.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/logging/test/tb_deprecated.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/logging/test/test_support_pkg.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/logging/test/tb_location.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/logging/test/tb_log_levels.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/data_types/src/data_types_private_pkg.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/data_types/src/integer_array_pkg.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/data_types/src/dict_pkg.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/data_types/src/codec_builder.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/data_types/src/queue_pkg.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/data_types/src/integer_vector_ptr_pool_pkg.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/data_types/src/byte_vector_ptr_pkg.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/data_types/src/codec.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/data_types/src/dict_pkg-2008p.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/data_types/src/integer_vector_ptr_pkg.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/data_types/src/types.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/data_types/src/string_ptr_pkg.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/data_types/src/codec-2008p.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/data_types/src/id_pkg.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/data_types/src/data_types_context.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/data_types/src/queue_pool_pkg.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/data_types/src/queue_pkg-2008p.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/data_types/src/event_pkg.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/data_types/src/integer_array_pkg-body.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/data_types/src/string_ptr_pool_pkg.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/data_types/src/codec_builder-2008p.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/data_types/src/queue_pkg-body.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/data_types/src/event_common_pkg.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/data_types/src/event_private_pkg.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/data_types/src/dict_pkg-body.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/data_types/src/api/external_integer_vector_pkg.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/data_types/src/api/external_string_pkg.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/data_types/test/tb_event_pkg.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/data_types/test/tb_string_ptr_pool.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/data_types/test/tb_codec.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/data_types/test/tb_byte_vector_ptr.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/data_types/test/tb_id.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/data_types/test/tb_event_private_pkg.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/data_types/test/tb_queue_pool.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/data_types/test/tb_integer_vector_ptr_pool.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/data_types/test/tb_queue.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/data_types/test/tb_codec-2008p.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/data_types/test/tb_integer_vector_ptr.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/data_types/test/tb_string_ptr.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/data_types/test/tb_integer_array.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/data_types/test/tb_dict-2008p.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/data_types/test/tb_queue-2008p.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/data_types/test/tb_dict.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/dictionary/src/dictionary.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/dictionary/test/tb_dictionary.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/array/src/array_pkg.vhd',
  '.local/lib/python3.10/site-packages/vunit/vhdl/array/test/tb_array.vhd',
]
```
