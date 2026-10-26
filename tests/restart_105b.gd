extends Node
## Revision 0.105b (SAVE, QA): saving and loading in a new process. Each
## phase is its own process (the game quits in between):
##   godot --headless --path . res://tests/restart_105b.tscn -- --phase=write
##   godot --headless --path . res://tests/restart_105b.tscn -- --phase=read
##   godot --headless --path . res://tests/restart_105b.tscn -- --phase=art_install
##   godot --headless --path . --import            (what the editor does on opening)
##   godot --headless --path . res://tests/restart_105b.tscn -- --phase=art_read
##   godot --headless --path . res://tests/restart_105b.tscn -- --phase=art_after
##
## A - International normal anchor (slot 1): off Antigua, motoring in, the
##     normal anchor down (a GAME ESTIMATE depth), the engine stopped. Read:
##     position, anchor (kind, depth, source), engine stopped, no prompt; an
##     hour at anchor goes as in the first process; anchor up, no engine start.
## B - Magic Anchor (slot 2): fitted at the boatyard, the Magic Anchor down
##     offshore west of the Canaries after its dial (two Perfects). Read: still
##     aboard, the Magic Anchor holding with its depth and bonus, engine off,
##     no prompt; a blow comes and the holding and drag go exactly as in the
##     first process.
## C - Artwork (Sprite Workshop): a replacement PNG for Snøvs's resting pose
##     is installed, Godot imports it, a new process uses it (as an imported
##     resource), the file is removed, and the next process is back to the
##     original - nothing left behind.
## Exits 0 only if everything holds.

const APP_SCENE := preload("res://src/app/app.tscn")
const F := preload("res://tests/helpers/art_fixtures.gd")
const SAVE_DIR := "user://test_restart105b_saves"
const EXPECT_PATH := "user://test_restart105b_expect.json"
const ANTIGUA := Vector2(-61.85, 17.0)
const OPEN_SEA := Vector2(-20.0, 28.5)
const ART_ID := &"pet.snovs.resting"

var app: Node
var failures := PackedStringArray()
var wind_kn := 10.0


func _ready() -> void:
	var phase := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--phase="):
			phase = arg.trim_prefix("--phase=")
	SaveManager.save_dir = SAVE_DIR
	SessionLog.log_dir = "user://test_restart105b_diagnostics"
	Simulation.auto_advance = false
	WindField.get_default().test_override = func(_geo: Vector2, _time: float) -> WindField.Sample:
		return WindField.Sample.make(200.0, wind_kn)
	app = APP_SCENE.instantiate()
	add_child(app)
	app.router.fade_duration = 0.05
	var phases := {"write": _write, "read": _read, "art_install": _art_install, "art_read": _art_read, "art_after": _art_after}
	if phases.has(phase):
		(phases[phase] as Callable).call_deferred()
	else:
		push_error("Use --phase=write|read|art_install|art_read|art_after")
		get_tree().quit(2)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _idle() -> void:
	var guard := 0
	while app.router.is_busy() and guard < 2000:
		guard += 1
		await get_tree().process_frame
	await _frames(4)


func _json(value: Variant) -> String:
	return JSON.stringify(value, "", true)


func _close(a: Array, b: Vector2, tolerance: float) -> bool:
	return Vector2(a[0], a[1]).distance_to(b) <= tolerance


## Underway at `geo` (a short course on), engine running if `motoring`.
func _underway_at(geo: Vector2, motoring: bool) -> void:
	var state := GameSession.get_state_snapshot()
	var route := PlannedRoute.new()
	route.origin_port_id = &"copenhagen"
	route.origin_position = geo
	route.destination_port_id = &"copenhagen"
	route.path = PackedVector2Array([geo, geo + Vector2(0.0, -0.05)])
	state.voyage = Voyage.create(route, state.game_time)
	state.vessel_status = SessionState.STATUS_UNDERWAY
	state.location_id = &""
	state.vessel_position = geo
	state.planned_route = null
	state.anchor.active = false
	state.propulsion.initialised = true
	state.propulsion.mode = PropulsionState.MODE_ENGINE if motoring else PropulsionState.MODE_SAIL
	state.propulsion.speed_kn = 5.0
	GameSession.replace_state(state)


