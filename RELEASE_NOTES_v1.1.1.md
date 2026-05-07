# v1.1.1 — bootstrap detection fix for 1.1.3.13 users

Patch release. Fixes a detection gap in the v1.1.0 auto-detect logic that could miss an existing Jacob10383 install if it was at `/mnt/UDISK/root/k2-improvements/` (a real directory, not a symlink) instead of `/mnt/UDISK/k2-improvements/`. The miss would silently route a 1.1.3.13 user with a working Jacob install through the default re-install path instead of offering the extras-only prompt.

## What changed

`bootstrap.sh` now probes **both** plausible install paths and one config-file fallback:

1. `/mnt/UDISK/k2-improvements/` (our convention, also where the symlink target points)
2. `/mnt/UDISK/root/k2-improvements/` (Jacob's `~/k2-improvements/` after `better-root` sets `HOME=/mnt/UDISK/root`)
3. **Fallback**: parse `~/printer_data/config/moonraker.conf` for `[update_manager k2-improvements]` block; expand `~` if used; verify the path has a Jacob10383-pointing `.git/config`.

If any of the three locates a Jacob-flagged repo, the auto-detect prompt fires and the prompt now shows the actual detected path (instead of hardcoding `/mnt/UDISK/k2-improvements/`).

## Why

We have no direct insight into Jacob's printer-side bootstrap (it's distributed via flashed firmware images, not in his git repo). His feature scripts reference `~/k2-improvements/`, so the canonical location after `better-root` is `/mnt/UDISK/root/k2-improvements/`. On a printer that went through Jacob's flow exclusively, the repo could legitimately live there as a real directory with no symlink at `/mnt/UDISK/k2-improvements/`. v1.1.0 only checked the latter and would silently miss the install.

## Verified

- Detection logic dry-run on a 1.1.5.2 + erondiel-installed printer correctly returns "no Jacob install" (the install is from erondiel, not Jacob, so neither the git-config grep nor moonraker.conf match triggers)
- Shell quoting works under busybox ash (the printer's shell)
- bootstrap.sh syntax clean in sh + dash

The 1.1.3.13 + Jacob-install detection success path is verified by inspection only (no Jacob-only printer available for live test). Same coverage level as v1.1.0's prompt logic.

## Upgrade

Same as v1.1.0:

```bash
curl -sSL https://raw.githubusercontent.com/erondiel/k2-improvements/main/bootstrap.sh \
  | sh -s -- <printer-ip>
```

Or update an existing install via menu item **8. Update installer**.

## Commits since v1.1.0

- `<this-commit>` bootstrap: harden 1.1.3.13 install detection (2 paths + moonraker.conf fallback)
