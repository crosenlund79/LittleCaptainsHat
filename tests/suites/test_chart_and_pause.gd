extends RefCounted
## I003b UI hotfix: the chart's tabbed sidebar (fixed header, Course /
## Weather / Details tabs, fixed footer) and the shared simulation Pause
## (cabin, deck and chart), through the real application.

const APP_SCENE := preload("res://src/app/app.tscn")

var t: Node
var app: Node


func run(runner: Node) -> void:
	t = runner
	app = APP_SCENE.instantiate()
	t.add_child(app)
	app.router.fade_duration = 0.05
	await _settle()
	Simulation.auto_advance = false
	app.start_new_game()
	await _settle()

	await _test_sidebar_structure()
	await _test_route_editing_and_tabs()
	await _test_map_controls()
	await _test_pause_everywhere()
	await _test_pause_and_sleep()
	await _test_pause_persistence()

	Simulation.auto_advance = true
	app.queue_free()
	await t.frames(2)
	GameSession.end_session()
	t.use_calm_wind()


# --- Sidebar -------------------------------------------------------------------------------

func _rect(map: WorldMap, control_name: String) -> Rect2:
	var control := map.find_child(control_name, true, false) as Control
	return control.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, control.size)


func _fixed_parts(map: WorldMap) -> Dictionary:
	var parts := {}
	for control_name in ["SidePanel", "Header", "Tabs", "Footer", "Title", "ApplyButton", "DiscardButton",
			"SetSailButton", "SleepButton", "BackButton"]:
		parts[control_name] = _rect(map, control_name)
	return parts


func _difference(a: Dictionary, b: Dictionary) -> String:
	for key: String in a:
		var r1: Rect2 = a[key]
		var r2: Rect2 = b[key]
		if r1.position.distance_to(r2.position) > 0.5 or r1.size.distance_to(r2.size) > 0.5:
			return "%s: %s -> %s" % [key, r1, r2]
	return ""


func _check_layout(map: WorldMap, label: String) -> void:
	var screen := Rect2(Vector2.ZERO, t.get_viewport().get_visible_rect().size)
	var panel := _rect(map, "SidePanel")
	var title := map.find_child("Title", true, false) as Label
	var title_rect := _rect(map, "Title")
	t.check(screen.encloses(panel.grow(-1.0)), "[sidebar] %s: the whole sidebar is on screen" % label)
	t.check(panel.encloses(title_rect) and title.size.y >= title.get_minimum_size().y - 0.5 and title.text == "Chart",
		"[sidebar] %s: the Chart title is fully visible" % label)
	var header := _rect(map, "Header")
	var tabs := _rect(map, "Tabs")
	var footer := _rect(map, "Footer")
	t.check(header.end.y <= tabs.position.y + 0.5 and tabs.end.y <= footer.position.y + 0.5 and panel.encloses(footer),
		"[sidebar] %s: header, tabs and footer are stacked without overlapping" % label)
	var footer_ok := true
	for control_name in ["ApplyButton", "SetSailButton", "SleepButton", "BackButton"]:
		footer_ok = footer_ok and panel.encloses(_rect(map, control_name)) and (map.find_child(control_name, true, false) as Control).is_visible_in_tree()
	t.check(footer_ok, "[sidebar] %s: Apply, Set sail, Sleep and Back are visible in the footer" % label)


