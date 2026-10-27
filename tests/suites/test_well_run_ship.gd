extends RefCounted
## Injection 2, The Well-Run Ship: performance guards and the new time passages.
##   - the interface's day/night recolouring is one theme change, not hundreds;
##   - repeated scene changes, sleeps and day/night changes leave the game's
##     structure as it was (nodes, autoload connections, audio players, tweens);
##   - dates, weekdays and twilight ends are right;
##   - sleep: the clock counts the hours, midnight turns the date, stores
##     are used, the captain wakes in the berth and can act at once;
##   - dawn and dusk: one card per twilight, the twilight passed with the
##     normal simulation, never after a jump in time, never twice;
##   - Long Passage: the voyage map follows the real route (canals, the
##     Date Line), stops for events with "Sail on", "Back aboard" returns to
##     the boat (shown and processed again), arrival, save and load.

const APP_SCENE := preload("res://src/app/app.tscn")

var t: Node
var app: Node


func run(runner: Node) -> void:
	t = runner
	Simulation.auto_advance = false
	_test_words()
	_test_twilight_end()
	app = APP_SCENE.instantiate()
	t.add_child(app)
	app.router.fade_duration = 0.05
	await _settle()
	app.start_new_game()
	await _settle()
	await _test_theme_is_one_change()
	await _test_stable_structure()
	TimePassage.enabled = true
	TimePassage.headless_ok = true
	await _test_sleep_passage()
	await _test_dawn_card()
	await _test_voyage_map()
	await _test_voyage_map_across_canal_and_date_line()
	TimePassage.headless_ok = false
	TimePassage.enabled = false
	Simulation.auto_advance = true
	app.queue_free()
	await t.frames(2)
	GameSession.end_session()


func _settle() -> void:
	await t.frames(2)
	await t.wait_until(func() -> bool: return not app.router.is_busy(), 5.0)
	await t.physics_frames(3)


func _moor_at(port_id: StringName) -> void:
	var state := GameSession.get_state_snapshot()
	state.location_id = port_id
	state.vessel_status = SessionState.STATUS_MOORED
	state.vessel_position = PortCatalog.get_default().get_port(port_id).get_geo_position()
	state.voyage = null
	state.planned_route = null
	state.anchor = AnchorState.new()
	GameSession.replace_state(state)


func _show(area: StringName) -> BoatArea:
	app.modals.clear()
	GameSession.enter_boat_area(area, &"start")
	app._show_current_boat_area()
	await _settle()
	return app.router.current_screen as BoatArea


func _set_time(time: float) -> void:
	var state := GameSession.get_state_snapshot()
	state.game_time = time
	GameSession.replace_state(state)


## The first game time after `from` when the sun at `geo` crosses `elevation`.
static func _crossing(geo: Vector2, from: float, elevation: float, rising: bool) -> float:
	var t0 := from
	var before := Daylight.sun_elevation(geo, t0)
	for i in 3 * 24 * 60:
		t0 += 60.0
		var now := Daylight.sun_elevation(geo, t0)
		if (rising and before < elevation and now >= elevation) or (not rising and before > elevation and now <= elevation):
			return t0
		before = now
	return -1.0


func _structure() -> Dictionary:
	var connections := 0
	for child in t.get_tree().root.get_children():
		if child == t:
			continue
		for s in child.get_signal_list():
			connections += child.get_signal_connection_list(s.name).size()
	var audio := 0
	for node in t.get_tree().root.find_children("*", "", true, false):
		if node is AudioStreamPlayer or node is AudioStreamPlayer2D:
			audio += 1
	return {"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), "connections": connections, "audio": audio,
		"tweens": t.get_tree().get_processed_tweens().size(), "orphans": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))}


# --- Words and times ---------------------------------------------------------------------------

func _test_words() -> void:
	var may7 := Time.get_unix_time_from_datetime_string("2026-05-07T09:00:00")
	t.check_eq(TimePassage.date_text(may7), "7 May 2026", "[date] the date in words")
	t.check_eq(TimePassage.weekday_phrase(may7), "a Thursday", "[date] 7 May 2026 is a Thursday")
	t.check_eq(TimePassage.weekday_phrase(may7, true), "a Thursday evening", "[date] and in the evening")
	var new_year := Time.get_unix_time_from_datetime_string("2027-01-01T00:30:00")
	t.check(TimePassage.date_text(new_year) == "1 January 2027" and TimePassage.weekday_phrase(new_year) == "a Friday",
		"[date] a new year: 1 January 2027, a Friday")
	t.check_eq(TimePassage.clock_text(Time.get_unix_time_from_datetime_string("2026-05-07T22:05:00")), "22:05", "[date] the clock")


