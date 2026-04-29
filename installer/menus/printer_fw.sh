#!/bin/sh
# Printer-firmware USB-stick prep sub-menu.
#
# Can't flash from inside Klipper (the bootloader does that, requires
# physical USB stick + power-cycle). What this menu does:
#   1. Detect a mounted USB stick (FAT32 or vfat).
#   2. List which firmware images are available locally on the printer.
#   3. Copy the chosen image to the stick with the filename Creality's
#      bootloader looks for.
#   4. Print the physical-flash steps and the K2 Plus motor-state caveat.

# Where Creality keeps OTA images on the printer
_FW_LOCAL_DIR=/mnt/UDISK/creality/upgrade
# Optional bundled images shipped with the installer
_FW_INSTALLER_DIR="$INSTALLER_DIR/installer/firmware/printer"
# Versions this menu knows about (must match _FW_FILENAME_TPL pattern)
_FW_SUPPORTED='1.1.3.13 1.1.5.2'
# Image filename template — Creality's bootloader expects this exact name
_FW_FILENAME_TPL='CR0CN240110C10_ota_img_V%s.img'

menu_printer_fw() {
    while :; do
        clear
        local cur=$(detect_printer_fw)
        local stick=$(detect_usb_stick)

        printf '\n=== Prepare USB stick — printer firmware swap ===\n\n'
        printf '  Currently running : %s\n' "$cur"
        printf '  USB stick         : %s\n\n' "${stick:-$(c_red 'NOT DETECTED')}"

        printf '  Available firmware images on the printer:\n'
        for v in $_FW_SUPPORTED; do
            local fname=$(printf "$_FW_FILENAME_TPL" "$v")
            local where=""
            if [ -f "$_FW_LOCAL_DIR/$fname" ]; then
                where="$_FW_LOCAL_DIR/"
            elif [ -f "$_FW_INSTALLER_DIR/$fname" ]; then
                where="$_FW_INSTALLER_DIR/"
            fi
            if [ -n "$where" ]; then
                printf '    %s  %s %s%s\n' "$v" "$(c_green '[on disk]')" "$(c_dim "$where")" "$fname"
            else
                printf '    %s  %s\n' "$v" "$(c_red '[missing — download from Creality]')"
            fi
        done

        printf '\n'
        printf '  1. Prepare stick with 1.1.3.13\n'
        printf '  2. Prepare stick with 1.1.5.2\n'
        printf '  i. Show physical-flash instructions\n'
        printf '  d. Where to download the missing .img files\n'
        printf '  b. Back\n\n'
        printf 'Choose: '
        read -r c
        case "$c" in
            1) prep_stick "1.1.3.13" "$stick" ;;
            2) prep_stick "1.1.5.2"  "$stick" ;;
            i|I) printer_fw_show_instructions ;;
            d|D) printer_fw_show_download_help ;;
            b|B|q|Q) return ;;
            *) ;;
        esac
    done
}

