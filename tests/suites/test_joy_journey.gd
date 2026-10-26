extends RefCounted
## Iteration 18 (SAVE-4, assignment section 23): fishing, anchoring and
## sailing together, the Captain's own example played through in order:
##   1 an anchorage waypoint marked near the coast; 2 sailing toward it;
##   3 the sails trimmed by hand; 4 a line out, trolling; 5 a bite; 6 the
##   reel-in dial; 7 the fish released below the keep threshold; 8 arriving
##   at the anchorage; 9 Long Passage time stops; 10 the anchor goes down;
##   11 the anchor ball, rode and buoy; 12 coffee below; 13 back on deck;
##   14 the companion joins; 15 save; 16 load; 17 anchor up; 18 the route
##   resumes to the harbour.
## Everything stays consistent, and after the reload nothing happens twice:
## no second arrival question, no fishing result shown again, no second walk
## up for the companion, no repeated coffee or catch.

const APP_SCENE := preload("res://src/app/app.tscn")
const Reel := preload("res://tests/helpers/reel.gd")

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
	t.set_wind(200.0, 9.0)
	await _journey()
	Simulation.stop_passage()
	Simulation.auto_advance = true
	app.queue_free()
	await t.frames(2)
	GameSession.end_session()
	t.use_calm_wind()


func _settle() -> void:
	await t.frames(2)
	await t.wait_until(func() -> bool: return not app.router.is_busy(), 5.0)
	await t.physics_frames(3)


func _show(area: StringName) -> BoatArea:
	app.modals.clear()
	GameSession.enter_boat_area(area, &"start" if area == SessionState.AREA_EXTERIOR else &"from_deck")
	app._show_current_boat_area()
	await _settle()
	return app.router.current_screen as BoatArea


