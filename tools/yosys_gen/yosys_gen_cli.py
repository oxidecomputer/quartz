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
parser.add_argument("--output", dest="output", help="Explicit output python")

args = parser.parse_args()

class Source:
    def __init__(self, path, library, standard):
        self.path = path
        self.library = library
        self.standard = standard


class Project:
    def __init__(self, 
        synth_family: str,
        top_entity_name: str,
        sources: List[Source],
    ):
        self.top_entity_name = top_entity_name
        self.synth_family = synth_family
        self.sources = sources
    
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
            top_entity_name=inputs.get("top_entity_name", ""),
            synth_family=inputs.get("synth_family", "synth_ice40"),
            sources=sources,
        )
def main():

    # Open the json file we were handed from buck2
    with open(args.input_json) as fp:
        inputs = json.load(fp)

    project = Project.from_dict(inputs)
    # Build jinja env
    env = Environment(
        loader=PackageLoader("yosys_gen"),
        lstrip_blocks=True,
        trim_blocks=True,
    )

    template = env.get_template("synth_py.jinja2")
    
    # Now render the template and write it out
    content = template.render(
        project=project,
    )
    with open(args.output, mode="w", encoding="utf-8") as message:
        message.write(content)


if __name__ == "__main__":
    main()