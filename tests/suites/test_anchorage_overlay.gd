extends RefCounted
## Revision 0.105b (ZONE, WAYPOINT): the chart's anchorage highlights.
##   - nothing is worked out when the chart opens or at world zoom, even
##     switched on (no global scan); a note says to zoom in;
##   - zoomed in on a coast, only the tiles in view are worked out, within a
##     per-frame budget, and kept: panning away and back costs nothing;
##   - teal (normal anchor) and amber (Magic Anchor) both appear; the overlay
##     agrees with the waypoint rule at every evaluated cell;
##   - across the Date Line the tiles on both sides are there;
##   - hovering explains (depth with "GAME ESTIMATE", shelter in this wind);
##   - a waypoint in teal becomes an anchorage; in amber it needs the Magic
##     Anchor (refused with the reason and a nearby spot offered without it,
##     accepted and drawn amber with it); dragged onto land it is flagged;
##     zooming out keeps the planned anchorage.

const APP_SCENE := preload("res://src/app/app.tscn")

var t: Node
var app: Node
var world: WorldMap
var map: MapView
var layer: AnchorageLayer


func run(runner: Node) -> void:
	t = runner
	Simulation.auto_advance = false
	app = APP_SCENE.instantiate()
	t.add_child(app)
	app.router.fade_duration = 0.05
	await _settle()
	app.start_new_game()
	await _settle()
	t.set_wind(90.0, 12.0)
	app.open_chart()
	await t.wait_until(func() -> bool: return app.router.current_screen is WorldMap and not app.router.is_busy(), 10.0)
	world = app.router.current_screen as WorldMap
	if t.check(world != null, "(setup) the chart is open"):
		map = world.get_map_view()
		layer = map.anchorage_layer
		world.set_wind_shown(false)
		await _test_zoom_gate()
		await _test_tiles()
		await _test_date_line()
		await _test_waypoints()
	app.close_chart()
	await _settle()
	Simulation.auto_advance = true
	app.queue_free()
	await t.frames(2)
	GameSession.end_session()
	t.use_calm_wind()


func _settle() -> void:
	await t.frames(2)
	await t.wait_until(func() -> bool: return not app.router.is_busy(), 5.0)


func _show_at(geo: Vector2, px_per_degree: float) -> void:
	map.center_on_geo(geo, px_per_degree / map.units_per_degree)
	await t.frames(2)
	layer.refresh_view()


func _test_zoom_gate() -> void:
	t.check(not layer.shown and layer.tiles_computed == 0, "[zone] the chart opens without working out any anchorage")
	map.reset_view()  # the whole world
	await t.frames(2)
	world.set_anchorages_shown(true)
	for i in 30:
		await t.frames(1)
	t.check(not layer.is_active() and layer.tiles_computed == 0 and not layer.visible,
		"[zone] at world zoom, even switched on: nothing worked out, nothing drawn")
	var note := world.find_child("AnchorageNote", true, false) as Label
	t.check(note != null and note.text.contains("Zoom in"), "[zone] the legend says to zoom in (%s)" % (note.text if note else ""))
	await t.screenshot("rb_01_world_zoom_no_anchorage_overlay")


