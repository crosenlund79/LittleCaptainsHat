class_name VesselCatalog
extends Resource
## All vessels the player can sail, in boatyard order. The first one is the
## starter boat and the fallback for unknown or missing vessel ids.

const DEFAULT_PATH := "res://data/vessels/vessel_catalog.tres"
const STARTER_ID := &"starling_33"

static var _default: VesselCatalog

@export var vessels: Array[VesselDefinition] = []


static func get_default() -> VesselCatalog:
	if _default == null:
		_default = load(DEFAULT_PATH) as VesselCatalog
	return _default


static func clear_default() -> void:
	_default = null


func get_vessel(vessel_id: StringName) -> VesselDefinition:
	for vessel in vessels:
		if vessel.id == vessel_id:
			return vessel
	return null


func has_vessel(vessel_id: StringName) -> bool:
	return get_vessel(vessel_id) != null


## The starter boat (also the fallback for unknown ids).
func get_starter() -> VesselDefinition:
	var starter := get_vessel(STARTER_ID)
	return starter if starter else vessels[0]


func get_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for vessel in vessels:
		ids.append(vessel.id)
	return ids
