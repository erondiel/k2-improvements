#!/bin/sh
# Shared helpers for the K2 Plus installer. Sourced by menu.sh.

INSTALLER_DIR="${INSTALLER_DIR:-/mnt/UDISK/k2-improvements}"
PRINTER_CFG_DIR="${PRINTER_CFG_DIR:-/mnt/UDISK/printer_data/config}"
KLIPPER_DIR="${KLIPPER_DIR:-/usr/share/klipper}"

if command -v dialog >/dev/null 2>&1; then
    HAS_DIALOG=1
else
    HAS_DIALOG=0
fi

c_red()    { printf '\033[31m%s\033[0m' "$1"; }
c_green()  { printf '\033[32m%s\033[0m' "$1"; }
c_yellow() { printf '\033[33m%s\033[0m' "$1"; }
c_dim()    { printf '\033[2m%s\033[0m' "$1"; }

die()  { echo "ERROR: $*" >&2; exit 1; }
info() { echo "I: $*"; }
warn() { echo "W: $*" >&2; }

confirm() {
    printf '%s [y/N]: ' "$1"
    read -r ans
    case "$ans" in y|Y|yes|YES) return 0 ;; *) return 1 ;; esac
}

press_enter() { printf '\nPress Enter to continue...'; read -r _; }

require_root() {
    [ "$(id -u)" = "0" ] || die "must run as root"
}

ensure_path() {
    case ":$PATH:" in
        *:/opt/bin:*) ;;
        *) PATH="/opt/bin:/opt/sbin:$PATH"; export PATH ;;
    esac
}
