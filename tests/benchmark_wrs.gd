extends Node
## The Well-Run Ship (Injection 2) probe: frame times, stalls and growth in
## the situations the Captain reported (sleep, day/night changes in harbour,
## at the chart and underway, Long Passage, long sessions). Same scenes on any
## build, for before/after comparison only. Prints "WRS {json}" and writes the
## file given with --out=PATH. Rendered (frame times):
##   xvfb-run godot --path . --rendering-driver opengl3 --resolution 1600x900 \
##     res://tests/benchmark_wrs.tscn -- --out=/tmp/w.json --label=before
##
## Frame time is the wall time between frames (vsync off, no frame cap).
## A "stall" is a frame over STALL_MS. Every scenario also records the
## structure of the game afterwards (nodes, objects, orphan nodes, signal
## connections on the autoloads, tweens, audio players, cache sizes, the
## diagnostic log's lines) so growth across a session shows as a trend.
## Starling 33 at Copenhagen, fixed fair wind. Uses the test save folder and
## a test diagnostics folder; never touches the player's files.

const APP_SCENE := preload("res://src/app/app.tscn")
const STALL_MS := 50.0
const COPENHAGEN := Vector2(12.59, 55.68)

var app: Node
var results := {"scenarios": {}, "growth": []}
var _log_lines_before := 0


func _ready() -> void:
	SaveManager.save_dir = "user://test_saves"
	_run.call_deferred()


func _arg(name: String, fallback: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % name):
			return a.get_slice("=", 1)
	return fallback


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


# --- Measuring --------------------------------------------------------------------------------

## Frame times while `per_frame` (optional) runs each frame, for `frames`
## frames: mean, median, p95, p99, worst, stalls, and script process time.
func _measure(label: String, frames: int, per_frame := Callable(), warmup := 10) -> Dictionary:
	await _frames(warmup)
	var times: Array[float] = []
	var process: Array[float] = []
	var last := Time.get_ticks_usec()
	for i in frames:
		if per_frame.is_valid():
			per_frame.call(i)
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		times.append((now - last) / 1000.0)
		process.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		last = now
	var entry := _stats(times)
	entry["process_ms_mean"] = snappedf(_mean(process), 0.01)
	entry["process_ms_max"] = snappedf(process.max(), 0.01)
	entry["draw_calls"] = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	entry["structure"] = _structure()
	results.scenarios[label] = entry
	print("  %-34s mean %6.2f  med %6.2f  p95 %6.2f  p99 %6.2f  worst %7.2f ms  stalls %d  nodes %d" % [label, entry.mean_ms,
		entry.median_ms, entry.p95_ms, entry.p99_ms, entry.worst_ms, entry.stalls, entry.structure.nodes])
	return entry


func _stats(times: Array[float]) -> Dictionary:
	var sorted := times.duplicate()
	sorted.sort()
	var n := sorted.size()
	var stalls := sorted.filter(func(x: float) -> bool: return x > STALL_MS).size()
	return {"frames": n, "mean_ms": snappedf(_mean(times), 0.01), "median_ms": snappedf(sorted[n / 2], 0.01),
		"p95_ms": snappedf(sorted[mini(int(n * 0.95), n - 1)], 0.01), "p99_ms": snappedf(sorted[mini(int(n * 0.99), n - 1)], 0.01),
		"worst_ms": snappedf(sorted[-1], 0.01), "stalls": stalls, "total_ms": snappedf(_sum(times), 0.1)}


static func _mean(values: Array) -> float:
	return _sum(values) / maxi(values.size(), 1)


static func _sum(values: Array) -> float:
	var total := 0.0
	for v in values:
		total += v
	return total


