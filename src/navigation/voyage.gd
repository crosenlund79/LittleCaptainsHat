class_name Voyage
extends RefCounted
## An active voyage: the validated route being sailed and how far along it the
## vessel is. The vessel's position is always derived from `route.path` and
## `progress_nm`, so the chart, HUD, simulation and saves agree by construction.

## The course being sailed. After a change of course at sea its origin is the
## position where the change was made (origin_port_id is then empty).
var route: PlannedRoute
## Distance sailed along route.path, in nautical miles.
var progress_nm := 0.0
## Increases every time the course is replaced; weather warnings are
## de-duplicated per revision.
var revision := 1
## Weather condition ids already announced for this revision.
var warned_conditions: Array[StringName] = []
## Game time (seconds) when the vessel left the departure port.
var departed_at := 0.0

var _cumulative := PackedFloat64Array()


static func create(planned: PlannedRoute, start_time: float) -> Voyage:
	var voyage := Voyage.new()
	voyage.route = planned.duplicate_route()
	voyage.departed_at = start_time
	return voyage


func duplicate_voyage() -> Voyage:
	var copy := Voyage.new()
	copy.route = route.duplicate_route()
	copy.progress_nm = progress_nm
	copy.revision = revision
	copy.warned_conditions = warned_conditions.duplicate()
	copy.departed_at = departed_at
	return copy


func get_cumulative() -> PackedFloat64Array:
	if _cumulative.size() != route.path.size():
		_cumulative = GeoMath.cumulative_distances(route.path)
	return _cumulative


func get_total_nm() -> float:
	var cumulative := get_cumulative()
	return cumulative[cumulative.size() - 1] if not cumulative.is_empty() else 0.0


func get_remaining_nm() -> float:
	return maxf(get_total_nm() - progress_nm, 0.0)


func get_position() -> Vector2:
	return position_at(progress_nm)


func position_at(distance_nm: float) -> Vector2:
	return GeoMath.point_along(route.path, get_cumulative(), distance_nm)


## The part of the course still ahead, starting at the vessel's position.
func get_remaining_path() -> PackedVector2Array:
	var result := PackedVector2Array([get_position()])
	var cumulative := get_cumulative()
	for i in route.path.size():
		if cumulative[i] > progress_nm + 1e-6:
			result.append(route.path[i])
	return result


## Player waypoints that are still ahead of the vessel.
func get_remaining_waypoints() -> Array[Vector2]:
	var result: Array[Vector2] = []
	var cumulative := get_cumulative()
	for i in route.waypoints.size():
		if cumulative[route.waypoint_path_indices[i]] > progress_nm + 1e-6:
			result.append(route.waypoints[i])
	return result


func is_complete() -> bool:
	return progress_nm >= get_total_nm() - 1e-9


func to_dict() -> Dictionary:
	return {
		"route": route.to_dict(),
		"progress_nm": progress_nm,
		"revision": revision,
		"warned_conditions": warned_conditions.map(func(id: StringName) -> String: return String(id)),
		"departed_at": departed_at,
	}


static func from_dict(data: Variant, catalog: PortCatalog, errors: Array[String]) -> Voyage:
	if not data is Dictionary:
		errors.append("voyage is not an object")
		return null
	var voyage := Voyage.new()
	voyage.route = PlannedRoute.from_dict(data.get("route"), catalog, errors)
	if voyage.route == null:
		return null
	if not voyage.route.has_path():
		errors.append("voyage has no course")
		return null
	var progress: Variant = data.get("progress_nm")
	var revision: Variant = data.get("revision", 1)
	var departed: Variant = data.get("departed_at", 0.0)
	if not _is_number(progress) or float(progress) < 0.0 or float(progress) > voyage.get_total_nm() + 1e-6:
		errors.append("voyage progress is invalid")
		return null
	if not _is_number(revision) or int(revision) < 1 or not _is_number(departed):
		errors.append("voyage revision or departure time is invalid")
		return null
	voyage.progress_nm = float(progress)
	voyage.revision = int(revision)
	voyage.departed_at = float(departed)
	var warned: Variant = data.get("warned_conditions", [])
	if not warned is Array:
		errors.append("voyage warnings are not a list")
		return null
	for id: Variant in warned:
		if not id is String:
			errors.append("voyage warning id is invalid")
			return null
		voyage.warned_conditions.append(StringName(id))
	return voyage


static func _is_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))
