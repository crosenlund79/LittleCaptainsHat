extends RefCounted
## Iteration 18 (MAP, finding I17-S3): a planned route stays visible while the
## world chart is panned east or west. In 0.104a the whole route was shifted
## to the world copy nearest the camera *by its first point*; a long route
## (Middelfart to Papeete spans ~160° of longitude) then vanished when the
## view was more than half a world from its start, although the copy in view
## still held most of it, and reappeared a little further on.
##
## For each route and each pan step this suite works out independently, by
## brute force over the world copies, where the route's points fall on screen,
## and checks that:
##   - the map draws a copy of the route wherever one reaches into the view;
##   - rendered: the route's colour is really on screen along it (pixels);
##   - no drawn segment jumps across the map (Date Line continuity);
##   - panning changes nothing in the route itself (waypoints, legs,
##     destination, distance), nor the vessel or the saved state.
## Routes: Middelfart to Papeete (the Captain's case), the same with several
## waypoints, Papeete to Auckland across the Date Line with a waypoint on it,
## the committed course underway, and the daydream route on the Dreamer's Map.

const APP_SCENE := preload("res://src/app/app.tscn")
## Pan steps of 15° longitude: 2.2 turns of the globe each way.
const STEPS := 53

var t: Node
var app: Node
var _rendered := false


func run(runner: Node) -> void:
	t = runner
	_rendered = DisplayServer.get_name() != "headless"
	Simulation.auto_advance = false
	app = APP_SCENE.instantiate()
	t.add_child(app)
	app.router.fade_duration = 0.05
	await _idle()
	app.start_new_game()
	await _idle()
	_moor_at(&"middelfart")
	# The Captain's case: Papeete from Middelfart on the working chart.
	var world := await _open_chart()
	if t.check(world != null, "[route wrap] (setup) the chart is open"):
		world.set_wind_shown(false)
		world.plot_course_to(&"papeete")
		await t.frames(2)
		if t.check(world.get_draft_route() != null, "[route wrap] (setup) a route to Papeete is plotted from Middelfart"):
			await _sweep_both_ways(world, "Middelfart to Papeete, whole world", 0.0)
			await _sweep_both_ways(world, "Middelfart to Papeete, regional", 8.0)
			await _screenshot_offset(world, "18_route_after_panning_west")
			# Several waypoints along the way (Atlantic, Caribbean, Pacific).
			for geo in [Vector2(-30.0, 30.0), Vector2(-75.0, 15.0), Vector2(-120.0, -5.0)]:
				var legs := world.get_draft_legs().size()
				world.insert_waypoint(legs - 1, geo)
			await t.frames(2)
			t.check(world.get_draft_waypoints().size() == 3 and world.get_draft_route() != null,
				"[route wrap] (setup) three waypoints added, the route still plots")
			await _sweep_both_ways(world, "Middelfart to Papeete with three waypoints", 0.0)
		world.discard_changes()
		await _close_chart()
	# Across the Date Line: Papeete to Auckland with a waypoint on 180°.
	_moor_at(&"papeete")
	world = await _open_chart()
	if world:
		world.set_wind_shown(false)
		world.plot_course_to(&"auckland")
		await t.frames(2)
		if t.check(world.get_draft_route() != null, "[route wrap] (setup) a route to Auckland is plotted from Papeete"):
			await _sweep_both_ways(world, "Papeete to Auckland across the Date Line", 0.0)
			world.insert_waypoint(0, Vector2(179.9, -27.0))
			await t.frames(2)
			t.check(world.get_draft_route() != null, "[route wrap] (setup) a waypoint on the Date Line keeps the route valid")
			await _sweep_both_ways(world, "Papeete to Auckland, waypoint on the Date Line", 0.0)
			await _sweep_both_ways(world, "Papeete to Auckland, regional", 14.0)
			# The committed course, underway: the solid course line.
			t.check(world.apply_course() == "", "[route wrap] (setup) the course is set")
		await _close_chart()
		t.set_wind(90.0, 12.0)
		GameSession.depart()
		Simulation.advance(3600.0)
		world = await _open_chart()
		if world:
			world.set_wind_shown(false)
			await _sweep_both_ways(world, "underway Papeete to Auckland (course line)", 0.0)
			await _close_chart()
	# The Dreamer's Map: the daydream's dashed route.
	app.modals.clear()
	_moor_at(&"middelfart")
	app.open_dream_map()
	await t.wait_until(func() -> bool: return app.router.current_screen is WorldMap and not app.router.is_busy(), 10.0)
	var dream := app.router.current_screen as WorldMap
	if t.check(dream != null, "[route wrap] (setup) the Dreamer's Map is open"):
		dream.select_port(&"papeete")
		dream.imagine_voyage(&"papeete")
		await t.frames(2)
		await _sweep_both_ways(dream, "Dreamer's Map, daydream to Papeete", 0.0)
		dream.discard_changes()
		app.close_chart()
		await _idle()
	Simulation.auto_advance = true
	app.queue_free()
	await t.frames(2)
	GameSession.end_session()
	t.use_calm_wind()


