extends Node
## Verifies that settings and saves survive an application restart. Run twice,
## as two separate processes:
##   godot --headless --path . res://tests/restart_check.tscn -- --phase=write
##   godot --headless --path . res://tests/restart_check.tscn -- --phase=read
## The read phase exits with code 0 only if everything written was restored.

const SETTINGS_PATH := "user://test_restart_settings.cfg"
const SAVE_DIR := "user://test_restart_saves"
## What the write phase sailed (speed depends on the wind), checked on read.
const EXPECT_PATH := "user://test_restart_expect.json"


func _ready() -> void:
	var phase := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--phase="):
			phase = arg.trim_prefix("--phase=")
	SettingsManager.settings_path = SETTINGS_PATH
	SaveManager.save_dir = SAVE_DIR
	if phase == "write":
		_write()
		get_tree().quit(0)
	elif phase == "read":
		get_tree().quit(0 if _read() else 1)
	else:
		push_error("Use --phase=write or --phase=read")
		get_tree().quit(2)


func _write() -> void:
	SettingsManager.restore_defaults()
	SettingsManager.set_volume(&"Ambience", 33)
	SettingsManager.set_volume(&"Master", 0)
	SettingsManager.set_vsync(false)
	SettingsManager.set_ui_scale(0.9)
	SettingsManager.save()
	Simulation.auto_advance = false
	GameSession.start_new_session(CompanionState.KIND_DOG)
	GameSession.switch_vessel(&"petrel_36")  # sail the trimaran
	GameSession.enter_boat_area(SessionState.AREA_EXTERIOR, &"from_cabin")
	GameSession.set_player_position(Vector2(-300.5, 42.25))
	GameSession.plan_route_to(&"kiel")
	GameSession.depart()
	Simulation.advance(3.0 * 3600.0)  # three hours out of Copenhagen, in the game's wind
	GameSession.set_time_scale(5)
	SaveManager.save_to_slot(2, GameSession.get_state_snapshot())
	var file := FileAccess.open(EXPECT_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({"progress_nm": GameSession.get_voyage_progress_nm(),
		"propulsion": GameSession.get_propulsion().to_dict(), "companion": GameSession.get_companion().to_dict(),
		"weather": _weather_snapshot(GameSession.get_vessel_position(), GameSession.get_game_time(), GameSession.get_wind_seed()),
		"exposure": GameSession.get_weather_exposure().to_dict()}, "", true, true))
	file.close()
	print("write phase done")


func _read() -> bool:
	SettingsManager.load_settings()
	var ok := true
	ok = _expect(SettingsManager.get_volume(&"Ambience") == 33, "ambience volume restored") and ok
	ok = _expect(SettingsManager.get_volume(&"Master") == 0, "muted master restored") and ok
	ok = _expect(AudioServer.is_bus_mute(AudioServer.get_bus_index(&"Master")), "master bus is muted after restart") and ok
	ok = _expect(not SettingsManager.get_vsync(), "VSync off restored") and ok
	ok = _expect(is_equal_approx(SettingsManager.get_ui_scale(), 0.9), "UI scale restored") and ok
	var result := SaveManager.load_from_slot(2)
	ok = _expect(result.is_ok(), "slot 2 loads after restart") and ok
	if result.is_ok():
		var state := result.state
		ok = _expect(state.boat_area == SessionState.AREA_EXTERIOR, "area restored") and ok
		ok = _expect(state.player_position.is_equal_approx(Vector2(-300.5, 42.25)), "player position restored") and ok
		ok = _expect(state.vessel_status == SessionState.STATUS_UNDERWAY and state.voyage != null, "voyage underway restored") and ok
		var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(EXPECT_PATH))
		ok = _expect(state.voyage != null and absf(state.voyage.progress_nm - expected.progress_nm) < 1e-6,
			"voyage progress (%.2f nm) restored" % expected.progress_nm) and ok
		ok = _expect(state.propulsion.to_dict() == expected.propulsion, "propulsion mode and controller state restored (%s)" % state.propulsion.mode) and ok
		ok = _expect(JSON.parse_string(JSON.stringify(state.companion.to_dict())) == expected.companion, "ship's companion restored (%s, %s)" % [state.companion.kind, state.companion.spot]) and ok
		ok = _expect(state.voyage != null and state.voyage.route.destination_port_id == &"kiel", "destination restored") and ok
		ok = _expect(is_equal_approx(state.game_time, SessionState.get_start_time() + 3.0 * 3600.0), "game clock restored") and ok
		ok = _expect(state.time_scale == 5, "time acceleration restored") and ok
		ok = _expect(state.vessel_id == &"petrel_36", "active vessel restored (%s)" % state.vessel_id) and ok
		# The weather is recomputed from the seed in this new process: the same
		# storms in the same places, and the same weather at the boat.
		var weather := _weather_snapshot(state.vessel_position, state.game_time, state.wind_seed)
		ok = _expect(JSON.parse_string(JSON.stringify(weather, "", true, true)) == expected.weather,
			"the same weather after restart (%d events active, %.1f kn at the boat)" % [weather.events.size(), weather.here.speed_kn]) and ok
		ok = _expect(JSON.parse_string(JSON.stringify(state.weather_exposure.to_dict(), "", true, true)) == expected.exposure,
			"weather exposure record restored") and ok
	# Clean up the scratch files.
	DirAccess.remove_absolute(SETTINGS_PATH)
	DirAccess.remove_absolute(EXPECT_PATH)
	SaveManager.delete_slot(2)
	DirAccess.remove_absolute(SAVE_DIR)
	SettingsManager.settings_path = SettingsManager.DEFAULT_PATH
	SettingsManager.load_settings()
	print("read phase: ", "PASS" if ok else "FAIL")
	return ok


## The weather at `geo` and every active event's place and strength.
func _weather_snapshot(geo: Vector2, time: float, seed: int) -> Dictionary:
	var model := WeatherModel.get_default()
	var events := []
	for event in model.active_events(time, seed):
		var center := event.center_at(time)
		events.append([String(event.id), center.x, center.y, event.radius_at(time), event.life_factor(time)])
	return {"here": model.sample(geo, time, seed).to_dict(), "events": events}


func _expect(condition: bool, description: String) -> bool:
	print(("  ok   " if condition else "  FAIL ") + description)
	return condition
