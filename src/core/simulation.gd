extends Node
## The single authoritative simulation timeline.
##
## Every frame Simulation turns real time into game time (base rate × the
## player's time acceleration) and advances the clock and the active voyage
## by exactly that amount. Sleeping advances the same timeline in one call.
## Nothing else in the game advances time or moves the vessel.
##
## Speed varies with wind and propulsion. It is (re)evaluated only at fixed
## evaluation points: an absolute grid every EVALUATION_INTERVAL game seconds,
## every route vertex (the heading changes there), departure and changes of
## course. Between evaluation points the speed is constant, so events
## (arrival, weather warnings, the next vertex or grid point) can be solved
## exactly. Because the evaluation points do not depend on how time is
## chopped into calls, one 8-hour step and 9,600 three-second frames produce
## the same positions, propulsion changes and events. Cost per call grows with
## the number of evaluation points and events, not with frame count.
##
## The node is pausable: when the game is paused (menus), time stops.

signal weather_warning(warning: Dictionary)
signal arrived(port_id: StringName)

## Real seconds to game seconds at 1× (1 real second = 1 game minute).
const DEFAULT_GAME_SECONDS_PER_REAL_SECOND := 60.0
## Warnings are given when a noteworthy condition lies within this much
## sailing time (at the current speed) along the remaining course.
const WARNING_HORIZON_HOURS := 5.0
## Wind and propulsion are re-evaluated on this absolute game-time grid.
const EVALUATION_INTERVAL := 300.0
## Step used to estimate remaining sailing time along a route (ETA).
const ESTIMATE_STEP_NM := 5.0
## Floor speed for time estimates, so a momentary calm never gives infinity.
const MIN_ESTIMATE_SPEED_KN := 0.5

const STOP_NONE := &""
const STOP_ARRIVAL := &"arrival"
const STOP_WARNING := &"warning"

## Tunable for balancing (and for tests).
var game_seconds_per_real_second := DEFAULT_GAME_SECONDS_PER_REAL_SECOND
## Tests can switch off frame-driven advancing to step time manually.
var auto_advance := true

var _encounters: Array[Dictionary] = []
var _encounters_key := ""
var _eta_key := ""
var _eta_seconds := 0.0


## Outcome of an advance() call.
class AdvanceResult:
	var elapsed_seconds := 0.0
	## Why advancing stopped early (STOP_ARRIVAL / STOP_WARNING), or STOP_NONE.
	var stopped_by: StringName = &""
	var warnings: Array[Dictionary] = []
	var arrived_at: StringName = &""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	GameSession.voyage_started.connect(_on_voyage_started)
	GameSession.voyage_course_changed.connect(_on_course_changed)
	GameSession.state_replaced.connect(_on_state_replaced)


func _process(delta: float) -> void:
	if auto_advance:
		tick(delta)


## Advances the game for `real_seconds` of real time at the current time
## acceleration (what happens every frame).
##
## While the player has paused the game (GameSession.is_paused()) the clock
## stands still: no time, no movement, no wind change, no companion moves.
## Explicit advances (sleeping) still work and leave the pause as it was.
func tick(real_seconds: float) -> void:
	if not GameSession.is_active() or GameSession.is_paused():
		return
	var result := advance(real_seconds * game_seconds_per_real_second * GameSession.get_time_scale())
	# Accelerated time drops back to normal speed when something needs the
	# player's attention, so nothing actionable flies past at 20×.
	if not result.warnings.is_empty() and GameSession.get_time_scale() > 1:
		GameSession.set_time_scale(1)


## Advances the game by `seconds` of game time. With `stop_at_events`, it stops
## at the first arrival or newly due weather warning (used by sleeping).
func advance(seconds: float, stop_at_events := false) -> AdvanceResult:
	var result := AdvanceResult.new()
	if not GameSession.is_active() or seconds <= 0.0:
		return result
	var remaining := seconds
	var guard := 1000000
	while remaining > 1e-9 and guard > 0:
		guard -= 1
		var time := GameSession.get_game_time()
		if not GameSession.is_underway():
			GameSession.apply_simulation_step(time + remaining, 0.0)
			result.elapsed_seconds += remaining
			break
		var propulsion := GameSession.get_propulsion()
		var next_grid := _next_grid_time(propulsion.last_evaluation_time)
		if not propulsion.initialised or time >= next_grid - 1e-6:
			evaluate_propulsion()
			propulsion = GameSession.get_propulsion()
			next_grid = _next_grid_time(propulsion.last_evaluation_time)
		var speed := propulsion.speed_kn
		var progress := GameSession.get_voyage_progress_nm()
		var total := GameSession.get_voyage_total_nm()
		var vertex := GameSession.get_voyage_next_vertex_nm()
		var due := _next_due_warning(progress, speed)
		var event_at := minf(total, vertex)
		if not due.is_empty():
			event_at = minf(event_at, due.trigger_nm)
		var to_event := (maxf(event_at - progress, 0.0) / speed * 3600.0) if speed > 0.0 else INF
		var to_grid := maxf(next_grid - time, 0.0)
		var step := minf(remaining, minf(to_event, to_grid))
		var reached_event := to_event <= step
		var new_progress := event_at if reached_event else progress + speed * step / 3600.0
		GameSession.apply_simulation_step(time + step, new_progress)
		result.elapsed_seconds += step
		remaining -= step
		if not reached_event:
			continue  # a grid point or the end of the requested time
		if not due.is_empty() and due.trigger_nm <= event_at + 1e-9 and due.trigger_nm < total:
			var warning := _make_warning(due, event_at, speed)
			GameSession.record_weather_warning(due.condition.id)
			result.warnings.append(warning)
			weather_warning.emit(warning)
			if stop_at_events:
				result.stopped_by = STOP_WARNING
				break
		elif event_at >= total - 1e-9:
			var destination := GameSession.get_voyage_destination_id()
			GameSession.complete_voyage()
			result.arrived_at = destination
			arrived.emit(destination)
			if stop_at_events:
				result.stopped_by = STOP_ARRIVAL
				break
		else:
			evaluate_propulsion()  # new leg: new heading
	return result


