import argparse
from pathlib import Path
from jinja2 import Environment, FileSystemLoader


parser = argparse.ArgumentParser()
parser.add_argument(
    "--input", "--inputs", nargs="+", dest="inputs", help="Explicit input file list"
)
parser.add_argument("--output", dest="output", help="Explicit output list")

args = parser.parse_args()


class Library:
    def __init__(self, name, files=None):
        self.name = name
        self.files = [] if files is None else files


def main():
    # Load jinja templates
    env = Environment(
        loader=FileSystemLoader(Path(__file__).parent / "templates"),
        lstrip_blocks=True,
        trim_blocks=True,
    )
    template = env.get_template("run_py.jinja2")

    lib = Library("lib")
    print([Path.cwd() / Path(x) for x in args.inputs])
    for x in args.inputs:
        p = Path.cwd() / Path(x)
        lib.files.append(p.absolute())

    content = template.render(
        libraries=[lib],
        # vunit_out=args.vunit_out,
    )
    with open(args.output, mode="w", encoding="utf-8") as message:
        message.write(content)


if __name__ == "__main__":
    main()
