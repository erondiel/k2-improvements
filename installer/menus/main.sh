#!/bin/sh
# Top-level menu loop. Sourced by menu.sh.

main_menu() {
    while :; do
        clear
        local fw=$(detect_printer_fw)
        local chw=$(detect_carto_hw)
        printf '\n=== K2 Plus Installer ===  fw: %s  carto: %s\n\n' "$fw" "${chw:-unknown}"
        printf '  1. Status — show what is installed\n'
        printf '  2. Install all (recommended)\n'
        printf '  3. Features (k2-improvements) ▶\n'
        printf '  4. Extras (K2-Plus patches) ▶\n'
        printf '  5. KAMP adaptive purge ▶\n'
        printf '  6. Cartographer firmware flash ▶\n'
        printf '  7. Prepare USB stick (printer firmware swap) ▶\n'
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
    done
}

stub_menu() {
    clear
    printf '\n%s — not yet implemented.\n' "$1"
    printf 'Tracked in installer-v1 milestone.\n\n'
    press_enter
}

menu_install_all()       { stub_menu "Install all"; }
menu_features()          { stub_menu "Features"; }
menu_extras()            { stub_menu "Extras"; }
menu_kamp()              { stub_menu "KAMP"; }
menu_carto_fw()          { stub_menu "Cartographer firmware flash"; }
menu_printer_fw()        { stub_menu "USB-stick firmware prep"; }
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
