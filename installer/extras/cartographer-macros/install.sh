#!/bin/sh
# Install CARTO_* macros that wrap CARTOGRAPHER_* commands into [gcode_macro]
# definitions, so Fluidd's macros panel shows them as buttons.
#
# Idempotent — re-runs just refresh the symlink and ensure the include.

set -eu

SCRIPT_DIR="$(readlink -f "$(dirname "$0")")"
CFG_DIR="${PRINTER_CFG_DIR:-/mnt/UDISK/printer_data/config}"
CUSTOM="$CFG_DIR/custom"

[ -d "$CUSTOM" ] || { echo "ERROR: $CUSTOM not found — install macros feature first"; exit 1; }
grep -q '^\[cartographer\]' "$CFG_DIR/printer.cfg" "$CUSTOM"/*.cfg 2>/dev/null || {
    echo "ERROR: no [cartographer] section found — install cartographer feature first"
    exit 1
}

ln -sfn "$SCRIPT_DIR/cartographer_macros.cfg" "$CUSTOM/cartographer_macros.cfg"
echo "I: symlinked cartographer_macros.cfg into custom/"

# Wire include into custom/main.cfg
INSTALLER_BASE="${INSTALLER_DIR:-/mnt/UDISK/k2-improvements}"
ENSURE_INCLUDED="$INSTALLER_BASE/scripts/ensure_included.py"
if [ -f "$ENSURE_INCLUDED" ]; then
    python3 "$ENSURE_INCLUDED" "$CUSTOM/main.cfg" cartographer_macros.cfg
else
    grep -q '^\[include cartographer_macros.cfg\]' "$CUSTOM/main.cfg" 2>/dev/null \
        || echo "[include cartographer_macros.cfg]" >> "$CUSTOM/main.cfg"
fi

echo "I: cartographer-macros installed. CARTO_* macros appear in Fluidd"
echo "I: after a Klipper restart (FIRMWARE_RESTART)."