func _test_sidebar_structure() -> void:
	app.open_chart()
	await _settle()
	var map := app.router.current_screen as WorldMap
	if not t.check(map != null, "(setup) the chart is open"):
		return
	await _refresh(map)
	_check_layout(map, "1920×1080, 100%")
	t.check(map.find_child("TimeControls", true, false) == null, "[sidebar] no second set of time controls in the sidebar")
	t.check(app.hud.find_child("Pause", true, false).is_visible_in_tree() and app.hud.find_child("Speed20", true, false).is_visible_in_tree(),
		"[controls] the shared time bar (Pause, 1×, 5×, 20×) is shown on the chart")
	var clock_rect: Rect2 = (app.hud.get_node("ClockPanel") as Control).get_global_transform_with_canvas() * \
		Rect2(Vector2.ZERO, (app.hud.get_node("ClockPanel") as Control).size)
	t.check(not clock_rect.intersects(_rect(map, "SidePanel")), "[controls] the time bar sits over the map, clear of the sidebar")
	for control_name in ["ZoomInButton", "ZoomOutButton", "ResetViewButton", "CenterBoatButton", "WindToggle"]:
		var control := map.find_child(control_name, true, false) as Control
		t.check(control.is_visible_in_tree() and not _rect(map, control_name).intersects(_rect(map, "SidePanel")),
			"[controls] %s is on the map, not in the sidebar" % control_name)
	await t.screenshot("33_chart_sidebar_course")

	# The same size on every tab, and Sleep reachable from each.
	var reference := _fixed_parts(map)
	for tab in [WorldMap.TAB_WEATHER, WorldMap.TAB_DETAILS, WorldMap.TAB_COURSE]:
		map.show_tab(tab)
		await _refresh(map)
		var difference := _difference(reference, _fixed_parts(map))
		t.check(difference.is_empty(), "[sidebar] tab %d: same sidebar, header and footer%s" % [tab, "" if difference.is_empty() else " (" + difference + ")"])
		t.check((map.find_child("SleepButton", true, false) as Control).is_visible_in_tree(), "[sidebar] tab %d: Sleep is available" % tab)
		if tab == WorldMap.TAB_DETAILS:
			t.check((map.find_child("PositionLabel", true, false) as Label).text.contains("N"), "[details] shows the boat's coordinates")
			await t.screenshot("35_chart_sidebar_details")

	# Underway at 20× with changing wind and propulsion: nothing in the frame moves.
	t.set_wind(270.0, 14.0)
	GameSession.plan_route_to(&"kiel")
	GameSession.depart()
	GameSession.set_time_scale(20)
	await _refresh(map)
	map.show_tab(WorldMap.TAB_COURSE)
	await _refresh(map)
	var live_reference := _fixed_parts(map)
	var course_buttons := {}
	for control_name in ["PlotButton", "RemoveWaypointButton", "ClearButton"]:
		course_buttons[control_name] = _rect(map, control_name)
	var problems := PackedStringArray()
	for step in 12:
		Simulation.tick(1.0)  # 20 game minutes
		t.set_wind(270.0 + step * 25.0, 2.0 + step * 2.5)
		Simulation.evaluate_propulsion(true, true)
		await _refresh(map)
		var difference := _difference(live_reference, _fixed_parts(map))
		var in_tab := {}
		for control_name: String in course_buttons:
			in_tab[control_name] = _rect(map, control_name)
		difference += _difference(course_buttons, in_tab)
		if not difference.is_empty():
			problems.append(difference)
	t.check(problems.is_empty(), "[sidebar] at 20× with changing wind, speed, ETA and sail/engine no control moves%s"
		% ("" if problems.is_empty() else " (" + problems[0] + ")"))
	var status := (map.find_child("StatusLabel", true, false) as Label)
	var voyage := (map.find_child("VoyageLabel", true, false) as Label)
	t.check(status.text.begins_with("Underway to Kiel") and voyage.text.contains("ETA"), "[header] shows voyage status, distance and ETA (%s | %s)" % [status.text, voyage.text])
	GameSession.set_time_scale(1)

	# Interface scales and a smaller window.
	for scale in [0.8, 1.3]:
		SettingsManager.set_ui_scale(scale)
		await _refresh(map)
		_check_layout(map, "%d%% interface scale" % roundi(scale * 100))
		if scale == 1.3:
			await t.screenshot("36_chart_sidebar_scale_130")
	SettingsManager.set_ui_scale(1.0)
	var window := t.get_window()
	var original_size := window.size
	if DisplayServer.get_name() != "headless":
		window.size = Vector2i(1366, 768)
		await t.frames(4)
		await _refresh(map)
		_check_layout(map, "1366×768 window")
		window.size = original_size
		await t.frames(4)
	await _refresh(map)


