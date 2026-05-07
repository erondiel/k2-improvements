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
# 6. Optional: enable Klipper firmware retraction
# ------------------------------------------------------------
# KAMP's LINE_PURGE prefers G10/G11 (firmware retraction) over inline
# G1 E-.5/+.5 fallbacks, and prints a recommendation message at print
# time if firmware retraction is not configured. Offer to add a default
# config here. Skip silently if [firmware_retraction] already exists
# anywhere in the config tree, or if running non-interactively (e.g.
# via menu.sh batch with no controlling terminal).

FW_RETRACT_STATUS="not configured"

if grep -rEhq '^\[firmware_retraction\]' ~/printer_data/config/ 2>/dev/null; then
    echo "I: [firmware_retraction] already configured — skipping"
    FW_RETRACT_STATUS="already configured (left alone)"
elif [ ! -t 0 ]; then
    echo "I: non-interactive run; skipping firmware_retraction prompt"
    echo "I:   to enable later: cp ${SCRIPT_DIR}/firmware_retraction.cfg \\"
    echo "I:                       ~/printer_data/config/custom/ and add to main.cfg"
    FW_RETRACT_STATUS="not configured (use --enable-firmware-retraction or run interactively)"
else
    echo ""
    echo "Optional: enable Klipper firmware retraction?"
    echo "  - Silences KAMP's purge-time warning"
    echo "  - Lets G10/G11 work in any macro"
    echo "  - One place to tune retraction length/speed"
    echo "  - Default ships with conservative PLA values (0.5mm @ 35mm/s)"
    echo "  - If you have it set per-filament in the slicer, you can skip this"
    echo ""
    printf "Enable firmware retraction with default values? [y/N] "
    read FW_RETRACT_CHOICE
    case "$FW_RETRACT_CHOICE" in
        y|Y|yes|YES)
            echo "I: copying firmware_retraction.cfg into custom/"
            cp -f "${SCRIPT_DIR}/firmware_retraction.cfg" \
                ~/printer_data/config/custom/firmware_retraction.cfg
            python ${SCRIPT_DIR}/../../scripts/ensure_included.py \
                ~/printer_data/config/custom/main.cfg firmware_retraction.cfg
            FW_RETRACT_STATUS="enabled with PLA defaults — tune in custom/firmware_retraction.cfg"
            ;;
        *)
            echo "I: skipped firmware retraction"
            echo "I:   to enable later: cp ${SCRIPT_DIR}/firmware_retraction.cfg \\"
            echo "I:                       ~/printer_data/config/custom/ and add to main.cfg"
            FW_RETRACT_STATUS="not configured"
            ;;
    esac
fi

# ------------------------------------------------------------
# 7. Done — instructions for the user
# ------------------------------------------------------------
echo ""
echo "=================================================================="
echo " KAMP adaptive line-purge installed."
echo "=================================================================="
echo ""
echo " Firmware retraction: ${FW_RETRACT_STATUS}"
echo ""
echo " IMPORTANT — slicer-side changes are required for KAMP to work."
echo " Without them LINE_PURGE has nothing to read and falls back to a"
echo " static purge at the bed origin (the original problem)."
echo ""
echo "------------------------------------------------------------------"
echo " 1. Restart Klipper (FIRMWARE_RESTART) when no print is active."
echo "    The new [exclude_object] block and LINE_PURGE macro will load."
echo ""
echo "------------------------------------------------------------------"
echo " 2. Enable 'Label objects' in your slicer."
echo ""
echo "    KAMP reads EXCLUDE_OBJECT_DEFINE polygons. Without 'Label"
echo "    objects' enabled, the slicer doesn't emit them and LINE_PURGE"
echo "    falls back to a static purge at the bed origin."
echo ""
echo "    Creality Print 7.x: Process settings (left panel) -> use the"
echo "                        search box, type 'label' -> enable"
echo "                        'Label objects' (Others tab in 7.x)."
echo ""
echo "    Orca / OrcaSlicer:  Process tab -> Quality -> Advanced ->"
echo "                        enable 'Label objects' (or 'Use exclude_object')."
echo ""
echo "------------------------------------------------------------------"
echo " 3. Update your slicer's Machine Start G-code."
echo ""
echo "    Drop-in templates ship with this feature:"
echo "      slicer-templates/creality-print-machine-start.gcode (verified"
echo "                                                          on CP 7.1.1)"
echo "      slicer-templates/orca-machine-start.gcode (unverified — bed_type"
echo "                                                strings may differ)"
echo ""
echo "    Both replace the hardcoded purge with a single LINE_PURGE call"
echo "    and use a blocking M109 so the purge fires at full print temp."
echo ""
echo "    On the printer, the templates are at:"
echo "      ${SCRIPT_DIR}/slicer-templates/"
echo ""
echo "    Open the file you need, copy the contents, paste into:"
echo "      Slicer -> printer profile -> Machine G-code -> Machine start"
echo ""
echo "------------------------------------------------------------------"
echo " 4. Verify it took effect."
echo ""
echo "    Slice your test print, then before sending it to the printer:"
echo "      head -100 your-print.gcode | grep -E 'EXCLUDE_OBJECT_DEFINE|LINE_PURGE'"
echo ""
echo "    You should see:"
echo "      - EXCLUDE_OBJECT_DEFINE NAME=... POLYGON=...  (one per object)"
echo "      - LINE_PURGE  (in the start-print block)"
echo ""
echo "    If EXCLUDE_OBJECT_DEFINE is missing -> Label objects is OFF."
echo "    If LINE_PURGE is missing -> machine start gcode change didn't save."
echo ""
echo "------------------------------------------------------------------"
echo " 5. Tune (optional)."
echo ""
echo "    Defaults are in custom/kamp_settings.cfg. Common knobs:"
echo "      variable_purge_margin : mm in front of print bbox (default 10)"
echo "      variable_purge_amount : mm of filament purged    (default 25)"
echo "      variable_purge_height : Z height during purge    (default 0.4)"
echo ""
echo "    Override in custom/overrides.cfg to survive future re-installs."
echo ""
echo "------------------------------------------------------------------"
echo " See features/kamp-adaptive-purge/README.md for the full guide."
echo ""
