#!/bin/sh
# Export .drawio sources to .drawio.svg with the editable diagram embedded,
# using the draw.io desktop flatpak headlessly.
#
# Two things make this work, both learned the hard way:
#   * /app/bin/run.sh prepends its own Electron flags, and drawio's argument
#     parser treats unknown flags as positional -- it then tries to open
#     "--ozone-platform-hint=auto" as the input and reports "input
#     file/directory not found". So invoke /app/main/drawio directly.
#   * That binary still needs a platform, and X11 is not reachable from the
#     sandbox here, so pass the ozone hint *after* the input file where the
#     parser will not mistake it for one.
#
# Two gotchas that cost real time, recorded so they do not have to be
# rediscovered:
#   * Output must land under $HOME. The sandbox shares `home` and nothing
#     else, so writing to /tmp succeeds *inside the sandbox* and the file
#     never appears on the host -- which looks exactly like a failed export.
#   * A cell whose id is "map" makes draw.io fail to render the whole
#     diagram ("Error: Export failed", no output). Presumably an id/property
#     collision in its model. Avoid ids that read like JS object members.
#
# Do NOT SIGKILL the app to "clean up" between runs: that leaves the flatpak
# session's D-Bus connection broken, after which every subsequent export hangs
# and dies with "D-Bus connection was disconnected", and only a fresh login
# seems to clear it. Let each invocation exit on its own.
#
# usage: tools/drawio_export.sh [files...]   (default: every .drawio in hdl/)
set -e
APP=com.jgraph.drawio.desktop
[ $# -gt 0 ] && FILES="$*" || FILES=$(find hdl -name '*.drawio' | sort)
for f in $FILES; do
    src=$(readlink -f "$f")
    out="${src%.drawio}.drawio.svg"
    flatpak run --command=/app/main/drawio $APP --no-sandbox \
        -x -f svg --embed-diagram -o "$out" "$src" \
        --ozone-platform-hint=auto 2>/dev/null
    printf '%s\n' "$out"
done
