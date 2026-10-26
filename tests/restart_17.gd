extends Node
## Iteration 17 (SAVE-4): saving underway and loading in a new process.
## Run twice, as two separate processes (the game quits in between):
##   godot --headless --path . res://tests/restart_17.tscn -- --phase=write
##   godot --headless --path . res://tests/restart_17.tscn -- --phase=read
## Three saves underway: on deck near the bow, in the cabin, and in poor
## weather. For each, the read phase checks the captain is aboard where they
## stood (relative to the boat), in the right area, with the boat's position,
## time, route and weather as saved; then sails six more hours and compares
## the result with what the write phase got sailing the same six hours
## (deterministic weather across processes). Exits 0 only if all hold.

const APP_SCENE := preload("res://src/app/app.tscn")
const SAVE_DIR := "user://test_restart17_saves"
const EXPECT_PATH := "user://test_restart17_expect.json"
const SIX_HOURS := 6.0 * 3600.0

var app: Node
var failures := PackedStringArray()


func _ready() -> void:
	var phase := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--phase="):
			phase = arg.trim_prefix("--phase=")
	SaveManager.save_dir = SAVE_DIR
	SessionLog.log_dir = "user://test_restart17_diagnostics"
	Simulation.auto_advance = false
	app = APP_SCENE.instantiate()
	add_child(app)
	app.router.fade_duration = 0.05
	if phase == "write":
		_write.call_deferred()
	elif phase == "read":
		_read.call_deferred()
	else:
		push_error("Use --phase=write or --phase=read")
		get_tree().quit(2)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _idle() -> void:
	var guard := 0
	while app.router.is_busy() and guard < 2000:
		guard += 1
		await get_tree().process_frame
	await _frames(4)
	for i in 4:
		await get_tree().physics_frame


func _show(area: StringName) -> BoatArea:
	app.modals.clear()
	GameSession.enter_boat_area(area, &"start")
	app._show_current_boat_area()
	await _idle()
	return app.router.current_screen as BoatArea


func _weather_text() -> String:
	var w := Simulation.get_weather_at_vessel()
	return "%.4f|%.4f|%.4f|%s" % [w.speed_kn, w.from_deg, w.gust_kn, w.classification]


func _snapshot(area: BoatArea) -> Dictionary:
	return {"area": String(area.area_id), "player": [area.player.position.x, area.player.position.y],
		"vessel": [GameSession.get_vessel_position().x, GameSession.get_vessel_position().y],
		"time": GameSession.get_game_time(), "progress": GameSession.get_voyage_progress_nm(),
		"destination": String(GameSession.get_voyage_destination_id()), "weather": _weather_text()}


## Saves `slot` here, then sails six hours and records where that led.
func _save_case(slot: int, label: String, area: BoatArea, expect: Dictionary) -> void:
	await _frames(2)
	var before := _snapshot(area)
	SaveManager.save_to_slot(slot, GameSession.get_state_snapshot())
	Simulation.advance(SIX_HOURS)
	before["after_vessel"] = [GameSession.get_vessel_position().x, GameSession.get_vessel_position().y]
	before["after_weather"] = _weather_text()
	before["label"] = label
	expect[str(slot)] = before
	print("RESTART17 wrote %s: %s" % [label, before])


func _write() -> void:
	for slot in [1, 2, 3]:
		SaveManager.delete_slot(slot)
	await _idle()
	app.start_new_game()
	await _idle()
	GameSession.plan_route_to(&"las_palmas")
	GameSession.depart()
	Simulation.advance(3.0 * 3600.0)
	var expect := {}
	var deck := await _show(SessionState.AREA_EXTERIOR)
	deck.player.position = Vector2(deck._boat_view_bounds().end.x - 110.0, 0.0)  # near the bow
	for i in 20:
		await get_tree().physics_frame
	await _save_case(1, "on deck near the bow", deck, expect)
	var cabin := await _show(SessionState.AREA_INTERIOR)
	await _save_case(2, "in the cabin", cabin, expect)
	# Sail on until the weather at the boat is poor (strong wind, gale or storms).
	var found := false
	for i in 400:
		var w := Simulation.get_weather_at_vessel()
		if w.hazard >= WeatherModel.HAZARD_CAUTION or w.speed_kn >= 22.0:
			found = true
			break
		Simulation.advance(1800.0)
		if not GameSession.is_underway():
			break
	deck = await _show(SessionState.AREA_EXTERIOR)
	print("RESTART17 poor weather found: %s (%s)" % [found, _weather_text()])
	await _save_case(3, "in poor weather" if found else "after the search for poor weather (none found)", deck, expect)
	expect["poor_weather_found"] = found
	var file := FileAccess.open(EXPECT_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(expect, "", true, true))
	file.close()
	get_tree().quit(0)


func _close(a: Array, b: Vector2, tolerance: float) -> bool:
	return Vector2(a[0], a[1]).distance_to(b) <= tolerance


func _read() -> void:
	var expect: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(EXPECT_PATH))
	await _idle()
	for slot in [1, 2, 3]:
		var e: Dictionary = expect[str(slot)]
		app.load_slot(slot)
		await _idle()
		var area := app.router.current_screen as BoatArea
		var label: String = e.label
		var ok: bool = area != null and String(area.area_id) == e.area
		_check(ok, "%s: loaded into the %s" % [label, e.area])
		if not ok:
			continue
		_check(_close(e.player, area.player.position, 0.5) and area.is_valid_player_position(area.player.position),
			"%s: the captain stands where they stood, aboard (%s vs %s)" % [label, e.player, area.player.position])
		_check(_close(e.vessel, GameSession.get_vessel_position(), 1e-4) and absf(float(e.time) - GameSession.get_game_time()) < 0.01
			and absf(float(e.progress) - GameSession.get_voyage_progress_nm()) < 1e-6 and String(GameSession.get_voyage_destination_id()) == e.destination,
			"%s: position, time, route and progress as saved" % label)
		_check(_weather_text() == e.weather, "%s: the same weather at the boat (%s)" % [label, e.weather])
		Simulation.advance(SIX_HOURS)
		_check(_close(e.after_vessel, GameSession.get_vessel_position(), 1e-4) and _weather_text() == e.after_weather,
			"%s: six hours later the boat is where it was in the first process, in the same weather" % label)
	print("RESTART17 poor weather case: %s" % ("found" if expect.poor_weather_found else "not found within the search"))
	print("RESTART17 %s" % ("PASS" if failures.is_empty() else "FAIL: " + "; ".join(failures)))
	get_tree().quit(0 if failures.is_empty() else 1)


func _check(condition: bool, text: String) -> void:
	print("RESTART17 %s %s" % ["ok  " if condition else "FAIL", text])
	if not condition:
		failures.append(text)
