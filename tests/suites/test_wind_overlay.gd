extends RefCounted
## Iteration 17 (WND): the chart's wind overlay is a cached snapshot, separate
## from the sailing weather.
## - WeatherModel.sample_wind gives exactly sample()'s speed and direction,
##   inside and outside gales, thunderstorms and cyclones.
## - A stationary chart samples no weather; small pans reuse cached chunks;
##   sampling per frame stays within its budget; a snapshot change keeps the
##   old field on screen until the new one is complete.
## - Fast clocks take at most one Now snapshot per real second.
## - The time navigator steps 30 minutes to ±2 h, labels NOW / PAST MODEL
##   SNAPSHOT / FORECAST, shows the forecast note, and changes nothing in the
##   game. Zoomed out, wind is hidden with "Zoom in to see wind details."
##   (with hysteresis). Closing the chart stops chart wind work.

const APP_SCENE := preload("res://src/app/app.tscn")

var t: Node
var app: Node


func run(runner: Node) -> void:
	t = runner
	_test_wind_only_query()
	Simulation.auto_advance = false
	app = APP_SCENE.instantiate()
	t.add_child(app)
	app.router.fade_duration = 0.05
	await _idle()
	app.start_new_game()
	await _idle()
	WindField.get_default().test_override = Callable()  # the real wind and weather
	app.open_chart()
	await t.wait_until(func() -> bool: return app.router.current_screen is WorldMap and not app.router.is_busy(), 10.0)
	var world := app.router.current_screen as WorldMap
	if t.check(world != null, "(setup) the chart is open"):
		world.set_wind_shown(true)
		var map := world.get_map_view()
		await _test_snapshot_cache(world, map)
		await _test_zoom_detail(world, map)
		await _test_time_navigator(world, map)
		await _test_fast_clock(map)
		await _test_closing_stops(world)
	Simulation.auto_advance = true
	app.queue_free()
	await t.frames(2)
	GameSession.end_session()


func _idle() -> void:
	await t.frames(2)
	await t.wait_until(func() -> bool: return not app.router.is_busy(), 5.0)
	await t.frames(2)


func _test_wind_only_query() -> void:
	var model := WeatherModel.get_default()
	var saved := WindField.get_default().test_override
	WindField.get_default().test_override = Callable()
	var start := 1777593600.0  # 1 May 2026
	var compared := 0
	var worst := 0.0
	var kinds := {}
	var points: Array[Vector2] = []
	for i in 40:
		points.append(Vector2(-180.0 + fmod(i * 47.3, 360.0), -60.0 + fmod(i * 23.7, 125.0)))
	for day in range(0, 400, 9):
		var time := start + day * 86400.0 + fmod(day * 3373.0, 86400.0)
		var here := points.duplicate()
		for event in model.active_events(time, 7):
			var centre := event.center_at(time)
			here.append(centre)
			here.append(centre + Vector2(0.4, 0.3))
			kinds[event.kind] = true
		for geo in here:
			for known in [INF, time - 6.0 * 3600.0]:
				var full := model.sample(geo, time, 7, known)
				var wind := model.sample_wind(geo, time, 7, known)
				compared += 1
				worst = maxf(worst, absf(full.speed_kn - wind.y))
				if full.speed_kn > 0.05:
					worst = maxf(worst, absf(angle_difference(deg_to_rad(full.from_deg), deg_to_rad(wind.x))))
	WindField.get_default().test_override = saved
	t.check(compared > 2000 and worst < 1e-4,
		"[wind query] sample_wind equals sample() in speed and direction (%d points, worst difference %.6f)" % [compared, worst])
	t.check(kinds.has(WeatherEvent.KIND_GALE) and kinds.has(WeatherEvent.KIND_THUNDERSTORM) and kinds.has(WeatherEvent.KIND_CYCLONE),
		"[wind query] the comparison covered gales, thunderstorms and cyclones (%s)" % ", ".join(kinds.keys()))


## Waits until the overlay shows the complete selected snapshot.
func _complete(map: MapView) -> bool:
	return await t.wait_until(func() -> bool: return map.wind_layer.is_complete(), 10.0)


