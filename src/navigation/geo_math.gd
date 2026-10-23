class_name GeoMath
extends RefCounted
## Geographic calculations on Vector2(longitude, latitude) degree pairs.
##
## Route legs are rhumb lines (loxodromes): lines of constant compass bearing.
## They are straight on the Mercator chart and in the Mercator navigation
## raster, so what the chart draws, what land validation checks and where the
## vessel actually sails are the same line. Distances along routes are rhumb
## distances; great-circle distance is only used for "as the crow flies" info.

const EARTH_RADIUS_NM := 3440.065


## Great-circle distance in nautical miles (haversine formula).
static func distance_nm(from: Vector2, to: Vector2) -> float:
	var lat1 := deg_to_rad(from.y)
	var lat2 := deg_to_rad(to.y)
	var d_lat := lat2 - lat1
	var d_lon := deg_to_rad(to.x - from.x)
	var a := sin(d_lat / 2.0) ** 2 + cos(lat1) * cos(lat2) * sin(d_lon / 2.0) ** 2
	return 2.0 * EARTH_RADIUS_NM * asin(sqrt(a))


## Length of the rhumb line between two points, in nautical miles.
static func rhumb_distance_nm(from: Vector2, to: Vector2) -> float:
	var lat1 := deg_to_rad(from.y)
	var lat2 := deg_to_rad(to.y)
	var d_lat := lat2 - lat1
	var d_lon := deg_to_rad(to.x - from.x)
	var d_psi := _psi(lat2) - _psi(lat1)
	# Along a constant-latitude line the stretched Mercator ratio is cos(lat).
	var q := d_lat / d_psi if absf(d_psi) > 1e-12 else cos(lat1)
	return sqrt(d_lat * d_lat + q * q * d_lon * d_lon) * EARTH_RADIUS_NM


## Point at `fraction` (0..1) of the rhumb-line distance from `from` to `to`.
## Distance along a rhumb line is proportional to the change in latitude, so
## latitude is interpolated linearly and longitude follows the constant bearing.
static func rhumb_interpolate(from: Vector2, to: Vector2, fraction: float) -> Vector2:
	var lat1 := deg_to_rad(from.y)
	var lat2 := deg_to_rad(to.y)
	var d_lat := lat2 - lat1
	if absf(d_lat) < 1e-12:
		return Vector2(lerpf(from.x, to.x, fraction), from.y)
	var lat := lat1 + d_lat * fraction
	var share := (_psi(lat) - _psi(lat1)) / (_psi(lat2) - _psi(lat1))
	return Vector2(from.x + (to.x - from.x) * share, rad_to_deg(lat))


## Constant compass bearing (degrees true, 0 = north, 90 = east) of the
## rhumb line from `from` to `to`.
static func rhumb_bearing(from: Vector2, to: Vector2) -> float:
	var d_psi := _psi(deg_to_rad(to.y)) - _psi(deg_to_rad(from.y))
	var d_lon := deg_to_rad(to.x - from.x)
	return fposmod(rad_to_deg(atan2(d_lon, d_psi)), 360.0)


## Total rhumb length of a polyline, in nautical miles.
static func path_length_nm(path: PackedVector2Array) -> float:
	var total := 0.0
	for i in range(1, path.size()):
		total += rhumb_distance_nm(path[i - 1], path[i])
	return total


## Cumulative rhumb distances: result[i] is the distance from path[0] to path[i].
static func cumulative_distances(path: PackedVector2Array) -> PackedFloat64Array:
	var result := PackedFloat64Array()
	result.resize(path.size())
	var total := 0.0
	for i in path.size():
		if i > 0:
			total += rhumb_distance_nm(path[i - 1], path[i])
		result[i] = total
	return result


## Point at `distance` nm along a polyline (clamped to its ends).
static func point_along(path: PackedVector2Array, cumulative: PackedFloat64Array, distance: float) -> Vector2:
	if path.is_empty():
		return Vector2.ZERO
	if distance <= 0.0:
		return path[0]
	var last := path.size() - 1
	if distance >= cumulative[last]:
		return path[last]
	var i := cumulative.bsearch(distance, false)  # first index with cumulative > distance
	i = clampi(i, 1, last)
	var length := cumulative[i] - cumulative[i - 1]
	var fraction := (distance - cumulative[i - 1]) / length if length > 0.0 else 0.0
	return rhumb_interpolate(path[i - 1], path[i], fraction)


## Index of the segment (1..n-1, its end point) that contains `distance`.
static func segment_index_at(cumulative: PackedFloat64Array, distance: float) -> int:
	return clampi(cumulative.bsearch(distance, false), 1, maxi(cumulative.size() - 1, 1))


static func _psi(lat: float) -> float:
	return log(tan(PI / 4.0 + lat / 2.0))


static func format_position(geo: Vector2) -> String:
	return "%s  %s" % [_format_angle(geo.y, "N", "S"), _format_angle(geo.x, "E", "W")]


static func _format_angle(value: float, positive: String, negative: String) -> String:
	var hemisphere := positive if value >= 0.0 else negative
	var absolute := absf(value)
	var degrees := floori(absolute)
	var minutes := (absolute - degrees) * 60.0
	return "%d°%04.1f′%s" % [degrees, minutes, hemisphere]
