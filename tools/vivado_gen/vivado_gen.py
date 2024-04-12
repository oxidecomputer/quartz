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
    def __init__(self, path, library):
        self.path = path
        self.library = library 

class Project:
    def __init__(self, 
        flow: str,
        part: str,
        top_name: str,
        constraints: list,
        sources: List[Source],
        synth_args: List[str],
        report_file: str,
        max_threads: int,
    ):
        self.flow = flow
        self.part = part
        self.top_name = top_name
        self.constraints = [Path(x) for x in constraints]
        self.sources = sources
        self.synth_args = synth_args
        self.report_file = report_file
        self.max_threads = max_threads
    
    @classmethod
    def from_dict(cls, inputs):
        srcs = inputs.get("sources")
        sources = []
        for file in srcs:
            sources.append(Source(Path(file.get("artifact")), file.get("library")))
        
        return cls(
            flow=inputs.get("flow"),
            part=inputs.get("part"),
            top_name=inputs.get("top_name"),
            constraints=inputs.get("constraints"),
            sources=sources,
            synth_args=inputs.get("synth_args"),
            report_file=inputs.get("report_file"),
            max_threads=inputs.get("max_threads"),
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

    # get flow id from the json file
    if project.flow == "synthesis":
        template = env.get_template("synth.jinja2")
    elif project.flow == "optimize":
        pass
    elif project.flow == "place":
        pass
    elif project.flow == "place_optimize":
        pass
    elif project.flow == "route":
        pass
    elif project.flow == "bitstream":
        pass
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