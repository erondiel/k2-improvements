# v1.1 — Single-command install + 1.1.3.13 extras + Cartographer precondition system

Major UX iteration on top of v1.0. Three themes:

1. **Single command for everyone** — bootstrap auto-detects firmware and existing-install state, no flags needed for the common cases.
2. **Extras-only mode for 1.1.3.13 users** — long-requested. 1.1.3.13 users with a working Jacob10383 install can finally add the K2-Plus extras (KAMP, surface-selection-wrapper, cartographer-macros, etc.) on top, without touching the existing install.
3. **Cartographer precondition system** — install scripts, bootstrap warning, and the Extras menu all surface the "you need Cartographer first" requirement up front, so users without Cartographer get clear guidance instead of mysterious runtime failures.

Plus KAMP comprehensive slicer setup docs, optional firmware retraction during KAMP install, and drop-in machine start gcode templates for Creality Print and OrcaSlicer.

## Headline features

### Single command for every user

```bash
curl -sSL https://raw.githubusercontent.com/erondiel/k2-improvements/main/bootstrap.sh \
  | sh -s -- <printer-ip>
```

Or, if you'd rather have the source locally first:

```bash
git clone https://github.com/erondiel/k2-improvements.git
cd k2-improvements
sh bootstrap.sh <printer-ip>
```

Auto-detect routing:

| Detected state | Behavior |
| --- | --- |
| 1.1.5.2 (fresh or update) | Erondiel full install |
| 1.1.3.13, no existing install | Routes to Jacob10383 + applies portable bug-fixes |
| **1.1.3.13, existing Jacob install** | Asks "Add extras only? [Y/n]" — defaults yes; on yes, clones to sibling path and shows reduced menu |
| Other firmware | Prompts user (existing v1.0 behavior) |

Power-user override flags (rarely needed): `--extras-only`, `--full`.

### Extras-only mode for 1.1.3.13 users

1.1.3.13 users with a working Cartographer install via Jacob10383 can now add the K2-Plus extras (KAMP, surface-selection-wrapper, cartographer-offset-setup picker, cartographer-macros) on top of their existing install. **Three independent safety layers** prevent damage to the working install:

1. **Sibling-path clone** — extras-only clones to `/mnt/UDISK/k2-improvements-extras/`, never touches `/mnt/UDISK/k2-improvements/`
2. **`menu.sh` path-based safeguard** — auto-sets extras-only mode when launched from a `-extras` directory, even without the env var
3. **`main_menu` firmware-based force** — checks printer firmware at runtime; if 1.1.3.13 and someone bypasses the other two layers, the menu still forces extras-only with a yellow warning banner

The reduced menu hides Install-essentials, Features, and the firmware-flash items. Pressing them shows "Disabled in extras-only mode."

### Robust existing-install detection

The auto-detect prompt probes three locations to handle both Jacob's and our path conventions:

1. `/mnt/UDISK/k2-improvements/` — our convention; symlink target on combined installs
2. `/mnt/UDISK/root/k2-improvements/` — Jacob's `~/k2-improvements/` after `better-root` sets `HOME=/mnt/UDISK/root`
3. **Fallback**: parse `~/printer_data/config/moonraker.conf` for `[update_manager k2-improvements]` block, expand `~` if present, verify `.git/config` points at Jacob10383

Either match flags the install as Jacob's. The detected path is shown verbatim in the prompt.

### Cartographer precondition system

Three layers of "you need Cartographer first" surface the dependency at the friendliest possible point:

**1. Install scripts refuse with clear errors** when `[cartographer]` is missing from the Klipper config tree. Affected scripts: `surface-selection-wrapper`, `cartographer-offset-setup`, `cartographer-macros`. Sample message:

```
ERROR: no [cartographer] section found in printer config.
       This wrapper patches START_PRINT to call CARTOGRAPHER_*
       commands, which need Cartographer installed first.
       Install via Jacob10383's gimme-the-jamin.sh or the menu's
       'Install Essentials' before adding this extra.
```

**2. Bootstrap warns** when `--extras-only` is forced (`EXTRAS_OVERRIDE=1`) and no `[cartographer]` is detected. Per-extra dependency breakdown plus prompt:

```
W: --extras-only forced but no [cartographer] section found in printer config.
W:
W:   Most extras require Cartographer to already be installed:
W:     - surface-selection-wrapper, cartographer-offset-setup, cartographer-macros
W:
W:   These extras work standalone:
W:     - KAMP (adaptive purge), motor-state-guard (UNTESTED), prtouch-cleanup

Continue anyway? [y/N]
```

Default no. Skipped when extras-only was set by the auto-detect prompt — that path already verified an install exists.

**3. Extras menu greys out blocked items** with yellow `[!] (needs Cartographer)`. Picking a blocked item shows a refusal screen with guidance toward menu items 2/3 or `gimme-the-jamin.sh`, without running the install script:

| State | Marker | When |
|---|---|---|
| Installed | `[X]` (green) | Detector function returns true |
| Available | `[ ]` (dim) | Not installed, precondition met |
| **Blocked** | **`[!]` (yellow) `(needs Cartographer)`** | Not installed, precondition missing |

`prtouch-cleanup` and `motor-state-guard` have no precondition and continue to behave as before.

### KAMP improvements

