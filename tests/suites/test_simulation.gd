extends RefCounted
## Game clock, voyages, sleeping, weather warnings and changing course,
## driven directly through Simulation and GameSession.

## A fixed strong-wind area where Iteration 002's demonstration area was
## (between Møn and Rügen, on the Copenhagen -> Kiel course), as a fixture of
## the one weather model.
const STRONG_WINDS := &"test_strong_winds"
const STRONG_WINDS_CENTER := Vector2(12.2, 54.78)
const AVOID_WAYPOINT := Vector2(12.62, 54.55)

var t: Node
var warnings: Array[Dictionary] = []


func run(runner: Node) -> void:
	t = runner
	Simulation.auto_advance = false
	Simulation.weather_warning.connect(_on_warning)
	await _test_clock()
	_test_voyage_basics()
	_test_step_independence()
	_test_arrival_and_next_voyage()
	_test_sleep()
	WeatherFixtures.use([WeatherFixtures.gale(String(STRONG_WINDS), STRONG_WINDS_CENTER, 9.0, 26.0,
		SessionState.get_start_time() - 3600.0, 24.0 * 365.0)])
	_test_weather_warnings()
	_test_rerouting()
	WeatherFixtures.clear()
	Simulation.weather_warning.disconnect(_on_warning)
	Simulation.auto_advance = true
	GameSession.end_session()


func _on_warning(warning: Dictionary) -> void:
	# Where and when it was given (the warning fires at an evaluation point).
	warning["at_progress"] = GameSession.get_voyage_progress_nm()
	warning["at_time"] = GameSession.get_game_time()
	warnings.append(warning)


func _test_clock() -> void:
	GameSession.start_new_session()
	t.check_eq(GameSession.get_game_time(), SessionState.get_start_time(), "a new game starts at the documented start time")
	t.check_eq(Simulation.format_game_time(GameSession.get_game_time()), "Fri 1 May 2026, 08:00 UTC", "start time is 1 May 2026, 08:00 UTC")
	var expectations := {1: 60.0, 5: 300.0, 20: 1200.0}
	for scale: int in expectations:
		GameSession.set_time_scale(scale)
		var before := GameSession.get_game_time()
		Simulation.tick(1.0)
		t.check(is_equal_approx(GameSession.get_game_time() - before, expectations[scale]),
			"1 real second at %d× advances %d game seconds" % [scale, expectations[scale]])
	GameSession.set_time_scale(1)

	# Pausing the tree stops the simulation node; unpausing resumes it.
	Simulation.auto_advance = true
	t.get_tree().paused = true
	var paused_at := GameSession.get_game_time()
	await t.get_tree().create_timer(0.3, true).timeout
	t.check_eq(GameSession.get_game_time(), paused_at, "game time stands still while the game is paused")
	t.get_tree().paused = false
	await t.get_tree().create_timer(0.3, true).timeout
	var advanced := GameSession.get_game_time() - paused_at
	t.check(advanced > 5.0 and advanced < 40.0, "game time runs at about 60× real time when unpaused (%.1f s in 0.3 s)" % advanced)
	Simulation.auto_advance = false


func _test_voyage_basics() -> void:
	_new_game_with_route(&"copenhagen", &"kiel")
	var start_time := GameSession.get_game_time()
	t.check_eq(GameSession.depart(), "", "departure starts a voyage")
	t.check(GameSession.is_underway() and GameSession.get_location_id().is_empty(), "the vessel is underway and no longer in port")
	t.check(GameSession.get_planned_route() == null, "the planned route became the active voyage")
	var start := GameSession.get_vessel_position()
	Simulation.advance(2.0 * 3600.0)
	t.check(is_equal_approx(GameSession.get_game_time() - start_time, 7200.0), "two hours of game time passed")
	t.check(absf(GameSession.get_voyage_progress_nm() - 10.0) < 1e-6, "2 h at 5 kn covers 10 nm (got %.6f)" % GameSession.get_voyage_progress_nm())
	t.check(GameSession.get_vessel_position() != start, "the vessel position changed")
	var voyage := GameSession.get_voyage()
	t.check(GameSession.get_vessel_position().is_equal_approx(voyage.position_at(10.0)), "the position lies on the route at 10 nm")
	t.check(SeaRouter.get_default().is_point_navigable(GameSession.get_vessel_position())
		or GeoMath.rhumb_distance_nm(GameSession.get_vessel_position(), PortCatalog.get_default().get_port(&"copenhagen").get_geo_position()) <= SeaRouter.MAX_APPROACH_NM,
		"the vessel is in navigable water (or in the harbour approach)")
	t.check(GameSession.get_vessel_speed_kn() == VesselProfile.get_default().engine_speed_kn and GameSession.is_motoring(),
		"in a calm the boat motors at the profile's engine speed (5 kn)")


