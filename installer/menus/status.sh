#!/bin/sh
# Status panel: shows what's installed and at what version.

show_status() {
    clear
    local fw=$(detect_printer_fw)
    local chw=$(detect_carto_hw)
    local cfw=$(detect_carto_fw)

    printf '\n=== K2 Plus installer status ===\n\n'
    printf '  Printer firmware    : %s\n' "$fw"
    printf '  Cartographer HW     : %s\n' "${chw:-unknown}"
    printf '  Cartographer FW     : %s\n' "${cfw:-unknown}"
    printf '  Cartographer offset : %s\n' "$(detect_carto_offset_label)"
    printf '\n--- Bootstrap ---\n'
    status_line 'Entware (opkg, git, curl)'  is_entware
    status_line 'better-root ($HOME → UDISK)' is_better_root
    status_line 'better-init (PATH/profile.d)' is_better_init
    printf '\n--- k2-improvements features ---\n'
    status_line 'cartographer'                is_cartographer
    status_line 'moonraker'                   is_moonraker
    status_line 'fluidd'                      is_fluidd
    status_line 'macros (start_print/m191/bed_mesh)' is_macros
    status_line 'screws_tilt_adjust'          is_screws_tilt
    status_line 'axis_twist_compensation'     is_axis_twist
    status_line 'abort_homing'                is_abort_homing
    status_line 'secure-auth'                 is_secure_auth
    status_line 'skip-setup'                  is_skip_setup
    status_line 'obico'                       is_obico
    printf '\n--- K2-Plus extras ---\n'
    status_line 'KAMP adaptive purge'         is_kamp
    status_line 'surface-selection wrapper'   is_surface_wrap
    status_line 'motor-state guard'           is_motor_guard
    status_line 'homing.py hasattr fix'       is_homing_hasattr
    status_line 'prtouch_v3 SAVE_CONFIG clean' is_prtouch_clean
    printf '\n'
    press_enter
}
