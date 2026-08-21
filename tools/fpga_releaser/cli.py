import sys
import os
import io
import argparse
import zipfile

from pathlib import Path
import arrow
import requests
from ghapi.all import GhApi
from fastcore.xtras import obj2dict

import fpga_releaser.project as project
import fpga_releaser.gh_releaser as gh_releaser



parser = argparse.ArgumentParser()
parser.add_argument("--token", default=None, help="Pass in your GitHub personal access token (will also use from GH_ACCESS_TOKEN env variable")
parser.add_argument("--branch", default="main", help="Quartz branch to use for the artifact")
parser.add_argument("--fpga", help="Name of FPGA project to release")
parser.add_argument("--hubris", default=None, help="Path to hubris git checkout as target for copying files. Will skip if None")
parser.add_argument("--local", default=False, action="store_true", help="Utilize local build directory, not GH.")
parser.add_argument("--skip-gh", default=False, action="store_true", help="Skip doing GH release. Note that doing this still generates release metadata that just will be wrong")
parser.add_argument("--zip", default=None, help="Path to zip file to use instead of downloading from GitHub")

# Register map docs go to the GH release but not into hubris, which has no
# consumer for them.
hubris_ignore = [".html", ".adoc", ".log", ".rpt"]

def main():
    """
    Main function to process the command line arguments and run the release process.
    """
    args = parser.parse_args()
    if args.fpga is None:
        print("Please specify an FPGA project with --fpga")
        sys.exit(1)

    project_info = project.get_config(args.fpga)
    print(f"Processing {args.fpga} with builder {project_info.builder}")

    # Get build archive
    if args.local:
        print("Using local build directory")
        # make a zip file from the local build directory
        zip_file = make_buck2_zip()
        args.zip = str(zip_file)

    if args.zip:
        project_info.local = True

    if args.skip_gh and args.zip is None:
        print("--skip-gh requires --zip or --local to supply a build archive")
        sys.exit(1)

    # Only require a GitHub token when we actually need to talk to GitHub.
    # With --skip-gh we have a local archive (enforced above) and won't push a
    # release, so the API client stays unused.
    needs_gh = not args.skip_gh
    api = None
    if needs_gh:
        if args.token is not None:
            token = args.token
        else:
            token = os.getenv("GITHUB_TOKEN", None)
        if token is None:
            print("the --token option or an env_variable GITHUB_TOKEN is required to use this tool")
            sys.exit(1)
        api = GhApi(owner='oxidecomputer', repo='quartz', token=token)

    zip_file, build_sha = process_gh_build(args, api, project_info.job_name)
    project_info.add_archive(zip_file)
    # Pin the release to the commit CI actually built, not to whatever main
    # points at by the time we get around to releasing.
    if build_sha is not None:
        project_info.add_build_sha(build_sha)
    
    # Do build reports
    timing_passed = project_info.report_timing()
    project_info.report_utilization()

    # extract files for GH release
    skip_gh = args.skip_gh
    # do GH release
    if args.skip_gh:
        print("Skipping GH release per command line request")
    elif not timing_passed:
        val = 'x'
        while val not in ['y', 'n']:
            val = input("Timing did not pass, do GH release anyway? (y/n): ")
            val = val.lower()
        if val == 'n':
            print("Skipping GH release due to timing failure")
            skip_gh = True
    gh_releaser.do_gh_release(api, project_info, skip_gh)

    # put files in hubris location
    if args.hubris is None:
        print("No hubris path provided, skipping materialization of files")
        return
    hubris_path = Path(args.hubris) / Path(project_info.hubris_path)
    print(f"Materializing files at {hubris_path} for hubris commit")
    project_info.materialize_relevant_files(hubris_path, exclusions=hubris_ignore)


def process_gh_build(args, api, name: str):
    """
    Return the build archive and the commit sha it was built from (None for a
    locally supplied archive, where we have no way to know).
    """
    # Get build archive zip file
    # Get the latest artifact from the repo since we didn't specify a zip file
    if args.zip is None:
        print("Fetching latest from GitHub")
        # Download the artifact from github
        artifact_inf = get_latest_artifact_info(api, name, branch=args.branch)
        zip_file = download_artifact(api, artifact_inf)
        build_sha = artifact_inf["workflow_run"]["head_sha"]
    else:
        print("Using local zip file")
        # Use the zip file from the command line
        zip_file = zipfile.ZipFile(args.zip)
        build_sha = None

    return zip_file, build_sha


def get_latest_artifact_info(api, fpga_name: str, branch: str = "main") -> dict:
    """
    Get the latest artifact from the specified branch.
    """
    artifacts = api.actions.list_artifacts_for_repo(name=fpga_name)
    artifacts = obj2dict(artifacts)

    on_branch = [x for x in artifacts["artifacts"] if x["workflow_run"]["head_branch"] == branch]
    if len(on_branch) == 0:
        print(f"No artifacts named {fpga_name} found on {branch}")
        print("Check that job_name in config.toml matches the CI artifact name")
        sys.exit(1)
    # GitHub keeps expired artifacts in the listing but refuses to serve them,
    # so drop them here rather than failing at download time.
    live = [x for x in on_branch if not x["expired"]]
    if len(live) == 0:
        newest = max(on_branch, key=lambda x: arrow.get(x["created_at"]))
        print(f"All {fpga_name} artifacts on {branch} have expired "
              f"(most recent: {newest['created_at']})")
        print("Re-run the build in CI to get a fresh artifact")
        sys.exit(1)
    live = sorted(live, key=lambda x: arrow.get(x["created_at"]), reverse=True)
    return live[0]


def download_artifact(api: GhApi, artifact_inf: dict):
    print(f"Downloading artifact {artifact_inf['name']} from GH: {artifact_inf['workflow_run']['head_branch']}")
    r = requests.get(artifact_inf["archive_download_url"], auth=("oxidecomputer", os.getenv("GITHUB_TOKEN", None)))
    if r.status_code != 200:
        # The body is JSON on error, and handing it to ZipFile just yields a
        # confusing BadZipFile, so say what GitHub actually told us.
        print(f"Failed to download artifact ({r.status_code}): {r.text}")
        sys.exit(1)
    return zipfile.ZipFile(io.BytesIO(r.content))


def make_buck2_zip():
    """
    Create a zip file from the buck2 build directory.
    """
    import shutil
    # Create object of ZipFile
    zipfile_path = Path.cwd() / Path("buck_out.zip")
    folder = Path.cwd() / "buck-out" / "v2" / "gen" / "root"
    shutil.make_archive(zipfile_path.with_suffix(''), 'zip', folder)
    return zipfile_path


if __name__ == '__main__':
    main()
    
    