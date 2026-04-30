#!/bin/sh
# KAMP adaptive purge sub-menu.

menu_kamp() {
    while :; do
        clear
        printf '\n=== KAMP adaptive purge ===\n\n'
        local mark
        if is_kamp; then mark=$(c_green '[X] INSTALLED'); else mark=$(c_dim '[ ] not installed'); fi
        printf '  Status: %s\n\n' "$mark"
        printf '  1. Show README\n'
        printf '  2. Install / re-install\n'
        printf '  3. Edit kamp_settings.cfg (purge_height / purge_margin / etc.)\n'
        printf '  b. Back\n\n'
        printf 'Choose: '
        read -r c
        case "$c" in
            1) kamp_show_readme ;;
            2) kamp_install ;;
            3) kamp_tune ;;
            b|B|q|Q) return ;;
            *) ;;
        esac
    done
}

kamp_show_readme() {
    local readme="$INSTALLER_DIR/features/kamp-adaptive-purge/README.md"
    show_feature_readme "kamp-adaptive-purge" "$readme"
    press_enter
}

kamp_install() {
    local script="$INSTALLER_DIR/features/kamp-adaptive-purge/install.sh"
    clear
    printf '\n=== Install KAMP adaptive purge ===\n\n'
    if [ ! -f "$script" ]; then
        warn "install script not found: $script"
        press_enter
        return
    fi
    if is_kamp; then
        printf '  Status: %s\n\n' "$(c_green 'ALREADY INSTALLED')"
        if ! confirm "Re-run install (refreshes KAMP repo, re-symlinks)?"; then return; fi
    else
        if ! confirm "Install KAMP now?"; then return; fi
    fi
    pwd_home=$(awk -F: '$1=="root"{print $6}' /etc/passwd)
    info "running KAMP install (HOME=$pwd_home)"
    HOME="$pwd_home" PATH="/opt/bin:/opt/sbin:$PATH" sh "$script" || warn "install.sh exited non-zero"
    printf '\n%s\n' "$(c_yellow 'Reminder: edit Creality Print machine start gcode to call LINE_PURGE.')"
    printf '         See README for the exact replacement.\n\n'
    press_enter
}

kamp_tune() {
    local cfg="${PRINTER_CFG_DIR}/custom/kamp_settings.cfg"
    clear
    printf '\n=== Tune KAMP settings ===\n\n'
    if [ ! -f "$cfg" ]; then
        warn "$cfg not found — install KAMP first"
        press_enter
        return
    fi
    printf 'Editing: %s\n\n' "$cfg"
    printf 'Common tuning:\n'
    printf '  variable_purge_height : Z position during purge (default 0.4)\n'
    printf '  variable_purge_margin : mm in front of print bbox (default 10)\n'
    printf '  variable_purge_amount : mm of filament purged (default 25)\n'
    printf '  variable_flow_rate    : mm³/s during purge (default 12)\n\n'
    if ! confirm "Open in vi?"; then return; fi
    if command -v vi >/dev/null 2>&1; then
        vi "$cfg"
    else
        warn "no editor available — edit manually: $cfg"
    fi
}
