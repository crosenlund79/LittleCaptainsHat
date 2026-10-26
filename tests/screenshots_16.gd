extends Node
## Iteration 16: renders the twenty review screenshots of The World Awaits
## into docs/screenshots/iteration16/ (run rendered, e.g. under Xvfb):
##   godot --path . --resolution 1600x900 res://tests/screenshots_16.tscn
## Uses the test save folder; never touches the player's saves.

const APP_SCENE := preload("res://src/app/app.tscn")
const OUT := "res://docs/screenshots/iteration16"

var app: Node


func _ready() -> void:
	SaveManager.save_dir = "user://test_saves"
	SessionLog.log_dir = "user://test_diagnostics"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_run.call_deferred()


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _shot(file_name: String) -> void:
	await _frames(6)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT.path_join(file_name + ".png")))
	print("shot ", file_name)


func _idle() -> void:
	var guard := 0
	while app.router.is_busy() and guard < 2000:
		guard += 1
		await get_tree().process_frame
	await _frames(3)


func _chart() -> WorldMap:
	app.modals.clear()
	app.open_chart()
	var guard := 0
	while (not (app.router.current_screen is WorldMap) or app.router.is_busy()) and guard < 2000:
		guard += 1
		await get_tree().process_frame
	await _frames(4)
	return app.router.current_screen as WorldMap


func _close_chart() -> void:
	(app.router.current_screen as WorldMap).discard_changes()
	app.close_chart()
	var guard := 0
	while (app.router.current_screen is WorldMap or app.router.is_busy()) and guard < 2000:
		guard += 1
		await get_tree().process_frame
	await _frames(4)


## Puts the boat in harbour at `port_id` (a fixture: the voyages themselves
## are sailed in tests/suites/test_world_voyage.gd).
func _moor_at(port_id: StringName) -> void:
	var state := GameSession.get_state_snapshot()
	state.location_id = port_id
	state.vessel_position = PortCatalog.get_default().get_port(port_id).get_geo_position()
	GameSession.replace_state(state)


func _frame_route(map: MapView, route: PlannedRoute) -> void:
	if route:
		map.frame_geo_points(route.path)


