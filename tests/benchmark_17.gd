extends Node
## Iteration 17 benchmark: the chart's wind overlay and the weather behind it,
## measured the same way on any build (newer APIs are looked up at run time,
## so the I016 baseline runs it too). Prints "BENCH17 {json}" and writes the
## file given with --out=PATH.
##
##   godot --headless --path . res://tests/benchmark_17.tscn -- --out=/tmp/b.json   (CPU only)
##   godot --path . res://tests/benchmark_17.tscn -- --out=/tmp/b.json              (rendered)
##
## Frame times are averages over N frames. "stationary" leaves the camera
## alone; "pan" moves it 30 px per frame; "zoom" breathes the zoom by ±1 %.
## Uses the test save folder; never touches the player's saves.

const APP_SCENE := preload("res://src/app/app.tscn")
## Zoom levels in screen pixels per degree of longitude, and where.
const VIEWS := {
	"world": [Vector2(10.0, 20.0), 0.0],
	"continental": [Vector2(10.0, 50.0), 14.0],
	"denmark_region": [Vector2(11.0, 57.0), 70.0],
	"coastal": [Vector2(11.0, 55.5), 300.0],
}
const FRAMES := 60

var results := {}
var out_path := ""
var app: Node


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_path = arg.trim_prefix("--out=")
	SaveManager.save_dir = "user://test_saves"
	_run.call_deferred()


func _ms(start_usec: int) -> float:
	return snappedf((Time.get_ticks_usec() - start_usec) / 1000.0, 0.01)


func _mb() -> float:
	return snappedf(OS.get_static_memory_usage() / 1048576.0, 0.1)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _idle() -> void:
	var guard := 0
	while app.router.is_busy() and guard < 3000:
		guard += 1
		await get_tree().process_frame
	await _frames(3)


func _open_chart() -> WorldMap:
	app.open_chart()
	var guard := 0
	while (not (app.router.current_screen is WorldMap) or app.router.is_busy()) and guard < 3000:
		guard += 1
		await get_tree().process_frame
	await _frames(2)
	return app.router.current_screen as WorldMap


func _close_chart() -> void:
	app.close_chart()
	var guard := 0
	while (app.router.current_screen is WorldMap or app.router.is_busy()) and guard < 3000:
		guard += 1
		await get_tree().process_frame
	await _frames(3)


## Weather samples taken so far, when the build counts them (I017), else -1.
func _samples() -> int:
	var model := WeatherModel.get_default()
	return int(model.get("sample_count")) if "sample_count" in model else -1


func _measure(map: MapView, mode: String) -> Dictionary:
	await _frames(5)
	var samples_before := _samples()
	var start := Time.get_ticks_usec()
	for i in FRAMES:
		match mode:
			"pan":
				map.camera.position.x += 30.0 / map.camera.zoom.x
				map._clamp_camera()
			"zoom":
				map.zoom_by(1.0 + 0.01 * sin(i * 0.5))
		await get_tree().process_frame
	var result := {"ms_per_frame": snappedf((Time.get_ticks_usec() - start) / 1000.0 / FRAMES, 0.01)}
	if samples_before >= 0:
		result["weather_samples_per_frame"] = snappedf(float(_samples() - samples_before) / FRAMES, 0.1)
	return result


func _view(map: MapView, name: String) -> void:
	var v: Array = VIEWS[name]
	if float(v[1]) <= 0.0:
		map.reset_view()
		map.camera.position.x = map.projection.geo_to_map(v[0]).x
		map._clamp_camera()
	else:
		map.center_on_geo(v[0], float(v[1]) / map.units_per_degree)
	await _frames(3)


