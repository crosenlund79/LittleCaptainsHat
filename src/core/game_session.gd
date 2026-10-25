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
## The player paused or resumed the simulation clock.
signal pause_changed(paused: bool)
signal voyage_started
## The active voyage's course was replaced (change of course at sea).
signal voyage_course_changed
signal voyage_arrived(port_id: StringName)
## Sail <-> engine changed (or propulsion ended on arrival: mode is then &"").
signal propulsion_changed(mode: StringName)
## The player switched boats at the boatyard.
signal vessel_changed(vessel_id: StringName)
## The ship's companion moved to another resting spot (see CompanionState).
signal companion_moved(spot: StringName)
## Something the player should be told that is not an error of their action
## (e.g. an old save's route had to be dropped).
signal notice(text: String)
## The active boat's condition (percent) changed (weather, repair, rescue).
signal condition_changed(percent: float)
signal funds_changed(funds: int)
## Food or water changed noticeably (restock, a new warning level; the
## steady consumption is read every frame by the UI instead).
signal provisions_changed
## Stores ran low (Provisions.WARN_*): given once per level until restocked.
signal provisions_warning(level: int, text: String)
## The boat was lost and its crew rescued: the voyage is over and the boat is
## back in the home harbour. `info` = {"fee", "funds_after", "port_id", "from"}.
signal rescued(info: Dictionary)
## A voyage ended and was written to the Captain's Log (see
## CaptainsLog.make_record()); `new_harbour` is true on a first visit.
signal voyage_logged(record: Dictionary, new_harbour: bool)
## Objectives completed by a voyage or a hat event paid renown: [{"id",
## "title", "reward", "text", "secret", "tone"}]. Emitted once per event,
## after voyage_logged (a voyage) or hat_lost / hat_bought (the hat).
signal renown_awarded(awards: Array)
## A travel update was published: {"renown", "euros", "funds_after"}.
signal travel_update_published(info: Dictionary)
## The captain's hat changed hands: put on, taken off, hung up, lost or
## bought (HatState.STORED / WORN / CARRIED / LOST).
signal hat_changed(status: StringName)
## The wind is strong enough to take a worn hat (once per exposure).
signal hat_warning(text: String)
## The hat blew away: {"time", "text", "log_text", "lost_count", "serial",
## "wind_kn", "gust_kn", "in_harbour", "position": {"lon", "lat"}}.
signal hat_lost(info: Dictionary)
## A replacement hat was bought: {"price", "funds_after", "serial"}.
signal hat_bought(info: Dictionary)

const START_LOCATION := &"copenhagen"
## Where a rescued boat is brought back to (fixed in this version).
const HOME_PORT := &"copenhagen"
## Where the player is put aboard after a rescue (a cabin spawn every boat has).
const RESCUE_AREA := SessionState.AREA_INTERIOR
const RESCUE_SPAWN := &"start"
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
	ObjectiveCatalog.clear_default()
	HatConfig.clear_default()
	HatArt.clear_default()
	SeaRouter.clear_default()
	WeatherModel.clear_default()
	WindField.clear_default()
	VesselProfile.clear_default()
	VesselCatalog.clear_default()


# --- Lifecycle ----------------------------------------------------------------

## Starts a new game with the chosen ship's companion ("cat" or "dog").
func start_new_session(companion_kind: StringName = CompanionState.DEFAULT_KIND) -> void:
	_state = SessionState.create_new(START_LOCATION, START_AREA, START_SPAWN, companion_kind)
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
	_check_vessel()
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


## Selects 1x/5x/20x. Choosing a speed while paused also resumes the clock.
func set_time_scale(scale: int) -> void:
	if _state == null or scale not in SessionState.TIME_SCALES:
		return
	if scale != _state.time_scale:
		_state.time_scale = scale
		_has_unsaved_changes = true
		time_scale_changed.emit(scale)
	set_paused(false)


## True while the player has paused the simulation clock. This is the one
## shared pause: Simulation does not advance time while it is set, in any
## scene. (Menus pausing the scene tree are a separate, temporary thing.)
func is_paused() -> bool:
	return _state.paused if _state else false


