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


# --- Navigation ------------------------------------------------------------------

func get_location_id() -> StringName:
	return _state.location_id if _state else &""


func get_location() -> PortData:
	return PortCatalog.get_default().get_port(get_location_id())


## Returns a copy of the planned route, or null.
func get_planned_route() -> PlannedRoute:
	if _state == null or _state.planned_route == null:
		return null
	return _state.planned_route.duplicate_route()


## Plans a direct route from the current location to `destination_id`.
## Returns false if the destination is unknown or is the current location.
func plan_route_to(destination_id: StringName) -> bool:
	if _state == null:
		return false
	if destination_id == _state.location_id or not PortCatalog.get_default().has_port(destination_id):
		return false
	_state.planned_route = PlannedRoute.create(_state.location_id, destination_id)
	_has_unsaved_changes = true
	route_changed.emit(get_planned_route())
	return true


func clear_planned_route() -> void:
	if _state == null or _state.planned_route == null:
		return
	_state.planned_route = null
	_has_unsaved_changes = true
	route_changed.emit(null)