func _test_step_independence() -> void:
	# The same voyage advanced in one big step and in many small steps must
	# end up in the same place at the same time.
	_new_game_with_route(&"kiel", &"gothenburg", [], true)
	GameSession.depart()
	Simulation.advance(15.0 * 3600.0)
	var big_step := [GameSession.get_game_time(), GameSession.get_voyage_progress_nm(), GameSession.get_vessel_position()]
	_new_game_with_route(&"kiel", &"gothenburg", [], true)
	GameSession.depart()
	for i in 900:
		Simulation.advance(60.0)
	t.check(absf(GameSession.get_game_time() - big_step[0]) < 1e-3, "clock agrees between 1 × 15 h and 900 × 1 min steps")
	t.check(absf(GameSession.get_voyage_progress_nm() - big_step[1]) < 1e-6, "progress agrees between step sizes")
	t.check(GameSession.get_vessel_position().distance_to(big_step[2]) < 1e-5, "position agrees between step sizes")
	var voyage := GameSession.get_voyage()
	var cumulative := voyage.get_cumulative()
	var vertices_passed := 0
	for d in cumulative:
		if d < voyage.progress_nm:
			vertices_passed += 1
	t.check(vertices_passed >= 3, "the voyage crossed several route segments (%d vertices passed)" % vertices_passed)


func _test_arrival_and_next_voyage() -> void:
	_new_game_with_route(&"kiel", &"gothenburg", [], true)
	var departure_time := GameSession.get_game_time()
	GameSession.depart()
	var total := GameSession.get_voyage_total_nm()
	var arrived := []
	var on_arrived := func(port: StringName) -> void: arrived.append(port)
	Simulation.arrived.connect(on_arrived)
	Simulation.advance(1000.0 * 3600.0)
	Simulation.arrived.disconnect(on_arrived)
	t.check_eq(arrived, [&"gothenburg"], "arrival is reported once")
	t.check_eq(GameSession.get_vessel_status(), SessionState.STATUS_ARRIVED, "voyage state is Arrived")
	t.check_eq(GameSession.get_location_id(), &"gothenburg", "Gothenburg is now the current location")
	t.check(GameSession.get_vessel_position().is_equal_approx(PortCatalog.get_default().get_port(&"gothenburg").get_geo_position()),
		"the vessel lies at Gothenburg")
	t.check(not GameSession.is_underway() and GameSession.get_voyage() == null, "the voyage is complete")
	t.check(is_equal_approx(GameSession.get_game_time(), departure_time + 1000.0 * 3600.0), "the clock keeps running after arrival")

	_new_game_with_route(&"kiel", &"gothenburg", [], true)
	departure_time = GameSession.get_game_time()
	GameSession.depart()
	var result := Simulation.advance(1000.0 * 3600.0, true)
	t.check_eq(result.stopped_by, Simulation.STOP_ARRIVAL, "an event-stopping advance stops at arrival")
	t.check(absf(GameSession.get_game_time() - (departure_time + total / 5.0 * 3600.0)) < 0.01,
		"arrival happens exactly at distance / speed (%.0f nm in %.2f h)" % [total, total / 5.0])
	t.check_eq(GameSession.plan_route_to(&"bergen"), "", "a new course can be planned from the arrival port")
	var next := GameSession.get_planned_route()
	t.check(next != null and next.origin_port_id == &"gothenburg", "the next voyage starts in Gothenburg")
	t.check_eq(GameSession.depart(), "", "the next voyage can depart")