func _test_twilight_end() -> void:
	var copenhagen := Vector2(12.59, 55.68)
	var dawn := _crossing(copenhagen, 1777593600.0, DayNightWatch.NIGHT_BELOW, true)
	var day := DayNightWatch.twilight_end(copenhagen, dawn, false)
	t.check(day > dawn and day - dawn <= DayNightWatch.MAX_SKIP_SECONDS and Daylight.sun_elevation(copenhagen, day) >= DayNightWatch.DAY_ABOVE,
		"[twilight] a May dawn in Copenhagen ends %d min after it starts" % roundi((day - dawn) / 60.0))
	# Midsummer far north: the twilight lasts too long, no card.
	var tromso := Vector2(18.95, 69.65)
	var june := Time.get_unix_time_from_datetime_string("2026-06-21T00:00:00")
	t.check(DayNightWatch.twilight_end(tromso, june, true) < 0.0, "[twilight] the midnight sun: no card, the light changes slowly")


# --- Performance guards ------------------------------------------------------------------------

func _test_theme_is_one_change() -> void:
	await _show(SessionState.AREA_EXTERIOR)
	var changes := [0]
	var count := func() -> void: changes[0] += 1
	UiTheme.theme.changed.connect(count)
	UiTheme.set_blend(0.0, true)
	var before: int = changes[0]
	UiTheme.set_blend(0.5, true)
	var one_step: int = changes[0] - before
	app.open_chart()
	await _settle()
	before = changes[0]
	var started := Time.get_ticks_usec()
	UiTheme.set_blend(1.0, true)
	var ms := (Time.get_ticks_usec() - started) / 1000.0
	var at_chart: int = changes[0] - before
	UiTheme.theme.changed.disconnect(count)
	t.check(one_step == 1 and at_chart == 1, "[theme] a day/night step is one theme change (%d on deck, %d at the chart; was about 280 each)" % [
		one_step, at_chart])
	t.check(ms < 500.0, "[theme] recolouring with the chart open takes %.1f ms (was over 2 s)" % ms)
	app.close_chart()
	await _settle()
	UiTheme.set_blend(UiTheme._target_blend(), true)


func _test_stable_structure() -> void:
	_moor_at(&"copenhagen")
	await _show(SessionState.AREA_EXTERIOR)
	await _show(SessionState.AREA_INTERIOR)
	app.toasts.clear()
	await t.frames(2)
	var first := _structure()
	for round in 6:
		await _show(SessionState.AREA_EXTERIOR)
		await _show(SessionState.AREA_INTERIOR)
		app.open_chart()
		await _settle()
		app.close_chart()
		await _settle()
		app.sleep_for(6.0)
		await _settle()
		UiTheme.set_blend(float(round % 2), true)
	await _show(SessionState.AREA_INTERIOR)
	app.toasts.clear()  # notices fade on their own; they are not what grows
	await t.frames(2)
	var last := _structure()
	t.check(last.nodes == first.nodes and last.connections == first.connections and last.audio == first.audio and last.orphans == first.orphans
		and last.tweens <= first.tweens + 2,
		"[growth] six rounds of deck, cabin, chart, sleep and day/night leave the game as it was (%s -> %s)" % [first, last])


# --- Sleep ---------------------------------------------------------------------------------------

