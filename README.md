# K2 Improvements — `erondiel` fork

[![Latest release](https://img.shields.io/github/v/release/erondiel/k2-improvements?label=latest&style=flat-square)](https://github.com/erondiel/k2-improvements/releases/latest)

Interactive TUI installer for the K2 Plus on stock Creality firmware. Builds on top of [Jacob10383/k2-improvements](https://github.com/Jacob10383/k2-improvements) — adds a one-command bootstrap, a 9-item menu, idempotent install scripts, and K2-Plus-specific extras (KAMP, surface-selection wrapper, Cartographer offset picker, CARTO_* gcode_macros for Fluidd).

## Quick install

**One command. No flags. Works for everyone.**

### Step 1 — Enable root SSH on the printer

On the printer's touchscreen: **Settings → General → "Open Root"**. Accept the disclaimer. (One-time, persists across reboots.)

### Step 2 — Find your printer's IP

On the touchscreen home screen, or your router's device list. Looks like `192.168.1.123` or similar.

### Step 3 — Run the bootstrap

Pick the path that matches where you are:

#### A) From your PC (most users)

Open a terminal — Linux, Mac, WSL, Git Bash on Windows, or MobaXterm all work. Replace `<printer-ip>` with the IP from step 2:

```bash
curl -sSL https://raw.githubusercontent.com/erondiel/k2-improvements/main/bootstrap.sh | sh -s -- <printer-ip>
```

If `curl` isn't available on your system (e.g. plain Windows Git Bash sometimes), use `wget`:

```bash
wget -qO- https://raw.githubusercontent.com/erondiel/k2-improvements/main/bootstrap.sh | sh -s -- <printer-ip>
```

#### B) From inside the printer's shell

If you don't have a Linux/Mac/WSL terminal handy, SSH into the printer first and run the bootstrap from there. Use `wget` (the K2 Plus shell has wget, not curl):

```bash
ssh root@<printer-ip>
# (default password: creality_2024)
wget -qO- https://raw.githubusercontent.com/erondiel/k2-improvements/main/bootstrap.sh | sh -s -- <printer-ip>
```

> **Use the printer's IP, NOT `localhost`** — but bootstrap detects "I'm running on the target machine" and skips SSH entirely. No password prompts, faster, no expect-wrapper machinery. (Localhost works too if you prefer; both forms get auto-detected as local.)

### What you'll see

```
=================================================================
 K2 Plus installer bootstrap (erondiel/k2-improvements)
 Starting up — this may take a few seconds while we prepare
 dependencies (download installer, install sshpass, etc.)
=================================================================
```

…then the bootstrap walks through:

1. **SSH probe** (or local-mode probe if running on the printer)
2. **Firmware detection** — picks the right install path automatically (see [Firmware-version routing](#firmware-version-routing) below)
3. **Existing-install detection** — if you already have a Cartographer install, it asks if you want to add extras *on top* without disturbing it (default yes)
4. **Entware + dependencies** — installs whatever's missing (`git`, `dialog`, `sshpass`, `ca-bundle`, etc.) on the first run; idempotent on subsequent runs
5. **Clone** — pulls the right repo into the right path
6. **Done** — prints the launch command for the menu, and offers to launch it for you (default yes in local-mode)

Total time: ~2 minutes for a fresh install on a decent connection. Idempotent — re-runs are safe and quick.

### Step 4 — Use the menu

Bootstrap ends with a colored "next step" line. Press **Enter** at the prompt to launch the menu. The 9-item TUI walks you through Install Essentials, Features picker, Extras (KAMP, surface-selection-wrapper, etc.), and the rest.

If you skipped the auto-launch prompt, copy the printed launch command and run it later — bootstrap shows the exact path. It's one of:

```
sh /mnt/UDISK/k2-improvements/menu.sh                            (1.1.5.2 users, fresh install)
sh /mnt/UDISK/k2-improvements/gimme-the-jamin.sh                 (1.1.3.13 fresh install via Jacob10383)
K2_EXTRAS_ONLY=1 sh /mnt/UDISK/k2-improvements-extras/menu.sh    (1.1.3.13 + existing install, extras-only)
```

### Alternative: clone first, run from source

If you'd rather inspect the source before running anything:

```bash
git clone https://github.com/erondiel/k2-improvements.git
cd k2-improvements
sh bootstrap.sh <printer-ip>
```

Same end result.

## The 9-item menu

| # | Item | What it does |
| ---: | --- | --- |
| 1 | Status | Shows printer firmware, Cartographer HW + firmware, current offset preset, and per-feature install state. |
| 2 | **Install essentials** (recommended) | The minimum needed to print, in dependency order: `entware`, `better-root-safe`, `better-init`, `moonraker`, `fluidd`, `screws_tilt_adjust`, `cartographer`, `prtouch-cleanup`, `macros`. Order matches upstream `gimme-the-jamin.sh` so feature installs that register with moonraker (cartographer, fluidd) find it already running. Skips already-installed. After auto steps, prompts you to pick the Cartographer mount preset (mandatory — offsets are hardware-specific). |
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

- Bootstrap from stock — Entware via the Python `wget` shim, `opkg install`, git clone, `unslung` boot hook installed (so `/opt/etc/init.d/S*` services auto-start on reboot).
- `Install essentials` — all 9 features land cleanly (caught and fixed multiple cascading bugs along the way: better-root's moonraker-dir trap, missing `features/macros/install.sh`, `$HOME` not refreshing between scripts after better-root, missing `~/k2-improvements` symlink, missing Entware unslung boot hook, fluidd detector matching stock-Creality build instead of Jacob's patched build).
- Status panel detection across the board.
- Features menu (READMEs + dispatch).
- Extras: `prtouch-cleanup`, `surface-selection-wrapper`, `cartographer-offset-setup` picker, `cartographer-macros` (CARTO_* buttons in Fluidd).
- KAMP install/tune.
- Camera via patched Fluidd + WebRTC Creality service (port 8000). After install, **hard-refresh the browser** (Ctrl+Shift+R) to clear cached stock-Fluidd or you'll see "service not supported".
- Reboot survives — moonraker, cartographer USB-bridge, and all features auto-start via the `unslung` boot hook.
- Idempotency end-to-end.

## What's not yet verified

- **Cartographer firmware flash (item 6)** — needs DFU button press. Code looks correct but the actual flash never ran. **Tagged `(UNTESTED)` in the menu**; if you flash and hit issues, please open an issue with output.
- **USB-stick printer-firmware prep (item 7)** — the test printer's only USB port is occupied by the Cartographer probe, so the copy step never executed. Detection logic and `cp` path look correct on inspection. **Tagged `(UNTESTED)` in the menu**.
- **`motor-state-guard`** — defense-in-depth against the K2 Plus motor wrapper bug after Klipper-only restarts. Code is complete but the runtime detection mechanism (tmpfs marker / `delayed_gcode` handshake / `G28` wrap) hasn't been observed engaging. Excluded from `Install essentials`. Clearly tagged `(UNTESTED)` in the Extras menu and its [README](./features/motor-state-guard/README.md).

## Firmware-version routing

`bootstrap.sh` detects firmware **and** existing-install state and picks the right path automatically:

| Detected state | What bootstrap does | Final launch command |
| --- | --- | --- |
| **1.1.5.2** (fresh or update) | Clones this fork, gives you the full TUI installer (menu + extras) | `sh /mnt/UDISK/k2-improvements/menu.sh` |
| **1.1.3.13**, no existing install | Clones [Jacob10383/k2-improvements](https://github.com/Jacob10383/k2-improvements) `main` upstream, applies our portable bug-fixes (see below), then hands off to the upstream installer | `sh /mnt/UDISK/k2-improvements/gimme-the-jamin.sh` |
| **1.1.3.13 with existing Jacob install** | Detects `/mnt/UDISK/k2-improvements/` already cloned from Jacob10383. Asks "Add extras only? [Y/n]" — defaults to yes. On yes, clones erondiel into `/mnt/UDISK/k2-improvements-extras/` (sibling path, **does NOT touch** the existing install) and shows a reduced menu (Status / Extras / KAMP / Update). On no, re-runs Jacob's full install. | `K2_EXTRAS_ONLY=1 sh /mnt/UDISK/k2-improvements-extras/menu.sh` |
| Unknown / 1.1.4.x / other | Prompts you to pick which path to use | varies |

**1.1.3.13 users CAN now get our K2-Plus-specific extras** (KAMP, surface-selection-wrapper, cartographer-offset-setup picker, cartographer-macros) on top of an existing Jacob10383 install — that's the third row above. The rebased Klipper patches stay 1.1.5.2-only; the extras menu only adds config files / macros, never touches Klipper py files, so it's safe cross-firmware.

### Extras-only mode safety

When extras-only mode activates (auto-detected on 1.1.3.13 with existing install, or forced via `--extras-only` flag), three independent layers prevent accidental damage to the working Cartographer install:

1. **Bootstrap clones to a separate path** (`/mnt/UDISK/k2-improvements-extras/`), never touches `/mnt/UDISK/k2-improvements/`.
2. **`menu.sh` path-based safeguard** — auto-sets extras-only mode when launched from a `-extras` install dir, even if the user re-enters the menu by typing `sh menu.sh` directly without the env var.
3. **`main_menu` firmware-based force** — if the printer is on 1.1.3.13 and someone bypasses both bootstrap and the path safeguard (manually clones erondiel into the regular path), the menu still detects 1.1.3.13 firmware and forces extras-only mode at runtime with a yellow warning banner.

The reduced menu hides Install-essentials, Features, and the firmware-flash items. Pressing them shows "Disabled in extras-only mode."

### Power-user override flags

All optional — defaults are correct for the common case.

- `--extras-only` — force extras-only mode regardless of detected state
- `--full` — force full install regardless of detected state (re-runs everything; idempotent)
- `--auto-launch` — skip the post-install "Launch the menu now? [Y/n]" prompt and exec the menu directly. In local-mode the menu runs in the current shell; in SSH-from-PC mode bootstrap opens an SSH session with `-t` (TTY allocated) for the menu. Useful for one-shot install-and-go workflows.
- `--test-jacob` — test mode: simulates a 1.1.3.13 + Jacob10383 install on any machine (forces local-mode, stages a fake Jacob install in `/tmp`, redirects clone to `/tmp/k2-test-...`, exits with a routing-decision summary). Skips destructive operations. Useful for verifying the auto-detect prompt and routing flow without real hardware. Composes with `--auto-launch` for full-flow smoke tests.

### Portable bug-fixes auto-applied to the 1.1.3.13 path

When bootstrap routes to Jacob's upstream, it auto-applies two small patches to fix known issues in upstream's install scripts. These are idempotent and become silent no-ops if upstream accepts the corresponding PRs.

| Bug in upstream | What our patch does |
| --- | --- |
| `features/secure-auth/install.sh` line 5: broken `grep -c PATTERN FILE -eq 0` syntax bypasses the safety check, **disables password SSH on printers with no authorized_keys → user lockout** | Replaces the check with proper shell syntax that genuinely refuses to disable password auth when no keys are configured |
| `features/better-root/install.sh`: tries to `ln -sfn /usr/share/moonraker moonraker` after rsync moves stock `/root/moonraker` into the new home, **install fails with "File exists"** | Comments out the moonraker symlink lines (the moonraker feature handles its own paths) |

The patcher script is at [`installer/scripts/patch-jacob-fixes.sh`](./installer/scripts/patch-jacob-fixes.sh) — runs on the printer once, immediately after the upstream clone.

(There WAS a third "bug" I initially flagged — moonraker not auto-starting after reboot. That turned out to be a bug introduced by **our** streamlined Entware bootstrap, not Jacob's. Jacob's `features/entware/install.sh` correctly installs the `/etc/init.d/unslung` boot hook that runs all `/opt/etc/init.d/S*` services. Our bootstrap now installs the same hook so we get the same correct behavior on the 1.1.5.2 path.)

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
- JimmyV (printables.com) — the K2 Plus back-mount Cartographer V4 adapter

Stack:

- [Klipper](https://github.com/Klipper3d/klipper) / [Moonraker](https://github.com/Arksine/moonraker) / [Fluidd](https://github.com/fluidd-core/fluidd) / [Entware](https://github.com/Entware/Entware) / [KAMP](https://github.com/kyleisah/Klipper-Adaptive-Meshing-Purging) / [Cartographer3D](https://github.com/Cartographer3D)

## FAQ

See [FAQ.md](./FAQ.md).
