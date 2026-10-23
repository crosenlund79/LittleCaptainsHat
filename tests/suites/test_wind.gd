extends RefCounted
## The wind field (determinism, range, continuity, plausibility, conventions,
## performance) and the vessel's sailing performance.

var t: Node
var field: WindField


func run(runner: Node) -> void:
	t = runner
	field = WindField.get_default()
	field.test_override = Callable()  # the real wind
	_test_conventions()
	_test_determinism_and_range()
	_test_continuity()
	_test_plausibility()
	_test_query_performance()
	_test_sailing_performance()


func _test_conventions() -> void:
	t.check_eq(WindField.from_to_to(270.0), 90.0, "a westerly (from 270°) blows towards 90°")
	var westerly := WindField.Sample.make(270.0, 10.0)
	t.check(westerly.to_vector().is_equal_approx(Vector2(10, 0)), "a westerly moves air east (to_vector)")
	t.check(WindField.Sample.make(0.0, 8.0).to_vector().is_equal_approx(Vector2(0, -8)), "a northerly moves air south")
	t.check_eq(WindField.relative_angle(0.0, 90.0), 90.0, "heading north, wind from east: +90 (starboard)")
	t.check_eq(WindField.relative_angle(0.0, 270.0), -90.0, "heading north, wind from west: -90 (port)")
	t.check_eq(WindField.relative_angle(0.0, 0.0), 0.0, "wind from dead ahead: 0")
	t.check_eq(WindField.relative_angle(0.0, 180.0), 180.0, "wind from dead astern: 180")
	t.check_eq(WindField.relative_angle(350.0, 20.0), 30.0, "relative angle wraps across north")
	t.check_eq(WindField.compass_name(247.5), "WSW", "compass names (247.5° = WSW)")
	t.check_eq(WindField.compass_name(359.0), "N", "compass names wrap to N")
	t.check_eq(PropulsionState.wind_side(45.0), "starboard", "positive angle = wind on the starboard side")
	t.check_eq(PropulsionState.wind_side(-45.0), "port", "negative angle = wind on the port side")
	t.check_eq(PropulsionState.point_of_sail_name(135.0), "broad reach", "135° is a broad reach")


func _test_determinism_and_range() -> void:
	var time := SessionState.get_start_time() + 12345.0
	var a := field.sample(Vector2(5.0, 55.0), time, 1)
	var b := field.sample(Vector2(5.0, 55.0), time, 1)
	t.check(a.from_deg == b.from_deg and a.speed_kn == b.speed_kn, "the same place, time and seed give the same wind")
	var fresh := WindField.load_from(WindField.DEFAULT_PATH)
	var c := fresh.sample(Vector2(5.0, 55.0), time, 1)
	t.check(is_equal_approx(c.from_deg, a.from_deg) and is_equal_approx(c.speed_kn, a.speed_kn),
		"a freshly loaded field gives the same wind (no hidden state)")
	var differs := false
	for i in 20:
		var geo := Vector2(-20.0 + i * 2.5, 40.0 + i)
		if absf(field.sample(geo, time, 1).speed_kn - field.sample(geo, time, 2).speed_kn) > 0.5:
			differs = true
	t.check(differs, "a different seed gives different weather")

	var min_speed := INF
	var max_speed := 0.0
	var valid := true
	for day in 10:
		for lon in range(-25, 38, 3):
			for lat in range(33, 73, 3):
				var s := field.sample(Vector2(lon, lat), SessionState.get_start_time() + day * 86400.0 * 3.1, 1)
				valid = valid and is_finite(s.speed_kn) and s.from_deg >= 0.0 and s.from_deg < 360.0
				min_speed = minf(min_speed, s.speed_kn)
				max_speed = maxf(max_speed, s.speed_kn)
	t.check(valid, "directions are within 0-360° and speeds finite across the whole region")
	t.check(min_speed >= 0.0 and max_speed <= 45.0, "wind speeds stay within 0-45 kn (%.1f-%.1f)" % [min_speed, max_speed])
	t.check(max_speed > 20.0, "there are windy places (max %.1f kn)" % max_speed)
	var corners := [Vector2(-25, 33), Vector2(37, 33), Vector2(-25, 72), Vector2(37, 72), Vector2(-40, 20)]
	var ok := true
	for geo: Vector2 in corners:
		ok = ok and is_finite(field.sample(geo, SessionState.get_start_time()).speed_kn)
	t.check(ok, "the region's corners (and points outside it) give a wind")


func _test_continuity() -> void:
	var time := SessionState.get_start_time() + 3.0 * 86400.0
	var worst_speed := 0.0
	var worst_dir := 0.0
	for lon in range(-24, 36, 4):
		for lat in range(34, 71, 4):
			var geo := Vector2(lon + 0.3, lat + 0.3)
			var a := field.sample(geo, time)
			var b := field.sample(geo + Vector2(0.1, 0.1), time)
			worst_speed = maxf(worst_speed, absf(a.speed_kn - b.speed_kn))
			worst_dir = maxf(worst_dir, absf(WindField.relative_angle(a.from_deg, b.from_deg)))
	t.check(worst_speed < 2.0 and worst_dir < 15.0,
		"the wind changes smoothly in space (0.1° apart: max %.2f kn, %.1f°)" % [worst_speed, worst_dir])
	var worst_time_speed := 0.0
	var worst_time_dir := 0.0
	for i in 50:
		var geo := Vector2(-20.0 + i * 1.1, 36.0 + (i % 30))
		var a := field.sample(geo, time + i * 7000.0)
		var b := field.sample(geo, time + i * 7000.0 + 300.0)
		worst_time_speed = maxf(worst_time_speed, absf(a.speed_kn - b.speed_kn))
		worst_time_dir = maxf(worst_time_dir, absf(WindField.relative_angle(a.from_deg, b.from_deg)))
	t.check(worst_time_speed < 1.0 and worst_time_dir < 5.0,
		"the wind changes gradually in time (5 min apart: max %.2f kn, %.1f°)" % [worst_time_speed, worst_time_dir])


