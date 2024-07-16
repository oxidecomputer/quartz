# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.
#
# Copyright 2024 Oxide Computer Company

import argparse
import json
from pathlib import Path
from jinja2 import Environment, PackageLoader

from typing import List

parser = argparse.ArgumentParser()
parser.add_argument(
    "--input", dest="input_json", help="Explicit input file"
)
parser.add_argument("--output", dest="output", help="Explicit output list")

args = parser.parse_args()

class Source:
    def __init__(self, path, library, standard):
        self.path = path
        self.library = library
        self.standard = standard

class Project:
    def __init__(self, 
        flow: str,
        part: str,
        top_name: str,
        constraints: list,
        pre_synth_tcl_files: list,
        post_synth_tcl_files: list,
        sources: List[Source],
        synth_args: List[str],
        debug_probes: str,
        report_file: str,
        max_threads: int,
        input_checkpoint: str,
    ):
        self.flow = flow
        self.part = part
        self.top_name = top_name
        self.constraints = [Path(x) for x in constraints]
        self.pre_synth_tcl_files = [Path(x) for x in pre_synth_tcl_files]
        self.post_synth_tcl_files = [Path(x) for x in post_synth_tcl_files]
        self.debug_probes = debug_probes
        self.sources = sources
        self.synth_args = synth_args
        self.report_file = report_file
        self.max_threads = max_threads
        self.input_checkpoint = Path(input_checkpoint)
    
    @classmethod
    def from_dict(cls, inputs):
        srcs = inputs.get("sources", [])
        sources = []
        for file in srcs:
            # Drop any non-synth files here
            if not file.get("is_synth"):
                print("Dropping non-synth file {}".format(file))
                continue
            sources.append(Source(Path(file.get("artifact")), file.get("library"), file.get("standard")))
        
        return cls(
            flow=inputs.get("flow"),
            part=inputs.get("part"),
            top_name=inputs.get("top_name", ""),
            constraints=inputs.get("constraints", []),
            pre_synth_tcl_files=inputs.get("pre_synth_tcl_files", []),
            post_synth_tcl_files=inputs.get("post_synth_tcl_files", []),
            debug_probes=inputs.get("debug_probes", ""),
            sources=sources,
            synth_args=inputs.get("synth_args"),
            report_file=inputs.get("report_file"),
            max_threads=inputs.get("max_threads"),
            input_checkpoint=inputs.get("input_checkpoint", "")
        )
def main():

    # Open the json file we were handed from buck2
    with open(args.input_json) as fp:
        inputs = json.load(fp)

    project = Project.from_dict(inputs)
    # Build jinja env
    env = Environment(
        loader=PackageLoader("vivado_gen"),
        lstrip_blocks=True,
        trim_blocks=True,
    )
 
    print("Constraints:")
    print(project.constraints)

    # get flow id from the json file
    if project.flow == "synthesis":
        template = env.get_template("synth.jinja2")
    elif project.flow == "optimize":
        template = env.get_template("optimize.jinja2")
    elif project.flow == "place":
        template = env.get_template("place.jinja2")
    elif project.flow == "place_optimize":
        template = env.get_template("place_optimize.jinja2")
    elif project.flow == "route":
        template = env.get_template("route.jinja2")
    elif project.flow == "bitstream":
        template = env.get_template("bitstream.jinja2")
    else:
        print("Unknown flow")
    
    # Now render the template and write it out
    content = template.render(
        project=project,
    )
    with open(args.output, mode="w", encoding="utf-8") as message:
        message.write(content)


if __name__ == "__main__":
    main()