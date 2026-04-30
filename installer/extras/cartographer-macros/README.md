# cartographer-macros

Wraps the most-used `CARTOGRAPHER_*` plugin commands in `[gcode_macro]`
blocks so they show up as buttons in Fluidd's Macros panel. Without
this, those commands only run via the console (which is fine but slow
to type and easy to mistype the plate name).

## Why a wrapper layer

`CARTOGRAPHER_CALIBRATE`, `CARTOGRAPHER_TOUCH_CALIBRATE`,
`CARTOGRAPHER_SCAN_MODEL LOAD=...`, etc. are commands registered by
the Cartographer Klipper plugin — not `[gcode_macro]` definitions.
Fluidd's macros panel only lists `[gcode_macro]` blocks, so plugin
commands don't appear there. This file adds a thin macro per command
that just calls through.

## Naming / grouping

Every macro in this file is prefixed `CARTO_`. Fluidd sorts macros
alphabetically, so they cluster together at the top of the panel.

## What you get

| Macro | Calls |
| --- | --- |
| `CARTO_CALIBRATE_DEFAULT` | `CARTOGRAPHER_CALIBRATE METHOD=manual NAME=default` |
| `CARTO_CALIBRATE_PEI` | `CARTOGRAPHER_CALIBRATE METHOD=manual NAME=pei` |
| `CARTO_CALIBRATE_COOLPLATE` | `CARTOGRAPHER_CALIBRATE METHOD=manual NAME=coolplate` |
| `CARTO_TOUCH_CAL_DEFAULT` | `CARTOGRAPHER_TOUCH_CALIBRATE NAME=default` |
| `CARTO_TOUCH_CAL_PEI` | `CARTOGRAPHER_TOUCH_CALIBRATE NAME=pei` |
| `CARTO_TOUCH_CAL_COOLPLATE` | `CARTOGRAPHER_TOUCH_CALIBRATE NAME=coolplate` |
| `CARTO_LOAD_DEFAULT` | scan + touch model load (default) |
| `CARTO_LOAD_PEI` | scan + touch model load (pei) |
| `CARTO_LOAD_COOLPLATE` | scan + touch model load (coolplate) |
| `CARTO_TOUCH_HOME` | `CARTOGRAPHER_TOUCH_HOME` (Z-ref via touch) |
| `CARTO_LIST_MODELS` | List all saved scan + touch models |
| `CARTO_INFO` | `CARTOGRAPHER_GET_INFO` (firmware/HW info) |

## Adding plates

If you have a build plate beyond default/pei/coolplate, copy one of
the existing `[gcode_macro CARTO_*_<plate>]` blocks and rename. Or
override in `custom/overrides.cfg` to keep the change through
reinstalls.

## Activation

Klipper picks up the macros on next `FIRMWARE_RESTART`.
