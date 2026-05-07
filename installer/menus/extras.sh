#!/bin/sh
# K2-Plus extras (patches not in upstream k2-improvements). Install only.

# name|detector|description|script_path|requires  (one per line; script_path
# relative to INSTALLER_DIR; requires is the name of a function that must
# return 0 for the extra to be installable — empty if no precondition).
_EXTRAS='prtouch-cleanup|is_prtouch_clean|Remove orphan [prtouch_v3] SAVE_CONFIG header|installer/extras/prtouch-cleanup/install.sh|
surface-selection-wrapper|is_surface_wrap|START_PRINT SURFACE= param loads matching scan/touch model|installer/extras/surface-selection-wrapper/install.sh|is_cartographer
cartographer-offset-setup|is_carto_offset_set|Cartographer probe X/Y offset (Jamin/JimmyV/custom)|installer/extras/cartographer-offset-setup/install.sh|is_cartographer
cartographer-macros|is_carto_macros|CARTO_* macro buttons for Fluidd (calibrate/load/touch home)|installer/extras/cartographer-macros/install.sh|is_cartographer
motor-state-guard|is_motor_guard|G28 crash-guard after klippy-only restart (UNTESTED)|features/motor-state-guard/install.sh|'

# Human-readable hint for the requires_function name. Add new entries here
# when new precondition functions are introduced.
_extras_requires_label() {
    case "$1" in
        is_cartographer) echo "needs Cartographer" ;;
        *)               echo "blocked: $1" ;;
    esac
}

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
            local req=$(printf  '%s' "$line" | cut -d'|' -f5)
            local mark hint=""
            if "$det" 2>/dev/null; then
                mark=$(c_green '[X]')
            elif [ -n "$req" ] && ! "$req" 2>/dev/null; then
                mark=$(c_yellow '[!]')
                hint=" $(c_yellow "($(_extras_requires_label "$req"))")"
            else
                mark=$(c_dim '[ ]')
            fi
            printf '  %2d. %s %-30s %s%s\n' "$n" "$mark" "$name" "$(c_dim "$desc")" "$hint"
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
    local req=$(printf  '%s' "$line" | cut -d'|' -f5)
    local script="$INSTALLER_DIR/$script_rel"
    local readme="$(dirname "$script")/README.md"

    clear
    printf '\n=== %s ===\n\n' "$name"

    # Precondition gate: refuse with a clean message if the extra requires
    # something that's not present (e.g. is_cartographer fails). The
    # install scripts have their own grep checks too — this is just the
    # friendlier UX layer that prevents the user from running the script
    # at all when the precondition is missing.
    if [ -n "$req" ] && ! "$req" 2>/dev/null; then
        printf '%s\n\n' "$(c_yellow "Cannot install: $(_extras_requires_label "$req")")"
        case "$req" in
            is_cartographer)
                printf '  This extra requires Cartographer to be installed first.\n'
                printf '  On a fresh K2 Plus, install Cartographer via:\n\n'
                printf '    - Menu item 2 (Install essentials)  — recommended path\n'
                printf '    - Menu item 3 (Features) -> cartographer\n'
                printf '    - Or Jacob10383'"'"'s gimme-the-jamin.sh on 1.1.3.13\n\n'
                printf '  Once Cartographer is installed and Klipper has restarted with the\n'
                printf '  new config, this extra will become available.\n\n'
                ;;
            *)
                printf '  Precondition function "%s" returned false.\n\n' "$req"
                ;;
        esac
        press_enter
        return 1
    fi

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
        motor-state-guard)
            printf '\n'
            printf '%s\n' "$(c_red '!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!')"
            printf '%s\n' "$(c_red '!!!  WARNING — UNTESTED FEATURE                              !!!')"
            printf '%s\n' "$(c_red '!!!                                                          !!!')"
            printf '%s\n' "$(c_red '!!!  Code looks correct but the detection mechanism (tmpfs   !!!')"
            printf '%s\n' "$(c_red '!!!  marker, delayed_gcode handshake, G28 wrap) has NOT      !!!')"
            printf '%s\n' "$(c_red '!!!  been verified end-to-end on a live K2 Plus.             !!!')"
            printf '%s\n' "$(c_red '!!!                                                          !!!')"
            printf '%s\n' "$(c_red '!!!  If the guard fails to engage you are in the same risk   !!!')"
            printf '%s\n' "$(c_red '!!!  position as without it: G28 after a klippy-only restart !!!')"
            printf '%s\n' "$(c_red '!!!  may invert Y and crash the toolhead into the back frame.!!!')"
            printf '%s\n' "$(c_red '!!!                                                          !!!')"
            printf '%s\n' "$(c_red '!!!  Install only if you understand and accept the risk.     !!!')"
            printf '%s\n' "$(c_red '!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!')"
            printf '\n'
            if "$det" 2>/dev/null; then
                printf '  Status: %s\n\n' "$(c_green 'ALREADY APPLIED')"
                if ! confirm "Re-run install.sh anyway?"; then return 0; fi
            else
                if ! confirm "Apply $name DESPITE the warning above?"; then return 0; fi
            fi
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
