class_name PortCatalog
extends Resource
## The set of known ports. Ports are looked up by their stable id.
##
## Built for catalogues much larger than today's: lookups by id use a
## dictionary, and ports_in_rect() answers "which harbours are in this area"
## from a coarse geographic grid, so the chart only draws what is visible.
## Every harbour stays in the catalogue whether or not it is on screen.

const DEFAULT_PATH := "res://data/navigation/port_catalog.tres"
## Size of a spatial bucket in degrees.
const BUCKET_DEGREES := 2.0

static var _default: PortCatalog

@export var ports: Array[PortData] = []

var _by_id := {}
var _buckets := {}
var _indexed_count := -1


## The game's catalog. Loaded once and shared, so session validation, saves
## and the map always agree on which port ids exist.
## Drops the shared instance. Called on shutdown: a script holding an instance
## of itself in a static variable would otherwise never be released.
static func clear_default() -> void:
	_default = null


static func get_default() -> PortCatalog:
	if _default == null:
		_default = load(DEFAULT_PATH) as PortCatalog
	return _default


func get_port(port_id: StringName) -> PortData:
	_ensure_index()
	return _by_id.get(port_id)


func has_port(port_id: StringName) -> bool:
	return get_port(port_id) != null


func get_display_name(port_id: StringName) -> String:
	var port := get_port(port_id)
	return port.display_name if port else String(port_id)


## Harbours whose position lies in `geo_rect` (x = longitude, y = latitude).
func ports_in_rect(geo_rect: Rect2) -> Array[PortData]:
	_ensure_index()
	var result: Array[PortData] = []
	var x0 := floori(geo_rect.position.x / BUCKET_DEGREES)
	var x1 := floori(geo_rect.end.x / BUCKET_DEGREES)
	var y0 := floori(geo_rect.position.y / BUCKET_DEGREES)
	var y1 := floori(geo_rect.end.y / BUCKET_DEGREES)
	if (x1 - x0 + 1) * (y1 - y0 + 1) > ports.size():
		# A large area (the whole world chart): looking at every harbour is
		# cheaper than visiting every bucket.
		for port in ports:
			if geo_rect.has_point(port.get_geo_position()):
				result.append(port)
		return result
	for bx in range(x0, x1 + 1):
		for by in range(y0, y1 + 1):
			for port: PortData in _buckets.get(Vector2i(bx, by), []):
				if geo_rect.has_point(port.get_geo_position()):
					result.append(port)
	return result


## Harbours whose name or country contains `text` (case-insensitive; names
## starting with it first, then alphabetical), at most `limit`.
func search(text: String, limit := 8) -> Array[PortData]:
	var query := text.strip_edges().to_lower()
	var result: Array[PortData] = []
	if query.is_empty():
		return result
	var starts: Array[PortData] = []
	var contains: Array[PortData] = []
	for port in ports:
		var name := port.display_name.to_lower()
		if name.begins_with(query) or String(port.id).begins_with(query):
			starts.append(port)
		elif name.contains(query) or port.country.to_lower().contains(query):
			contains.append(port)
	var by_name := func(a: PortData, b: PortData) -> bool: return a.display_name.naturalnocasecmp_to(b.display_name) < 0
	starts.sort_custom(by_name)
	contains.sort_custom(by_name)
	result.append_array(starts)
	result.append_array(contains)
	return result.slice(0, limit)


## Rebuilds the id index and the spatial grid (after `ports` changed).
func rebuild_index() -> void:
	_by_id.clear()
	_buckets.clear()
	for port in ports:
		_by_id[port.id] = port
		var key := Vector2i(floori(port.longitude / BUCKET_DEGREES), floori(port.latitude / BUCKET_DEGREES))
		if not _buckets.has(key):
			_buckets[key] = []
		_buckets[key].append(port)
	_indexed_count = ports.size()


func _ensure_index() -> void:
	if _indexed_count != ports.size():
		rebuild_index()
