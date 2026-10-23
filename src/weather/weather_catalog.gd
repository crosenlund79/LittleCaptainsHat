class_name WeatherCatalog
extends Resource
## The weather conditions currently on the chart, and route queries on them.
## Pure data and maths: no scene, timer or UI dependencies, so the simulation,
## chart and tests can all ask the same questions.

const DEFAULT_PATH := "res://data/weather/demo_conditions.tres"
## Sampling step when searching a route for the first point inside a condition.
const SAMPLE_STEP_NM := 0.5

static var _default: WeatherCatalog

@export var conditions: Array[WeatherCondition] = []


## Drops the shared instance. Called on shutdown: a script holding an instance
## of itself in a static variable would otherwise never be released.
static func clear_default() -> void:
	_default = null


static func get_default() -> WeatherCatalog:
	if _default == null:
		_default = load(DEFAULT_PATH) as WeatherCatalog
	return _default


func get_condition(id: StringName) -> WeatherCondition:
	for condition in conditions:
		if condition.id == id:
			return condition
	return null


## Noteworthy conditions the path runs into at or after `from_nm`, as
## [{"condition": WeatherCondition, "at_nm": float}] sorted by distance, where
## at_nm is the distance along the path of the first point inside the area
## (from_nm itself if the path is already inside). Deterministic: fixed
## sampling followed by bisection to 0.01 nm.
func find_encounters(path: PackedVector2Array, cumulative: PackedFloat64Array, from_nm: float) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if path.size() < 2:
		return result
	var total := cumulative[cumulative.size() - 1]
	for condition in conditions:
		if not condition.is_noteworthy():
			continue
		var at := _first_entry(condition, path, cumulative, from_nm, total)
		if at >= 0.0:
			result.append({"condition": condition, "at_nm": at})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.at_nm < b.at_nm)
	return result


func _first_entry(condition: WeatherCondition, path: PackedVector2Array, cumulative: PackedFloat64Array,
		from_nm: float, total: float) -> float:
	if condition.contains(GeoMath.point_along(path, cumulative, from_nm)):
		return from_nm
	var center := condition.get_center()
	for i in range(1, path.size()):
		var seg_start := maxf(cumulative[i - 1], from_nm)
		var seg_end := cumulative[i]
		if seg_end <= seg_start:
			continue
		# Skip segments that cannot come near the area.
		var length := seg_end - cumulative[i - 1]
		if GeoMath.distance_nm(center, path[i - 1]) - length > condition.radius_nm \
				and GeoMath.distance_nm(center, path[i]) - length > condition.radius_nm:
			continue
		var previous := seg_start
		var d := seg_start
		while d < seg_end:
			d = minf(d + SAMPLE_STEP_NM, seg_end)
			if condition.contains(GeoMath.point_along(path, cumulative, d)):
				var low := previous
				var high := d
				while high - low > 0.01:
					var mid := (low + high) / 2.0
					if condition.contains(GeoMath.point_along(path, cumulative, mid)):
						high = mid
					else:
						low = mid
				return high
			previous = d
	return -1.0
