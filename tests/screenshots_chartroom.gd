extends Node
## Captain's Chartroom UI pass: rendered evidence of every main interface by
## day (Vintage Chartroom) and by night (Harbor Dusk), at the normal 1600x900
## presentation. Run rendered (Xvfb + software OpenGL is fine):
##   xvfb-run godot --path . --rendering-driver opengl3 --resolution 1600x900 \
##     res://tests/screenshots_chartroom.tscn -- --out=DIR [--only=day|night]
## The game clock is set to local noon or midnight at the boat so the world's
## light matches the interface's mood; the interface follows it automatically
## (Settings: Interface light = Automatic).

const APP_SCENE := preload("res://src/app/app.tscn")

var app: Node
var out := "res://docs/screenshots/chartroom_ui"
var only := ""


func _ready() -> void:
	SaveManager.save_dir = "user://test_saves"
	SettingsManager.settings_path = "user://test_settings.cfg"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
		elif a.begins_with("--only="):
			only = a.trim_prefix("--only=")
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _idle() -> void:
	var guard := 0
	while app.router.is_busy() and guard < 2000:
		guard += 1
		await get_tree().process_frame
	await _frames(6)


func _shot(file_name: String, keep_toasts := false) -> void:
	if not keep_toasts:
		app.toasts.clear()
	await _frames(4)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, file_name])
	print("SHOT %s (night %.2f)" % [file_name, UiTheme.blend])


func _set_local_hour(hour: float) -> void:
	var state := GameSession.get_state_snapshot()
	var geo := GameSession.get_vessel_position()
	var day_start := floorf(state.game_time / 86400.0) * 86400.0
	state.game_time = day_start + fposmod(hour - geo.x / 15.0, 24.0) * 3600.0
	GameSession.replace_state(state)
	UiTheme.set_blend(UiTheme._target_blend(), true)


func _show(area: StringName) -> BoatArea:
	app.modals.clear()
	GameSession.enter_boat_area(area, &"start")
	app._show_current_boat_area()
	await _idle()
	var screen := app.router.current_screen as BoatArea
	var lighting := screen.get_node_or_null("Lighting")
	if lighting:
		lighting.update_now()
	app.toasts.clear()
	return screen


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(out)
	Simulation.auto_advance = false
	WindField.get_default().test_override = func(_geo: Vector2, _time: float) -> WindField.Sample:
		return WindField.Sample.make(220.0, 11.0)
	app = APP_SCENE.instantiate()
	add_child(app)
	await _frames(12)
	SettingsManager.set_ui_light(SettingsManager.UI_LIGHT_DAY)
	await _shot("00_main_menu_day")
	SettingsManager.set_ui_light(SettingsManager.UI_LIGHT_NIGHT)
	await _shot("00_main_menu_night")
	SettingsManager.set_ui_light(SettingsManager.UI_LIGHT_AUTO)
	app.start_new_game()
	await _idle()
	for mood in ["day", "night"]:
		if only != "" and only != mood:
			continue
		await _mood(mood)
	print("CHARTROOM SHOTS DONE")
	get_tree().quit()