func _idle() -> void:
	await t.frames(2)
	await t.wait_until(func() -> bool: return not app.router.is_busy(), 5.0)
	await t.frames(2)


func _moor_at(port_id: StringName) -> void:
	var state := GameSession.get_state_snapshot()
	state.location_id = port_id
	state.vessel_status = SessionState.STATUS_MOORED
	state.vessel_position = PortCatalog.get_default().get_port(port_id).get_geo_position()
	state.voyage = null
	state.planned_route = null
	GameSession.replace_state(state)


func _open_chart() -> WorldMap:
	app.modals.clear()
	app.open_chart()
	await t.wait_until(func() -> bool: return app.router.current_screen is WorldMap and not app.router.is_busy(), 10.0)
	await t.frames(2)
	return app.router.current_screen as WorldMap


func _close_chart() -> void:
	var world := app.router.current_screen as WorldMap
	if world:
		world.discard_changes()
		app.close_chart()
	await _idle()


## The geographic paths the map should be showing (draft legs, course line).
func _paths(map: MapView) -> Array[PackedVector2Array]:
	var paths: Array[PackedVector2Array] = []
	for leg in map.draft_legs:
		if leg.path.size() >= 2:
			paths.append(leg.path)
	if map.active_path.size() >= 2:
		paths.append(map.active_path)
	return paths


## Everything panning must leave alone.
func _route_fingerprint(world: WorldMap) -> String:
	var route := world.get_draft_route()
	return "%s|%s|%s|%.3f|%s|%s|%s" % [world.get_draft_waypoints(), world.get_draft_legs().size(),
		route.destination_port_id if route else &"", route.get_distance_nm() if route else -1.0,
		GameSession.get_vessel_position(), GameSession.get_voyage_destination_id(), GameSession.has_unsaved_changes()]


func _sweep_both_ways(world: WorldMap, label: String, px_per_degree: float) -> void:
	for direction in [-1.0, 1.0]:
		await _sweep(world, "%s, panning %s" % [label, "west" if direction < 0.0 else "east"], px_per_degree, direction)