func _test_sleep() -> void:
	# Sleep while underway (no weather on Kiel -> Gothenburg).
	_new_game_with_route(&"kiel", &"gothenburg", [], true)
	GameSession.depart()
	var before := GameSession.get_game_time()
	var result := Simulation.sleep(8.0)
	t.check_eq(result.stopped_by, Simulation.STOP_NONE, "an 8 h sleep on a clear course is not interrupted")
	t.check(is_equal_approx(GameSession.get_game_time() - before, 8.0 * 3600.0), "sleeping 8 h advances the clock 8 h")
	t.check(absf(GameSession.get_voyage_progress_nm() - 40.0) < 1e-6, "the voyage advances 40 nm during 8 h of sleep")
	var slept_position := GameSession.get_vessel_position()
	_new_game_with_route(&"kiel", &"gothenburg", [], true)
	GameSession.depart()
	for i in 480:
		Simulation.advance(60.0)
	t.check(GameSession.get_vessel_position().distance_to(slept_position) < 1e-5, "sleep progress equals 8 h of normal time")

	# Arrival during sleep stops the sleep at the destination.
	var total := GameSession.get_voyage_total_nm()
	Simulation.advance((total - 10.0) / 5.0 * 3600.0 - 8.0 * 3600.0)  # 10 nm (2 h) from Gothenburg
	var asleep_at := GameSession.get_game_time()
	result = Simulation.sleep(8.0)
	t.check_eq(result.stopped_by, Simulation.STOP_ARRIVAL, "sleep stops on arrival")
	t.check(absf(result.elapsed_seconds - 2.0 * 3600.0) < 1.0, "sleep ended after the 2 h it took to arrive (%.2f h)" % (result.elapsed_seconds / 3600.0))
	t.check(absf(GameSession.get_game_time() - asleep_at - 2.0 * 3600.0) < 1.0, "the clock stops at the arrival time")
	t.check_eq(GameSession.get_location_id(), &"gothenburg", "the vessel is at its destination, not past it")

	# Sleeping in port only passes time.
	before = GameSession.get_game_time()
	result = Simulation.sleep(6.0)
	t.check(is_equal_approx(GameSession.get_game_time() - before, 6.0 * 3600.0) and GameSession.get_location_id() == &"gothenburg",
		"sleeping in port advances time only")


func _hazard_start_nm(path: PackedVector2Array) -> float:
	var hazards := Simulation.route_hazards(path, 0.0, 1000.0)
	return hazards[0].distance_nm if not hazards.is_empty() else -1.0


