extends Node
## Application shell and flow coordinator (the project's main scene).
##
## App owns the persistent layers (current screen, HUD, modal menus,
## notifications) and connects them: menus and screens emit requests, App
## calls the services (GameSession, SaveManager) and asks the SceneRouter to
## show the right screen. It is also the single place that handles Esc, so no
## two layers ever react to the same key press.

@export var main_menu_scene: PackedScene
@export var world_map_scene: PackedScene
## Boat area id (see SessionState.BOAT_AREAS) -> scene for that area.
@export var boat_area_scenes: Dictionary[StringName, PackedScene] = {}
@export var pause_menu_scene: PackedScene
@export var settings_menu_scene: PackedScene
@export var save_load_menu_scene: PackedScene
@export var sleep_menu_scene: PackedScene
## Played on every button press, routed to the UI bus.
@export var ui_click_sound: AudioStream

@onready var router: SceneRouter = $SceneRouter
@onready var hud: Hud = $HudLayer/Hud
@onready var modals: ModalStack = $ModalLayer/ModalStack
@onready var toasts: Toasts = $ToastLayer/ToastArea/Toasts
@onready var _hud_layer: CanvasLayer = $HudLayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	$Screen.process_mode = Node.PROCESS_MODE_PAUSABLE
	for area: StringName in SessionState.BOAT_AREAS:
		if not boat_area_scenes.has(area):
			push_error("No scene registered for boat area '%s'." % area)
	get_tree().node_added.connect(_on_node_added)
	modals.stack_changed.connect(_on_modal_stack_changed)
	modals.notification_requested.connect(notify)
	hud.menu_requested.connect(open_pause_menu)
	hud.chart_requested.connect(open_chart_from_warning)
	GameSession.notice.connect(notify)
	Simulation.weather_warning.connect(_on_weather_warning)
	Simulation.arrived.connect(_on_arrived)
	router.screen_changed.connect(_on_screen_changed)
	_hud_layer.hide()
	show_main_menu()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"pause") or event.is_echo():
		return
	get_viewport().set_input_as_handled()
	if router.is_busy():
		return
	if not modals.is_empty():
		modals.handle_back()
	elif router.current_screen is BoatArea:
		open_pause_menu()
	elif router.current_screen and router.current_screen.has_method(&"handle_back"):
		router.current_screen.handle_back()


func notify(text: String) -> void:
	toasts.show_message(text)


func is_in_gameplay() -> bool:
	return GameSession.is_active() and router.current_screen is BoatArea


# --- Main flow -------------------------------------------------------------------

func show_main_menu() -> void:
	modals.clear()
	GameSession.end_session()
	AudioManager.stop_ambience()
	AudioManager.stop_music()
	router.change_screen(main_menu_scene, _connect_main_menu)


func start_new_game() -> void:
	GameSession.start_new_session()
	_show_current_boat_area()


func continue_game() -> void:
	var slot := SaveManager.get_most_recent_valid_slot()
	if slot == 0:
		notify("There is no saved game to continue.")
		return
	load_slot(slot)


## Loads a slot, asking first if the current session has unsaved progress.
func request_load(slot: int) -> void:
	if GameSession.has_unsaved_changes():
		var proceed: bool = await modals.confirm("Load this game?",
			"Progress since your last save will be lost.", "Load")
		if not proceed:
			return
	load_slot(slot)


## Validates the slot completely before anything changes; a failed load
## leaves the current session and screen exactly as they were.
func load_slot(slot: int) -> void:
	var result := SaveManager.load_from_slot(slot)
	if not result.is_ok():
		notify("Could not load slot %d. %s" % [slot, result.error])
		return
	modals.clear()
	GameSession.replace_state(result.state)
	notify("Loaded slot %d." % slot)
	_show_current_boat_area()


func request_main_menu() -> void:
	if GameSession.has_unsaved_changes():
		var proceed: bool = await modals.confirm("Return to main menu?",
			"Progress since your last save will be lost.", "Leave without saving")
		if not proceed:
			return
	show_main_menu()


func quit_game() -> void:
	# Stop sounds (e.g. this button's click) and give the audio thread a moment
	# to release them before the engine shuts down.
	AudioManager.stop_all()
	await get_tree().create_timer(0.1, true).timeout
	get_tree().quit()


# --- Boat and chart ----------------------------------------------------------------

func open_chart() -> void:
	router.change_screen(world_map_scene, _connect_world_map)


func open_chart_from_warning() -> void:
	if is_in_gameplay() and modals.is_empty() and not router.is_busy():
		open_chart()


## Leaves the chart. Unapplied course changes are only discarded after asking.
func close_chart() -> void:
	var map := router.current_screen as WorldMap
	if map and map.has_unapplied_changes():
		var leave: bool = await modals.confirm("Leave the chart?",
			"Your course changes have not been applied. The current course stays as it is.",
			"Discard changes", "Keep editing")
		if not leave:
			return
	_show_current_boat_area()


# --- Voyage ------------------------------------------------------------------------

