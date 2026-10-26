extends RefCounted
## Iteration 17 (HUD, NAV-8): the cockpit.
## - The sailing panel underway: speed, heading (on the planned course), wind
##   now, the next leg's course and forecast wind (labelled an estimate), the
##   time and distance to the next turn, or "no more turns" before the
##   destination; collapsible; clear of the other panels.
## - A new course of more than 5° gets a short highlight; nothing otherwise.
## - The chartplotter (P or the action wheel): on deck underway only, coast
##   from the navigation raster around the boat, the voyage's course and next
##   turn; it never builds the world chart.
## - The action wheel (Q): the actions for where the captain is, keyboard
##   and mouse, nothing under it reacts; its key is in the help strip.

const APP_SCENE := preload("res://src/app/app.tscn")
const DECK := SessionState.AREA_EXTERIOR
const CABIN := SessionState.AREA_INTERIOR

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
	t.check("Q actions" in app.hud.get_controls_text(), "[help] the help strip shows the action wheel key (%s)" % app.hud.get_controls_text())
	t.check(not app.hud.sailing_panel.visible, "[panel] no sailing panel in harbour")
	t.set_wind(270.0, 14.0)
	GameSession.plan_route_to(&"las_palmas")
	GameSession.depart()
	Simulation.advance(1800.0)
	await _show(DECK)
	await _test_sailing_panel()
	await _test_course_change_pulse()
	await _test_chartplotter()
	await _test_action_wheel()
	ChartPlotter.shown = false
	SailingPanel.collapsed = false
	Simulation.auto_advance = true
	app.queue_free()
	await t.frames(2)
	GameSession.end_session()
	t.use_calm_wind()


func _settle() -> void:
	await t.frames(2)
	await t.wait_until(func() -> bool: return not app.router.is_busy(), 5.0)
	await t.physics_frames(3)


func _show(area: StringName, spawn := &"start") -> BoatArea:
	app.modals.clear()
	GameSession.enter_boat_area(area, spawn)
	app._show_current_boat_area()
	await _settle()
	app.toasts.clear()
	app.hud.hide_warning()
	return app.router.current_screen as BoatArea


func _test_sailing_panel() -> void:
	var panel: SailingPanel = app.hud.sailing_panel
	await t.frames(2)
	t.check(panel.visible, "[panel] underway, the sailing panel is shown")
	t.check(panel.get_value("speed").begins_with("%.1f kn" % GameSession.get_vessel_speed_kn()), "[panel] speed: %s" % panel.get_value("speed"))
	t.check(panel.get_value("heading").begins_with("%03d°" % roundi(Simulation.get_current_heading())) and "planned course" in panel.get_value("heading"),
		"[panel] heading: %s" % panel.get_value("heading"))
	var wind := Simulation.get_wind_at(GameSession.get_vessel_position())
	t.check(panel.get_value("wind").begins_with(Hud.describe_wind(wind).trim_prefix("Wind ")), "[panel] wind now: %s" % panel.get_value("wind"))
	var turn := WorldMap.get_next_turn()
	t.check("forecast" in panel.get_value("next_leg") and "(estimate)" in panel.get_value("next_leg")
		and panel.get_value("next_leg").begins_with("%03d°" % roundi(turn.next_course)), "[panel] next leg: %s" % panel.get_value("next_leg"))
	t.check(("%.1f nm" % float(turn.nm)) in panel.get_value("turn") and "→" in panel.get_value("turn"), "[panel] next turn: %s" % panel.get_value("turn"))
	t.check("(estimate)" in panel.get_value("remaining"), "[panel] distance to go and ETA, an estimate: %s" % panel.get_value("remaining"))
	# Clear of the route panel and the Long Passage panel.
	var rect := panel.get_global_rect()
	var route := (app.hud.get_node("RoutePanel") as Control).get_global_rect()
	var passage: Control = app.hud.passage_panel
	t.check(not rect.intersects(route) and (not passage.visible or not rect.intersects(passage.get_global_rect())),
		"[panel] it does not overlap the route or Long Passage panels")
	await t.screenshot("17_sailing_panel")
	# Collapsible.
	await t.click(panel.find_child("Collapse", true, false))
	await t.frames(2)
	t.check(not (panel.find_child("NextLeg", true, false) as Control).visible and (panel.find_child("Speed", true, false) as Control).visible,
		"[panel] collapsed: the essentials stay, the details go")
	await t.click(panel.find_child("Collapse", true, false))
	await t.frames(2)
	t.check((panel.find_child("NextLeg", true, false) as Control).visible, "[panel] and back")
	# No fictitious turn on the last leg.
	var voyage := GameSession.get_voyage()
	var cumulative := voyage.get_cumulative()
	var last_leg_start := cumulative[cumulative.size() - 2]
	var state := GameSession.get_state_snapshot()
	state.voyage.progress_nm = last_leg_start + 0.5
	state.vessel_position = state.voyage.get_position()
	GameSession.replace_state(state)
	await t.frames(3)
	t.check(panel.get_value("turn").begins_with("No more turns") and not (panel.find_child("NextLeg", true, false) as Control).visible,
		"[panel] on the last leg: %s" % panel.get_value("turn"))
	state = GameSession.get_state_snapshot()
	state.voyage.progress_nm = 20.0
	state.vessel_position = state.voyage.get_position()
	GameSession.replace_state(state)
	await t.frames(2)