# Detect a mounted FAT32/vfat USB stick. Returns the mountpoint or empty.
detect_usb_stick() {
    local m
    for m in /tmp/udisk/sda1 /tmp/udisk/* /mnt/udisk/* /mnt/usb* /media/* ; do
        [ -d "$m" ] && [ -w "$m" ] && {
            # Confirm it's actually a mount (not just an empty dir)
            mountpoint -q "$m" 2>/dev/null && { echo "$m"; return; }
            mount 2>/dev/null | grep -q " on $m " && { echo "$m"; return; }
        }
    done
}

prep_stick() {
    local version="$1"
    local stick="$2"

    clear
    printf '\n=== Prepare stick with firmware %s ===\n\n' "$version"

    if [ -z "$stick" ]; then
        warn "no USB stick detected."
        printf '\nPlug in a FAT32-formatted USB stick and re-open this menu.\n\n'
        printf '%s\n' "$(c_yellow 'Note for K2 Plus:')"
        printf '  If your Cartographer probe is wired to the only USB port (welded\n'
        printf '  internally to the front-USB connector), you cannot use this flow\n'
        printf '  without temporarily unplugging the probe.\n\n'
        press_enter
        return
    fi

    local fname=$(printf "$_FW_FILENAME_TPL" "$version")
    local src
    if [ -f "$_FW_LOCAL_DIR/$fname" ]; then
        src="$_FW_LOCAL_DIR/$fname"
    elif [ -f "$_FW_INSTALLER_DIR/$fname" ]; then
        src="$_FW_INSTALLER_DIR/$fname"
    else
        warn "firmware $fname not found on the printer."
        printf '\nDownload it first — see option (d) for help.\n\n'
        press_enter
        return
    fi

    printf '  Source : %s\n' "$src"
    printf '  Target : %s/%s\n\n' "$stick" "$fname"

    local size=$(ls -l "$src" | awk '{print $5}')
    local free=$(df -P "$stick" 2>/dev/null | awk 'NR==2 {print $4}')
    [ -n "$free" ] && [ -n "$size" ] && {
        printf '  Image size  : %s bytes\n' "$size"
        printf '  Stick free  : %s blocks (1K)\n\n' "$free"
    }

    if ! confirm "Copy the image to the stick now?"; then return; fi

    info "copying — this takes 10-60 seconds depending on the stick"
    if cp "$src" "$stick/$fname" && sync; then
        printf '\n%s\n\n' "$(c_green 'Copy succeeded.')"
        printf 'Run option (i) for the physical flash steps.\n\n'
    else
        warn "copy failed — stick may be full or write-protected"
    fi
    press_enter
}

printer_fw_show_instructions() {
    clear
    cat <<'EOF'

=== How to flash printer firmware from the USB stick ===

1. Unmount any active prints. The printer should be idle.

2. Power the printer OFF at the rear power switch.

3. Insert the prepared USB stick into the printer's front USB port.

4. Power the printer ON.

5. The bootloader will detect the .img file on the stick and prompt
   you on the touchscreen to confirm the firmware install. Confirm.

6. Wait for the install to finish (3-5 minutes). The screen will show
   progress. Do NOT power off during the install.

7. After install completes, the printer reboots. Verify the new
   version on the touchscreen Settings → About screen.

8. *** K2 PLUS MOTOR-STATE CAVEAT ***
   After ANY firmware install (and after any Klipper-only restart),
   power-cycle the printer from the mains BEFORE running G28.
   See: K2 Plus motor-state bug memory.

If the bootloader does not detect the file:
   - Check the file is named exactly CR0CN240110C10_ota_img_V<ver>.img
   - Check the stick is FAT32-formatted (NOT exFAT or NTFS).
     (FAT32 is confirmed working — exFAT is sometimes claimed but the
      bootloader does NOT actually need exFAT.)
   - Try a smaller stick (some bootloaders dislike >32 GB sticks).

EOF
    press_enter
}

printer_fw_show_download_help() {
    clear
    cat <<'EOF'

=== Where to get printer firmware .img files ===

The K2 Plus printer firmware is distributed by Creality. The installer
does NOT bundle these files (they are 120-130 MB each and not freely
redistributable).

Two options to obtain them:

A. Pull from Creality's update server (the printer does this when you
   click "Check for updates" on the touchscreen). After the printer
   downloads, the file lives in:
     /mnt/UDISK/creality/upgrade/CR0CN240110C10_ota_img_V<version>.img

   You can let the printer download a version, then this menu will
   detect it and offer to copy it to the stick.

B. Download manually from a Creality firmware mirror. Search for:
     "K2 Plus firmware 1.1.3.13" or "K2 Plus firmware 1.1.5.2"
   Confirmed working sources at the time of writing:
     - https://www.creality.com/pages/download (official, current versions only)
     - Creality forum / community mirrors for older versions

   Drop the downloaded .img into either:
     /mnt/UDISK/creality/upgrade/                      (printer-local)
     installer/firmware/printer/                       (in this repo)

Both directories are searched by this menu. Filename must be exactly:
   CR0CN240110C10_ota_img_V<version>.img

EOF
    press_enter
}
