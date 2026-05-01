# Slicer templates

Drop-in machine start gcode templates for `kamp-adaptive-purge` on the K2 Plus.

| File | Slicer | Status |
| --- | --- | --- |
| `creality-print-machine-start.gcode` | Creality Print 7.x | Verified on 7.1.1 |
| `orca-machine-start.gcode` | Orca / OrcaSlicer | Unverified — `bed_type` strings need confirming against your Orca profile |

See the parent feature [README.md](../README.md) § "Slicer change required" for full setup instructions including:

- Enabling the **Label objects** toggle in your slicer (required — without it `LINE_PURGE` falls back to bed-origin behavior)
- Why a blocking `M109` is needed before `LINE_PURGE`
- Verification with `grep EXCLUDE_OBJECT_DEFINE|LINE_PURGE` on the sliced gcode

## Using a template

1. Open your slicer's printer profile → Machine G-code → Machine start G-code
2. Replace the entire block with the contents of the appropriate template
3. Save the printer profile
4. Slice a test print and verify with the grep command from the parent README before sending to the printer
