extends Node
## Performance benchmark (Iteration 16): the same measurements before and
## after a change, printed as one JSON line ("BENCH {...}") and written to
## the file given with --out=PATH.
##
## Run headless (load, routing, simulation, memory):
##   godot --headless --path . res://tests/benchmark.tscn -- --out=/tmp/bench.json
## Run rendered for frame times (e.g. under Xvfb):
##   godot --path . res://tests/benchmark.tscn -- --out=/tmp/bench_rendered.json
##
## Uses the test save folder; never touches the player's saves.

const APP_SCENE := preload("res://src/app/app.tscn")
## Routes measured cold (fresh router, empty caches): [from, to].
const ROUTES := [
	[&"copenhagen", &"svendborg"],
	[&"copenhagen", &"kiel"],
	[&"copenhagen", &"lisbon"],
	[&"copenhagen", &"piraeus"],
	[&"reykjavik", &"piraeus"],
]
## Extra routes measured when the harbours exist (worldwide chart).
const WORLD_ROUTES := [
	[&"copenhagen", &"las_palmas"],
	[&"las_palmas", &"bridgetown"],
	[&"bridgetown", &"papeete"],
	[&"papeete", &"auckland"],
	[&"copenhagen", &"papeete"],
]

var results := {}
var out_path := ""


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_path = arg.trim_prefix("--out=")
	SaveManager.save_dir = "user://test_saves"
	_run.call_deferred()


func _ms(start_usec: int) -> float:
	return snappedf((Time.get_ticks_usec() - start_usec) / 1000.0, 0.1)


func _mb() -> float:
	return snappedf(OS.get_static_memory_usage() / 1048576.0, 0.1)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _run() -> void:
	results["version"] = GameVersion.DISPLAY
	results["renderer"] = DisplayServer.get_name()
	results["memory_start_mb"] = _mb()
	# Navigation data (fresh, uncached).
	var start := Time.get_ticks_usec()
	var router := SeaRouter.load_from(NavGrid.DEFAULT_MASK, NavGrid.DEFAULT_META, SeaRouter.DEFAULT_GRAPH)
	results["navigation_load_ms"] = _ms(start)
	results["graph_nodes"] = router.get_node_count()
	results["memory_after_navigation_mb"] = _mb()
	var routes := {}
	for pair: Array in ROUTES + WORLD_ROUTES:
		var from := PortCatalog.get_default().get_port(pair[0])
		if from == null or PortCatalog.get_default().get_port(pair[1]) == null:
			continue
		var fresh := router
		start = Time.get_ticks_usec()
		var result := fresh.plan_route(from.id, from.get_geo_position(), [], pair[1])
		routes["%s>%s" % pair] = {"ms": _ms(start), "ok": result.is_ok(),
			"nm": snappedf(result.route.get_distance_nm(), 1.0) if result.is_ok() else 0.0}
	results["routes_cold"] = routes
	router = null
	# The game: startup, chart, frames.
	Simulation.auto_advance = false
	start = Time.get_ticks_usec()
	var app := APP_SCENE.instantiate()
	add_child(app)
	await _frames(3)
	results["app_startup_ms"] = _ms(start)
	app.router.fade_duration = 0.05
	app.start_new_game()
	await _frames(10)
	start = Time.get_ticks_usec()
	app.open_chart()
	await _frames(1)
	results["chart_open_ms"] = _ms(start)
	await _frames(10)
	var world := app.router.current_screen as WorldMap
	if world:
		var map := world.get_map_view()
		results["frame_chart_whole_ms"] = await _frame_time(map, Vector2.ZERO, 0.0, 90)
		results["frame_chart_europe_ms"] = await _frame_time(map, Vector2(10.0, 50.0), 25.0 / map.units_per_degree, 90)
		results["frame_chart_denmark_ms"] = await _frame_time(map, Vector2(11.0, 55.5), 300.0 / map.units_per_degree, 90)
		results["frame_chart_pan_ms"] = await _pan_time(map, 120)
		app.close_chart()
		await _frames(10)
	results["frame_deck_ms"] = await _plain_frames(90)
	# A long session at sea: ten days of simulated sailing, the chart opened
	# and closed between, memory watched.
	results["memory_before_session_mb"] = _mb()
	GameSession.plan_route_to(&"piraeus")
	var depart_error := GameSession.depart()
	var sim_ms := 0.0
	var chart_cycles := 0
	if depart_error == "":
		for day in 10:
			start = Time.get_ticks_usec()
			for slot in 4:
				Simulation.advance(6.0 * 3600.0)
			sim_ms += (Time.get_ticks_usec() - start) / 1000.0
			app.open_chart()
			await _frames(4)
			app.close_chart()
			await _frames(4)
			chart_cycles += 1
	results["session_days"] = 10 if depart_error == "" else 0
	results["session_sim_ms_per_day"] = snappedf(sim_ms / 10.0, 0.1)
	results["session_chart_cycles"] = chart_cycles
	results["memory_after_session_mb"] = _mb()
	results["memory_session_growth_mb"] = snappedf(results.memory_after_session_mb - results.memory_before_session_mb, 0.1)
	# Save and load.
	start = Time.get_ticks_usec()
	SaveManager.save_to_slot(3, GameSession.get_state_snapshot())
	results["save_ms"] = _ms(start)
	start = Time.get_ticks_usec()
	var loaded := SaveManager.load_from_slot(3)
	results["load_parse_ms"] = _ms(start)
	start = Time.get_ticks_usec()
	if loaded.is_ok():
		GameSession.replace_state(loaded.state)
	results["load_apply_ms"] = _ms(start)
	SaveManager.delete_slot(3)
	results["memory_end_mb"] = _mb()
	var line := JSON.stringify(results)
	print("BENCH " + line)
	if out_path != "":
		var file := FileAccess.open(out_path, FileAccess.WRITE)
		if file:
			file.store_string(JSON.stringify(results, "  ", true))
			file.close()
	app.queue_free()
	await _frames(2)
	GameSession.end_session()
	get_tree().quit(0)


func _frame_time(map: MapView, centre: Vector2, zoom: float, count: int) -> float:
	if zoom <= 0.0:
		map.reset_view()
	else:
		map.center_on_geo(centre, zoom)
	await _frames(5)
	var start := Time.get_ticks_usec()
	for i in count:
		map.zoom_by(1.0 + 0.002 * sin(i * 0.3))  # keep the view changing a little
		await get_tree().process_frame
	return snappedf((Time.get_ticks_usec() - start) / 1000.0 / count, 0.01)


func _pan_time(map: MapView, count: int) -> float:
	map.center_on_geo(Vector2(0.0, 45.0), 12.0 / map.units_per_degree)
	await _frames(5)
	var start := Time.get_ticks_usec()
	for i in count:
		map.camera.position.x += 40.0 / map.camera.zoom.x
		map._clamp_camera()
		map._overlay.queue_redraw()
		await get_tree().process_frame
	return snappedf((Time.get_ticks_usec() - start) / 1000.0 / count, 0.01)


func _plain_frames(count: int) -> float:
	var start := Time.get_ticks_usec()
	await _frames(count)
	return snappedf((Time.get_ticks_usec() - start) / 1000.0 / count, 0.01)