## Asks for confirmation, then sets sail on the planned route.
func request_departure() -> void:
	var route := GameSession.get_planned_route()
	if route == null or not route.has_path():
		notify("Plot a course at the chart table before setting sail.")
		return
	var catalog := PortCatalog.get_default()
	var speed := GameSession.get_vessel_speed_kn()
	var waypoints := "" if route.waypoints.is_empty() else " via %d waypoint%s" % [
		route.waypoints.size(), "" if route.waypoints.size() == 1 else "s"]
	var go: bool = await modals.confirm("Set sail for %s?" % catalog.get_display_name(route.destination_port_id),
		"%d nm%s, about %s at %.1f knots." % [roundi(route.get_distance_nm()), waypoints,
			Simulation.format_duration(route.get_distance_nm() / speed * 3600.0), speed], "Set sail")
	if not go:
		return
	var error := GameSession.depart()
	notify(error if not error.is_empty() else "Underway to %s. The autopilot holds the course." %
		catalog.get_display_name(route.destination_port_id))


func _on_helm_requested() -> void:
	if GameSession.is_underway():
		notify("The autopilot is steering for %s, %d nm to go. Use the chart table to change course." % [
			PortCatalog.get_default().get_display_name(GameSession.get_voyage_destination_id()),
			roundi(GameSession.get_voyage_remaining_nm())])
	else:
		request_departure()


func open_sleep_menu() -> void:
	if not is_in_gameplay() or not modals.is_empty():
		return
	var menu := sleep_menu_scene.instantiate() as SleepMenu
	menu.sleep_requested.connect(sleep_for)
	modals.push(menu)


## Sleeps by advancing the normal simulation; stops early on arrival or a
## weather warning (those report themselves through their own signals).
func sleep_for(hours: float) -> void:
	modals.clear()
	var result := Simulation.sleep(hours)
	var slept := Simulation.format_duration(result.elapsed_seconds)
	var now := Simulation.format_game_time(GameSession.get_game_time())
	match result.stopped_by:
		Simulation.STOP_WARNING:
			notify("You were woken after %s by a weather warning. It is %s." % [slept, now])
		Simulation.STOP_ARRIVAL:
			notify("You were woken after %s: the boat has arrived. It is %s." % [slept, now])
		_:
			notify("You slept %s. It is %s." % [slept, now])


func _on_weather_warning(warning: Dictionary) -> void:
	hud.show_warning(warning.text)
	notify(warning.text)


func _on_arrived(port_id: StringName) -> void:
	hud.hide_warning()
	notify("Arrived in %s." % PortCatalog.get_default().get_display_name(port_id))


func _show_current_boat_area() -> void:
	var area := GameSession.get_boat_area()
	var scene: PackedScene = boat_area_scenes.get(area)
	if scene == null:
		push_error("Cannot show unknown boat area '%s'." % area)
		return
	router.change_screen(scene, _connect_boat_area)


func _on_area_change_requested(area: StringName, spawn_point: StringName) -> void:
	GameSession.enter_boat_area(area, spawn_point)
	_show_current_boat_area()


# --- Menus -------------------------------------------------------------------------

func open_pause_menu() -> void:
	if not is_in_gameplay() or router.is_busy() or not modals.is_empty():
		return
	var menu := pause_menu_scene.instantiate() as PauseMenu
	menu.save_requested.connect(open_save_menu)
	menu.load_requested.connect(open_load_menu)
	menu.settings_requested.connect(open_settings)
	menu.main_menu_requested.connect(request_main_menu)
	modals.push(menu)


func open_settings() -> void:
	modals.push(settings_menu_scene.instantiate() as ModalPanel)


func open_save_menu() -> void:
	var menu := save_load_menu_scene.instantiate() as SaveLoadMenu
	menu.setup(SaveLoadMenu.Mode.SAVE)
	modals.push(menu)


func open_load_menu() -> void:
	var menu := save_load_menu_scene.instantiate() as SaveLoadMenu
	menu.setup(SaveLoadMenu.Mode.LOAD)
	menu.load_requested.connect(request_load)
	modals.push(menu)


# --- Screen wiring -----------------------------------------------------------------

func _connect_main_menu(menu: MainMenu) -> void:
	menu.new_game_requested.connect(start_new_game)
	menu.continue_requested.connect(continue_game)
	menu.load_requested.connect(open_load_menu)
	menu.settings_requested.connect(open_settings)
	menu.quit_requested.connect(quit_game)


func _connect_boat_area(area: BoatArea) -> void:
	area.area_change_requested.connect(_on_area_change_requested)
	area.chart_requested.connect(open_chart)
	area.sleep_requested.connect(open_sleep_menu)
	area.helm_requested.connect(_on_helm_requested)
	area.message_requested.connect(notify)
	area.interaction_prompt_changed.connect(hud.set_prompt)


func _connect_world_map(map: WorldMap) -> void:
	map.close_requested.connect(close_chart)
	map.depart_requested.connect(request_departure)


func _on_screen_changed(screen: Node) -> void:
	var area := screen as BoatArea
	_hud_layer.visible = area != null
	hud.set_prompt("")
	if area:
		hud.set_area(area.area_id)
		hud.refresh()
	else:
		AudioManager.stop_ambience()
	_on_modal_stack_changed(modals.depth())


func _on_modal_stack_changed(depth: int) -> void:
	# Gameplay pauses while any menu is open over it. Menus, the HUD and
	# notifications run with PROCESS_MODE_ALWAYS and stay responsive.
	get_tree().paused = depth > 0 and is_in_gameplay()
	if depth == 0 and router.current_screen is MainMenu:
		var menu := router.current_screen as MainMenu
		menu.refresh_saves()
		menu.focus_default()


func _on_node_added(node: Node) -> void:
	var button := node as BaseButton
	if button and ui_click_sound:
		button.pressed.connect(AudioManager.play_ui.bind(ui_click_sound))