func _test_course_change_pulse() -> void:
	var panel: SailingPanel = app.hud.sailing_panel
	await t.get_tree().create_timer(2.0).timeout  # the jump back above was a course change
	var pulses := 0
	for i in 30:
		await t.frames(1)
		pulses += 1 if panel.is_pulsing() else 0
	t.check(pulses == 0, "[pulse] no highlight while the course stays the same")
	# Sail to the next leg whose course differs by more than 5°.
	var start := Simulation.get_current_heading()
	var turned := false
	for i in 300:
		Simulation.advance(300.0)
		await t.frames(1)
		if absf(angle_difference(deg_to_rad(start), deg_to_rad(Simulation.get_current_heading()))) > deg_to_rad(SailingPanel.COURSE_CHANGE_DEG):
			turned = true
			break
	t.check(turned and panel.is_pulsing(), "[pulse] a new course from the autopilot gets a short highlight")
	await t.get_tree().create_timer(2.0).timeout
	t.check(not panel.is_pulsing(), "[pulse] the highlight ends by itself (no continuous flashing)")


func _test_chartplotter() -> void:
	var plotter: ChartPlotter = app.hud.chart_plotter
	ChartPlotter.shown = false
	await t.frames(2)
	t.check(not plotter.visible, "[plotter] hidden until asked for")
	await t.press_action(&"chartplotter")
	await t.frames(2)
	t.check(ChartPlotter.shown and plotter.visible, "[plotter] P shows it on deck underway")
	t.check(await t.wait_until(func() -> bool: return plotter.is_raster_ready(), 5.0), "[plotter] the coast raster is built in a few frames")
	var turn := WorldMap.get_next_turn()
	t.check(("%.1f nm" % float(turn.nm)) in plotter.get_info_text(), "[plotter] it shows the next turn of the voyage: %s" % plotter.get_info_text().replace("\n", " | "))
	t.check(app.find_children("*", "MapView", true, false).is_empty() and not app.router.current_screen is WorldMap,
		"[plotter] no world chart was built for it")
	plotter.change_range(1)
	t.check(await t.wait_until(func() -> bool: return plotter.is_raster_ready(), 5.0), "[plotter] a new range is rebuilt too")
	await t.screenshot("17_chartplotter")
	var cabin := await _show(CABIN)
	await t.frames(2)
	t.check(cabin != null and not plotter.visible, "[plotter] not shown in the cabin")
	await _show(DECK, &"from_cabin")
	await t.frames(2)
	t.check(plotter.visible, "[plotter] back on deck it is there again")


func _wheel() -> ActionWheel:
	return app.modals.get_top() as ActionWheel


func _ids(wheel: ActionWheel) -> Array[StringName]:
	var ids: Array[StringName] = []
	for item in wheel.items:
		ids.append(item.id)
	return ids


func _test_action_wheel() -> void:
	var deck := app.router.current_screen as BoatArea
	var before := deck.player.position
	await t.press_action(&"action_wheel")
	await t.frames(3)
	var wheel := _wheel()
	if not t.check(wheel != null, "[wheel] Q opens the action wheel"):
		return
	t.check((wheel.get_node("Title") as Label).text == "At the helm" and &"chartplotter" in _ids(wheel) and &"go" in _ids(wheel),
		"[wheel] at the helm underway: %s" % ", ".join(_ids(wheel)))
	await t.screenshot("17_action_wheel_helm")
	# Keyboard: D moves to the next action, E chooses it.
	var index := _ids(wheel).find(&"chartplotter")
	wheel.select(index - 1)
	await t.press_action(&"move_right")
	t.check(wheel.get_selected_id() == &"chartplotter", "[wheel] D moves to the next action")
	var shown := ChartPlotter.shown
	await t.press_action(&"interact")
	await t.frames(3)
	t.check(app.modals.is_empty() and ChartPlotter.shown != shown, "[wheel] E uses it (the chartplotter toggled) and the wheel closes")
	t.check(deck.player.position.distance_to(before) < 2.0, "[wheel] the captain did not move meanwhile")
	# Esc closes; nothing under it reacts.
	await t.press_action(&"action_wheel")
	await t.frames(2)
	await t.press_action(&"pause")
	await t.frames(2)
	t.check(app.modals.is_empty(), "[wheel] Esc closes it (no pause menu behind it)")
	# In the cabin.
	await _show(CABIN)
	await t.press_action(&"action_wheel")
	await t.frames(3)
	wheel = _wheel()
	t.check(wheel != null and &"sleep" in _ids(wheel) and &"dream_map" in _ids(wheel) and &"chart" in _ids(wheel),
		"[wheel] in the cabin: %s" % (", ".join(_ids(wheel)) if wheel else "-"))
	if wheel:
		await t.click(wheel.find_child("Action_dream_map", true, false))
		await t.wait_until(func() -> bool: return app.router.current_screen is WorldMap and not app.router.is_busy(), 10.0)
		t.check((app.router.current_screen as WorldMap).mode == WorldMap.MODE_DREAM, "[wheel] choosing World map with the mouse opens the Dreamer's Map")
		app.close_chart()
		await _settle()
