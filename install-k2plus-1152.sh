#!/bin/sh
# install-k2plus-1152.sh
#
# Automated installer for the firmware-1.1.5.2-compat branch of
# erondiel/k2-improvements on a stock Creality K2 Plus running firmware 1.1.5.2.
#
# Wraps the upstream feature scripts and works around six undocumented gotchas
# (entware/profile.d ordering, better-root link_up bugs, $HOME-path mismatch,
# missing PATH for Entware tools, orphan SAVE_CONFIG block).
#
# Usage (on the printer, as root, after copying this repo to any path):
#
#   cd /tmp/k2-improvements   # or wherever you placed the repo
#   sh install-k2plus-1152.sh
#
# Idempotent — safe to re-run; steps that have already completed are skipped.
# Does NOT restart Klipper. After the script finishes, power-cycle the printer
# at the mains, then continue with manual cartographer calibration in Fluidd.

set -e

SCRIPT_DIR=$(readlink -f "$(dirname "$0")")
TARGET="/mnt/UDISK/root/k2-improvements"
PRINTER_CFG="/mnt/UDISK/printer_data/config/printer.cfg"

LOG()  { printf '\033[1;36m[k2-install]\033[0m %s\n' "$*"; }
WARN() { printf '\033[1;33m[k2-install WARN]\033[0m %s\n' "$*" >&2; }
ERR()  { printf '\033[1;31m[k2-install ERROR]\033[0m %s\n' "$*" >&2; }

trap 'ERR "failed at line $LINENO"; exit 1' EXIT
ok() { trap - EXIT; }

LOG "K2 Plus k2-improvements 1.1.5.2 installer"

# ---------------------------------------------------------------------------
# Pre-flight
# ---------------------------------------------------------------------------
[ "$(id -u)" -eq 0 ] || { ERR "must run as root"; exit 1; }
[ -d /mnt/UDISK ]    || { ERR "/mnt/UDISK is not mounted — is this a K2 Plus?"; exit 1; }
[ -d "$SCRIPT_DIR/features" ] && [ -f "$SCRIPT_DIR/gimme-the-jamin.sh" ] \
    || { ERR "must be run from the k2-improvements repo root (no features/ or gimme-the-jamin.sh found in $SCRIPT_DIR)"; exit 1; }
[ -d /usr/share/klipper ] && [ -d /usr/share/klippy-env ] \
    || { ERR "klipper or klippy-env missing under /usr/share — wrong machine or stripped firmware"; exit 1; }

# ---------------------------------------------------------------------------
# Step 1/6 — defensive /etc/profile.d
# Stock 1.1.5.2 does not ship /etc/profile.d. Entware creates it; this is a
# belt-and-braces in case feature scripts reach for it before entware finishes.
# ---------------------------------------------------------------------------
LOG "step 1/6 — ensuring /etc/profile.d/ exists"
mkdir -p /etc/profile.d

# ---------------------------------------------------------------------------
# Step 2/6 — Entware (gives us git, curl, jq, unzip in /opt/bin)
# ---------------------------------------------------------------------------
if [ -x /opt/bin/opkg ] && [ -x /opt/bin/git ]; then
    LOG "step 2/6 — Entware already installed, skipping"
else
    LOG "step 2/6 — bootstrapping Entware (downloads opkg + git/curl/jq/unzip)"
    sh "$SCRIPT_DIR/features/entware/install.sh"
fi

# ---------------------------------------------------------------------------
# Step 3/6 — better-root: move_homedir + idempotent symlinks
# We DO NOT call features/better-root/install.sh directly because:
#   - its link_up() uses non-idempotent `ln -s` (fails on re-run)
#   - it kills SSH at the end (breaks any non-interactive runner)
# Inline only the safe slice (move_homedir) and create the symlinks ourselves.
# Skip the moonraker symlinks here — gimme-the-jamin's moonraker feature
# creates them when it installs.
# ---------------------------------------------------------------------------
if grep -qE 'root.*UDISK' /etc/passwd; then
    LOG "step 3/6 — root home already on UDISK, skipping move_homedir"
