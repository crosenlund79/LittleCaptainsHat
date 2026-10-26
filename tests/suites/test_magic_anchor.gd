extends RefCounted
## Revision 0.105b (MAGIC, SKILL, NANCH engine-off): the Magic Anchor and
## anchoring with the engine stopped.
##   - the shared circular timing check: constant needle, Perfect, misses,
##     deterministic arcs; the reel still uses it unchanged;
##   - prototype access: fitted free in Boat care at a boatyard, kept by the
##     captain (a progress mark, no new save field), every boat;
##   - the windlass: "Magic Anchor" only when aboard; checks by the wind
##     (1 / 2 / 3); a miss costs game time; failed -> still unanchored, retry;
##     cancel -> nothing let go; success -> the one anchored state, depth kept
##     as the GAME ESTIMATE (not falsified), bounded Perfect bonus;
##   - offshore: holds position, says it is no shelter; dragging uses the same
##     holding model and one alarm;
##   - engine: anchoring (normal or Magic) stops it; it cannot run at anchor
##     ("Let's raise the anchor before starting the engine."); raising does not
##     start it; an old save at anchor with the engine running loads stopped;
##   - save/load at the meaningful transitions; no prompt after loading.

const APP_SCENE := preload("res://src/app/app.tscn")
const OPEN_SEA := Vector2(-30.0, 30.0)
const SHOTS := [
	"rb_09_magic_anchor_fitting_boatyard",
	"rb_10_magic_anchor_deployment_dial",
	"rb_11_magic_anchor_failed_retry",
	"rb_12_magic_anchor_holding_offshore",
]

var t: Node
var app: Node


func run(runner: Node) -> void:
	t = runner
	_test_timing_check()
	Simulation.auto_advance = false
	app = APP_SCENE.instantiate()
	t.add_child(app)
	app.router.fade_duration = 0.05
	await _settle()
	app.start_new_game()
	await _settle()
	t.use_calm_wind()
	await _test_fitting()
	await _test_deployment()
	await _test_engine_and_normal_anchor()
	await _test_offshore_drag_and_saves()
	Simulation.auto_advance = true
	app.queue_free()
	await t.frames(2)
	GameSession.end_session()
	t.use_calm_wind()


func _settle() -> void:
	await t.frames(2)
	await t.wait_until(func() -> bool: return not app.router.is_busy(), 5.0)
	await t.physics_frames(3)


## A screenshot without the test set-up's own notices (re-planning toasts).
func _shot(file_name: String) -> void:
	app.toasts.clear()
	await t.frames(2)
	await t.screenshot(file_name)


## The boat underway at `geo` (a short course on from there), engine running if `motoring`.
func _underway_at(geo: Vector2, motoring := false) -> void:
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


# --- The shared timing check --------------------------------------------------------------

func _test_timing_check() -> void:
	var a := TimingCheck.new(2, 60.0, 4)
	var b := TimingCheck.new(2, 60.0, 4)
	t.check(is_equal_approx(a.target_deg, b.target_deg), "[skill] the same seed places the same arc (deterministic)")
	a.step(1.0)
	t.check(is_equal_approx(a.angle, TimingCheck.SPEED_DEG), "[skill] the needle turns at one constant speed (%.0f deg/s)" % TimingCheck.SPEED_DEG)
	a.angle = a.target_deg
	t.check_eq(a.press(), TimingCheck.PRESS_PERFECT, "[skill] in the middle: Perfect")
	a.step(TimingCheck.DEBOUNCE + 0.01)
	a.angle = fposmod(a.target_deg + 90.0, 360.0)
	t.check_eq(a.press(), TimingCheck.PRESS_MISS, "[skill] outside the arc: a miss")
	t.check(not a.is_over() and a.get_line_control() == a.line_control - 1, "[skill] one miss is not the end")
	t.check(ReelTiming.new(1, 50.0, 1) is TimingCheck, "[skill] the fishing reel is the same component with its own rules")
	var d := MagicAnchorDeployment.new(3, 9)
	t.check(d.check.checks_needed == 3 and d.check.arc_deg >= MagicAnchorDeployment.ARC_STORM_DEG and d.check.line_control == MagicAnchorDeployment.MISSES_ALLOWED,
		"[skill] a storm deployment: 3 checks, the arc no narrower than %d°, %d misses allowed" % [roundi(MagicAnchorDeployment.ARC_STORM_DEG), MagicAnchorDeployment.MISSES_ALLOWED])
	t.check(MagicAnchorDeployment.arc_for(1) > MagicAnchorDeployment.arc_for(2) and MagicAnchorDeployment.arc_for(2) > MagicAnchorDeployment.arc_for(3),
		"[skill] calmer weather, wider arc")
	var speed_before := d.check.angle
	d.check.step(0.5)
	d.check.step(0.5)
	t.check(is_equal_approx(d.check.angle - speed_before, TimingCheck.SPEED_DEG), "[skill] the needle never speeds up in a storm")


