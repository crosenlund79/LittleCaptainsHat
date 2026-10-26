extends Node
## Revision 0.105b benchmark (from the Iteration 18 one, same scenes so the
## numbers compare), plus the chart's anchorage overlay where the build has
## it. Provenance (0.105b): every result file records the version, the commit
## and the label it was run as (--label=before/after), and when; the I018
## "after" files reported 0.104a because they were run on the Checkpoint H
## tree before the version was raised (see REVISION_0_105B_REPORT.md).
##
## Iteration 18 benchmark: frame times of the scenes this iteration touched,
## measured the same way on any build (newer APIs are looked up at run time,
## so the I017 baseline runs it too). Prints "BENCH18 {json}" and writes the
## file given with --out=PATH. Rendered only (frame times):
##   xvfb-run godot --path . --rendering-driver opengl3 --resolution 1600x900 \
##     res://tests/benchmark_105b.tscn -- --out=/tmp/b.json --label=after
##
## Scenes (Starling 33 at Copenhagen, fair weather, local midnight unless
## said): cabin at night (lamps, shadows, corner shade); deck at night moored;
## deck at night underway (navigation lights); deck at night at anchor
## (anchor light, ball, rode, buoy, the companion on deck where the build has
## it); the rod with a fish on (the reel dial and the animated fish where the
## build has them); and the chart's wind time navigator: frames and time for
## each snapshot to complete, stepping through all of them, then a second
## sweep (cached). Frame time is the wall time between frames with vsync
## off and no frame cap, over FRAMES frames after WARMUP frames.
## Uses the test save folder; never touches the player's saves.

const APP_SCENE := preload("res://src/app/app.tscn")
const FRAMES := 240
const WARMUP := 30
var app: Node
var results := {}


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


## [mean ms, p95 ms, worst ms] over FRAMES frames.
func _measure(label: String) -> void:
	await _frames(WARMUP)
	var times: Array[float] = []
	var last := Time.get_ticks_usec()
	for i in FRAMES:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		times.append((now - last) / 1000.0)
		last = now
	var sorted := times.duplicate()
	sorted.sort()
	var mean := 0.0
	for x in times:
		mean += x / times.size()
	results[label] = {"mean_ms": snappedf(mean, 0.01), "p95_ms": snappedf(sorted[int(sorted.size() * 0.95)], 0.01),
		"worst_ms": snappedf(sorted[-1], 0.01)}
	print("  %-28s mean %6.2f ms  p95 %6.2f ms  worst %6.2f ms" % [label, mean, sorted[int(sorted.size() * 0.95)], sorted[-1]])


func _set_time_midnight() -> void:
	var state := GameSession.get_state_snapshot()
	var geo := GameSession.get_vessel_position()
	state.game_time = 1777593600.0 + (24.0 - geo.x / 15.0) * 3600.0
	GameSession.replace_state(state)


func _show(area: StringName) -> BoatArea:
	app.modals.clear()
	GameSession.enter_boat_area(area, &"start")
	app._show_current_boat_area()
	await _frames(20)
	var screen := app.router.current_screen as BoatArea
	var lighting := screen.get_node_or_null("Lighting")
	if lighting and lighting.has_method("update_now"):
		lighting.update_now()
	app.toasts.clear()
	if app.hud.has_method("hide_warning"):
		app.hud.hide_warning()
	return screen


