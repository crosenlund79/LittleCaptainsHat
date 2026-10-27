extends Node
## Iteration 18 (PASS): how often Long Passage time stops on an ocean
## passage (Copenhagen to Las Palmas, the real wind, 12 game hours per real
## second, 12 game days), resuming after every stop, by reason: without
## fishing, trolling with "Stop for every bite", and with "Stop only for fish
## worth keeping" (keep Rare or better). Prints one PACE line per run.
##   godot --headless --path . res://tests/pacing_18.tscn
const APP_SCENE := preload("res://src/app/app.tscn")
var app: Node
var reasons := {}
func _ready() -> void:
	SaveManager.save_dir = "user://test_saves"
	_run.call_deferred()
func _on_interrupted(reason: StringName, _text: String) -> void:
	reasons[reason] = int(reasons.get(reason, 0)) + 1
func _sail(posture: StringName, line: bool) -> Dictionary:
	reasons = {}
	app.start_new_game()
	for i in 5: await get_tree().process_frame
	WindField.get_default().test_override = Callable()
	GameSession.set_passage_posture(posture)
	GameSession.set_keep_preferences("rare", &"")
	GameSession.plan_route_to(&"las_palmas")
	GameSession.depart()
	Simulation.advance(1800.0)
	if line:
		GameSession.set_line(true, "spinner")
	var ticks := 0
	var start := GameSession.get_game_time()
	while GameSession.is_underway() and GameSession.get_game_time() - start < 12.0 * 86400.0 and ticks < 200000:
		if not Simulation.is_passage_running():
			if GameSession.get_pending_bite().size() > 0:
				GameSession.expire_bite()
			if GameSession.is_anchored():
				break
			if line and not GameSession.is_line_out():
				GameSession.set_line(true, "spinner")
			Simulation.start_passage(Simulation.PASSAGE_RATES[2])
		Simulation._passage_tick(0.1)
		ticks += 1
		if line and not GameSession.is_line_out() and ticks % 20 == 0:
			GameSession.set_line(true, "spinner")
	var f := GameSession.get_fishing()
	return {"posture": posture, "line": line, "days": (GameSession.get_game_time() - start) / 86400.0, "stops": reasons.duplicate(),
		"nibbles": GameSession.take_quiet_nibbles()}
func _run() -> void:
	Simulation.auto_advance = false
	app = APP_SCENE.instantiate()
	add_child(app)
	app.router.fade_duration = 0.05
	for i in 5: await get_tree().process_frame
	Simulation.passage_interrupted.connect(_on_interrupted)
	for spec in [[FishingState.PASSAGE_ALL, false], [FishingState.PASSAGE_ALL, true], [FishingState.PASSAGE_KEEPERS, true]]:
		print("PACE ", await _sail(spec[0], spec[1]))
	get_tree().quit()
