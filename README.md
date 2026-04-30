# K2 Improvements — `erondiel` fork

Interactive TUI installer for the K2 Plus on stock Creality firmware. Builds on top of [Jacob10383/k2-improvements](https://github.com/Jacob10383/k2-improvements) — adds a one-command bootstrap, a 9-item menu, idempotent install scripts, and K2-Plus-specific extras (KAMP, surface-selection wrapper, Cartographer offset picker, CARTO_* gcode_macros for Fluidd).

## Quick install

From your PC's terminal (Linux / Mac / WSL / Git Bash on Windows):

```bash
git clone https://github.com/erondiel/k2-improvements.git
cd k2-improvements
sh bootstrap.sh <printer-ip>
```

The bootstrap takes ~2 minutes and:
1. SSH-tests the printer (root SSH must be enabled in Settings → General → "Open Root").
2. Installs Entware on the printer using its built-in `python3` + a small `wget` shim (stock K2 Plus has no `wget`/`curl`, which is why the official Entware installer fails on it).
3. `opkg install`s `git` + `dialog` + `ca-bundle`.
4. `git clone`s this fork into `/mnt/UDISK/k2-improvements`.

When it finishes, SSH into the printer and launch the menu:

```bash
ssh root@<printer-ip>
sh /mnt/UDISK/k2-improvements/menu.sh
```

## The 9-item menu

| # | Item | What it does |
| ---: | --- | --- |
| 1 | Status | Shows printer firmware, Cartographer HW + firmware, current offset preset, and per-feature install state. |
| 2 | **Install essentials** (recommended) | The minimum needed to print: `entware`, `better-root-safe`, `better-init`, `cartographer`, `prtouch-cleanup`, `moonraker`, `fluidd`, `macros`, `screws_tilt_adjust`. Skips already-installed. After auto steps, prompts you to pick the Cartographer mount preset (mandatory — offsets are hardware-specific). |
| 3 | Features ▶ | Pick any of the 13 k2-improvements features individually. Shows that feature's README inline before the install confirm. |
| 4 | Extras ▶ | K2-Plus-only patches: `prtouch-cleanup`, `surface-selection-wrapper`, `cartographer-offset-setup` (Jamin/JimmyV/custom picker), `cartographer-macros` (CARTO_* buttons for Fluidd), `motor-state-guard` (UNTESTED). |
| 5 | KAMP ▶ | Install / re-install / tune the [KAMP adaptive line-purge](./features/kamp-adaptive-purge/README.md). |
| 6 | Cartographer firmware flash ▶ (UNTESTED) | V4-full / V4-lite / V3 build picker; HW-mismatch guard. Wraps the upstream `flash.py`. |
| 7 | Prepare USB stick (printer firmware swap) ▶ (UNTESTED) | Detects mounted FAT32 stick, copies the chosen `1.1.3.13` / `1.1.5.2` `.img`, prints physical-flash instructions. |
| 8 | Update installer | `git pull` to refresh `/mnt/UDISK/k2-improvements`. |
| 9 | Exit | |

Every install action is idempotent — running `Install essentials` twice in a row is a no-op.

## What's verified

Tested live on a freshly factory-reset **K2 Plus 1.1.5.2 + Cartographer V4** on 2026-04-30:

- Bootstrap from stock — Entware via the Python `wget` shim, `opkg install`, git clone.
- `Install essentials` — all 9 features land cleanly (caught and fixed multiple cascading bugs along the way: better-root's moonraker-dir trap, missing `features/macros/install.sh`, `$HOME` not refreshing between scripts after better-root, missing `~/k2-improvements` symlink, moonraker's rc.d boot entry not enabled).
- Status panel detection across the board.
- Features menu (READMEs + dispatch).
- Extras: `prtouch-cleanup`, `surface-selection-wrapper`, `cartographer-offset-setup` picker, `cartographer-macros`.
- KAMP install/tune.
- Idempotency end-to-end.

## What's not yet verified

- **Cartographer firmware flash (item 6)** — needs DFU button press. Code looks correct but the actual flash never ran. **Tagged `(UNTESTED)` in the menu**; if you flash and hit issues, please open an issue with output.
- **USB-stick printer-firmware prep (item 7)** — the test printer's only USB port is occupied by the Cartographer probe, so the copy step never executed. Detection logic and `cp` path look correct on inspection. **Tagged `(UNTESTED)` in the menu**.
- **`motor-state-guard`** — defense-in-depth against the K2 Plus motor wrapper bug after Klipper-only restarts. Code is complete but the runtime detection mechanism (tmpfs marker / `delayed_gcode` handshake / `G28` wrap) hasn't been observed engaging. Excluded from `Install essentials`. Clearly tagged `(UNTESTED)` in the Extras menu and its [README](./features/motor-state-guard/README.md).

## Firmware-version routing

`bootstrap.sh` detects which Creality firmware your printer runs and picks the right install path:

| Detected firmware | What bootstrap does | Final command |
| --- | --- | --- |
| **1.1.5.2** | Clones this fork, gives you the full TUI installer (menu + extras) | `sh /mnt/UDISK/k2-improvements/menu.sh` |
| **1.1.3.13** | Clones [Jacob10383/k2-improvements](https://github.com/Jacob10383/k2-improvements) `main` upstream, applies our portable bug-fixes (see below), then hands off to the upstream installer | `sh /mnt/UDISK/k2-improvements/gimme-the-jamin.sh` |
| Unknown / 1.1.4.x / other | Prompts you to pick which path to use | varies |

**1.1.3.13 users do NOT get our menu UI or K2-Plus-specific extras** (KAMP via menu, surface-selection-wrapper, cartographer-offset-setup picker, cartographer-macros). Those rely on the rebased Klipper patches that only target 1.1.5.2. If you want them, switch to 1.1.5.2.

### Portable bug-fixes auto-applied to the 1.1.3.13 path

When bootstrap routes to Jacob's upstream, it auto-applies three small patches to fix known issues in upstream's install scripts. These are idempotent and become silent no-ops if upstream accepts the corresponding PRs.

| Bug in upstream | What our patch does |
| --- | --- |
| `features/secure-auth/install.sh` line 5: broken `grep -c PATTERN FILE -eq 0` syntax bypasses the safety check, **disables password SSH on printers with no authorized_keys → user lockout** | Replaces the check with proper shell syntax that genuinely refuses to disable password auth when no keys are configured |
| `features/moonraker/install.sh`: removes `/etc/rc.d/S*moonraker` and only adds `/opt/etc/init.d/S56moonraker`, **moonraker doesn't auto-start after reboot** | Appends `/etc/init.d/moonraker enable` so the rc.d boot entry is recreated |
| `features/better-root/install.sh`: tries to `ln -sfn /usr/share/moonraker moonraker` after rsync moves stock `/root/moonraker` into the new home, **install fails with "File exists"** | Comments out the moonraker symlink lines (the moonraker feature handles its own paths) |

The patcher script is at [`installer/scripts/patch-jacob-fixes.sh`](./installer/scripts/patch-jacob-fixes.sh) — runs on the printer once, immediately after the upstream clone.

## Looking for the older firmware-1.1.5.2-compat one-shot installer?

The legacy `install-k2plus-1152.sh` one-shot lives on the [`firmware-1.1.5.2-compat`](https://github.com/erondiel/k2-improvements/tree/firmware-1.1.5.2-compat) branch. The new installer on `main` supersedes it but builds on the same rebased Klipper patches underneath.

## DISCLAIMER

Use at your own risk. We're not responsible for fires or broken dreams. But you do get to keep both halves if something breaks.

## Warning

These improvements are **not compatible with Creality's auto-calibration**. Manual tuning gives better results in our experience.

## Features (individual READMEs)

- [axis_twist_compensation](./features/axis_twist_compensation/README.md)
- [better-init](./features/better-init/README.md)
- [better-root](./features/better-root/README.md) (and our [`better-root-safe`](./installer/extras/better-root-safe/README.md) wrapper)
- [Cartographer](./features/cartographer/README.md) support
- [Entware](https://github.com/Entware/Entware) bootstrap
- [Fluidd](./features/fluidd/README.md)
- [Moonraker](./features/moonraker/README.md)
- [Obico](./features/obico/README.md) — *WIP, optional*
- [SCREWS_TILT_CALCULATE](https://www.klipper3d.org/Manual_Level.html#adjusting-bed-leveling-screws-using-the-bed-probe)
- [KAMP adaptive purge](./features/kamp-adaptive-purge/README.md)
- [`motor-state-guard`](./features/motor-state-guard/README.md) — UNTESTED

K2-Plus-specific extras:

- [`cartographer-offset-setup`](./installer/extras/cartographer-offset-setup/README.md) — Jamin / JimmyV / custom mount picker
- [`cartographer-macros`](./installer/extras/cartographer-macros/README.md) — CARTO_* gcode_macros for Fluidd buttons
- [`surface-selection-wrapper`](./installer/extras/surface-selection-wrapper/README.md) — `START_PRINT SURFACE=…` for multi-plate setups
- [`prtouch-cleanup`](./installer/extras/prtouch-cleanup/README.md) — strip orphan SAVE_CONFIG block after cartographer install
- [`better-root-safe`](./installer/extras/better-root-safe/README.md) — fixes the moonraker-dir-conflict in upstream `better-root`

QoL macros (in `features/macros/`):

- [MESH_IF_NEEDED](./features/macros/bed_mesh/README.md)
- [START_PRINT](./features/macros/start_print/README.md)
- [M191](./features/macros/m191/README.md)

## Bed Leveling

Many K2 beds resemble a taco or valley. In the [bed_leveling](bed_leveling) folder you'll find a Python script and write-up on applying aluminium tape to shim the bed.

## Credits

- [Jacob10383](https://github.com/Jacob10383) — original `k2-improvements` upstream that this fork builds on
- [Jamin Collins](https://github.com/jaminollins) — the K2 Plus front-mount Cartographer printable + earlier `k2-improvements` work
- [@Guilouz](https://github.com/Guilouz) — Creality Helper Script and K1 docs (standing on the shoulders of giants)
- [@stranula](https://github.com/stranula)
- [@juliosueiras](https://github.com/juliosueiras)
- JimmyV (printables.com) — the K2 Plus back-mount Cartographer adapter

Stack:

- [Klipper](https://github.com/Klipper3d/klipper) / [Moonraker](https://github.com/Arksine/moonraker) / [Fluidd](https://github.com/fluidd-core/fluidd) / [Entware](https://github.com/Entware/Entware) / [KAMP](https://github.com/kyleisah/Klipper-Adaptive-Meshing-Purging) / [Cartographer3D](https://github.com/Cartographer3D)

## FAQ

See [FAQ.md](./FAQ.md).