func _test_weather_warnings() -> void:
	var horizon := Simulation.WARNING_HORIZON_HOURS * 5.0  # calm: motoring at 5 kn
	var route: PlannedRoute = t.make_route(&"copenhagen", &"kiel")
	var hazards := Simulation.route_hazards(route.path, 0.0, 1000.0)
	t.check(hazards.size() == 1 and hazards[0].event_id == STRONG_WINDS and hazards[0].hazard == WeatherModel.HAZARD_CAUTION,
		"Copenhagen -> Kiel runs into the strong-wind area (caution)")
	var entry := _hazard_start_nm(route.path)

	# At 1× in one-minute steps: one warning, about 6 hours of sailing before the area.
	_new_game_with_route(&"copenhagen", &"kiel")
	GameSession.depart()
	warnings.clear()
	var progress_at_warning := -1.0
	for i in 20 * 60:
		Simulation.advance(60.0)
		if not warnings.is_empty() and progress_at_warning < 0.0:
			progress_at_warning = warnings[0].at_progress
			break
	t.check_eq(warnings.size(), 1, "one warning is given before the area")
	var ahead := entry - progress_at_warning
	t.check(ahead <= horizon + Simulation.FORECAST_STEP_NM and ahead >= horizon - 1.0,
		"it comes about 6 h of sailing (30 nm at 5 kn) before the area (%.1f nm)" % ahead)
	t.check(not warnings.is_empty() and "Strong winds" in warnings[0].text and "h" in warnings[0].text and warnings[0].hazard == WeatherModel.HAZARD_CAUTION,
		"warning text names the weather and when: %s" % (warnings[0].text if not warnings.is_empty() else ""))
	Simulation.advance(6.0 * 3600.0)
	for i in 120:
		Simulation.advance(60.0)
	t.check_eq(warnings.size(), 1, "the same weather is not announced again (also not on entering it)")
	t.check(GameSession.is_weather_warned(StringName("%s>1" % STRONG_WINDS)), "the warning is recorded on the voyage")

	# At 20× with large frame steps the warning fires at the same point, and
	# accelerated time drops back to 1×.
	_new_game_with_route(&"copenhagen", &"kiel")
	GameSession.depart()
	warnings.clear()
	GameSession.set_time_scale(20)
	for i in 200:
		Simulation.tick(1.0)  # 1 real second = 20 game minutes
		if not warnings.is_empty():
			break
	var warned_time: float = warnings[0].at_time if not warnings.is_empty() else -1.0
	t.check(not warnings.is_empty() and absf(warnings[0].at_progress - progress_at_warning) < 1e-6,
		"at 20× the warning comes at exactly the same point")
	t.check_eq(GameSession.get_time_scale(), 1, "a warning returns accelerated time to 1×")

	# Sleeping does not sleep through a warning: woken at the same evaluation point.
	_new_game_with_route(&"copenhagen", &"kiel")
	GameSession.depart()
	warnings.clear()
	var departed := GameSession.get_game_time()
	var result := Simulation.sleep(12.0)
	t.check_eq(result.stopped_by, Simulation.STOP_WARNING, "sleep is interrupted by the warning")
	t.check(absf(GameSession.get_voyage_progress_nm() - progress_at_warning) < 1e-6,
		"woken at exactly the point where the 1× voyage was warned (%.3f nm)" % GameSession.get_voyage_progress_nm())
	t.check(absf(GameSession.get_game_time() - warned_time) < 1e-6,
		"at the same game time as the 20× voyage was warned")

	# Weather now acts on the boat: inside the area the wind is the area's.
	# Sail on until the closest approach to the area's centre (the course
	# passes about 3 nm from it).
	var inside := false
	var previous := INF
	for i in 12 * 60:
		var area := WeatherModel.get_default().find_event(STRONG_WINDS, GameSession.get_game_time())
		var d := area.normalized_distance(GameSession.get_vessel_position(), GameSession.get_game_time())
		if d > previous and previous < 0.6:
			inside = true
			break
		previous = d
		Simulation.advance(60.0)
	var here := Simulation.get_weather_at_vessel()
	t.check(inside and here.speed_kn >= 22.0 and here.event_id == STRONG_WINDS, "inside the area the wind is strong (%.0f kn), from the area" % here.speed_kn)
	Simulation.advance(Simulation.EVALUATION_INTERVAL)
	t.check(absf(GameSession.get_propulsion().wind_speed_kn - Simulation.get_weather_at_vessel().speed_kn) < 3.0,
		"propulsion uses that same wind (%.0f kn)" % GameSession.get_propulsion().wind_speed_kn)
	t.check(GameSession.get_weather_exposure().level == WeatherModel.HAZARD_CAUTION and GameSession.get_weather_exposure().event_id == STRONG_WINDS,
		"the exposure record knows the boat is in it")
	t.check(GameSession.is_underway(), "weather does not stop or harm the boat")

	# A course that never meets the area gives no warnings.
	_new_game_with_route(&"kiel", &"gothenburg", [], true)
	GameSession.depart()
	warnings.clear()
	Simulation.advance(1000.0 * 3600.0)
	t.check(warnings.is_empty(), "no warnings on a course that avoids all weather")


