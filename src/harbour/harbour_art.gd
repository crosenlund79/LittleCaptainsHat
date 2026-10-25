@tool
class_name HarbourArt
extends Resource
## Optional art for one harbour (Visual Identity V01): up to MAX_LANDMARKS
## local landmark illustrations shown beyond the guest pontoon.
##
## Looked up by port id at res://data/harbours/<port_id>.tres. A harbour
## without a file (all but Copenhagen so far) simply shows the generic
## illustrated harbour; nothing requires art for the 163 harbours. Landmarks
## are art only: they never affect collision, mooring or any interaction.

const PATH_PATTERN := "res://data/harbours/%s.tres"
const MAX_LANDMARKS := 3

## The harbour this art belongs to (must match the file name).
@export var port_id: StringName
@export var landmarks: Array[HarbourLandmark] = []
## The harbour's broad water atmosphere for the animated water (0.100b):
## "marina", "coastal" or "urban"; "auto" derives it from the catalogue (see
## WaterLife.atmosphere_for()).
@export_enum("auto", "marina", "coastal", "urban") var atmosphere := "auto"


## The art for `port_id`, or null when that harbour has none.
static func for_port(port_id: StringName) -> HarbourArt:
	if port_id.is_empty():
		return null
	var path := PATH_PATTERN % port_id
	if not ResourceLoader.exists(path):
		return null
	var art := load(path) as HarbourArt
	if art == null or art.port_id != port_id:
		push_warning("Harbour art %s does not belong to '%s'; ignored." % [path, port_id])
		return null
	return art


## The landmarks that will be drawn: those with a texture, at most
## MAX_LANDMARKS (extra ones are ignored with a warning).
func get_landmarks() -> Array[HarbourLandmark]:
	var result: Array[HarbourLandmark] = []
	for landmark in landmarks:
		if landmark == null or landmark.texture == null:
			continue
		if result.size() == MAX_LANDMARKS:
			push_warning("Harbour '%s' has more than %d landmarks; the rest are not shown." % [port_id, MAX_LANDMARKS])
			break
		result.append(landmark)
	return result
