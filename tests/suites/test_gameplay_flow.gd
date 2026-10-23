extends RefCounted
## End-to-end flow through the real application scene: main menu, new game,
## movement and collision, interactions, area transitions, the chart, pause
## menu, settings, save/load and returning to the main menu. Input is fed
## through the engine's input pipeline (key actions and mouse clicks).

const APP_SCENE := preload("res://src/app/app.tscn")

var t: Node
var app: Node


func run(runner: Node) -> void:
	t = runner
	app = APP_SCENE.instantiate()
	t.add_child(app)
	app.router.fade_duration = 0.05
	await _settle()

	await _test_main_menu()
	await _test_new_game_and_movement()
	await _test_interactions_in_cabin()
	await _test_chart()
	await _test_companionway_transitions()
	await _test_pause_and_settings()
	await _test_save_and_load()
	await _test_main_menu_return_and_continue()
	await _test_quit()


# --- Steps -----------------------------------------------------------------------

func _test_main_menu() -> void:
	t.check(app.router.current_screen is MainMenu, "app starts on the main menu")
	var menu: MainMenu = app.router.current_screen
	var logo := menu.find_child("Logo", true, false) as TextureRect
	t.check(logo != null and logo.texture != null and logo.is_visible_in_tree(), "logo is displayed on the main menu")
	t.check(_button(menu, "ContinueButton").disabled, "Continue is disabled without a valid save")
	t.check(not _button(menu, "NewGameButton").disabled, "New Game is enabled")
	await t.screenshot("01_main_menu")

	# Settings from the main menu returns to the main menu.
	await t.click(_button(menu, "SettingsButton"))
	t.check(app.modals.get_top() is SettingsMenu, "Settings opens from the main menu")
	await t.screenshot("02_settings")
	await t.press_action(&"pause")
	t.check(app.modals.is_empty(), "Esc closes settings back to the main menu")

	# Load Game is disabled while every slot is empty.
	t.check(_button(menu, "LoadButton").disabled, "Load Game is disabled while all slots are empty")


func _test_new_game_and_movement() -> void:
	var menu: MainMenu = app.router.current_screen
	await t.click(_button(menu, "NewGameButton"))
	await _settle()
	var area := app.router.current_screen as BoatArea
	t.check(area != null and area.area_id == &"interior", "New Game starts inside the boat (cabin)")
	t.check(GameSession.is_active(), "a session is active")
	t.check_eq(_player_count(), 1, "exactly one player exists")
	t.check(app.hud.is_visible_in_tree(), "HUD is visible in the boat")
	t.check_eq((app.hud.find_child("AreaLabel", true, false) as Label).text, "Cabin", "HUD shows the current area")
	var spawn: Vector2 = area.get_node("SpawnPoints/start").position
	t.check(area.player.position.distance_to(spawn) < 1.0, "player starts at the start spawn point")
	await t.screenshot("03_cabin")

	var player := area.player
	var start := player.position
	await t.hold_actions([&"move_left"], 0.3)
	t.check(player.position.x < start.x - 40.0, "A/left moves the player left")
	start = player.position
	await t.hold_actions([&"move_right"], 0.3)
	t.check(player.position.x > start.x + 40.0, "D/right moves the player right")

	# Diagonal speed equals straight speed.
	Input.action_press(&"move_right")
	Input.action_press(&"move_down")
	await t.physics_frames(3)
	var diagonal_speed := player.velocity.length()
	Input.action_release(&"move_right")
	Input.action_release(&"move_down")
	await t.physics_frames(2)
	t.check(absf(diagonal_speed - player.speed) < 0.5, "diagonal movement is normalized (%.1f vs %.1f)" % [diagonal_speed, player.speed])

	# Walls and furniture stop the player.
	player.position = Vector2(-120, 0)
	await t.physics_frames(2)
	await t.hold_actions([&"move_up"], 1.2)
	t.check(player.position.y > -110.0, "settee blocks the player (y = %.1f)" % player.position.y)
	player.position = Vector2(-195, 0)
	await t.physics_frames(2)
	await t.hold_actions([&"move_left"], 1.0)
	t.check(player.position.x > -260.0, "companionway steps block the player (x = %.1f)" % player.position.x)
	player.position = Vector2(270, 0)
	await t.physics_frames(2)
	await t.hold_actions([&"move_right", &"move_up"], 1.5)
	t.check(player.position.y > -110.0 and player.position.x < 330.0, "hull and berth contain the player")
	t.check(Rect2(-330, -170, 790, 340).has_point(player.position), "player stays inside the cabin")


