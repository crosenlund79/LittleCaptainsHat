class_name VesselProfile
extends Resource
## Static characteristics of the player's boat. In this iteration only the
## cruising speed affects the game; wind, sail condition or equipment may
## later scale it (see ARCHITECTURE.md, "Vessel speed").

const DEFAULT_PATH := "res://data/vessel/starter_sloop.tres"

@export var display_name := ""
@export var length_ft := 33.0
## Constant speed through the water while underway, in knots (nm per hour).
@export_range(0.5, 20.0, 0.1) var cruising_speed_kn := 5.0


static func get_default() -> VesselProfile:
	return load(DEFAULT_PATH) as VesselProfile
