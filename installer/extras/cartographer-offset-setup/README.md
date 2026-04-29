# jimmyv-mount

Cartographer config overrides for the [JimmyV community back-mount
adapter](https://www.printables.com/model/944244-jimmyv-cartographer-survey-mount-for-creality-k2-p)
on the K2 Plus.

## What problem does this solve?

The default Cartographer mount on the K2 Plus places the probe
right next to the nozzle. The JimmyV mount relocates the probe
~36mm behind the nozzle so it has line-of-sight to the bed when
the toolhead nears the front edge, and so it doesn't collide with
the silicone wipe pad.

But Klipper still thinks the probe is at `y_offset: 0`, so:
- Z heights from probing get applied at the wrong Y position.
- Bed mesh probing crashes the back of the toolhead because it
  tries to reach areas the back-mounted probe physically cannot.
- Y axis position-min and endstop are slightly off because the
  effective Y travel changes.

## What this patches

`custom/cartographer.cfg` — six values, in three sections:

| Section          | Key                | New value     |
| ---              | ---                | ---           |
| `[cartographer]` | `x_offset`         | `0`           |
| `[cartographer]` | `y_offset`         | `36`          |
| `[bed_mesh]`     | `mesh_min`         | `10, 5`       |
| `[bed_mesh]`     | `mesh_max`         | `340, 330`    |
| `[stepper_y]`    | `position_endstop` | `-0.4`        |
| `[stepper_y]`    | `position_min`     | `-0.4`        |

All other config values are untouched.

## Idempotency / safety

- Re-running this install does nothing if `y_offset` is already 36
  and `mesh_min` is `10, 5`.
- Original file is backed up to `cartographer.cfg.before-jimmyv-<timestamp>`.
- Bails out with a clear error if `[cartographer]`, `[bed_mesh]`, or
  `[stepper_y]` sections are missing from the file.

## Activation

Klipper picks up the change on next `FIRMWARE_RESTART`. Per K2 Plus
motor-state caveat, power-cycle from mains before the next G28.

## When NOT to install this

- You're running the stock side-mount Cartographer (not the JimmyV
  back-mount). Values are wrong for your hardware.
- You have a different community mount with different offsets — pick
  the matching values for your specific mount, this is JimmyV-specific.