# --- Prototype access ---------------------------------------------------------------------

func _test_fitting() -> void:
	t.check(not GameSession.has_magic_anchor(), "[magic] a new game has no Magic Anchor (the normal anchor is enough to play)")
	t.check(GameSession.anchoring_refusal(AnchorState.KIND_MAGIC) != "", "[magic] without it, it cannot be chosen")
	# Copenhagen has a boatyard: Boat care offers it free (prototype).
	var menu := app.open_boat_care() as BoatCareMenu
	if not t.check(menu != null, "(setup) Boat care opens at the Copenhagen boatyard"):
		return
	await t.frames(3)
	var button := menu.get_magic_anchor_button()
	t.check(button != null and button.text.contains("free") and not button.disabled, "[magic] Boat care offers the Magic Anchor, free for now (%s)" % (button.text if button else ""))
	var funds := GameSession.get_funds()
	await t.screenshot(SHOTS[0])
	button.pressed.emit()
	await t.frames(2)
	t.check(GameSession.has_magic_anchor() and GameSession.get_funds() == funds, "[magic] fitted, and nothing is charged")
	t.check(button.disabled and button.text == "Aboard", "[magic] then shown as aboard")
	app.modals.clear()
	# Kept by the captain: every boat can use it.
	t.check_eq(GameSession.switch_vessel(&"halcyon_40"), "", "(setup) aboard the Clam 40")
	t.check(GameSession.has_magic_anchor(), "[magic] changing boats keeps it (every vessel can use it)")
	GameSession.switch_vessel(&"arctic_wanderer_26")
	await _settle()


# --- Deployment at the windlass -----------------------------------------------------------

