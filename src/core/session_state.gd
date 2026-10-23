class_name SessionState
extends RefCounted
## Plain-data representation of everything a game session persists.
##
## This is the explicit, serializable state that GameSession owns and that
## SaveManager writes. It contains no node references, so it exists regardless
## of which scene is visible. to_dict()/from_dict() define the save format;
## each subsystem keeps its data in its own top-level section ("boat",
## "player", "clock", "vessel", "navigation") so future systems can add
## sections of their own.

const AREA_INTERIOR := &"interior"
const AREA_EXTERIOR := &"exterior"
const BOAT_AREAS: Array[StringName] = [AREA_INTERIOR, AREA_EXTERIOR]
const AREA_NAMES := {AREA_INTERIOR: "Cabin", AREA_EXTERIOR: "Deck"}

const STATUS_MOORED := &"moored"
const STATUS_UNDERWAY := &"underway"
const STATUS_ARRIVED := &"arrived"
const STATUSES: Array[StringName] = [STATUS_MOORED, STATUS_UNDERWAY, STATUS_ARRIVED]

const TIME_SCALES: Array[int] = [1, 5, 20]
## New games start on 1 May 2026, 08:00 UTC (start of the sailing season).
const START_TIME_ISO := "2026-05-01T08:00:00"

## Boat area the player is in.
var boat_area: StringName = AREA_INTERIOR
## Player position in the boat area's local coordinates. Only meaningful when
## has_player_position is true; otherwise the area places the player at
## spawn_point (used for new games and for moving between areas).
var player_position := Vector2.ZERO
var has_player_position := false
var spawn_point: StringName = &""
## Port id where the boat lies; empty while underway.
var location_id: StringName
## The course planned from the current port, or null. Not used while underway.
var planned_route: PlannedRoute

## Authoritative game clock: seconds since the Unix epoch, UTC.
var game_time := 0.0
## Selected time acceleration (one of TIME_SCALES).
var time_scale := 1
## Moored (never left), underway, or arrived (at location_id after a voyage).
var vessel_status: StringName = STATUS_MOORED
## Vessel's geographic position Vector2(lon, lat).
var vessel_position := Vector2.ZERO
var vessel_speed_kn := 5.0
## The voyage being sailed, or null when not underway.
var voyage: Voyage


static func create_new(start_location: StringName, start_area: StringName, start_spawn: StringName) -> SessionState:
	var state := SessionState.new()
	state.location_id = start_location
	state.boat_area = start_area
	state.spawn_point = start_spawn
	state.game_time = get_start_time()
	var port := PortCatalog.get_default().get_port(start_location)
	state.vessel_position = port.get_geo_position() if port else Vector2.ZERO
	state.vessel_speed_kn = VesselProfile.get_default().cruising_speed_kn
	return state


static func get_start_time() -> float:
	return float(Time.get_unix_time_from_datetime_string(START_TIME_ISO))


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
	copy.game_time = game_time
	copy.time_scale = time_scale
	copy.vessel_status = vessel_status
	copy.vessel_position = vessel_position
	copy.vessel_speed_kn = vessel_speed_kn
	copy.voyage = voyage.duplicate_voyage() if voyage else null
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
		"clock": {"game_time": game_time, "time_scale": time_scale},
		"vessel": {
			"status": String(vessel_status),
			"position": {"lon": vessel_position.x, "lat": vessel_position.y},
			"speed_kn": vessel_speed_kn,
		},
		"navigation": {
			"location_id": String(location_id),
			"planned_route": planned_route.to_dict() if planned_route else null,
			"voyage": voyage.to_dict() if voyage else null,
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

	var clock: Variant = data.get("clock")
	if not clock is Dictionary or not _is_finite_number(clock.get("game_time")) \
			or not _is_finite_number(clock.get("time_scale")):
		errors.append("missing or invalid clock")
		return null
	state.game_time = float(clock.game_time)
	state.time_scale = int(clock.time_scale)
	if state.game_time < 0.0 or state.time_scale not in TIME_SCALES:
		errors.append("invalid game time or time acceleration")
		return null

	var vessel: Variant = data.get("vessel")
	if not vessel is Dictionary or not vessel.get("status") is String or not _is_finite_number(vessel.get("speed_kn")):
		errors.append("missing or invalid vessel data")
		return null
	state.vessel_status = StringName(vessel.status)
	state.vessel_speed_kn = float(vessel.speed_kn)
	var vessel_position: Variant = PlannedRoute._point_from(vessel.get("position"))
	if state.vessel_status not in STATUSES or vessel_position == null \
			or state.vessel_speed_kn <= 0.0 or state.vessel_speed_kn > 50.0:
		errors.append("invalid vessel status, position or speed")
		return null
	state.vessel_position = vessel_position

	var navigation: Variant = data.get("navigation")
	if not navigation is Dictionary:
		errors.append("missing navigation data")
		return null
	var location: Variant = navigation.get("location_id")
	if not location is String:
		errors.append("invalid location")
		return null
	state.location_id = StringName(location)
	var underway := state.vessel_status == STATUS_UNDERWAY
	if underway != state.location_id.is_empty():
		errors.append("location does not match the vessel status")
		return null
	if not underway and not catalog.has_port(state.location_id):
		errors.append("unknown location: %s" % [location])
		return null
	var route_data: Variant = navigation.get("planned_route")
	if route_data != null:
		state.planned_route = PlannedRoute.from_dict(route_data, catalog, errors)
		if state.planned_route == null:
			return null
	var voyage_data: Variant = navigation.get("voyage")
	if underway != (voyage_data != null):
		errors.append("voyage data does not match the vessel status")
		return null
	if underway:
		state.voyage = Voyage.from_dict(voyage_data, catalog, errors)
		if state.voyage == null:
			return null
		if state.voyage.get_position().distance_to(state.vessel_position) > 0.001:
			errors.append("vessel position does not match the voyage progress")
			return null
		# Use the exact derived position so the simulation continues seamlessly.
		state.vessel_position = state.voyage.get_position()
	return state


static func _is_finite_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))
