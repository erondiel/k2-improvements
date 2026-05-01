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

KAMP needs three things from the slicer to work correctly:

1. **"Label objects" must be ON** — `LINE_PURGE` reads the print's bbox from `[exclude_object]` polygons, which only get emitted when the slicer labels each object.
2. **The hardcoded purge block in the machine start gcode must be replaced with `LINE_PURGE`.**
3. **The nozzle must be at full print temperature before `LINE_PURGE` runs.** The standard Creality Print start gcode uses non-blocking `M104` to set temp; you need a blocking `M109` before `LINE_PURGE` or the purge fires while the nozzle is still heating.

### Creality Print

Verified on Creality Print 7.1.1.

**Step 1 — Enable "Label objects"**

Process settings panel (left sidebar) → search box at the top → type `label` → toggle **Label objects** ON.

The setting moves between tabs across versions:
- 7.x: Process settings → **Others** tab
- Some 5.x/6.x builds: Quality → Advanced
- Older builds: Printer settings → "Use exclude_object"

The search box is the reliable way regardless of version.

**Step 2 — Replace the machine start gcode**

Printer profile (gear icon next to the printer profile) → **Machine G-code → Machine start G-code**. Replace the entire block with the K2 Plus version: see [`k2plus/slicer/creality-print-machine-start.gcode`](https://github.com/erondiel/printers/blob/main/k2plus/slicer/creality-print-machine-start.gcode) in the printers repo (or copy from the snippet below).

What changed from stock Creality Print machine start gcode:
- Removed leading `M140 S0` / `M104 S0` — `START_PRINT` re-enables them immediately, so they were just noise.
- Removed the static `G1 X0 Y0 E9 ...` purge from both the `{if multicolor_method}` and `{else}` branches.
- Added `M109 S[nozzle_temperature_initial_layer]` (blocking — waits for actual print temp) before `LINE_PURGE` in both branches. **Critical:** without this, the purge can fire while the nozzle is still heating because `START_PRINT` only sets the warm-up temp via M104.
- Replaced the static purge with `LINE_PURGE`.

Snippet of the changed section (full file is in the printers repo):

```
{if multicolor_method}
... [existing multicolor flush + wipe sequence stays unchanged]
M8200 O
M204 S2000
M83
M109 S[nozzle_temperature_initial_layer]
LINE_PURGE
{else}
T[initial_no_support_extruder]
M204 S2000
M83
M109 S[nozzle_temperature_initial_layer]
LINE_PURGE
{endif}
```

### Orca / OrcaSlicer

Orca uses different placeholder names from Creality Print (`bed_type` instead of `curr_bed_type`, etc.). The principle is identical — Label objects ON, replace the static purge with `LINE_PURGE`, blocking `M109` before purge.

**Step 1 — Enable "Label objects"**

Process tab (right panel) → **Quality → Advanced** → toggle **Label objects** ON. Some Orca builds expose it as **"Use exclude_object"** with the same effect.

**Step 2 — Machine start gcode**

Printer settings (gear next to printer profile) → Machine G-code → Machine start G-code:

```
{if bed_type=="Custom"}
START_PRINT EXTRUDER_TEMP=[nozzle_temperature_initial_layer] BED_TEMP=[bed_temperature_initial_layer_single] CHAMBER_TEMP=[chamber_temperature] MATERIAL={filament_type[initial_extruder]} SURFACE=coolplate
{else}
START_PRINT EXTRUDER_TEMP=[nozzle_temperature_initial_layer] BED_TEMP=[bed_temperature_initial_layer_single] CHAMBER_TEMP=[chamber_temperature] MATERIAL={filament_type[initial_extruder]} SURFACE=pei
{endif}

T[initial_extruder]
M204 S2000
M83
M109 S[nozzle_temperature_initial_layer]
LINE_PURGE
```

The exact `bed_type` strings depend on the bed types defined in your Orca K2 Plus profile — verify by slicing each plate type once and grepping the output `.gcode` for `; bed_type =` to see the literal string Orca emits.

### Verification (both slicers)

After slicing your test print, before sending to the printer, open the `.gcode` in a text editor and confirm:

```bash
head -100 sliced.gcode | grep -E "EXCLUDE_OBJECT_DEFINE|LINE_PURGE"
```

Expected output:
- One `EXCLUDE_OBJECT_DEFINE NAME=... POLYGON=[[...]]` line per object on the plate — proves Label objects worked.
- `LINE_PURGE` appears in the start block — proves the machine start gcode change took effect.

Failure modes:
- **No `EXCLUDE_OBJECT_DEFINE` lines** → "Label objects" is OFF (or named differently in your slicer build). `LINE_PURGE` will fall back to a static behavior at bed origin — same problem you started with.
- **No `LINE_PURGE` line** → the machine start gcode change didn't save, or you're slicing under a different printer profile than the one you edited.

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
