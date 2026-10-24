extends RefCounted
## Iteration 006, Checkpoint D: the chart with many harbours. Viewport
## culling, zoom-dependent markers, labels that never overlap, harbours that
## stay findable through search when their marker is hidden, a stable sidebar,
## and measured scaling (15 / 50 / 100 / all / 1,000 synthetic harbours).

const APP_SCENE := preload("res://src/app/app.tscn")

var t: Node
var app: Node
## Benchmark rows for the report: [label, harbours, ms ...].
var benchmark: Array = []


func run(runner: Node) -> void:
	t = runner
	Simulation.auto_advance = false
	t.use_calm_wind()
	app = APP_SCENE.instantiate()
	t.add_child(app)
	app.router.fade_duration = 0.05
	await _settle()
	app.start_new_game()
	await _settle()
	app.open_chart()
	await _settle()
	var world := app.router.current_screen as WorldMap
	if t.check(world != null, "(setup) the chart is open"):
		var map := world.get_node("MapView") as MapView
		await _test_wide_zoom(world, map)
		await _test_close_zoom(world, map)
		await _test_search(world, map)
		await _test_benchmarks(map)
	Simulation.auto_advance = true
	app.queue_free()
	await t.frames(2)
	GameSession.end_session()


func _settle() -> void:
	await t.frames(2)
	await t.wait_until(func() -> bool: return not app.router.is_busy(), 5.0)
	await t.physics_frames(3)


func _no_overlap(rects: Array[Rect2]) -> bool:
	for i in rects.size():
		for j in range(i + 1, rects.size()):
			if rects[i].intersects(rects[j]):
				return false
	return true


func _test_wide_zoom(world: WorldMap, map: MapView) -> void:
	map.reset_view()
	await t.frames(2)
	var catalog := PortCatalog.get_default()
	var shown := map.get_shown_port_ids()
	var minor_shown := shown.filter(func(id: StringName) -> bool: return catalog.get_port(id).importance > 1 and id != &"copenhagen")
	var majors := catalog.ports.filter(func(p: PortData) -> bool: return p.importance == 1).size()
	t.check(minor_shown.is_empty() and shown.size() >= majors - 2 and shown.size() <= majors + 1,
		"[chart] whole Europe (%.0f px/°): only the %d major harbours get a marker of %d (%d shown)" % [map.get_px_per_degree(), majors, catalog.ports.size(), shown.size()])
	var labels := map.get_port_label_rects()
	t.check(_no_overlap(labels) and labels.size() >= shown.size() / 2, "[chart] no two harbour names overlap (%d of %d named)" % [labels.size(), shown.size()])
	t.check(map.pick_port(map.get_port_screen_position(&"paros")) != &"paros", "[chart] a hidden harbour's marker cannot be clicked (Paros at wide zoom)")
	await t.screenshot("114_chart_wide_zoom")


func _test_close_zoom(world: WorldMap, map: MapView) -> void:
	var catalog := PortCatalog.get_default()
	# Regional zoom: importance 2 appears, 3 does not.
	map.center_on_geo(catalog.get_port(&"visby").get_geo_position(), 60.0 / map.units_per_degree)
	await t.frames(2)
	var shown := map.get_shown_port_ids()
	t.check(shown.has(&"visby") and shown.has(&"mariehamn") and not shown.has(&"kalmar") and not shown.has(&"naples"),
		"[chart] regional zoom (60 px/°): Visby and Mariehamn shown, small Kalmar not yet, far-away Naples culled")
	t.check(_no_overlap(map.get_port_label_rects()), "[chart] regional zoom: names do not overlap")
	# Close zoom on the Cyclades: every harbour there, nothing outside the view.
	map.center_on_geo(catalog.get_port(&"paros").get_geo_position(), 140.0 / map.units_per_degree)
	await t.frames(2)
	shown = map.get_shown_port_ids()
	var area := map.get_visible_geo_rect()
	var expected := catalog.ports_in_rect(area).map(func(p: PortData) -> StringName: return p.id)
	t.check(expected.all(func(id: StringName) -> bool: return shown.has(id)) and expected.has(&"naxos") and expected.has(&"mykonos"),
		"[chart] close zoom (140 px/°): every harbour in view has a marker (%s)" % [expected])
	var margin := area.grow(1.0)
	t.check(shown.all(func(id: StringName) -> bool: return margin.has_point(catalog.get_port(id).get_geo_position()) or id == &"copenhagen"),
		"[chart] harbours outside the view are not drawn (viewport culling): %d of %d considered" % [shown.size(), catalog.ports.size()])
	t.check(_no_overlap(map.get_port_label_rects()) and map.get_labelled_port_ids().has(&"paros"), "[chart] close zoom: names do not overlap, Paros is named")
	t.check_eq(map.pick_port(map.get_port_screen_position(&"naxos")), &"naxos", "[chart] at close zoom Naxos can be clicked")
	await t.screenshot("115_chart_close_zoom")


