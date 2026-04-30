#!/bin/sh
# Cartographer probe firmware flash sub-menu.
#
# Dispatches to the upstream flash.py (features/cartographer/firmware/flash.py),
# which already does V3/V4 hardware detection, build selection (full/lite/V3),
# DFU mode handling, progress bars, and verification. This menu just shows
# DFU instructions, the K2 Plus motor-state reminder, and launches it.
#
# Excluded from "Install all" — the user must physically put the probe in
# DFU mode before this can succeed.

menu_carto_fw() {
    while :; do
        clear
        local hw=$(detect_carto_hw)
        local cur=$(detect_carto_fw)

        printf '\n=== Cartographer firmware flash ===\n\n'
        printf '  Detected hardware : %s\n' "${hw:-unknown}"
        printf '  Current firmware  : %s\n\n' "${cur:-unknown}"

        printf '%s\n' "$(c_red '!!  UNTESTED — physical access to the probe DFU button required.  !!')"
        printf '%s\n' "$(c_red '!!  Code is written but never run end-to-end. If you flash and    !!')"
        printf '%s\n' "$(c_red '!!  hit issues, please open an issue on github with the output.   !!')"
        printf '\n'
        printf '%s\n' "$(c_dim 'Flashing uses the upstream flash.py tool — auto-detects V3/V4,')"
        printf '%s\n\n' "$(c_dim 'shows its own build picker (full/lite for V4, USB/K1-USB for V3).')"

        printf '  1. Show DFU/bootloader instructions\n'
        printf '  2. Launch flash.py (probe must be in DFU mode)\n'
        printf '  b. Back\n\n'
        printf 'Choose: '
        read -r c
        case "$c" in
            1) carto_fw_show_instructions ;;
            2) carto_fw_launch ;;
            b|B|q|Q) return ;;
            *) ;;
        esac
    done
}

carto_fw_show_instructions() {
    clear
    cat <<'EOF'

=== How to flash the Cartographer probe firmware ===

1. Make sure no print is active. Klipper should be idle.

2. Look at the Cartographer probe. There is a small button labeled BOOT
   or DFU on the side of the PCB.

3. Press AND HOLD the BOOT/DFU button while the printer is powered.

4. While holding the button, briefly press the printer's main power
   switch off and back on (or unplug-replug the USB cable from the
   Cartographer if it has its own USB).

5. Release the BOOT/DFU button. The probe is now in bootloader mode.

6. Come back to this menu and pick "Launch flash.py" — flash.py will
   detect the probe, present a build picker, and flash. The flash
   usually takes 5-15 seconds.

7. After flash completes, Klipper needs to be restarted (FIRMWARE_RESTART
   or full power cycle) before the new firmware loads. Per the K2 Plus
   motor-state caveat: power-cycle from the mains before the next G28.

If flash.py says "no DFU device found", the probe was not in bootloader
mode — repeat steps 2-5.

EOF
    press_enter
}

carto_fw_launch() {
    local flash_py="$INSTALLER_DIR/features/cartographer/firmware/flash.py"
    if [ ! -f "$flash_py" ]; then
        warn "flash.py not found: $flash_py"
        warn "(install the cartographer feature first)"
        press_enter
        return
    fi

    clear
    printf '\n%s\n' "$(c_yellow 'Final check — is the probe in DFU/bootloader mode?')"
    printf '  (See option 1 if you need a refresher on entering DFU mode.)\n\n'
    if ! confirm "Probe is in DFU mode and ready to flash?"; then return; fi

    info "running $flash_py"
    ensure_path
    if python3 "$flash_py"; then
        printf '\n%s\n' "$(c_green 'flash.py exited cleanly.')"
        printf 'Restart Klipper (FIRMWARE_RESTART) to load the new firmware,\n'
        printf 'then power-cycle from the mains before the next G28.\n\n'
    else
        warn "flash.py exited non-zero"
    fi
    press_enter
}
