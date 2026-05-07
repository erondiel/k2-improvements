# v1.1.2 — Cartographer precondition guards on extras + bootstrap

Patch release. Adds two safety guards so users who try to install Cartographer-dependent extras without Cartographer present get a clear error up front instead of mysterious runtime failures later.

## What changed

### 1. `surface-selection-wrapper` install now checks for `[cartographer]`

`cartographer-offset-setup` and `cartographer-macros` already had this check. `surface-selection-wrapper` was the holdout — it would silently patch `START_PRINT` to call `CARTOGRAPHER_SCAN_MODEL LOAD=...` and `CARTOGRAPHER_TOUCH_MODEL LOAD=...`, which then errored every time `START_PRINT` ran on a printer without Cartographer.

The install script now greps the config tree for `[cartographer]` before patching. On miss:

```
ERROR: no [cartographer] section found in printer config.
       This wrapper patches START_PRINT to call CARTOGRAPHER_*
       commands, which need Cartographer installed first.
       Install via Jacob10383's gimme-the-jamin.sh or the menu's
       'Install Essentials' before adding this extra.
```

### 2. `bootstrap.sh --extras-only` now warns when no Cartographer detected

If the user explicitly passes `--extras-only` (force-mode) and we can't find a `[cartographer]` section anywhere in the printer's config, bootstrap warns and prompts before continuing:

```
W: --extras-only forced but no [cartographer] section found in printer config.
W:
W:   Most extras require Cartographer to already be installed:
W:     - surface-selection-wrapper  (patches START_PRINT to call CARTOGRAPHER_*)
W:     - cartographer-offset-setup  (edits [cartographer] x_offset / y_offset)
W:     - cartographer-macros        (CARTO_* macros wrap CARTOGRAPHER_*)
W:
W:   These extras work standalone:
W:     - KAMP (adaptive purge)
W:     - motor-state-guard (UNTESTED)
W:     - prtouch-cleanup

Continue anyway? [y/N]
```

Default is "no" — the safer choice. The check is skipped when `EXTRAS_ONLY` was set by the auto-detect prompt (1.1.3.13 + existing Jacob install path), since that path already verified an install exists.

## Verified

- Probe runs cleanly under busybox ash on K2 Plus 1.1.5.2 (positive: detects existing `[cartographer]`; negative: handles missing files without `set -e` aborting)
- bootstrap.sh + surface-selection-wrapper/install.sh syntax clean in sh + dash
- Auto-detect path (1.1.3.13 + existing Jacob install) unaffected — `EXTRAS_OVERRIDE=0` skips the new check

## Upgrade

Same as previous releases:

```bash
curl -sSL https://raw.githubusercontent.com/erondiel/k2-improvements/main/bootstrap.sh \
  | sh -s -- <printer-ip>
```

Or update an existing install via menu item **8. Update installer**.