func _test_rerouting() -> void:
	_new_game_with_route(&"copenhagen", &"kiel")
	GameSession.enter_boat_area(SessionState.AREA_INTERIOR, &"start")
	GameSession.set_player_position(Vector2(-150, 10))
	GameSession.depart()
	warnings.clear()
	for i in 40:
		Simulation.advance(1800.0)
		if not warnings.is_empty():
			break
	t.check_eq(warnings.size(), 1, "a strong-wind warning arrives during the voyage")
	var position := GameSession.get_vessel_position()
	var time := GameSession.get_game_time()
	var voyage_before := GameSession.get_voyage().to_dict()

	# An invalid change of course leaves the voyage untouched.
	var error := GameSession.change_course(&"kiel", [Vector2(11.9, 55.45)] as Array[Vector2])
	t.check(not error.is_empty(), "a course through a waypoint on land is refused: %s" % error)
	t.check_eq(GameSession.get_voyage().to_dict(), voyage_before, "the active voyage is unchanged after a refused change")

	# Changing course around the area, from where the boat is now.
	error = GameSession.change_course(&"kiel", [AVOID_WAYPOINT] as Array[Vector2])
	t.check_eq(error, "", "the course can be changed at sea via a waypoint")
	var voyage := GameSession.get_voyage()
	t.check(voyage.route.path[0].is_equal_approx(position), "the new course starts at the vessel's current position")
	t.check(voyage.route.origin_port_id.is_empty(), "the new origin is a position at sea, not a port")
	t.check(GameSession.get_vessel_position().is_equal_approx(position), "the vessel did not move (no teleport)")
	t.check_eq(GameSession.get_game_time(), time, "the clock is unchanged by the change of course")
	t.check_eq(voyage.progress_nm, 0.0, "progress restarts on the new course")
	t.check(absf(GameSession.get_voyage_remaining_nm() - GeoMath.path_length_nm(voyage.route.path)) < 1e-6, "remaining distance is recalculated")
	t.check_eq(voyage.revision, 2, "the course revision increased")
	t.check_eq(GameSession.get_boat_area(), SessionState.AREA_INTERIOR, "the boat area is preserved")
	t.check(GameSession.get_player_position().is_equal_approx(Vector2(-150, 10)), "the player position is preserved")
	t.check(Simulation.route_hazards(voyage.route.path, 0.0, 1000.0).is_empty(), "the new course avoids the strong-wind area")
	warnings.clear()
	var result := Simulation.advance(100.0 * 3600.0, true)
	t.check(warnings.is_empty(), "no further warnings after avoiding the area")
	t.check_eq(result.stopped_by, Simulation.STOP_ARRIVAL, "the voyage continues to arrival")
	t.check_eq(GameSession.get_location_id(), &"kiel", "arrived in Kiel after the change of course")

	# Changing the destination at sea.
	_new_game_with_route(&"copenhagen", &"kiel")
	GameSession.depart()
	Simulation.advance(3.0 * 3600.0)
	t.check_eq(GameSession.change_course(&"gothenburg", [] as Array[Vector2]), "", "the destination can be changed at sea")
	t.check_eq(GameSession.get_voyage_destination_id(), &"gothenburg", "the voyage now heads for Gothenburg")
	Simulation.advance(200.0 * 3600.0, true)
	t.check_eq(GameSession.get_location_id(), &"gothenburg", "the boat arrives at the new destination")


func _new_game_with_route(from: StringName, to: StringName, waypoints: Array = [], quiet := false) -> void:
	GameSession.start_new_session()
	if from != GameSession.START_LOCATION:
		# Start somewhere else by placing the vessel in the other port.
		var state := GameSession.get_state_snapshot()
		state.location_id = from
		state.vessel_position = PortCatalog.get_default().get_port(from).get_geo_position()
		GameSession.replace_state(state)
	var typed: Array[Vector2] = []
	typed.assign(waypoints)
	var error := GameSession.plan_route_to(to, typed)
	if not quiet or not error.is_empty():
		t.check_eq(error, "", "course %s -> %s planned" % [from, to])
