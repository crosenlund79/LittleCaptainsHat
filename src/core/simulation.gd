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
## Weather (Iteration 005a) comes from WeatherModel, the single authoritative
## source: propulsion, warnings, ETA, chart and HUD all read get_weather_at().
## While underway the weather at the boat and along the route ahead is
## assessed at every evaluation point (the same absolute 5-minute grid, plus
## departure), so warnings, sleep interruptions and the exposure record are
## identical at 1×, 20×, in one large step or while sleeping. Weather events
## are pure functions of (seed, time); nothing here changes the weather.
##
## The node is pausable: when the game is paused (menus), time stops.

signal weather_warning(warning: Dictionary)
signal arrived(port_id: StringName)

## Real seconds to game seconds at 1× (1 real second = 1 game minute).
const DEFAULT_GAME_SECONDS_PER_REAL_SECOND := 60.0
## Weather warnings look this far ahead along the course (sailing time at the
## estimated speed). Only weather that already exists is foreseen: storms that
## form later cannot be predicted.
const WARNING_HORIZON_HOURS := 6.0
## How far ahead the chart's Weather tab looks along a course.
const DISPLAY_HORIZON_HOURS := 12.0
## Distance step when looking along a course for weather (nm).
const FORECAST_STEP_NM := 2.0
## Thunderstorm cells this close (nm, from their edge) count as "nearby".
const NEARBY_STORM_NM := 15.0
## Wind and propulsion are re-evaluated on this absolute game-time grid.
const EVALUATION_INTERVAL := 300.0
## Step used to estimate remaining sailing time along a route (ETA).
const ESTIMATE_STEP_NM := 5.0
## Floor speed for time estimates, so a momentary calm never gives infinity.
const MIN_ESTIMATE_SPEED_KN := 0.5

const STOP_NONE := &""
const STOP_ARRIVAL := &"arrival"
const STOP_WARNING := &"warning"
## The boat was lost and its crew rescued (the voyage ended mid-advance).
const STOP_RESCUE := &"rescue"

## Tunable for balancing (and for tests).
var game_seconds_per_real_second := DEFAULT_GAME_SECONDS_PER_REAL_SECOND
## Tests can switch off frame-driven advancing to step time manually.
var auto_advance := true

var _eta_key := ""
var _eta_seconds := 0.0


## Outcome of an advance() call.
class AdvanceResult:
	var elapsed_seconds := 0.0
	## Why advancing stopped early (STOP_ARRIVAL / STOP_WARNING), or STOP_NONE.
	var stopped_by: StringName = &""
	var warnings: Array[Dictionary] = []
	var arrived_at: StringName = &""
	## True when a rescue ended the voyage during this advance.
	var rescued := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	GameSession.voyage_started.connect(_on_voyage_started)
	GameSession.voyage_course_changed.connect(_on_course_changed)
	GameSession.state_replaced.connect(_on_state_replaced)
	GameSession.vessel_changed.connect(_on_vessel_changed)
	GameSession.rescued.connect(func(_info: Dictionary) -> void: invalidate_estimates())


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
	# A leftover below a microsecond is floating-point residue, not time: it
	# must not run one more iteration, or an evaluation point exactly at the
	# end would be handled in this call after one big step but in the next
	# call after many small ones (and the results would differ).
	while remaining > 1e-6 and guard > 0:
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
			# The weather is assessed at every grid point (and nowhere else on
			# the way), so the result never depends on how time is chopped.
			var warned := _assess_weather(result)
			if result.rescued:
				# The voyage is over: never continue along it, whatever was asked.
				result.stopped_by = STOP_RESCUE
				break
			if warned and stop_at_events:
				result.stopped_by = STOP_WARNING
				break
		var speed := propulsion.speed_kn
		var progress := GameSession.get_voyage_progress_nm()
		var total := GameSession.get_voyage_total_nm()
		var vertex := GameSession.get_voyage_next_vertex_nm()
		var event_at := minf(total, vertex)
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
		if event_at >= total - 1e-9:
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


## The weather (and wind) anywhere at the current game time: the one query
## used by the chart, HUD, sails, sounds and simulation. The returned sample's
## from_deg/speed_kn are the sustained effective wind (what propulsion uses).
func get_wind_at(geo: Vector2) -> WeatherSample:
	return get_weather_at(geo)