## Pauses or resumes the simulation clock; resuming continues at the selected
## time scale.
func set_paused(paused: bool) -> void:
	if _state == null or _state.paused == paused:
		return
	_state.paused = paused
	_has_unsaved_changes = true
	pause_changed.emit(paused)


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


## Current speed through the water in knots (0 when not underway).
func get_vessel_speed_kn() -> float:
	return _state.propulsion.speed_kn if is_underway() else 0.0


## The boat's performance profile (one starter boat for now).
## Sailing performance of the active vessel.
func get_vessel_profile() -> VesselProfile:
	var vessel := get_vessel_definition()
	return vessel.performance if vessel and vessel.performance else VesselProfile.get_default()


## The boat the player owns (the starter boat when no game is running).
func get_vessel_definition() -> VesselDefinition:
	var catalog := VesselCatalog.get_default()
	if _state == null:
		return catalog.get_starter()
	var vessel := catalog.get_vessel(_state.vessel_id)
	return vessel if vessel else catalog.get_starter()


func get_vessel_id() -> StringName:
	return _state.vessel_id if _state else VesselCatalog.STARTER_ID


## True when the boatyard may be used: in harbour, not on a passage.
func can_change_vessel() -> bool:
	return _state != null and not is_underway() and get_location() != null


## Switches to another boat at the boatyard. Only in harbour; refused (with a
## reason) underway. Everything long-term stays: time, location, planned
## course, companion, saves. The player goes on deck of the new boat at its
## boatyard spawn point; the companion keeps its resting spot, which every
## cabin provides. The propulsion controller starts afresh, so no rolling
## average from the old boat's performance carries over.
func switch_vessel(vessel_id: StringName) -> String:
	if _state == null:
		return "No game is running."
	if is_underway():
		return "You can only change boats in harbour, not during a passage."
	if get_location() == null:
		return "The boatyard is only available in harbour."
	var vessel := VesselCatalog.get_default().get_vessel(vessel_id)
	if vessel == null:
		return "Unknown boat '%s'." % vessel_id
	if vessel_id == _state.vessel_id:
		return ""
	_state.vessel_id = vessel_id
	_state.propulsion = PropulsionState.new()
	_has_unsaved_changes = true
	enter_boat_area(SessionState.AREA_EXTERIOR, &"from_boatyard")
	vessel_changed.emit(vessel_id)
	return ""


## A save naming a boat this version does not know falls back to the starter
## boat, and the player is told (the rest of the save is kept).
func _check_vessel() -> void:
	var catalog := VesselCatalog.get_default()
	if catalog.has_vessel(_state.vessel_id):
		return
	var unknown := _state.vessel_id
	_state.vessel_id = catalog.get_starter().id
	_state.spawn_point = &"start"
	_state.has_player_position = false
	push_warning("Unknown vessel id '%s' in the loaded game; using '%s'." % [unknown, _state.vessel_id])
	notice.emit.call_deferred("The saved boat '%s' is not available; you are aboard the %s." % [unknown, catalog.get_starter().display_name])


## A copy of the propulsion state (mode, potential speed, wind, sails).
func get_propulsion() -> PropulsionState:
	return _state.propulsion.duplicate_state() if _state else PropulsionState.new()


## True while the engine is driving the boat.
func is_motoring() -> bool:
	return is_underway() and _state.propulsion.is_motoring()


## True while sails are drawing on a voyage (false in port or when motoring).
func are_sails_set() -> bool:
	return is_underway() and _state.propulsion.initialised and _state.propulsion.sails_set()


## A copy of the ship's companion (kind, resting spot, schedule).
func get_companion() -> CompanionState:
	return _state.companion.duplicate_state() if _state else null


func get_wind_seed() -> int:
	return _state.wind_seed if _state else 1


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


## Distance along the course of the next route vertex ahead of the vessel
## (where the heading changes), or the total if none is left.
func get_voyage_next_vertex_nm() -> float:
	if _state == null or _state.voyage == null:
		return 0.0
	var cumulative := _state.voyage.get_cumulative()
	var i := cumulative.bsearch(_state.voyage.progress_nm + 1e-9, false)
	return cumulative[mini(i, cumulative.size() - 1)]