func _test_route_editing_and_tabs() -> void:
	var map := app.router.current_screen as WorldMap
	# Weather tab: wind at the boat and the warnings along the course.
	map.show_tab(WorldMap.TAB_WEATHER)
	await _refresh(map)
	var tabs := map.find_child("Tabs", true, false) as TabContainer
	t.check(tabs.get_tab_title(WorldMap.TAB_WEATHER) == "Weather (1)", "[weather] the tab shows that the course meets 1 weather area (%s)" % tabs.get_tab_title(WorldMap.TAB_WEATHER))
	var weather := (map.find_child("WeatherLabel", true, false) as Label).text
	t.check(weather.contains("Strong winds") and weather.contains("caution"), "[weather] the strong-wind area on the way to Kiel is listed")
	t.check((map.find_child("WindHereLabel", true, false) as Label).text.begins_with("Wind "), "[weather] the wind at the boat is shown")
	await t.screenshot("34_chart_sidebar_weather")

	# Course editing at sea: change course, insert and remove a waypoint, apply from the footer.
	map.select_port(&"gothenburg")
	await _refresh(map)
	t.check_eq(map.get_current_tab(), WorldMap.TAB_COURSE, "[course] clicking a port shows the Course tab")
	await t.click(map.find_child("PlotButton", true, false))
	t.check(map.has_unapplied_changes() and map.get_draft_route() != null, "[course] a new course is plotted")
	var apply := map.find_child("ApplyButton", true, false) as Button
	t.check(not apply.disabled and apply.text == "Change course", "[course] the footer offers 'Change course'")
	var legs := map.get_draft_legs()
	var leg: PackedVector2Array = legs[0].path
	var index := map.insert_waypoint(0, GeoMath.point_along(leg, GeoMath.cumulative_distances(leg), 4.0))
	await _refresh(map)
	t.check(map.get_draft_waypoints().size() == 1 and index == 0, "[course] a waypoint can be added")
	map.remove_waypoint(0)
	await _refresh(map)
	t.check(map.get_draft_waypoints().is_empty(), "[course] and removed")
	await t.click(apply)
	await _refresh(map)
	t.check(GameSession.get_voyage_destination_id() == &"gothenburg" and not map.has_unapplied_changes(), "[course] Apply in the footer changes the course")
	t.check((map.find_child("SetSailButton", true, false) as Button).disabled and (map.find_child("ApplyButton", true, false) as Button).disabled,
		"[course] actions that cannot be used are disabled, not hidden")


func _test_map_controls() -> void:
	var map := app.router.current_screen as WorldMap
	var view := map.get_map_view()
	view.reset_view()
	await t.frames(2)
	var zoom := view.get_zoom()
	await t.click(map.find_child("ZoomInButton", true, false))
	t.check(view.get_zoom() > zoom, "[map] zoom in works")
	await t.click(map.find_child("ZoomOutButton", true, false))
	t.check(is_equal_approx(view.get_zoom(), zoom), "[map] zoom out works")
	view.center_on_geo(Vector2(-20.0, 40.0), 1.0)
	await t.frames(2)
	await t.click(map.find_child("CenterBoatButton", true, false))
	var boat_screen := view.geo_to_screen(GameSession.get_vessel_position())
	var free := view.get_viewport_rect().size - Vector2(WorldMap.SIDE_PANEL_WIDTH, 0)
	t.check(Rect2(Vector2.ZERO, free).has_point(boat_screen), "[map] Find boat brings the boat into view")
	var camera_before := view.camera.position
	var drag_from := Vector2(400, 400)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = drag_from
	t.get_viewport().push_input(press, true)
	var motion := InputEventMouseMotion.new()
	motion.position = drag_from + Vector2(120, 40)
	motion.relative = Vector2(120, 40)
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	t.get_viewport().push_input(motion, true)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = drag_from + Vector2(120, 40)
	t.get_viewport().push_input(release, true)
	await t.frames(2)
	t.check(view.camera.position != camera_before, "[map] dragging pans the chart")
	await t.click(map.find_child("WindToggle", true, false))
	t.check(not map.is_wind_shown(), "[map] the wind overlay switches off")
	await t.click(map.find_child("WindToggle", true, false))
	t.check(map.is_wind_shown(), "[map] and on again")


