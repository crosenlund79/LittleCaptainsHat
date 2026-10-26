extends Node
## Iteration 17: renders the review screenshots of Let There Be Light into
## docs/screenshots/iteration17/ (run rendered, e.g. under Xvfb):
##   godot --path . --resolution 1600x900 res://tests/screenshots_17.tscn
##   ... -- --only=cabin        (only the shots whose name contains "cabin")
## Uses the test save folder; never touches the player's saves.

const APP_SCENE := preload("res://src/app/app.tscn")
const OUT := "res://docs/screenshots/iteration17"
const BOATS: Array[StringName] = [&"arctic_wanderer_26", &"starling_33", &"petrel_36", &"halcyon_40"]

var app: Node
var only := ""


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			only = arg.trim_prefix("--only=")
	SaveManager.save_dir = "user://test_saves"
	SessionLog.log_dir = "user://test_diagnostics"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_run.call_deferred()


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _wanted(file_name: String) -> bool:
	return only.is_empty() or only in file_name


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


func _show(area: StringName, spawn := &"start") -> BoatArea:
	app.modals.clear()
	GameSession.enter_boat_area(area, spawn)
	app._show_current_boat_area()
	await _idle()
	await _frames(4)
	return app.router.current_screen as BoatArea


func _board(id: StringName) -> void:
	var state := GameSession.get_state_snapshot()
	state.vessel_id = id
	GameSession.replace_state(state)


func _run() -> void:
	Simulation.auto_advance = false
	app = APP_SCENE.instantiate()
	add_child(app)
	app.router.fade_duration = 0.05
	await _frames(5)
	app.start_new_game()
	await _idle()
	app.toasts.clear()
	for id in BOATS:
		var name := "cabin_world_map_%s" % id
		if not _wanted(name):
			continue
		_board(id)
		var cabin := await _show(SessionState.AREA_INTERIOR)
		var station := cabin.find_child("WorldMap", true, false) as Interactable
		cabin.player.position = station.position
		await _frames(10)
		await _shot(name)
	get_tree().quit(0)
