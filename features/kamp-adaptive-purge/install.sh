#!/bin/ash
#
# Install KAMP (Klipper Adaptive Meshing & Purging) for adaptive line-purge
# on the K2 Plus. Clones upstream KAMP, symlinks Line_Purge.cfg into
# custom/, drops a K2 Plus-tailored kamp_settings.cfg + an [exclude_object]
# block, and ensures all three are included from custom/main.cfg.
#
# Does NOT restart Klipper — the new macros are available on next config
# reload. Print user-facing instructions at the end.

set -e

SCRIPT_DIR="$(readlink -f $(dirname $0))"
KAMP_DIR="${HOME}/Klipper-Adaptive-Meshing-Purging"
KAMP_REPO="https://github.com/kyleisah/Klipper-Adaptive-Meshing-Purging.git"

test -d ~/printer_data/config/custom || mkdir -p ~/printer_data/config/custom

# ------------------------------------------------------------
# 1. Clone or update KAMP at $HOME/Klipper-Adaptive-Meshing-Purging
# ------------------------------------------------------------
if [ -d "${KAMP_DIR}/.git" ]; then
    echo "I: KAMP repo already present at ${KAMP_DIR}, pulling latest"
    git -C "${KAMP_DIR}" pull --ff-only
else
    echo "I: cloning KAMP to ${KAMP_DIR}"
    git clone --depth=1 "${KAMP_REPO}" "${KAMP_DIR}"
fi

# ------------------------------------------------------------
# 2. Symlink KAMP's Line_Purge.cfg into custom/
# ------------------------------------------------------------
echo "I: symlinking Line_Purge.cfg into custom/"
ln -sfn "${KAMP_DIR}/Configuration/Line_Purge.cfg" \
    ~/printer_data/config/custom/Line_Purge.cfg

# ------------------------------------------------------------
# 3. Drop our K2 Plus-tailored kamp_settings.cfg into custom/
# (NOT a symlink — survives KAMP repo updates intact)
# ------------------------------------------------------------
echo "I: copying kamp_settings.cfg into custom/"
cp -f "${SCRIPT_DIR}/kamp_settings.cfg" \
    ~/printer_data/config/custom/kamp_settings.cfg

# ------------------------------------------------------------
# 4. Drop the [exclude_object] block (required for KAMP)
# ------------------------------------------------------------
# Only ship our own block if no [exclude_object] exists already anywhere
# in the config tree. If user already has one, leave it alone.
if ! grep -rEhq '^\[exclude_object\]' ~/printer_data/config/ 2>/dev/null; then
    echo "I: copying exclude_object.cfg into custom/"
    cp -f "${SCRIPT_DIR}/exclude_object.cfg" \
        ~/printer_data/config/custom/exclude_object.cfg
else
    echo "I: [exclude_object] already defined elsewhere, skipping"
fi

# ------------------------------------------------------------
# 5. Wire all three into custom/main.cfg
# ------------------------------------------------------------
echo "I: ensuring includes in custom/main.cfg"
python ${SCRIPT_DIR}/../../scripts/ensure_included.py \
    ~/printer_data/config/printer.cfg custom/main.cfg
python ${SCRIPT_DIR}/../../scripts/ensure_included.py \
    ~/printer_data/config/custom/main.cfg kamp_settings.cfg
python ${SCRIPT_DIR}/../../scripts/ensure_included.py \
    ~/printer_data/config/custom/main.cfg Line_Purge.cfg
if [ -f ~/printer_data/config/custom/exclude_object.cfg ]; then
    python ${SCRIPT_DIR}/../../scripts/ensure_included.py \
        ~/printer_data/config/custom/main.cfg exclude_object.cfg
fi

# ------------------------------------------------------------
# 6. Done — instructions for the user
# ------------------------------------------------------------
echo ""
echo "=================================================================="
echo " KAMP adaptive line-purge installed."
echo "=================================================================="
echo ""
echo " Next steps (do these when convenient — Klipper not restarted yet):"
echo ""
echo "  1. Restart Klipper (FIRMWARE_RESTART or SAVE_CONFIG) when no print"
echo "     is active. New [exclude_object] block + LINE_PURGE macro will"
echo "     load."
echo ""
echo "  2. Update your slicer's machine start gcode: replace the hardcoded"
echo "     purge G1 lines with a single LINE_PURGE call. Example:"
echo ""
echo "         (delete old G1 X0 Y150 ... G1 X150 Y0 ... block)"
echo "         LINE_PURGE"
echo ""
echo "     KAMP reads EXCLUDE_OBJECT_DEFINE polygons (Creality Print emits"
echo "     these automatically) and computes the purge position to land"
echo "     ~10mm in front of your print's bbox, inside the bed mesh region."
echo "     Tune via variable_purge_margin in custom/kamp_settings.cfg."
echo ""
echo "  3. Tune defaults in custom/kamp_settings.cfg or override in"
echo "     custom/overrides.cfg if needed."
echo ""
echo "  See features/kamp-adaptive-purge/README.md for the full guide."
echo ""