## Samples the wind at the vessel and lets the propulsion controller decide
## sail or engine and the speed until the next evaluation point.
## `reset_history` restarts the rolling average from the current heading;
## `reassess` lets clearly good or poor conditions decide at once (see
## PropulsionController).
func evaluate_propulsion(reset_history := false, reassess := false) -> void:
	if not GameSession.is_underway():
		return
	var wind := get_wind_at(GameSession.get_vessel_position())
	var state := PropulsionController.evaluate(GameSession.get_propulsion(), GameSession.get_vessel_profile(),
		GameSession.get_game_time(), get_current_heading(), wind, reset_history, reassess)
	GameSession.set_propulsion(state)


## The helm's "Check sail configuration": a fresh assessment of the current
## heading and local wind through the normal controller (same safeguards; no
## timer is reset). Returns {"changed", "before", "after"} (PropulsionStates)
## so the caller can describe the result. Does nothing in port.
func reassess_propulsion() -> Dictionary:
	if not GameSession.is_underway():
		return {}
	var before := GameSession.get_propulsion()
	evaluate_propulsion(false, true)
	var after := GameSession.get_propulsion()
	return {"changed": before.mode != after.mode, "before": before, "after": after}


## The wind anywhere at the current game time (the one query used by the
## chart, HUD, sails and simulation).
func get_wind_at(geo: Vector2) -> WindField.Sample:
	return WindField.get_default().sample(geo, GameSession.get_game_time(), GameSession.get_wind_seed())


## Heading (true, degrees) of the route leg the vessel is on.
func get_current_heading() -> float:
	var voyage := GameSession.get_voyage()
	if voyage == null:
		return 0.0
	var i := GeoMath.segment_index_at(voyage.get_cumulative(), voyage.progress_nm)
	return GeoMath.rhumb_bearing(voyage.route.path[i - 1], voyage.route.path[i])


func _next_grid_time(last_evaluation: float) -> float:
	return (floorf(last_evaluation / EVALUATION_INTERVAL) + 1.0) * EVALUATION_INTERVAL


func _on_voyage_started() -> void:
	invalidate_estimates()
	evaluate_propulsion()


func _on_course_changed() -> void:
	invalidate_estimates()
	evaluate_propulsion(true, true)


func _on_state_replaced() -> void:
	invalidate_estimates()
	# Loaded voyages keep their saved controller state; only a migrated (never
	# evaluated) one is evaluated straight away.
	if GameSession.is_underway() and not GameSession.get_propulsion().initialised:
		evaluate_propulsion()


# --- Estimates ----------------------------------------------------------------------

## Estimated sailing time in seconds along `path` from `from_nm` to its end,
## starting at `start_time`. Walks the route in ESTIMATE_STEP_NM steps, using
## the wind expected at each point and time and a simple propulsion rule (sail
## if the potential beats the engine-start threshold, otherwise motor). It is
## an estimate: it ignores the controller's averaging and hysteresis.
func estimate_route_seconds(path: PackedVector2Array, from_nm := 0.0, start_time := -1.0, to_nm := -1.0) -> float:
	if path.size() < 2:
		return 0.0
	var profile := GameSession.get_vessel_profile()
	var cumulative := GeoMath.cumulative_distances(path)
	var total := cumulative[cumulative.size() - 1]
	if to_nm >= 0.0:
		total = minf(total, to_nm)
	var time := GameSession.get_game_time() if start_time < 0.0 else start_time
	var seconds := 0.0
	var d := from_nm
	var field := WindField.get_default()
	while d < total - 1e-6:
		var i := GeoMath.segment_index_at(cumulative, d)
		var heading := GeoMath.rhumb_bearing(path[i - 1], path[i])
		var wind := field.sample(GeoMath.point_along(path, cumulative, d), time + seconds, GameSession.get_wind_seed())
		var potential := profile.sail_speed_kn(wind.speed_kn, WindField.relative_angle(heading, wind.from_deg))
		var speed := potential if potential >= profile.engine_start_below_kn else profile.engine_speed_kn
		var ds := minf(ESTIMATE_STEP_NM, total - d)
		seconds += ds / maxf(speed, MIN_ESTIMATE_SPEED_KN) * 3600.0
		d += ds
	return seconds


