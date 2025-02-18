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
- You need a copy of buck2 built locally. The official 
[Instructions](https://buck2.build/docs/about/getting_started/) are here but note that the buck2 version
is intrinsically tied to the checkout of the submodules, and as such, our currently supported
buck2 version is installed like this:
`rustup install nightly-2024-10-13`
`cargo +nightly-2024-10-13 install --git https://github.com/facebook/buck2.git --tag "2025-02-01" buck2 `
See [this issue](https://github.com/facebook/buck2/issues/468) for more info
- You'll need python3/pip installed and accessible on your path. We have python 3.10
working in linux, and python 3.12 working in windows. Python 3.9 did not work in 
windows at least, we have no other data points on other python versions.
- If you're updating an already checked out repo to a new buck version, you'll need to update the submodules!!
- You'll need to install required python packages `pip install -r tools/requirements.txt`
- You'll need to have nvc (https://github.com/nickg/nvc). For linux, this can be obtained as a .deb
from the releases section, for windows there are also compiled binaries in the releases section. 
Current minimum supported version is 1.13.1

:warning: **Windows Users**: You need to be in Developer Mode for buck2 to be
able to use symlinks, and should consider setting `LongPathsEnabled` in regedit at
`HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\FileSystem` to 1 and rebooting.

- When building Xilinx design, Vivado will need to be installed and on your `$PATH`.
- Adjusting paths may require restarting of the buck2 background process so that it notices
the changes. This can be done with `buck2 clean`

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

### running all sims or sim regressions
We can use the build system to query for vunit simulation testbenches and have built a .bxl
that does this and gives you the command line options to run each one found:

`buck2 bxl //tools/vunit-sims.bxl:vunit_sim_gen`

If you'd like to run a regression run like the build machine does, you can pipe that into split
and use the shell to execute each line:

`buck2 bxl //tools/vunit-sims.bxl:vunit_sim_gen | while IFS= read -r line; do eval "$line" ; done`

## Release tooling
There's a rudimentary FPGA releaser tool that can be run as follows:
`buck2 run //tools/fpga_releaser:cli -- --fpga <fpga-name> --hubris <path to root of hubris checkout>`
This tool will fetch the latest main build of your chosen FPGA, download the build archive,
collect the relevant files, create a GitHub releaes, copy the hubris-impacting files into the 
appropriate location in hubris (for you to manually commit), write out the hubris README.md
for these files and print some timing and utilization statistics.
`--skip-gh` will skip doing the github release (mostly for testing)
`--token` you can pass your github token in, your env will be checked for `GITHUB_TOKEN` if this is
empty.

Config information is stored in `tools/fpga_releaser/config.toml` which controls the fpga name
to build image mapping, toolchain info, and hubris subdirectory information for each build.

Currently, only buck2-based build archives are able to be processed, cobble-based stuff is
not implemented.

## multitool
multitool is a collection of quality of live utilities built in-tree for regular use, but whose
function is small enough to not warrant a self-contained project.

### lsp file generation
There is basic support for generating vhdl_ls.toml files from the BUCK files.  This is tested and
is working with the https://github.com/VHDL-LS/rust_hdl_vscode vscode extension.

Using bxl, the following command queries the build graph for VHDL files, outputs a
json blob to stdout which is then converted into vhdl_ls.toml.  Ideally we'd have an
editor hook do this and have it be a little more standalone.
you can now do the following:
`buck2 run //tools/multitool:multitool -- lsp-toml`

The vunit sources are not currently enumerated in BUCK files as their installation
location can vary, but multitool -- lsp-toml now attempts to discover an add these
so a .vhdl_ls.toml in your home directory is no longer required or recommended.

### testbench boilerplate generation
This generates some basic testbench and test harness boiler plate with some basic 
assumptions built in, but once generated you can modify as needed for your project
`buck2 run //tools/multitool:multitool -- tb-gen --name <testbench_name> --path <path to sims folder>`

### VHDL "auto" formatter
We're using [vhdl-style-guide](https://vhdl-style-guide.readthedocs.io/) to provide
consistent formatting. Our custom ruleset is in the repo root (vsg_config.json) and we provide a wrapper to run this tool against all of our 1st-party VHDL code.
You can run `buck2 run //tools/multitool:multitool -- format` to auto-format our code 
and you can run `buck2 run //tools/multitool:multitool -- format --no-fix` to see a
report of the formatter without changing the code. This is especially useful when 
trying to identify a target rule for adjustment or disablement.

Right now, this has to be run manually by a user before code check-in, we'll look
into editor automation as we stabilize the rules and have time to do so.