## The position at `distance_nm` along the active voyage's course (Simulation).
func get_voyage_position_at(distance_nm: float) -> Vector2:
	return _state.voyage.position_at(distance_nm) if _state and _state.voyage else get_vessel_position()


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
	if _state.provisions.is_empty():
		return "You are out of food or water. Buy provisions at the grocery store before setting sail."
	var location := get_location()
	if location == null or route.origin_port_id != location.id:
		return "The planned course does not start here."
	var problem := SeaRouter.get_default().validate_route(route)
	if not problem.is_empty():
		return problem
	_state.voyage = Voyage.create(route, _state.game_time)
	_state.hat.voyage_worn_hazard = 0
	_state.hat.voyage_lost = false
	_state.weather_exposure.reset(_state.game_time)
	_state.damage_applied_until = _state.game_time
	_state.propulsion = PropulsionState.new()  # evaluated by Simulation on voyage_started
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
## Food and water are used up with the elapsed game time, wherever the boat is.
func apply_simulation_step(game_time: float, progress_nm: float) -> void:
	if _state == null:
		return
	var elapsed := game_time - _state.game_time
	_state.game_time = game_time
	if elapsed > 0.0:
		_state.provisions.consume(elapsed / Provisions.DAY_SECONDS)
		_check_provisions()
	# The companion's resting schedule runs on the same clock (pure function of time).
	if _state.companion.advance_to(game_time):
		companion_moved.emit(_state.companion.spot)
	if _state.voyage:
		var progress := clampf(progress_nm, 0.0, _state.voyage.get_total_nm())
		_state.voyage.sailed_nm += maxf(progress - _state.voyage.progress_nm, 0.0)
		_state.voyage.progress_nm = progress
		_state.vessel_position = _state.voyage.get_position()
	_has_unsaved_changes = true


## Ends the voyage at its destination.
## Replaces the propulsion state (Simulation only). Announces mode changes.
func set_propulsion(state: PropulsionState) -> void:
	if _state == null:
		return
	var changed := state.mode != _state.propulsion.mode or not _state.propulsion.initialised
	_state.propulsion = state.duplicate_state()
	_has_unsaved_changes = true
	if changed:
		propulsion_changed.emit(state.mode)


func complete_voyage() -> void:
	if not is_underway():
		return
	var destination := PortCatalog.get_default().get_port(_state.voyage.route.destination_port_id)
	var record := CaptainsLog.make_record(_state.voyage, _state.game_time, _state.vessel_id, CaptainsLog.OUTCOME_ARRIVED)
	var new_harbour := _state.captains_log.record_voyage(record)
	var awards := _award_objectives(record, new_harbour)
	_state.voyage = null
	_state.vessel_status = SessionState.STATUS_ARRIVED
	_state.location_id = destination.id
	_state.vessel_position = destination.get_geo_position()
	_state.propulsion = PropulsionState.new()
	_state.weather_exposure.reset(_state.game_time)
	_has_unsaved_changes = true
	propulsion_changed.emit(&"")
	voyage_logged.emit(record, new_harbour)
	if not awards.is_empty():
		renown_awarded.emit(awards)
	voyage_arrived.emit(destination.id)


## Records the weather at the boat (Simulation only, on its evaluation grid).
func update_weather_exposure(sample: WeatherSample) -> void:
	if _state == null:
		return
	_state.weather_exposure.record(sample, _state.game_time)
	if _state.voyage:
		_state.voyage.worst_hazard = maxi(_state.voyage.worst_hazard, sample.hazard)
	_has_unsaved_changes = true


## A copy of the weather exposure record: the hazard level the boat is in, since
## when, the responsible event and the peaks (see WeatherExposure).
func get_weather_exposure() -> WeatherExposure:
	return _state.weather_exposure.duplicate_exposure() if _state else WeatherExposure.new()


## Records that a weather warning (key "<event>><level>") was given on this voyage.
func record_weather_warning(condition_id: StringName) -> void:
	if _state and _state.voyage and condition_id not in _state.voyage.warned_conditions:
		_state.voyage.warned_conditions.append(condition_id)
		_has_unsaved_changes = true


