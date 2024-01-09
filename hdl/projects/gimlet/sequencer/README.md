This is the gimlet sequencer design.


It has dependencies on oxidecomputer/cobalt (as a submodule) which further depends on oxidecomputer/cobble-build as a sub-sub-module.

In order to build FPGA images you'll need the bluespec toolchain installed, the yosys toolchain installed and some PyPI packages installed.  You can see the Dockerfile in the oxidecomputer/cobalt repository for an example of the steps required to install the toolchain and supporting files.

If you've installed things locally you'll need to create a BUILD.vars file (in your quartz/ checkout directory) that looks something like this (with your toolchain paths substituted as appropriate):
```
[bluespec]
prefix = "/tools/bluespec"
bin = "/tools/bluespec/bin/bsc"
libdir = "/tools/bluespec/lib"

[yosys]
bin = "/tools/fpga-toolchain/bin/yosys"
libdir = "/tools/fpga-toolchain/share/yosys"

[nextpnr]
ecp5 = "/tools/fpga-toolchain/bin/nextpnr-ecp5"
ecp5_pack = "/tools/fpga-toolchain/bin/ecppack"
ice40 = "/tools/fpga-toolchain/bin/nextpnr-ice40"
ice40_pack = "/tools/fpga-toolchain/bin/icepack"
```

(If you build with the docker image this should be done for you.)

Checking out
============
```
git clone --recursive https://github.com/oxidecomputer/quartz.git
```

Building
========
- Make a build output folder at `quartz/build` to contain build artifacts
- Initialize the cobble project in the build directory: `../vnd/cobalt/vnd/cobble/cobble init .. --reinit`
- Build the bitstream target: `./cobble build latest/hdl/boards/gimlet/sequencer/gimlet_sequencer.bit -v` which will output a filed named the same at build/latest/hdl/board/gimlet/sequencer/ folder. Other build artifacts such as the register map and register json will be there as well.

Testing
======
From the build directory run to run all tests with "Test" in the name in quartz and cobalt, or be more selective with the filter as appropriate:
`./cobble bluesim_test --vcd-always -v ".*Test.*"`
