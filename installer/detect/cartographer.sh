#!/bin/sh
# Detect Cartographer hardware revision (V3/V4) and firmware build.

detect_carto_hw() {
    local k=/mnt/UDISK/printer_data/logs/klippy.log
    if [ -r "$k" ]; then
        local hw=$(grep -oE 'CARTOGRAPHER V[34]' "$k" | tail -1 | awk '{print $2}')
        [ -n "$hw" ] && { echo "$hw"; return; }
    fi
    echo "unknown"
}

detect_carto_fw() {
    local k=/mnt/UDISK/printer_data/logs/klippy.log
    [ -r "$k" ] || { echo "unknown"; return; }
    grep -oE 'CARTOGRAPHER V[34] [0-9]+\.[0-9]+\.[0-9]+' "$k" | tail -1 | awk '{print $3}'
}