func is_weather_warned(condition_id: StringName) -> bool:
	return _state != null and _state.voyage != null and condition_id in _state.voyage.warned_conditions


# --- Condition, repair and rescue ---------------------------------------------------

## The active boat's condition in percent (100 = perfect).
func get_condition() -> float:
	return _state.get_condition(_state.vessel_id) if _state else VesselCondition.FULL


## Condition of any boat (each boat keeps its own, also when not sailed).
func get_vessel_condition(vessel_id: StringName) -> float:
	return _state.get_condition(vessel_id) if _state else VesselCondition.FULL


## Weather damage has been applied up to this game time (Simulation only).
func get_damage_applied_until() -> float:
	return _state.damage_applied_until if _state else 0.0


## Applies weather damage for the voyage up to `until` (Simulation only, at
## its evaluation points). When the condition reaches zero the crew is rescued
## at once (see rescue()). Returns true if that happened.
func apply_weather_damage(percent: float, until: float) -> bool:
	if _state == null or not is_underway():
		return false
	_state.damage_applied_until = maxf(_state.damage_applied_until, until)
	_has_unsaved_changes = true
	if percent <= 0.0:
		return false
	var before := get_condition()
	_state.set_condition(_state.vessel_id, before - percent)
	_state.voyage.damage_percent += before - get_condition()
	condition_changed.emit(get_condition())
	if get_condition() <= 0.0:
		rescue()
		return true
	return false


## Repairs and restocking are harbour services: moored or arrived in port.
func is_moored_in_harbour() -> bool:
	return _state != null and not is_underway() and get_location() != null


## Repairs the active boat to 100 % (free in this version). Harbour only.
## Returns "" on success, otherwise the reason.
func repair_vessel() -> String:
	if not is_moored_in_harbour():
		return "Repairs can only be made while moored in harbour."
	if get_condition() >= VesselCondition.FULL:
		return "The %s is already in perfect condition." % get_vessel_definition().display_name
	_state.set_condition(_state.vessel_id, VesselCondition.FULL)
	_has_unsaved_changes = true
	condition_changed.emit(get_condition())
	return ""


## Rescue at sea: the boat's condition reached zero. One complete transaction,
## applied to the state at once, so a save can never hold half of it: the
## voyage ends, the boat and crew are brought back to the home harbour, the
## boat is repaired, and the fee (at most what the player has) is paid. The
## companion, provisions, other boats and the clock are kept; time acceleration
## drops to 1× (a player pause stays as it was). Does nothing if not underway,
## so one incident can only ever be rescued once.
func rescue() -> void:
	if _state == null or not is_underway():
		return
	var port := PortCatalog.get_default().get_port(HOME_PORT)
	var from := _state.vessel_position
	var fee := mini(SessionState.RESCUE_FEE, _state.funds)
	_state.funds -= fee
	var record := CaptainsLog.make_record(_state.voyage, _state.game_time, _state.vessel_id, CaptainsLog.OUTCOME_RESCUED)
	_state.captains_log.record_voyage(record)
	var awards := _award_objectives(record, false)
	_state.voyage = null
	_state.planned_route = null
	_state.vessel_status = SessionState.STATUS_MOORED
	_state.location_id = port.id
	_state.vessel_position = port.get_geo_position()
	_state.propulsion = PropulsionState.new()
	_state.weather_exposure.reset(_state.game_time)
	_state.damage_applied_until = _state.game_time
	_state.set_condition(_state.vessel_id, VesselCondition.FULL)
	_state.boat_area = RESCUE_AREA
	_state.spawn_point = RESCUE_SPAWN
	_state.has_player_position = false
	_state.time_scale = 1
	_state.rescue_count += 1
	var info := {"time": _state.game_time, "fee": fee, "funds_after": _state.funds, "port_id": String(port.id),
		"from": {"lon": from.x, "lat": from.y}}
	_state.last_rescue = info.duplicate(true)
	_has_unsaved_changes = true
	time_scale_changed.emit(1)
	propulsion_changed.emit(&"")
	route_changed.emit(null)
	condition_changed.emit(get_condition())
	funds_changed.emit(_state.funds)
	voyage_logged.emit(record, false)
	if not awards.is_empty():
		renown_awarded.emit(awards)
	rescued.emit(info)