func _test_deployment() -> void:
	_underway_at(OPEN_SEA)
	t.set_wind(200.0, 10.0)
	await t.frames(2)
	t.check(GameSession.anchoring_refusal().contains("too deep"), "[magic] out at sea the normal anchor cannot reach the bottom (%s)" % GameSession.anchoring_refusal())
	t.check_eq(GameSession.anchoring_refusal(AnchorState.KIND_MAGIC), "", "[magic] the Magic Anchor can go down here (open water, wind 10 kn)")
	var menu := app.open_anchor() as AnchorMenu
	if not t.check(menu != null, "(setup) the anchor panel opens"):
		return
	await t.frames(2)
	var magic := menu.find_child("MagicButton", true, false) as Button
	var drop := menu.find_child("DropButton", true, false) as Button
	t.check(magic.visible and not magic.disabled and drop.disabled, "[magic] the windlass offers the Magic Anchor; the normal drop is unavailable")
	# Cancel: nothing let go.
	menu.start_magic()
	t.check(menu.is_deploying_magic() and menu.get_deployment().check.checks_needed == 1, "[magic] in 10 kn: one good turn")
	menu.cancel_magic()
	t.check(not menu.is_deploying_magic() and not GameSession.is_anchored() and not GameSession.is_holding_at_anchorage(), "[magic] cancelled: nothing let go, the boat as it was")
	# Fail: three misses -> still unanchored; time spent per miss.
	t.set_wind(200.0, 20.0)
	menu.refresh()
	menu.start_magic()
	var deployment := menu.get_deployment()
	t.check(deployment.check.checks_needed == 2, "[magic] in 20 kn: two good turns")
	var before := GameSession.get_game_time()
	for i in MagicAnchorDeployment.MISSES_ALLOWED:
		deployment.check.angle = fposmod(deployment.check.target_deg + 180.0, 360.0)
		menu.press_magic()
		deployment.check.step(TimingCheck.DEBOUNCE + 0.01)
	t.check(deployment.failed() and not GameSession.is_anchored(), "[magic] three misses: it has not bitten, the boat is not anchored")
	t.check(GameSession.get_game_time() - before >= MagicAnchorDeployment.MISS_MINUTES * 60.0 * MagicAnchorDeployment.MISSES_ALLOWED - 1.0,
		"[magic] each miss cost %d game minutes" % roundi(MagicAnchorDeployment.MISS_MINUTES))
	var retry := menu.find_child("MagicRetry", true, false) as Button
	var feedback := (menu.find_child("MagicFeedback", true, false) as Label).text
	t.check(retry.visible and feedback.contains("not anchored"), "[magic] the captain is told and may try again (%s)" % feedback)
	await t.frames(2)
	await _shot(SHOTS[2])
	# Retry: a fresh dial; two Perfects.
	retry.pressed.emit()
	deployment = menu.get_deployment()
	t.check(deployment != null and not deployment.is_over() and deployment.attempts == 2, "[magic] a retry gives a fresh dial")
	deployment.check.angle = deployment.check.target_deg
	t.check_eq(menu.press_magic(), TimingCheck.PRESS_PERFECT, "[magic] Perfect")
	await t.frames(2)
	await _shot(SHOTS[1])
	deployment.check.step(TimingCheck.DEBOUNCE + 0.01)
	deployment.check.angle = deployment.check.target_deg
	menu.press_magic()
	t.check(GameSession.is_anchored() and GameSession.get_anchor().kind == AnchorState.KIND_MAGIC, "[magic] success: anchored, with the Magic Anchor")
	var anchor := GameSession.get_anchor()
	var site := AnchorSite.evaluate(anchor.position, Simulation.get_weather_at_vessel(), true)
	t.check(is_equal_approx(anchor.depth_m, float(site.depth_m)) and anchor.depth_m > AnchorSite.NORMAL_MAX_DEPTH_M and anchor.depth_source == DepthService.SOURCE_ESTIMATE,
		"[magic] the depth is kept as it is, %s (GAME ESTIMATE), not falsified" % DepthService.describe_depth(anchor.depth_m))
	t.check(is_equal_approx(anchor.bonus_kn, 2.0) and anchor.bonus_kn <= AnchorState.MAGIC_BONUS_MAX_KN, "[magic] two Perfects: a modest bounded holding bonus (%.0f kn)" % anchor.bonus_kn)
	var toast: String = app.toasts.get_messages()[-1]
	t.check(toast.contains("no shelter"), "[magic] offshore it says it holds position, not shelter (%s)" % toast)
	t.check(not GameSession.is_motoring() and GameSession.get_vessel_speed_kn() == 0.0, "[engine] anchored: the boat is still, the engine off")
	await t.get_tree().create_timer(1.3).timeout
	menu.refresh()
	await t.frames(2)
	t.check(menu.get_site_text().contains("Magic Anchor holds") and menu.get_site_text().contains("GAME ESTIMATE"), "[magic] the panel says the Magic Anchor holds, depth a GAME ESTIMATE")
	t.check(not (menu.find_child("MagicDeploy", true, false) as Control).visible, "[magic] the dial is put away after the brass flourish")
	app.modals.clear()


# --- The engine and the normal anchor -----------------------------------------------------

