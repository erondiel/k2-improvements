#!/bin/sh
# "Install all (recommended)" flow — installs every missing feature + extra
# + KAMP, in dependency order. Cartographer firmware flash is intentionally
# excluded (requires the user to put the probe in DFU mode physically).

# Order: bootstrap → core klipper features → web UIs → macros → extras → KAMP
_INSTALL_ALL_ORDER='entware|is_entware|features/entware/install.sh
better-root|is_better_root|features/better-root/install.sh
better-init|is_better_init|features/better-init/install.sh
cartographer|is_cartographer|features/cartographer/install.sh
prtouch-cleanup|is_prtouch_clean|installer/extras/prtouch-cleanup/install.sh
moonraker|is_moonraker|features/moonraker/install.sh
fluidd|is_fluidd|features/fluidd/install.sh
macros|is_macros|features/macros/install.sh
screws_tilt_adjust|is_screws_tilt|features/screws_tilt_adjust/install.sh
secure-auth|is_secure_auth|features/secure-auth/install.sh
axis_twist_compensation|is_axis_twist|features/axis_twist_compensation/install.sh
abort_homing|is_abort_homing|features/abort_homing/install.sh
skip-setup|is_skip_setup|features/skip-setup/install.sh
jimmyv-mount|is_jimmyv|installer/extras/jimmyv-mount/install.sh
surface-selection-wrapper|is_surface_wrap|installer/extras/surface-selection-wrapper/install.sh
motor-state-guard|is_motor_guard|features/motor-state-guard/install.sh
kamp-adaptive-purge|is_kamp|features/kamp-adaptive-purge/install.sh'

menu_install_all() {
    clear
    printf '\n=== Install all (recommended) ===\n\n'
    printf 'Walks the canonical install order, skipping anything already done.\n'
    printf 'Cartographer firmware flash and printer firmware swap are NOT in this\n'
    printf 'flow — those need physical interaction (DFU button, USB stick).\n\n'
    printf 'Plan:\n'
    local OLDIFS="$IFS"
    IFS='
'
    local n=0
    for line in $_INSTALL_ALL_ORDER; do
        n=$((n+1))
        local name=$(printf '%s' "$line" | cut -d'|' -f1)
        local det=$(printf  '%s' "$line" | cut -d'|' -f2)
        local mark
        if "$det" 2>/dev/null; then mark=$(c_green '[X]'); else mark=$(c_dim '[ ]'); fi
        printf '  %2d. %s %s\n' "$n" "$mark" "$name"
    done
    IFS="$OLDIFS"
    printf '\n'
    printf '%s\n' "$(c_yellow 'WARNING: this can take 5-15 minutes and will modify Klipper.')"
    printf '         Make sure no print is active.\n\n'

    if ! confirm "Proceed with install all?"; then return 0; fi

    local installed=0 skipped=0 failed=0
    OLDIFS="$IFS"
    IFS='
'
    for line in $_INSTALL_ALL_ORDER; do
        local name=$(printf '%s' "$line" | cut -d'|' -f1)
        local det=$(printf  '%s' "$line" | cut -d'|' -f2)
        local script_rel=$(printf '%s' "$line" | cut -d'|' -f3)
        local script="$INSTALLER_DIR/$script_rel"

        printf '\n--- %s ---\n' "$name"

        if "$det" 2>/dev/null; then
            info "already installed — skipping"
            skipped=$((skipped+1))
            continue
        fi
        if [ ! -f "$script" ]; then
            warn "missing $script — skipping"
            failed=$((failed+1))
            continue
        fi
        if sh "$script"; then
            installed=$((installed+1))
        else
            warn "$name install.sh failed (continuing)"
            failed=$((failed+1))
        fi
    done
    IFS="$OLDIFS"

    printf '\n%s\n' '----------------------------------------------------------------'
    printf 'Install-all summary: %s installed, %s skipped, %s failed\n' \
        "$(c_green "$installed")" "$skipped" "$(c_red "$failed")"
    printf '%s\n\n' '----------------------------------------------------------------'
    printf 'Next steps:\n'
    printf '  1. Restart Klipper (FIRMWARE_RESTART) — but ONLY if no print is active.\n'
    printf '  2. Power-cycle from the mains before the next G28 (motor-state caveat).\n'
    printf '  3. If you use Cartographer probe firmware: menu item 6 (manual flash).\n\n'
    press_enter
}
