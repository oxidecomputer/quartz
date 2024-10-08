#!/bin/bash
#:
#: name = "build-and-test"
#: variety = "basic"
#: target = "ubuntu-20.04"
#:
#: output_rules = [
#:     "/work/oxidecomputer/quartz/build/latest/**/*",
#: ]

set -o errexit
set -o pipefail
set -o xtrace

#
# The token authentication mechanism that affords us access to other private
# repositories requires that we use HTTPS URLs for GitHub, rather than SSH.
#
override_urls=(
    'git://github.com/'
    'git@github.com:'
    'ssh://github.com/'
    'ssh://git@github.com/'
)
for (( i = 0; i < ${#override_urls[@]}; i++ )); do
	git config --add --global url.https://github.com/.insteadOf \
	    "${override_urls[$i]}"
done

#
# Require that cargo use the git CLI instead of the built-in support.  This
# achieves two things: first, SSH URLs should be transformed on fetch without
# requiring Cargo.toml rewriting, which is especially difficult in transitive
# dependencies; second, Cargo does not seem willing on its own to look in
# ~/.netrc and find the temporary token that buildomat generates for our job,
# so we must use git which uses curl.
#
export CARGO_NET_GIT_FETCH_WITH_CLI=true

git submodule sync
git submodule update --init --recursive

pfexec apt -y update
pfexec apt -y install make

#
# Install yosys from pre-built toolchain as specified
#
banner Yosys Install
YOSYS_TOOLCHAIN="https://github.com/YosysHQ/oss-cad-suite-build/releases/download/2024-05-13/oss-cad-suite-linux-x64-20240513.tgz"
wget -q $YOSYS_TOOLCHAIN
tar zxf oss-cad-suite-linux-x64*

#
# Install pre-built bsv toolchain as specified and add bsc/bin folder to path
#
banner Bluespec Install
BSV_TOOLCHAIN="https://github.com/B-Lang-org/bsc/releases/download/2022.01/bsc-2022.01-ubuntu-20.04.tar.gz"
wget -q $BSV_TOOLCHAIN
tar zxf bsc-2022.01-ubuntu*

#
# Now do bsc contrib (not part of the binary release)
# This works but takes a non-zero amount of time, so it is commented out because we don't currently depend on it
#
# git clone --recursive https://github.com/B-Lang-org/bsc-contrib.git
# pushd bsc-contrib
# make PREFIX=/work/oxidecomputer/quartz/bsc-2022.01-ubuntu-20.04 BSC=/work/oxidecomputer/quartz/bsc-2022.01-ubuntu-20.04/bin/bsc
# popd

#
# Do cobalt setup (python packages required)
#
banner cobalt Setup
pushd tools
#
# Install cobalt-related python stuff, ninja + other 3rd party things
#
pfexec apt -y install python3-pip ninja-build
pip3 install -r requirements.txt
popd

#
# Prep for build by setting up the BUILD.vars that cobble needs
# then making a build directory and initializing cobble
#
cp BUILD.vars.buildomat BUILD.vars

mkdir build
pushd build

#
# Initialize cobalt
#
../vnd/cobble/cobble init .. --reinit

#
# Do the build
#
banner FPGA Builds

# Get all bit files and build them
./cobble build -v "//.*#bitstream"
