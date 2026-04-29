#!/bin/sh
# Cartographer probe firmware flash sub-menu.
#
# This is INTENTIONALLY excluded from "Install all" because the user has to
# physically put the probe in DFU mode (button press, see README) before
# the flash command can succeed.

# build|hardware|description|filename
_CARTO_FW='V4_full|V4|V4 USB full build (default; 2x sampling rate)|CartographerV4_6.0.0_USB_full_8MHz.bin
V4_lite|V4|V4 USB lite build (TRSYNC fallback; tighter timing margin)|CartographerV4_6.0.0_USB_lite_8MHz.bin
V3|V3|V3 hardware survey build (NOT for V4)|Survey_Cartographer_K1_5.1.0.bin'

menu_carto_fw() {
    local hw=$(detect_carto_hw)
    local cur=$(detect_carto_fw)

    while :; do
        clear
        printf '\n=== Cartographer firmware flash ===\n\n'
        printf '  Detected hardware : %s\n' "${hw:-unknown}"
        printf '  Current firmware  : %s\n\n' "${cur:-unknown}"

        printf '%s\n' "$(c_yellow 'WARNING — this is a manual-only flow.')"
        printf '  You must press the DFU button on the probe BEFORE picking a build,\n'
        printf '  otherwise the flash will fail to find the bootloader.\n\n'

        local n=0
        local OLDIFS="$IFS"
        IFS='
'
        for line in $_CARTO_FW; do
            n=$((n+1))
            local build=$(printf '%s' "$line" | cut -d'|' -f1)
            local fwhw=$(printf  '%s' "$line" | cut -d'|' -f2)
            local desc=$(printf  '%s' "$line" | cut -d'|' -f3)
            local marker
            if [ "$fwhw" = "$hw" ]; then marker=$(c_green ' ←'); else marker=''; fi
            printf '  %d. %-10s %s%s\n' "$n" "$build" "$(c_dim "$desc")" "$marker"
        done
        IFS="$OLDIFS"

        printf '\n  s. Show flash instructions (DFU button, etc.)\n'
        printf '  b. Back\n\n'
        printf 'Choose: '
        read -r c
        case "$c" in
            s|S) carto_fw_show_instructions ;;
            b|B|q|Q) return ;;
            ''|*[!0-9]*) ;;
            *)
                local picked=$(printf '%s' "$_CARTO_FW" | sed -n "${c}p")
                [ -n "$picked" ] && carto_fw_flash "$picked" "$hw"
                ;;
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

6. Come back to this menu, pick the firmware build (V4 full, V4 lite,
   or V3) matching your hardware. The flash usually takes 5-15 seconds.

7. After flash completes, Klipper needs to be restarted (FIRMWARE_RESTART
   or full power cycle) before the new firmware loads. Per the K2 Plus
   motor-state caveat: power-cycle from the mains before the next G28.

If the flash fails with "no DFU device found", the probe was not in
bootloader mode — repeat steps 2-5.

EOF
    press_enter
}

# Run the actual flash. Args: <table-line> <detected-hw>
carto_fw_flash() {
    local line="$1"
    local detected_hw="$2"
    local build=$(printf '%s' "$line" | cut -d'|' -f1)
    local fwhw=$(printf  '%s' "$line" | cut -d'|' -f2)
    local desc=$(printf  '%s' "$line" | cut -d'|' -f3)
    local fname=$(printf '%s' "$line" | cut -d'|' -f4)

    clear
    printf '\n=== Flash: %s ===\n\n' "$build"
    printf '  Build       : %s\n' "$build"
    printf '  For HW      : %s\n' "$fwhw"
    printf '  Detected HW : %s\n' "${detected_hw:-unknown}"
    printf '  Description : %s\n\n' "$desc"

    if [ "$fwhw" != "$detected_hw" ] && [ -n "$detected_hw" ] && [ "$detected_hw" != "unknown" ]; then
        printf '%s\n' "$(c_red 'MISMATCH — this build is for a different hardware revision than detected.')"
        printf '         V3 firmware on V4 hardware (or vice versa) will brick the probe.\n\n'
        if ! confirm "Are you SURE you want to continue?"; then return; fi
    fi

    local fwfile="$INSTALLER_DIR/installer/firmware/cartographer/$fname"
    if [ ! -f "$fwfile" ]; then
        warn "firmware file not found: $fwfile"
        warn "(installer ships these under installer/firmware/cartographer/)"
        warn "If missing, fetch from upstream cartographer3d releases."
        press_enter
        return 1
    fi

    printf '\n%s\n' "$(c_yellow 'Final check — is the probe in DFU/bootloader mode?')"
    printf '  Press 's' from the previous screen to see how to enter DFU mode.\n\n'
    if ! confirm "Probe is in DFU mode and ready to flash?"; then return; fi

    info "running flash for $fname"
    if command -v cartoflash >/dev/null 2>&1; then
        cartoflash "$fwfile"
    elif [ -x /opt/bin/cartographer3d ]; then
        /opt/bin/cartographer3d flash --firmware "$fwfile"
    elif [ -x "$KLIPPER_DIR/scripts/flash-cartographer.sh" ]; then
        sh "$KLIPPER_DIR/scripts/flash-cartographer.sh" "$fwfile"
    else
        warn "no flash tool found on this printer."
        warn "Install cartographer3d (opkg install python3-cartographer3d)"
        warn "or use the Klipper macro CARTOGRAPHER_FLASH_FIRMWARE from the web UI."
        press_enter
        return 1
    fi

    printf '\n%s\n' "$(c_green 'Flash command exited.')"
    printf 'Restart Klipper (FIRMWARE_RESTART) to load the new firmware,\n'
    printf 'then power-cycle from the mains before the next G28.\n\n'
    press_enter
}
