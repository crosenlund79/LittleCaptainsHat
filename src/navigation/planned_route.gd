class_name PlannedRoute
extends RefCounted
## A planned voyage: origin port, destination port and optional intermediate
## waypoints. Waypoints are geographic Vector2(longitude, latitude) values and
## are part of the data format already, although this iteration's map only
## creates direct origin -> destination routes.

var origin_port_id: StringName
var destination_port_id: StringName
var waypoints: Array[Vector2] = []


static func create(origin: StringName, destination: StringName) -> PlannedRoute:
	var route := PlannedRoute.new()
	route.origin_port_id = origin
	route.destination_port_id = destination
	return route


func duplicate_route() -> PlannedRoute:
	var copy := PlannedRoute.create(origin_port_id, destination_port_id)
	copy.waypoints = waypoints.duplicate()
	return copy


## Full ordered path as geographic points, including origin and destination.
func get_geo_path(catalog: PortCatalog) -> PackedVector2Array:
	var path := PackedVector2Array()
	var origin := catalog.get_port(origin_port_id)
	var destination := catalog.get_port(destination_port_id)
	if origin == null or destination == null:
		return path
	path.append(origin.get_geo_position())
	for waypoint in waypoints:
		path.append(waypoint)
	path.append(destination.get_geo_position())
	return path


func get_distance_nm(catalog: PortCatalog) -> float:
	var path := get_geo_path(catalog)
	var total := 0.0
	for i in range(1, path.size()):
		total += GeoMath.distance_nm(path[i - 1], path[i])
	return total


## Short summary such as "Copenhagen → Kiel  ·  52 nm" (or a note when null).
static func describe(route: PlannedRoute, catalog: PortCatalog) -> String:
	if route == null:
		return "No route planned"
	return "%s → %s  ·  %d nm" % [
		catalog.get_display_name(route.origin_port_id),
		catalog.get_display_name(route.destination_port_id),
		roundi(route.get_distance_nm(catalog))]


func to_dict() -> Dictionary:
	var points: Array = []
	for waypoint in waypoints:
		points.append({"lon": waypoint.x, "lat": waypoint.y})
	return {
		"origin": String(origin_port_id),
		"destination": String(destination_port_id),
		"waypoints": points,
	}


## Builds a route from saved data. Returns null and appends to `errors` when
## the data is malformed or references unknown ports.
static func from_dict(data: Variant, catalog: PortCatalog, errors: Array[String]) -> PlannedRoute:
	if not data is Dictionary:
		errors.append("planned route is not an object")
		return null
	var origin: Variant = data.get("origin")
	var destination: Variant = data.get("destination")
	if not origin is String or not catalog.has_port(StringName(origin)):
		errors.append("planned route has an unknown origin: %s" % [origin])
		return null
	if not destination is String or not catalog.has_port(StringName(destination)):
		errors.append("planned route has an unknown destination: %s" % [destination])
		return null
	if origin == destination:
		errors.append("planned route starts and ends at the same port")
		return null
	var route := PlannedRoute.create(StringName(origin), StringName(destination))
	var points: Variant = data.get("waypoints", [])
	if not points is Array:
		errors.append("planned route waypoints are not a list")
		return null
	for point: Variant in points:
		if not (point is Dictionary and _is_number(point.get("lon")) and _is_number(point.get("lat"))):
			errors.append("planned route contains an invalid waypoint")
			return null
		var lon := float(point["lon"])
		var lat := float(point["lat"])
		if absf(lon) > 180.0 or absf(lat) > 90.0:
			errors.append("planned route waypoint out of range")
			return null
		route.waypoints.append(Vector2(lon, lat))
	return route


static func _is_number(value: Variant) -> bool:
	return value is int or value is float