func _run() -> void:
	Simulation.auto_advance = false
	app = APP_SCENE.instantiate()
	add_child(app)
	app.router.fade_duration = 0.05
	await _frames(5)
	app.start_new_game()
	await _idle()
	var state := GameSession.get_state_snapshot()
	state.wind_seed = 16
	state.funds = 20000
	GameSession.replace_state(state)
	GameSession.buy_provisions(GameSession.get_passage_store_days())

	var world := await _chart()
	var map := world.get_map_view()
	map.reset_view()
	await _shot("01_global_chart")
	map.center_on_geo(Vector2(8.0, 50.0), 8.0 / map.units_per_degree)
	await _shot("02_europe_on_world_chart")
	map.center_on_geo(Vector2(11.5, 56.0), 70.0 / map.units_per_degree)
	await _shot("03_denmark_regional")
	map.center_on_geo(Vector2(10.75, 55.15), 420.0 / map.units_per_degree)
	await _shot("04_danish_coast_detail")
	map.center_on_geo(Vector2(-38.0, 40.0), 11.0 / map.units_per_degree)
	await _shot("05_north_atlantic")
	map.center_on_geo(Vector2(-68.0, 16.0), 34.0 / map.units_per_degree)
	await _shot("06_caribbean")
	map.center_on_geo(Vector2(-165.0, -18.0), 10.0 / map.units_per_degree)
	await _shot("07_south_pacific")
	# Zoom from world to regional (three steps, combined below).
	for step: Array in [["19a", 4.0], ["19b", 12.0], ["19c", 60.0]]:
		map.center_on_geo(Vector2(10.0, 54.0), float(step[1]) / map.units_per_degree)
		await _shot("19_zoom_" + step[0])
	world.select_port(&"papeete")
	map.center_on_geo(Vector2(-149.6, -17.3), 60.0 / map.units_per_degree)
	await _shot("08_french_polynesia_papeete")
	world.select_port(&"auckland")
	map.center_on_geo(Vector2(174.8, -38.5), 30.0 / map.units_per_degree)
	await _shot("09_new_zealand_auckland")
	# Europe to the Atlantic.
	world.select_port(&"las_palmas")
	world.plot_course_to(&"las_palmas")
	await _frames(3)
	_frame_route(map, world.get_draft_route())
	map.zoom_by(0.85)
	await _shot("12_route_europe_to_atlantic")
	await _close_chart()

	# Readiness before the longest leg, with only the everyday stores aboard.
	_moor_at(&"puerto_ayora")
	GameSession.set_provisions_for_testing(Provisions.CAPACITY_DAYS)
	world = await _chart()
	map = world.get_map_view()
	world.select_port(&"taiohae")
	world.plot_course_to(&"taiohae")
	await _frames(3)
	_frame_route(map, world.get_draft_route())
	map.zoom_by(0.8)
	await _shot("14_readiness_long_voyage")
	await _close_chart()
	GameSession.set_provisions_for_testing(GameSession.get_passage_store_days())

	# Around a landmass: Castries to Nassau around the Greater Antilles.
	_moor_at(&"castries")
	world = await _chart()
	map = world.get_map_view()
	world.plot_course_to(&"nassau")
	await _frames(3)
	_frame_route(map, world.get_draft_route())
	await _shot("10_route_around_a_landmass")
	await _close_chart()
	# The Date Line.
	_moor_at(&"suva")
	world = await _chart()
	map = world.get_map_view()
	world.plot_course_to(&"avarua")
	await _frames(3)
	_frame_route(map, world.get_draft_route())
	await _shot("11_dateline_route")
	await _close_chart()
	# A course by way of an intermediate harbour: Las Palmas to Castries past Mindelo.
	_moor_at(&"las_palmas")
	world = await _chart()
	map = world.get_map_view()
	world.plot_course_to(&"castries")
	await _frames(2)
	world.insert_waypoint(0, Vector2(-25.3, 16.6))
	await _frames(3)
	_frame_route(map, world.get_draft_route())
	await _shot("16_route_with_intermediate_harbour")
	await _close_chart()

	# Underway in the ocean: Long Passage on deck.
	GameSession.plan_route_to(&"castries")
	GameSession.depart()
	Simulation.advance(9.0 * 86400.0)
	GameSession.enter_boat_area(SessionState.AREA_EXTERIOR, &"start")
	app._show_current_boat_area()
	await _idle()
	await _shot("15_underway_ocean_passage")
	var panel := (app.hud as Hud).passage_panel
	(panel.find_child("Rate1", true, false) as Button).pressed.emit()
	Simulation.auto_advance = true  # let Long Passage time run for a moment
	await _frames(40)
	await _shot("13_long_passage_ui")
	Simulation.auto_advance = false
	(panel.find_child("Save", true, false) as Button).pressed.emit()
	await _frames(4)
	await _shot("20_save_during_long_passage")
	app.modals.clear()
	Simulation.stop_passage()

	# Finish the crossing to Castries first (a fixture), then the last leg in
	# French Polynesia: arrival in Papeete, moored, and Go Ashore there.
	var crossing := 0
	while GameSession.is_underway() and crossing < 4000:
		crossing += 1
		Simulation.advance(3600.0, true)
	_moor_at(&"taiohae")
	GameSession.plan_route_to(&"papeete")
	GameSession.depart()
	var guard := 0
	while GameSession.is_underway() and guard < 2000:
		guard += 1
		Simulation.advance(3600.0, true)
	GameSession.enter_boat_area(SessionState.AREA_EXTERIOR, &"from_boatyard")
	app._show_current_boat_area()
	await _idle()
	await _frames(30)
	await _shot("17_arrival_papeete")
	app.open_go_ashore()
	await _frames(6)
	await _shot("18_go_ashore_papeete")
	app.modals.clear()
	_combine_zoom()
	get_tree().quit(0)


## Screenshot 19: the three zoom steps side by side.
func _combine_zoom() -> void:
	var parts: Array[Image] = []
	for step in ["19a", "19b", "19c"]:
		var image := Image.load_from_file(ProjectSettings.globalize_path(OUT.path_join("19_zoom_%s.png" % step)))
		if image == null:
			return
		image.resize(image.get_width() / 3, image.get_height() / 3)
		parts.append(image)
	var combined := Image.create(parts[0].get_width() * 3 + 16, parts[0].get_height(), false, parts[0].get_format())
	combined.fill(Color("#10232c"))
	for i in 3:
		combined.blit_rect(parts[i], Rect2i(Vector2i.ZERO, parts[i].get_size()), Vector2i(i * (parts[0].get_width() + 8), 0))
	combined.save_png(ProjectSettings.globalize_path(OUT.path_join("19_zoom_world_to_regional.png")))
	for step in ["19a", "19b", "19c"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(OUT.path_join("19_zoom_%s.png" % step)))
