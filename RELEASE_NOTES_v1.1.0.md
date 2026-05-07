# v1.1.0 — Single-command install + extras for 1.1.3.13 users

Adds a unified install flow that works for every user with one command, expands KAMP support, and lets 1.1.3.13 users install K2-Plus extras (KAMP, surface-selection-wrapper, cartographer-macros, etc.) on top of their existing Jacob10383 install **without touching it**.

## Highlights

### Single command for every user

```bash
curl -sSL https://raw.githubusercontent.com/erondiel/k2-improvements/main/bootstrap.sh \
  | sh -s -- <printer-ip>
```

Bootstrap now auto-detects firmware and existing-install state, then does the right thing. No flag needed for the common cases:

| Detected state | Behavior |
| --- | --- |
| 1.1.5.2 (fresh or update) | Erondiel full install |
| 1.1.3.13, no install | Routes to Jacob10383 + applies our portable bug-fixes |
| 1.1.3.13, existing Jacob install | Asks "Add extras only? [Y/n]" — defaults to yes; on yes, clones to a sibling path and shows a reduced menu (Status / Extras / KAMP / Update) |
| Other firmware | Prompts user (existing behavior) |

Power-user override flags (rarely needed): `--extras-only`, `--full`.

### Extras-only mode for 1.1.3.13 users

The most-requested feature since v1.0. 1.1.3.13 users with a working Cartographer install via Jacob10383 can now add the K2-Plus extras (KAMP, surface-selection-wrapper, cartographer-offset-setup picker, cartographer-macros) on top of their existing install. **Three independent safety layers** prevent damage to the working install:

1. **Sibling-path clone** — extras-only clones to `/mnt/UDISK/k2-improvements-extras/`, never touches `/mnt/UDISK/k2-improvements/`
2. **Path-based safeguard** — `menu.sh` auto-sets extras-only mode when launched from a `-extras` directory, even without the env var
3. **Firmware-based force** — `main_menu` checks printer firmware at runtime; if 1.1.3.13 and someone bypasses the other two layers, the menu still forces extras-only with a yellow warning banner

The reduced menu hides Install-essentials, Features, and the firmware-flash items — pressing them shows "Disabled in extras-only mode."

### KAMP improvements

- **Optional Klipper firmware retraction** during install. KAMP's `LINE_PURGE` prefers G10/G11 and prints a warning when firmware retraction isn't configured. The install now offers to add a `firmware_retraction.cfg` with conservative PLA defaults (0.5mm @ 35mm/s). Opt-in, default no. Skipped silently if `[firmware_retraction]` already exists, or if running non-interactively.

- **Comprehensive slicer setup docs.** The biggest "I installed KAMP and it doesn't work" failure mode is missing the slicer-side configuration (Label objects toggle off, machine start gcode not updated). The README and post-install message now cover Label objects (Creality Print and Orca paths), the blocking M109 requirement, machine start gcode replacement with verification step (`grep EXCLUDE_OBJECT_DEFINE|LINE_PURGE` on sliced output), and failure modes for both pieces.

- **Slicer templates ship in-tree.** `features/kamp-adaptive-purge/slicer-templates/`:
  - `creality-print-machine-start.gcode` — verified on Creality Print 7.1.1
  - `orca-machine-start.gcode` — Orca template (unverified — `bed_type` strings need confirming against your Orca profile)

## Verified

- Bootstrap auto-detect on 1.1.5.2 — correctly skips the 1.1.3.13-specific prompt
- Extras-only flow on 1.1.5.2 — clones to sibling path, banner displays correctly, reduced menu shows only safe items, hidden items show "Disabled in extras-only mode" message
- Path-based safeguard on 1.1.5.2 — `sh menu.sh` from `-extras` dir without env var still triggers extras-only mode
- Existing `/mnt/UDISK/k2-improvements/` install left untouched after `--extras-only` run
- KAMP install with firmware retraction prompt — fires when `[firmware_retraction]` is absent, skipped silently when present, expanded post-install message displays
- KAMP install non-interactive — skip prompt cleanly, hint about how to enable later

## Verified by inspection only

- 1.1.3.13 + existing Jacob install auto-detect prompt — code path verified by inspection; no 1.1.3.13 printer available for live test
- Firmware-based force in `main_menu` for 1.1.3.13 — same coverage level

## Upgrade path

Existing users on v1.0.x can update via the menu:

- **8. Update installer** in any menu — does `git pull` in the install dir

Or re-run bootstrap (idempotent):

```bash
curl -sSL https://raw.githubusercontent.com/erondiel/k2-improvements/main/bootstrap.sh \
  | sh -s -- <printer-ip>
```

## Commits since v1.0.1

- `17aa380` bootstrap: auto-detect existing Jacob install, single command for all users
- `35b58aa` kamp-adaptive-purge: optional firmware retraction + expanded slicer setup
- `23029ab` bootstrap + menu: add extras-only mode for 1.1.3.13 users
- `c018220` kamp-adaptive-purge: add slicer-templates/ with CP + Orca start gcode
- `a6d96ae` kamp-adaptive-purge: expand slicer setup docs

## Known issues

- **Cartographer V4 mid-print USB disconnects on 1.1.5.2** are still under investigation (see `CLAUDE.md` § "Cartographer V4 mid-print USB disconnects" in the printers-repo working notes). Two failure modes characterized: bridge daemon stuck on stale fd (recovers via `FIRMWARE_RESTART`) and full enumeration failure (requires mains power-cycle). Mechanical-disturbance correlation is the active lead.
- **`motor-state-guard`** still UNTESTED. Excluded from `Install essentials`, available in Extras with prominent UNTESTED warning.
- **Cartographer firmware flash (item 6)** and **USB-stick printer-firmware prep (item 7)** still UNTESTED.
