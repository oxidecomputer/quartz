# create a release with image-name-TIMESTAMP?
# push up logs, binary, docs and readme
from ghapi.all import GhApi
from pathlib import Path
import tempfile


def do_gh_release(api: GhApi, info, skip_mods=False):

    name = f"{info.name}-{info.timestamp}"
    body = f"FPGA release for {info.name} made on {info.timestamp} UTC"
    # TODO: should we add something about timing failure here?
    # TODO: info about this being a locally generated file?
    applicable_hcvs = '_' + ''.join(info.applicable_hcvs) if info.applicable_hcvs else ''
    tag_name = name + applicable_hcvs
    if info.gh_build_sha == "":
        # Built locally? Or not from a GH release
        sha = api.git.get_ref("heads/main")["object"].get("sha")
    else:
        sha = info.gh_build_sha

    info.add_build_sha(sha)  # in case local build

    # Create a tag
    if not skip_mods:
        api.git.create_tag(tag_name, body, sha, "commit")

    # Stick the release files somewhere temporary
    with tempfile.TemporaryDirectory() as temp_dir:
        files = info.materialize_relevant_files(temp_dir)
        full_files = [Path(temp_dir) / Path(x) for x in files]
        # Create a Release
        if not skip_mods:
            rel = api.create_release(tag_name,sha,name,body, files=full_files)
            info.add_release_url(rel.get('url'))
        else:
            info.add_release_url('None: gh release was skipped')
    