## Mean direction (vector mean of FROM) and speed over 30 days at a place.
func _climate(geo: Vector2) -> Dictionary:
	var sum := Vector2.ZERO
	var speed := 0.0
	var calm := 0
	var n := 0
	for hour in range(0, 30 * 24, 3):
		var s := field.sample(geo, SessionState.get_start_time() + hour * 3600.0)
		var rad := deg_to_rad(s.from_deg)
		sum += Vector2(sin(rad), cos(rad))
		speed += s.speed_kn
		calm += 1 if s.speed_kn < 3.0 else 0
		n += 1
	return {"from": fposmod(rad_to_deg(atan2(sum.x, sum.y)), 360.0), "speed": speed / n, "calm": float(calm) / n}


func _in_sector(degrees: float, low: float, high: float) -> bool:
	return fposmod(degrees - low, 360.0) <= fposmod(high - low, 360.0)


func _test_plausibility() -> void:
	var atlantic := _climate(Vector2(-20.0, 55.0))
	t.check(_in_sector(atlantic.from, 210.0, 300.0) and atlantic.speed > 12.0,
		"North Atlantic: westerlies (mean from %d°, %.1f kn)" % [atlantic.from, atlantic.speed])
	var portugal := _climate(Vector2(-10.5, 40.0))
	t.check(_in_sector(portugal.from, 315.0, 30.0), "off Portugal: northerly trades (mean from %d°, %.1f kn)" % [portugal.from, portugal.speed])
	var aegean := _climate(Vector2(25.0, 37.5))
	t.check(_in_sector(aegean.from, 320.0, 40.0), "Aegean: northerly Meltemi (mean from %d°, %.1f kn)" % [aegean.from, aegean.speed])
	var lion := _climate(Vector2(4.5, 42.5))
	t.check(_in_sector(lion.from, 290.0, 20.0), "Gulf of Lion: north-westerly Mistral (mean from %d°, %.1f kn)" % [lion.from, lion.speed])
	var baltic := _climate(Vector2(19.0, 57.0))
	t.check(baltic.calm > 0.02 and baltic.calm < 0.4, "Baltic: changeable, light-air spells %.0f%% of the time" % (baltic.calm * 100.0))
	t.check(baltic.speed < atlantic.speed, "the Baltic is lighter on average than the open Atlantic")


func _test_query_performance() -> void:
	field.sample(Vector2.ZERO, 0.0)  # build the lattice first
	var start := Time.get_ticks_usec()
	for i in 2000:
		field.sample(Vector2(-25.0 + (i % 62), 33.0 + (i % 39)), SessionState.get_start_time() + i * 60.0)
	var per_sample := (Time.get_ticks_usec() - start) / 2000.0
	print("    wind query: %.1f µs per sample" % per_sample)
	t.check(per_sample < 100.0, "a wind query is fast enough for the chart overlay (%.1f µs)" % per_sample)


func _test_sailing_performance() -> void:
	var profile := VesselProfile.get_default()
	t.check_eq(profile.sail_speed_kn(15.0, 0.0), 0.0, "head to wind: no sailing speed")
	t.check_eq(profile.sail_speed_kn(15.0, 30.0), 0.0, "inside 35° of the wind: no sailing speed")
	t.check_eq(profile.sail_speed_kn(0.5, 120.0), 0.0, "no wind: no sailing speed")
	var best := 0.0
	for tws in [5.0, 10.0, 15.0, 20.0, 30.0, 45.0]:
		for twa in range(0, 181, 5):
			best = maxf(best, profile.sail_speed_kn(tws, twa))
	t.check(best <= 10.0 + 1e-6 and best > 9.5, "top sailing speed is about 10 kn and never above (%.2f)" % best)
	var reach := profile.sail_speed_kn(12.0, 100.0)
	t.check(reach > 6.0 and reach < 8.5, "12 kn on the beam: a good cruising speed (%.1f kn)" % reach)
	var marginal := profile.sail_speed_kn(6.0, 90.0)
	t.check(marginal > 2.5 and marginal < 5.0, "6 kn of wind: marginal sailing (%.1f kn)" % marginal)
	t.check(profile.sail_speed_kn(12.0, -100.0) == reach, "port and starboard tack sail the same")
	var increasing := true
	for tws in range(1, 40):
		increasing = increasing and profile.sail_speed_kn(tws + 1, 90.0) >= profile.sail_speed_kn(tws, 90.0)
	t.check(increasing, "more wind never makes the boat slower")
	t.check(profile.wants_spinnaker(115.0) and profile.wants_spinnaker(180.0) and profile.wants_spinnaker(-150.0),
		"spinnaker angles: 115-180° on either side")
	t.check(not profile.wants_spinnaker(110.0) and not profile.wants_spinnaker(-60.0), "no spinnaker above 115° off downwind")
	var no_kite := profile.duplicate() as VesselProfile
	no_kite.has_spinnaker = false
	var bonus := profile.sail_speed_kn(10.0, 140.0) / no_kite.sail_speed_kn(10.0, 140.0)
	t.check(bonus > 1.0 and bonus <= 1.15, "the spinnaker gives a small, bounded speed bonus (x%.2f)" % bonus)
	t.check_eq(profile.sail_speed_kn(10.0, 110.0), no_kite.sail_speed_kn(10.0, 110.0), "no bonus below the spinnaker angle")
