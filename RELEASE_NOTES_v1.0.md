# v1.0 — Interactive TUI installer for K2 Plus

First tagged release of the `erondiel/k2-improvements` fork. Adds a
one-command bootstrap and a 9-item menu installer on top of
[Jacob10383/k2-improvements](https://github.com/Jacob10383/k2-improvements),
targeted at K2 Plus owners on stock Creality firmware **1.1.5.2**
(routes 1.1.3.13 users automatically to upstream).

## Quick start

From your PC:

```bash
git clone https://github.com/erondiel/k2-improvements.git
cd k2-improvements
sh bootstrap.sh <printer-ip>
```

Then SSH into the printer and run `sh /mnt/UDISK/k2-improvements/menu.sh`.
Pick **`2 Install essentials`**. Walk away. Come back to a working K2
Plus with Cartographer.

See the [README](./README.md) for the full menu walkthrough.

## What's verified end-to-end

Tested live on a freshly factory-reset **K2 Plus 1.1.5.2 + Cartographer V4** on 2026-04-30:

- **Bootstrap from stock**: Entware via the printer's `python3` + a
  small Python `wget` shim (stock K2 Plus has no `wget`/`curl`,
  generic.sh wouldn't work), then `opkg install`, git clone, and the
  Entware `unslung` boot hook installed — the latter is what makes
  `/opt/etc/init.d/S*` services auto-start on every reboot.
- **`Install essentials`** runs cleanly in dependency order: entware
  → better-root-safe → better-init → moonraker → fluidd (patched
  build with WebRTC Creality K2 camera support) → screws_tilt_adjust
  → cartographer (registers update-manager with moonraker) →
  prtouch-cleanup (no-op once cartographer's PR-#9 fix is in) →
  macros. **Order matches upstream gimme-the-jamin.sh.**
- **Mandatory Cartographer mount picker** at the end (Jamin Collins /
  JimmyV / custom). Probe offsets are hardware-specific.
- **Reboot survives**: moonraker, cartographer USB-bridge, all
  feature services auto-start via the unslung hook. No manual
  intervention.
- **Camera in Fluidd**: registered automatically with moonraker as
  `webrtc-crealityk2rtc`, served on port 8000. Hard-refresh browser
  (`Ctrl+Shift+R`) the first time to clear cached stock-Creality Fluidd.
- **Status panel detection** correctly identifies all installed +
  not-installed features post-install.
- **Idempotency**: re-running any install step is a no-op.

## What's in the box

### Top-level menu

| # | Item | What it does |
| ---: | --- | --- |
| 1 | Status | Shows printer fw, Cartographer HW + firmware, current offset preset, per-feature install state |
| 2 | **Install essentials** (recommended) | Auto-installs the 9 essentials in dependency order, then prompts for mount preset |
| 3 | Features ▶ | Pick any of the 13 k2-improvements features individually with README preview |
| 4 | Extras ▶ | K2-Plus-only patches: prtouch-cleanup, surface-selection-wrapper, cartographer-offset-setup, cartographer-macros, motor-state-guard (UNTESTED) |
| 5 | KAMP ▶ | Install / re-install / tune the KAMP adaptive line-purge |
| 6 | Cartographer firmware flash ▶ (UNTESTED) | V4 full / V4 lite / V3 build picker, HW-mismatch guard, wraps upstream `flash.py` |
| 7 | Prepare USB stick (printer firmware swap) ▶ (UNTESTED) | Detects FAT32 stick, copies the chosen `1.1.3.13` / `1.1.5.2` `.img`, prints physical-flash steps |
| 8 | Update installer | `git pull` to refresh the install on the printer |
| 9 | Exit | |

### K2-Plus-specific extras (not in upstream)

- **`cartographer-offset-setup`** — Jamin / JimmyV / custom mount picker with idempotency + numeric input validation.
- **`cartographer-macros`** — `CARTO_*` `gcode_macro` buttons in Fluidd for `CARTOGRAPHER_CALIBRATE`, `CARTOGRAPHER_TOUCH_CALIBRATE`, `CARTOGRAPHER_TOUCH_HOME`, `CARTOGRAPHER_GET_INFO`, plus per-plate calibrate/load/touch buttons (default / pei / coolplate).
- **`surface-selection-wrapper`** — adds `SURFACE=…` parameter to `START_PRINT` so the slicer can drive multi-surface profile loading from the bed-type dropdown.
- **`prtouch-cleanup`** — strips orphan `[prtouch_v3]` SAVE_CONFIG header (now redundant for our path; cartographer install includes the same cleanup via PR-#9 changes in our fork — kept as Extras item for diagnostic use).
- **`better-root-safe`** — drop-in replacement for upstream `better-root` that handles the `/mnt/UDISK/root/moonraker` real-directory conflict on K2 Plus 1.1.5.2 and never kills SSH on non-interactive runs.
- **`motor-state-guard`** — defense-in-depth against the K2 Plus motor wrapper bug after Klipper-only restarts. **Tagged UNTESTED** — code is complete but the runtime detection mechanism hasn't been observed engaging.

### Firmware-version routing

`bootstrap.sh` detects which firmware your printer runs:

| Detected firmware | What bootstrap does | Final command |
| --- | --- | --- |
| **1.1.5.2** | Clones this fork, installer-v1 menu | `sh /mnt/UDISK/k2-improvements/menu.sh` |
| **1.1.3.13** | Clones [Jacob10383/k2-improvements](https://github.com/Jacob10383/k2-improvements) `main` upstream, applies our portable bug-fixes (overlay), then hands off | `sh /mnt/UDISK/k2-improvements/gimme-the-jamin.sh` |
| Unknown / 1.1.4.x | Prompts user to pick which path to use | varies |

### Portable bug-fix overlay (1.1.3.13 path)

When bootstrap routes to Jacob's upstream, it overlays 5 patched files
on top of his clone via [`installer/scripts/patch-jacob-fixes.sh`](./installer/scripts/patch-jacob-fixes.sh).
4 of the 5 mirror open PRs against Jacob's repo (silent no-op once
upstream merges them):

- **PR #6** — `gimme-the-jamin.sh` PATH export so feature scripts find Entware tools
- **PR #7** — `features/better-root/install.sh` idempotent `link_up` + don't kill SSH on non-interactive runs
- **PR #8** — `features/better-init/install.sh` mkdir `/etc/profile.d` before write
- **PR #9** — `features/cartographer/install.sh` strip orphan `[prtouch_v3]` SAVE_CONFIG header

5th overlay: `features/secure-auth/install.sh` — fix broken `grep -c PATTERN FILE -eq 0` syntax (would otherwise lock the user out by disabling password SSH on a printer with no authorized_keys). Not yet PR'd upstream pending a clean test.

## Not yet verified

These paths exist in the menu and look right on inspection, but
weren't exercised end-to-end in this release's testing:

- **Cartographer firmware flash (item 6)** — needs DFU button press on the probe.
- **USB-stick printer firmware prep (item 7)** — the test printer's only USB port is occupied by the Cartographer probe; the `cp` step never executed.
- **`motor-state-guard`** — runtime detection mechanism not observed engaging.

If you exercise any of these and hit issues, please open an issue with output.

## Bugs caught and fixed during this release's testing (~12)

This release is the result of two intensive sessions of fresh-printer testing. Fixes include:

1. Bootstrap couldn't run on stock K2 Plus (no `wget`/`curl`) → use printer's `python3` + Python `wget` shim
2. `scp` needed `-O` for legacy protocol (dropbear has no sftp-server)
3. `--force-overwrite` for `opkg install wget` (shim conflict)
4. Factory resets regenerate SSH host key → `UserKnownHostsFile=/dev/null`
5. Pruned `Install all` → `Install essentials` (no secure-auth/obico/QoL auto-install)
6. `better-root-safe` wrapper (skip the moonraker-dir trap)
7. `features/macros/install.sh` wrapper for the 4 sub-installs (upstream lacked one)
8. `$HOME` from `/etc/passwd` for every install dispatch (better-root mid-flow change)
9. `/mnt/UDISK/root/k2-improvements` symlink for cartographer's `~/k2-improvements/scripts/...`
10. Firmware-version routing (1.1.5.2 → us, 1.1.3.13 → Jacob)
11. **Entware `unslung` boot hook** — the headline missing piece. Without it, `/opt/etc/init.d/S*` services don't fire on reboot. Was wrongly attributed to Jacob upstream until @erondiel called out the misattribution and we found our own bypass.
12. `is_fluidd` detector — distinguishes Creality stock Fluidd from Jacob's patched build (the stock build has no Creality WebRTC support; without this fix, Install essentials skipped fluidd and the camera silently didn't work)

## Acknowledgements

- [Jacob10383](https://github.com/Jacob10383) for the upstream `k2-improvements` this fork builds on
- [Jamin Collins](https://github.com/jaminollins) for the K2 Plus front-mount Cartographer printable + earlier `k2-improvements` work
- JimmyV (printables.com) for the K2 Plus back-mount Cartographer adapter
- [@Guilouz](https://github.com/Guilouz) for the Creality Helper Script and K1 docs (standing on the shoulders of giants)
- [@stranula](https://github.com/stranula) and [@juliosueiras](https://github.com/juliosueiras) for K2-improvements contributions

Stack: [Klipper](https://github.com/Klipper3d/klipper) / [Moonraker](https://github.com/Arksine/moonraker) / [Fluidd](https://github.com/fluidd-core/fluidd) / [Entware](https://github.com/Entware/Entware) / [KAMP](https://github.com/kyleisah/Klipper-Adaptive-Meshing-Purging) / [Cartographer3D](https://github.com/Cartographer3D)