## The game's structure now (for growth across a session).
func _structure() -> Dictionary:
	var connections := 0
	for child in get_tree().root.get_children():
		if child == self or child == app:
			continue
		for s in child.get_signal_list():
			connections += child.get_signal_connection_list(s.name).size()
	var audio := 0
	var timers := 0
	for node in get_tree().root.find_children("*", "", true, false):
		if node is AudioStreamPlayer or node is AudioStreamPlayer2D:
			audio += 1
		elif node is Timer:
			timers += 1
	var weather: Object = WeatherModel.get_default()
	var router := SeaRouter.get_loaded()
	return {
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"objects": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		"resources": int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),
		"orphan_nodes": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
		"static_mb": snappedf(Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, 0.1),
		"autoload_connections": connections,
		"tweens": get_tree().get_processed_tweens().size(),
		"audio_players": audio,
		"timer_nodes": timers,
		"theme_tints": UiTheme.get("_tints").size() if UiTheme.get("_tints") != null else -1,
		"theme_dims": UiTheme.get("_dims").size() if UiTheme.get("_dims") != null else -1,
		"weather_cache": weather.get("_slot_cache").size() + weather.get("_bucket_cache").size() + weather.get("_cell_cache").size(),
		"router_leg_cache": router.get("_leg_cache").size() if router else -1,
		"log_lines": _log_lines() - _log_lines_before,
	}


func _log_lines() -> int:
	var lines = SessionLog.get("_lines")
	return lines if lines is int else 0


# --- Setting scenes up --------------------------------------------------------------------------

func _show(area: StringName) -> BoatArea:
	app.modals.clear()
	GameSession.enter_boat_area(area, &"start")
	app._show_current_boat_area()
	await _frames(15)
	app.toasts.clear()
	return app.router.current_screen as BoatArea


func _close_chart() -> void:
	if app.router.current_screen is WorldMap:
		app.close_chart()
	await _frames(15)


## The game time `minutes` before the sun next crosses `elevation` (rising
## when `rising`) at `geo`, from `from`.
static func _time_before_crossing(geo: Vector2, from: float, elevation: float, rising: bool, minutes: float) -> float:
	var t := from
	var before := Daylight.sun_elevation(geo, t)
	for i in 2 * 24 * 60:
		t += 60.0
		var now := Daylight.sun_elevation(geo, t)
		if (rising and before < elevation and now >= elevation) or (not rising and before > elevation and now <= elevation):
			return t - minutes * 60.0
		before = now
	return from


func _moor() -> void:
	var state := GameSession.get_state_snapshot()
	state.location_id = &"copenhagen"
	state.vessel_status = SessionState.STATUS_MOORED
	state.vessel_position = PortCatalog.get_default().get_port(&"copenhagen").get_geo_position()
	state.voyage = null
	state.planned_route = null
	GameSession.replace_state(state)


func _set_time(t: float) -> void:
	var state := GameSession.get_state_snapshot()
	state.game_time = t
	GameSession.replace_state(state)
	UiTheme.set_blend(UiTheme._target_blend(), true)


## Walking: the player goes right, then left, then up and down.
func _walk(i: int) -> void:
	var dirs := [&"move_right", &"move_left", &"move_up", &"move_down"]
	for d in dirs:
		Input.action_release(d)
	Input.action_press(dirs[(i / 45) % 4])


func _stop_walking() -> void:
	for d in [&"move_right", &"move_left", &"move_up", &"move_down"]:
		Input.action_release(d)


## Real time passes normally (auto_advance) at the given time scale.
func _run_time(scale: int) -> void:
	GameSession.set_time_scale(scale)
	Simulation.auto_advance = true


func _stop_time() -> void:
	Simulation.auto_advance = false
	GameSession.set_time_scale(1)


func _growth(label: String) -> void:
	var s := _structure()
	s["at"] = label
	results.growth.append(s)
	print("  growth %-24s nodes %d objects %d orphans %d conns %d tweens %d audio %d tints %d dims %d static %.1f MB log %d" % [label,
		s.nodes, s.objects, s.orphan_nodes, s.autoload_connections, s.tweens, s.audio_players, s.theme_tints, s.theme_dims,
		s.static_mb, s.log_lines])


# --- The run ---------------------------------------------------------------------------------------