func _test_interactions_in_cabin() -> void:
	var area := app.router.current_screen as BoatArea
	var player := area.player
	await _move_player_to(Vector2(-110, 0))
	t.check_eq(app.hud.get_prompt(), "", "no prompt when nothing is in reach")

	await _move_player_to(Vector2(276, 0))
	t.check_eq(app.hud.get_prompt(), "Sleep", "prompt appears near the berth")
	await t.screenshot("04_prompt_berth")
	await t.press_action(&"interact")
	t.check(_toast_contains("Sleeping is not implemented"), "bed interaction shows its message")

	# Between the companionway and the chart table both are in reach; the
	# closer one must win, and the choice must not flicker.
	var sensor: InteractionSensor = player.get_node("InteractionSensor")
	await _move_player_to(Vector2(-220, 40))
	var in_reach := sensor.get_overlapping_areas().filter(func(a: Area2D) -> bool: return a is Interactable)
	t.check_eq(in_reach.size(), 2, "two interactables are in reach between companionway and chart table")
	t.check_eq(sensor.focused.interaction_id, &"nav_table", "the closer chart table is focused")
	await t.physics_frames(5)
	t.check_eq(sensor.focused.interaction_id, &"nav_table", "focus stays stable while standing still")
	await _move_player_to(Vector2(-222, 8))
	t.check_eq(sensor.focused.interaction_id, &"companionway", "moving closer to the companionway switches focus")

	await _move_player_to(Vector2(-232, 62))
	t.check_eq(app.hud.get_prompt(), "Open chart", "prompt appears at the navigation table")
	GameSession.mark_saved()


func _test_chart() -> void:
	var position_at_table: Vector2 = (app.router.current_screen as BoatArea).player.position
	await t.press_action(&"interact")
	await _settle()
	var map := app.router.current_screen as WorldMap
	t.check(map != null, "navigation table opens the chart")
	if map == null:
		return
	t.check(not app.hud.is_visible_in_tree(), "gameplay HUD is hidden on the chart")
	t.check_eq(_player_count(), 0, "no player exists while the chart is open")
	var view := map.get_map_view()
	await t.screenshot("05_chart")

	var zoom := view.get_zoom()
	view.zoom_by(1.5)
	t.check(view.get_zoom() > zoom * 1.4, "zoom in works")
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	wheel.position = Vector2(700, 500)
	t.get_viewport().push_input(wheel, true)
	await t.frames(1)
	t.check(view.get_zoom() < zoom * 1.5, "mouse wheel zooms out")

	var camera_before := view.camera.position
	await _drag(Vector2(600, 500), Vector2(450, 420))
	t.check(view.camera.position.distance_to(camera_before) > 20.0, "dragging pans the chart")
	camera_before = view.camera.position
	await t.hold_actions([&"move_right"], 0.2)
	t.check(view.camera.position.x > camera_before.x, "keyboard pans the chart")
	view.reset_view()
	await t.frames(2)

	# Select Kiel by clicking its marker, then plot a course.
	await t.click_at(view.get_port_screen_position(&"kiel"))
	t.check_eq(map.get_selected_port_id(), &"kiel", "clicking a port selects it")
	var plot := map.find_child("PlotButton", true, false) as Button
	t.check(not plot.disabled, "Plot course is available for Kiel")
	await t.click(plot)
	var route := GameSession.get_planned_route()
	t.check(route != null and route.origin_port_id == &"copenhagen" and route.destination_port_id == &"kiel",
		"a route Copenhagen -> Kiel is plotted")
	t.check(view.route_path.size() == 2, "the chart draws the planned course")
	await t.screenshot("06_chart_route")

	await t.click_at(view.get_port_screen_position(&"copenhagen"))
	t.check(plot.disabled, "cannot plot a course to the current port")
	var clear := map.find_child("ClearButton", true, false) as Button
	await t.click(clear)
	t.check(GameSession.get_planned_route() == null, "route can be cleared")
	t.check(clear.disabled, "Clear route is disabled without a route")
	await t.click_at(view.get_port_screen_position(&"kiel"))
	await t.click(plot)
	t.check(GameSession.get_planned_route() != null, "route can be plotted again")

	await t.press_action(&"pause")
	await _settle()
	var area := app.router.current_screen as BoatArea
	t.check(area != null and area.area_id == &"interior", "Esc returns from the chart to the cabin")
	if area:
		t.check(area.player.position.distance_to(position_at_table) < 1.0, "player is back at the navigation table")
	t.check(app.modals.is_empty() and not t.get_tree().paused, "closing the chart does not open the pause menu")
	t.check_eq((app.hud.find_child("RouteLabel", true, false) as Label).text,
		PlannedRoute.describe(GameSession.get_planned_route(), PortCatalog.get_default()), "HUD shows the planned route")


