extends RefCounted
## Iteration 17 (NAV): the navigation views share one chart, router,
## catalogue, boat and voyage.
## - Every cabin has a framed world map; using it opens the Dreamer's Map:
##   the whole world, harbours with their story and visited status, search,
##   and no wind or weather (nothing samples the weather for it).
## - "Imagine this voyage" plans a real route, names only real catalogue
##   harbours near it (at most three, maybe none) and changes nothing.
## - "Plan it at the chart table" opens the working chart with that harbour
##   selected; the working chart opens on the region around the boat
##   (latitude-aware, about 400 nm) and still plans courses worldwide.
## - Underway, the next turn shown is the voyage's own.

const APP_SCENE := preload("res://src/app/app.tscn")
const CABIN := SessionState.AREA_INTERIOR
const BOATS: Array[StringName] = [&"arctic_wanderer_26", &"starling_33", &"petrel_36", &"halcyon_40"]

var t: Node
var app: Node


func run(runner: Node) -> void:
	t = runner
	Simulation.auto_advance = false
	app = APP_SCENE.instantiate()
	t.add_child(app)
	app.router.fade_duration = 0.05
	await _settle()
	app.start_new_game()
	await _settle()
	await _test_every_cabin_has_a_world_map()
	var dream := await _open_dream_from_cabin()
	if t.check(dream != null and dream.mode == WorldMap.MODE_DREAM, "[dream] the cabin's world map opens the Dreamer's Map"):
		await _test_dream_map(dream)
		await _test_daydreams(dream)
		await _test_plan_at_chart_table(dream)
	await _test_station_chart()
	Simulation.auto_advance = true
	app.queue_free()
	await t.frames(2)
	GameSession.end_session()


func _settle() -> void:
	await t.frames(2)
	await t.wait_until(func() -> bool: return not app.router.is_busy(), 5.0)
	await t.physics_frames(3)


func _show(area: StringName) -> BoatArea:
	app.modals.clear()
	GameSession.enter_boat_area(area, &"start")
	app._show_current_boat_area()
	await _settle()
	return app.router.current_screen as BoatArea


func _board(id: StringName) -> void:
	var state := GameSession.get_state_snapshot()
	state.vessel_id = id
	GameSession.replace_state(state)


## Walks up to the frame (puts the captain at its station) and presses E.
func _use_world_map(cabin: BoatArea) -> bool:
	var station := cabin.find_child("WorldMap", true, false) as Interactable
	if station == null:
		return false
	cabin.player.position = station.position
	await t.physics_frames(4)
	if cabin.player.get_focused_interactable() != station:
		return false
	await t.press_action(&"interact")
	await _settle()
	return true


func _test_every_cabin_has_a_world_map() -> void:
	for id in BOATS:
		_board(id)
		var cabin := await _show(CABIN)
		var frame := cabin.find_child("WorldMapFrame", true, false) as CabinWorldMap
		var station := cabin.find_child("WorldMap", true, false) as Interactable
		t.check(frame != null and station != null and station.interaction_id == &"world_map",
			"[cabin] %s: a framed world map hangs in the cabin" % id)
		if station:
			cabin.player.position = station.position
			await t.physics_frames(4)
			t.check(cabin.player.get_focused_interactable() == station and cabin.is_valid_player_position(station.position),
				"[cabin] %s: the captain can stand at it and it is the thing in focus there" % id)
			var outline := HighlightResolver.resolve(cabin, station)
			t.check(outline.size() == 4, "[cabin] %s: the frame itself is highlighted (no circle)" % id)
	_board(&"arctic_wanderer_26")


func _open_dream_from_cabin() -> WorldMap:
	var cabin := await _show(CABIN)
	if not await _use_world_map(cabin):
		return null
	await t.wait_until(func() -> bool: return app.router.current_screen is WorldMap and not app.router.is_busy(), 10.0)
	await t.frames(3)
	return app.router.current_screen as WorldMap