func _mood(mood: String) -> void:
	var hour := 12.5 if mood == "day" else 23.5
	# Moored deck.
	_set_local_hour(hour)
	var deck := await _show(SessionState.AREA_EXTERIOR)
	await _shot("01_deck_moored_%s" % mood)
	# The action wheel (a popup) and a tooltip-style prompt.
	app.open_action_wheel()
	await _frames(6)
	await _shot("02_action_wheel_%s" % mood)
	app.modals.clear()
	# Cabin with a station open (provisions), and boat care in harbour.
	await _show(SessionState.AREA_INTERIOR)
	await _shot("03_cabin_%s" % mood)
	app.open_trophies()
	await _frames(6)
	await _shot("04_trophy_board_%s" % mood)
	app.modals.clear()
	app.open_boat_care()
	await _frames(6)
	await _shot("05_boat_care_%s" % mood)
	app.modals.clear()
	# Harbour: the chandlery, the boatyard, going ashore; the log; sleep.
	for pair in [["open_grocery", "15_grocery"], ["open_boatyard", "16_boatyard"], ["open_go_ashore", "17_go_ashore"],
			["open_captains_log", "18_captains_log"], ["open_sleep_menu", "19_sleep"], ["open_cooking", "20_galley"]]:
		app.call(pair[0])
		await _idle()
		await _frames(8)
		await _shot("%s_%s" % [pair[1], mood])
		app.modals.clear()
		await _idle()
	# A weather warning and a tooltip on deck.
	await _show(SessionState.AREA_EXTERIOR)
	app.hud.show_warning("Gale expected in about 6 hours along your course. Consider a sheltered harbour.")
	await _frames(4)
	var menu := app.hud.find_child("MenuButton", true, false) as Control
	var motion := InputEventMouseMotion.new()
	motion.position = menu.get_global_transform_with_canvas() * (menu.size / 2.0)
	motion.global_position = motion.position
	get_viewport().push_input(motion)
	await get_tree().create_timer(1.2).timeout
	await _shot("21_warning_and_tooltip_%s" % mood)
	app.hud.hide_warning()
	# Navigation chart with a course to Kiel.
	GameSession.plan_route_to(&"kiel")
	app.open_chart()
	await _idle()
	await _frames(10)
	await _shot("06_chart_course_%s" % mood)
	app.close_chart()
	await _idle()
	# Underway: deck with the sailing panel, then fishing.
	GameSession.depart()
	Simulation.advance(1800.0)
	_set_local_hour(hour)
	deck = await _show(SessionState.AREA_EXTERIOR)
	await _shot("07_deck_underway_%s" % mood)
	app.open_sail_trim()
	await _frames(8)
	await _shot("22_sail_trim_%s" % mood)
	app.modals.clear()
	var catalog := FishingCatalog.get_default()
	GameSession.expire_bite()
	GameSession._pending_bite = {"species": "cod", "kg": 4.2, "time": GameSession.get_game_time(), "mode": "trolling",
		"lure": "spinner", "kind": String(catalog.kind_of("cod")), "rarity": catalog.rarity_of("cod")}
	var fishing: FishingMenu = app.open_fishing()
	await _frames(8)
	await _shot("08_fishing_reel_%s" % mood)
	if fishing and fishing.is_reeling():
		var reel := fishing.get_reel()
		while not reel.is_over():
			fishing.step_reel(ReelTiming.DEBOUNCE + 0.01)
			reel.angle = reel.target_deg
			fishing.press_reel()
		await _frames(8)
		await _shot("09_fishing_result_%s" % mood)
	app.modals.clear()
	# Dreamer's Map (the cabin's atlas).
	app.open_dream_map()
	await _idle()
	await _frames(10)
	await _shot("10_dream_map_%s" % mood)
	app.close_chart()
	await _idle()
	# Menus: pause, settings, developer guides, a confirmation.
	app.open_pause_menu()
	await _frames(6)
	await _shot("11_pause_menu_%s" % mood)
	app.modals.clear()
	app.open_settings()
	await _frames(6)
	await _shot("12_settings_%s" % mood)
	app.modals.clear()
	if app.has_method("open_dev_guides"):
		app.open_dev_guides()
		await _frames(8)
		await _shot("13_dev_guides_%s" % mood)
		app.modals.clear()
	app.notify("A friendly notice: the kettle is on.")
	await _frames(4)
	await _shot("14_toast_and_prompt_%s" % mood, true)
	# Back to harbour for the next mood.
	var state := GameSession.get_state_snapshot()
	state.location_id = &"copenhagen"
	state.vessel_status = SessionState.STATUS_MOORED
	state.vessel_position = PortCatalog.get_default().get_port(&"copenhagen").get_geo_position()
	state.voyage = null
	state.planned_route = null
	GameSession.replace_state(state)
