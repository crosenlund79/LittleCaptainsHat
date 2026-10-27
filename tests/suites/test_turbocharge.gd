extends RefCounted
## Turbocharge (performance pass): the quick weather path must give exactly
## the results of the full one, everywhere it is used.
##   - WeatherModel.sample_hazard() == sample() in wind, gusts and hazard;
##   - Simulation.route_hazards() == the previous implementation (kept here
##     as a reference), on representative routes, dates and seeds;
##   - WeatherDamage.damage_between() == the previous implementation;
##   - and it is cheaper (a loose guard, not a frame-time target).

var t: Node
var catalog: PortCatalog


func run(runner: Node) -> void:
	t = runner
	catalog = PortCatalog.get_default()
	Simulation.auto_advance = false
	# Real weather (the runner's calm-wind fixture would leave nothing to compare).
	WindField.get_default().test_override = Callable()
	Simulation.invalidate_estimates()
	GameSession.start_new_session()
	_test_quick_sample()
	_test_route_hazards()
	_test_damage()
	_test_sleep_identity()
	t.use_calm_wind()
	Simulation.auto_advance = true
	GameSession.end_session()


## Places and times with every kind of weather: Baltic summer, North
## Atlantic winter gales, Caribbean hurricane season, the Bay of Bengal.
const PLACES := [Vector2(12.6, 55.7), Vector2(-25.0, 55.0), Vector2(-60.0, 18.0), Vector2(88.0, 15.0), Vector2(179.5, -18.0),
	Vector2(-179.5, -18.0), Vector2(150.0, 20.0), Vector2(-40.0, -50.0)]
const DATES := ["2026-05-01T08:00:00", "2026-09-10T00:00:00", "2027-01-15T12:00:00"]


func _test_quick_sample() -> void:
	var model := WeatherModel.get_default()
	var compared := 0
	var mismatches := []
	var hazards := 0
	for seed in [1, 7, 42]:
		for date in DATES:
			var t0 := Time.get_unix_time_from_datetime_string(date)
			for place: Vector2 in PLACES:
				for k in 40:
					var geo: Vector2 = place + Vector2(fmod(k * 1.7, 9.0) - 4.5, fmod(k * 2.3, 7.0) - 3.5)
					var time := t0 + k * 5400.0
					for known_at in [INF, t0]:
						var full := model.sample(geo, time, seed, known_at)
						var quick := model.sample_hazard(geo, time, seed, known_at)
						compared += 1
						hazards += 1 if full.hazard >= WeatherModel.HAZARD_CAUTION else 0
						if quick[0] != full.from_deg or quick[1] != full.speed_kn or quick[2] != full.gust_kn or int(quick[3]) != full.hazard:
							mismatches.append([geo, time, seed, quick, [full.from_deg, full.speed_kn, full.gust_kn, full.hazard]])
	t.check(mismatches.is_empty() and hazards > 50, "[weather] the quick sample equals the full one exactly: %d samples (%d with a hazard), %d differ %s" % [
		compared, hazards, mismatches.size(), mismatches.slice(0, 2)])


## The previous Simulation.route_hazards() (before Turbocharge), unchanged.
static func _reference_route_hazards(path: PackedVector2Array, from_nm: float, horizon_hours: float) -> Array[Dictionary]:
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
		var ds := minf(Simulation.FORECAST_STEP_NM, total - d)
		seconds += ds / maxf(speed, Simulation.MIN_ESTIMATE_SPEED_KN) * 3600.0
		d += ds
	return found


static func _strip(hazards: Array[Dictionary]) -> Array:
	return hazards.map(func(h: Dictionary) -> Array: return [h.key, h.hazard, h.hours, h.distance_nm, h.speed_kn, h.gust_kn, h.label,
		(h.sample as WeatherSample).classification])


func _set_time(date: String, seed: int) -> void:
	var state := GameSession.get_state_snapshot()
	state.game_time = Time.get_unix_time_from_datetime_string(date)
	state.wind_seed = seed
	GameSession.replace_state(state)


