#!/bin/sh
# "Install all (recommended)" flow — installs every missing feature + extra
# + KAMP, in dependency order. Cartographer firmware flash is intentionally
# excluded (requires the user to put the probe in DFU mode physically).

# Essentials only — what's needed to have a working K2 Plus + Cartographer.
# QoL features (KAMP, surface-wrapper, abort_homing, axis_twist), security
# features (secure-auth — can lock you out if installed without keys), and
# optional integrations (obico, skip-setup) are excluded here. They stay
# available individually from the Features and Extras menus.
_INSTALL_ALL_ORDER='entware|is_entware|features/entware/install.sh
better-root|is_better_root|installer/extras/better-root-safe/install.sh
better-init|is_better_init|features/better-init/install.sh
cartographer|is_cartographer|features/cartographer/install.sh
prtouch-cleanup|is_prtouch_clean|installer/extras/prtouch-cleanup/install.sh
moonraker|is_moonraker|features/moonraker/install.sh
fluidd|is_fluidd|features/fluidd/install.sh
macros|is_macros|features/macros/install.sh
screws_tilt_adjust|is_screws_tilt|features/screws_tilt_adjust/install.sh'

menu_install_all() {
    clear
    printf '\n=== Install essentials (recommended) ===\n\n'
    printf 'The minimum needed to run a K2 Plus + Cartographer probe. Skips anything\n'
    printf 'already installed. After the auto steps, prompts you to pick your\n'
    printf 'Cartographer mount preset (mandatory — probe offsets depend on hardware).\n\n'
    printf 'NOT in this flow (need physical interaction or are optional):\n'
    printf '  - Cartographer firmware flash (DFU button)\n'
    printf '  - Printer firmware swap (USB stick)\n'
    printf '  - QoL features (KAMP, surface-wrapper, axis_twist, etc.) — Extras menu\n\n'
    printf 'Plan:\n'
    local OLDIFS="$IFS"
    IFS='
'
    local n=0
    for line in $_INSTALL_ALL_ORDER; do
        n=$((n+1))
        local name=$(printf '%s' "$line" | cut -d'|' -f1)
        local det=$(printf  '%s' "$line" | cut -d'|' -f2)
        local mark
        if "$det" 2>/dev/null; then mark=$(c_green '[X]'); else mark=$(c_dim '[ ]'); fi
        printf '  %2d. %s %s\n' "$n" "$mark" "$name"
    done
    IFS="$OLDIFS"
    printf '\n'
    printf '%s\n' "$(c_yellow 'WARNING: this can take 5-15 minutes and will modify Klipper.')"
    printf '         Make sure no print is active.\n\n'

    if ! confirm "Proceed with install essentials?"; then return 0; fi

    local installed=0 skipped=0 failed=0
    OLDIFS="$IFS"
    IFS='
'
    for line in $_INSTALL_ALL_ORDER; do
        local name=$(printf '%s' "$line" | cut -d'|' -f1)
        local det=$(printf  '%s' "$line" | cut -d'|' -f2)
        local script_rel=$(printf '%s' "$line" | cut -d'|' -f3)
        local script="$INSTALLER_DIR/$script_rel"

        printf '\n--- %s ---\n' "$name"

        if "$det" 2>/dev/null; then
            info "already installed — skipping"
            skipped=$((skipped+1))
            continue
        fi
        if [ ! -f "$script" ]; then
            warn "missing $script — skipping"
            failed=$((failed+1))
            continue
        fi
        # Force HOME into the install script's env from current /etc/passwd.
        # better-root mid-flow updates /etc/passwd, but the running menu
        # shell's HOME is cached from SSH login (won't reflect the change),
        # and child shells inherit that stale value. Setting HOME=... on
        # the sh call overrides it for that one invocation.
        pwd_home=$(awk -F: '$1=="root"{print $6}' /etc/passwd)
        info "running $name (HOME=$pwd_home)"

        if HOME="$pwd_home" sh "$script"; then
            installed=$((installed+1))
        else
            warn "$name install.sh failed (continuing)"
            failed=$((failed+1))
        fi
    done
    IFS="$OLDIFS"

    # Post-install: ensure moonraker auto-starts at boot. Two-pronged fix:
    # 1) /etc/init.d/moonraker enable — recreates rc.d/S56moonraker symlink
    #    (upstream removes it during the moonraker feature install).
    # 2) Append hook to /etc/rc.local — always run by /etc/init.d/done at
    #    S95 phase. Belt-and-braces because procd's S56 firing isn't
    #    reliable on K2 Plus (Klipper auto-starts via the same mechanism;
    #    moonraker doesn't, even with the symlink).
    if [ -x /etc/init.d/moonraker ]; then
        if [ ! -e /etc/rc.d/S56moonraker ]; then
            /etc/init.d/moonraker enable >/dev/null 2>&1 && \
                info "moonraker auto-start enabled (rc.d/S56moonraker)"
        fi
        if [ -f /etc/rc.local ] && ! grep -q 'erondiel-fix: moonraker auto-start' /etc/rc.local; then
            python3 - <<'PYEOF'
path = '/etc/rc.local'
with open(path) as f: content = f.read()
hook = (
    '\n# erondiel-fix: moonraker auto-start (procd boot of S56moonraker\n'
    '# does not fire reliably on K2 Plus). Idempotent: only starts if not running.\n'
    '[ -x /etc/init.d/moonraker ] && [ -z "$(pidof -x moonraker.py 2>/dev/null)" ] && /etc/init.d/moonraker start &\n'
)
if 'erondiel-fix: moonraker auto-start' not in content:
    if '\nexit 0\n' in content:
        content = content.replace('\nexit 0\n', hook + '\nexit 0\n', 1)
    else:
        content = content + hook
    with open(path, 'w') as f: f.write(content)
PYEOF
            info "moonraker auto-start hook added to /etc/rc.local"
        fi
    fi

    printf '\n%s\n' '----------------------------------------------------------------'
    printf 'Auto-install summary: %s installed, %s skipped, %s failed\n' \
        "$(c_green "$installed")" "$skipped" "$(c_red "$failed")"
    printf '%s\n\n' '----------------------------------------------------------------'

    # Mandatory final step: pick the Cartographer mount preset. The offset
    # values are hardware-specific so we can't auto-pick — but the user must
    # set them or Z-probing will be wrong across the bed.
    if is_cartographer; then
        printf '%s\n' "$(c_yellow 'MANDATORY: select your Cartographer mount preset')"
        printf 'Probe x_offset and y_offset depend on which physical mount you have.\n'
        printf 'Without picking the right preset, Z heights are wrong across the bed.\n\n'
        if confirm "Open the Cartographer offset picker now?"; then
            HOME=$(awk -F: '$1=="root"{print $6}' /etc/passwd) \
                sh "$INSTALLER_DIR/installer/extras/cartographer-offset-setup/install.sh" || true
        else
            printf '\n%s\n\n' "$(c_yellow 'Skipped — run it later from Extras menu (item 4).')"
        fi
    fi

    printf '\nFinal manual steps:\n'
    printf '  1. Power-cycle the printer from the mains (the cartographer install\n'
    printf '     restarted Klipper, which under K2 Plus motor-state caveat means\n'
    printf '     your next G28 must come AFTER a real boot).\n'
    printf '  2. Optional QoL: KAMP (item 5), surface-selection-wrapper (item 4),\n'
    printf '     axis_twist_compensation / abort_homing / skip-setup (item 3).\n'
    printf '  3. Optional: Cartographer firmware flash (item 6), printer firmware\n'
    printf '     swap prep (item 7) — both need physical interaction.\n'
    printf '  4. Calibrate per surface: CARTOGRAPHER_CALIBRATE METHOD=manual NAME=<plate>\n'
    printf '     and BED_MESH_CALIBRATE for each plate (default/pei/coolplate/etc).\n\n'
    press_enter
}
