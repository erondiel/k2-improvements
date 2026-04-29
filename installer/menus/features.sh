#!/bin/sh
# k2-improvements feature install sub-menu. Install only — uninstall is v2.

# name|detector|description (one per line)
_FEATURES='abort_homing|is_abort_homing|Abort homing on M112/cancel
axis_twist_compensation|is_axis_twist|Compensate Z drift across X
better-init|is_better_init|/etc/profile.d autoloader
better-root|is_better_root|$HOME → /mnt/UDISK/root (more space)
cartographer|is_cartographer|Cartographer probe + Klipper patches
entware|is_entware|opkg toolchain (git/curl/dialog)
fluidd|is_fluidd|Web UI (alternative to Mainsail)
macros|is_macros|START_PRINT / M191 / bed_mesh macros
moonraker|is_moonraker|Klipper API server (replaces Creality)
obico|is_obico|Cloud failure detection
screws_tilt_adjust|is_screws_tilt|Manual bed-screws assist
secure-auth|is_secure_auth|Lock down moonraker trusted_clients
skip-setup|is_skip_setup|Skip first-run wizard'

# Canonical install order (deps first). Used by install_all_missing.
_FEATURES_ORDER='entware better-root better-init cartographer moonraker fluidd macros screws_tilt_adjust secure-auth axis_twist_compensation abort_homing skip-setup obico'

menu_features() {
    while :; do
        clear
        printf '\n=== k2-improvements features ===\n\n'
        local n=0
        local OLDIFS="$IFS"
        IFS='
'
        for line in $_FEATURES; do
            n=$((n+1))
            local name=$(printf '%s' "$line" | cut -d'|' -f1)
            local det=$(printf '%s'  "$line" | cut -d'|' -f2)
            local desc=$(printf '%s' "$line" | cut -d'|' -f3)
            local mark
            if "$det"; then mark=$(c_green '[X]'); else mark=$(c_dim '[ ]'); fi
            printf '  %2d. %s %-25s %s\n' "$n" "$mark" "$name" "$(c_dim "$desc")"
        done
        IFS="$OLDIFS"
        printf '\n   i. Install all NOT-installed (in dep order)\n'
        printf '   b. Back\n\n'
        printf 'Choose: '
        read -r c
        case "$c" in
            b|B|q|Q) return ;;
            i|I) install_all_missing ;;
            ''|*[!0-9]*) ;;
            *)
                local picked=$(printf '%s' "$_FEATURES" | sed -n "${c}p" | cut -d'|' -f1)
                [ -n "$picked" ] && install_feature "$picked"
                ;;
        esac
    done
}

# Run a feature's install.sh from the upstream k2-improvements layout
install_feature() {
    local name="$1"
    local script="$INSTALLER_DIR/features/$name/install.sh"
    local readme="$INSTALLER_DIR/features/$name/README.md"

    clear
    printf '\n=== %s ===\n\n' "$name"

    if [ ! -f "$script" ]; then
        warn "feature script not found: $script"
        warn "(installer must live at $INSTALLER_DIR — check your bootstrap)"
        press_enter
        return 1
    fi

    show_feature_readme "$name" "$readme"

    local det=$(printf '%s' "$_FEATURES" | grep "^$name|" | cut -d'|' -f2)
    if [ -n "$det" ] && "$det"; then
        printf '  Status: %s\n\n' "$(c_green 'ALREADY INSTALLED')"
        if ! confirm "Re-run install.sh anyway?"; then return 0; fi
    else
        if ! confirm "Install $name now?"; then return 0; fi
    fi

    info "running $script"
    if sh "$script"; then
        info "$name install completed"
    else
        warn "$name install.sh exited non-zero"
    fi
    press_enter
}

# Print a feature's README inline. User scrolls back in their terminal if needed.
show_feature_readme() {
    local name="$1"
    local readme="$2"

    if [ ! -f "$readme" ]; then
        local desc=$(printf '%s' "$_FEATURES" | grep "^$name|" | cut -d'|' -f3)
        printf '(no README.md ships with this feature)\n'
        [ -n "$desc" ] && printf 'Short description: %s\n' "$desc"
        printf '\n'
        return
    fi

    printf '%s\n' '----------------------------------------------------------------'
    printf 'README: %s\n' "$name"
    printf '%s\n\n' '----------------------------------------------------------------'
    cat "$readme"
    printf '\n%s\n\n' '----------------------------------------------------------------'
}

# Install all features not yet installed, in canonical dep order
install_all_missing() {
    clear
    printf '\n=== Install all NOT-installed features ===\n\n'
    printf 'Order: %s\n\n' "$_FEATURES_ORDER"
    if ! confirm "Proceed? Each feature's own install.sh runs in turn"; then return; fi

    local skipped=0 installed=0 failed=0
    for name in $_FEATURES_ORDER; do
        local det=$(printf '%s' "$_FEATURES" | grep "^$name|" | cut -d'|' -f2)
        [ -z "$det" ] && continue

        printf '\n--- %s ---\n' "$name"
        if "$det"; then
            info "already installed — skipping"
            skipped=$((skipped+1))
            continue
        fi

        local script="$INSTALLER_DIR/features/$name/install.sh"
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

    printf '\n=== Summary: %d installed, %d skipped, %d failed ===\n\n' \
        "$installed" "$skipped" "$failed"
    press_enter
}