# --- Captain's Log ---------------------------------------------------------------

## A copy of the Captain's Log.
func get_captains_log() -> CaptainsLog:
	return _state.captains_log.duplicate_log() if _state else CaptainsLog.new()


## Everything sailed so far, nm: ended voyages plus the voyage under way.
func get_total_nm_sailed() -> float:
	if _state == null:
		return 0.0
	return _state.captains_log.total_nm + (_state.voyage.sailed_nm if _state.voyage else 0.0)


func get_voyage_sailed_nm() -> float:
	return _state.voyage.sailed_nm if _state and _state.voyage else 0.0


# --- Objectives and renown ----------------------------------------------------------

## A copy of renown and the objectives completed.
func get_objective_progress() -> ObjectiveProgress:
	return _state.progress.duplicate_progress() if _state else ObjectiveProgress.new()


## All renown ever earned (never decreases).
func get_lifetime_renown() -> int:
	return _state.progress.lifetime_renown if _state else 0


## Renown not yet published in a travel update.
func get_unpublished_renown() -> int:
	return _state.progress.unpublished_renown if _state else 0


## What publishing a travel update would do now: {"renown", "rate", "euros",
## "funds", "funds_after", "error"} ("" when it is possible).
func get_publish_quote() -> Dictionary:
	var rate := ObjectiveCatalog.get_default().euros_per_renown
	var renown := get_unpublished_renown()
	var error := ""
	if not is_moored_in_harbour():
		error = "Publishing needs a steady connection: moor in a harbour first."
	elif renown <= 0:
		error = "No unpublished renown yet: sail, explore and complete objectives to earn some."
	return {"renown": renown, "rate": rate, "euros": renown * rate, "funds": get_funds(),
		"funds_after": get_funds() + renown * rate, "error": error}


## Publishes a travel update (social media): all unpublished renown becomes
## money at the configured rate, in one transaction. The renown deduction and
## the payment happen together or not at all; lifetime renown stays. In
## harbour only. Returns {"error", "renown", "euros", "funds_after"}.
func publish_travel_update() -> Dictionary:
	if _state == null:
		return {"error": "No game is running.", "renown": 0, "euros": 0, "funds_after": 0}
	var quote := get_publish_quote()
	if not String(quote.error).is_empty():
		return {"error": quote.error, "renown": 0, "euros": 0, "funds_after": _state.funds}
	var progress := _state.progress
	var renown := progress.unpublished_renown
	var euros: int = renown * int(quote.rate)
	progress.unpublished_renown = 0
	progress.publications += 1
	progress.published_renown += renown
	progress.published_euros += euros
	_state.funds += euros
	_has_unsaved_changes = true
	var info := {"error": "", "renown": renown, "euros": euros, "funds_after": _state.funds}
	funds_changed.emit(_state.funds)
	travel_update_published.emit(info.duplicate())
	return info


## Pays the objectives the voyage just logged completes (inside
## complete_voyage() and rescue(), so the reward is part of the same
## transaction as the record and can never be paid twice).
func _award_objectives(record: Dictionary, new_harbour: bool) -> Array[Dictionary]:
	var awards := ObjectiveCatalog.get_default().evaluate(_state.captains_log, record, new_harbour, _state.progress, _state.hat)
	for award in awards:
		_state.progress.award(StringName(award.id), award.title, award.reward, float(record.ended))
	return awards


## Pays the (secret) objectives a hat event completes, inside the hat's own
## transaction, so each pays exactly once (see ObjectiveProgress.can_pay()).
func _award_hat_objectives(event: Dictionary) -> Array[Dictionary]:
	var awards := ObjectiveCatalog.get_default().evaluate_hat_event(event, _state.captains_log, _state.hat, _state.progress)
	for award in awards:
		_state.progress.award(StringName(award.id), award.title, award.reward, float(event.time))
	return awards


func get_rescue_count() -> int:
	return _state.rescue_count if _state else 0


func get_last_rescue() -> Dictionary:
	return _state.last_rescue.duplicate(true) if _state else {}