func _test_companionway_transitions() -> void:
	await _move_player_to(Vector2(-222, 0))
	t.check_eq(app.hud.get_prompt(), "Go on deck", "companionway prompt in the cabin")
	await t.press_action(&"interact")
	await _settle()
	var deck := app.router.current_screen as BoatArea
	t.check(deck != null and deck.area_id == &"exterior", "companionway leads on deck")
	if deck == null:
		return
	t.check_eq(GameSession.get_boat_area(), &"exterior", "session records the deck as current area")
	var spawn: Vector2 = deck.get_node("SpawnPoints/from_cabin").position
	t.check(deck.player.position.distance_to(spawn) < 1.0, "player arrives at the companionway on deck")
	t.check_eq((app.hud.find_child("AreaLabel", true, false) as Label).text, "Deck", "HUD shows Deck")
	await t.screenshot("07_deck")

	await _move_player_to(Vector2(-448, 0))
	t.check_eq(app.hud.get_prompt(), "Take the helm", "helm prompt")
	await t.press_action(&"interact")
	t.check(_toast_contains("Steering and sailing are not implemented"), "helm interaction shows its message")

	# Deck boundaries hold.
	await _move_player_to(Vector2(0, -130))
	await t.hold_actions([&"move_up"], 1.0)
	t.check(deck.player.position.y > -170.0, "lifelines keep the player on deck")
	await _move_player_to(Vector2(300, 0))
	await t.hold_actions([&"move_right"], 1.5)
	t.check(deck.player.position.x < 495.0, "bow pulpit stops the player")

	# Repeated round trips never duplicate the player or the screen.
	for i in 3:
		await _move_player_to(Vector2(-262, 0))
		await t.press_action(&"interact")
		await _settle()
		await _move_player_to(Vector2(-222, 0))
		await t.press_action(&"interact")
		await _settle()
	t.check_eq(_player_count(), 1, "repeated transitions keep exactly one player")
	t.check_eq(app.get_node("Screen").get_child_count(), 1, "only one screen is loaded")
	t.check_eq(GameSession.get_boat_area(), &"exterior", "ended on deck after round trips")


