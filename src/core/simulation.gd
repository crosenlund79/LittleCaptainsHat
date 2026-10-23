extends Node
## The single authoritative simulation timeline.
##
## Every frame Simulation turns real time into game time (base rate × the
## player's time acceleration) and advances the clock and the active voyage
## by exactly that amount. Sleeping advances the same timeline in one call.
## Nothing else in the game advances time or moves the vessel.
##
## Advancing is event-driven: the elapsed time is split at the exact moments
## something happens (arrival, a weather warning becoming due), so any step
## size, from one frame at 1× to eight hours of sleep, produces the same
## positions and events. Cost per call is proportional to the number of events,
## not to the amount of time simulated.
##
## The node is pausable: when the game is paused (menus), time stops.

signal weather_warning(warning: Dictionary)
signal arrived(port_id: StringName)

## Real seconds to game seconds at 1× (1 real second = 1 game minute).
const DEFAULT_GAME_SECONDS_PER_REAL_SECOND := 60.0
## Warnings are given when a noteworthy condition lies within this much
## sailing time along the remaining course.
const WARNING_HORIZON_HOURS := 5.0

const STOP_NONE := &""
const STOP_ARRIVAL := &"arrival"
const STOP_WARNING := &"warning"

## Tunable for balancing (and for tests).
var game_seconds_per_real_second := DEFAULT_GAME_SECONDS_PER_REAL_SECOND
## Tests can switch off frame-driven advancing to step time manually.
var auto_advance := true

var _encounters: Array[Dictionary] = []
var _encounters_key := ""


## Outcome of an advance() call.
class AdvanceResult:
	var elapsed_seconds := 0.0
	## Why advancing stopped early (STOP_ARRIVAL / STOP_WARNING), or STOP_NONE.
	var stopped_by: StringName = &""
	var warnings: Array[Dictionary] = []
	var arrived_at: StringName = &""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE


func _process(delta: float) -> void:
	if auto_advance:
		tick(delta)


## Advances the game for `real_seconds` of real time at the current time
## acceleration (what happens every frame).
func tick(real_seconds: float) -> void:
	if not GameSession.is_active():
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
	while remaining > 0.0:
		var time := GameSession.get_game_time()
		if not GameSession.is_underway():
			GameSession.apply_simulation_step(time + remaining, 0.0)
			result.elapsed_seconds += remaining
			break
		var speed := GameSession.get_vessel_speed_kn()
		var progress := GameSession.get_voyage_progress_nm()
		var total := GameSession.get_voyage_total_nm()
		var due := _next_due_warning(progress, speed)
		var event_at := total
		if not due.is_empty():
			event_at = minf(event_at, due.trigger_nm)
		var to_event := maxf(event_at - progress, 0.0) / speed * 3600.0
		if to_event > remaining:
			GameSession.apply_simulation_step(time + remaining, progress + speed * remaining / 3600.0)
			result.elapsed_seconds += remaining
			break
		# Step exactly to the event.
		GameSession.apply_simulation_step(time + to_event, event_at)
		result.elapsed_seconds += to_event
		remaining -= to_event
		if not due.is_empty() and due.trigger_nm <= event_at and due.trigger_nm < total:
			var warning := _make_warning(due, event_at, speed)
			GameSession.record_weather_warning(due.condition.id)
			result.warnings.append(warning)
			weather_warning.emit(warning)
			if stop_at_events:
				result.stopped_by = STOP_WARNING
				break
		else:
			var destination := GameSession.get_voyage_destination_id()
			GameSession.complete_voyage()
			result.arrived_at = destination
			arrived.emit(destination)
			if stop_at_events:
				result.stopped_by = STOP_ARRIVAL
				break
	return result


## Sleeps for `hours`: the normal simulation advanced in one go, stopping
## early on arrival or when a weather warning becomes due.
func sleep(hours: float) -> AdvanceResult:
	return advance(hours * 3600.0, true)


func get_warning_horizon_nm() -> float:
	return WARNING_HORIZON_HOURS * GameSession.get_vessel_speed_kn()


## All noteworthy conditions still ahead on the active course, nearest first:
## [{"condition", "at_nm" (distance ahead), "hours"}]. For display.
func get_conditions_ahead() -> Array[Dictionary]:
	var ahead: Array[Dictionary] = []
	if not GameSession.is_underway():
		return ahead
	var progress := GameSession.get_voyage_progress_nm()
	var speed := GameSession.get_vessel_speed_kn()
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
	var hours: float = maxf(due.at_nm - progress, 0.0) / speed
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