## The weather at `geo` at `time` (default: now). With `known_at`, only weather
## events that exist by then are included (a forecast made at that time).
func get_weather_at(geo: Vector2, time := -1.0, known_at := INF) -> WeatherSample:
	var at := GameSession.get_game_time() if time < 0.0 else time
	return WeatherModel.get_default().sample(geo, at, GameSession.get_wind_seed(), known_at)


## The weather at the vessel now.
func get_weather_at_vessel() -> WeatherSample:
	return get_weather_at(GameSession.get_vessel_position())


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
	_assess_weather(null)


func _on_course_changed() -> void:
	invalidate_estimates()
	evaluate_propulsion(true, true)


func _on_vessel_changed(_vessel_id: StringName) -> void:
	# Another hull sails differently: cached ETAs no longer hold.
	invalidate_estimates()


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
	var model := WeatherModel.get_default()
	var known_at := GameSession.get_game_time()
	while d < total - 1e-6:
		var i := GeoMath.segment_index_at(cumulative, d)
		var heading := GeoMath.rhumb_bearing(path[i - 1], path[i])
		var wind := model.sample(GeoMath.point_along(path, cumulative, d), time + seconds, GameSession.get_wind_seed(), known_at)
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


## Remote work in harbour for `hours` (1-8): the normal simulation advanced
## in one go (food and water are used as always), then GameSession pays for
## every completed hour. Works while paused, which it leaves as it was.
## Returns {"error", "hours", "earned", "elapsed"}.
func work(hours: int) -> Dictionary:
	if not GameSession.can_work_remotely():
		return {"error": "Remote work needs a steady connection: moor in a harbour first.", "hours": 0, "earned": 0, "elapsed": 0.0}
	hours = clampi(hours, GameSession.REMOTE_WORK_MIN_HOURS, GameSession.REMOTE_WORK_MAX_HOURS)
	var result := advance(hours * 3600.0, true)
	var completed := floori(result.elapsed_seconds / 3600.0 + 1e-6)
	var earned := GameSession.pay_remote_work(completed)
	return {"error": "", "hours": completed, "earned": earned, "elapsed": result.elapsed_seconds}


## Sleeps for `hours`: the normal simulation advanced in one go, stopping
## early on arrival or when a weather warning becomes due.
func sleep(hours: float) -> AdvanceResult:
	return advance(hours * 3600.0, true)


# --- Weather along the course and warnings ------------------------------------------

## Hazardous weather (CAUTION or worse) along `path` from `from_nm`, within
## `horizon_hours` of sailing at the estimated speed: one entry per event (or
## per strong background wind), the first place it is met, with its worst
## level on the way: [{"key", "event_id", "label", "hazard", "hours",
## "distance_nm", "speed_kn", "gust_kn", "sample"}], nearest first.
## A forecast made now: only weather that already exists is foreseen. Times
## are estimates (the same simple propulsion rule as the ETA).
func route_hazards(path: PackedVector2Array, from_nm := 0.0, horizon_hours := DISPLAY_HORIZON_HOURS) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	if path.size() < 2:
		return found
	var profile := GameSession.get_vessel_profile()
	var cumulative := GeoMath.cumulative_distances(path)
	var total := cumulative[cumulative.size() - 1]
	var now := GameSession.get_game_time()
	var model := WeatherModel.get_default()
	var seed := GameSession.get_wind_seed()
	var seconds := 0.0
	var d := from_nm
	var by_key := {}
	while seconds <= horizon_hours * 3600.0:
		var geo := GeoMath.point_along(path, cumulative, d)
		var sample := model.sample(geo, now + seconds, seed, now)
		if sample.hazard >= WeatherModel.HAZARD_CAUTION:
			var key := String(sample.event_id) if not sample.event_id.is_empty() else "wind"
			if not by_key.has(key):
				by_key[key] = {"key": key, "event_id": sample.event_id, "label": sample.get_label(), "hazard": sample.hazard,
					"hours": seconds / 3600.0, "distance_nm": d - from_nm, "speed_kn": sample.speed_kn, "gust_kn": sample.gust_kn,
					"sample": sample}
				found.append(by_key[key])
			elif sample.hazard > by_key[key].hazard:
				by_key[key].hazard = sample.hazard
				by_key[key].label = sample.get_label()
				by_key[key].speed_kn = maxf(by_key[key].speed_kn, sample.speed_kn)
				by_key[key].gust_kn = maxf(by_key[key].gust_kn, sample.gust_kn)
		if d >= total - 1e-6:
			break
		var i := GeoMath.segment_index_at(cumulative, d)
		var heading := GeoMath.rhumb_bearing(path[i - 1], path[i])
		var potential := profile.sail_speed_kn(sample.speed_kn, WindField.relative_angle(heading, sample.from_deg))
		var speed := potential if potential >= profile.engine_start_below_kn else profile.engine_speed_kn
		var ds := minf(FORECAST_STEP_NM, total - d)
		seconds += ds / maxf(speed, MIN_ESTIMATE_SPEED_KN) * 3600.0
		d += ds
	return found