func _sweep(world: WorldMap, label: String, px_per_degree: float, direction: float) -> void:
	var map := world.get_map_view()
	var paths := _paths(map)
	if not t.check(not paths.is_empty(), "[route wrap] %s: a route is shown" % label):
		return
	if px_per_degree <= 0.0:
		map.reset_view()
	else:
		map.center_on_geo(paths[0][0], px_per_degree / map.units_per_degree)
	await t.frames(2)
	var before := _route_fingerprint(world)
	var free := Rect2(Vector2.ZERO, map._free_view_size()).grow(-12.0)
	var expected_steps := 0
	var missing := PackedStringArray()
	var jumps := 0
	var pixel_checked := 0
	var pixel_missing := PackedStringArray()
	for step in STEPS:
		map.camera.position.x += direction * 15.0 * map.units_per_degree
		map._clamp_camera()
		await t.frames(1)
		var image: Image = null
		if _rendered:
			await RenderingServer.frame_post_draw
			image = map.get_viewport().get_texture().get_image()
		for path in paths:
			var on_screen := _expected_screen_samples(map, path, free)
			if on_screen.is_empty():
				continue
			expected_steps += 1
			# The map must draw a copy that covers these points.
			var drawn := map._path_copies(path)
			var covered := 0
			for sample in on_screen:
				for copy in drawn:
					if _near_polyline(map, copy, sample, 3.0):
						covered += 1
						break
			if covered < on_screen.size():
				missing.append("step %d (%d of %d points drawn)" % [step, covered, on_screen.size()])
			for copy in drawn:
				for i in range(1, copy.size()):
					if absf(copy[i].x - copy[i - 1].x) > map._world_width / 2.0:
						jumps += 1
			if image and on_screen.size() >= 6:
				pixel_checked += 1
				var hits := 0
				# The window may show the viewport scaled (stretch mode).
				var scale := Vector2(image.get_size()) / map.get_viewport().get_visible_rect().size
				for sample in on_screen:
					if _route_colour_near(image, sample * scale):
						hits += 1
				if hits < on_screen.size() * 0.4:
					pixel_missing.append("step %d (%d of %d)" % [step, hits, on_screen.size()])
	t.check(expected_steps > 0, "[route wrap] %s: the route came into view during the sweep (%d times)" % [label, expected_steps])
	t.check(missing.is_empty(), "[route wrap] %s: drawn wherever it is in view%s" % [label,
		"" if missing.is_empty() else ": missing at " + ", ".join(missing.slice(0, 4))])
	t.check(jumps == 0, "[route wrap] %s: no segment jumps across the map (%d)" % [label, jumps])
	if _rendered:
		t.check(pixel_checked > 0 and pixel_missing.is_empty(), "[route wrap] %s: rendered, the route's colour is on screen along it (%d steps)%s" % [
			label, pixel_checked, "" if pixel_missing.is_empty() else ": not at " + ", ".join(pixel_missing.slice(0, 4))])
	t.check_eq(_route_fingerprint(world), before, "[route wrap] %s: panning changed nothing in the route, voyage or vessel" % label)


## Screen points every ~10 px along every world copy of `path` inside `free`
## (brute force over copies: independent of the map's own choice of copies).
func _expected_screen_samples(map: MapView, path: PackedVector2Array, free: Rect2) -> PackedVector2Array:
	var base := map.projection.geo_polygon_to_map(GeoMath.unwrap_path(path))
	var result := PackedVector2Array()
	for k in range(-3, 4):
		var dx := k * map._world_width
		for i in range(1, base.size()):
			var a := map.map_to_screen(base[i - 1] + Vector2(dx, 0.0))
			var b := map.map_to_screen(base[i] + Vector2(dx, 0.0))
			var count := maxi(int(a.distance_to(b) / 10.0), 1)
			for j in count:
				var p := a.lerp(b, float(j) / count)
				if free.has_point(p):
					result.append(p)
	return result


func _near_polyline(map: MapView, points: PackedVector2Array, screen_point: Vector2, tolerance: float) -> bool:
	for i in range(1, points.size()):
		var a := map.map_to_screen(points[i - 1])
		var b := map.map_to_screen(points[i])
		if Geometry2D.get_closest_point_to_segment(screen_point, a, b).distance_to(screen_point) <= tolerance:
			return true
	return false


## The route's colours (brass course, seafoam proposal) within a few pixels
## (dashes leave gaps; labels and markers may cover a little).
func _route_colour_near(image: Image, at: Vector2) -> bool:
	for dy in range(-6, 7, 2):
		for dx in range(-6, 7, 2):
			var x := int(at.x) + dx
			var y := int(at.y) + dy
			if x < 0 or y < 0 or x >= image.get_width() or y >= image.get_height():
				continue
			var c := image.get_pixel(x, y)
			for colour in [MapView.BRASS, MapView.SEAFOAM]:
				if absf(c.r - colour.r) + absf(c.g - colour.g) + absf(c.b - colour.b) < 0.18:
					return true
	return false


## Rendered evidence: the Captain's view, panned west of the route's start
## (where 0.104a showed no route).
func _screenshot_offset(world: WorldMap, file_name: String) -> void:
	var map := world.get_map_view()
	map.reset_view()
	map.camera.position.x = map.projection.geo_to_map(Vector2(-178.0, 0.0)).x
	map._clamp_camera()
	await t.frames(3)
	await t.screenshot(file_name)
