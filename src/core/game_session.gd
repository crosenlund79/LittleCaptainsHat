extends Node
## Authoritative owner of the active game session's state.
##
## GameSession holds a SessionState and is the only code that mutates it.
## Scenes read from it and request changes through its methods; it announces
## changes with signals. It never loads scenes or touches the UI, so the state
## stays valid whichever scene (cabin, deck, map, menu) is currently visible.

signal session_started
signal session_ended
## Emitted after a loaded state has replaced the current one.
signal state_replaced
signal boat_area_changed(area: StringName)
## `route` is a PlannedRoute, or null when the route was cleared.
signal route_changed(route: PlannedRoute)
signal time_scale_changed(scale: int)
signal voyage_started
## The active voyage's course was replaced (change of course at sea).
signal voyage_course_changed
signal voyage_arrived(port_id: StringName)
## Something the player should be told that is not an error of their action
## (e.g. an old save's route had to be dropped).
signal notice(text: String)

const START_LOCATION := &"copenhagen"
const START_AREA := SessionState.AREA_INTERIOR
const START_SPAWN := &"start"

var _state: SessionState
var _has_unsaved_changes := false


func is_active() -> bool:
	return _state != null


## True when the session changed since it was started, saved or loaded.
func has_unsaved_changes() -> bool:
	return _state != null and _has_unsaved_changes


func _exit_tree() -> void:
	PortCatalog.clear_default()
	SeaRouter.clear_default()
	WeatherCatalog.clear_default()


# --- Lifecycle ----------------------------------------------------------------

func start_new_session() -> void:
	_state = SessionState.create_new(START_LOCATION, START_AREA, START_SPAWN)
	_has_unsaved_changes = false
	session_started.emit()


func end_session() -> void:
	if _state == null:
		return
	_state = null
	_has_unsaved_changes = false
	session_ended.emit()


## Replaces the whole state at once (used by loading). The caller must pass an
## already validated state; the previous state is untouched until this point.
func replace_state(new_state: SessionState) -> void:
	assert(new_state != null)
	var was_active := _state != null
	_state = new_state.duplicate_state()
	_has_unsaved_changes = false
	_complete_legacy_route()
	if not was_active:
		session_started.emit()
	state_replaced.emit()


## A copy of the current state, safe to serialize while the game continues.
func get_state_snapshot() -> SessionState:
	return _state.duplicate_state() if _state else null


func mark_saved() -> void:
	_has_unsaved_changes = false


# --- Boat and player -----------------------------------------------------------

func get_boat_area() -> StringName:
	return _state.boat_area if _state else &""


## Moves the player to another boat area, arriving at `spawn_point`.
func enter_boat_area(area: StringName, spawn_point: StringName) -> void:
	if _state == null or area not in SessionState.BOAT_AREAS:
		push_error("Cannot enter boat area '%s'" % area)
		return
	_state.boat_area = area
	_state.spawn_point = spawn_point
	_state.has_player_position = false
	_has_unsaved_changes = true
	boat_area_changed.emit(area)


func set_player_position(position: Vector2) -> void:
	if _state == null:
		return
	if _state.has_player_position and _state.player_position.is_equal_approx(position):
		return
	_state.player_position = position
	_state.has_player_position = true
	_has_unsaved_changes = true


func has_player_position() -> bool:
	return _state != null and _state.has_player_position


func get_player_position() -> Vector2:
	return _state.player_position if _state else Vector2.ZERO


func get_spawn_point() -> StringName:
	return _state.spawn_point if _state else &""


# --- Clock ---------------------------------------------------------------------------

## Game time in seconds since the Unix epoch (UTC).
func get_game_time() -> float:
	return _state.game_time if _state else 0.0


func get_time_scale() -> int:
	return _state.time_scale if _state else 1


func set_time_scale(scale: int) -> void:
	if _state == null or scale not in SessionState.TIME_SCALES or scale == _state.time_scale:
		return
	_state.time_scale = scale
	_has_unsaved_changes = true
	time_scale_changed.emit(scale)


# --- Vessel and location -------------------------------------------------------

func get_location_id() -> StringName:
	return _state.location_id if _state else &""


## The port the vessel lies in, or null while underway.
func get_location() -> PortData:
	return PortCatalog.get_default().get_port(get_location_id())


func get_vessel_status() -> StringName:
	return _state.vessel_status if _state else &""


func is_underway() -> bool:
	return _state != null and _state.vessel_status == SessionState.STATUS_UNDERWAY


func get_vessel_position() -> Vector2:
	return _state.vessel_position if _state else Vector2.ZERO


func get_vessel_speed_kn() -> float:
	return _state.vessel_speed_kn if _state else 0.0


# --- Planned route (in port) ---------------------------------------------------------

## Returns a copy of the planned route, or null.
func get_planned_route() -> PlannedRoute:
	if _state == null or _state.planned_route == null:
		return null
	return _state.planned_route.duplicate_route()


## Calculates a sea route from the current port to `destination_id` and makes
## it the planned route. Returns "" on success, otherwise the reason.
func plan_route_to(destination_id: StringName, waypoints: Array[Vector2] = []) -> String:
	if _state == null or is_underway():
		return "A course can only be planned in port."
	var location := get_location()
	if location == null:
		return "The vessel is not in a port."
	if destination_id == location.id and waypoints.is_empty():
		return "The vessel is already in %s." % location.display_name
	var result := SeaRouter.get_default().plan_route(location.id, location.get_geo_position(), waypoints, destination_id)
	if not result.is_ok():
		return result.error
	return set_planned_route(result.route)