- **Optional Klipper firmware retraction during install** silences the LINE_PURGE warning and gives one place to tune retraction. Opt-in prompt with conservative PLA defaults (0.5mm @ 35mm/s); skipped silently if `[firmware_retraction]` already exists, or if running non-interactively.
- **Drop-in machine start gcode templates** ship in `features/kamp-adaptive-purge/slicer-templates/`:
  - `creality-print-machine-start.gcode` — verified on Creality Print 7.1.1
  - `orca-machine-start.gcode` — Orca template (unverified; `bed_type` strings may need adjustment per profile)
- **Comprehensive slicer setup docs** addressing the most common "I installed KAMP but it doesn't work" failure mode: Label objects toggle paths for Creality Print 7.x and Orca, blocking M109 requirement, machine start gcode replacement walkthrough, and verification step using `grep EXCLUDE_OBJECT_DEFINE|LINE_PURGE` on the sliced gcode.

## Verified

- K2 Plus 1.1.5.2 + Cartographer V4 USB-full
- Bootstrap default: auto-detect correctly skips the 1.1.3.13-specific prompt on 1.1.5.2
- Extras-only mode on 1.1.5.2: clones to sibling path, banner displays correctly, reduced menu hides Install-essentials / Features / firmware items, pressing hidden items shows yellow "Disabled in extras-only mode" message
- Path-based safeguard on 1.1.5.2: `sh menu.sh` from `-extras` dir without env var still triggers extras-only mode
- Existing `/mnt/UDISK/k2-improvements/` install untouched after `--extras-only` run
- KAMP install firmware retraction prompt fires when `[firmware_retraction]` is absent, skipped silently when present, expanded post-install message displays
- KAMP install non-interactive: skip prompt cleanly with hint about how to enable later
- Cartographer precondition probe runs cleanly under busybox ash on K2 Plus (positive case finds existing `[cartographer]`; negative case handles missing files without `set -e` aborting)
- Extras menu greying with `is_cartographer` temporarily forced false: yellow `[!]` renders on the 3 Cartographer-dependent extras with the hint, picking one shows the refusal screen with guidance, install script does not run

## Verified by inspection only

- 1.1.3.13 + existing Jacob install auto-detect prompt — code path verified by inspection; no 1.1.3.13 printer available for live test
- Firmware-based force in `main_menu` on 1.1.3.13 — same coverage level

## Upgrade

```bash
curl -sSL https://raw.githubusercontent.com/erondiel/k2-improvements/main/bootstrap.sh \
  | sh -s -- <printer-ip>
```

Or update an existing install via menu item **8. Update installer**.

## Patch history

| Tag | Commit | Theme |
|---|---|---|
| v1.1.0 | `a6d96ae`, `c018220`, `23029ab`, `35b58aa`, `17aa380`, `f89de16` | Initial v1.1 — single-command install, extras-only mode, KAMP firmware retraction + slicer templates, README updates |
| v1.1.1 | `6fe1a41` | Bootstrap detection: 2-path probe + moonraker.conf fallback |
| v1.1.2 | `d702ba7` | Cartographer precondition guards in install scripts + bootstrap |
| v1.1.3 | `804ece2` | Extras menu greys out items with unmet preconditions |
| v1.1.4 | `2bb2c5e` | Bootstrap self-heals when piped from curl on systems without sshpass — fixes silent termination on dropbear (BusyBox / K2 Plus shells) where the SSH password prompt eats the rest of the script. Re-downloads to /tmp and re-execs with TTY stdin. |
| v1.1.5 | `b8d5359` | Bootstrap auto-installs sshpass via the host's package manager (opkg / apt / dnf / yum / pacman / brew) with a default-yes prompt — eliminates the ~10 password prompts per run on hosts where sshpass isn't pre-installed. Falls through to the existing warning if no package manager is detected (e.g. Git Bash on Windows). |
| v1.1.6 | `f36e731` | Bootstrap detects `sshpass` is missing from the K2 Plus's Entware feed (armv7-3.2 doesn't ship it) and falls back to installing `expect` + an `expect`-based sshpass-equivalent shell wrapper. The wrapper as shipped in v1.1.6 had several bugs that prevented it from working — see v1.1.7. |
| v1.1.7 | (this release) | Fixes bugs in v1.1.6's expect-based sshpass wrapper. Issues found via end-to-end testing on K2 Plus: (1) `expect -c` mode doesn't reliably populate `$argv` — switched to script-file invocation. (2) Regex didn't match dropbear's `(y/n)` fingerprint prompt — added pattern and `y` answer alongside the OpenSSH `(yes/no)` pattern. (3) `trap ... EXIT` cleanup was masking expect's exit code in busybox ash — replaced with explicit cleanup that preserves `$?`. (4) Bootstrap's curl-pipe self-heal and the wrapper download both used curl unconditionally, but the K2 Plus stock has wget not curl — added wget fallback to both. Verified working: correct password → exit 0, wrong password → exit 5 (sshpass-compatible), dropbear fingerprint auto-answered. |

## Known issues

- **Cartographer V4 mid-print USB disconnects on 1.1.5.2** are still under investigation. Two failure modes characterized: bridge daemon stuck on stale fd (recovers via `FIRMWARE_RESTART`) and full enumeration failure (requires mains power-cycle). Mechanical-disturbance correlation is the active lead.
- **`motor-state-guard`** still UNTESTED. Excluded from `Install essentials`, available in Extras with prominent UNTESTED warning.
- **Cartographer firmware flash (item 6)** and **USB-stick printer-firmware prep (item 7)** still UNTESTED.
