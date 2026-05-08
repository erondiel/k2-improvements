# v1.1 — Single-command install + 1.1.3.13 extras + UX hardening

Major UX iteration on top of v1.0. **Single command for every user** — bootstrap now auto-detects firmware, existing-install state, and where it's running from, and does the right thing with no flags needed.

## Headline features

### 1. Single command for everyone

```bash
# with curl:
curl -sSL https://raw.githubusercontent.com/erondiel/k2-improvements/main/bootstrap.sh | sh -s -- <printer-ip>

# with wget (K2 Plus shells default to wget):
wget -qO- https://raw.githubusercontent.com/erondiel/k2-improvements/main/bootstrap.sh | sh -s -- <printer-ip>
```

Auto-detect routing:

| Detected state | Behavior |
| --- | --- |
| **1.1.5.2** (fresh or update) | Erondiel full install |
| **1.1.3.13**, no existing install | Routes to Jacob10383 + applies portable bug-fixes |
| **1.1.3.13**, existing Jacob install | Asks "Add extras only? [Y/n]" — defaults yes; on yes, clones to sibling path and shows reduced menu |
| Other firmware | Prompts user (existing v1.0 behavior) |

Power-user override flags: `--extras-only`, `--full`, `--auto-launch`, `--test-jacob`.

### 2. Extras-only mode for 1.1.3.13 users

1.1.3.13 users with a working Cartographer install via Jacob10383 can now add the K2-Plus extras (KAMP, surface-selection-wrapper, cartographer-offset-setup picker, cartographer-macros) **on top of their existing install**, without touching it. **Three independent safety layers**:

1. **Sibling-path clone** — extras-only clones to `/mnt/UDISK/k2-improvements-extras/`, never touches `/mnt/UDISK/k2-improvements/`
2. **`menu.sh` path-based safeguard** — auto-sets extras-only mode when launched from a `-extras` directory, even without the env var
3. **Firmware-based force** — `main_menu` checks printer firmware at runtime; on 1.1.3.13 it forces extras-only mode regardless

The reduced menu hides Install-essentials, Features, and the firmware-flash items. Pressing them shows "Disabled in extras-only mode."

Existing-install detection probes three locations to handle both Jacob's and our path conventions: `/mnt/UDISK/k2-improvements/`, `/mnt/UDISK/root/k2-improvements/`, plus a `moonraker.conf` `[update_manager k2-improvements]` block as fallback.

### 3. Local-mode (run bootstrap on the printer itself)

When `PRINTER_IP` matches localhost / 127.0.0.1 / a local interface / hostname, bootstrap detects "I'm on the target" and **skips SSH entirely** — runs commands directly. No SSH, no sshpass, no expect wrapper, no password prompts. Faster (no network roundtrip per command), and sidesteps the dropbear / curl-pipe-stdin chain entirely.

```bash
# from the printer's shell:
ssh root@<printer-ip>
wget -qO- https://raw.githubusercontent.com/erondiel/k2-improvements/main/bootstrap.sh | sh -s -- localhost
```

### 4. Cartographer precondition system

Three layers of "you need Cartographer first" guidance for users without Cartographer installed:

- **Install scripts** refuse with clear errors when `[cartographer]` is missing from the Klipper config tree (`surface-selection-wrapper`, `cartographer-offset-setup`, `cartographer-macros`)
- **Bootstrap** warns when `--extras-only` is forced without `[cartographer]` detected, with per-extra dependency breakdown
- **Extras menu** greys out blocked items with yellow `[!] (needs Cartographer)`. Picking a blocked item shows a refusal screen with guidance toward menu items 2/3 or `gimme-the-jamin.sh`

| State | Marker |
|---|---|
| Installed | `[X]` (green) |
| Available | `[ ]` (dim) |
| **Blocked** | **`[!]` (yellow) `(needs Cartographer)`** |

`prtouch-cleanup` and `motor-state-guard` have no preconditions and behave as before.

### 5. KAMP improvements

- **Optional Klipper firmware retraction during install** — silences the LINE_PURGE warning, gives one place to tune retraction. Opt-in prompt with conservative PLA defaults; skipped silently if `[firmware_retraction]` already exists or running non-interactively.
- **Drop-in machine start gcode templates** ship in `features/kamp-adaptive-purge/slicer-templates/`:
  - `creality-print-machine-start.gcode` — verified on Creality Print 7.1.1
  - `orca-machine-start.gcode` — Orca template (unverified; `bed_type` strings may need adjustment per profile)
- **Comprehensive slicer setup docs** addressing the most common "I installed KAMP but it doesn't work" failure mode: Label objects toggle paths for both slicers, blocking M109 requirement, machine-start-gcode walkthrough, and verification with `grep EXCLUDE_OBJECT_DEFINE|LINE_PURGE` on sliced output.

### 6. UX polish

- **Startup banner** so users see immediate feedback after pasting the curl/wget one-liner (no more "is it frozen?" moments)
- **Bold-cyan launch command** in both the "Bootstrap complete" banner and the test-mode summary — the next-step action is unmistakable
- **`Launch the menu now? [Y/n]` prompt** at the end of a local-mode install (default yes; auto-skip on non-TTY)
- **`--auto-launch` flag** for one-shot install-and-go workflows — skips the prompt and execs the menu directly. Works in both local-mode (clean exec) and SSH-from-PC (allocates `-t` TTY for the menu over SSH).

### 7. Testing infrastructure