## Development tools only (DevTools): sets the active boat's condition.
## Zero is not allowed here; losing the boat is left to the real weather path.
func set_condition_for_testing(percent: float) -> void:
	if _state == null:
		return
	_state.set_condition(_state.vessel_id, clampf(percent, 0.1, VesselCondition.FULL))
	_has_unsaved_changes = true
	condition_changed.emit(get_condition())


# --- Money ----------------------------------------------------------------------------

## Euros (whole).
func get_funds() -> int:
	return _state.funds if _state else 0


static func format_money(euros: int) -> String:
	var digits := str(absi(euros))
	var grouped := ""
	for i in digits.length():
		if i > 0 and (digits.length() - i) % 3 == 0:
			grouped += ","
		grouped += digits[i]
	return "€%s" % grouped


# --- Provisions -----------------------------------------------------------------------

## A copy of the food and water aboard.
func get_provisions() -> Provisions:
	return _state.provisions.duplicate_provisions() if _state else Provisions.new()


func get_food_days() -> float:
	return _state.provisions.food_days if _state else 0.0


func get_water_days() -> float:
	return _state.provisions.water_days if _state else 0.0


## Price of provisions at the grocery store: euros per missing day of food or
## of water (combined), the same in every harbour.
const PROVISIONS_PRICE_PER_DAY := 10
## Remote work: euros per completed hour, and the hours one session may last.
const REMOTE_WORK_PAY_PER_HOUR := 25
const REMOTE_WORK_MIN_HOURS := 1
const REMOTE_WORK_MAX_HOURS := 8


## Days missing to fill food and water to capacity, both counted (0-28).
func get_missing_provision_days() -> float:
	if _state == null:
		return 0.0
	return (Provisions.CAPACITY_DAYS - _state.provisions.food_days) + (Provisions.CAPACITY_DAYS - _state.provisions.water_days)


## What filling food and water to capacity costs now (whole euros, rounded up,
## so a fraction of a day is never free).
func get_provisions_price() -> int:
	return ceili(get_missing_provision_days() * PROVISIONS_PRICE_PER_DAY - 1e-6)


## Buys food and water up to capacity at the grocery store: one transaction
## that pays get_provisions_price() and fills both stores. Harbour only, and
## refused (nothing changes) when the money is not enough. Returns "" on
## success, otherwise the reason.
func buy_provisions() -> String:
	if not is_moored_in_harbour():
		return "The grocery store is only reachable while moored in harbour."
	if _state.provisions.is_full():
		return "Food and water are already full."
	var price := get_provisions_price()
	if price > _state.funds:
		return "Not enough money: %s needed, you have %s." % [format_money(price), format_money(_state.funds)]
	_state.funds -= price
	_state.provisions.restock()
	_has_unsaved_changes = true
	funds_changed.emit(_state.funds)
	provisions_changed.emit()
	return ""


## Remote work is possible while moored in harbour (a reliable connection).
func can_work_remotely() -> bool:
	return is_moored_in_harbour()


## Pays for `hours` completed hours of remote work (Simulation.work only,
## after it has advanced the time).
func pay_remote_work(hours: int) -> int:
	if _state == null or hours <= 0:
		return 0
	var earned := hours * REMOTE_WORK_PAY_PER_HOUR
	_state.funds += earned
	_has_unsaved_changes = true
	funds_changed.emit(_state.funds)
	return earned


## Development tools only (DevTools): sets food and water to `days`.
func set_provisions_for_testing(days: float) -> void:
	if _state == null:
		return
	_state.provisions.food_days = clampf(days, 0.0, Provisions.CAPACITY_DAYS)
	_state.provisions.water_days = clampf(days, 0.0, Provisions.CAPACITY_DAYS)
	_state.provisions.warning_level = Provisions.WARN_NONE
	_has_unsaved_changes = true
	_check_provisions()
	provisions_changed.emit()