func _anchor_view() -> Dictionary:
	return {"vessel": [GameSession.get_vessel_position().x, GameSession.get_vessel_position().y], "time": GameSession.get_game_time(),
		"anchor": _json(GameSession.get_anchor().to_dict()), "mode": String(GameSession.get_propulsion().mode)}


# --- Write -----------------------------------------------------------------------

func _write() -> void:
	for slot in [1, 2]:
		SaveManager.delete_slot(slot)
	await _idle()
	app.start_new_game()
	await _idle()
	var expect := {}
	# A: international normal anchor.
	var spot := GameSession.nearest_anchorage_spot(ANTIGUA, 6.0)
	_check(spot != Vector2.INF, "A(write): an anchorage off Antigua")
	_underway_at(spot, true)
	_check(GameSession.is_motoring(), "A(write): motoring in")
	var result := GameSession.drop_anchor(5, 0.8)
	_check(result.error == "" and not GameSession.is_motoring() and GameSession.get_anchor().depth_source == DepthService.SOURCE_ESTIMATE,
		"A(write): the normal anchor down, engine stopped, depth a GAME ESTIMATE (%s)" % result.error)
	_check(SaveManager.save_to_slot(1, GameSession.get_state_snapshot()) == OK, "A(write): saved")
	expect["A"] = _anchor_view()
	Simulation.advance(3600.0)
	expect["A"]["after"] = _anchor_view()
	# B: the Magic Anchor offshore.
	GameSession.end_session()
	app.start_new_game()
	await _idle()
	_check(GameSession.fit_magic_anchor() == "", "B(write): the Magic Anchor fitted at the Copenhagen boatyard")
	_underway_at(OPEN_SEA, false)
	_check(GameSession.anchoring_refusal().contains("deep") and GameSession.anchoring_refusal(AnchorState.KIND_MAGIC) == "", "B(write): too deep for the normal anchor; the Magic Anchor may go down")
	var deployment := MagicAnchorDeployment.new(GameSession.magic_anchor_checks(), 7)
	deployment.check.angle = deployment.check.target_deg
	deployment.check.press()
	deployment.check.step(TimingCheck.DEBOUNCE + 0.01)
	deployment.check.angle = deployment.check.target_deg
	deployment.check.press()
	var magic := GameSession.drop_magic_anchor(5, deployment.set_quality(), deployment.check.perfects)
	_check(magic.error == "" and GameSession.get_anchor().kind == AnchorState.KIND_MAGIC and bool(magic.site.get("offshore", false)),
		"B(write): the Magic Anchor holds offshore (%s)" % magic.error)
	_check(SaveManager.save_to_slot(2, GameSession.get_state_snapshot()) == OK, "B(write): saved")
	expect["B"] = _anchor_view()
	wind_kn = 50.0
	Simulation.advance(2.0 * 3600.0)
	expect["B"]["after"] = _anchor_view()
	var file := FileAccess.open(EXPECT_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(expect, "", true, true))
	file.close()
	print("RESTART105B write phase done (%s)" % ("all set up" if failures.is_empty() else "; ".join(failures)))
	get_tree().quit(0 if failures.is_empty() else 1)


# --- Read ------------------------------------------------------------------------