func _test_pause_and_settings() -> void:
	var area := app.router.current_screen as BoatArea
	await t.press_action(&"pause")
	t.check(app.modals.get_top() is PauseMenu, "Esc opens the pause menu")
	t.check(t.get_tree().paused, "gameplay is paused")
	await t.screenshot("08_pause")
	var before := area.player.position
	await t.hold_actions([&"move_right"], 0.3)
	t.check(area.player.position.is_equal_approx(before), "player cannot move while paused")

	var pause: PauseMenu = app.modals.get_top()

	# UI scale enlarges menus and HUD while their layout still fits the screen.
	SettingsManager.set_ui_scale(1.3)
	await t.frames(3)
	var layer := app.get_node("ModalLayer") as CanvasLayer
	t.check(layer.scale.is_equal_approx(Vector2(1.3, 1.3)), "UI scale is applied to the menu layer")
	var stack_size: Vector2 = (layer.get_node("ModalStack") as Control).size
	t.check(stack_size.is_equal_approx(t.get_viewport().get_visible_rect().size / 1.3), "scaled UI still covers the screen exactly")
	var resume_rect := _button(pause, "ResumeButton").get_global_rect()
	t.check(Rect2(Vector2.ZERO, stack_size).encloses(resume_rect), "scaled pause menu stays on screen")
	await t.screenshot("08b_pause_ui_scale_130")
	SettingsManager.set_ui_scale(1.0)
	await t.frames(2)

	await t.click(_button(pause, "SettingsButton"))
	t.check(app.modals.get_top() is SettingsMenu, "Settings opens from the pause menu")
	t.check(not pause.visible, "pause menu is hidden behind settings")
	var settings: SettingsMenu = app.modals.get_top()

	# Changing a slider applies immediately; leaving asks to discard.
	var music_slider: HSlider = settings._volume_sliders[&"Music"]
	music_slider.value = 30
	t.check_eq(SettingsManager.get_volume(&"Music"), 30, "music slider changes the setting immediately")
	t.check(absf(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"Music")) - linear_to_db(0.3)) < 0.01,
		"music slider changes the Music bus volume")
	music_slider.value = 0
	t.check(AudioServer.is_bus_mute(AudioServer.get_bus_index(&"Music")), "music slider at 0 mutes the bus")
	await t.press_action(&"pause")
	t.check(app.modals.get_top() is ConfirmDialog, "leaving with unapplied changes asks for confirmation")
	await t.screenshot("09_settings_confirm")
	await t.click(_button(app.modals.get_top(), "ConfirmButton"))
	t.check_eq(SettingsManager.get_volume(&"Music"), SettingsManager.DEFAULT_VOLUMES[&"Music"], "discarding restores the previous volume")
	t.check(app.modals.get_top() is PauseMenu and pause.visible, "settings return to the pause menu")

	# Apply persists; Restore Defaults resets.
	await t.click(_button(pause, "SettingsButton"))
	settings = app.modals.get_top()
	(settings._volume_sliders[&"SFX"] as HSlider).value = 40
	await t.click(_button(settings, "ApplyButton"))
	t.check(FileAccess.file_exists(t.TEST_SETTINGS_PATH), "Apply writes the settings file")
	var config := ConfigFile.new()
	config.load(t.TEST_SETTINGS_PATH)
	t.check_eq(config.get_value("audio", "sfx"), 40, "applied SFX volume is stored")
	await t.click(_button(settings, "DefaultsButton"))
	t.check_eq(SettingsManager.get_volume(&"SFX"), 80, "Restore Defaults resets the SFX volume")
	await t.click(_button(settings, "ApplyButton"))
	await t.click(_button(settings, "BackButton"))
	t.check(app.modals.get_top() is PauseMenu, "Back returns to the pause menu")

	await t.click(_button(pause, "ResumeButton"))
	t.check(app.modals.is_empty() and not t.get_tree().paused, "Resume closes the menu and unpauses")
	await t.hold_actions([&"move_right"], 0.2)
	t.check(not area.player.position.is_equal_approx(before), "player moves again after resuming")


