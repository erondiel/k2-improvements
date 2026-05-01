{if curr_bed_type=="Customized Plate"}
START_PRINT EXTRUDER_TEMP=[nozzle_temperature_initial_layer] BED_TEMP=[bed_temperature_initial_layer_single] CHAMBER_TEMP=[overall_chamber_temperature] MATERIAL={filament_type[initial_tool]} SURFACE=coolplate
{else}
START_PRINT EXTRUDER_TEMP=[nozzle_temperature_initial_layer] BED_TEMP=[bed_temperature_initial_layer_single] CHAMBER_TEMP=[overall_chamber_temperature] MATERIAL={filament_type[initial_tool]} SURFACE=pei
{endif}

{if multicolor_method}
M83
M8200 P S[initial_no_support_extruder]
M220 S100
G0 Y200 F12000
G0 X10
SET_VELOCITY_LIMIT ACCEL=5000 ACCEL_TO_DECEL=25000
G0 F30000

M8200 C S0
SET_VELOCITY_LIMIT ACCEL=5000 ACCEL_TO_DECEL=5000
G0 Y345 F18000
G0 X139
G0 Y378
G0 X133
M8200 R
M104 S[nozzle_temperature_range_high[initial_no_support_extruder]]
M8200 L I[initial_no_support_extruder]
M106 S0
M106 P2 S0
T[initial_no_support_extruder]

; FLUSH_START
M106 S30
G1 F60
M400
G1 E{90 * 0.18} F{filament_max_volumetric_speed[initial_no_support_extruder]/2.4053*60}
G1 E{90 * 0.02} F60
G1 E{90 * 0.18} F{filament_max_volumetric_speed[initial_no_support_extruder]/2.4053*60}
G1 E{90 * 0.02} F60
G1 E{90 * 0.18} F{filament_max_volumetric_speed[initial_no_support_extruder]/2.4053*60}
G1 E{90 * 0.02} F60
G1 E{90 * 0.18} F{filament_max_volumetric_speed[initial_no_support_extruder]/2.4053*60}
G1 E{90 * 0.02} F60
G1 E{90 * 0.18} F{filament_max_volumetric_speed[initial_no_support_extruder]/2.4053*60}
G1 E{90 * 0.02} F60

M400
M106 S255
G4 P5000
M106 S30
G1 E-[retract_length_toolchange[initial_no_support_extruder]] F1800
; FLUSH_END

; WIPE
SET_VELOCITY_LIMIT ACCEL=5000 ACCEL_TO_DECEL=5000
G0 X160 F12000
G0 X135

G0 X160 Y374 F12000
G2 I4 J0 P1 F10000
G0 X170 Y374 F12000
G3 I-4 J0 P1 F10000

G0 X160 Y378 F12000
G0 X133 Y378 F12000
G0 X160 Y378 F12000
G0 X133 Y378 F12000
G0 X160 Y378 F12000
G0 X133 Y378 F12000

; FLUSH_START
G1 F60
M400
G1 E{90 * 0.18} F{filament_max_volumetric_speed[initial_no_support_extruder]/2.4053*60}
G1 E{90 * 0.02} F60
G1 E{90 * 0.18} F{filament_max_volumetric_speed[initial_no_support_extruder]/2.4053*60}
G1 E{90 * 0.02} F60
G1 E{90 * 0.18} F{filament_max_volumetric_speed[initial_no_support_extruder]/2.4053*60}
G1 E{90 * 0.02} F60
G1 E{90 * 0.18} F{filament_max_volumetric_speed[initial_no_support_extruder]/2.4053*60}
G1 E{90 * 0.02} F60
G1 E{90 * 0.18} F{filament_max_volumetric_speed[initial_no_support_extruder]/2.4053*60}
G1 E{90 * 0.02} F60

M400
M106 S255
G4 P5000
M106 S30
G1 E-[retract_length_toolchange[initial_no_support_extruder]] F1800
; FLUSH_END

; WIPE
SET_VELOCITY_LIMIT ACCEL=5000 ACCEL_TO_DECEL=5000
G0 X160 F12000
G0 X135

G0 X160 Y374 F12000
G2 I4 J0 P1 F10000
G0 X170 Y374 F12000
G3 I-4 J0 P1 F10000

G0 X160 Y378 F12000
G0 X133 Y378 F12000
G0 X160 Y378 F12000
G0 X133 Y378 F12000
G0 X160 Y378 F12000
G0 X133 Y378 F12000

; FLUSH_START
G1 F60
M400
M104 S[nozzle_temperature_initial_layer]
G1 E{90 * 0.18} F{filament_max_volumetric_speed[initial_no_support_extruder]/2.4053*60}
G1 E{90 * 0.02} F60
G1 E{90 * 0.18} F{filament_max_volumetric_speed[initial_no_support_extruder]/2.4053*60}
G1 E{90 * 0.02} F60
G1 E{90 * 0.18} F{filament_max_volumetric_speed[initial_no_support_extruder]/2.4053*60}
G1 E{90 * 0.02} F60
G1 E{90 * 0.18} F{filament_max_volumetric_speed[initial_no_support_extruder]/2.4053*60}
G1 E{90 * 0.02} F60
G1 E{90 * 0.18} F{filament_max_volumetric_speed[initial_no_support_extruder]/2.4053*60}
G1 E{90 * 0.02} F60

M400
M106 S255
G4 P5000
M106 S0
G1 E-[retract_length_toolchange[initial_no_support_extruder]] F1800
; FLUSH_END

; WIPE
SET_VELOCITY_LIMIT ACCEL=5000 ACCEL_TO_DECEL=5000
G0 X160 F12000
G0 X135

G0 X160 Y374 F12000
G2 I4 J0 P1 F10000
G0 X170 Y374 F12000
G3 I-4 J0 P1 F10000

G0 X160 Y378 F12000
G0 X133 Y378 F12000
G0 X160 Y378 F12000
G0 X133 Y378 F12000
G0 X160 Y378 F12000
G0 X133 Y378 F12000

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