func _run() -> void:
	results["version"] = GameVersion.DISPLAY
	results["renderer"] = DisplayServer.get_name()
	Simulation.auto_advance = false
	var start := Time.get_ticks_usec()
	app = APP_SCENE.instantiate()
	add_child(app)
	app.router.fade_duration = 0.05
	await _frames(3)
	results["app_startup_ms"] = _ms(start)
	app.start_new_game()
	await _idle()
	# The real wind and weather (as in play).
	WindField.get_default().test_override = Callable()

	# Chart: first open, then reopen cycles with memory.
	start = Time.get_ticks_usec()
	var world := await _open_chart()
	results["chart_first_open_ms"] = _ms(start)
	await _close_chart()
	var reopen := []
	var memory := []
	for cycle in 8:
		start = Time.get_ticks_usec()
		world = await _open_chart()
		reopen.append(_ms(start))
		await _close_chart()
		memory.append(_mb())
	results["chart_reopen_ms"] = reopen
	results["chart_reopen_memory_mb"] = memory

	# Frame cost by zoom, wind off and on, stationary / pan / zoom.
	world = await _open_chart()
	var map := world.get_map_view()
	var frames := {}
	for name: String in VIEWS:
		for wind in [false, true]:
			world.set_wind_shown(wind)
			for mode in ["stationary", "pan", "zoom"]:
				await _view(map, name)
				frames["%s|wind_%s|%s" % [name, "on" if wind else "off", mode]] = await _measure(map, mode)
	results["chart_frames"] = frames
	# The cost of one full wind re-sample of the view (what the overlay does
	# when the time it shows changes), and frames while the clock runs at 20x.
	world.set_wind_shown(true)
	var rebuilds := {}
	var clock := {}
	for name: String in VIEWS:
		await _view(map, name)
		var total := 0.0
		var samples_before := _samples()
		for r in 4:
			var t0 := Time.get_ticks_usec()
			_force_wind_time(map, GameSession.get_game_time() + 3600.0 * (r + 1))
			await get_tree().process_frame
			total += (Time.get_ticks_usec() - t0) / 1000.0
		rebuilds[name] = {"ms_per_rebuild_frame": snappedf(total / 4.0, 0.01)}
		if samples_before >= 0:
			rebuilds[name]["weather_samples_per_rebuild"] = (_samples() - samples_before) / 4
		_force_wind_time(map, GameSession.get_game_time())
		await _frames(3)
		GameSession.set_time_scale(20)
		Simulation.auto_advance = true
		clock[name] = await _measure(map, "stationary")
		Simulation.auto_advance = false
		GameSession.set_time_scale(1)
	results["wind_rebuild"] = rebuilds
	results["chart_stationary_clock_20x_wind_on"] = clock
	await _close_chart()

	# Sailing with the chart closed: simulation cost per game day.
	GameSession.plan_route_to(&"las_palmas")
	GameSession.depart()
	var samples_before := _samples()
	start = Time.get_ticks_usec()
	for slot in 8:
		Simulation.advance(6.0 * 3600.0)
	results["sail_sim_ms_per_day"] = snappedf(_ms(start) / 2.0, 0.1)
	if samples_before >= 0:
		results["sail_weather_samples_per_day"] = (_samples() - samples_before) / 2
	# Long Passage at 12 game hours per second: real time per game day.
	start = Time.get_ticks_usec()
	var ticks := 0
	var begin := GameSession.get_game_time()
	Simulation.start_passage(Simulation.PASSAGE_RATES[2])
	while GameSession.get_game_time() - begin < 2.0 * 86400.0 and GameSession.is_underway() and ticks < 2000:
		if not Simulation.is_passage_running():
			Simulation.start_passage(Simulation.PASSAGE_RATES[2])
		Simulation.tick(0.1)
		ticks += 1
	Simulation.stop_passage()
	var days := (GameSession.get_game_time() - begin) / 86400.0
	results["long_passage_ms_per_game_day"] = snappedf(_ms(start) / maxf(days, 0.01), 0.1)
	# Deck frames underway (no chart).
	results["deck_underway_ms_per_frame"] = await _plain(90)
	# Save and load.
	start = Time.get_ticks_usec()
	SaveManager.save_to_slot(3, GameSession.get_state_snapshot())
	results["save_ms"] = _ms(start)
	start = Time.get_ticks_usec()
	var loaded := SaveManager.load_from_slot(3)
	if loaded.is_ok():
		GameSession.replace_state(loaded.state)
	results["load_ms"] = _ms(start)
	SaveManager.delete_slot(3)
	results["memory_end_mb"] = _mb()

	var line := JSON.stringify(results)
	print("BENCH17 " + line)
	if out_path != "":
		var file := FileAccess.open(out_path, FileAccess.WRITE)
		if file:
			file.store_string(JSON.stringify(results, "  ", true))
			file.close()
	app.queue_free()
	await _frames(2)
	GameSession.end_session()
	get_tree().quit(0)


## Makes the overlay show `time` now (whatever the build calls it).
func _force_wind_time(map: MapView, time: float) -> void:
	var layer: Variant = map.wind_layer
	if layer.has_method("force_snapshot"):
		layer.force_snapshot(time)
	else:
		layer.update_time(time, true)


func _plain(count: int) -> float:
	var start := Time.get_ticks_usec()
	await _frames(count)
	return snappedf((Time.get_ticks_usec() - start) / 1000.0 / count, 0.01)
