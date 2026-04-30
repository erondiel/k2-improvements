#!/bin/sh
# Strip the orphan `#*# [prtouch_v3]` SAVE_CONFIG header that survives the
# cartographer feature install on stock K2 Plus and triggers
#   "Option 'step_swap_pin' in section 'prtouch_v3' must be specified"
# at Klipper start.
#
# Idempotent — does nothing if no orphan header exists.

set -eu

CFG="${PRINTER_CFG_DIR:-/mnt/UDISK/printer_data/config}/printer.cfg"

[ -f "$CFG" ] || { echo "ERROR: $CFG not found"; exit 1; }

if grep -q '^#\*# \[prtouch_v3\]$' "$CFG"; then
    cp "$CFG" "${CFG}.before-prtouch-cleanup-$(date +%s)"
    sed -i '/^#\*# \[prtouch_v3\]$/d' "$CFG"
    echo "I: removed orphan [prtouch_v3] SAVE_CONFIG header from $CFG"
    echo "I: backup at ${CFG}.before-prtouch-cleanup-*"
else
    echo "I: no orphan [prtouch_v3] header found — nothing to do"
fi
