# v1.1.3 — Extras menu now greys out items that require Cartographer

Patch release. UX improvement that makes the Cartographer dependency visible at menu render time, instead of waiting for the install script to refuse later.

## What changed

The Extras menu now shows three states per item:

| State | Marker | When |
|---|---|---|
| Installed | `[X]` (green) | The detector function returns true |
| Available | `[ ]` (dim) | Not installed, but precondition met |
| **Blocked** | **`[!]` (yellow) `(needs Cartographer)`** | **Not installed, precondition missing** |

The 3 Cartographer-dependent extras (`surface-selection-wrapper`, `cartographer-offset-setup`, `cartographer-macros`) gate on `is_cartographer` — the same software check used elsewhere (greps `[cartographer]` across the Klipper config tree).

Picking a blocked `[!]` item shows a friendly refusal screen explaining what's needed and how to install Cartographer (menu item 2 / 3, or Jacob10383's `gimme-the-jamin.sh` on 1.1.3.13). The install script itself is not run.

The 2 Cartographer-independent extras (`prtouch-cleanup`, `motor-state-guard`) have no precondition and continue to behave as before.

## Implementation

`installer/menus/extras.sh`:

- The `_EXTRAS` table now has an optional 5th field `requires` — the name of a function that must return true for the extra to be installable. Empty for no precondition.
- `menu_extras` checks the requires_function on each render; mismatched precondition triggers the yellow `[!]` rendering.
- `install_extra` checks the same precondition and refuses to launch the install script with a per-precondition explanation (e.g. "needs Cartographer" → install via menu items 2/3 or gimme-the-jamin.sh).
- A small `_extras_requires_label` helper maps function names to human-readable labels so the menu hint stays user-friendly.

## Verified

Live on K2 Plus 1.1.5.2 with `is_cartographer` temporarily forced to false: yellow `[!]` marks render correctly on the 3 Cartographer-dependent extras with `(needs Cartographer)` hint; refusal screen shows when picked; install script is NOT run.

## Upgrade

```bash
curl -sSL https://raw.githubusercontent.com/erondiel/k2-improvements/main/bootstrap.sh \
  | sh -s -- <printer-ip>
```

Or update an existing install via menu item **8. Update installer**.