func _test_save_and_load() -> void:
	var area := app.router.current_screen as BoatArea
	await _move_player_to(Vector2(-330, 30))
	var saved_state := GameSession.get_state_snapshot().to_dict()

	await _open_pause_and_click("SaveButton")
	var menu := app.modals.get_top() as SaveLoadMenu
	t.check(menu != null and menu.mode == SaveLoadMenu.Mode.SAVE, "Save Game opens the save dialog")
	await t.screenshot("10_save_dialog")
	await t.click(menu.find_child("Slot1", true, false))
	t.check(_toast_contains("Game saved to slot 1"), "saving reports success")
	t.check(app.modals.get_top() is PauseMenu, "save dialog closes back to the pause menu")
	t.check(not GameSession.has_unsaved_changes(), "session is marked as saved")
	t.check(SaveManager.get_slot_info(1).is_loadable(), "slot 1 contains a valid save")

	# Save to a second slot, then overwrite slot 1 with confirmation.
	await t.click(_button(app.modals.get_top(), "SaveButton"))
	await t.click(app.modals.get_top().find_child("Slot2", true, false))
	t.check(SaveManager.get_slot_info(2).is_loadable(), "slot 2 contains a valid save")
	await t.click(_button(app.modals.get_top(), "SaveButton"))
	await t.click(app.modals.get_top().find_child("Slot1", true, false))
	t.check(app.modals.get_top() is ConfirmDialog, "overwriting an occupied slot asks for confirmation")
	await t.click(_button(app.modals.get_top(), "CancelButton"))
	t.check(app.modals.get_top() is SaveLoadMenu, "cancelling an overwrite returns to the slot list")
	await t.click(app.modals.get_top().find_child("Slot1", true, false))
	await t.click(_button(app.modals.get_top(), "ConfirmButton"))
	t.check(app.modals.get_top() is PauseMenu, "confirmed overwrite saves and closes the dialog")
	await t.click(_button(app.modals.get_top(), "ResumeButton"))

	# Change the session: different area, position and no route.
	GameSession.clear_planned_route()
	await _move_player_to(Vector2(-262, 0))
	await t.press_action(&"interact")
	await _settle()
	await _move_player_to(Vector2(0, 0))
	t.check(GameSession.has_unsaved_changes(), "changes after saving are tracked")

	# Load slot 1: asks to discard progress, then restores everything.
	await _open_pause_and_click("LoadButton")
	var load_menu := app.modals.get_top() as SaveLoadMenu
	t.check(load_menu != null and load_menu.mode == SaveLoadMenu.Mode.LOAD, "Load Game opens the load dialog")
	var empty_slot := load_menu.find_child("Slot3", true, false) as Button
	t.check(empty_slot.disabled, "empty slots cannot be loaded")
	await t.screenshot("11_load_dialog")
	await t.click(load_menu.find_child("Slot1", true, false))
	t.check(app.modals.get_top() is ConfirmDialog, "loading with unsaved progress asks for confirmation")
	await t.click(_button(app.modals.get_top(), "ConfirmButton"))
	await _settle()
	area = app.router.current_screen as BoatArea
	t.check(area != null and area.area_id == &"exterior", "loading restores the saved area (deck)")
	t.check_eq(GameSession.get_state_snapshot().to_dict(), saved_state, "loading restores the saved session state")
	if area:
		t.check(area.player.position.distance_to(Vector2(saved_state.player.position.x, saved_state.player.position.y)) < 1.0,
			"loading restores the player position")
	t.check(GameSession.get_planned_route() != null and GameSession.get_planned_route().destination_port_id == &"kiel",
		"loading restores the planned route")
	t.check(app.modals.is_empty() and not t.get_tree().paused, "game resumes after loading")
	t.check_eq(_player_count(), 1, "loading does not duplicate the player")

	# A damaged slot is reported and leaves the session untouched.
	var damaged := FileAccess.open(SaveManager.save_dir.path_join("slot_3.json"), FileAccess.WRITE)
	damaged.store_string("{\"format\": \"next_harbor_save\", \"version\": 1, \"session\": 42}")
	damaged.close()
	var state_before := GameSession.get_state_snapshot().to_dict()
	app.load_slot(3)
	await t.frames(2)
	t.check(_toast_contains("Could not load slot 3"), "loading a damaged save reports an error")
	t.check_eq(GameSession.get_state_snapshot().to_dict(), state_before, "a failed load leaves the session unchanged")
	t.check(app.router.current_screen == area, "a failed load keeps the current scene")