- **`--test-jacob` flag** simulates a 1.1.3.13 + Jacob install in `/tmp` so the auto-detect prompt and routing logic can be tested without real hardware. Forces local-mode, stages a fake Jacob install, redirects clone destination to `/tmp/k2-test-...`, then exits with a routing-decision summary. Skips destructive operations (Entware install, opkg, unslung hook).
- Test mode also performs the git clone (harmless to `/tmp`), so users can launch `menu.sh` afterwards to see the actual extras menu.
- Composes with `--auto-launch` for a one-line full-flow smoke test:
  ```bash
  wget -qO- https://raw.githubusercontent.com/erondiel/k2-improvements/main/bootstrap.sh \
    | sh -s -- --test-jacob --auto-launch
  ```

## Robustness improvements (foundation work)

The bigger UX stories above sit on top of substantial robustness work that's invisible when things go right but critical when they don't. Highlights:

- **Self-heal on curl-pipe** — bootstrap detects when it's being run via `curl ... | sh` (stdin is the pipe), re-downloads itself to `/tmp`, and re-execs with `</dev/tty` so interactive prompts wait for keyboard input instead of returning empty immediately. Fixes silent termination on dropbear shells (where the SSH password prompt was eating the rest of the script as password attempts).
- **Auto-install sshpass** on the host with a default-yes prompt — opkg / apt / dnf / yum / pacman / brew detection. Eliminates the ~10 password prompts per run on hosts without sshpass.
- **Expect-based sshpass fallback** for K2 Plus Entware (armv7-3.2 doesn't ship sshpass, but does ship expect). Acts as a drop-in sshpass replacement for our use cases. Wrapper survives multiple iterations of correctness fixes (argv handling, log_user mixing, CRLF capture, dropbear `(y/n)` prompt, exit-code preservation, post-auth timeout lift).
- **Auto-refresh stale wrapper** — on every run, bootstrap detects if our expect wrapper is already at `/opt/bin/sshpass` and re-downloads it from GitHub. Ensures wrapper bug fixes reach users who installed an older version.
- **Hard-reset clone update** — if `git pull --ff-only` fails because of dirty working trees from interrupted previous runs, bootstrap falls through to `git reset --hard origin/<branch>` + `git clean -fd`. Install dirs aren't user-editable workspaces; recoverability beats preservation.
- **Download timeouts** — explicit connect/total timeouts on curl and wget in the self-heal block. No more silent multi-minute hangs on transient GitHub slowness.
- **Wget shim socket timeout** — the temporary Python wget shim (used during initial Entware bootstrap before real wget is installed) now has a 30s socket timeout. Prevents indefinite hangs if the shim sticks around as `/opt/bin/wget` instead of being replaced by real wget.

## Verified

- K2 Plus 1.1.5.2 + Cartographer V4 (full install, idempotent re-run, extras-only path, local-mode)
- K2 Plus 1.1.3.13 + Jacob10383 install — Dennis McKinney's hardware. Full extras-only install end-to-end (auto-detect prompt, routing, clone, menu launch).
- `--test-jacob` flow including `--auto-launch` exercises the routing decision + prompt + clone + menu launch on any machine

## Verified by inspection

- Most rare edge-case fallback paths are exercised by inspection rather than live tests (no test bench available for every combination of firmware × shell × network state). Core happy paths and Dennis's reported failure modes are all live-tested.

## Upgrade

Same one-liner as a fresh install:

```bash
curl -sSL https://raw.githubusercontent.com/erondiel/k2-improvements/main/bootstrap.sh | sh -s -- <printer-ip>
```

Or update an existing install via menu item **8. Update installer**.

## Patch history

24 patch releases between v1.1.0 and the current v1.1.24. Most addressed real-world failures surfaced by Dennis McKinney's testing on `K2Plus-024C` and `K2Plus-0A10` — particularly the dropbear / sshpass / curl-pipe interactions on K2 Plus shells where bootstrap originally wasn't designed to run from. Full per-commit history is in the repo's `git log`.

| Range | Theme |
| --- | --- |
| v1.1.0 – v1.1.3 | Initial v1.1 (single-command install, extras-only mode, KAMP improvements, Cartographer precondition system, menu greying) |
| v1.1.4 – v1.1.12 | Curl-pipe / sshpass / expect-wrapper hardening (~9 patches addressing the dropbear-pipe-eats-script chain end-to-end) |
| v1.1.13 | Local-mode detection — skip SSH when the target is the same machine |
| v1.1.14 – v1.1.15 | `--test-jacob` flag for testing without real hardware |
| v1.1.16 – v1.1.20 | Stability fixes (clone progress, wget-shim timeout, dirty-tree recovery, etc.) |
| v1.1.21 – v1.1.22 | Auto-launch prompt + `--auto-launch` flag |
| v1.1.23 | Test-mode supports `--auto-launch` for full-flow smoke tests |
| v1.1.24 | Self-heal download timeouts (no silent hangs on transient network issues) |

## Credits

Special thanks to **Dennis McKinney** for testing the install flow on real K2 Plus hardware and reporting the dropbear / sshpass / curl-pipe failures end-to-end. Each iteration of the patch line surfaced a new layer; without his persistence the install would be broken for any K2 Plus user trying to run from their printer's shell.

## Known issues (carried over from v1.0)

- **Cartographer V4 mid-print USB disconnects on 1.1.5.2** still under investigation. Two failure modes characterized; mechanical-disturbance correlation is the active lead.
- **`motor-state-guard`** still UNTESTED. Excluded from `Install essentials`, available in Extras with prominent UNTESTED warning.
- **Cartographer firmware flash** (item 6) and **USB-stick printer-firmware prep** (item 7) still UNTESTED.
