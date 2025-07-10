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
parser.add_argument("--output", dest="output", help="Explicit output list")

args = parser.parse_args()

def main():

    # Build jinja env
    env = Environment(
        loader=PackageLoader("vivado_ip"),
        lstrip_blocks=True,
        trim_blocks=True,
    )
    template = env.get_template("ip_gen.jinja2")
    
    # Now render the template and write it out
    content = template.render(
    )
    with open(args.output, mode="w", encoding="utf-8") as message:
        message.write(content)


if __name__ == "__main__":
    main()