## Gives each low-stores warning once (until the stores are refilled).
func _check_provisions() -> void:
	var needed := _state.provisions.needed_warning()
	if needed <= _state.provisions.warning_level:
		return
	_state.provisions.warning_level = needed
	var text := ""
	match needed:
		Provisions.WARN_LOW:
			text = "Provisions are running low: %s of food and water left." % Provisions.format_days(_state.provisions.endurance_days())
		Provisions.WARN_CRITICAL:
			text = "Provisions are critically low: less than a day of food or water left."
		_:
			text = "You have run out of food or water. Head for a harbour and buy provisions before the next passage."
	provisions_changed.emit()
	provisions_warning.emit(needed, text)


# --- Captain's hat -------------------------------------------------------------------

## Open water is looked for this far around a hat lost at sea (nm).
const OFFSHORE_CHECK_NM := 30.0


## A copy of the hat (state, strain, history).
func get_hat() -> HatState:
	return _state.hat.duplicate_hat() if _state else HatState.new()


func get_hat_status() -> StringName:
	return _state.hat.status if _state else HatState.STORED


## What a replacement hat costs (data/hat/hat_config.json).
func get_hat_price() -> int:
	return HatConfig.get_default().price_eur


## The hook in the cabin: puts the hat on when it hangs there, hangs it up
## when the player has it. Returns the message for the player.
func use_hat_hook() -> String:
	if _state == null:
		return ""
	match _state.hat.status:
		HatState.STORED:
			_set_hat_status(HatState.WORN)
			return "You put on your captain's hat. Very distinguished."
		HatState.WORN, HatState.CARRIED:
			_set_hat_status(HatState.STORED)
			return "You hang your captain's hat on its hook."
	return "An empty hat hook. Replacement captain's hats are sold at the harbour grocery store (%s)." % format_money(get_hat_price())


## The hat key (H): takes a worn hat off (it is tucked under the arm, safe from
## the wind) or puts a carried one back on. A hat on its hook stays there.
## Returns the message for the player.
func toggle_hat() -> String:
	if _state == null:
		return ""
	match _state.hat.status:
		HatState.WORN:
			_set_hat_status(HatState.CARRIED)
			return "You take off your captain's hat and tuck it under your arm."
		HatState.CARRIED:
			_set_hat_status(HatState.WORN)
			return "You put your captain's hat back on."
		HatState.STORED:
			return "Your captain's hat hangs on its hook in the cabin."
	return "You have no captain's hat. The harbour grocery store sells replacements (%s)." % format_money(get_hat_price())


## The worn hat is out in the wind: on deck. (Simulation also treats sleeping
## and working as below deck.)
func is_hat_exposed() -> bool:
	return _state != null and _state.hat.status == HatState.WORN and _state.boat_area == SessionState.AREA_EXTERIOR


## Hat checks have been made up to this game time (Simulation only).
func get_hat_checked_until() -> float:
	return _state.hat.checked_until if _state else 0.0


## The hat recovers for `ticks` hat checks in which it was not at risk (below
## deck, taken off, or light wind), the last of them at `until` (Simulation
## only).
func recover_hat(ticks: int, until: float) -> void:
	if _state == null:
		return
	var hat := _state.hat
	hat.checked_until = maxf(hat.checked_until, until)
	if ticks <= 0 or (hat.strain <= 0.0 and not hat.warned):
		return
	var config := HatConfig.get_default()
	hat.strain = maxf(hat.strain - config.recovery_per_min * config.check_interval_s / 60.0 * ticks, 0.0)
	# A new warning only after the hat has fully recovered and a while has
	# passed, so stepping in and out of the companionway never repeats it.
	if hat.strain <= 0.0 and until - hat.warned_at >= config.warning_repeat_min * 60.0:
		hat.warned = false
	_has_unsaved_changes = true