func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var started := Time.get_ticks_msec()
	WindField.get_default().test_override = func(_geo: Vector2, _time: float) -> WindField.Sample:
		return WindField.Sample.make(200.0, 8.0)
	app = APP_SCENE.instantiate()
	add_child(app)
	await get_tree().process_frame
	# Startup: until the app has loaded what it needs (loading screen gone).
	var loading_frames := 0
	while app.has_method("is_loading") and app.is_loading() and loading_frames < 2000:
		await get_tree().process_frame
		loading_frames += 1
	results["startup_ms_after_engine"] = Time.get_ticks_msec() - started
	results["engine_ms_before_probe"] = started
	app.start_new_game()
	await _frames(10)
	Simulation.auto_advance = false
	var state := GameSession.get_state_snapshot()
	state.vessel_id = &"starling_33"
	GameSession.replace_state(state)
	_log_lines_before = _log_lines()
	var t0 := GameSession.get_game_time()
	_growth("start")

	# 1-3. Walking: deck in harbour, cabin, at noon.
	_set_time(_time_before_crossing(COPENHAGEN, t0, 40.0, true, 0.0))
	await _show(SessionState.AREA_EXTERIOR)
	await _measure("walk_deck_harbour_day", 360, _walk)
	_stop_walking()
	await _show(SessionState.AREA_INTERIOR)
	await _measure("walk_cabin_day", 360, _walk)
	_stop_walking()

	# 4. Day/night in harbour while walking on deck (20x, sunset).
	_set_time(_time_before_crossing(COPENHAGEN, GameSession.get_game_time(), -1.0, false, 50.0))
	await _show(SessionState.AREA_EXTERIOR)
	_run_time(20)
	await _measure("daynight_harbour_walk_20x", 600, _walk, 0)
	_stop_walking()
	_stop_time()
	await _measure("harbour_night_still", 240)

	# 5. The navigation station: open, idle, through a sunrise, open/close.
	_set_time(_time_before_crossing(COPENHAGEN, GameSession.get_game_time(), -1.0, true, 50.0))
	await _show(SessionState.AREA_INTERIOR)
	app.open_chart()
	await _frames(20)
	await _measure("chart_open_idle", 240)
	_run_time(20)
	await _measure("daynight_chart_20x", 600, Callable(), 0)
	_stop_time()
	await _close_chart()
	var opens: Array[float] = []
	var before_nodes := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	for i in 12:
		var t := Time.get_ticks_usec()
		app.open_chart()
		await get_tree().process_frame
		opens.append((Time.get_ticks_usec() - t) / 1000.0)
		await _frames(10)
		await _close_chart()
	results.scenarios["chart_open_close_x12"] = {"open_ms": _stats(opens), "nodes_before": before_nodes,
		"nodes_after": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), "structure": _structure()}
	print("  chart open x12: mean %.1f ms worst %.1f ms, nodes %d -> %d" % [_mean(opens), opens.max(), before_nodes,
		int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))])
	_growth("after_chart_cycles")

	# 6-8. Sleep across midnight, sunrise and sunset (in harbour).
	for spec in [["sleep_8h_across_midnight", -30.0, false, 180.0], ["sleep_4h_across_sunrise", 0.0, true, 120.0],
			["sleep_4h_across_sunset", 0.0, false, 120.0]]:
		var start := _time_before_crossing(COPENHAGEN, GameSession.get_game_time(), spec[1], spec[2], spec[3])
		_set_time(start)
		await _show(SessionState.AREA_INTERIOR)
		await _frames(30)
		var hours := 8.0 if String(spec[0]).contains("8h") else 4.0
		var t := Time.get_ticks_usec()
		app.sleep_for(hours)
		var call_ms := (Time.get_ticks_usec() - t) / 1000.0
		var after := await _measure(spec[0], 300, Callable(), 0)
		after["sleep_call_ms"] = snappedf(call_ms, 0.1)
		print("    sleep call %.1f ms" % call_ms)
	_growth("after_sleeps")

	# 9. Sailing at 1x, then a day/night change underway at 20x.
	_set_time(_time_before_crossing(COPENHAGEN, GameSession.get_game_time(), -1.0, false, 50.0))
	GameSession.plan_route_to(&"gothenburg")
	GameSession.depart()
	await _show(SessionState.AREA_EXTERIOR)
	_run_time(1)
	await _measure("sailing_1x", 360)
	_run_time(20)
	await _measure("daynight_sailing_20x", 600, Callable(), 0)
	_stop_time()

	# 10. Repeated day/night changes: five sunrises and sunsets in harbour.
	_moor()
	var repeated := []
	for i in 6:
		var rising := i % 2 == 1
		_set_time(_time_before_crossing(COPENHAGEN, GameSession.get_game_time() + 3600.0, -1.0, rising, 30.0))
		await _show(SessionState.AREA_EXTERIOR)
		_run_time(20)
		var e := await _measure("daynight_repeat_%d" % i, 300, Callable(), 0)
		_stop_time()
		repeated.append([e.mean_ms, e.worst_ms, e.stalls, e.structure.nodes, e.structure.autoload_connections])
	results["daynight_repeated"] = repeated
	_growth("after_repeated_daynight")

	# 11. Long Passage on a long voyage (Copenhagen -> Reykjavik), 12 h per second.
	await _long_passage()

	# 12. A long session: 20 rounds of deck, cabin, chart, a short sleep.
	for round in 20:
		await _show(SessionState.AREA_EXTERIOR)
		await _show(SessionState.AREA_INTERIOR)
		app.open_chart()
		await _frames(10)
		await _close_chart()
		app.sleep_for(1.0)
		await _frames(10)
		if round % 5 == 4:
			_growth("session_round_%d" % (round + 1))
	await _show(SessionState.AREA_EXTERIOR)
	await _measure("walk_deck_after_session", 360, _walk)
	_stop_walking()

	results["version"] = ProjectSettings.get_setting("application/config/version", "")
	results["label"] = _arg("label", "")
	results["renderer"] = "%s / %s" % [RenderingServer.get_video_adapter_name(), RenderingServer.get_video_adapter_vendor()]
	results["when"] = Time.get_datetime_string_from_system(true)
	var json := JSON.stringify(results)
	print("WRS " + json)
	var out := _arg("out", "")
	if not out.is_empty():
		var f := FileAccess.open(out, FileAccess.WRITE)
		f.store_string(JSON.stringify(results, "  "))
	get_tree().quit()


