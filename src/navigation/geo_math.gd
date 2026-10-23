class_name GeoMath
extends RefCounted
## Geographic calculations on Vector2(longitude, latitude) degree pairs.

const EARTH_RADIUS_NM := 3440.065


## Great-circle distance in nautical miles (haversine formula).
static func distance_nm(from: Vector2, to: Vector2) -> float:
	var lat1 := deg_to_rad(from.y)
	var lat2 := deg_to_rad(to.y)
	var d_lat := lat2 - lat1
	var d_lon := deg_to_rad(to.x - from.x)
	var a := sin(d_lat / 2.0) ** 2 + cos(lat1) * cos(lat2) * sin(d_lon / 2.0) ** 2
	return 2.0 * EARTH_RADIUS_NM * asin(sqrt(a))


static func format_position(geo: Vector2) -> String:
	return "%s  %s" % [_format_angle(geo.y, "N", "S"), _format_angle(geo.x, "E", "W")]


static func _format_angle(value: float, positive: String, negative: String) -> String:
	var hemisphere := positive if value >= 0.0 else negative
	var absolute := absf(value)
	var degrees := floori(absolute)
	var minutes := (absolute - degrees) * 60.0
	return "%d°%04.1f′%s" % [degrees, minutes, hemisphere]
