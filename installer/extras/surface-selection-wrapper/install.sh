#!/bin/sh
# Insert the SURFACE-selection wrapper into start_print.cfg so the
# slicer can pass SURFACE=<name> and have START_PRINT load the matching
# Cartographer scan and touch models.
#
# Idempotent — detects the BEGIN marker and exits if already inserted.

set -eu

CFG_DIR="${PRINTER_CFG_DIR:-/mnt/UDISK/printer_data/config}"
SYMLINK="$CFG_DIR/custom/start_print.cfg"

[ -e "$SYMLINK" ] || { echo "ERROR: $SYMLINK not found — install macros feature first"; exit 1; }

# Resolve symlink so we patch the actual file
TARGET=$(readlink -f "$SYMLINK" 2>/dev/null || echo "$SYMLINK")
[ -f "$TARGET" ] || { echo "ERROR: $TARGET not found"; exit 1; }

# Match both clean and parenthetical-variant markers
if grep -qE '^[[:space:]]*# === BEGIN surface-selection wrapper' "$TARGET"; then
    echo "I: surface-selection wrapper already present in $TARGET"
    exit 0
fi

if ! grep -q 'STATUS_MSG.*MSG="Preheating' "$TARGET"; then
    echo "ERROR: anchor not found in $TARGET"
    echo "  expected line containing: STATUS_MSG ... MSG=\"Preheating ...\""
    echo "  upstream macros file may have changed; bail out"
    exit 1
fi

BACKUP="${TARGET}.before-surface-wrapper-$(date +%s)"
cp "$TARGET" "$BACKUP"

awk '
/STATUS_MSG.*MSG="Preheating/ && !inserted {
    print "  # === BEGIN surface-selection wrapper ==="
    print "  {% set SURFACE = params.SURFACE|default(\047default\047)|lower %}"
    print "  CARTOGRAPHER_SCAN_MODEL LOAD={SURFACE}"
    print "  CARTOGRAPHER_TOUCH_MODEL LOAD={SURFACE}"
    print "  # === END surface-selection wrapper ==="
    print ""
    inserted=1
}
{ print }
' "$TARGET" > "${TARGET}.new" && mv "${TARGET}.new" "$TARGET"

echo "I: surface-selection wrapper inserted into $TARGET"
echo "I: backup at $BACKUP"
echo "I: active on next Klipper restart"
