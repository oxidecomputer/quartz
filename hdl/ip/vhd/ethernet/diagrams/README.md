# diagrams

`*.drawio` are the editable sources; the `*.drawio.svg` next to them are what
the .adoc files reference. Regenerate with

    tools/drawio_export.sh [file...]        # default: every .drawio under hdl/

which drives the draw.io desktop flatpak headlessly and embeds the editable
diagram in the SVG, so the exported file opens in draw.io as shapes rather
than as an image -- the convention the espi and ignition diagrams follow. The
equivalent by hand is File > Export as > SVG with "Include a copy of my
diagram" checked.

Two things to know when authoring: keep exports under `$HOME` (the flatpak
shares only the home directory, so an export to `/tmp` silently goes nowhere),
and do not give a cell the id `map` -- draw.io then fails to render the whole
diagram. The script's two non-obvious flags are explained in its header: draw.io's
wrapper prepends Electron flags that its own argument parser mistakes for the
input filename, so the binary is invoked directly and the platform hint is
passed *after* the input.

Palette (same as those): fill `#1C372E`, stroke and text `#48D597`, accent
`#F5B944`, Courier New. Accent marks what a diagram is actually about -- the
blocks the managed top adds, the tap and inject paths, the fields that get
patched after the fact.

Note the three older `bridge_block` / `pcs_block` / `rgmii_block` SVGs here are
hand-written SVG rather than draw.io exports, despite the extension: draw.io
opens them as images, not as editable shapes.