func _read() -> void:
	var expect: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(EXPECT_PATH))
	await _idle()
	app.load_slot(1)
	await _idle()
	var a: Dictionary = expect.A
	var now := _anchor_view()
	_check(_close(a.vessel, GameSession.get_vessel_position(), 1e-6) and absf(float(a.time) - GameSession.get_game_time()) < 0.01 and now.anchor == a.anchor,
		"A: at anchor off Antigua as saved (kind normal, depth and source kept)")
	_check(now.mode == "sail" and not GameSession.is_motoring() and GameSession.engine_start_refusal() != "", "A: the engine stays off at anchor")
	_check(not app.is_anchorage_prompt_due(), "A: no anchorage prompt after loading")
	Simulation.advance(3600.0)
	_check(_json(_anchor_view()) == _json(a.after), "A: an hour at anchor goes exactly as in the first process")
	_check(GameSession.raise_anchor() == "" and not GameSession.is_motoring(), "A: anchor up; the engine is not started")
	app.load_slot(2)
	await _idle()
	var b: Dictionary = expect.B
	now = _anchor_view()
	_check(now.anchor == b.anchor and _close(b.vessel, GameSession.get_vessel_position(), 1e-6), "B: the Magic Anchor holds where it was saved, with its depth and bonus")
	_check(GameSession.has_magic_anchor() and GameSession.get_anchor().kind == AnchorState.KIND_MAGIC and GameSession.get_anchor().bonus_kn > 0.0,
		"B: still aboard after the restart")
	_check(not GameSession.is_motoring() and not app.is_anchorage_prompt_due(), "B: engine off, no prompt")
	wind_kn = 50.0
	Simulation.advance(2.0 * 3600.0)
	_check(_json(_anchor_view()) == _json(b.after), "B: the blow drags it exactly as in the first process (%s)" % GameSession.get_anchor().holding)
	print("RESTART105B %s" % ("PASS" if failures.is_empty() else "FAIL: " + "; ".join(failures)))
	for slot in [1, 2]:
		SaveManager.delete_slot(slot)
	get_tree().quit(0 if failures.is_empty() else 1)


# --- C: artwork --------------------------------------------------------------------

func _art_install() -> void:
	await _idle()
	var entry := ArtworkResolver.get_entry(ART_ID)
	F.install(entry)
	_check(FileAccess.file_exists(entry.path), "C(install): %s written" % entry.path)
	print("RESTART105B art_install done")
	get_tree().quit(0 if failures.is_empty() else 1)


func _cabin_pet_texture() -> Texture2D:
	app.start_new_game()
	await _idle()
	if GameSession.get_companion().kind != CompanionState.KIND_CAT:
		var state := GameSession.get_state_snapshot()
		state.companion = CompanionState.create(CompanionState.KIND_CAT, state.game_time)
		GameSession.replace_state(state)
	app.modals.clear()
	GameSession.enter_boat_area(SessionState.AREA_INTERIOR, &"start")
	app._show_current_boat_area()
	await _idle()
	var pet := app.router.current_screen.find_child("Companion", true, false) as ShipCompanion
	return pet.get_pose_texture(CompanionVisualSet.POSE_RESTING) if pet else null


func _art_read() -> void:
	await _idle()
	var entry := ArtworkResolver.get_entry(ART_ID)
	_check(ResourceLoader.exists(entry.path), "C: after Godot's import the PNG is an imported resource (the editor workflow)")
	var texture := await _cabin_pet_texture()
	_check(F.is_fixture(texture) and ArtworkResolver.get_warnings().is_empty(), "C: a new process shows Snøvs with the replacement, no warnings")
	F.remove(entry)
	_check(not FileAccess.file_exists(entry.path) and not FileAccess.file_exists(entry.path + ".import"), "C: the replacement and its import file removed")
	print("RESTART105B art_read %s" % ("PASS" if failures.is_empty() else "FAIL: " + "; ".join(failures)))
	get_tree().quit(0 if failures.is_empty() else 1)


func _art_after() -> void:
	await _idle()
	var texture := await _cabin_pet_texture()
	_check(texture != null and not F.is_fixture(texture), "C: the next process is back to Snøvs's own picture")
	_check(F.installed_pngs().is_empty() and ArtworkResolver.get_warnings().is_empty(), "C: nothing left installed, no warnings")
	print("RESTART105B art_after %s" % ("PASS" if failures.is_empty() else "FAIL: " + "; ".join(failures)))
	get_tree().quit(0 if failures.is_empty() else 1)


func _check(condition: bool, text: String) -> void:
	print("RESTART105B %s %s" % ["ok  " if condition else "FAIL", text])
	if not condition:
		failures.append(text)