func _test_sleep_passage() -> void:
	_moor_at(&"copenhagen")
	# 21:00 UTC on a Thursday: eight hours take the captain into Friday.
	_set_time(Time.get_unix_time_from_datetime_string("2026-05-07T21:00:00"))
	await _show(SessionState.AREA_INTERIOR)
	var food := GameSession.get_provisions().food_days
	var dates: Array[String] = []
	var clocks: Array[String] = []
	app.sleep_for(8.0)
	t.check(is_instance_valid(app.time_passage), "[sleep] the screen fades to black (the time passage shows)")
	var passage: TimePassage = app.time_passage
	var date_label := passage.find_child("Date", true, false) as Label
	var clock_label := passage.find_child("Clock", true, false) as Label
	var started := Time.get_ticks_msec()
	while is_instance_valid(passage) and Time.get_ticks_msec() - started < 15000:
		if clocks.is_empty() or clocks[-1] != clock_label.text:
			clocks.append(clock_label.text)
			dates.append("%s %s" % [date_label.text, (passage.find_child("Phrase", true, false) as Label).text])
		await t.frames(1)
	var seconds := (Time.get_ticks_msec() - started) / 1000.0
	t.check(clocks.size() >= 8 and clocks[0] == "21:00" and clocks[-1] == "05:00",
		"[sleep] the clock counts the hours: %s" % [clocks])
	t.check(dates[0] == "7 May 2026 a Thursday" and dates[-1] == "8 May 2026 a Friday",
		"[sleep] midnight turns the date and the weekday (%s ... %s)" % [dates[0], dates[-1]])
	t.check(seconds > 3.0 and seconds < 9.0, "[sleep] at a calm pace: 8 hours in %.1f s, then back" % seconds)
	t.check(GameSession.get_provisions().food_days < food and not t.get_tree().paused and app.time_passage == null
		and (app.router.current_screen as BoatArea).area_id == SessionState.AREA_INTERIOR,
		"[sleep] stores used, the captain awake in the cabin, the game running again")
	t.check(app.toasts.get_messages().size() > 0 and String(app.toasts.get_messages()[-1]).contains("You slept 8 h"),
		"[sleep] and told so (%s)" % [app.toasts.get_messages()])
	# A key skips to the end: control comes back at once.
	app.sleep_for(2.0)
	await t.frames(2)
	var key := InputEventKey.new()
	key.keycode = KEY_SPACE
	key.pressed = true
	var skip_started := Time.get_ticks_msec()
	Input.parse_input_event(key)
	await t.wait_until(func() -> bool: return app.time_passage == null, 5.0)
	t.check(app.time_passage == null and Time.get_ticks_msec() - skip_started < 2500,
		"[sleep] a key skips the clock: back in control after %.1f s" % ((Time.get_ticks_msec() - skip_started) / 1000.0))
	# No second sleep while one is on screen.
	app.sleep_for(2.0)
	var during := GameSession.get_game_time()
	app.sleep_for(2.0)
	await t.wait_until(func() -> bool: return app.time_passage == null, 10.0)
	t.check(GameSession.get_game_time() - during <= 2.0 * 3600.0 + 1.0, "[sleep] never two sleeps at once")


# --- Dawn and dusk -------------------------------------------------------------------------------

func _test_dawn_card() -> void:
	_moor_at(&"copenhagen")
	await _show(SessionState.AREA_EXTERIOR)
	var geo := GameSession.get_vessel_position()
	var dawn := _crossing(geo, GameSession.get_game_time(), DayNightWatch.NIGHT_BELOW, true)
	_set_time(dawn - 120.0)
	app.snap_light()
	await t.frames(3)
	var food := GameSession.get_provisions().food_days
	# Ordinary play: two minutes of game time, frame by frame, across the start of dawn.
	for i in 12:
		Simulation.advance(20.0)
		await t.frames(1)
	t.check(is_instance_valid(app.time_passage), "[dawn] the start of the morning twilight brings the date card")
	var passage: TimePassage = app.time_passage
	var date_label := passage.find_child("Date", true, false) as Label if passage else null
	var phrase := passage.find_child("Phrase", true, false) as Label if passage else null
	await t.frames(2)
	var words := "%s / %s" % [date_label.text if date_label else "", phrase.text if phrase else ""]
	await t.wait_until(func() -> bool: return app.time_passage == null, 10.0)
	var elevation := Daylight.sun_elevation(geo, GameSession.get_game_time())
	t.check(elevation >= DayNightWatch.DAY_ABOVE and UiTheme.blend < 0.01 and GameSession.get_provisions().food_days < food,
		"[dawn] under the black the twilight passed with the normal simulation (sun %.1f°, interface day, stores used): %s" % [
			elevation, words])
	t.check(TimePassage.weekday_phrase(GameSession.get_game_time()) in words, "[dawn] the card names the new day")
	# No second card for the same morning, and none after a jump in time.
	for i in 6:
		Simulation.advance(60.0)
		await t.frames(1)
	t.check(app.time_passage == null, "[dawn] once per twilight")
	var dusk := _crossing(geo, GameSession.get_game_time(), DayNightWatch.DAY_ABOVE, false)
	_set_time(dusk + 600.0)  # a load just after dusk began: a jump, not play
	for i in 3:
		Simulation.advance(20.0)
		await t.frames(1)
	t.check(app.time_passage == null, "[dusk] after a load (a jump in time) no card")
	# A menu open: time stands still, no card.
	app.open_pause_menu()
	await t.frames(3)
	t.check(not app.day_night_watch.can_show(), "[dusk] never over a menu")
	app.modals.clear()
	await t.frames(2)
	# Evening in ordinary play.
	_set_time(dusk - 120.0)
	app.snap_light()
	await t.frames(2)
	for i in 12:
		Simulation.advance(20.0)
		await t.frames(1)
	var evening: TimePassage = app.time_passage
	var evening_words := (evening.find_child("Phrase", true, false) as Label).text if evening else ""
	await t.wait_until(func() -> bool: return app.time_passage == null, 10.0)
	t.check(evening_words.ends_with("evening") and UiTheme.blend > 0.99, "[dusk] the evening card (\"%s\"), then Harbor Dusk" % evening_words)
	await t.screenshot("wrs_dusk_after")


