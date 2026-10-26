class_name PlannedRoute
extends RefCounted
## A planned course: where it starts, the player's waypoints, the destination
## port and the calculated path the vessel will actually sail.
##
## `path` is the validated geometry (geographic Vector2(lon, lat) points joined
## by rhumb lines), produced by SeaRouter. The chart draws exactly this path and
## the voyage follows exactly this path. Waypoints are the player's constraints;
## `waypoint_path_indices[i]` is the index of waypoint i within `path`, which
## splits the path into legs.
##
## The origin is either a port (origin_port_id) or, for a course changed at
## sea, an arbitrary position (origin_port_id is empty). origin_position always
## holds the starting coordinate.

var origin_port_id: StringName
var origin_position := Vector2.ZERO
var destination_port_id: StringName
var waypoints: Array[Vector2] = []
var path := PackedVector2Array()
var waypoint_path_indices := PackedInt32Array()


func duplicate_route() -> PlannedRoute:
	var copy := PlannedRoute.new()
	copy.origin_port_id = origin_port_id
	copy.origin_position = origin_position
	copy.destination_port_id = destination_port_id
	copy.waypoints = waypoints.duplicate()
	copy.path = path.duplicate()
	copy.waypoint_path_indices = waypoint_path_indices.duplicate()
	return copy


## False for routes that only name a destination (e.g. from an old save) and
## still need to be calculated.
func has_path() -> bool:
	return path.size() >= 2


func get_distance_nm() -> float:
	return GeoMath.path_length_nm(path)


## Path index ranges [start, end] of each leg (between origin, waypoints, destination).
func get_leg_ranges() -> Array[Vector2i]:
	var ranges: Array[Vector2i] = []
	var start := 0
	for index in waypoint_path_indices:
		ranges.append(Vector2i(start, index))
		start = index
	ranges.append(Vector2i(start, path.size() - 1))
	return ranges


## Short summary such as "Copenhagen → Kiel  ·  152 nm".
static func describe(route: PlannedRoute, catalog: PortCatalog) -> String:
	if route == null:
		return "No route planned"
	var origin := catalog.get_display_name(route.origin_port_id) if route.origin_port_id else "Position at sea"
	var text := "%s → %s" % [origin, catalog.get_display_name(route.destination_port_id)]
	return text + ("  ·  %d nm" % roundi(route.get_distance_nm()) if route.has_path() else "  ·  needs plotting")


func to_dict() -> Dictionary:
	return {
		"origin": String(origin_port_id),
		"origin_position": _point_to_dict(origin_position),
		"destination": String(destination_port_id),
		"waypoints": waypoints.map(_point_to_dict),
		"path": Array(path).map(_point_to_dict),
		"waypoint_path_indices": Array(waypoint_path_indices),
	}


## Builds a route from saved data. Returns null and appends to `errors` when
## the data is malformed or references unknown ports. Structure only: the
## geometry was validated against the chart when it was planned.
static func from_dict(data: Variant, catalog: PortCatalog, errors: Array[String]) -> PlannedRoute:
	if not data is Dictionary:
		errors.append("route is not an object")
		return null
	var route := PlannedRoute.new()
	var origin: Variant = data.get("origin", "")
	var destination: Variant = data.get("destination")
	if not origin is String or (origin != "" and not catalog.has_port(StringName(origin))):
		errors.append("route has an unknown origin: %s" % [origin])
		return null
	if not destination is String or not catalog.has_port(StringName(destination)):
		errors.append("route has an unknown destination: %s" % [destination])
		return null
	route.origin_port_id = StringName(origin)
	route.destination_port_id = StringName(destination)
	var origin_point: Variant = _point_from(data.get("origin_position"))
	if origin_point == null:
		errors.append("route has no valid origin position")
		return null
	route.origin_position = origin_point
	for key in ["waypoints", "path"]:
		var list: Variant = data.get(key, [])
		if not list is Array:
			errors.append("route %s are not a list" % key)
			return null
		for item: Variant in list:
			# Waypoints are chart positions (within ±180°); path points may run on
			# past the Date Line.
			var point: Variant = _point_from(item, 180.0 if key == "waypoints" else 540.0)
			if point == null:
				errors.append("route contains an invalid %s point" % key.trim_suffix("s"))
				return null
			if key == "waypoints":
				route.waypoints.append(point)
			else:
				route.path.append(point)
	var indices: Variant = data.get("waypoint_path_indices", [])
	if not indices is Array:
		errors.append("route waypoint indices are not a list")
		return null
	for value: Variant in indices:
		if not (value is int or value is float) or int(value) <= 0 or int(value) >= route.path.size():
			errors.append("route waypoint index out of range")
			return null
		route.waypoint_path_indices.append(int(value))
	if route.has_path():
		if route.waypoint_path_indices.size() != route.waypoints.size():
			errors.append("route waypoints do not match the path")
			return null
		if not route.path[0].is_equal_approx(route.origin_position):
			errors.append("route path does not start at its origin")
			return null
		if not route.path[route.path.size() - 1].is_equal_approx(catalog.get_port(route.destination_port_id).get_geo_position()):
			errors.append("route path does not end at its destination")
			return null
	elif route.path.size() == 1:
		errors.append("route path is incomplete")
		return null
	return route


static func _point_to_dict(point: Vector2) -> Dictionary:
	return {"lon": point.x, "lat": point.y}


## Vector2(lon, lat) from {"lon": .., "lat": ..}, or null if invalid.
static func _point_from(value: Variant, max_lon := 540.0) -> Variant:
	if not value is Dictionary:
		return null
	var lon: Variant = value.get("lon")
	var lat: Variant = value.get("lat")
	if not (lon is int or lon is float) or not (lat is int or lat is float):
		return null
	# Longitudes beyond ±180 occur in paths continuous across the Date Line
	# (Iteration 16); anything beyond one extra turn is invalid.
	if not is_finite(float(lon)) or not is_finite(float(lat)) or absf(lon) > max_lon or absf(lat) > 90.0:
		return null
	return Vector2(float(lon), float(lat))
