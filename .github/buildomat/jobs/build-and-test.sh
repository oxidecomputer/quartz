#!/bin/bash
#:
#: name = "build-and-test"
#: variety = "basic"
#: target = "ubuntu-20.04"
#:

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

#
# Install yosys from pre-built toolchain as specified
#
banner Yosys Install
YOSYS_TOOLCHAIN="https://github.com/YosysHQ/oss-cad-suite-build/releases/download/2022-08-25/oss-cad-suite-linux-x64-20220825.tgz"
wget -q $YOSYS_TOOLCHAIN
tar xf oss-cad-suite-linux-x64*

#
# Install pre-built bsv toolchain as specified
#
banner Bluespec Install
BSV_TOOLCHAIN="https://github.com/B-Lang-org/bsc/releases/download/2022.01/bsc-2022.01-ubuntu-20.04.tar.gz"
wget -q $BSV_TOOLCHAIN
tar xf bsc-2022.01-ubuntu*

#
# Do cobalt setup (python packages required)
# 
banner cobalt Setup
pushd vnd/cobalt
#
# Install cobalt-related python stuff, ninja + other 3rd party things
#
pfexec apt -y install python3-pip
pip3 install ninja
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
../vnd/cobalt/vnd/cobble/cobble init .. --reinit

#
# Do the build
#
banner FPGA build
ptime -m ./cobble build -v latest/hdl/boards/gimlet/sequencer/gimlet_sequencer.bit
