#!/usr/bin/env bash
set -o errexit -o nounset -o xtrace -o pipefail
shopt -s inherit_errexit nullglob dotglob

# Remove everything except buck-out/ and .git/ to preserve Buck2 cache
# and git repo between CI runs on self-hosted runners.
# Note: dotglob is enabled above, so hidden files like .git are matched
# by globs. We must explicitly exclude .git here or actions/checkout will
# see a non-repo directory and do a full re-clone (wiping buck-out too).
shopt -s extglob
rm -rf "${GITHUB_WORKSPACE:?}"/!(buck-out|vunit_out|.git)

if test "${RUNNER_DEBUG:-0}" != '1'; then
  set +o xtrace
fi