#!/bin/sh
# install-k2plus-1152.sh
#
# Automated installer for the firmware-1.1.5.2-compat branch of
# erondiel/k2-improvements on a stock Creality K2 Plus running firmware 1.1.5.2.
#
# Orchestrates the upstream feature scripts in the right order. The branch
# already carries the bug fixes that previously needed in-script workarounds
# (mkdir profile.d, idempotent better-root, gimme-the-jamin PATH, orphan
# SAVE_CONFIG strip), so this installer just composes them.
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

LOG() { printf '\033[1;36m[k2-install]\033[0m %s\n' "$*"; }
ERR() { printf '\033[1;31m[k2-install ERROR]\033[0m %s\n' "$*" >&2; }

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
# Step 1/4 — Entware (gives us git, curl, jq, unzip in /opt/bin)
# ---------------------------------------------------------------------------
if [ -x /opt/bin/opkg ] && [ -x /opt/bin/git ]; then
    LOG "step 1/4 — Entware already installed, skipping"
else
    LOG "step 1/4 — bootstrapping Entware (downloads opkg + git/curl/jq/unzip)"
    sh "$SCRIPT_DIR/features/entware/install.sh"
fi

# ---------------------------------------------------------------------------
# Step 2/4 — better-root: move_homedir + idempotent symlinks
# Calling the upstream script directly works now that link_up() is idempotent
# (uses ln -sfn) and the SSH-kill is gated on TTY (so non-interactive runs
# don't take down the parent shell).
# ---------------------------------------------------------------------------
if grep -qE 'root.*UDISK' /etc/passwd; then
    LOG "step 2/4 — root home already on UDISK, skipping better-root"
else
    LOG "step 2/4 — running features/better-root/install.sh (move /root → /mnt/UDISK/root)"
    sh "$SCRIPT_DIR/features/better-root/install.sh"
fi

# ---------------------------------------------------------------------------
# Step 3/4 — Place fork at /mnt/UDISK/root/k2-improvements
# Feature install scripts reference $HOME/k2-improvements after move_homedir.
# If the script was started from somewhere else (e.g. /tmp), rsync ourselves
# to the canonical location. Re-runs from the canonical location no-op.
# ---------------------------------------------------------------------------
if [ "$SCRIPT_DIR" = "$TARGET" ]; then
    LOG "step 3/4 — already running from $TARGET, skipping fork relocation"
else
    LOG "step 3/4 — relocating fork to $TARGET"
    mkdir -p "$TARGET"
    rsync -a --delete \
        --exclude='.git/' --exclude='*.pyc' --exclude='__pycache__/' \
        "$SCRIPT_DIR/" "$TARGET/"
fi

# ---------------------------------------------------------------------------
# Step 4/4 — gimme-the-jamin.sh
# The script now exports its own PATH, so feature scripts find Entware tools
# without our wrapper. cartographer/install.sh strips the orphan SAVE_CONFIG
# [prtouch_v3] header itself.
# ---------------------------------------------------------------------------
LOG "step 4/4 — running gimme-the-jamin.sh (this can take several minutes)"
cd "$TARGET"
sh ./gimme-the-jamin.sh

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
