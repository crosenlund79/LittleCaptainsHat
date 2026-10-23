class_name PortCatalog
extends Resource
## The set of known ports. Ports are looked up by their stable id.

const DEFAULT_PATH := "res://data/navigation/port_catalog.tres"

static var _default: PortCatalog

@export var ports: Array[PortData] = []


## The game's catalog. Loaded once and shared, so session validation, saves
## and the map always agree on which port ids exist.
static func get_default() -> PortCatalog:
	if _default == null:
		_default = load(DEFAULT_PATH) as PortCatalog
	return _default


func get_port(port_id: StringName) -> PortData:
	for port in ports:
		if port.id == port_id:
			return port
	return null


func has_port(port_id: StringName) -> bool:
	return get_port(port_id) != null


func get_display_name(port_id: StringName) -> String:
	var port := get_port(port_id)
	return port.display_name if port else String(port_id)
