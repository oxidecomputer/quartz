This mux design emulates most of the functionality of a PCA9545ABS
with the following changes/enhancements:

hw-enforced single channel selection.  Commands that would result on multiple legs
of the mux to be enabled in an real PCA9545ABS will result in NACKs and no change
in current state.

Given that i2c muxing in an FPGA is a bad idea, this design relies on external
analog muxes like TMUX131