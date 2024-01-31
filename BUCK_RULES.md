= Flow-specific BUCK rules

== VHDL files/module rule organization
The expectation is that your BUCK files will have at least one entry
for each vhdl "module" in your design. As a guideline, you should
compose your modules such that any level that could be a dependency
to some other module is factored into its own rule. It would be a
common case for many VHDL package files to want be re-used in multiple
places, so they would be put each in their own `vhdl_unit` rule.
In cases where a package and some number of other files might make
up a re-usable module all together but not separately, these could
be put in a single `vhdl_unit` rule.


The general VHDL rule in buck is defined [here](tools/hdl.bzl) as
`vhdl_unit = rule(
    impl=_hdl_unit_impl,
    attrs={
        "deps": attrs.list(
            attrs.dep(doc="Dependencies as dep types (ie from another rule)"),
            default=[],
        ),
        "srcs": attrs.list(attrs.source(doc="Expected VHDL sources")),
        "is_tb": attrs.bool(
            doc=(
                "Set to True when this is a top-level VUnit testbench\
            for which a run.py should be generate"
            ),
            default=False,
        ),
        "_toolchain": attrs.toolchain_dep(
            doc="Use system python toolchain for running VUnit",
            default="toolchains//:python",
        ),
        "_bins": attrs.exec_dep(
            doc="Use vunit_gen toolchain for generating VUnit run.pys",
            default="root//tools/vunit_gen:vunit_gen",
        ),
    },
)`

`srcs` is a list of source files for this module, and glob can be used if it makes sense,
`srcs = glob(["*.vhd"])` as an example with the paths being relative to the BUCK file.

`deps` expects a list of BUCK target patterns that point to other targets that this module
depends on, typically RDL targets (see below) or other VHDL module targets. See 
[vunit_example](hdl/projects/vunit_example/BUCK) for some examples.

The remaining attributes should generally use the defaults and can be ignored.


== System RDL
Another simple rule here, but each RDL file gets its own rule entry.

The rdl rule in buck is defined [here](tools/rdl.bzl) as
`rdl_file = rule(
    impl=_rdl_file_impl,
    attrs={
        "src": attrs.source(),
        "deps": attrs.list(attrs.dep(), default=[]),
        "outputs": attrs.list(attrs.string(), default=[]),
        "_rdl_gen": attrs.exec_dep(default="root//tools/site_cobble/rdl_pkg:rdl_cli"),
    },
)`

The user provides the `src` file path and optionally any other RDL target patterns upon which
this definition depends, and provides a list of expected `outputs`.  Output type is determined
by output extension, known possible output extensions are: `.bsv`, `.json`, `.vhd`, `.html`, `.adoc`

The `vhdl_unit` rule knows how to take the RDL targets as a dependency so long as a `.vhd` output is
generated for the target that will be a dep to a VHDL block.