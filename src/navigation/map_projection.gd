class_name MapProjection
extends RefCounted
## Converts geographic coordinates (Vector2(longitude, latitude) in degrees) to
## map-space units and back, using a spherical Mercator projection.
##
## Map space is an internal 2D coordinate system for drawing; the camera then
## maps it to the screen. Game data never stores map-space or screen values.

const MAX_LATITUDE := 85.0

## Map units per degree of longitude.
var scale := 100.0


func _init(units_per_degree := 100.0) -> void:
	scale = units_per_degree


func geo_to_map(geo: Vector2) -> Vector2:
	var lat := deg_to_rad(clampf(geo.y, -MAX_LATITUDE, MAX_LATITUDE))
	var mercator_y := rad_to_deg(log(tan(PI / 4.0 + lat / 2.0)))
	return Vector2(geo.x * scale, -mercator_y * scale)


func map_to_geo(point: Vector2) -> Vector2:
	var mercator_y := deg_to_rad(-point.y / scale)
	var lat := rad_to_deg(2.0 * atan(exp(mercator_y)) - PI / 2.0)
	return Vector2(point.x / scale, lat)


func geo_polygon_to_map(points: PackedVector2Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	result.resize(points.size())
	for i in points.size():
		result[i] = geo_to_map(points[i])
	return result
