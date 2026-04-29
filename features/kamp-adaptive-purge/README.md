# kamp-adaptive-purge

Installs [KAMP](https://github.com/kyleisah/Klipper-Adaptive-Meshing-Purging)'s adaptive line-purge for the K2 Plus, replacing the hardcoded slicer-side purge line that lives at the front-left bed corner.

## What problem does this solve?

The default Creality Print machine start gcode draws an L-shaped purge line at `(X0, Y150) → (X0, Y0) → (X150, Y0)`. On a K2 Plus with the JimmyV back-mount Cartographer overrides (`mesh_min: 5, 36`), most of that purge sits *outside* the bed mesh region:

- `Y < 36` is below mesh — Klipper extrapolates Z. If the front of the bed is high (typical), the nozzle drags or grazes the bed during purge.
- `X = 0` is below `mesh_min_x = 5` — same extrapolation issue.

This feature replaces the hardcoded purge with KAMP's `LINE_PURGE` macro, which:

1. Reads the print's polygon coordinates from `[exclude_object]` (Creality Print emits `EXCLUDE_OBJECT_DEFINE` blocks automatically — confirmed on test slices).
2. Computes a purge line just outside the print's bbox but inside the bed bounds.
3. Uses the configured `purge_margin` to keep the purge clear of the print and inside the mesh.

Small prints get short purges, large prints get long ones — no wasted filament, no off-mesh collisions.

## What gets installed

- KAMP repo cloned to `$HOME/Klipper-Adaptive-Meshing-Purging` (= `/mnt/UDISK/root/Klipper-Adaptive-Meshing-Purging` on K2 Plus).
- `Line_Purge.cfg` symlinked from KAMP into `custom/` (gets KAMP updates via `git pull` in the repo).
- `kamp_settings.cfg` copied (not symlinked) into `custom/` — K2 Plus-tailored defaults; survives KAMP repo updates intact.
- `exclude_object.cfg` (one-line `[exclude_object]` block) into `custom/`, only if no existing `[exclude_object]` is defined elsewhere.
- All three included from `custom/main.cfg`.

`Smart_Park.cfg` and `Adaptive_Meshing.cfg` from KAMP are intentionally **not** installed:

- Smart Park's heat-soak/parking conflicts with the heat-soak logic already in k2-improvements' `START_PRINT`.
- Adaptive_Meshing.cfg targets stock Klipper bed_mesh; the K2 Plus's Cartographer plugin already does adaptive meshing via `BED_MESH_CALIBRATE PROFILE=adaptive ADAPTIVE=1` (called from `START_PRINT`).

## Slicer change required

After installing on the printer, edit your Creality Print **machine start gcode** and replace the hardcoded purge block with a single `LINE_PURGE` call. Find this in the `{else}` (single-color) branch near the bottom:

```
G1 Y150 F12000
G1 X0 F12000
G1 Z0.2 F600
G1 X0 Y150 F6000
G1 E0.8 F300
G1 X0 Y0 E9 F{filament_max_volumetric_speed[initial_extruder]/0.3*60}
G1 X150 Y0 E9 F{filament_max_volumetric_speed[initial_extruder]/0.3*60}
G92 E0
G1 Z1 F600
```

Replace with:

```
LINE_PURGE
```

Same change in the `{if multicolor_method}` branch — replace its trailing purge G1 block with `LINE_PURGE`.

## Tuning

Edit `custom/kamp_settings.cfg` to change defaults, or override individual variables in `custom/overrides.cfg` to keep the changes through reinstalls. Key knobs:

| Variable | Default | What it does |
| --- | --- | --- |
| `variable_purge_height` | `0.4` | Z position during purge. Lower = better adhesion but risk if mesh is off. |
| `variable_purge_margin` | `10` | mm in front of print's bbox. Increase if mesh-edge collisions still happen. |
| `variable_purge_amount` | `25` | mm of filament purged. Increase for color changes or PETG. |
| `variable_flow_rate` | `12` | mm³/s during purge. Default — usually fine. |

## Edge case to watch

If you slice prints aligned to the very front of the bed (Y_min ≤ 45), the purge can land at `Y < 36` (below mesh). Workarounds:
- Increase `variable_purge_margin` further (less likely to be needed).
- Center the print on the bed (Creality Print's "auto-arrange" usually does this).
- Or accept the risk — bed-mesh extrapolation just outside the mesh edge is usually within 0.2mm of correct.

## Install

```sh
sh /mnt/UDISK/root/k2-improvements/features/kamp-adaptive-purge/install.sh
```

Idempotent — re-runs pull KAMP updates and refresh the symlinks. Does **not** restart Klipper. Restart manually when convenient (and remember the K2 Plus power-cycle caveat after restart).

## Credits

KAMP itself is by Kyle Isom — [github.com/kyleisah/Klipper-Adaptive-Meshing-Purging](https://github.com/kyleisah/Klipper-Adaptive-Meshing-Purging). This feature is just a thin install/configure wrapper for K2 Plus.
