; Orca / OrcaSlicer machine start gcode for K2 Plus with kamp-adaptive-purge.
;
; UNVERIFIED: the exact bed_type strings depend on the bed types defined in
; your Orca K2 Plus profile. Slice each plate type once and grep the output
; .gcode for `; bed_type =` to confirm the literal string Orca emits, then
; adjust the conditional below to match.
;
; Companion to features/kamp-adaptive-purge. Requires:
;   1. Process tab → Quality → Advanced → Label objects (ON)
;   2. KAMP installed on the printer (sh install.sh from this feature dir)
;   3. k2-improvements START_PRINT macro (installed by the macros feature)
;
; The blocking M109 before LINE_PURGE is required — START_PRINT only sets
; the warm-up temp via M104 (non-blocking). Without M109, LINE_PURGE can
; fire while the nozzle is still heating.

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