func _test_tiles() -> void:
	# Antigua and its neighbours.
	await _show_at(Vector2(-61.80, 17.05), 1600.0)
	var wanted := layer._wanted.size()
	var started := Time.get_ticks_msec()
	var worst := 0
	while not layer.is_complete() and Time.get_ticks_msec() - started < 60000:
		var frame := Time.get_ticks_usec()
		await t.frames(1)
		worst = maxi(worst, Time.get_ticks_usec() - frame)
	t.check(layer.is_complete() and layer.tiles_computed <= wanted and wanted <= 12,
		"[zone] zoomed in: only the %d tiles in view are worked out (%d), in %.1f s" % [wanted, layer.tiles_computed, (Time.get_ticks_msec() - started) / 1000.0])
	print("    anchorage overlay: worst whole frame while filling %.1f ms (rendering included); the layer's own work at most %.1f ms a frame; last tile %.0f ms of work, by stage %s us, longest single step per stage %s us" % [
		worst / 1000.0, layer.max_frame_usec / 1000.0, layer.last_tile_usec / 1000.0, layer.last_stage_usec, layer.max_step_usec])
	var samples := Array(layer.frame_usec)
	samples.sort()
	var p95: int = samples[int(samples.size() * 0.95)] if not samples.is_empty() else 0
	t.check(p95 <= AnchorageLayer.FRAME_BUDGET_USEC + 1500 and layer.max_frame_usec < 12000,
		"[zone] filling stays within its frame budget: %.1f ms of work in 95%% of %d busy frames (budget %.0f ms), %.1f ms at most" % [
			p95 / 1000.0, samples.size(), AnchorageLayer.FRAME_BUDGET_USEC / 1000.0, layer.max_frame_usec / 1000.0])
	# Teal and amber; agreement with the waypoint rule.
	var normal := 0
	var magic := 0
	var checked := 0
	var disagree := []
	var coast := CoastalGeography.get_default()
	var rect := map.get_visible_geo_rect()
	var rng := RandomNumberGenerator.new()
	rng.seed = 18
	for i in 400:
		var geo := Vector2(rng.randf_range(rect.position.x, rect.end.x), rng.randf_range(rect.position.y, rect.end.y))
		# The overlay cell's centre (where it evaluates).
		var cell := coast.cell_of(geo)
		cell = Vector2i(cell.x - cell.x % AnchorageLayer.STEP + AnchorageLayer.STEP / 2, cell.y - cell.y % AnchorageLayer.STEP + AnchorageLayer.STEP / 2)
		var centre := coast.cell_center(cell)
		var c := layer.class_at(centre)
		if c < 0:
			continue
		normal += 1 if c == AnchorageLayer.NORMAL else 0
		magic += 1 if c == AnchorageLayer.MAGIC else 0
		if c == 0 and not coast.is_water(centre):
			continue  # land: trivially agrees
		checked += 1
		var spot := GameSession.anchorage_spot(centre, true)
		var expected := 0
		if spot.ok:
			expected = AnchorageLayer.NORMAL if spot.kind == AnchorSite.KIND_NORMAL else (AnchorageLayer.MAGIC if float(spot.land_nm) < AnchorSite.COASTAL_NM else 0)
		if expected != c:
			disagree.append("%s overlay %d rule %d (%s)" % [GeoMath.format_position(centre), c, expected, spot.reason])
	t.check(normal > 0 and magic > 0, "[zone] teal (%d) and amber (%d) cells both appear around Antigua" % [normal, magic])
	t.check(checked >= 40 and disagree.is_empty(), "[zone] the overlay agrees with the waypoint rule at %d water cells %s" % [checked, disagree.slice(0, 3)])
	await t.frames(3)
	await t.screenshot("rb_02_coast_normal_and_magic_regions")
	# Hover explains.
	var teal := _find_class(AnchorageLayer.NORMAL)
	var amber := _find_class(AnchorageLayer.MAGIC)
	if teal != Vector2.INF:
		var text := world.inspect_anchorage(teal)
		t.check(text.begins_with("Suitable for ordinary anchoring") and text.contains("GAME ESTIMATE") and text.contains("wind"),
			"[zone] hover on teal: %s" % text)
		await t.frames(2)
		await t.screenshot("rb_05_depth_tooltip_ordinary")
	if amber != Vector2.INF:
		var text := world.inspect_anchorage(amber)
		t.check(text.contains("Magic Anchor required") and text.contains("GAME ESTIMATE"), "[zone] hover on amber: %s" % text)
		await t.frames(2)
		await t.screenshot("rb_03_deep_coast_magic_anchor_zone")
		await t.screenshot("rb_06_game_estimate_depth_tooltip")
	var land_text := world.inspect_anchorage(Vector2(-61.80, 17.08))
	t.check(land_text.begins_with("Land"), "[zone] hover on land: %s" % land_text)
	await t.frames(2)
	await t.screenshot("rb_04_invalid_land_area")
	# Panning away and back reuses the tiles.
	var computed := layer.tiles_computed
	await _show_at(Vector2(-61.0, 17.6), 1600.0)
	await t.wait_until(func() -> bool: return layer.is_complete(), 60.0)
	var after_away := layer.tiles_computed
	await _show_at(Vector2(-61.80, 17.05), 1600.0)
	for i in 10:
		await t.frames(1)
	t.check(layer.is_complete() and layer.tiles_computed == after_away and after_away >= computed,
		"[zone] back over Antigua: the kept tiles are reused (no new work)")
	t.check(layer.get_tile_count() <= AnchorageLayer.MAX_TILES, "[zone] the cache is bounded (%d tiles, at most %d)" % [layer.get_tile_count(), AnchorageLayer.MAX_TILES])