## Hazards ahead on the active course (the Weather tab and HUD), nearest first.
func get_hazards_ahead(horizon_hours := DISPLAY_HORIZON_HOURS) -> Array[Dictionary]:
	if not GameSession.is_underway():
		var empty: Array[Dictionary] = []
		return empty
	var voyage := GameSession.get_voyage()
	return route_hazards(voyage.route.path, voyage.progress_nm, horizon_hours)


## Thunderstorm cells near (within NEARBY_STORM_NM of their edge) `geo` now.
func get_storms_near(geo: Vector2) -> Array[WeatherEvent]:
	var near: Array[WeatherEvent] = []
	var now := GameSession.get_game_time()
	for event in WeatherModel.get_default().events_of_kind(now, WeatherEvent.KIND_THUNDERSTORM, GameSession.get_wind_seed()):
		var distance := event.offset_nm(geo, now).length()
		if distance - event.outline_radius(atan2(event.offset_nm(geo, now).x, event.offset_nm(geo, now).y), now) <= NEARBY_STORM_NM \
				and event.life_factor(now) > 0.3:
			near.append(event)
	return near


## Assesses the weather at the boat and ahead (at evaluation points while
## underway): records the exposure and gives at most one new warning. Returns
## true when a warning was given.
func _assess_weather(result: AdvanceResult) -> bool:
	if not GameSession.is_underway():
		return false
	# Damage for the time since it was last applied, sampled on the fixed
	# WeatherDamage grid (so gust bursts between evaluation points count, and
	# no stretch of time is counted twice).
	var now := GameSession.get_game_time()
	# The weather here is recorded first, so a voyage lost in it still has
	# the storm in its log record.
	var here := get_weather_at_vessel()
	GameSession.update_weather_exposure(here)
	var damage := WeatherDamage.damage_between(GameSession.get_damage_applied_until(), now,
		GameSession.get_vessel_position(), GameSession.get_wind_seed(), GameSession.get_vessel_profile().weather_damage_factor)
	if GameSession.apply_weather_damage(damage, now):
		if result:
			result.rescued = true
		return false
	var warning := _local_warning(here)
	if warning.is_empty():
		warning = _nearby_storm_warning()
	if warning.is_empty():
		warning = _route_warning()
	if warning.is_empty():
		return false
	GameSession.record_weather_warning(StringName(warning.key))
	if result:
		result.warnings.append(warning)
	weather_warning.emit(warning)
	return true


## True when this event (or the background wind) was already announced at
## `level` or worse on this voyage.
static func _is_warned(event_key: String, level: int) -> bool:
	for l in range(level, WeatherModel.HAZARD_SEVERE + 1):
		if GameSession.is_weather_warned(StringName("%s>%d" % [event_key, l])):
			return true
	return false


static func _event_key(sample: WeatherSample) -> String:
	return String(sample.event_id) if not sample.event_id.is_empty() else "wind"