## One hat check at `time` while the hat is worn on deck (Simulation only):
## `strain_per_min` from HatConfig for the weather `sample` at `position`.
## The first check with any risk only warns; later ones add strain, and the
## hat blows away at its threshold. Returns &"" , &"warned" or &"lost".
func apply_hat_check(time: float, strain_per_min: float, sample: WeatherSample, position: Vector2) -> StringName:
	if _state == null or _state.hat.status != HatState.WORN:
		return &""
	var hat := _state.hat
	var config := HatConfig.get_default()
	hat.checked_until = maxf(hat.checked_until, time)
	if _state.voyage:
		hat.voyage_worn_hazard = maxi(hat.voyage_worn_hazard, sample.hazard)
	_has_unsaved_changes = true
	if strain_per_min <= 0.0:
		recover_hat(1, time)
		return &""
	if not hat.warned:
		hat.warned = true
		hat.warned_at = time
		hat_warning.emit("Better hold onto your hat! The wind is %d kn%s. Go below, or press H to take it off." % [
			roundi(sample.speed_kn), ", gusting %d" % roundi(sample.gust_kn) if sample.gust_kn >= sample.speed_kn + 6.0 else ""])
		return &"warned"
	hat.strain += strain_per_min * config.check_interval_s / 60.0
	if hat.strain < config.threshold_for(_state.wind_seed, hat.serial):
		return &""
	_lose_hat(time, sample, position)
	return &"lost"


func _lose_hat(time: float, sample: WeatherSample, position: Vector2) -> void:
	var hat := _state.hat
	hat.status = HatState.LOST
	hat.strain = 0.0
	hat.warned = false
	hat.lost_count += 1
	if _state.voyage:
		hat.voyage_lost = true
	var in_harbour := not is_underway()
	var place := HatStory.describe_place(position, _state.location_id if in_harbour else &"")
	var log_text := HatStory.loss_log_line(hat.lost_count, place, sample)
	hat.add_history(time, HatState.EVENT_LOST, log_text)
	_has_unsaved_changes = true
	# How far from land, for "The Sea Wears a Hat Now" (only at sea).
	var open_water := 0.0 if in_harbour else HatStory.open_water_nm(position, OFFSHORE_CHECK_NM)
	var info := {"time": time, "text": HatStory.loss_message(hat.lost_count), "log_text": log_text,
		"lost_count": hat.lost_count, "serial": hat.serial, "wind_kn": sample.speed_kn, "gust_kn": sample.gust_kn,
		"in_harbour": in_harbour, "position": {"lon": position.x, "lat": position.y},
		"bought_at": hat.bought_at, "open_water_nm": open_water}
	var awards := _award_hat_objectives({"kind": ObjectiveCatalog.HAT_EVENT_LOST, "time": time, "underway": not in_harbour,
		"open_water_nm": open_water, "bought_at": hat.bought_at})
	hat_changed.emit(hat.status)
	hat_lost.emit(info)
	if not awards.is_empty():
		renown_awarded.emit(awards)


## Buys a replacement hat at the harbour grocery store: one transaction that
## pays get_hat_price() and hands the player the new hat (carried, ready to
## put on). Harbour only, only without a hat, and refused (nothing changes)
## when the money is not enough. Returns "" on success, otherwise the reason.
func buy_hat() -> String:
	if not is_moored_in_harbour():
		return "Captain's hats are sold at the harbour grocery store, while moored in harbour."
	if _state.hat.is_owned():
		return "You already have your captain's hat."
	var price := get_hat_price()
	if price > _state.funds:
		return "Not enough money: %s needed, you have %s." % [format_money(price), format_money(_state.funds)]
	var hat := _state.hat
	_state.funds -= price
	hat.status = HatState.CARRIED
	hat.serial += 1
	hat.bought_count += 1
	hat.spent += price
	hat.bought_at = _state.game_time
	hat.strain = 0.0
	hat.warned = false
	var place := get_location()
	hat.add_history(_state.game_time, HatState.EVENT_BOUGHT, "Bought a new captain's hat in %s for %s%s." % [
		place.display_name if place else "harbour", format_money(price),
		"" if hat.bought_count == 1 else " (hat number %d)" % hat.serial])
	var awards := _award_hat_objectives({"kind": ObjectiveCatalog.HAT_EVENT_BOUGHT, "time": _state.game_time})
	_has_unsaved_changes = true
	funds_changed.emit(_state.funds)
	hat_changed.emit(hat.status)
	hat_bought.emit({"price": price, "funds_after": _state.funds, "serial": hat.serial})
	if not awards.is_empty():
		renown_awarded.emit(awards)
	return ""


func _set_hat_status(status: StringName) -> void:
	if _state.hat.status == status:
		return
	_state.hat.status = status
	_has_unsaved_changes = true
	hat_changed.emit(status)


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