func _long_passage() -> void:
	_set_time(_time_before_crossing(COPENHAGEN, GameSession.get_game_time(), 20.0, true, 0.0))
	_moor()
	var error := GameSession.plan_route_to(&"reykjavik")
	GameSession.depart()
	await _show(SessionState.AREA_EXTERIOR)
	var rate := Simulation.PASSAGE_RATES[-1]
	var started := Simulation.start_passage(rate)
	var sim_ms: Array[float] = []
	var progress_before := GameSession.get_voyage_progress_nm()
	var game_before := GameSession.get_game_time()
	# Simulation stepped here (auto_advance off) so its own cost is measured.
	var step := func(_i: int) -> void:
		if not Simulation.is_passage_running():
			return
		var t := Time.get_ticks_usec()
		Simulation.tick(get_process_delta_time())
		sim_ms.append((Time.get_ticks_usec() - t) / 1000.0)
	var e := await _measure("long_passage_12h_per_s", 360, step, 0)
	e["plan_error"] = error
	e["start_error"] = started
	e["sim_ms"] = _stats(sim_ms) if not sim_ms.is_empty() else {}
	e["game_hours"] = snappedf((GameSession.get_game_time() - game_before) / 3600.0, 0.1)
	e["nm"] = snappedf(GameSession.get_voyage_progress_nm() - progress_before, 0.1)
	e["still_running"] = Simulation.is_passage_running()
	print("    passage: %.1f game h, %.1f nm, sim per frame mean %.2f ms worst %.2f ms (%s)" % [e.game_hours, e.nm,
		e.sim_ms.get("mean_ms", 0.0), e.sim_ms.get("worst_ms", 0.0), "running" if e.still_running else "interrupted"])
	Simulation.stop_passage()
	_growth("after_long_passage")