func _test_snapshot_cache(world: WorldMap, map: MapView) -> void:
	var layer := map.wind_layer
	var model := WeatherModel.get_default()
	map.center_on_geo(Vector2(10.5, 56.5), 70.0 / map.units_per_degree)  # Denmark and southern Norway
	await t.frames(2)
	t.check(await _complete(map), "[overlay] the regional snapshot completes")
	t.check(not layer.detail_hidden, "[overlay] regional zoom shows wind detail")
	# Arrows only at sea: every lattice point drawn as an arrow is navigable water.
	var grid := SeaRouter.get_default().grid
	var lattice := layer._lattice()
	var arrows := 0
	var on_land := 0
	for key: Vector3i in WindLayer._land:
		if key.x != lattice.level:
			continue
		var classes: PackedByteArray = WindLayer._land[key]
		for j in WindLayer.CHUNK:
			for i in WindLayer.CHUNK:
				if classes[j * WindLayer.CHUNK + i] != WindLayer.SEA:
					continue
				arrows += 1
				var geo := GeoMath.normalize(map.projection.map_to_geo(WindLayer._point_at(key.y * WindLayer.CHUNK + i, key.z * WindLayer.CHUNK + j, lattice.spacing)))
				if grid.cell_class_at_geo(geo) == NavGrid.LAND:
					on_land += 1
	t.check(arrows > 50 and on_land == 0, "[overlay] no arrow is drawn on land (%d arrows at sea, %d on land)" % [arrows, on_land])
	var before := layer.chunks_sampled
	var samples := model.sample_count
	var clock := Time.get_ticks_msec()
	await t.frames(30)
	t.check(layer.chunks_sampled == before, "[overlay] a stationary chart samples no wind for the overlay (%d chunks in 30 frames)" % (layer.chunks_sampled - before))
	print("    stationary chart, other weather readouts: %d samples in %.2f s (the boat wind readout, one per frame)" % [model.sample_count - samples, (Time.get_ticks_msec() - clock) / 1000.0])
	# A small pan inside the cached ring: no new samples.
	before = layer.chunks_sampled
	map.camera.position.x += 20.0 / map.camera.zoom.x
	await t.frames(5)
	t.check(layer.chunks_sampled == before, "[overlay] a small pan reuses cached samples")
	# A big pan samples new chunks within the frame budget.
	var worst := 0
	for i in 12:
		map.camera.position.x += 300.0 / map.camera.zoom.x
		map._clamp_camera()
		var start := Time.get_ticks_usec()
		layer._fill(WindLayer.FRAME_BUDGET_USEC)
		worst = maxi(worst, Time.get_ticks_usec() - start)
		await t.frames(1)
	print("    wind overlay: worst fill %.2f ms" % (worst / 1000.0))
	t.check(worst < WindLayer.FRAME_BUDGET_USEC + 15000, "[overlay] sampling per frame stays bounded (worst %.1f ms)" % (worst / 1000.0))
	t.check(await _complete(map), "[overlay] the panned view completes")
	# A new snapshot time keeps the old one on screen until complete.
	var shown := layer._shown
	layer.set_offset_steps(1)
	t.check(layer._shown == shown and layer._target != shown, "[overlay] the previous snapshot stays on screen while the next is sampled")
	t.check(await _complete(map) and layer._shown == layer._target, "[overlay] the new snapshot replaces it when complete")
	before = layer.chunks_sampled
	layer.set_offset_steps(0)
	await t.frames(2)
	t.check(layer.is_complete() and layer.chunks_sampled == before, "[overlay] stepping back to a cached snapshot needs no new samples")
	await t.screenshot("17_wind_regional_snapshot")
	world.set_wind_shown(true)


