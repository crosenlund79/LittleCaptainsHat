extends RefCounted
## Iteration 13: one voyage through the whole of "The Catch & The Cove", the
## way a player would play it, through the stations and panels: depart, troll
## a lure behind the boat, land a fish, anchor near the coast, cook it for
## supper, sleep at anchor and wake, raise the anchor, sail on, and save and
## load on the way. Then the same evening in rough weather.

const APP_SCENE := preload("res://src/app/app.tscn")
const Reel := preload("res://tests/helpers/reel.gd")
const W := preload("res://tests/helpers/walkability.gd")
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
	await _journey()
	await _rough_evening()
	Simulation.auto_advance = true
	app.queue_free()
	await t.frames(2)
	GameSession.end_session()
	t.use_calm_wind()


func _settle() -> void:
	await t.frames(2)
	await t.wait_until(func() -> bool: return not app.router.is_busy(), 5.0)
	await t.physics_frames(3)


func _show(area: StringName, spawn: StringName) -> BoatArea:
	app.modals.clear()
	GameSession.enter_boat_area(area, spawn)
	app._show_current_boat_area()
	await _settle()
	return app.router.current_screen as BoatArea


## Walks to the station (nearest usable spot) and presses E there.
func _use(area: BoatArea, station_name: String) -> ModalPanel:
	var station := area.get_node("Layout/Stations/%s" % station_name) as Interactable
	var points := W.use_points(station, W.walkable_cells(area, area.player.position, 5.0))
	if points.is_empty():
		return null
	area.player.position = points[0]
	await t.physics_frames(4)
	if area.player.get_focused_interactable() != station:
		return null
	station.interact(area.player)
	await t.frames(2)
	return app.modals.get_top()


## Reels the catch in through the dial (Iteration 18).
func _land(menu: FishingMenu) -> bool:
	return Reel.land(menu)


func _journey() -> void:
	t.set_wind(90.0, 9.0)
	# Depart for Malmö through the Øresund.
	GameSession.plan_route_to(&"malmo")
	t.check_eq(GameSession.depart(), "", "[journey] depart Copenhagen for Malmö")
	Simulation.advance(900.0)
	var deck := await _show(DECK, &"start")
	# Troll: the line out at the rod, then the boat sails on.
	var rod := await _use(deck, "Fishing") as FishingMenu
	if not t.check(rod != null and rod.get_info_text().begins_with("Trolling"), "[journey] at the rod underway: trolling"):
		return
	(rod.find_child("LineButton", true, false) as Button).pressed.emit()
	t.check(GameSession.is_line_out() and GameSession.get_fishing().line_mode == FishingState.MODE_TROLLING, "[journey] the lure trails astern")
	app.modals.clear()
	var progress := GameSession.get_voyage_progress_nm()
	var bit := false
	for i in 120:
		var result := Simulation.advance(300.0)
		if result.bite:
			bit = true
			break
		if not GameSession.is_underway():
			break
	t.check(bit and GameSession.get_voyage_progress_nm() > progress, "[journey] a fish bites while the boat sails on")
	if not bit:
		return
	t.check(app.get_bite_wait() > 0.0, "[journey] \"Fish on!\": time to go to the rod")
	rod = await _use(deck, "Fishing") as FishingMenu
	t.check(rod != null and rod.is_reeling(), "[journey] at the rod the reel-in is on")
	t.check(rod != null and _land(rod), "[journey] the fish is landed")
	var fish := rod.get_last_result().get("fish", {}) as Dictionary
	(rod.find_child("LineButton", true, false) as Button).pressed.emit()
	t.check(not GameSession.is_line_out(), "[journey] line in")
	app.modals.clear()
	# Save on the way and load it back.
	t.check_eq(SaveManager.save_to_slot(3, GameSession.get_state_snapshot()), OK, "(setup) saved underway with a fish aboard")
	app.load_slot(3)
	await _settle()
	t.check(GameSession.get_fishing().find_in_hold(int(fish.uid)) >= 0, "[journey] after loading the fish is still in the cool box, once")
	deck = app.router.current_screen as BoatArea
	if deck == null or deck.area_id != DECK:
		deck = await _show(DECK, &"start")
	# Anchor near the coast.
	var near := false
	for i in 120:
		if GameSession.evaluate_anchorage().ok:
			near = true
			break
		Simulation.advance(300.0)
		if not GameSession.is_underway():
			break
	if not t.check(near, "[journey] the boat comes near enough a coast to anchor"):
		return
	var anchor := await _use(deck, "Anchor") as AnchorMenu
	if not t.check(anchor != null, "[journey] at the windlass"):
		return
	anchor.set_scope(5)
	anchor.start_setting(true)
	var dropped := anchor.catch_set(0.48)
	t.check(dropped.get("error", "x") == "" and GameSession.is_anchored(), "[journey] the anchor is down: %s" % AnchorSite.holding_text(GameSession.get_anchor().holding))
	app.modals.clear()
	var anchored_at := GameSession.get_voyage_progress_nm()
	# Supper: cook the catch in the galley.
	var cabin := await _show(CABIN, &"from_deck")
	var galley := await _use(cabin, "Cook") as CookingMenu
	if not t.check(galley != null, "[journey] at the stove"):
		return
	galley.select_recipe("pan_fried_fish")
	(galley.find_child("CookButton", true, false) as Button).pressed.emit()
	var meal := galley.serve()
	t.check(meal.error == "" and meal.evening and galley.get_outcome_text().contains("A quiet evening at anchor. Fresh fish for supper."),
		"[journey] supper from the catch at anchor: \"A quiet evening at anchor. Fresh fish for supper.\"")
	t.check(GameSession.get_fishing().find_in_hold(int(fish.uid)) < 0, "[journey] the fish was used, once")
	app.modals.clear()
	# Sleep at anchor and wake.
	var night := GameSession.get_game_time()
	app.sleep_for(9.0)
	await _settle()
	t.check(is_equal_approx(GameSession.get_game_time() - night, 9.0 * 3600.0) and GameSession.is_anchored(), "[journey] a quiet night at anchor")
	t.check(is_equal_approx(GameSession.get_voyage_progress_nm(), anchored_at), "[journey] the voyage waited")
	var log_texts := GameSession.get_aboard_moments().map(func(m: Dictionary) -> String: return String(m.text))
	t.check(log_texts.size() >= 3, "[journey] the Captain's Log remembers the day (%s)" % [log_texts])
	# Raise the anchor and sail on.
	deck = await _show(DECK, &"start")
	anchor = await _use(deck, "Anchor") as AnchorMenu
	(anchor.find_child("RaiseButton", true, false) as Button).pressed.emit()
	t.check(not GameSession.is_anchored(), "[journey] the anchor comes up")
	app.modals.clear()
	Simulation.advance(1800.0)
	t.check(GameSession.get_voyage_progress_nm() > anchored_at or not GameSession.is_underway(), "[journey] and the boat sails on")
	t.check_eq(SaveManager.save_to_slot(3, GameSession.get_state_snapshot()), OK, "(setup) saved after the night")
	var before := JSON.stringify(GameSession.get_state_snapshot().to_dict())
	app.load_slot(3)
	await _settle()
	t.check(JSON.stringify(JSON.parse_string(JSON.stringify(GameSession.get_state_snapshot().to_dict()))) == JSON.stringify(JSON.parse_string(before)),
		"[journey] and the whole day saves and loads exactly")
	SaveManager.delete_slot(3)


