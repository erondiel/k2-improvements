#!/bin/sh
# Detect Cartographer hardware revision (V3/V4) and firmware build.

detect_carto_hw() {
    local serial=$(cat /sys/bus/usb/devices/*/serial 2>/dev/null | grep -iE 'cartographer|scanner' | head -1)
    case "$serial" in
        *V4*) echo "V4" ;;
        *V3*) echo "V3" ;;
        *)
            local k=/mnt/UDISK/printer_data/logs/klippy.log
            if [ -r "$k" ]; then
                grep -oiE 'cartographer.*(v[34])' "$k" | tail -1 | grep -oiE 'v[34]' | tr a-z A-Z | head -1
            else
                echo "unknown"
            fi
            ;;
    esac
}

detect_carto_fw() {
    local k=/mnt/UDISK/printer_data/logs/klippy.log
    [ -r "$k" ] || { echo "unknown"; return; }
    grep -oE "Cartographer.*[0-9]+\.[0-9]+\.[0-9]+(_USB_(full|lite))?" "$k" | tail -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+(_USB_(full|lite))?'
}