func _test_engine_and_normal_anchor() -> void:
	# Raise: no engine start.
	t.check_eq(GameSession.engine_start_refusal(), "Let's raise the anchor before starting the engine.", "[engine] at anchor the engine may not start")
	Simulation.advance(3600.0)
	t.check(not GameSession.is_motoring() and GameSession.get_propulsion().mode == PropulsionState.MODE_SAIL,
		"[engine] an hour at anchor: still no engine (no crew automation, no Long Passage)")
	t.check_eq(GameSession.raise_anchor(), "", "[engine] the anchor comes up")
	t.check(not GameSession.is_motoring() and GameSession.engine_start_refusal() == "", "[engine] raised: the engine is free again but not started")
	# Normal anchor near Nyborg with the engine running.
	var spot := GameSession.nearest_anchorage_spot(Vector2(10.95, 55.35), 6.0)
	if not t.check(spot != Vector2.INF, "(setup) an anchorage off Nyborg"):
		return
	t.set_wind(200.0, 8.0)
	_underway_at(spot, true)
	t.check(GameSession.is_motoring(), "(setup) motoring towards the anchorage")
	t.check(GameSession.drop_anchor(5, 0.8).error == "" and GameSession.get_anchor().kind == AnchorState.KIND_NORMAL, "[engine] the normal anchor goes down")
	t.check(not GameSession.is_motoring() and GameSession.get_propulsion().mode == PropulsionState.MODE_SAIL, "[engine] the engine stops on anchoring (normal)")
	GameSession.raise_anchor()
	# Waiting at an anchorage is not anchoring: the engine is not stopped by arriving alone.
	t.check(not GameSession.is_anchored(), "(setup) weighed")
	# Magic at a motoring boat: also stops.
	_underway_at(OPEN_SEA, true)
	t.check(GameSession.is_motoring(), "(setup) motoring at sea")
	t.check(GameSession.drop_magic_anchor(5, 0.6, 0).error == "" and not GameSession.is_motoring(), "[engine] the engine stops on anchoring (Magic)")
	# An old save at anchor with the engine running loads with it stopped.
	var state := GameSession.get_state_snapshot()
	state.propulsion.mode = PropulsionState.MODE_ENGINE
	state.propulsion.speed_kn = 5.0
	t.check_eq(SaveManager.save_to_slot(3, state), OK, "(setup) an older-style save: anchored, engine running")
	app.load_slot(3)
	await _settle()
	t.check(GameSession.is_anchored() and GameSession.get_propulsion().mode == PropulsionState.MODE_SAIL and not GameSession.is_motoring(),
		"[engine] loaded: still anchored, the engine set to stopped")
	GameSession.raise_anchor()


# --- Offshore holding, dragging and saves -------------------------------------------------

func _test_offshore_drag_and_saves() -> void:
	_underway_at(OPEN_SEA)
	t.set_wind(200.0, 12.0)
	t.check(GameSession.drop_magic_anchor(7, 1.0, 1).error == "", "(setup) the Magic Anchor down offshore")
	await t.frames(3)
	await _shot(SHOTS[3])
	# Save/load at anchor: same state, no prompt.
	t.check_eq(SaveManager.save_to_slot(3, GameSession.get_state_snapshot()), OK, "[save] saved with the Magic Anchor down")
	app.load_slot(3)
	await _settle()
	var anchor := GameSession.get_anchor()
	t.check(GameSession.is_anchored() and anchor.kind == AnchorState.KIND_MAGIC and is_equal_approx(anchor.bonus_kn, 1.0) and anchor.depth_m > 25.0,
		"[save] loaded: the Magic Anchor still holds, with its depth and bonus")
	t.check(not app.is_anchorage_prompt_due() and not (app.modals.get_top() is AnchoragePrompt), "[save] no anchorage prompt after loading")
	t.check(GameSession.has_magic_anchor(), "[save] the Magic Anchor stays aboard after loading")
	# A gale offshore: same holding model, it drags; one alarm.
	var alarms := []
	var on_alarm := func(alarm: Dictionary) -> void: alarms.append(alarm)
	GameSession.anchor_alarm.connect(on_alarm)
	t.set_wind(200.0, 50.0)
	Simulation.advance(2.0 * 3600.0)
	anchor = GameSession.get_anchor()
	t.check(anchor.holding == AnchorState.HOLDING_DRAGGING and anchor.dragged_nm > 0.0, "[magic] in 50 kn of open-sea wind even the Magic Anchor drags (%s, %.2f nm)" % [anchor.holding, anchor.dragged_nm])
	t.check(alarms.size() >= 1 and alarms.size() <= 2, "[magic] the existing alarm sounds (not once per check: %d)" % alarms.size())
	t.check(SeaRouter.get_default().is_afloat(GameSession.get_vessel_position()), "[magic] dragging never puts the boat on land")
	GameSession.anchor_alarm.disconnect(on_alarm)
	t.check_eq(SaveManager.save_to_slot(3, GameSession.get_state_snapshot()), OK, "[save] saved while dragging")
	app.load_slot(3)
	await _settle()
	t.check(GameSession.is_anchored() and GameSession.get_anchor().holding == AnchorState.HOLDING_DRAGGING, "[save] loaded: still at anchor, still dragging")
	t.check(not GameSession.is_motoring(), "[engine] and still no engine")
	# Raised: the underway state is back, the equipment remains.
	t.set_wind(200.0, 10.0)
	t.check(GameSession.raise_anchor() == "" and not GameSession.is_anchored() and GameSession.has_magic_anchor(), "[magic] raised; the Magic Anchor is kept for next time")
	SaveManager.delete_slot(3)
	t.use_calm_wind()
