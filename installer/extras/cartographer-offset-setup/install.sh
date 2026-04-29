#!/bin/sh
# JimmyV back-mount Cartographer overrides.
#
# Updates these specific values in custom/cartographer.cfg:
#   [cartographer]   x_offset: 0       y_offset: 36
#   [bed_mesh]       mesh_min: 10, 5   mesh_max: 340, 330
#   [stepper_y]      position_endstop: -0.4   position_min: -0.4
#
# Idempotent — re-runs are no-ops if the values already match.

set -eu

CFG="${PRINTER_CFG_DIR:-/mnt/UDISK/printer_data/config}/custom/cartographer.cfg"
[ -f "$CFG" ] || { echo "ERROR: $CFG not found — install cartographer feature first"; exit 1; }

# Verify required sections exist before touching anything
for sec in '\[cartographer\]' '\[bed_mesh\]' '\[stepper_y\]'; do
    grep -q "^$sec" "$CFG" || {
        echo "ERROR: section $sec not found in $CFG — non-standard layout"
        exit 1
    }
done

# Detect whether the values are already correct
CURRENT_Y_OFFSET=$(awk '/^\[cartographer\]/{f=1} f&&/^y_offset:/{print $2; exit}' "$CFG" 2>/dev/null || true)
CURRENT_MESH_MIN=$(awk '/^\[bed_mesh\]/{f=1} f&&/^mesh_min:/{$1=""; print substr($0,2); exit}' "$CFG" 2>/dev/null || true)

if [ "$CURRENT_Y_OFFSET" = "36" ] \
    && [ "$CURRENT_MESH_MIN" = "10, 5" ]; then
    echo "I: JimmyV mount overrides already applied to $CFG"
    exit 0
fi

BACKUP="${CFG}.before-jimmyv-$(date +%s)"
cp "$CFG" "$BACKUP"

# Section-aware patch: only update keys when inside the right [section]
awk '
BEGIN { section = "" }
/^\[/ { section = $0; print; next }
section == "[cartographer]" && /^x_offset:/  { print "x_offset: 0";       next }
section == "[cartographer]" && /^y_offset:/  { print "y_offset: 36";      next }
section == "[bed_mesh]"     && /^mesh_min:/  { print "mesh_min: 10, 5";   next }
section == "[bed_mesh]"     && /^mesh_max:/  { print "mesh_max: 340, 330";next }
section == "[stepper_y]"    && /^position_endstop:/ { print "position_endstop: -0.4"; next }
section == "[stepper_y]"    && /^position_min:/     { print "position_min: -0.4";     next }
{ print }
' "$CFG" > "${CFG}.new" && mv "${CFG}.new" "$CFG"

echo "I: JimmyV mount overrides applied to $CFG"
echo "I: backup at $BACKUP"
echo "I: changed values:"
echo "    [cartographer] x_offset=0, y_offset=36"
echo "    [bed_mesh]     mesh_min=10,5  mesh_max=340,330"
echo "    [stepper_y]    position_endstop=-0.4  position_min=-0.4"
echo "I: active on next Klipper restart"