func _find_class(c: int) -> Vector2:
	var coast := CoastalGeography.get_default()
	var rect := map.get_visible_geo_rect()
	for y in 80:
		for x in 120:
			var geo := Vector2(lerpf(rect.position.x, rect.end.x, (x + 0.5) / 120.0), lerpf(rect.position.y, rect.end.y, (y + 0.5) / 80.0))
			var cell := coast.cell_of(geo)
			cell = Vector2i(cell.x - cell.x % AnchorageLayer.STEP + AnchorageLayer.STEP / 2, cell.y - cell.y % AnchorageLayer.STEP + AnchorageLayer.STEP / 2)
			if layer.class_at(coast.cell_center(cell)) == c:
				return coast.cell_center(cell)
	return Vector2.INF


func _test_date_line() -> void:
	# Fiji's Taveuni and its neighbours straddle 180 degrees.
	await _show_at(Vector2(180.0, -16.8), 900.0)
	layer.complete_now()
	await t.frames(2)
	var east := false
	var west := false
	for key in layer._wanted:
		east = east or key.x == 0  # 180W..179W
		west = west or key.x == 359  # 179E..180E
	t.check(east and west and layer.is_complete(), "[zone] across the Date Line the tiles on both sides are worked out")


func _test_waypoints() -> void:
	await _show_at(Vector2(-61.80, 17.05), 1600.0)
	await t.wait_until(func() -> bool: return layer.is_complete(), 60.0)
	var teal := _find_class(AnchorageLayer.NORMAL)
	var amber := _find_class(AnchorageLayer.MAGIC)
	if not t.check(teal != Vector2.INF and amber != Vector2.INF, "(setup) teal and amber spots in view"):
		return
	world.plot_course_to(&"falmouth_antigua")
	await t.frames(1)
	if world.get_draft_route() == null:
		# Moored in Copenhagen: plot a course to Antigua's harbour anyway (long).
		pass
	var legs := world.get_draft_legs().size()
	var index := world.insert_waypoint(maxi(legs - 1, 0), teal)
	var reason := world.toggle_anchorage(index)
	t.check(world.is_anchorage(index) and reason == "", "[waypoint] a waypoint in teal becomes a normal anchorage")
	await t.frames(2)
	await t.screenshot("rb_07_anchorage_waypoint_in_valid_region")
	# Amber without the Magic Anchor: refused, with the reason and a nearby spot.
	var amber_index := world.insert_waypoint(maxi(world.get_draft_legs().size() - 1, 0), amber)
	var refused := world.toggle_anchorage(amber_index)
	t.check(not world.is_anchorage(amber_index) and refused.contains("Magic Anchor") and world.get_anchorage_suggestion() != Vector2.INF,
		"[waypoint] amber without the Magic Anchor: refused (%s), a nearby normal spot offered" % refused)
	# With it: accepted, drawn amber.
	GameSession.fit_magic_anchor()
	world._spot_cache.clear()
	var accepted := world.toggle_anchorage(amber_index)
	await t.frames(2)
	t.check(world.is_anchorage(amber_index) and accepted == "" and amber_index < map.anchorage_magic.size() and map.anchorage_magic[amber_index],
		"[waypoint] with the Magic Anchor aboard the amber spot is an anchorage, drawn amber")
	# Dragged onto land: flagged and explained.
	map.waypoint_dragged.emit(amber_index, Vector2(-61.80, 17.08))
	await t.frames(20)
	t.check(amber_index in map.invalid_waypoints, "[waypoint] dragged onto land: the anchorage is flagged")
	await t.screenshot("rb_08_invalid_anchorage_placement")
	map.waypoint_dragged.emit(amber_index, amber)
	await t.frames(20)
	# Zooming out keeps the planned anchorages.
	map.reset_view()
	await t.frames(3)
	t.check(world.is_anchorage(index) and world.is_anchorage(amber_index) and world.get_draft_waypoints()[index] == teal,
		"[waypoint] zoomed out to the whole world, the anchorages and their places are kept")