## Makes an already calculated route the planned route, after validating it
## against the chart. Returns "" on success, otherwise the reason.
func set_planned_route(route: PlannedRoute) -> String:
	if _state == null or is_underway():
		return "A course can only be planned in port."
	var location := get_location()
	if location == null or route.origin_port_id != location.id \
			or not route.origin_position.is_equal_approx(location.get_geo_position()):
		return "The course must start from %s." % (location.display_name if location else "the vessel")
	var problem := SeaRouter.get_default().validate_route(route)
	if not problem.is_empty():
		return problem
	_state.planned_route = route.duplicate_route()
	_has_unsaved_changes = true
	route_changed.emit(get_planned_route())
	return ""


func clear_planned_route() -> void:
	if _state == null or _state.planned_route == null:
		return
	_state.planned_route = null
	_has_unsaved_changes = true
	route_changed.emit(null)


# --- Voyage ---------------------------------------------------------------------------

## A copy of the active voyage, or null when not underway.
func get_voyage() -> Voyage:
	return _state.voyage.duplicate_voyage() if _state and _state.voyage else null


## Cheap read-only queries for UI that refreshes every frame.
func get_voyage_destination_id() -> StringName:
	return _state.voyage.route.destination_port_id if _state and _state.voyage else &""


func get_voyage_progress_nm() -> float:
	return _state.voyage.progress_nm if _state and _state.voyage else 0.0


func get_voyage_remaining_nm() -> float:
	return _state.voyage.get_remaining_nm() if _state and _state.voyage else 0.0


func get_voyage_total_nm() -> float:
	return _state.voyage.get_total_nm() if _state and _state.voyage else 0.0


func get_voyage_revision() -> int:
	return _state.voyage.revision if _state and _state.voyage else 0


## Sets sail on the planned route. Returns "" on success, otherwise the reason.
func depart() -> String:
	if _state == null:
		return "No game is running."
	if is_underway():
		return "The vessel is already underway."
	var route := _state.planned_route
	if route == null or not route.has_path():
		return "Plot a course at the chart table first."
	var location := get_location()
	if location == null or route.origin_port_id != location.id:
		return "The planned course does not start here."
	var problem := SeaRouter.get_default().validate_route(route)
	if not problem.is_empty():
		return problem
	_state.voyage = Voyage.create(route, _state.game_time)
	_state.planned_route = null
	_state.vessel_status = SessionState.STATUS_UNDERWAY
	_state.location_id = &""
	_state.vessel_position = _state.voyage.get_position()
	_has_unsaved_changes = true
	route_changed.emit(null)
	voyage_started.emit()
	return ""


## Changes course at sea: plans a new route from the vessel's current position
## (via the waypoints) to `destination_id` and replaces the remaining voyage.
## The clock, progress already made and position are preserved. If no valid
## route exists the current voyage stays exactly as it was. Returns "" on success.
func change_course(destination_id: StringName, waypoints: Array[Vector2]) -> String:
	if not is_underway():
		return "The vessel is not underway."
	var origin := _state.vessel_position
	var result := SeaRouter.get_default().plan_route(&"", origin, waypoints, destination_id)
	if not result.is_ok():
		return result.error
	var voyage := _state.voyage
	voyage.route = result.route
	voyage.progress_nm = 0.0
	voyage.revision += 1
	voyage.warned_conditions.clear()
	_state.vessel_position = voyage.get_position()
	_has_unsaved_changes = true
	voyage_course_changed.emit()
	return ""


# --- Simulation hooks (called by Simulation only) ------------------------------------

## Applies a simulation step: new game time and, when underway, new progress.
func apply_simulation_step(game_time: float, progress_nm: float) -> void:
	if _state == null:
		return
	_state.game_time = game_time
	if _state.voyage:
		_state.voyage.progress_nm = clampf(progress_nm, 0.0, _state.voyage.get_total_nm())
		_state.vessel_position = _state.voyage.get_position()
	_has_unsaved_changes = true


## Ends the voyage at its destination.
func complete_voyage() -> void:
	if not is_underway():
		return
	var destination := PortCatalog.get_default().get_port(_state.voyage.route.destination_port_id)
	_state.voyage = null
	_state.vessel_status = SessionState.STATUS_ARRIVED
	_state.location_id = destination.id
	_state.vessel_position = destination.get_geo_position()
	_has_unsaved_changes = true
	voyage_arrived.emit(destination.id)


func record_weather_warning(condition_id: StringName) -> void:
	if _state and _state.voyage and condition_id not in _state.voyage.warned_conditions:
		_state.voyage.warned_conditions.append(condition_id)
		_has_unsaved_changes = true


func is_weather_warned(condition_id: StringName) -> bool:
	return _state != null and _state.voyage != null and condition_id in _state.voyage.warned_conditions


# --- Internals ------------------------------------------------------------------------

## Saves from before route calculation only stored a destination. Calculate the
## sea route now; if that is impossible, drop the plan and tell the player.
func _complete_legacy_route() -> void:
	var route := _state.planned_route
	if route == null or route.has_path() or is_underway():
		return
	var location := get_location()
	var result := SeaRouter.get_default().plan_route(location.id, location.get_geo_position(),
		route.waypoints, route.destination_port_id)
	if result.is_ok():
		_state.planned_route = result.route
	else:
		_state.planned_route = null
		notice.emit.call_deferred("The saved course to %s could not be recalculated and was removed." %
			PortCatalog.get_default().get_display_name(route.destination_port_id))