func _test_zoom_detail(world: WorldMap, map: MapView) -> void:
	var layer := map.wind_layer
	var notice := world.find_child("WindZoomNotice", true, false) as Control
	map.reset_view()
	await t.frames(3)
	t.check(layer.detail_hidden and notice.visible, "[zoom] the whole-world chart hides wind detail and says to zoom in")
	t.check(world.is_wind_shown(), "[zoom] the Wind switch stays on (wind has not disappeared)")
	var before := layer.chunks_sampled
	await t.frames(10)
	t.check(layer.chunks_sampled == before, "[zoom] nothing is sampled while wind detail is hidden")
	await t.screenshot("17_wind_world_notice")
	# Hysteresis: just above the hide limit stays hidden, above the show limit shows.
	map.center_on_geo(Vector2(10.0, 50.0), (WindLayer.HIDE_PX_PER_DEG + 1.0) / map.units_per_degree)
	await t.frames(2)
	t.check(layer.detail_hidden, "[zoom] hysteresis: between the limits it stays hidden")
	map.center_on_geo(Vector2(10.0, 50.0), (WindLayer.SHOW_PX_PER_DEG + 1.0) / map.units_per_degree)
	await t.frames(2)
	t.check(not layer.detail_hidden and not notice.visible, "[zoom] continental zoom shows sparse wind")
	map.center_on_geo(Vector2(10.0, 50.0), (WindLayer.HIDE_PX_PER_DEG + 1.0) / map.units_per_degree)
	await t.frames(2)
	t.check(not layer.detail_hidden, "[zoom] hysteresis: zooming out a little keeps it shown")
	# Arrow counts stay bounded at every zoom.
	for px in [14.0, 70.0, 300.0, 2000.0]:
		map.center_on_geo(Vector2(11.0, 55.5), px / map.units_per_degree)
		await t.frames(2)
		var lattice := layer._lattice()
		var points: int = (lattice.to.x - lattice.from.x) * (lattice.to.y - lattice.from.y)
		t.check(points <= WindLayer.MAX_VIEW_POINTS * 1.2, "[zoom] at %d px/deg the overlay has %d lattice points in view (bounded)" % [px, points])


func _test_time_navigator(world: WorldMap, map: MapView) -> void:
	var layer := map.wind_layer
	map.center_on_geo(Vector2(10.5, 56.5), 70.0 / map.units_per_degree)
	await _complete(map)
	var label := world.find_child("WindTimeLabel", true, false) as Label
	var note := world.find_child("WindForecastNote", true, false) as Control
	t.check(label.text.begins_with("NOW") and not note.visible, "[navigator] the chart opens on NOW (%s)" % label.text)
	var time := GameSession.get_game_time()
	var position := GameSession.get_vessel_position()
	var state_before := JSON.stringify(GameSession.get_state_snapshot().to_dict())
	var seed := GameSession.get_wind_seed()
	await t.click(world.find_child("WindNext", true, false))
	await t.frames(2)
	t.check(is_equal_approx(layer.get_snapshot_time(), (floorf(time / 1800.0) + 2.0) * 1800.0) and label.text.ends_with("(+1 h)"),
		"[navigator] one step is one hour (Iteration 18; %s)" % label.text)
	t.check((world.find_child("WindNext", true, false) as Button).text == "1 h ▶" and (world.find_child("WindPrevious", true, false) as Button).text == "◀ 1 h",
		"[navigator] the buttons say 1 h")
	for i in 8:
		await t.click(world.find_child("WindNext", true, false))
	await t.frames(2)
	t.check(layer.get_offset_steps() == WindLayer.MAX_OFFSET_STEPS and WindLayer.MAX_OFFSET_STEPS == 6, "[navigator] Next stops at +6 h")
	t.check(label.text.begins_with("FORECAST") and note.visible and (note as Label).text == "Estimated conditions. Actual wind may differ.",
		"[navigator] future snapshots are labelled FORECAST with the note (%s)" % label.text)
	t.check(is_equal_approx(layer.get_snapshot_time(), (floorf(time / 1800.0) + 12.0) * 1800.0) and label.text.ends_with("(+6 h)"),
		"[navigator] the forecast reaches 6 × 1 hour ahead (%s)" % label.text)
	t.check(await _complete(map), "[navigator] the forecast snapshot completes")
	await t.screenshot("17_wind_forecast")
	await t.screenshot("34_wind_preview_controls_1h_steps")
	for i in 16:
		await t.click(world.find_child("WindPrevious", true, false))
	await t.frames(2)
	t.check(layer.get_offset_steps() == -WindLayer.MAX_OFFSET_STEPS and label.text.begins_with("PAST MODEL SNAPSHOT") and not note.visible,
		"[navigator] Previous stops at −6 h, labelled PAST MODEL SNAPSHOT (%s)" % label.text)
	await t.click(world.find_child("WindNow", true, false))
	await t.frames(2)
	t.check(layer.get_offset_steps() == 0 and label.text.begins_with("NOW"), "[navigator] Now returns to the current time")
	var state_after := JSON.stringify(GameSession.get_state_snapshot().to_dict())
	t.check(GameSession.get_game_time() == time and GameSession.get_vessel_position() == position and GameSession.get_wind_seed() == seed
		and state_after == state_before,
		"[navigator] previewing changes nothing (time, position, seed, whole saved state)")
	# The forecast only knows weather formed by now, like every forecast.
	var model := WeatherModel.get_default()
	var geo := Vector2(10.5, 56.5)
	var future := (floorf(time / 1800.0) + 8.0) * 1800.0
	var expected := model.sample_wind(geo, future, seed, floorf(time / 1800.0) * 1800.0)
	layer.set_offset_steps(4)
	await _complete(map)
	var key := _key_of(map, geo)
	var data: PackedFloat32Array = layer._snapshots[layer._shown].get(key[0], PackedFloat32Array())
	var got := Vector2(data[key[1] * 2], data[key[1] * 2 + 1]) if not data.is_empty() else Vector2.INF
	var lattice_geo: Vector2 = key[2]
	expected = model.sample_wind(lattice_geo, future, seed, floorf(time / 1800.0) * 1800.0)
	t.check(got.is_equal_approx(expected), "[navigator] forecast arrows come from the forecast query (%s vs %s)" % [got, expected])
	# Iteration 18: every navigator time stays cached - a second sweep from
	# −6 h to +6 h samples nothing new.
	for steps in range(-WindLayer.MAX_OFFSET_STEPS, WindLayer.MAX_OFFSET_STEPS + 1):
		layer.set_offset_steps(steps)
		await _complete(map)
	var sampled := layer.chunks_sampled
	for steps in range(-WindLayer.MAX_OFFSET_STEPS, WindLayer.MAX_OFFSET_STEPS + 1):
		layer.set_offset_steps(steps)
		await _complete(map)
	t.check_eq(layer.chunks_sampled, sampled, "[navigator] all 13 snapshot times (−6 h to +6 h) stay cached")
	layer.set_offset_steps(0)
	await _complete(map)