# --- Long Passage ------------------------------------------------------------------------------------

func _test_voyage_map() -> void:
	_moor_at(&"copenhagen")
	_set_time(Time.get_unix_time_from_datetime_string("2026-05-08T10:00:00"))
	GameSession.plan_route_to(&"reykjavik")
	GameSession.depart()
	var deck := await _show(SessionState.AREA_EXTERIOR)
	var error := Simulation.start_passage(Simulation.PASSAGE_RATES[0])
	await t.frames(2)
	var map: VoyageMap = app.voyage_map
	t.check(error == "" and map != null, "[passage] Long Passage opens the voyage map (%s)" % error)
	if map == null:
		Simulation.stop_passage()
		return
	await t.get_tree().create_timer(VoyageMap.FADE_SECONDS * 2.5).timeout
	t.check(not deck.visible and deck.process_mode == Node.PROCESS_MODE_DISABLED and not app._hud_layer.visible,
		"[passage] the boat scene and the HUD below are hidden and not processed")
	# Run the passage clock: the boat moves along the drawn route.
	var progress := GameSession.get_voyage_progress_nm()
	for i in 30:
		Simulation.tick(0.1)
		await t.frames(1)
	await t.frames(2)
	var points := map.get_route_screen_points()
	var boat := map.get_boat_screen_position()
	var nearest := INF
	for i in range(1, points.size()):
		nearest = minf(nearest, Geometry2D.get_closest_point_to_segment(boat, points[i - 1], points[i]).distance_to(boat))
	t.check(GameSession.get_voyage_progress_nm() > progress + 5.0 and nearest < 3.0,
		"[passage] the boat follows the planned route on the map (%.0f nm on, %.1f px from the line)" % [
			GameSession.get_voyage_progress_nm() - progress, nearest])
	t.check((map.find_child("When", true, false) as Label).text.contains("May 2026") and
		(map.find_child("Distance", true, false) as Label).text.contains("nm to go"), "[passage] date, distance to go and arrival shown")
	await t.screenshot("wrs_voyage_map")
	# An event stops it: the reason, Sail on, and no repeat of the same event.
	Simulation._interrupt_passage(Simulation.STOP_WARNING, "Weather ahead: a test gale.")
	await t.frames(3)
	var sail_on := map.find_child("SailOn", true, false) as Button
	t.check(map.is_stopped() and map.get_stop_text().contains("test gale") and sail_on.visible and not Simulation.is_passage_running(),
		"[passage] an interruption pauses the clock and says why, with Sail on (\"%s\")" % map.get_stop_text())
	await t.screenshot("wrs_voyage_map_interrupted")
	var stopped_at := GameSession.get_voyage_progress_nm()
	sail_on.pressed.emit()
	await t.frames(2)
	t.check(Simulation.is_passage_running() and not map.is_stopped() and is_equal_approx(GameSession.get_voyage_progress_nm(), stopped_at),
		"[passage] Sail on resumes from where it stopped")
	# Save while the passage runs, and load: the map closes, the boat is back.
	var data := GameSession.get_state_snapshot().to_dict()
	Simulation.stop_passage()
	var errors: Array[String] = []
	GameSession.replace_state(SessionState.from_dict(data, errors))
	await t.frames(3)
	t.check(errors.is_empty() and app.voyage_map == null and deck.visible and deck.process_mode != Node.PROCESS_MODE_DISABLED
		and app._hud_layer.visible and GameSession.is_underway(), "[passage] a load closes the map: the boat shown and running again")
	# Take the helm.
	Simulation.start_passage(Simulation.PASSAGE_RATES[1])
	await t.frames(2)
	map = app.voyage_map
	(map.find_child("TakeHelm", true, false) as Button).pressed.emit()
	await t.wait_until(func() -> bool: return app.voyage_map == null, 5.0)
	t.check(app.voyage_map == null and not Simulation.is_passage_running() and deck.visible and app._hud_layer.visible,
		"[passage] Take the helm: normal time, aboard (map %s, running %s, deck %s, hud %s)" % [app.voyage_map, Simulation.is_passage_running(),
			deck.visible, app._hud_layer.visible])


