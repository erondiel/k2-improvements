#!/bin/ash

set -e

SCRIPT_DIR="$(readlink -f $(dirname $0))"

test -d ~/printer_data/config/custom || mkdir -p ~/printer_data/config/custom

# Defensive check: this feature defines [save_variables] (filename in /tmp).
# If the user has another [save_variables] elsewhere, Klipper will refuse to
# load with a duplicate-section error.
if grep -rEhq '^\[save_variables\]' ~/printer_data/config/ 2>/dev/null; then
    EXISTING="$(grep -rl '^\[save_variables\]' ~/printer_data/config/ 2>/dev/null | grep -v 'motor_state_guard.cfg' || true)"
    if [ -n "$EXISTING" ]; then
        echo "E: motor-state-guard requires [save_variables] but it is already defined in:"
        echo "   $EXISTING"
        echo "E: merge manually — set 'filename: /tmp/k2-motor-state-guard.cfg' in your"
        echo "E: existing block (it MUST live in tmpfs for restart detection to work)."
        exit 1
    fi
fi

# Defensive check: G28 is overridden via rename_existing. If another macro
# already wraps G28, the user must reconcile.
if grep -rEhq '^\[gcode_macro G28\]' ~/printer_data/config/ 2>/dev/null; then
    EXISTING="$(grep -rl '^\[gcode_macro G28\]' ~/printer_data/config/ 2>/dev/null | grep -v 'motor_state_guard.cfg' || true)"
    if [ -n "$EXISTING" ]; then
        echo "E: motor-state-guard wraps G28 via rename_existing, but another"
        echo "E: [gcode_macro G28] already exists in:"
        echo "E:   $EXISTING"
        echo "E: merge manually — call the guard logic at the top of your wrapper,"
        echo "E: or skip this feature."
        exit 1
    fi
fi

# add main.cfg to printer.cfg (no-op if already included)
python ${SCRIPT_DIR}/../../scripts/ensure_included.py \
    ~/printer_data/config/printer.cfg custom/main.cfg

# symlink the cfg into custom/
ln -sf ${SCRIPT_DIR}/motor_state_guard.cfg \
    ~/printer_data/config/custom/motor_state_guard.cfg

# include it from custom/main.cfg
python ${SCRIPT_DIR}/../../scripts/ensure_included.py \
    ~/printer_data/config/custom/main.cfg motor_state_guard.cfg

echo "I: motor-state-guard installed."
echo "I: NOT restarting Klipper automatically — restart triggers the very state"
echo "I: this guard exists to detect. Restart Klipper at your convenience; the"
echo "I: guard becomes active on the next start. After that, mains power-cycle"
echo "I: is required before G28 (or run POWER_CYCLED_OK to override)."
