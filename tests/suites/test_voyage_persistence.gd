extends RefCounted
## Saving and loading voyages, save migration from Iteration 001, and safety
## of the active session when a load fails.

var t: Node


func run(runner: Node) -> void:
	t = runner
	Simulation.auto_advance = false
	_test_underway_round_trip()
	_test_migration_from_iteration_001()
	_test_invalid_voyage_saves()
	SaveManager.delete_slot(1)
	SaveManager.delete_slot(2)
	SaveManager.delete_slot(3)
	Simulation.auto_advance = true
	GameSession.end_session()


func _test_underway_round_trip() -> void:
	GameSession.start_new_session()
	GameSession.plan_route_to(&"kiel")
	GameSession.depart()
	GameSession.enter_boat_area(SessionState.AREA_EXTERIOR, &"from_cabin")
	GameSession.set_player_position(Vector2(-260.5, 12.25))
	var warnings: Array = []
	var on_warning := func(w: Dictionary) -> void: warnings.append(w)
	Simulation.weather_warning.connect(on_warning)
	Simulation.advance(8.0 * 3600.0)  # past the strong-wind warning point
	GameSession.set_time_scale(20)
	t.check_eq(warnings.size(), 1, "the voyage received its weather warning before saving")
	var saved := GameSession.get_state_snapshot()
	t.check_eq(SaveManager.save_to_slot(1, saved), OK, "a game can be saved while underway")
	var info := SaveManager.get_slot_info(1)
	t.check(info.location_name == "At sea" and info.destination_name == "Kiel", "slot metadata shows the voyage (%s, to %s)" % [info.location_name, info.destination_name])

	# Change things, then load the save back.
	Simulation.advance(5.0 * 3600.0)
	GameSession.set_time_scale(1)
	var loaded := SaveManager.load_from_slot(1)
	t.check(loaded.is_ok(), "the underway save loads")
	if not loaded.is_ok():
		return
	GameSession.replace_state(loaded.state)
	t.check(GameSession.is_underway(), "voyage status is restored")
	t.check_eq(GameSession.get_game_time(), saved.game_time, "game clock is restored exactly")
	t.check_eq(GameSession.get_time_scale(), 20, "time acceleration is restored")
	t.check(GameSession.get_vessel_position().distance_to(saved.vessel_position) < 1e-6, "vessel position is restored")
	t.check(absf(GameSession.get_voyage_progress_nm() - saved.voyage.progress_nm) < 1e-9, "route progress is restored")
	t.check_eq(GameSession.get_voyage().route.path, saved.voyage.route.path, "the active route geometry is restored")
	t.check_eq(GameSession.get_voyage_destination_id(), &"kiel", "destination is restored")
	t.check_eq(GameSession.get_boat_area(), SessionState.AREA_EXTERIOR, "boat area is restored")
	t.check(GameSession.get_player_position().is_equal_approx(Vector2(-260.5, 12.25)), "player position is restored")
	t.check(GameSession.is_weather_warned(&"strong_winds_western_baltic"), "the handled warning is restored")
	warnings.clear()
	GameSession.set_time_scale(1)
	Simulation.advance(10.0 * 3600.0)
	t.check(warnings.is_empty(), "a warning already handled is not repeated after loading")
	Simulation.advance(100.0 * 3600.0)
	t.check_eq(GameSession.get_location_id(), &"kiel", "the loaded voyage continues to Kiel")
	Simulation.weather_warning.disconnect(on_warning)


func _test_migration_from_iteration_001() -> void:
	SettingsManager.save()
	var settings_before := FileAccess.get_file_as_string(SettingsManager.settings_path)
	# A save written by Iteration 001 (format version 1).
	var v1 := {
		"format": "next_harbor_save", "version": 1, "game_version": "0.1.0",
		"saved_at_unix": 1790000000.0, "saved_at_utc": "2026-09-21T12:53:20Z",
		"session": {
			"boat": {"area": "interior"},
			"player": {"position": {"x": -120.0, "y": 4.0}},
			"navigation": {
				"location_id": "copenhagen",
				"planned_route": {"origin": "copenhagen", "destination": "kiel", "waypoints": []},
			},
		},
	}
	_write(SaveManager.save_dir.path_join("slot_2.json"), JSON.stringify(v1))
	var info := SaveManager.get_slot_info(2)
	t.check_eq(info.status, SaveManager.Status.VALID, "an Iteration 001 save is still valid")
	var loaded := SaveManager.load_from_slot(2)
	t.check(loaded.is_ok(), "an Iteration 001 save loads: %s" % loaded.error)
	if not loaded.is_ok():
		return
	var state := loaded.state
	t.check_eq(state.game_time, SessionState.get_start_time(), "migrated save gets the default start time")
	t.check_eq(state.time_scale, 1, "migrated save runs at 1×")
	t.check_eq(state.vessel_status, SessionState.STATUS_MOORED, "migrated vessel is moored")
	t.check(state.vessel_position.is_equal_approx(PortCatalog.get_default().get_port(&"copenhagen").get_geo_position()), "migrated vessel lies at Copenhagen")
	t.check(state.player_position.is_equal_approx(Vector2(-120, 4)), "migrated player position is kept")
	GameSession.replace_state(state)
	var route := GameSession.get_planned_route()
	t.check(route != null and route.has_path() and SeaRouter.get_default().validate_route(route).is_empty(),
		"the old straight-line course is recalculated as a sea route")
	t.check_eq(FileAccess.get_file_as_string(SettingsManager.settings_path), settings_before, "settings are untouched by loading and migration")


func _test_invalid_voyage_saves() -> void:
	GameSession.start_new_session()
	GameSession.plan_route_to(&"kiel")
	GameSession.depart()
	Simulation.advance(3.0 * 3600.0)
	SaveManager.save_to_slot(3, GameSession.get_state_snapshot())
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SaveManager.save_dir.path_join("slot_3.json")))
	var cases := {
		"progress beyond the route": func(d: Dictionary) -> void: d.session.navigation.voyage.progress_nm = 99999.0,
		"position not on the route": func(d: Dictionary) -> void: d.session.vessel.position = {"lon": 5.0, "lat": 60.0},
		"underway with a port location": func(d: Dictionary) -> void: d.session.navigation.location_id = "kiel",
		"voyage path not ending at the destination": func(d: Dictionary) -> void: d.session.navigation.voyage.route.destination = "bergen",
		"time acceleration not offered": func(d: Dictionary) -> void: d.session.clock.time_scale = 3,
	}
	var before := GameSession.get_state_snapshot().to_dict()
	for name: String in cases:
		var data: Dictionary = raw.duplicate(true)
		cases[name].call(data)
		_write(SaveManager.save_dir.path_join("slot_3.json"), JSON.stringify(data))
		t.check_eq(SaveManager.get_slot_info(3).status, SaveManager.Status.CORRUPTED, "rejected save: %s" % name)
		t.check(not SaveManager.load_from_slot(3).is_ok(), "loading it fails: %s" % name)
	t.check_eq(GameSession.get_state_snapshot().to_dict(), before, "failed loads leave the active voyage untouched")


func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()
