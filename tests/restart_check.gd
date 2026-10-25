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
const LOG_DIR := "user://test_restart_diagnostics"


func _ready() -> void:
	var phase := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--phase="):
			phase = arg.trim_prefix("--phase=")
	SettingsManager.settings_path = SETTINGS_PATH
	SaveManager.save_dir = SAVE_DIR
	SessionLog.log_dir = LOG_DIR
	SessionLog.restart()
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
	SettingsManager.set_art_style(SettingsManager.ART_CLASSIC)
	SettingsManager.save()
	Simulation.auto_advance = false
	GameSession.start_new_session(CompanionState.KIND_DOG)
	# A first passage to Gothenburg (Captain's Log, renown), then a travel update.
	GameSession.plan_route_to(&"gothenburg")
	GameSession.depart()
	while GameSession.is_underway():
		Simulation.advance(24.0 * 3600.0, true)
	# The captain's hat: worn on deck, lost (through the game's own hat check,
	# which also finds the secret Captain No-Hat), replaced in Gothenburg and
	# put back on.
	GameSession.enter_boat_area(SessionState.AREA_EXTERIOR, &"start")
	GameSession.use_hat_hook()
	var here := WeatherModel.get_default().sample(GameSession.get_vessel_position(), GameSession.get_game_time(), GameSession.get_wind_seed())
	GameSession.apply_hat_check(GameSession.get_game_time(), 100.0, here, GameSession.get_vessel_position())
	GameSession.apply_hat_check(GameSession.get_game_time(), 100.0, here, GameSession.get_vessel_position())
	GameSession.buy_hat()
	GameSession.toggle_hat()
	GameSession.publish_travel_update()
	GameSession.switch_vessel(&"petrel_36")  # sail the trimaran
	GameSession.enter_boat_area(SessionState.AREA_EXTERIOR, &"from_cabin")
	GameSession.set_player_position(Vector2(-300.5, 42.25))
	GameSession.plan_route_to(&"kiel")
	GameSession.depart()
	Simulation.advance(3.0 * 3600.0)  # three hours out of Gothenburg, in the game's wind
	GameSession.set_condition_for_testing(64.0)  # a worn trimaran
	GameSession.set_time_scale(5)
	SaveManager.save_to_slot(2, GameSession.get_state_snapshot())
	var file := FileAccess.open(EXPECT_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({"progress_nm": GameSession.get_voyage_progress_nm(),
		"propulsion": GameSession.get_propulsion().to_dict(), "companion": GameSession.get_companion().to_dict(),
		"weather": _weather_snapshot(GameSession.get_vessel_position(), GameSession.get_game_time(), GameSession.get_wind_seed()),
		"exposure": GameSession.get_weather_exposure().to_dict(),
		"game_time": GameSession.get_game_time(),
		"log": GameSession.get_captains_log().to_dict(), "progress": GameSession.get_objective_progress().to_dict(),
		"sailed_nm": GameSession.get_voyage_sailed_nm(),
		"hat": GameSession.get_hat().to_dict(), "log_file": SessionLog.get_log_path(),
		"upkeep": {"funds": GameSession.get_funds(), "food": GameSession.get_food_days(), "water": GameSession.get_water_days(),
			"condition": GameSession.get_condition(),
			"starling": GameSession.get_vessel_condition(&"starling_33"), "damage_until": GameSession.get_damage_applied_until()}}, "", true, true))
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
	ok = _expect(SettingsManager.get_art_style() == SettingsManager.ART_CLASSIC, "Artwork setting (Classic) restored") and ok
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
		ok = _expect(is_equal_approx(state.game_time, float(expected.game_time)), "game clock restored") and ok
		ok = _expect(JSON.parse_string(JSON.stringify(state.captains_log.to_dict(), "", true, true)) == expected.log
			and state.captains_log.has_visited(&"gothenburg") and state.captains_log.voyages_completed == 1,
			"Captain's Log restored (1 voyage, %d harbours)" % state.captains_log.get_distinct_harbours()) and ok
		ok = _expect(JSON.parse_string(JSON.stringify(state.progress.to_dict(), "", true, true)) == expected.progress
			and state.progress.lifetime_renown > 0 and state.progress.publications == 1 and state.progress.unpublished_renown == 0,
			"renown and objectives restored (lifetime %d, 1 travel update published)" % state.progress.lifetime_renown) and ok
		ok = _expect(state.voyage != null and absf(state.voyage.sailed_nm - float(expected.sailed_nm)) < 1e-9
			and state.voyage.departure_port_id == &"gothenburg", "the voyage's log data restored (%.1f nm from Gothenburg)" % float(expected.sailed_nm)) and ok
		ok = _expect(state.time_scale == 5, "time acceleration restored") and ok
		ok = _expect(state.vessel_id == &"petrel_36", "active vessel restored (%s)" % state.vessel_id) and ok
		# The weather is recomputed from the seed in this new process: the same
		# storms in the same places, and the same weather at the boat.
		var weather := _weather_snapshot(state.vessel_position, state.game_time, state.wind_seed)
		ok = _expect(JSON.parse_string(JSON.stringify(weather, "", true, true)) == expected.weather,
			"the same weather after restart (%d events active, %.1f kn at the boat)" % [weather.events.size(), weather.here.speed_kn]) and ok
		ok = _expect(JSON.parse_string(JSON.stringify(state.weather_exposure.to_dict(), "", true, true)) == expected.exposure,
			"weather exposure record restored") and ok
		var hat: Dictionary = JSON.parse_string(JSON.stringify(state.hat.to_dict(), "", true, true))
		ok = _expect(hat == expected.hat and state.hat.status == HatState.WORN and state.hat.serial == 2 and state.hat.lost_count == 1
			and state.hat.spent == 15, "the captain's hat restored (hat number 2, worn; one lost, EUR 15 spent)") and ok
		ok = _expect(state.progress.is_completed(&"secret_captain_no_hat") and state.progress.get_count(&"secret_captain_no_hat") == 1,
			"the secret achievement Captain No-Hat restored, paid once") and ok
		var log_text := FileAccess.get_file_as_string(String(expected.log_file))
		ok = _expect(log_text.contains("\"event\":\"session_start\"") and log_text.contains("\"event\":\"hat_lost\"")
			and log_text.contains("\"event\":\"save\""), "the first process's diagnostic log was flushed (start, hat loss, save)") and ok
		var upkeep: Dictionary = expected.upkeep
		ok = _expect(state.funds == int(upkeep.funds) and absf(state.provisions.food_days - upkeep.food) < 1e-9
			and absf(state.provisions.water_days - upkeep.water) < 1e-9, "money, food and water restored (%s, %.3f days)" % [
				GameSession.format_money(state.funds), state.provisions.food_days]) and ok
		ok = _expect(absf(state.get_condition(&"petrel_36") - upkeep.condition) < 1e-9 and absf(state.get_condition(&"starling_33") - upkeep.starling) < 1e-9
			and absf(state.damage_applied_until - upkeep.damage_until) < 1e-6, "each boat's condition restored (Petrel %d %%)" % roundi(upkeep.condition)) and ok
	# Clean up the scratch files.
	DirAccess.remove_absolute(SETTINGS_PATH)
	DirAccess.remove_absolute(EXPECT_PATH)
	SaveManager.delete_slot(2)
	DirAccess.remove_absolute(SAVE_DIR)
	SessionLog.log_dir = SessionLog.DEFAULT_DIR
	SessionLog.restart()
	for file in DirAccess.get_files_at(LOG_DIR):
		DirAccess.remove_absolute(LOG_DIR.path_join(file))
	DirAccess.remove_absolute(LOG_DIR)
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
