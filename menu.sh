#!/bin/sh
# K2 Plus installer — TUI entry point. Run this on the printer.

set -u

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
INSTALLER_DIR="$SCRIPT_DIR"
export INSTALLER_DIR

# Path-based safeguard for extras-only mode. The bootstrap clones to
# /mnt/UDISK/k2-improvements-extras/ when --extras-only is passed and
# launches with K2_EXTRAS_ONLY=1, but if the user re-enters the menu
# later by typing `sh /mnt/UDISK/k2-improvements-extras/menu.sh`
# without the env var, default to extras-only mode anyway based on
# the install directory name. The full installer at
# /mnt/UDISK/k2-improvements/ is unaffected.
case "$SCRIPT_DIR" in
    *-extras|*-extras/*)
        K2_EXTRAS_ONLY=1
        export K2_EXTRAS_ONLY
        ;;
esac

. "$SCRIPT_DIR/installer/lib/common.sh"
. "$SCRIPT_DIR/installer/detect/printer_fw.sh"
. "$SCRIPT_DIR/installer/detect/cartographer.sh"
. "$SCRIPT_DIR/installer/detect/features.sh"
. "$SCRIPT_DIR/installer/menus/status.sh"
. "$SCRIPT_DIR/installer/menus/features.sh"
. "$SCRIPT_DIR/installer/menus/extras.sh"
. "$SCRIPT_DIR/installer/menus/kamp.sh"
. "$SCRIPT_DIR/installer/menus/install_all.sh"
. "$SCRIPT_DIR/installer/menus/carto_fw.sh"
. "$SCRIPT_DIR/installer/menus/printer_fw.sh"
. "$SCRIPT_DIR/installer/menus/main.sh"

require_root
ensure_path
main_menu