## [chunk key, index in chunk, lattice point geo] of the lattice point nearest `geo`.
func _key_of(map: MapView, geo: Vector2) -> Array:
	var lattice := map.wind_layer._lattice()
	var spacing: float = lattice.spacing
	var at := map.projection.geo_to_map(geo)
	var ix := floori(at.x / spacing)
	var iy := floori(at.y / spacing)
	var cx := floori(ix / float(WindLayer.CHUNK))
	var cy := floori(iy / float(WindLayer.CHUNK))
	var index := (iy - cy * WindLayer.CHUNK) * WindLayer.CHUNK + ix - cx * WindLayer.CHUNK
	var point := WindLayer._point_at(ix, iy, spacing)
	return [Vector3i(lattice.level, cx, cy), index, map.projection.map_to_geo(point)]


func _test_fast_clock(map: MapView) -> void:
	var layer := map.wind_layer
	var changes := [0]
	var count := func() -> void: changes[0] += 1
	layer.snapshot_changed.connect(count)
	var start := Time.get_ticks_msec()
	var time := GameSession.get_game_time()
	# 12 game hours per real second for half a second: 12 half-hour steps.
	for i in 30:
		time += 12.0 * 3600.0 / 60.0
		layer.update_time(time)
		await t.frames(1)
	var seconds := (Time.get_ticks_msec() - start) / 1000.0
	layer.snapshot_changed.disconnect(count)
	t.check(changes[0] <= ceili(seconds / WindLayer.NOW_MIN_REAL_SECONDS) + 1,
		"[fast clock] %d Now snapshots in %.1f s of a fast clock (not one per half hour of game time)" % [changes[0], seconds])
	layer.force_snapshot(GameSession.get_game_time())


func _test_closing_stops(world: WorldMap) -> void:
	var layer := world.get_map_view().wind_layer
	var ref: WeakRef = weakref(layer)
	app.close_chart()
	await t.wait_until(func() -> bool: return not app.router.current_screen is WorldMap and not app.router.is_busy(), 10.0)
	await t.frames(3)
	var alive: WindLayer = ref.get_ref()
	t.check(alive == null or not alive.is_processing() or not alive.is_inside_tree(), "[close] closing the chart stops the wind overlay's work")
	# The sailing weather keeps working without the chart.
	var sample := Simulation.get_wind_at(GameSession.get_vessel_position())
	t.check(sample != null and sample.speed_kn >= 0.0, "[close] the sailing weather still answers with the chart closed")
