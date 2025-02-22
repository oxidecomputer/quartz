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
parser.add_argument("--skip-gh", default=False, action="store_true", help="Skip doing GH release. Note that doing this still generates release metadata that just will be wrong")
parser.add_argument("--zip", default=None, help="Path to zip file to use instead of downloading from GitHub")

hubris_ignore = [".html", ".log", ".rpt"]

def main():
    """
    Main function to process the command line arguments and run the release process.
    """
    args = parser.parse_args()
    if args.fpga is None:
        print("Please specify an FPGA project with --fpga")
        sys.exit(1)

    if args.token is not None:
          token = args.token
    else:
        token = os.getenv("GITHUB_TOKEN", None)
    if token is None:
        print("the --token option or an env_variable GITHUB_TOKEN is required to use this tool")
        sys.exit(1)

    repo = "quartz"
    api = GhApi(owner='oxidecomputer', repo=repo, token=token)
    
    project_info = project.get_config(args.fpga)
    print(f"Processing {args.fpga} with builder {project_info.builder}")

    # Get build archive
    zip_file = process_gh_build(args, api, project_info.job_name)
    project_info.add_archive(zip_file)
    
    # Do build reports
    project_info.report_timing()
    project_info.report_utilization()

    # extract files for GH release
    # do GH release
    if args.skip_gh:
        print("Skipping GH release per command line request")
    gh_releaser.do_gh_release(api, project_info, args.skip_gh)

    # put files in hubris location
    hubris_path = Path(args.hubris) / Path(project_info.hubris_path)
    print(f"Materializing files at {hubris_path} for hubris commit")
    project_info.materialize_relevant_files(hubris_path, exclusions=hubris_ignore)

    

def process_gh_build(args, api, name: str):

    # Get build archive zip file
    # Get the latest artifact from the repo since we didn't specify a zip file
    if args.zip is None:
        print("Fetching latest from GitHub")
        # Download the artifact from github
        artifact_inf = get_latest_artifact_info(api, name, branch=args.branch)
        zip_file = download_artifact(api, artifact_inf)
    else:
        print("Using local zip file")
        # Use the zip file from the command line
        zip_file = zipfile.ZipFile(args.zip)

    return zip_file


def get_latest_artifact_info(api, fpga_name: str, branch: str = "main") -> dict:
    """
    Get the latest artifact from the specified branch.
    """
    artifacts = api.actions.list_artifacts_for_repo(name=fpga_name)
    artifacts = obj2dict(artifacts)
    artifacts = list(filter(lambda x: x["workflow_run"]["head_branch"] == branch, artifacts["artifacts"]))
    if len(artifacts) == 0:
        print(f"No artifacts found for {fpga_name} on {branch}")
        return None
    artifacts = sorted(artifacts, key=lambda x: arrow.get(x["created_at"]), reverse=True)
    return artifacts[0]

def download_artifact(api: GhApi, artifact_inf: dict):
    print(f"Downloading artifact {artifact_inf['name']} from GH: {artifact_inf['workflow_run']['head_branch']}")
    r = requests.get(artifact_inf["archive_download_url"], auth=("oxidecomputer", os.getenv("GITHUB_TOKEN", None)))
    return zipfile.ZipFile(io.BytesIO(r.content))

if __name__ == '__main__':
    main()
    
    