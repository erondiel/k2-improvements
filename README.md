# K2 Improvements

> [!IMPORTANT]
> **You are on branch `firmware-1.1.5.2-compat` — verified on hardware.**
>
> This branch rebases the cartographer Klipper patches onto stock firmware **1.1.5.2** (`CR0CN240110C10`, released 2026-03-31). **Installed and operational on a K2 Plus with Cartographer V4 6.0.0 as of 2026-04-28.** If you prefer the upstream-maintained experience on the older firmware, use [Jacob10383/k2-improvements `main`](https://github.com/Jacob10383/k2-improvements) on firmware 1.1.3.13.
>
> **Verified end-to-end:**
> - Clean install via `install-k2plus-1152.sh` (see [Automated installer](#automated-installer-firmware-1152-compat-only) below).
> - Klipper boots clean — no `.so` ImportErrors from the 1.1.3.13-era `cpython-39` wrappers.
> - `G28` homes correctly with the rebased `homing.py`.
> - Cartographer V4 (6.0.0 Full) — manual `CARTOGRAPHER_CALIBRATE` and `BED_MESH_CALIBRATE` complete without comms loss.
> - Multi-surface calibration: `default` / `pei` / `coolplate` scan models, touch models, and bed meshes saved and switchable via the new `START_PRINT SURFACE=…` parameter.
> - 2 full print jobs and several adaptive bed scans completed without faults.
>
> **Rebase summary (`a7479fa`, then `c3892b4` follow-up fix):**
> - 3 files rebased — `homing.py`, `mcu.py`, `serialhdl.py` — via 3-way merge (stock 1.1.3.13 ancestor, stock 1.1.5.2 Creality branch, project patches as ours).
> - 4 files byte-identical to upstream — `bed_mesh.py`, `clocksync.py`, `configfile.py`, `temperature_mcu.py` — Creality didn't touch them between 1.1.3.13 and 1.1.5.2.
> - One genuine line-level conflict at `homing.py` L43 (prtouch_v3 lookup) resolved during rebase.
> - Follow-up: rebased `homing.py` originally referenced four prtouch_v3 attributes the cartographer plugin does not expose, crashing `G28`. Fixed in [`c3892b4`](https://github.com/erondiel/k2-improvements/commit/c3892b4) with `hasattr()` guards at all four sites.
>
> **Interesting finding during the rebase:** Creality's 1.1.5.2 changes to `mcu.py` trsync-tag handling move in the **same direction** as this project's patches (both add `& 0xffffffff` masking to `state_tag`). `clocksync.py` is byte-identical across 1.1.3.13 / 1.1.4.x / 1.1.5.2 — not where the "timing issue" lives.
>
> **`.so` blobs from 1.1.3.13 era:** `box_wrapper`, `filament_rack_wrapper`, `motor_control_wrapper`, `prtouch_v*_wrapper`, `serial_485_wrapper` (all `cpython-39`) load cleanly on 1.1.5.2 — Python ABI unchanged (still 3.9). No ImportErrors observed.
>
> **Note on probe firmware for V4 users:** the "flash the K1 firmware" instruction further down this README is V3-era terminology. A K1-specific build only exists for Cartographer V2/V3 hardware (`Survey_Cartographer_K1_USB`, last at 5.1.0). **Cartographer V4 has no K1 variant** — the `flash.py` script correctly offers "V4 6.0.0 Full" (recommended for K2, 2× sampling rate) and "V4 6.0.0 Lite" (conservative fallback for timing issues). Upstream [Cartographer3D/cartographer_firmware](https://github.com/Cartographer3D/cartographer_firmware) has since published V4 6.1.0, but the project's 6.0.0 pin is a deliberate known-good for K2 — don't chase the newer version unless a Cartographer-specific bug surfaces.
>
> **Post-`SAVE_CONFIG` caveat (K2 Plus-specific, observed during validation):** the K2 Plus motor wrapper does **not** reinitialize cleanly on a Klipper-only restart. Always **power-cycle the printer at the mains** before the next `G28` after a `SAVE_CONFIG`. A Klipper-only restart followed by `G28` has inverted Y homing direction and crashed the toolhead into the back frame. Confirmed on 1.1.5.2.
>
> The `motor-state-guard` feature in this branch is a defense-in-depth safety net for this exact bug: it detects klippy-only restarts and refuses `G28` until either (a) Klipper detects a real boot via the wiped `/tmp` marker, or (b) the user runs `POWER_CYCLED_OK` to override. Empirically, no gcode command we have access to reproduces the wrapper's full re-init handshake; the safety guard prevents the crash without claiming to fix the underlying state issue.
>
> **Cartographer V4 mid-print USB disconnects (`USB_full` firmware, observed 2026-04-29):** during a long full-bed print on stock 1.1.5.2 with V4 6.0.0 Full, the Cartographer MCU dropped and auto-reconnected **4 times** without pausing or interrupting the print. On each reconnect the cartographer module reloads its **default** scan and touch profiles, overriding any `SURFACE=` selection that was active at `START_PRINT`. **The print itself is unaffected** — by the time disconnects happen, `START_PRINT` has already finished probing and Z-referencing, and all moves are baked into the sliced gcode; the runtime profile no longer drives toolhead Z. If the disconnects become more frequent or start affecting setup actions (calibration, manual probing), reflash with the **V4 6.0.0 Lite** build — it trades the 2× sampling rate for tighter TRSYNC timing margin and is the documented mitigation for this exact symptom.
>
> **Component fork lag (informational):** Jacob's `cartographer3d-plugin:k2` fork is 7 commits behind upstream (K2-specific divergence; not a bug). `fluidd:k2` is 1 behind (negligible). `moonraker:k2` is 0 behind (pure additions). None observed to cause issues.

## Live Component Status vs Mainline

[![Fluidd](https://img.shields.io/badge/dynamic/json?url=https://api.github.com/repos/fluidd-core/fluidd/compare/develop...Jacob10383:fluidd:k2&query=$.behind_by&label=Fluidd&suffix=%20commits%20behind&color=blue&style=for-the-badge&logo=github)](https://github.com/Jacob10383/fluidd/tree/k2)  
![Fluidd Last Update](https://img.shields.io/badge/dynamic/json?url=https://gist.githubusercontent.com/Jacob10383/f94d1bab6f84f53cd0a88e33c528d196/raw/fluidd-last-update.json&query=$.date&label=Last%20Synced&style=flat-square&color=gray)

[![Moonraker](https://img.shields.io/badge/dynamic/json?url=https://api.github.com/repos/Arksine/moonraker/compare/master...jacob10383:moonraker:k2&query=$.behind_by&label=Moonraker&suffix=%20commits%20behind&color=blue&style=for-the-badge&logo=github)](https://github.com/jacob10383/moonraker/tree/k2)  
![Moonraker Last Update](https://img.shields.io/badge/dynamic/json?url=https://gist.githubusercontent.com/Jacob10383/f94d1bab6f84f53cd0a88e33c528d196/raw/moonraker-last-update.json&query=$.date&label=Last%20Synced&style=flat-square&color=gray)

[![Cartographer](https://img.shields.io/badge/dynamic/json?url=https://api.github.com/repos/Cartographer3D/cartographer3d-plugin/compare/main...jacob10383:cartographer3d-plugin:main&query=$.behind_by&label=Cartographer&suffix=%20commits%20behind&color=blue&style=for-the-badge&logo=github)](https://github.com/jacob10383/cartographer3d-plugin)  
![Cartographer Last Update](https://img.shields.io/badge/dynamic/json?url=https://gist.githubusercontent.com/Jacob10383/f94d1bab6f84f53cd0a88e33c528d196/raw/cartographer-last-update.json&query=$.date&label=Last%20Synced&style=flat-square&color=gray)

*Tracks my forks vs upstream as updates happen there, not here.*

## Firmware & Cartographer Support

**Recommended Firmware:** 1.1.3.13 on `main`; **1.1.5.2 on this branch (verified on hardware 2026-04-28)**

> [!WARNING]
> 1.1.4.x is "compatabile" but the firmware itself has numerous known issues. Timing problems can be exacerbated when using Cartographer.
>
> **1.1.5.2 (this branch only):** rebased and verified on a K2 Plus with Cartographer V4 — clean Klipper boot, successful calibration, multiple completed prints and bed scans. Still a one-printer datapoint; if you hit something the original tester didn't, please open an issue with logs and consider rolling back to `main` + 1.1.3.13 while it's investigated.

**Cartographer Support:**

- Supports Cartographer v3 and v4
- Includes custom flash tool for flashing either version directly on the K2
- Includes new Cartographer plugin with custom modifications for K2 compatibility and optimizations

## DISCLAIMER

Use at your own risk, I'm not responsible for fires or broken dreams.  But you do get to keep both halves if something breaks.

## Warning

As a *heads up* these improvements are not compatible with Creality's *auto-calibration*.  In our experience we get better results through manual tuning.

## Automated installer (firmware-1.1.5.2-compat only)

This branch ships **`install-k2plus-1152.sh`** — a single SSH-driven installer that runs all the prerequisites (Entware, the safe slice of better-root, fork placement) and then invokes `gimme-the-jamin.sh` with the right `PATH`, then strips the orphan `[prtouch_v3]` SAVE_CONFIG block. It works around six undocumented gotchas that otherwise break a fresh install on stock 1.1.5.2.

Use this instead of the manual "Start Here at Bootstrap" procedure below if you're on 1.1.5.2.

**Requirements before running:**

- Stock K2 Plus on firmware 1.1.5.2 (`CR0CN240110C10`).
- Root SSH enabled (Settings → General → "Open Root", note the printer-displayed password — typically `creality_2024`).
- Cartographer probe (V3 or V4) flashed with the appropriate firmware and plugged in. Both probe revisions are supported — the installer is hardware-neutral; only the probe firmware binary you flash beforehand is hardware-specific.

**Procedure (from your workstation):**

```bash
# 1. Get the fork onto the printer (any path works; /tmp is fine)
ssh root@<printer-ip>
cd /tmp
wget --no-check-certificate -O k2.tar.gz \
    https://github.com/erondiel/k2-improvements/archive/refs/heads/firmware-1.1.5.2-compat.tar.gz
tar xf k2.tar.gz
cd k2-improvements-firmware-1.1.5.2-compat

# 2. Run the installer
sh install-k2plus-1152.sh
```

The installer is idempotent — re-running after a partial failure resumes from the next missing step.

**After it finishes:**

1. **Power-cycle the printer at the mains.** The K2 Plus motor-stall state machine does not reinitialize cleanly on a Klipper-only restart; running `G28` after a Klipper-only restart has crashed the toolhead into the back frame.
2. Open Fluidd at `http://<printer-ip>/`, verify the cartographer MCU is connected.
3. Run `CARTOGRAPHER_CALIBRATE METHOD=manual` and `BED_MESH_CALIBRATE` followed by `SAVE_CONFIG`.

For multi-surface setups, `START_PRINT` accepts a `SURFACE=<name>` parameter that loads the matching scan and touch models — see *Surface selection wrapper* below.

## Surface selection wrapper

`START_PRINT` accepts an optional `SURFACE=<name>` parameter (default `default`). When passed, it loads the matching saved Cartographer scan_model and touch_model before homing/probing, so multi-plate setups don't need separate gcode profiles.

Example slicer machine start gcode (Creality Print / Orca, auto-selecting from the bed-type dropdown):

```
{if curr_bed_type=="Customized Plate"}
START_PRINT EXTRUDER_TEMP=[nozzle_temperature_initial_layer] BED_TEMP=[bed_temperature_initial_layer_single] CHAMBER_TEMP=[overall_chamber_temperature] MATERIAL={filament_type[initial_tool]} SURFACE=coolplate
{else}
START_PRINT EXTRUDER_TEMP=[nozzle_temperature_initial_layer] BED_TEMP=[bed_temperature_initial_layer_single] CHAMBER_TEMP=[overall_chamber_temperature] MATERIAL={filament_type[initial_tool]} SURFACE=pei
{endif}
```

Calibrate each plate under its own name (e.g. `CARTOGRAPHER_CALIBRATE METHOD=manual NAME=pei`, then with `NAME=coolplate`). The macro re-meshes adaptively every print, so you don't need named bed-mesh profiles — the active scan model is what matters at probe time.

## Start Here at Bootstrap

The Bootstrap is a requirement for the improvements to install properly, so this must be accomplished first. Of note, it will install entware tools necessary to accomplish the installs. Additionally, root is enabled by default with the password: 'creality_2024'. At some point, we recommend running command 'passwd' in the terminal to change the defualt password to something secure.

It is recommend to perform a factory reset prior to install to avoid potential conflicts with previous modifications.  A factory reset can be achieved with the following command in a terminal on the K2:

```raw
echo "all" | /usr/bin/nc -U /var/run/wipe.sock
```

1. Enable root access on the K2 Plus by going to Settings, General tab and root on the physical screen. Take note of the password.
1. Download the latest bootstrap release from [https://github.com/Jacob10383/k2-improvements/releases](https://github.com/Jacob10383/k2-improvements/releases) and extract the folder.
1. To install the bootstrap, connect to your K2 Plus's Fluid interface via browser **<http://PrinterIP:4408>**
1. Unzip the downloaded bootstrap folder and upload the extracted bootstrap folder by going to Configuration **{...}**, **+**, **Upload Folder**, and selecting the extracted bootstrap folder.
    ![image](https://github.com/user-attachments/assets/3d242efc-4cf8-412d-b4b0-59507720f5ad)
1. SSH to the K2 Plus using any terminal tool (e.g. PuTTy) using the printers ip adress, port 22, user "root" and the password noted in step 1.
1. If you execute a wipe, you will need to go through setup on the K2 screen and complete all the way through creality cloud connection. This will give you the wifi/network connection that you will need and connect appropriately to creality cloud. Stop at the calibration, you can do this later.
1. To start the boostrap install paste into the terminal `sh /mnt/UDISK/printer_data/config/bootstrap/bootstrap.sh` and hit enter.
1. Once the setup completes, it will log you out of your terminal and you will need to log back in.

## Installers

A unified installation menu is *planned*.  For now each feature can be found under the [features](./features/) directory.  A `README.md` and installation script `install.sh` are provided for each option.

The unified installer will understand inter option dependencies and ensure they are met.

For now, there are two default installations:   **Note either option will take some time and seem to hang at times. Be patient as it is moving lots of files and creating venvs for klipper and moonraker full installs

- Option 1: `gimme-the-jamin.sh` - Used to install carto **NOTE MUST HAVE CARTO FLASHED AND PLUGGED IN AND READY TO GO** by following instructions [here](https://github.com/Jacob10383/k2-improvements/blob/main/features/cartographer/firmware/README.md) first.

    To run, use the terminal command `sh /mnt/UDISK/root/k2-improvements/gimme-the-jamin.sh`

    After install you will need to calibrate the carto by following instructions [here](https://github.com/Jacob10383/k2-improvements/blob/main/features/cartographer/SETUP.md)

- Option 2: `no-carto.sh` - Use this if you aren't going to use a carto, or don't have your carto yet.

    To run, use the terminal command `sh /mnt/UDISK/root/k2-improvements/no-carto.sh`

They both install the same set of features (those that I use).  The only difference is whether or not the cartographer bits are installed. If you start with no-carto.sh and later get a carto, you can then run the gimme-the-jamin.sh script and it will install all of the necessary carto items appropriately.

You are still welcome to hand pick which features you want to install.

## Donations

Donations are definitely *not required*, they are appreciated.  If you'd like to donate you can do so [here](https://ko-fi.com/jacob10383).

## Features

- [axis_twist_compensation](./features/axis_twist_compensation/README.md)
- [better init](./features/better-init/README.md)
- [better root](./features/better-root/README.md) home directory
- [Cartographer](./features/cartographer/README.md) support
- installs [Entware](https://github.com/Entware/Entware)
- updated [Fluidd](./features/fluidd/README.md)
- updated [Moonraker](./features/moonraker/README.md)
- [Obico](./features/obico/README.md) - *WIP*
- implements [SCREWS_TILT_CALCULATE](https://www.klipper3d.org/Manual_Level.html#adjusting-bed-leveling-screws-using-the-bed-probe)

And a few quality of life improvement macros

- [MESH_IF_NEEDED](./features/macros/bed_mesh/README.md)
- [START_PRINT](./features/macros/start_print/README.md)
- [M191](./features/macros/m191/README.md)

### Bed Leveling

Sadly, many of the K2 beds resemble a taco or valley.  In the [bed_leveling](bed_leveling) folder you will find a python based script and short writeup on how to apply aluminium tape to shim the bed.

## Credits

- [@Guilouz](https://github.com/Guilouz) - standing on the shoulders of giants
- [@stranula](https://github.com/stranula)
- [@juliosueiras](https://github.com/juliosueiras)

- Moonraker - [https://github.com/Arksine/moonraker](https://github.com/Arksine/moonraker)
- Klipper - [https://github.com/Klipper3d/klipper](https://github.com/Klipper3d/klipper)
- Fluidd - [https://github.com/fluidd-core/fluidd](https://github.com/fluidd-core/fluidd)
- Entware - [https://github.com/Entware/Entware](https://github.com/Entware/Entware)
- Obico - [https://www.obico.io/](https://www.obico.io/)
- SimplyPrint - [https://simplyprint.io/](https://simplyprint.io/)

## FAQ

See the [FAQ](./FAQ.md)
