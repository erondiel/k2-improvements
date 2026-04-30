# motor-state-guard

> [!WARNING]
> **UNTESTED — DO NOT RELY ON THIS FEATURE WITHOUT VERIFYING IT FIRST.**
>
> The detection mechanism (tmpfs marker file, `delayed_gcode` handshake, `G28` wrap via `rename_existing`) has not been verified end-to-end on a live K2 Plus. The code below describes the intended behavior; the actual flow has not been observed working.
>
> If the guard fails to engage, your printer is in the same risk profile as without it: `G28` after a klippy-only restart may invert Y and crash the toolhead into the back frame.
>
> Install only if you understand and accept this risk and are willing to test the guard yourself (a structured 7-step test is described at the bottom of this README) before relying on it. Pull requests with verification logs are welcome.

Prevents `G28` from running when the K2 Plus motor wrapper's state may be stale after a Klipper-only restart.

## What problem does this solve?

The K2 Plus's proprietary motor wrapper (`motor_control_wrapper.cpython-39.so` plus the external Serial_485 motor controllers at addresses `0x81`–`0x84`) retains direction state across `klippy` restarts. After any of:

- `SAVE_CONFIG` (which triggers an internal `RESTART`)
- Manual `RESTART`
- `FIRMWARE_RESTART`
- `/etc/init.d/klipper restart`

…without a mains power-cycle, the next `G28 Y` has been observed to home in the **wrong direction**, driving the toolhead into the back frame. Confirmed on K2 Plus firmware 1.1.5.2 with Cartographer V4 (2026-04-28).

The wrapper's full re-init handshake only runs on a real boot. None of the wrapper's exposed gcode commands (`MOTOR_STALL_MODE`, `MOTOR_BOOT`, `RESET_HOME_AXES_XY`, `MOTOR_CLEAR_ERR_WARN_CODE`) reproduce the cure from a running Klipper — empirically tested.

This feature can't fix the underlying bug (it lives in closed Creality code), but it prevents the crash by refusing to home until the user has actually power-cycled.

## How it works

1. `[save_variables]` is configured to use a file in `/tmp` (tmpfs — wiped on real boot, persists across `klippy` restart).
2. A `[delayed_gcode]` runs 0.1s after Klipper start, checks for a marker variable in that file.
   - **Marker absent** (real boot just happened, `/tmp` was wiped): the guard sets motor-state to safe.
   - **Marker present** (klippy-only restart, `/tmp` survived): the guard sets motor-state to uncertain and prints a console warning.
3. The marker is then written, so the *next* restart sees it.
4. `G28` is wrapped via `rename_existing: G28.1`. If motor-state is uncertain, `G28` raises an error pointing the user at the cause and at `POWER_CYCLED_OK` (the manual override).

## UX

- **After a real power-cycle**: zero friction. `G28` works as normal.
- **After `SAVE_CONFIG` / `RESTART` / `FIRMWARE_RESTART`**: `G28` is blocked. User power-cycles (recommended) or runs `POWER_CYCLED_OK` if they understand the risk.

## Conflicts

The feature defines `[save_variables]` and overrides `[gcode_macro G28]` via `rename_existing`. The install script bails out loudly if either is already defined elsewhere in your config — manual merge required in that case (see install.sh comments).

The `[save_variables] filename` MUST live in `/tmp` for the boot-detection to work. If you have an existing `save_variables` you want to keep using for other variables, you'll need to either redirect it to `/tmp` (acceptable if you don't care about persistence across reboots) or remove the `[save_variables]` block from this feature and find a different boot-detection method (e.g. `[gcode_shell_command]` to touch a marker file).

## Install

```sh
sh /mnt/UDISK/root/k2-improvements/features/motor-state-guard/install.sh
```

The installer does **not** restart Klipper automatically — restarting Klipper is the very condition this guard exists to detect, so the user should restart at their own convenience and then power-cycle to clear the (now-active) guard.

## Related upstream work

The same `gimme-the-jamin.sh` includes this feature when running on `firmware-1.1.5.2-compat` (because the K2 Plus motor-state issue is reproducible there). For other firmwares it's available as opt-in.
