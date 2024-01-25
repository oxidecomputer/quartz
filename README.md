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
- You'll need python3/pip installed and accessible on your path.
- You'll need to install required python packages `pip install -r tools/requirements.txt`

### buck2 run
Comprehensive buck2 command line guidance is out of the scope of this document
but if you want to see a list of all available buck2 targets you can do: `buck2 ctargets /...`

To run a simulation, pick one of the testbench targets and `buck2 run <target>` you may do
`-- <vunit args>` if you need to pass arguments into VUnit.