func _test_dream_map(dream: WorldMap) -> void:
	var map := dream.get_map_view()
	t.check(not map.wind_layer.visible and not map.show_weather and map.get_weather_shapes().is_empty(),
		"[dream] no wind arrows and no weather areas")
	t.check(not dream.find_child("WindToggle", true, false).visible and not dream.find_child("WindLegend", true, false).visible,
		"[dream] no wind switch or legend")
	var samples := WeatherModel.get_default().sample_count
	var chunks := map.wind_layer.chunks_sampled
	for i in 30:
		map.camera.position.x += 400.0 / map.camera.zoom.x  # panning east, across the Date Line
		map._clamp_camera()
		await t.frames(1)
	var per_frame := (WeatherModel.get_default().sample_count - samples) / 30.0
	t.check(map.wind_layer.chunks_sampled == chunks and per_frame <= 1.0,
		"[dream] panning the world samples no wind field (%.1f point queries per frame: the boat's own readout)" % per_frame)
	t.check(map.is_world_land_drawn_at(map.projection.geo_to_map(Vector2(134.2, -25.3)))
		or not Rect2(Vector2.ZERO, map._free_view_size()).has_point(map.geo_to_screen(Vector2(134.2, -25.3))),
		"[dream] after panning across the Date Line the land is still drawn")
	map.reset_view()
	await t.frames(2)
	await t.screenshot("17_dream_map_world")
	# Search, select, story and visited status.
	dream.search_harbours("Papeete")
	await t.frames(1)
	t.check(&"papeete" in dream.get_search_result_ids(), "[dream] harbours can be found by name")
	dream.select_port(&"papeete")
	await t.frames(2)
	var title := (dream.find_child("SelectionTitle", true, false) as Label).text
	var details := (dream.find_child("SelectionDetails", true, false) as Label).text
	var papeete := PortCatalog.get_default().get_port(&"papeete")
	t.check(title == "%s, %s" % [papeete.display_name, papeete.country] and papeete.description.left(20) in details
		and "Not visited yet" in details, "[dream] a harbour shows its name, country, story and that it is not visited yet")
	dream.select_port(&"copenhagen")
	await t.frames(2)
	t.check("Visited" in (dream.find_child("SelectionDetails", true, false) as Label).text and
		not "Not visited" in (dream.find_child("SelectionDetails", true, false) as Label).text, "[dream] the home harbour shows as visited")


func _same_state(a: Dictionary, b: Dictionary) -> bool:
	return JSON.stringify(a) == JSON.stringify(b)


func _test_daydreams(dream: WorldMap) -> void:
	var catalog := PortCatalog.get_default()
	var before := GameSession.get_state_snapshot().to_dict()
	dream.select_port(&"papeete")
	var start := Time.get_ticks_msec()
	var result := dream.imagine_voyage(&"papeete")
	var first_ms := Time.get_ticks_msec() - start
	await t.frames(2)
	var text := dream.get_daydream_text()
	print("    daydream (Papeete, %d ms): %s" % [first_ms, text])
	t.check(result.ok and float(result.nm) > 8000.0 and "Papeete" in text, "[daydream] a real route to Papeete (%d nm)" % roundi(result.nm))
	var stops: Array[StringName] = result.stops
	var real := stops.size() <= 3 and stops.size() >= 1
	for id in stops:
		var port := catalog.get_port(id)
		real = real and port != null and port.display_name in text and id != &"papeete" and id != &"copenhagen"
	t.check(real, "[daydream] it names %d real harbours along the way (%s)" % [stops.size(), ", ".join(stops)])
	# The stops are near the route and in sailing order.
	var samples := VoyageDaydream._resample(result.path, 5.0)
	var last := -1.0
	var ordered := true
	for id in stops:
		var geo := catalog.get_port(id).get_geo_position()
		var best := INF
		var along := 0.0
		for sample in samples:
			var d := GeoMath.distance_nm(geo, Vector2(sample.x, sample.y))
			if d < best:
				best = d
				along = sample.z
		ordered = ordered and along > last and best < VoyageDaydream.NEAR_ROUTE_NM + 40.0
		last = along
	t.check(ordered, "[daydream] the harbours lie along the route, in the order they would be passed")
	start = Time.get_ticks_usec()
	var again := VoyageDaydream.imagine(&"papeete")
	t.check(again.text == result.text and Time.get_ticks_usec() - start < 2000, "[daydream] imagining it again uses the cached route")
	t.check(_same_state(GameSession.get_state_snapshot().to_dict(), before),
		"[daydream] imagining changes nothing: course, boat, clock, money, stores")
	t.check(GameSession.get_planned_route() == null or GameSession.get_planned_route().destination_port_id != &"papeete",
		"[daydream] no course was planned by it")
	await t.screenshot("17_daydream_papeete")
	# A short hop: no invented stops.
	var near := VoyageDaydream.imagine(&"helsingor")
	t.check(near.ok and (near.stops as Array).size() <= 1 and "Helsing" in near.text, "[daydream] a short hop has at most one stop (%s)" % near.text)
	var panama := VoyageDaydream.imagine(&"panama_city")
	t.check(panama.ok and "Panama" in panama.text, "[daydream] Panama City: %s" % panama.text)
	# Tones vary between destinations (a small authored set).
	var tones := {}
	for id in [&"papeete", &"panama_city", &"helsingor", &"las_palmas", &"skagen", &"helsinki"]:
		tones[VoyageDaydream.imagine(id).get("tone", "")] = true
	t.check(tones.size() >= 2, "[daydream] the tone varies between destinations (%s)" % ", ".join(tones.keys()))


