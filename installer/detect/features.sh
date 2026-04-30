#!/bin/sh
# Per-feature install detection. Each function returns 0 if installed, 1 if not.

is_entware()       { [ -x /opt/bin/opkg ]; }
is_better_root()   { grep -q '^root:.*:/mnt/UDISK/root:' /etc/passwd 2>/dev/null; }
is_cartographer()  { [ -f "$PRINTER_CFG_DIR/custom/cartographer.cfg" ] || \
                     grep -q '^\[cartographer\]' "$PRINTER_CFG_DIR/printer.cfg" 2>/dev/null; }
is_moonraker()     { [ -d /mnt/UDISK/printer_data/moonraker ] || [ -f /mnt/UDISK/printer_data/config/moonraker.conf ]; }
is_fluidd()        { [ -f /usr/share/fluidd/index.html ] || [ -d /mnt/UDISK/fluidd ]; }
is_macros()        { [ -L "$PRINTER_CFG_DIR/custom/start_print.cfg" ]; }
is_kamp()          { [ -L "$PRINTER_CFG_DIR/custom/Line_Purge.cfg" ]; }
is_screws_tilt()   { [ -L "$PRINTER_CFG_DIR/custom/screws_tilt_adjust.cfg" ]; }
is_obico()         { [ -d /mnt/UDISK/moonraker-obico ]; }
is_secure_auth()   { grep -q '^trusted_clients' /mnt/UDISK/printer_data/config/moonraker.conf 2>/dev/null && \
                     ! grep -q '127\.0\.0\.0/8' /mnt/UDISK/printer_data/config/moonraker.conf 2>/dev/null; }
is_skip_setup()    { [ -f /mnt/UDISK/.skip_setup_done ]; }
is_axis_twist()    { grep -q '^\[axis_twist_compensation\]' "$PRINTER_CFG_DIR/printer.cfg" 2>/dev/null; }
is_abort_homing()  { grep -q 'ABORT_HOMING' "$KLIPPER_DIR/klippy/extras/homing.py" 2>/dev/null; }
is_better_init()   { [ -f /etc/profile.d/better-init.sh ]; }

is_surface_wrap()  { grep -q 'surface-selection wrapper' "$PRINTER_CFG_DIR/custom/start_print.cfg" 2>/dev/null; }
is_carto_macros()  { [ -L "$PRINTER_CFG_DIR/custom/cartographer_macros.cfg" ] || \
                     [ -f "$PRINTER_CFG_DIR/custom/cartographer_macros.cfg" ]; }
is_carto_offset_set() { is_cartographer; }  # always "set" if cartographer is installed (some value is always there)
is_motor_guard()   { grep -q 'motor-state-guard' "$PRINTER_CFG_DIR/custom/start_print.cfg" 2>/dev/null; }

# Returns a human label for the currently-installed cartographer offset preset.
# Echoes one of: "Jamin", "JimmyV", "custom (x=N y=N)", "(no cartographer)"
detect_carto_offset_label() {
    local cfg="$PRINTER_CFG_DIR/custom/cartographer.cfg"
    [ -f "$cfg" ] || { echo "(no cartographer)"; return; }
    local x=$(awk '/^\[cartographer\]/{f=1; next} f && /^\[/ {f=0} f && /^x_offset:/ {print $2; exit}' "$cfg")
    local y=$(awk '/^\[cartographer\]/{f=1; next} f && /^\[/ {f=0} f && /^y_offset:/ {print $2; exit}' "$cfg")
    case "${x:-?} ${y:-?}" in
        "0 -15") echo "Jamin (x=0 y=-15)" ;;
        "0 36")  echo "JimmyV (x=0 y=36)" ;;
        *)       echo "custom (x=${x:-?} y=${y:-?})" ;;
    esac
}
is_homing_hasattr() { grep -q "hasattr.*get_suspended_det_status" "$KLIPPER_DIR/klippy/extras/homing.py" 2>/dev/null; }
is_prtouch_clean() { ! grep -q '^#\*# \[prtouch_v3\]$' "$PRINTER_CFG_DIR/printer.cfg" 2>/dev/null; }

# Pretty-print a feature's status. Args: label, detector_function_name
status_line() {
    local label="$1"
    local fn="$2"
    if "$fn"; then
        printf '  %s %s\n' "$(c_green '[X]')" "$label"
    else
        printf '  %s %s\n' "$(c_dim '[ ]')" "$label"
    fi
}