func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	Simulation.auto_advance = false
	WindField.get_default().test_override = func(_geo: Vector2, _time: float) -> WindField.Sample:
		return WindField.Sample.make(200.0, 8.0)
	app = APP_SCENE.instantiate()
	add_child(app)
	await _frames(10)
	app.start_new_game()
	await _frames(10)
	var state := GameSession.get_state_snapshot()
	state.vessel_id = &"starling_33"
	GameSession.replace_state(state)
	_set_time_midnight()
	var midnight := GameSession.get_game_time()
	await _show(SessionState.AREA_INTERIOR)
	await _measure("cabin_night")
	await _show(SessionState.AREA_EXTERIOR)
	await _measure("deck_night_moored")
	# The rod with a fish on.
	if app.has_method("open_fishing"):
		var catalog: Variant = (load("res://src/fishing/fishing_catalog.gd") as Script).call("get_default")
		var bite := {"species": "cod", "kg": 7.0, "time": GameSession.get_game_time(), "mode": "stationary", "lure": "spinner"}
		if catalog and catalog.has_method("kind_of"):
			bite["kind"] = String(catalog.kind_of("cod"))
			bite["rarity"] = catalog.rarity_of("cod")
		GameSession.set("_pending_bite", bite)
		var menu: Node = app.open_fishing()
		await _frames(5)
		results["fishing_reel_open"] = menu != null and (not menu.has_method("is_reeling") or menu.is_reeling())
		await _measure("fishing_reel_night_deck")
		app.modals.clear()
		if GameSession.has_method("expire_bite"):
			GameSession.expire_bite()
	# Underway and at anchor.
	GameSession.plan_route_to(&"malmo")
	GameSession.depart()
	Simulation.advance(300.0)
	var after := GameSession.get_state_snapshot()
	after.game_time = midnight + 300.0
	GameSession.replace_state(after)
	await _show(SessionState.AREA_EXTERIOR)
	await _measure("deck_night_underway")
	var anchored := false
	for i in 120:
		Simulation.advance(300.0)
		if GameSession.evaluate_anchorage().ok:
			anchored = GameSession.drop_anchor(5, 0.9).error == ""
			break
	results["anchored"] = anchored
	if anchored:
		var at_anchor := GameSession.get_state_snapshot()
		at_anchor.game_time = midnight + 86400.0
		GameSession.replace_state(at_anchor)
		var deck := await _show(SessionState.AREA_EXTERIOR)
		if GameSession.has_method("set_companion_area"):
			GameSession.set_companion_area(&"deck")
			await _frames(240)
		results["companion_on_deck"] = deck.has_method("get_deck_companion") and deck.get_deck_companion() != null and deck.get_deck_companion().visible
		await _measure("deck_night_anchor")
	# The wind time navigator.
	WindField.get_default().test_override = Callable()  # the real wind, as on the chart in play
	app.open_chart()
	for i in 300:
		if app.router.current_screen is WorldMap and not app.router.is_busy():
			break
		await get_tree().process_frame
	var world: Node = app.router.current_screen
	var map: Node = world.get_map_view() if world and world.has_method("get_map_view") else null
	if map and map.get("wind_layer"):
		var layer: Node = map.wind_layer
		if world.has_method("set_wind_shown"):
			world.set_wind_shown(true)
		map.center_on_geo(Vector2(10.5, 56.5), 70.0 / map.units_per_degree)
		await _frames(30)
		var reach: int = layer.MAX_OFFSET_STEPS
		var sweeps := []
		for sweep in 2:
			var total_ms := 0.0
			var worst_ms := 0.0
			var frames := 0
			for steps in range(-reach, reach + 1):
				var start := Time.get_ticks_usec()
				layer.set_offset_steps(steps)
				var n := 0
				while not layer.is_complete() and n < 600:
					await get_tree().process_frame
					n += 1
				var ms := (Time.get_ticks_usec() - start) / 1000.0
				total_ms += ms
				worst_ms = maxf(worst_ms, ms)
				frames += n
			sweeps.append({"snapshots": reach * 2 + 1, "total_ms": snappedf(total_ms, 0.1), "worst_ms": snappedf(worst_ms, 0.1), "frames": frames})
			print("  wind navigator sweep %d: %d snapshots, %.0f ms, worst %.0f ms, %d frames" % [sweep + 1, reach * 2 + 1, total_ms, worst_ms, frames])
		results["wind_navigator"] = sweeps
		layer.set_offset_steps(0)
		await _measure("chart_wind_overlay")
	# The anchorage overlay (0.105b builds): a coast at close zoom, the time
	# for its tiles to fill, then frame times with it shown.
	if world and world.has_method("set_anchorages_shown") and map:
		world.set_wind_shown(false)
		map.center_on_geo(Vector2(-61.85, 17.05), 900.0 / map.units_per_degree)
		await _frames(10)
		var start := Time.get_ticks_usec()
		world.set_anchorages_shown(true)
		var layer: Node = map.anchorage_layer
		var n := 0
		while not layer.is_complete() and n < 6000:
			await get_tree().process_frame
			n += 1
		results["anchorage_overlay_fill"] = {"ms": snappedf((Time.get_ticks_usec() - start) / 1000.0, 0.1), "frames": n,
			"tiles": layer.tiles_computed, "max_frame_work_ms": snappedf(layer.max_frame_usec / 1000.0, 0.01)}
		print("  anchorage overlay fill: %s" % [results["anchorage_overlay_fill"]])
		await _measure("chart_anchorage_overlay")
	results["version"] = ProjectSettings.get_setting("application/config/version", "")
	# The build reads its commit from .git; in a git worktree (.git is a file)
	# it cannot, so the runner may pass --commit=<id> (recorded as given).
	var commit := GameVersion.get_commit()
	results["commit"] = commit if commit != "" else _arg("commit", "")
	results["commit_source"] = "build" if commit != "" else ("runner" if _arg("commit", "") != "" else "unknown")
	results["label"] = _arg("label", "")
	results["measured_at"] = Time.get_datetime_string_from_system(true)
	var json := JSON.stringify(results)
	print("BENCH105B " + json)
	var out := _arg("out", "")
	if out != "":
		var f := FileAccess.open(out, FileAccess.WRITE)
		if f:
			f.store_string(json)
	get_tree().quit()