## Estimated game time of arrival for the active voyage (cached; refreshed as
## the boat moves on or time passes).
func get_eta() -> float:
	if not GameSession.is_underway():
		return 0.0
	var progress := GameSession.get_voyage_progress_nm()
	var key := "%d|%s|%.3f|%d|%d|%d" % [GameSession.get_voyage_revision(), GameSession.get_voyage_destination_id(),
		GameSession.get_voyage_total_nm(), GameSession.get_wind_seed(), floori(progress / 2.0),
		floori(GameSession.get_game_time() / 1800.0)]
	if key != _eta_key:
		_eta_key = key
		var voyage := GameSession.get_voyage()
		_eta_seconds = estimate_route_seconds(voyage.route.path, progress)
	return GameSession.get_game_time() + _eta_seconds


## Forgets cached estimates (after the voyage, a loaded game or the wind changed).
func invalidate_estimates() -> void:
	_eta_key = ""


## Sleeps for `hours`: the normal simulation advanced in one go, stopping
## early on arrival or when a weather warning becomes due.
func sleep(hours: float) -> AdvanceResult:
	return advance(hours * 3600.0, true)


## All noteworthy conditions still ahead on the active course, nearest first:
## [{"condition", "at_nm" (distance ahead), "hours"}]. For display.
func get_conditions_ahead() -> Array[Dictionary]:
	var ahead: Array[Dictionary] = []
	if not GameSession.is_underway():
		return ahead
	var progress := GameSession.get_voyage_progress_nm()
	var speed := maxf(GameSession.get_vessel_speed_kn(), MIN_ESTIMATE_SPEED_KN)
	for encounter in _get_encounters():
		if encounter.at_nm >= progress - 1e-6:
			var distance: float = encounter.at_nm - progress
			ahead.append({"condition": encounter.condition, "at_nm": distance, "hours": distance / speed})
	return ahead


## The earliest not-yet-announced encounter and the progress at which its
## warning is due (when it is WARNING_HORIZON_HOURS of sailing away).
func _next_due_warning(progress: float, speed: float) -> Dictionary:
	var horizon := WARNING_HORIZON_HOURS * speed
	var best := {}
	for encounter in _get_encounters():
		var condition: WeatherCondition = encounter.condition
		if GameSession.is_weather_warned(condition.id) or encounter.at_nm < progress - 1e-6:
			continue
		var trigger := maxf(encounter.at_nm - horizon, progress)
		if best.is_empty() or trigger < best.trigger_nm:
			best = {"condition": condition, "at_nm": encounter.at_nm, "trigger_nm": trigger}
	return best


func _make_warning(due: Dictionary, progress: float, speed: float) -> Dictionary:
	var condition: WeatherCondition = due.condition
	var hours: float = maxf(due.at_nm - progress, 0.0) / maxf(speed, MIN_ESTIMATE_SPEED_KN)
	var when := "now" if hours < 0.1 else "in about %s" % format_duration(hours * 3600.0)
	return {
		"condition": condition,
		"hours": hours,
		"distance_nm": maxf(due.at_nm - progress, 0.0),
		"text": "%s expected along your route %s." % [condition.display_name, when],
	}


## Encounters along the active course, cached per voyage revision.
func _get_encounters() -> Array[Dictionary]:
	var voyage_key := "%d:%d:%s" % [GameSession.get_voyage_revision(), GameSession.get_voyage_total_nm() * 1000.0,
		GameSession.get_voyage_destination_id()]
	if voyage_key != _encounters_key:
		_encounters_key = voyage_key
		_encounters.clear()
		var voyage := GameSession.get_voyage()
		if voyage:
			_encounters = WeatherCatalog.get_default().find_encounters(voyage.route.path, voyage.get_cumulative(), 0.0)
	return _encounters


## "4 h 50 min", "35 min", "2 d 3 h".
static func format_duration(seconds: float) -> String:
	var minutes := roundi(seconds / 60.0)
	if minutes < 60:
		return "%d min" % minutes
	var hours := minutes / 60
	if hours < 48:
		return "%d h %02d min" % [hours, minutes % 60] if minutes % 60 else "%d h" % hours
	return "%d d %d h" % [hours / 24, hours % 24]


## "Fri 1 May 2026, 08:00 UTC"
static func format_game_time(unix_time: float, with_zone := true) -> String:
	var d := Time.get_datetime_dict_from_unix_time(int(unix_time))
	const DAYS := ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
	const MONTHS := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
	return "%s %d %s %d, %02d:%02d%s" % [DAYS[d.weekday], d.day, MONTHS[d.month - 1], d.year, d.hour, d.minute,
		" UTC" if with_zone else ""]