else
    LOG "step 3/6 — moving /root → /mnt/UDISK/root (better-root move_homedir slice)"
    mkdir -p /mnt/UDISK/root
    rsync --remove-source-files -a /root/ /mnt/UDISK/root/
    rm -fr /overlay/upper/root/* 2>/dev/null || true
    sed -i 's,/root,/mnt/UDISK/root,' /etc/passwd
    sync
fi

LOG "step 3/6 — creating root symlinks (idempotent)"
ln -sfn /usr/share/klipper      /mnt/UDISK/root/klipper
ln -sfn /usr/share/klippy-env   /mnt/UDISK/root/klippy-env
ln -sfn /mnt/UDISK/printer_data /mnt/UDISK/root/printer_data

# ---------------------------------------------------------------------------
# Step 4/6 — Place fork at /mnt/UDISK/root/k2-improvements
# Feature install scripts reference $HOME/k2-improvements after move_homedir.
# If the script was started from somewhere else (e.g. /tmp), rsync ourselves
# to the canonical location. Re-runs from the canonical location no-op.
# ---------------------------------------------------------------------------
if [ "$SCRIPT_DIR" = "$TARGET" ]; then
    LOG "step 4/6 — already running from $TARGET, skipping fork relocation"
else
    LOG "step 4/6 — relocating fork to $TARGET"
    mkdir -p "$TARGET"
    rsync -a --delete \
        --exclude='.git/' --exclude='*.pyc' --exclude='__pycache__/' \
        "$SCRIPT_DIR/" "$TARGET/"
fi

# ---------------------------------------------------------------------------
# Step 5/6 — gimme-the-jamin.sh with the PATH that feature scripts need
# Without this PATH, cartographer/install.sh's `git clone` fails because
# Entware's git is in /opt/bin which isn't on stock K2 Plus PATH.
# ---------------------------------------------------------------------------
LOG "step 5/6 — running gimme-the-jamin.sh (this can take several minutes)"
cd "$TARGET"
PATH=/opt/bin:/opt/sbin:/mnt/UDISK/bin:$PATH sh ./gimme-the-jamin.sh

# ---------------------------------------------------------------------------
# Step 6/6 — strip orphan SAVE_CONFIG [prtouch_v3] block
# alter_config.py removes the active [prtouch_v3] section but leaves a stale
# `#*# [prtouch_v3]` header in the SAVE_CONFIG block, which Klipper still
# tries to load — error: "Option 'step_swap_pin' in section 'prtouch_v3'".
# ---------------------------------------------------------------------------
if [ -f "$PRINTER_CFG" ] && grep -q '^#\*# \[prtouch_v3\]$' "$PRINTER_CFG"; then
    LOG "step 6/6 — stripping orphan #*# [prtouch_v3] block from printer.cfg"
    sed -i '/^#\*# \[prtouch_v3\]$/d' "$PRINTER_CFG"
else
    LOG "step 6/6 — no orphan #*# [prtouch_v3] block found, skipping"
fi

ok
LOG ""
LOG "================================================================"
LOG " install complete"
LOG "================================================================"
LOG ""
LOG "NEXT STEPS — user action required:"
LOG ""
LOG " 1. POWER-CYCLE the printer at the mains."
LOG "    Do NOT use \`/etc/init.d/klipper restart\` or FIRMWARE_RESTART —"
LOG "    the K2 Plus motor-stall state machine does not reinitialize"
LOG "    cleanly on a Klipper-only restart. The next G28 has crashed"
LOG "    the toolhead into the back frame in the past."
LOG ""
LOG " 2. After power-up, open Fluidd at http://<printer-ip>/"
LOG "    System tab should show the cartographer MCU connected."
LOG ""
LOG " 3. In Fluidd console, calibrate the Cartographer probe:"
LOG "       CARTOGRAPHER_CALIBRATE METHOD=manual"
LOG "    (Follow paper-touch prompts; saves [cartographer scan_model default]"
LOG "     and [cartographer touch_model default] to printer.cfg.)"
LOG ""
LOG " 4. Generate the bed mesh:"
LOG "       BED_MESH_CALIBRATE"
LOG "       SAVE_CONFIG"
LOG "    (Klipper will restart — power-cycle again per step 1's caveat"
LOG "     before running the next G28.)"
LOG ""
LOG " 5. (Multi-surface setups, e.g. PEI + coolplate)"
LOG "    Re-run #3+#4 with NAME=<surface> for each plate, then configure"
LOG "    your slicer to pass SURFACE=<name> in the START_PRINT call."
LOG "    See README.md \"Surface selection wrapper\" for details."
LOG ""