func _test_voyage_map_across_canal_and_date_line() -> void:
	# Through the Kiel Canal to arrival.
	_moor_at(&"kiel")
	GameSession.plan_route_to(&"cuxhaven")
	GameSession.depart()
	await _show(SessionState.AREA_EXTERIOR)
	Simulation.start_passage(Simulation.PASSAGE_RATES[0])
	await t.frames(2)
	var map: VoyageMap = app.voyage_map
	var in_canal := false
	for i in 400:
		if not Simulation.is_passage_running():
			break
		Simulation.tick(0.05)
		in_canal = in_canal or not SeaRouter.get_default().canal_at(GameSession.get_vessel_position()).is_empty()
		await t.frames(1)
	await t.frames(2)
	t.check(in_canal and GameSession.get_location_id() == &"cuxhaven" and map != null and map.is_stopped() and map.get_stop_text().contains("Cuxhaven"),
		"[passage] through the Kiel Canal to Cuxhaven: the map says Land ho (\"%s\")" % (map.get_stop_text() if map else ""))
	if map:
		(map.find_child("BackAboard", true, false) as Button).pressed.emit()
		await t.wait_until(func() -> bool: return app.voyage_map == null, 5.0)
	await _settle()
	t.check(app.voyage_map == null and app.router.current_screen is BoatArea and (app.router.current_screen as BoatArea).visible,
		"[passage] back aboard after arriving")
	# Across the Date Line: Nouméa to Papeete.
	_moor_at(&"noumea")
	var error := GameSession.plan_route_to(&"papeete")
	GameSession.depart()
	await _show(SessionState.AREA_EXTERIOR)
	Simulation.start_passage(Simulation.PASSAGE_RATES[2])
	await t.frames(2)
	map = app.voyage_map
	if not t.check(error == "" and map != null, "(setup) Nouméa -> Papeete on the voyage map (%s)" % error):
		Simulation.stop_passage()
		return
	var unit := VoyageMap.unwrap(GameSession.get_voyage().route.path)
	var jumps := 0
	for i in range(1, unit.size()):
		if absf(unit[i].x - unit[i - 1].x) > 0.25:
			jumps += 1
	var crossed := false
	var last_lon := GameSession.get_vessel_position().x
	for i in 200:
		if not Simulation.is_passage_running():
			Simulation.start_passage(Simulation.PASSAGE_RATES[2])
		Simulation.tick(0.1)
		var lon := GameSession.get_vessel_position().x
		crossed = crossed or (last_lon > 150.0 and lon < -150.0)
		last_lon = lon
		if crossed:
			break
		await t.frames(1)
	await t.frames(3)
	var points := map.get_route_screen_points()
	var boat := map.get_boat_screen_position()
	var nearest := INF
	for i in range(1, points.size()):
		nearest = minf(nearest, Geometry2D.get_closest_point_to_segment(boat, points[i - 1], points[i]).distance_to(boat))
	t.check(jumps == 0 and crossed and nearest < 3.0,
		"[passage] across the Date Line the route is one line and the boat stays on it (%.1f px)" % nearest)
	await t.screenshot("wrs_voyage_map_date_line")
	map.take_the_helm()
	await t.wait_until(func() -> bool: return app.voyage_map == null, 5.0)
