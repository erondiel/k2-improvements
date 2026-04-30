# surface-selection-wrapper

Adds a `SURFACE=` parameter to `START_PRINT` so the slicer can tell the
printer which build surface is on the bed; `START_PRINT` then loads the
matching Cartographer scan and touch models automatically.

## What it patches

The k2-improvements `START_PRINT` macro (lives in
`features/macros/start_print/start_print.cfg`, symlinked into
`custom/start_print.cfg`).

A small block is inserted just before the preheat step, bracketed by
markers so the patch is self-locating on re-runs:

```
  # === BEGIN surface-selection wrapper ===
  {% set SURFACE = params.SURFACE|default('default')|lower %}
  CARTOGRAPHER_SCAN_MODEL LOAD={SURFACE}
  CARTOGRAPHER_TOUCH_MODEL LOAD={SURFACE}
  # === END surface-selection wrapper ===
```

## Why

Without this, the printer always uses the default Cartographer
scan/touch model regardless of which plate is on the bed. With
multiple calibrated profiles (PEI, coolplate, etc.), Z height is wrong
when you swap plates and forget to manually `CARTOGRAPHER_SCAN_MODEL
LOAD=...`.

## Slicer side

Pass `SURFACE=<name>` from your machine start gcode. Suggested
Creality Print machine start gcode (matches the K2 Plus calibrated
plates on the canonical setup):

```
{if curr_bed_type=="Customized Plate"}
START_PRINT EXTRUDER_TEMP=... BED_TEMP=... ... MATERIAL=... SURFACE=coolplate
{else}
START_PRINT EXTRUDER_TEMP=... BED_TEMP=... ... MATERIAL=... SURFACE=pei
{endif}
```

If `SURFACE=` is omitted, the wrapper falls back to `default`.

## Idempotency / safety

- Re-running this install does nothing if the BEGIN/END markers are
  already in the file.
- Original file is backed up to
  `start_print.cfg.before-surface-wrapper-<timestamp>` before patching.
- If the upstream macros file changes structure (the anchor `STATUS_MSG
  ... MSG="Preheating ...` disappears), the install bails out with a
  clear error rather than corrupting the file.

## Activation

Klipper picks up the change on next `FIRMWARE_RESTART`. Per K2 Plus
motor-state caveat, power-cycle from mains before the next G28.

## Re-applying after `git pull`

The wrapper lives in the upstream macros file. A `git pull` in
`/mnt/UDISK/k2-improvements` would clobber it. After pulling, re-run
this install to put the wrapper back. The detection is symmetric — if
the marker isn't there, it'll re-insert; if it is, it's a no-op.