func _test_search(world: WorldMap, map: MapView) -> void:
	var size_before := (world.find_child("SidePanel", true, false) as Control).size
	map.reset_view()
	await t.frames(2)
	world.search_harbours("kor")
	await t.frames(2)
	var ids := world.get_search_result_ids()
	t.check(ids.has(&"korcula"), "[search ui] typing 'kor' lists Korčula (%s)" % [ids])
	await t.screenshot("116_chart_search")
	(world.find_child("Result_korcula", true, false) as Button).pressed.emit()
	await t.frames(3)
	t.check(world.get_selected_port_id() == &"korcula" and map.get_shown_port_ids().has(&"korcula") and map.get_labelled_port_ids().has(&"korcula"),
		"[search ui] choosing it selects Korčula and zooms the chart until its marker and name show")
	t.check(world.get_search_result_ids().is_empty(), "[search ui] the result list closes")
	world.plot_course_to(&"korcula")
	await t.frames(2)
	var route := world.get_draft_route()
	t.check(route != null and route.destination_port_id == &"korcula" and world.get_draft_error().is_empty(),
		"[search ui] a course to the found harbour is plotted (%.0f nm)" % (route.get_distance_nm() if route else 0.0))
	world.discard_changes()
	await t.screenshot("117_chart_search_result")
	t.check((world.find_child("SidePanel", true, false) as Control).size == size_before, "[search ui] the sidebar keeps its size")
	# Typing in the search field does not pan the chart.
	var search := world.find_child("HarbourSearch", true, false) as LineEdit
	search.grab_focus()
	var camera := map.camera.position
	await t.hold_actions([&"move_right", &"move_down"], 0.3)
	t.check(map.camera.position == camera, "[search ui] WASD while typing does not move the chart")
	search.release_focus()


## Layout cost (choosing markers and placing labels) and lookups at several
## catalogue sizes. Measured on this machine; see the report.
func _test_benchmarks(map: MapView) -> void:
	var real := PortCatalog.get_default()
	var sizes := [15, 50, 100, real.ports.size()]
	var catalogs: Array = []
	for n: int in sizes:
		var c := PortCatalog.new()
		for i in n:
			c.ports.append(real.ports[i])
		catalogs.append(["%d real" % n, c])
	var synthetic := PortCatalog.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 6
	for i in 1000:
		var p := PortData.new()
		p.id = StringName("synthetic_%d" % i)
		p.display_name = "Harbour %d" % i
		p.longitude = rng.randf_range(-24.0, 36.0)
		p.latitude = rng.randf_range(34.0, 71.0)
		p.importance = 1 if i % 20 == 0 else (2 if i % 4 == 0 else 3)
		synthetic.ports.append(p)
	catalogs.append(["1000 synthetic", synthetic])
	var views := [["whole chart", Vector2(10.0, 52.0), 0.0], ["regional", Vector2(18.0, 58.0), 60.0], ["close", Vector2(25.15, 37.08), 140.0]]
	print("    harbours        | layout whole/regional/close (ms) | shown whole/regional/close | ports_in_rect (µs) | get_port (µs)")
	var worst := 0.0
	for entry: Array in catalogs:
		var c: PortCatalog = entry[1]
		map.catalog = c
		var times := []
		var counts := []
		for view: Array in views:
			if view[2] == 0.0:
				map.reset_view()
			else:
				map.center_on_geo(view[1], view[2] / map.units_per_degree)
			var start := Time.get_ticks_usec()
			for r in 20:
				map._port_layout_key = ""
				map._update_port_layout()
			times.append((Time.get_ticks_usec() - start) / 20000.0)
			counts.append(map.get_shown_port_ids().size())
		var start := Time.get_ticks_usec()
		for r in 1000:
			c.ports_in_rect(Rect2(20.0, 35.0, 8.0, 6.0))
		var rect_us := (Time.get_ticks_usec() - start) / 1000.0
		start = Time.get_ticks_usec()
		for r in 1000:
			c.get_port(c.ports[r % c.ports.size()].id)
		var lookup_us := (Time.get_ticks_usec() - start) / 1000.0
		worst = maxf(worst, times.max())
		benchmark.append([entry[0], c.ports.size(), times, counts, rect_us, lookup_us])
		print("    %-15s | %6.2f / %6.2f / %6.2f | %4d / %4d / %4d | %8.1f | %6.2f" % [entry[0], times[0], times[1], times[2],
			counts[0], counts[1], counts[2], rect_us, lookup_us])
	# For comparison: what an unindexed list scan costs for the same lookup.
	var start := Time.get_ticks_usec()
	for r in 1000:
		var wanted: StringName = synthetic.ports[(r * 37) % 1000].id
		for p in synthetic.ports:
			if p.id == wanted:
				break
	print("    (list scan get_port on 1000 harbours, as before Iteration 006: %.2f µs)" % ((Time.get_ticks_usec() - start) / 1000.0))
	map.catalog = real
	map._port_layout_key = ""
	map.reset_view()
	t.check(worst < 50.0, "[performance] marker and label layout takes at most %.1f ms even with 1,000 harbours (measured)" % worst)
	await t.frames(2)
