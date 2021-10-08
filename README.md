# Quartz

Quartz is a collection of soft-logic designs and hardware abstraction libraries (HALs) for various
subsystems found in Oxide hardware. This includes components such as Ignition, power sequencing for
system boards and QSFP interface management.

Quartz leans heavily on [Cobalt](https://github.com/oxidecomputer/cobalt) and unless a component is
experimental or specific to an Oxide system, our posture should be to push as much into that project
as possible. Having said that, it is acceptable to prototype in private under the Quartz project and
move something to Cobalt once deemed ready.

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
At the root of the Quartz directory, the BUILD.vars file controls machine-specific paths.
It is recommended that you copy the BUILD.vars.example and adapt for your system paths.
Typically this involves adjusting the [bluespec] [yosys] [nextpnr] sections to point to the tooling in your environment.

## Adding new source files
In each folder that is scanned, there is a BUILD file that includes the information for cobble to determine build targets
and a complete dependency tree. In general, bluespec files get added as individual bluespec libraries, bluespec simulation targets get added
as a bluespec_sim target, and bluesim_binary target.

For top-level designs that would synthesize to an FPGA, a bluespec_verilog target, a yosys_design target and a nextpnr target are needed to
properly generate bitstreams.

## Adding new hardware targets
To add support for a totally new chip design, a new "environment" in cobble parlance has to be created. This is done up at the root of the 
quartz repo in the BUILD.conf file.