func _local_warning(here: WeatherSample) -> Dictionary:
	if here.hazard < WeatherModel.HAZARD_CAUTION or _is_warned(_event_key(here), here.hazard):
		return {}
	var what := here.get_label()
	var text := ""
	match here.hazard:
		WeatherModel.HAZARD_CAUTION:
			text = "%s at the boat: wind %s, gusts %d kn." % [what, _wind_text(here), roundi(here.gust_kn)]
		WeatherModel.HAZARD_DANGEROUS:
			text = "Dangerous conditions at the boat (%s): wind %s, gusts %d kn." % [what.to_lower(), _wind_text(here), roundi(here.gust_kn)]
		_:
			text = "Severe conditions at the boat (%s): wind %s, gusts %d kn." % [what.to_lower(), _wind_text(here), roundi(here.gust_kn)]
	if here.classification == WeatherModel.CLASS_THUNDER_RISK:
		text = "Thunderstorm risk at the boat: thunderstorms may develop nearby."
	return _warning(here, "%s>%d" % [_event_key(here), here.hazard], text, 0.0, 0.0)


func _nearby_storm_warning() -> Dictionary:
	var vessel := GameSession.get_vessel_position()
	for storm in get_storms_near(vessel):
		var key := "%s>near" % storm.id
		if GameSession.is_weather_warned(StringName(key)) or _is_warned(String(storm.id), WeatherModel.HAZARD_CAUTION):
			continue
		var offset := storm.offset_nm(vessel, GameSession.get_game_time())
		var bearing := WindField.compass_name(rad_to_deg(atan2(-offset.x, -offset.y)))
		var severe := storm.peak_kn + storm.gust_kn >= WeatherModel.SEVERE_STORM_KN
		var text := "%s %d nm to the %s, moving %s." % ["Severe squalls nearby:" if severe else "Thunderstorm nearby:",
			roundi(maxf(offset.length() - storm.radius_nm, 0.0)), bearing, WindField.compass_name(storm.heading_at(GameSession.get_game_time()))]
		var sample := get_weather_at(storm.center_at(GameSession.get_game_time()))
		return _warning(sample, key, text, 0.0, offset.length())
	return {}


func _route_warning() -> Dictionary:
	for hazard in get_hazards_ahead(WARNING_HORIZON_HOURS):
		var sample: WeatherSample = hazard.sample
		if _is_warned(hazard.key, hazard.hazard):
			continue
		var expected := expected_strength(hazard)
		var text := "%s ahead on your route %s: wind up to %d kn, gusts %d kn." % [hazard.label, describe_when(hazard.hours),
			roundi(expected[0]), roundi(expected[1])]
		if sample.classification == WeatherModel.CLASS_THUNDER_RISK:
			text = "Thunderstorm risk ahead on your route %s." % describe_when(hazard.hours)
		var warning := _warning(sample, "%s>%d" % [hazard.key, hazard.hazard], text, hazard.hours, hazard.distance_nm)
		warning.hazard = hazard.hazard
		return warning
	return {}


## The strongest wind and gusts a hazard ahead may bring: what the forecast
## met on the course, or the responsible event's core strength if more.
func expected_strength(hazard: Dictionary) -> Array:
	var sustained: float = hazard.speed_kn
	var gust: float = hazard.gust_kn
	var event := WeatherModel.get_default().find_event(hazard.event_id, GameSession.get_game_time(), GameSession.get_wind_seed()) \
		if not String(hazard.event_id).is_empty() else null
	if event:
		var sample: WeatherSample = hazard.sample
		var core := WeatherModel.event_strength(event, GameSession.get_game_time() + hazard.hours * 3600.0, sample.background_kn)
		sustained = maxf(sustained, core[0])
		gust = maxf(gust, core[1])
	return [sustained, gust]


func _warning(sample: WeatherSample, key: String, text: String, hours: float, distance_nm: float) -> Dictionary:
	return {"key": key, "text": text, "title": sample.get_label(), "hazard": sample.hazard, "hours": hours,
		"distance_nm": distance_nm, "event_id": sample.event_id, "classification": sample.classification,
		"event_kind": sample.event_kind, "sample": sample}


static func _wind_text(sample: WeatherSample) -> String:
	return "%s %d kn" % [WindField.compass_name(sample.from_deg), roundi(sample.speed_kn)]


## "now", "within the hour", "in about 2–3 h": forecast times are estimates,
## shown as a range rather than to the minute.
static func describe_when(hours: float) -> String:
	if hours < 0.25:
		return "now"
	if hours < 1.0:
		return "within the hour"
	return "in about %d–%d h" % [floori(hours), floori(hours) + 1]


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
