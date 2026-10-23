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


func close_chart() -> void:
	_show_current_boat_area()


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
	area.message_requested.connect(notify)
	area.interaction_prompt_changed.connect(hud.set_prompt)


func _connect_world_map(map: WorldMap) -> void:
	map.close_requested.connect(close_chart)


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
