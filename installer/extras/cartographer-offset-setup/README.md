# cartographer-offset-setup

Sets `[cartographer] x_offset` and `y_offset` in `custom/cartographer.cfg`
to match your physical Cartographer mount.

## Why

The Cartographer probe sits on a 3D-printed mount that physically
positions it relative to the nozzle. Klipper needs to know that
distance to interpret probe readings correctly. Different community
mounts place the probe in different positions.

## Presets

| Mount | x_offset | y_offset | Notes |
| --- | ---: | ---: | --- |
| Jamin Collins front-mount | 0 | -15 | Probe 15mm in **front** of nozzle. Default for `gimme-the-jamin.sh`. [Printables link](https://www.printables.com/model/1198696-k2-plus-cartographer-mount-shroud-and-spacers) |
| JimmyV back-mount | 0 | 36 | Probe 36mm **behind** nozzle |
| Custom | user value | user value | Enter the offsets your specific mount needs |

## What this does NOT touch

`[bed_mesh]` (`mesh_min`, `mesh_max`, `zero_reference_position`, etc.)
and `[stepper_y]` (`position_endstop`, `position_min`) are general
K2 Plus values that are the same for every Cartographer mount the
community has shipped so far. The picker leaves them alone.

If you have a mount that genuinely needs different mesh limits, edit
`custom/cartographer.cfg` directly after running this picker.

## Idempotency / safety

- Picking the preset that matches your current values is a no-op.
- Backs up `custom/cartographer.cfg` to `cartographer.cfg.before-offset-<timestamp>`
  before any change.
- Custom values are validated: must parse as numbers, range -100 to +100.

## Activation

Klipper picks up the change on next `FIRMWARE_RESTART`. Per K2 Plus
motor-state caveat, power-cycle from mains before the next G28.

## Why this is NOT in "Install all"

Picking the wrong mount silently breaks Z-probing across the bed (the
probe reads at the wrong physical location). Because installer scripts
can't see your physical hardware, this picker stays manual.
