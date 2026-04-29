#!/bin/sh
# K2-Plus extras (patches not in upstream k2-improvements). Install only.

# name|detector|description|script_path  (one per line, script_path relative to INSTALLER_DIR)
_EXTRAS='motor-state-guard|is_motor_guard|Block G28 after Klipper-only restart (Y-axis crash guard)|features/motor-state-guard/install.sh
prtouch-cleanup|is_prtouch_clean|Remove orphan [prtouch_v3] SAVE_CONFIG header|installer/extras/prtouch-cleanup/install.sh
surface-selection-wrapper|is_surface_wrap|START_PRINT SURFACE= param loads matching scan/touch model|installer/extras/surface-selection-wrapper/install.sh
cartographer-offset-setup|is_carto_offset_set|Cartographer probe X/Y offset (Jamin/JimmyV/custom)|installer/extras/cartographer-offset-setup/install.sh'

menu_extras() {
    while :; do
        clear
        printf '\n=== K2-Plus extras ===\n\n'
        local n=0
        local OLDIFS="$IFS"
        IFS='
'
        for line in $_EXTRAS; do
            n=$((n+1))
            local name=$(printf '%s' "$line" | cut -d'|' -f1)
            local det=$(printf  '%s' "$line" | cut -d'|' -f2)
            local desc=$(printf '%s' "$line" | cut -d'|' -f3)
            local mark
            if "$det" 2>/dev/null; then mark=$(c_green '[X]'); else mark=$(c_dim '[ ]'); fi
            printf '  %2d. %s %-30s %s\n' "$n" "$mark" "$name" "$(c_dim "$desc")"
        done
        IFS="$OLDIFS"
        printf '\n   b. Back\n\n'
        printf 'Choose: '
        read -r c
        case "$c" in
            b|B|q|Q) return ;;
            ''|*[!0-9]*) ;;
            *)
                local picked=$(printf '%s' "$_EXTRAS" | sed -n "${c}p")
                [ -n "$picked" ] && install_extra "$picked"
                ;;
        esac
    done
}

install_extra() {
    local line="$1"
    local name=$(printf '%s' "$line" | cut -d'|' -f1)
    local det=$(printf  '%s' "$line" | cut -d'|' -f2)
    local script_rel=$(printf '%s' "$line" | cut -d'|' -f4)
    local script="$INSTALLER_DIR/$script_rel"
    local readme="$(dirname "$script")/README.md"

    clear
    printf '\n=== %s ===\n\n' "$name"

    if [ ! -f "$script" ]; then
        warn "install script not found: $script"
        warn "(this extra is not yet implemented in v1)"
        press_enter
        return 1
    fi

    show_feature_readme "$name" "$readme"

    case "$name" in
        cartographer-offset-setup)
            local label=$(detect_carto_offset_label)
            printf '  Currently configured: %s\n\n' "$(c_green "$label")"
            if ! confirm "Open the offset picker?"; then return 0; fi
            ;;
        *)
            if "$det" 2>/dev/null; then
                printf '  Status: %s\n\n' "$(c_green 'ALREADY APPLIED')"
                if ! confirm "Re-run install.sh anyway?"; then return 0; fi
            else
                if ! confirm "Apply $name now?"; then return 0; fi
            fi
            ;;
    esac

    info "running $script"
    if sh "$script"; then
        info "$name install completed"
    else
        warn "$name install.sh exited non-zero"
    fi
    press_enter
}