func _test_main_menu_return_and_continue() -> void:
	await _move_player_to(Vector2(-300, 0))
	await _open_pause_and_click("MainMenuButton")
	t.check(app.modals.get_top() is ConfirmDialog, "returning to the main menu with unsaved progress asks first")
	await t.click(_button(app.modals.get_top(), "CancelButton"))
	t.check(app.modals.get_top() is PauseMenu, "cancel keeps the game running behind the pause menu")
	await t.click(_button(app.modals.get_top(), "MainMenuButton"))
	await t.click(_button(app.modals.get_top(), "ConfirmButton"))
	await _settle()
	t.check(app.router.current_screen is MainMenu, "returns to the main menu")
	t.check(not GameSession.is_active(), "session ends on returning to the main menu")
	t.check(not t.get_tree().paused, "main menu is not paused")
	t.check_eq(_player_count(), 0, "no player remains after leaving the game")

	var menu: MainMenu = app.router.current_screen
	t.check(not _button(menu, "ContinueButton").disabled, "Continue is enabled once a valid save exists")
	t.check(not _button(menu, "LoadButton").disabled, "Load Game is enabled once a save exists")
	await t.click(_button(menu, "LoadButton"))
	t.check(app.modals.get_top() is SaveLoadMenu, "Load Game opens the slot list from the main menu")
	await t.press_action(&"pause")
	t.check(app.modals.is_empty(), "Esc closes the slot list")

	var newest := SaveManager.get_most_recent_valid_slot()
	var expected := SaveManager.load_from_slot(newest).state.to_dict()
	await t.click(_button(menu, "ContinueButton"))
	await _settle()
	t.check(app.router.current_screen is BoatArea, "Continue loads into the boat")
	t.check_eq(GameSession.get_state_snapshot().to_dict(), expected, "Continue loads the most recent save (slot %d)" % newest)

	await _open_pause_and_click("MainMenuButton")
	if app.modals.get_top() is ConfirmDialog:
		await t.click(_button(app.modals.get_top(), "ConfirmButton"))
	await _settle()

	# New Game must not touch existing save slots.
	var slot_files := {}
	for slot in [1, 2]:
		slot_files[slot] = FileAccess.get_file_as_string(SaveManager.save_dir.path_join("slot_%d.json" % slot))
	await t.click(_button(app.router.current_screen, "NewGameButton"))
	await _settle()
	var untouched := true
	for slot: int in slot_files:
		untouched = untouched and FileAccess.get_file_as_string(SaveManager.save_dir.path_join("slot_%d.json" % slot)) == slot_files[slot]
	t.check(untouched, "New Game does not overwrite manual save slots")
	t.check(GameSession.get_planned_route() == null, "New Game starts without a route")
	app.show_main_menu()
	await _settle()


func _test_quit() -> void:
	# Quitting ends this test process, so it is the last step and only runs
	# when everything else passed (the exit code must reflect failures).
	if t.failed > 0:
		return
	var menu: MainMenu = app.router.current_screen
	t.check(menu != null, "main menu is shown before quitting")
	print("\n%d checks passed, 0 failed. Pressing Quit; the process should now exit with code 0." % t.passed)
	await t.click(_button(menu, "QuitButton"))
	await t.frames(30)
	t.check(false, "Quit should have closed the application")


# --- Helpers -------------------------------------------------------------------------

func _settle() -> void:
	await t.frames(2)
	await t.wait_until(func() -> bool: return not app.router.is_busy(), 5.0)
	await t.physics_frames(3)


func _move_player_to(position: Vector2) -> void:
	var area := app.router.current_screen as BoatArea
	area.player.position = position
	await t.physics_frames(3)


func _drag(from: Vector2, to: Vector2) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = from
	t.get_viewport().push_input(press, true)
	var steps := 5
	var previous := from
	for i in range(1, steps + 1):
		var motion := InputEventMouseMotion.new()
		motion.position = from.lerp(to, float(i) / steps)
		motion.relative = motion.position - previous
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		previous = motion.position
		t.get_viewport().push_input(motion, true)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = to
	t.get_viewport().push_input(release, true)
	await t.frames(2)


func _open_pause_and_click(button_name: String) -> void:
	if not app.modals.get_top() is PauseMenu:
		await t.press_action(&"pause")
	await t.click(_button(app.modals.get_top(), button_name))


func _button(root: Node, button_name: String) -> Button:
	return root.find_child(button_name, true, false) as Button


func _player_count() -> int:
	return t.get_tree().get_nodes_in_group(&"player").size()


func _toast_contains(text: String) -> bool:
	for message in app.toasts.get_messages():
		if text in message:
			return true
	return false
