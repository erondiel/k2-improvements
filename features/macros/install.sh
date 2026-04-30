#!/bin/sh
# Top-level macros installer — runs all four macros sub-feature installers
# (start_print, m191, bed_mesh, overrides) in order.
#
# Without this wrapper, the "macros" feature has no top-level install.sh
# and any caller that dispatches to features/macros/install.sh fails.

set -eu

SCRIPT_DIR="$(readlink -f $(dirname $0))"

for sub in start_print m191 bed_mesh overrides; do
    if [ -f "$SCRIPT_DIR/$sub/install.sh" ]; then
        echo "--- macros/$sub ---"
        sh "$SCRIPT_DIR/$sub/install.sh"
    else
        echo "W: $SCRIPT_DIR/$sub/install.sh not found — skipping"
    fi
done

echo "I: macros (start_print, m191, bed_mesh, overrides) installed"