func _rough_evening() -> void:
	GameSession.end_session()
	app.start_new_game()
	await _settle()
	t.set_wind(90.0, 9.0)
	GameSession.plan_route_to(&"malmo")
	GameSession.depart()
	var near := false
	for i in 120:
		Simulation.advance(300.0)
		if GameSession.evaluate_anchorage().ok:
			near = true
			break
	if not t.check(near, "(setup) near the coast again"):
		return
	t.set_wind(90.0, 38.0)
	t.check(GameSession.anchoring_refusal().contains("Too much wind"), "[weather] in a gale the anchor is not offered (%s)" % GameSession.anchoring_refusal())
	t.check(GameSession.cooking_refusal() != "", "[weather] nor the stove underway")
	t.set_wind(90.0, 9.0)
	t.check_eq(GameSession.drop_anchor(3, 0.2).error, "", "(setup) anchored on short chain, barely set")
	# The wind rises in the night: the alarm wakes the captain before anything breaks.
	var start := GameSession.get_game_time()
	WindField.get_default().test_override = func(_geo: Vector2, time: float) -> WindField.Sample:
		return WindField.Sample.make(90.0, 9.0 + clampf((time - start) / 3600.0, 0.0, 6.0) * 5.0)
	Simulation.invalidate_estimates()
	var hull := GameSession.get_condition()
	# Forecast warnings wake the captain too; they go back to sleep each time.
	for i in 6:
		app.sleep_for(10.0)
		await _settle()
		if GameSession.get_anchor().alarm or GameSession.get_game_time() - start >= 10.0 * 3600.0:
			break
	var slept := GameSession.get_game_time() - start
	t.check(slept < 10.0 * 3600.0 and GameSession.get_anchor().alarm and app.toasts.get_messages()[-1].contains("anchor alarm"),
		"[weather] the anchor alarm woke the captain after %s (%s)" % [Simulation.format_duration(slept), app.toasts.get_messages()[-1]])
	t.check(GameSession.get_condition() >= hull - 5.0 and GameSession.is_anchored(), "[weather] no teleport, no sudden loss: still at anchor, hull %d %%" % roundi(GameSession.get_condition()))
	t.check(String(app.toasts.get_messages()[-1]).contains("Go up to the windlass"), "[weather] the wake-up says what to do")
	t.check(GameSession.get_anchor().holding in [AnchorState.HOLDING_POOR, AnchorState.HOLDING_DRAGGING], "[weather] woken at %s, before it gets worse" % AnchorSite.holding_text(GameSession.get_anchor().holding).to_lower())
	t.use_calm_wind()
	GameSession.raise_anchor()