# --- Pause ---------------------------------------------------------------------------------

## Lets `frames` real frames pass with the frame-driven clock running.
func _run_frames(frames: int) -> void:
	Simulation.auto_advance = true
	await t.frames(frames)
	Simulation.auto_advance = false


func _snapshot() -> Dictionary:
	return {
		"time": GameSession.get_game_time(),
		"progress": GameSession.get_voyage_progress_nm() if GameSession.is_underway() else -1.0,
		"wind": Simulation.get_wind_at(GameSession.get_vessel_position()).to_vector(),
		"companion": GameSession.get_companion().to_dict(),
	}


func _test_pause_everywhere() -> void:
	t.set_wind(270.0, 14.0)
	var pause := app.hud.find_child("Pause", true, false) as Button
	var badge := app.hud.find_child("PausedBadge", true, false) as Control
	GameSession.set_time_scale(20)
	for place in ["chart", "cabin", "deck"]:
		if place == "cabin":
			app.close_chart()
			await _settle()
			GameSession.enter_boat_area(SessionState.AREA_INTERIOR, &"start")
			app._show_current_boat_area()
			await _settle()
		elif place == "deck":
			app._on_area_change_requested(&"exterior", &"start")
			await _settle()
		t.check(pause.is_visible_in_tree(), "[pause] the Pause button is shown (%s)" % place)
		await t.click(pause)
		app.hud.refresh()
		t.check(GameSession.is_paused() and pause.button_pressed and badge.visible, "[pause] pausing on the %s shows PAUSED" % place)
		var speeds_lit := 0
		for scale in SessionState.TIME_SCALES:
			speeds_lit += 1 if (app.hud.find_child("Speed%d" % scale, true, false) as Button).button_pressed else 0
		t.check_eq(speeds_lit, 0, "[pause] no speed is lit while paused (%s)" % place)
		var before := _snapshot()
		await _run_frames(20)
		var after := _snapshot()
		t.check(after.time == before.time and after.progress == before.progress and after.wind == before.wind
			and after.companion == before.companion, "[pause] time, voyage progress, wind and the companion stand still (%s)" % place)
		await t.click(pause)
		t.check(not GameSession.is_paused() and GameSession.get_time_scale() == 20
			and (app.hud.find_child("Speed20", true, false) as Button).button_pressed, "[pause] resuming continues at 20× (%s)" % place)
		await _run_frames(5)
		t.check(GameSession.get_game_time() > after.time, "[pause] and time runs again (%s)" % place)
	if t.screenshot_dir != "":
		GameSession.set_paused(true)
		app.hud.refresh()
		await t.frames(2)
		await t.screenshot("37_deck_paused")
		GameSession.set_paused(false)

	# Picking a speed while paused resumes at that speed.
	GameSession.set_paused(true)
	await t.click(app.hud.find_child("Speed5", true, false))
	t.check(not GameSession.is_paused() and GameSession.get_time_scale() == 5, "[pause] choosing 5× while paused resumes at 5×")
	GameSession.set_paused(true)
	await t.click(app.hud.find_child("Speed5", true, false))
	t.check(not GameSession.is_paused() and GameSession.get_time_scale() == 5, "[pause] choosing the same speed again also resumes")

	# Pause survives scene changes, and the chart stays usable while paused.
	GameSession.set_paused(true)
	app._on_area_change_requested(&"interior", &"from_deck")
	await _settle()
	app.open_chart()
	await _settle()
	var map := app.router.current_screen as WorldMap
	t.check(GameSession.is_paused() and pause.button_pressed, "[pause] still paused after going below and opening the chart")
	var time := GameSession.get_game_time()
	map.select_port(&"bergen")
	await t.click(map.find_child("PlotButton", true, false))
	await t.click(map.find_child("ApplyButton", true, false))
	await _run_frames(10)
	t.check(GameSession.get_voyage_destination_id() == &"bergen" and GameSession.get_game_time() == time,
		"[pause] the chart can be used to plan and change course while paused, without time passing")
	await t.screenshot("38_chart_paused")
	app.close_chart()
	await _settle()
	t.check(GameSession.is_paused(), "[pause] still paused after closing the chart")
	GameSession.set_paused(false)


