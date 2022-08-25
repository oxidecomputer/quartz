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
pfexec apt -y install docker.io
pfexec chown "$LOGNAME" "/var/run/docker.sock"

banner cobalt
pushd vnd/cobalt
#
# Build the cobalt docker image.  This takes a while, and produces a vast
# quantity of console output that we do not generally want to look at, so we
# build with the quiet flag.  This image could probably be built and published
# in the cobalt repository itself, and just _consumed_ here.
#
ptime -m docker build -q -t cobalt .
popd

banner hey presto
ptime -m docker run -i cobalt \
    find /opt/bluespec/bin /opt/fpga-toolchain/bin -type f -ls
