#!/bin/sh
# K2 Plus installer — TUI entry point. Run this on the printer.

set -u

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
INSTALLER_DIR="$SCRIPT_DIR"
export INSTALLER_DIR

. "$SCRIPT_DIR/installer/lib/common.sh"
. "$SCRIPT_DIR/installer/detect/printer_fw.sh"
. "$SCRIPT_DIR/installer/detect/cartographer.sh"
. "$SCRIPT_DIR/installer/detect/features.sh"
. "$SCRIPT_DIR/installer/menus/status.sh"
. "$SCRIPT_DIR/installer/menus/features.sh"
. "$SCRIPT_DIR/installer/menus/extras.sh"
. "$SCRIPT_DIR/installer/menus/kamp.sh"
. "$SCRIPT_DIR/installer/menus/install_all.sh"
. "$SCRIPT_DIR/installer/menus/main.sh"

require_root
ensure_path
main_menu