func _test_pause_and_sleep() -> void:
	SettingsManager.set_sleep_hours(SettingsManager.DEFAULT_SLEEP_HOURS, false)  # the dialog remembers the last choice (Cozy Polish)
	GameSession.set_paused(true)
	var before := GameSession.get_game_time()
	app.open_sleep_menu()
	await t.frames(2)
	var menu := app.modals.get_top() as SleepMenu
	if not t.check(menu != null, "[sleep] the sleep dialog opens while paused"):
		return
	t.check((menu.find_child("Info", true, false) as Label).text.contains("paused"), "[sleep] the dialog says the game stays paused")
	for i in 4:
		menu.change_hours(-1)  # 2 hours
	await t.click(menu.find_child("SleepButton", true, false))
	await _settle()
	t.check(is_equal_approx(GameSession.get_game_time() - before, 2.0 * 3600.0), "[sleep] sleeping while paused moves time on by exactly the chosen hours")
	t.check(GameSession.is_paused() and _toast_contains("Time is still paused"), "[sleep] afterwards the game is still paused, and says so")
	var woke := GameSession.get_game_time()
	await _run_frames(10)
	t.check_eq(GameSession.get_game_time(), woke, "[sleep] continuous time does not start after waking")
	GameSession.set_paused(false)


func _test_pause_persistence() -> void:
	GameSession.set_paused(true)
	t.check_eq(SaveManager.save_to_slot(2, GameSession.get_state_snapshot()), OK, "[save] saved while paused")
	GameSession.set_paused(false)
	app.show_main_menu()
	await _settle()
	app.load_slot(2)
	await _settle()
	t.check(GameSession.is_paused(), "[save] a game saved while paused loads paused")
	var pause := app.hud.find_child("Pause", true, false) as Button
	t.check(pause.button_pressed, "[save] and the time bar shows it")
	# Older saves (no pause flag) load running.
	var data: Dictionary = GameSession.get_state_snapshot().to_dict()
	data.clock.erase("paused")
	var errors: Array[String] = []
	var older := SessionState.from_dict(JSON.parse_string(JSON.stringify(data)), errors)
	t.check(older != null and not older.paused, "[save] saves without a pause flag load unpaused")
	data.clock["paused"] = "yes"
	t.check(SessionState.from_dict(data, errors) == null, "[save] an invalid pause flag is rejected")
	SaveManager.delete_slot(2)
	GameSession.set_paused(false)
	app.show_main_menu()
	await _settle()
	app.start_new_game()
	await _settle()
	t.check(not GameSession.is_paused(), "[pause] a new game starts running")
	app.show_main_menu()
	await _settle()


# --- Helpers -------------------------------------------------------------------------------

func _refresh(map: WorldMap) -> void:
	map._refresh()
	await t.frames(3)


func _settle() -> void:
	await t.frames(2)
	await t.wait_until(func() -> bool: return not app.router.is_busy(), 5.0)
	await t.physics_frames(3)


func _toast_contains(text: String) -> bool:
	for message in app.toasts.get_messages():
		if text in message:
			return true
	return false