func _test_plan_at_chart_table(dream: WorldMap) -> void:
	dream.select_port(&"las_palmas")
	await t.frames(1)
	await t.click(dream.find_child("PlanAtChartTableButton", true, false))
	await t.wait_until(func() -> bool:
		var map := app.router.current_screen as WorldMap
		return map != null and map != dream and not app.router.is_busy(), 10.0)
	await t.frames(3)
	var station := app.router.current_screen as WorldMap
	t.check(station != null and station.mode == WorldMap.MODE_STATION and station.get_selected_port_id() == &"las_palmas",
		"[station] 'Plan it at the chart table' opens the working chart with the harbour selected")
	if station:
		station.plot_course_to(&"las_palmas")
		var route := station.get_draft_route()
		var direct := SeaRouter.get_default().plan_route(GameSession.get_location_id(), GameSession.get_vessel_position(), [] as Array[Vector2], &"las_palmas")
		t.check(route != null and direct.is_ok() and route.path == direct.route.path, "[station] it plans with the same router: the same route")
		station.discard_changes()
		app.close_chart()
		await _settle()


func _visible_nm(station: WorldMap) -> float:
	var map := station.get_map_view()
	var free := map._free_view_size()
	var top := map.screen_to_geo(Vector2(free.x / 2.0, 0.0))
	var bottom := map.screen_to_geo(Vector2(free.x / 2.0, free.y))
	var left := map.screen_to_geo(Vector2(0.0, free.y / 2.0))
	var right := map.screen_to_geo(Vector2(free.x, free.y / 2.0))
	return minf(GeoMath.distance_nm(top, bottom), GeoMath.distance_nm(left, right))


func _test_station_chart() -> void:
	# In harbour at Copenhagen, and at Papeete (another latitude).
	for port_id in [&"copenhagen", &"papeete"]:
		var state := GameSession.get_state_snapshot()
		state.location_id = port_id
		state.vessel_position = PortCatalog.get_default().get_port(port_id).get_geo_position()
		GameSession.replace_state(state)
		await _show(CABIN)
		app.open_chart()
		await t.wait_until(func() -> bool: return app.router.current_screen is WorldMap and not app.router.is_busy(), 10.0)
		await t.frames(3)
		var station := app.router.current_screen as WorldMap
		var nm := _visible_nm(station)
		t.check(station.mode == WorldMap.MODE_STATION and nm > 300.0 and nm < 500.0,
			"[station] at %s the working chart opens on the region around the boat: %d nm across" % [port_id, roundi(nm)])
		if port_id == &"copenhagen":
			await t.screenshot("17_station_regional_copenhagen")
		app.close_chart()
		await _settle()
	# Underway: the next turn is the voyage's own.
	var home := GameSession.get_state_snapshot()
	home.location_id = &"copenhagen"
	home.vessel_position = PortCatalog.get_default().get_port(&"copenhagen").get_geo_position()
	GameSession.replace_state(home)
	t.set_wind(270.0, 14.0)
	GameSession.plan_route_to(&"las_palmas")
	GameSession.depart()
	Simulation.advance(3.0 * 3600.0)
	app.open_chart()
	await t.wait_until(func() -> bool: return app.router.current_screen is WorldMap and not app.router.is_busy(), 10.0)
	await t.frames(3)
	var chart := app.router.current_screen as WorldMap
	var turn := WorldMap.get_next_turn()
	var voyage := GameSession.get_voyage()
	var i := GeoMath.segment_index_at(voyage.get_cumulative(), voyage.progress_nm)
	t.check(not turn.is_empty() and (turn.geo as Vector2).is_equal_approx(voyage.route.path[i])
		and chart.get_map_view().next_waypoint_geo.is_equal_approx(voyage.route.path[i]),
		"[station] the next turn marked on the chart is the voyage's next route point")
	t.check(is_equal_approx(float(turn.course), Simulation.get_current_heading()), "[station] the course shown is the course being sailed")
	t.check("Steering" in (chart.find_child("CourseLabel", true, false) as Label).text, "[station] the course panel shows the course and the next turn")
	await t.wait_until(func() -> bool: return chart.get_map_view().wind_layer.is_complete(), 10.0)
	var arrows := chart.get_map_view().wind_layer.count_arrows_on_land()
	t.check(arrows.x > 50 and arrows.y == 0, "[station] wind arrows only at sea (%d arrows, %d on land)" % [arrows.x, arrows.y])
	await t.frames(3)
	var layer := chart.get_map_view().wind_layer
	var grid := SeaRouter.get_default().grid
	var drawn_on_land := 0
	for at in layer.drawn_points:
		if grid.cell_class_at_geo(GeoMath.normalize(chart.get_map_view().projection.map_to_geo(at))) == NavGrid.LAND:
			drawn_on_land += 1
	t.check(layer.drawn_points.size() > 50 and drawn_on_land == 0, "[station] arrows drawn: %d, on land: %d" % [layer.drawn_points.size(), drawn_on_land])
	await t.screenshot("17_station_underway_next_turn")
	app.close_chart()
	await _settle()
	t.use_calm_wind()
