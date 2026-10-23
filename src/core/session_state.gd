class_name SessionState
extends RefCounted
## Plain-data representation of everything a game session persists.
##
## This is the explicit, serializable state that GameSession owns and that
## SaveManager writes. It contains no node references, so it exists regardless
## of which scene is visible. to_dict()/from_dict() define the save format;
## each subsystem keeps its data in its own top-level section ("boat",
## "player", "navigation") so future systems can add sections of their own.

const AREA_INTERIOR := &"interior"
const AREA_EXTERIOR := &"exterior"
const BOAT_AREAS: Array[StringName] = [AREA_INTERIOR, AREA_EXTERIOR]
const AREA_NAMES := {AREA_INTERIOR: "Cabin", AREA_EXTERIOR: "Deck"}

## Boat area the player is in.
var boat_area: StringName = AREA_INTERIOR
## Player position in the boat area's local coordinates. Only meaningful when
## has_player_position is true; otherwise the area places the player at
## spawn_point (used for new games and for moving between areas).
var player_position := Vector2.ZERO
var has_player_position := false
var spawn_point: StringName = &""
## Port (or later, anchorage) id where the boat currently lies.
var location_id: StringName
## The planned voyage, or null when no route is planned.
var planned_route: PlannedRoute


static func create_new(start_location: StringName, start_area: StringName, start_spawn: StringName) -> SessionState:
	var state := SessionState.new()
	state.location_id = start_location
	state.boat_area = start_area
	state.spawn_point = start_spawn
	return state


static func get_area_display_name(area: StringName) -> String:
	return AREA_NAMES.get(area, String(area).capitalize())


func duplicate_state() -> SessionState:
	var copy := SessionState.new()
	copy.boat_area = boat_area
	copy.player_position = player_position
	copy.has_player_position = has_player_position
	copy.spawn_point = spawn_point
	copy.location_id = location_id
	copy.planned_route = planned_route.duplicate_route() if planned_route else null
	return copy


func to_dict() -> Dictionary:
	var player := {}
	if has_player_position:
		player["position"] = {"x": player_position.x, "y": player_position.y}
	else:
		player["spawn_point"] = String(spawn_point)
	return {
		"boat": {"area": String(boat_area)},
		"player": player,
		"navigation": {
			"location_id": String(location_id),
			"planned_route": planned_route.to_dict() if planned_route else null,
		},
	}


## Validates saved data and builds a complete new state from it. Returns null
## (and appends human-readable reasons to `errors`) if anything is missing or
## invalid; a partially valid state is never returned.
static func from_dict(data: Variant, errors: Array[String]) -> SessionState:
	if not data is Dictionary:
		errors.append("session data is not an object")
		return null
	var catalog := PortCatalog.get_default()
	var state := SessionState.new()

	var boat: Variant = data.get("boat")
	if not boat is Dictionary or not boat.get("area") is String:
		errors.append("missing boat area")
		return null
	state.boat_area = StringName(boat["area"])
	if state.boat_area not in BOAT_AREAS:
		errors.append("unknown boat area: %s" % state.boat_area)
		return null

	var player: Variant = data.get("player")
	if not player is Dictionary:
		errors.append("missing player data")
		return null
	var position: Variant = player.get("position")
	if position is Dictionary:
		var x: Variant = position.get("x")
		var y: Variant = position.get("y")
		if not (_is_finite_number(x) and _is_finite_number(y)):
			errors.append("invalid player position")
			return null
		state.player_position = Vector2(float(x), float(y))
		state.has_player_position = true
	elif player.get("spawn_point") is String:
		state.spawn_point = StringName(player["spawn_point"])
	else:
		errors.append("player has neither a position nor a spawn point")
		return null

	var navigation: Variant = data.get("navigation")
	if not navigation is Dictionary:
		errors.append("missing navigation data")
		return null
	var location: Variant = navigation.get("location_id")
	if not location is String or not catalog.has_port(StringName(location)):
		errors.append("unknown location: %s" % [location])
		return null
	state.location_id = StringName(location)
	var route_data: Variant = navigation.get("planned_route")
	if route_data != null:
		state.planned_route = PlannedRoute.from_dict(route_data, catalog, errors)
		if state.planned_route == null:
			return null
	return state


static func _is_finite_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))
