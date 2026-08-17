#!/usr/bin/env python3
"""Pick the git revision BTD should diff the current commit against.

On a branch the answer is just origin/main. On main it needs to be the last
commit we actually finished building, which is *not* the previous commit:

  - A push can carry several commits. Diffing against HEAD~1 only sees what the
    tip commit touched, so anything changed by an earlier commit in the same
    push is never built. That is how cosmo_seq's hash engine landed without a
    bitstream.
  - `concurrency.cancel-in-progress` kills a run when the next push arrives.
    Whatever that run was partway through is simply lost, and a per-push diff
    has no way to notice.

Anchoring to the head_sha of the last successful run of this workflow makes both
cases self-healing: a skipped-over or cancelled commit widens the next run's
diff instead of dropping out of it. A failed run is not a valid anchor either --
its failed targets still need building -- so only successful runs count.

Writes `base_commit=<rev>` to $GITHUB_OUTPUT. An empty value means no usable
base was found and the caller must build everything.
"""

import argparse
import json
import os
import subprocess
import sys
import urllib.error
import urllib.request

NULL_SHA = "0" * 40


def git(*args):
    return subprocess.run(
        ["git", *args], capture_output=True, text=True, check=False
    )


def usable(rev, head):
    """A base has to exist locally and be an ancestor of HEAD.

    Force-pushes can name a commit that is gone or that lives on an abandoned
    line of history; diffing against either produces a changes list full of
    spurious reverts.
    """
    if not rev or rev == NULL_SHA:
        return False
    if git("cat-file", "-e", f"{rev}^{{commit}}").returncode != 0:
        print(f"  {rev[:12]}: not present in this clone")
        return False
    if git("merge-base", "--is-ancestor", rev, head).returncode != 0:
        print(f"  {rev[:12]}: not an ancestor of {head}")
        return False
    return True


def last_successful_run_shas(repo, workflow, branch, token, limit=20):
    """head_shas of recent successful runs of this workflow, newest first."""
    url = (
        f"https://api.github.com/repos/{repo}/actions/workflows/{workflow}/runs"
        f"?branch={branch}&status=success&per_page={limit}"
    )
    req = urllib.request.Request(url, headers={"Accept": "application/vnd.github+json"})
    if token:
        req.add_header("Authorization", f"Bearer {token}")
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            data = json.load(resp)
    except (urllib.error.URLError, json.JSONDecodeError, TimeoutError) as e:
        # Not fatal: we still have github.event.before to fall back to.
        print(f"::warning::Could not query workflow runs ({e}); falling back")
        return []
    return [r["head_sha"] for r in data.get("workflow_runs", [])]


def resolve(args):
    if args.ref != f"refs/heads/{args.branch}":
        # On a branch we want every target the branch touches, not just what
        # the last push touched, so origin/main is the right base.
        return "origin/main"

    print(f"Looking for the last successful {args.workflow} run on {args.branch}")
    for sha in last_successful_run_shas(
        args.repo, args.workflow, args.branch, args.token
    ):
        if sha == args.head:
            # A re-run of the current commit. Nothing new to build.
            print(f"  {sha[:12]}: is HEAD, using it")
            return sha
        if usable(sha, args.head):
            print(f"Using last successful build at {sha[:12]}")
            return sha

    print("::warning::No usable successful run found; falling back to event.before")
    if usable(args.event_before, args.head):
        print(f"Using push base {args.event_before[:12]}")
        return args.event_before

    print("::warning::No usable base commit; all targets will be built")
    return ""


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--ref", required=True, help="github.ref")
    parser.add_argument("--event-before", default="", help="github.event.before")
    parser.add_argument("--workflow", required=True, help="workflow filename")
    parser.add_argument("--repo", required=True, help="owner/name")
    parser.add_argument("--branch", default="main")
    parser.add_argument("--head", default="HEAD")
    args = parser.parse_args()
    args.token = os.environ.get("GITHUB_TOKEN", "")

    # Resolve HEAD once so ancestry checks and the re-run comparison both work
    # against a full sha.
    rev_parse = git("rev-parse", args.head)
    if rev_parse.returncode != 0:
        print(f"::error::Cannot resolve {args.head}: {rev_parse.stderr.strip()}")
        return 1
    args.head = rev_parse.stdout.strip()

    base = resolve(args)
    print(f"base_commit={base}")

    out = os.environ.get("GITHUB_OUTPUT")
    if out:
        with open(out, "a") as f:
            f.write(f"base_commit={base}\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