func _test_route_hazards() -> void:
	var routes := [[&"copenhagen", &"reykjavik"], [&"limassol", &"noumea"], [&"castries", &"panama_city"], [&"noumea", &"papeete"],
		[&"kiel", &"cuxhaven"]]
	var compared := 0
	var with_hazards := 0
	var differ := []
	var quick_us := 0
	var reference_us := 0
	for pair in routes:
		var route := SeaRouter.get_default().plan_route(pair[0], catalog.get_port(pair[0]).get_geo_position(), [] as Array[Vector2], pair[1]).route
		if route == null:
			differ.append("no route %s" % [pair])
			continue
		var total := route.get_distance_nm()
		for seed in [1, 42]:
			for date in DATES:
				_set_time(date, seed)
				for f in [0.0, 0.37, 0.81]:
					var from: float = total * f
					# Both once to warm the weather caches, then timed in turn.
					var fast := Simulation.route_hazards(route.path, from, Simulation.DISPLAY_HORIZON_HOURS)
					var slow := _reference_route_hazards(route.path, from, Simulation.DISPLAY_HORIZON_HOURS)
					for rep in 2:
						var c0 := Time.get_ticks_usec()
						_reference_route_hazards(route.path, from, Simulation.DISPLAY_HORIZON_HOURS)
						var c1 := Time.get_ticks_usec()
						Simulation.route_hazards(route.path, from, Simulation.DISPLAY_HORIZON_HOURS)
						quick_us += Time.get_ticks_usec() - c1
						reference_us += c1 - c0
					compared += 1
					with_hazards += 1 if not slow.is_empty() else 0
					if _strip(fast) != _strip(slow):
						differ.append([pair, seed, date, f])
	t.check(differ.is_empty() and with_hazards >= 5, "[route] route hazards identical to the previous scan: %d scans (%d with hazards) on Baltic, Suez, Panama, Pacific and canal routes; %d differ %s" % [
		compared, with_hazards, differ.size(), differ.slice(0, 3)])
	t.check(quick_us < reference_us, "[route] and cheaper: %.1f ms against %.1f ms for the same scans" % [quick_us / 1000.0, reference_us / 1000.0])


func _test_damage() -> void:
	var model := WeatherModel.get_default()
	var differ := 0
	var nonzero := 0
	var count := 0
	for seed in [1, 42]:
		for date in DATES:
			var t0 := Time.get_unix_time_from_datetime_string(date)
			for place: Vector2 in PLACES:
				for k in 6:
					var from := t0 + k * 7200.0
					var fast := WeatherDamage.damage_between(from, from + 3600.0, place, seed, 1.0)
					var slow := 0.0
					var step := floorf(from / WeatherDamage.SUBSTEP) + 1.0
					while step * WeatherDamage.SUBSTEP <= from + 3600.0 + 1e-6:
						var sample := model.sample(place, step * WeatherDamage.SUBSTEP, seed)
						slow += WeatherDamage.rate_per_hour(sample.speed_kn, sample.gust_kn, 1.0) * WeatherDamage.SUBSTEP / 3600.0
						step += 1.0
					count += 1
					nonzero += 1 if slow > 0.0 else 0
					differ += 1 if fast != slow else 0
	t.check(differ == 0 and nonzero > 0, "[damage] weather damage identical to before: %d hours (%d with damage), %d differ" % [count, nonzero, differ])


## Whole sleeps underway (the hot path): two identical runs, the same end.
func _test_sleep_identity() -> void:
	var results := []
	for run in 2:
		GameSession.start_new_session()
		_moor(&"copenhagen", "2026-10-20T20:00:00", 3)
		GameSession.plan_route_to(&"reykjavik")
		GameSession.depart()
		var warnings := []
		for night in 3:
			var r := Simulation.sleep(8.0)
			warnings.append([String(r.stopped_by), r.warnings.map(func(w: Dictionary) -> String: return String(w.key))])
		results.append([GameSession.get_vessel_position(), GameSession.get_game_time(), GameSession.get_condition(),
			GameSession.get_provisions().food_days, warnings])
	t.check(results[0] == results[1], "[sleep] three nights underway in October seas end the same way each time (%s / %s)" % [results[0], results[1]])


func _moor(port_id: StringName, date: String, seed: int) -> void:
	var state := GameSession.get_state_snapshot()
	state.location_id = port_id
	state.vessel_status = SessionState.STATUS_MOORED
	state.vessel_position = catalog.get_port(port_id).get_geo_position()
	state.voyage = null
	state.planned_route = null
	state.game_time = Time.get_unix_time_from_datetime_string(date)
	state.wind_seed = seed
	GameSession.replace_state(state)