func _journey() -> void:
	# 1. The anchorage waypoint, on the chart.
	app.open_chart()
	await _settle()
	var world := app.router.current_screen as WorldMap
	if not t.check(world != null, "(setup) the chart is open"):
		return
	world.set_wind_shown(false)
	world.plot_course_to(&"gothenburg")
	await t.frames(1)
	var path := world.get_draft_route().path
	var offshore := Vector2.INF
	for i in range(path.size() - 1):
		for f in [0.25, 0.5, 0.75]:
			var p: Vector2 = path[i].lerp(path[i + 1], f)
			if offshore == Vector2.INF and SeaRouter.get_default().is_point_navigable(p) and float(GameSession.anchorage_spot(p).land_nm) > AnchorSite.MAX_LAND_NM:
				offshore = p
	var index := world.insert_waypoint(world.get_draft_legs().size() - 1, offshore)
	world.toggle_anchorage(index)
	world.use_anchorage_suggestion()
	await t.frames(1)
	var spot: Vector2 = world.get_draft_waypoints()[index]
	t.check(world.is_anchorage(index) and world.apply_course() == "", "[1] a coastal anchorage waypoint on the course to Gothenburg")
	app.close_chart()
	await _settle()
	# 2-3. Under way, trimmed by hand.
	t.check_eq(GameSession.depart(), "", "[2] cast off toward it")
	Simulation.advance(900.0)
	GameSession.set_sail_trim(false, 0.5)
	t.check(not GameSession.get_sail_trim().auto and GameSession.get_vessel_speed_kn() > 0.0,
		"[3] the sails trimmed by hand (factor %.3f)" % GameSession.get_trim_factor())
	# 4-7. Trolling: a bite, the dial, released below the threshold.
	GameSession.set_keep_preferences("uncommon", &"")
	t.check(GameSession.set_line(true) == "" and GameSession.get_fishing_mode() == FishingState.MODE_TROLLING, "[4] a line out, trolling")
	var fishing_before := GameSession.get_fishing().to_dict()
	GameSession.expire_bite()
	GameSession._pending_bite = {"species": "herring", "kg": 0.3, "time": GameSession.get_game_time(), "mode": "trolling",
		"lure": "spinner", "kind": "fish", "rarity": "common"}
	await _show(SessionState.AREA_EXTERIOR)
	t.check(not GameSession.get_pending_bite().is_empty(), "[5] a bite")
	var menu: FishingMenu = app.open_fishing()
	await t.frames(3)
	t.check(menu != null and menu.is_reeling(), "[6] the reel-in dial")
	var landed := Reel.land(menu) if menu else false
	var result := menu.get_last_result() if menu else {}
	t.check(landed and not bool(result.get("kept")) and String(result.get("released_reason")) == "preferences",
		"[7] landed and let go: below the keep threshold")
	var fishing_after := GameSession.get_fishing().to_dict()
	t.check((fishing_after.hold as Array).size() == (fishing_before.hold as Array).size()
		and (fishing_after.trophies as Array).size() == (fishing_before.trophies as Array).size()
		and int(fishing_after.total_caught) == int(fishing_before.total_caught) + 1,
		"[7] nothing in the cool box or on the trophy board; counted once")
	app.modals.clear()
	GameSession.set_line(false)
	# 8-9. Long Passage time to the anchorage: it stops there.
	t.check_eq(Simulation.start_passage(Simulation.PASSAGE_RATES[1]), "", "(setup) Long Passage time")
	var guard := 0
	while not GameSession.is_holding_at_anchorage() and GameSession.is_underway() and guard < 20000:
		if not Simulation.is_passage_running():
			Simulation.start_passage(Simulation.PASSAGE_RATES[1])
		Simulation._passage_tick(0.05)
		guard += 1
	t.check(GameSession.is_holding_at_anchorage() and GameSession.get_vessel_position().distance_to(spot) < 1e-3, "[8] arrived at the anchorage")
	t.check(not Simulation.is_passage_running(), "[9] Long Passage time has stopped")
	var deck := await _show(SessionState.AREA_EXTERIOR)
	await t.frames(3)
	var prompt := app.modals.get_top() as AnchoragePrompt
	t.check(prompt != null, "[8] the arrival question")
	# 10-11. The anchor, the ball, rode and buoy.
	app.modals.clear()
	var dropped := GameSession.drop_anchor(5, 0.9)
	t.check(dropped.error == "" and GameSession.is_anchored(), "[10] the anchor goes down")
	await t.frames(2)
	t.check(deck.get_anchor_signals() != null and deck.get_anchor_signals().visible, "[11] the anchor ball, rode and buoy show")
	# 12. Coffee below.
	await _show(SessionState.AREA_INTERIOR)
	var coffee := GameSession.make_coffee()
	t.check(coffee.error == "", "[12] coffee below (%s)" % (coffee.text if coffee.error == "" else coffee.error))
	Simulation.advance(float(coffee.minutes) * 60.0)
	# 13-14. Back on deck; the companion joins.
	deck = await _show(SessionState.AREA_EXTERIOR)
	for i in 40:
		app._update_companion_follow(0.25)
		await t.frames(1)
	await t.wait_until(func() -> bool: return not deck.get_deck_companion().is_walking(), 30.0)
	t.check(GameSession.get_companion().area == CompanionState.AREA_DECK and deck.get_deck_companion().visible, "[13-14] back on deck, and the companion joins")
	# 15-16. Save and load.
	var before := GameSession.get_state_snapshot().to_dict()
	var log_before: Variant = before.get("log")
	t.check_eq(SaveManager.save_to_slot(3, GameSession.get_state_snapshot()), OK, "[15] saved")
	app.load_slot(3)
	await _settle()
	await t.frames(5)
	var after := GameSession.get_state_snapshot().to_dict()
	t.check(JSON.stringify(after.get("fishing")) == JSON.stringify(before.get("fishing")) and JSON.stringify(after.get("anchor")) == JSON.stringify(before.get("anchor"))
		and JSON.stringify(after.get("navigation")) == JSON.stringify(before.get("navigation")) and JSON.stringify(after.get("companion")) == JSON.stringify(before.get("companion"))
		and before.get("navigation") != null and before.get("companion") != null and before.get("log") != null,
		"[16] loaded: fishing, anchor, course and companion exactly as saved")
	t.check(app.modals.is_empty() and not app.is_anchorage_prompt_due(), "[16] no arrival question and no fishing result shown again")
	var companion := (app.router.current_screen as BoatArea).get_deck_companion()
	t.check(companion != null and companion.visible and not companion.is_walking(), "[16] the companion is at its place on deck (no second walk up)")
	t.check(JSON.stringify(after.get("log")) == JSON.stringify(log_before), "[16] the log has no repeated entries (catch, coffee, anchorage)")
	SaveManager.delete_slot(3)
	# 17-18. Anchor up; the route resumes to the harbour.
	t.check_eq(GameSession.raise_anchor(), "", "[17] anchor up")
	t.check_eq(GameSession.get_companion().area, CompanionState.AREA_CABIN, "[17] and the companion goes below")
	var stops := 0
	var arrived := false
	for i in 400:
		if Simulation.advance(1800.0, true).stopped_by == Simulation.STOP_ANCHORAGE:
			stops += 1
		if not GameSession.is_underway():
			arrived = GameSession.get_location_id() == &"gothenburg"
			break
	t.check(arrived and stops == 0, "[18] the route resumes and ends in Gothenburg, without stopping at the anchorage again")
	t.check(not GameSession.get_sail_trim().auto, "[18] the captain's trim was kept the whole way")
