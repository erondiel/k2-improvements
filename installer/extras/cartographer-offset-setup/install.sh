#!/bin/sh
# Cartographer probe X/Y offset picker.
#
# Touches [cartographer] x_offset / y_offset AND [stepper_y] position_endstop
# / position_min in custom/cartographer.cfg. The stepper_y range MUST match
# the mount geometry — for the toolhead to reach a probe Y position, the
# nozzle-axis Y must be (probe_Y - y_offset). Examples:
#   Jamin (y_offset=-15): probe Y=5 → toolhead Y=20  (position_min=-0.4 OK)
#   JimmyV (y_offset=36):  probe Y=5 → toolhead Y=-31 (needs position_min<=-32)
# Without widening position_min, BED_MESH_CALIBRATE on JimmyV throws
# "Move out of range" and fails. Mesh region stays the same — the bed is
# physically the same regardless of mount.
#
# Idempotent — picking the preset that's already applied is a no-op.

set -eu

CFG="${PRINTER_CFG_DIR:-/mnt/UDISK/printer_data/config}/custom/cartographer.cfg"
[ -f "$CFG" ] || { echo "ERROR: $CFG not found — install cartographer feature first"; exit 1; }

grep -q '^\[cartographer\]' "$CFG" || {
    echo "ERROR: [cartographer] section not found in $CFG"
    exit 1
}

# Read current values
CURRENT_X=$(awk '/^\[cartographer\]/{f=1; next} f && /^\[/ {f=0} f && /^x_offset:/ {print $2; exit}' "$CFG")
CURRENT_Y=$(awk '/^\[cartographer\]/{f=1; next} f && /^\[/ {f=0} f && /^y_offset:/ {print $2; exit}' "$CFG")
CURRENT_X="${CURRENT_X:-?}"
CURRENT_Y="${CURRENT_Y:-?}"

case "$CURRENT_X $CURRENT_Y" in
    "0 -15") CURRENT_PRESET='Jamin Collins front-mount' ;;
    "0 36")  CURRENT_PRESET='JimmyV back-mount' ;;
    *)       CURRENT_PRESET='custom' ;;
esac

echo
echo "=== Cartographer offset setup ==="
echo
echo "Current values in $CFG:"
echo "  x_offset: $CURRENT_X"
echo "  y_offset: $CURRENT_Y"
echo "  Identified as: $CURRENT_PRESET"
echo
echo "Pick your mount:"
echo "  1. Jamin Collins front-mount   x=0   y=-15  (gimme-the-jamin default)"
echo "  2. JimmyV back-mount           x=0   y=36"
echo "  3. Custom — enter values"
echo "  b. Cancel — leave config unchanged"
echo
printf 'Choose: '
read -r choice

case "$choice" in
    1) NEW_X=0;  NEW_Y=-15; NEW_YMIN=-0.4;  LABEL='Jamin Collins front-mount' ;;
    2) NEW_X=0;  NEW_Y=36;  NEW_YMIN=-32;   LABEL='JimmyV back-mount' ;;
    3)
        printf '  x_offset (mm, default %s): ' "$CURRENT_X"
        read -r NEW_X
        [ -z "$NEW_X" ] && NEW_X="$CURRENT_X"
        printf '  y_offset (mm, default %s): ' "$CURRENT_Y"
        read -r NEW_Y
        [ -z "$NEW_Y" ] && NEW_Y="$CURRENT_Y"

        # Validate: numeric in range -100..100
        for v in "$NEW_X" "$NEW_Y"; do
            case "$v" in
                ''|*[!0-9.\-]*) echo "ERROR: '$v' is not a number"; exit 1 ;;
            esac
        done
        # Range check via awk (handles floats and negatives)
        for v in "$NEW_X" "$NEW_Y"; do
            ok=$(awk -v x="$v" 'BEGIN { print (x >= -100 && x <= 100) ? "ok" : "bad" }')
            [ "$ok" = "ok" ] || { echo "ERROR: $v is outside the sane range -100..100"; exit 1; }
        done
        # Auto-derive position_min: needs to be at least (5 - y_offset)
        # so probe can reach mesh_min Y=5. Add 1mm safety margin.
        NEW_YMIN=$(awk -v y="$NEW_Y" 'BEGIN { v = 5 - y - 1; printf "%.1f", (v < -0.4) ? v : -0.4 }')
        echo "  Derived position_min: $NEW_YMIN  (so probe can reach mesh_min Y=5)"
        LABEL='custom'
        ;;
    *) echo "cancelled"; exit 0 ;;
esac

if [ "$NEW_X" = "$CURRENT_X" ] && [ "$NEW_Y" = "$CURRENT_Y" ]; then
    echo "I: values already match — no change"
    exit 0
fi

BACKUP="${CFG}.before-offset-$(date +%s)"
cp "$CFG" "$BACKUP"

awk -v nx="$NEW_X" -v ny="$NEW_Y" -v nymin="$NEW_YMIN" '
BEGIN { section = "" }
/^\[/ { section = $0; print; next }
section == "[cartographer]" && /^x_offset:/ { print "x_offset: " nx; next }
section == "[cartographer]" && /^y_offset:/ { print "y_offset: " ny; next }
section == "[stepper_y]" && /^position_endstop:/ { print "position_endstop: " nymin; next }
section == "[stepper_y]" && /^position_min:/ { print "position_min: " nymin; next }
{ print }
' "$CFG" > "${CFG}.new" && mv "${CFG}.new" "$CFG"

echo
echo "I: applied $LABEL"
echo "I:   x_offset:           $CURRENT_X → $NEW_X"
echo "I:   y_offset:           $CURRENT_Y → $NEW_Y"
echo "I:   stepper_y position: → $NEW_YMIN  (endstop + min, to reach mesh corners)"
echo "I: backup at $BACKUP"
echo "I: active on next Klipper restart (then power-cycle from mains before next G28)"
