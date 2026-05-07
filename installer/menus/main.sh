#!/bin/sh
# Top-level menu loop. Sourced by menu.sh.

main_menu() {
    while :; do
        clear
        local fw=$(detect_printer_fw)
        local chw=$(detect_carto_hw)
        local extras_only="${K2_EXTRAS_ONLY:-0}"
        local extras_forced=0

        # Firmware-based safety gate: force extras-only mode on 1.1.3.13
        # regardless of how the menu was invoked. This fork's Cartographer
        # Klipper patches are rebased for 1.1.5.2 — running them against
        # stock 1.1.3.13 Klipper files would silently overwrite Creality's
        # 1.1.3.13 fixes and break Cartographer on the next Klipper restart.
        # Items 2 (Install essentials) and 3 (Features) are the dangerous
        # ones; we hide them by forcing extras-only.
        if [ "$fw" = "1.1.3.13" ] && [ "$extras_only" != "1" ]; then
            extras_only=1
            extras_forced=1
        fi

        if [ "$extras_only" = "1" ]; then
            printf '\n=== K2 Plus Installer (extras-only) ===  fw: %s  carto: %s\n\n' "$fw" "${chw:-unknown}"
            if [ "$extras_forced" = "1" ]; then
                printf '%s\n' "$(c_yellow '  Forced extras-only: detected firmware 1.1.3.13. This fork ships')"
                printf '%s\n' "$(c_yellow '  Klipper patches rebased for 1.1.5.2 only — Install-essentials and')"
                printf '%s\n' "$(c_yellow '  Features would overwrite working patches and break Cartographer.')"
                printf '%s\n' "$(c_yellow '  Use Jacob10383/k2-improvements for Cartographer install on 1.1.3.13.')"
            else
                printf '%s\n' "$(c_dim '  Mode: extras-only — Cartographer install is assumed to be already')"
                printf '%s\n' "$(c_dim '  in place (e.g. via Jacob10383). Install-essentials and Features')"
                printf '%s\n' "$(c_dim '  are hidden because they would overwrite Klipper patches.')"
            fi
            printf '\n'
            printf '  1. Status — show what is installed\n'
            printf '  4. Extras (K2-Plus patches) ▶\n'
            printf '  5. KAMP adaptive purge ▶\n'
            printf '  8. Update installer (git pull)\n'
            printf '  9. Exit\n\n'
            printf 'Choose: '
            read -r c
            case "$c" in
                1) show_status ;;
                4) menu_extras ;;
                5) menu_kamp ;;
                8) menu_update_installer ;;
                9|q|Q) exit 0 ;;
                2|3|6|7)
                    printf '\n  %s\n\n' "$(c_yellow 'Disabled in extras-only mode. Re-run bootstrap.sh without --extras-only for the full menu.')"
                    press_enter
                    ;;
                *) ;;
            esac
        else
            printf '\n=== K2 Plus Installer ===  fw: %s  carto: %s\n\n' "$fw" "${chw:-unknown}"
            printf '  1. Status — show what is installed\n'
            printf '  2. Install essentials (recommended)\n'
            printf '  3. Features (k2-improvements) ▶\n'
            printf '  4. Extras (K2-Plus patches) ▶\n'
            printf '  5. KAMP adaptive purge ▶\n'
            printf '  6. Cartographer firmware flash ▶  (UNTESTED)\n'
            printf '  7. Prepare USB stick (printer firmware swap) ▶  (UNTESTED)\n'
            printf '  8. Update installer (git pull)\n'
            printf '  9. Exit\n\n'
            printf 'Choose [1-9]: '
            read -r c
            case "$c" in
                1) show_status ;;
                2) menu_install_all ;;
                3) menu_features ;;
                4) menu_extras ;;
                5) menu_kamp ;;
                6) menu_carto_fw ;;
                7) menu_printer_fw ;;
                8) menu_update_installer ;;
                9|q|Q) exit 0 ;;
                *) ;;
            esac
        fi
    done
}

stub_menu() {
    clear
    printf '\n%s — not yet implemented.\n' "$1"
    printf 'Tracked in installer-v1 milestone.\n\n'
    press_enter
}

menu_update_installer()  {
    clear
    ensure_path
    if [ -d "$INSTALLER_DIR/.git" ]; then
        info "git pull in $INSTALLER_DIR"
        ( cd "$INSTALLER_DIR" && git pull --ff-only )
    else
        warn "$INSTALLER_DIR is not a git checkout — can't auto-update."
        warn "Re-run bootstrap.sh from the host to refresh."
    fi
    press_enter
}
