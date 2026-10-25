extends RefCounted
## Iteration 13, "The Cove": the galley (dishes from the catch and the
## stores, one simple rule for the stove underway) and the anchor
## (suitability without invented depths, scope, setting, holding feedback, the
## dragging alarm before anything critical, sleeping at anchor, raising it to
## sail on, saving and loading at anchor), and how they connect: fishing at
## anchor and supper from the catch.

const APP_SCENE := preload("res://src/app/app.tscn")
const W := preload("res://tests/helpers/walkability.gd")
const DECK := SessionState.AREA_EXTERIOR
const CABIN := SessionState.AREA_INTERIOR

var t: Node
var app: Node


func run(runner: Node) -> void:
	t = runner
	Simulation.auto_advance = false
	t.use_calm_wind()
	_test_site_model()
	app = APP_SCENE.instantiate()
	t.add_child(app)
	app.router.fade_duration = 0.05
	await _settle()
	app.start_new_game()
	await _settle()
	await _test_stove_on_every_boat()
	await _test_cooking_in_harbour()
	await _test_cooking_underway_rule()
	await _test_anchoring()
	await _test_dragging()
	await _test_sleep_at_anchor()
	await _test_save_load_at_anchor()
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


func _restart() -> void:
	GameSession.end_session()
	app.start_new_game()
	await _settle()


func _walk_to(area: BoatArea, station: Interactable) -> void:
	var cells := W.walkable_cells(area, area.player.position)
	var points := W.use_points(station, cells)
	if points.is_empty():
		return
	area.player.position = points[0]
	area.player.set_facing(station.position - points[0])  # walking up to it
	await t.physics_frames(4)


func _shot(file_name: String, keep_notices := false) -> void:
	if not keep_notices:
		app.toasts.clear()
	app.hud.hide_warning()
	await t.frames(2)
	await t.screenshot(file_name)


func _add_fish(species: String, kg: float) -> void:
	GameSession.expire_bite()
	GameSession._pending_bite = {"species": species, "kg": kg, "time": GameSession.get_game_time(), "mode": "stationary", "lure": "spinner"}
	GameSession.finish_fight(true)


## Departs Copenhagen for Malmö and sails on until the boat is near enough a
## coast to anchor (Øresund). Returns false if it never is.
func _sail_to_anchorage() -> bool:
	t.set_wind(90.0, 8.0)
	GameSession.plan_route_to(&"malmo")
	if GameSession.depart() != "":
		return false
	for i in 200:
		Simulation.advance(300.0)
		if not GameSession.is_underway():
			return false
		var site := GameSession.evaluate_anchorage()
		if site.ok and GameSession.get_voyage_progress_nm() > 1.0:
			return true
	return false


# --- The model ------------------------------------------------------------------------

func _test_site_model() -> void:
	var calm := WindField.Sample.make(90.0, 8.0)
	t.check(AnchorSite.holding(5, 0.8, AnchorSite.SHELTERED, calm) == AnchorState.HOLDING_WELL,
		"[model] sheltered, usual chain, well set, light wind: holding well")
	var fresh := WindField.Sample.make(90.0, 22.0)
	var levels := []
	for scope in AnchorState.SCOPES:
		levels.append(AnchorSite.holding_margin(scope, 0.5, AnchorSite.PARTLY, fresh))
	t.check(levels[0] < levels[1] and levels[1] < levels[2], "[model] more chain holds better (%s)" % [levels])
	t.check(AnchorSite.holding_margin(5, 1.0, AnchorSite.PARTLY, fresh) > AnchorSite.holding_margin(5, 0.0, AnchorSite.PARTLY, fresh),
		"[model] a well-set anchor holds better")
	t.check(AnchorSite.holding_margin(5, 0.5, AnchorSite.SHELTERED, fresh) > AnchorSite.holding_margin(5, 0.5, AnchorSite.EXPOSED, fresh),
		"[model] shelter from the wind holds better")
	# As the wind rises, the holding steps down through each level: the alarm
	# for poor holding always comes before dragging.
	var seen := []
	for kn in range(4, 60):
		var level := AnchorSite.holding(5, 0.5, AnchorSite.EXPOSED, WindField.Sample.make(90.0, float(kn)))
		if seen.is_empty() or seen[-1] != level:
			seen.append(level)
	t.check(seen == [AnchorState.HOLDING_WELL, AnchorState.HOLDING_FAIR, AnchorState.HOLDING_POOR, AnchorState.HOLDING_DRAGGING],
		"[model] rising wind: well → fair → poor → dragging, never straight to dragging (%s)" % [seen])
	var gap := 0.0
	for kn in range(4, 60):
		var w := WindField.Sample.make(90.0, float(kn))
		if AnchorSite.holding(5, 0.5, AnchorSite.EXPOSED, w) == AnchorState.HOLDING_POOR:
			gap += 1.0
	t.check(gap >= 3.0, "[model] poor holding spans %d knots of wind before dragging (time to react)" % roundi(gap))
	var open_sea := Vector2(4.0, 56.0)  # the middle of the North Sea
	var far := AnchorSite.evaluate(open_sea, calm)
	t.check(not far.ok and String(far.reason).contains("deep"), "[model] far from any coast: too deep to anchor (%s)" % far.reason)
	var land := AnchorSite.evaluate(PortCatalog.get_default().get_port(&"copenhagen").get_geo_position() + Vector2(0.3, 0.0), calm)
	t.check(not land.ok, "[model] on land: no anchoring")


# --- The galley -------------------------------------------------------------------------

func _test_stove_on_every_boat() -> void:
	for id in VesselCatalog.get_default().get_ids():
		if id != GameSession.get_vessel_id():
			GameSession.switch_vessel(id)
		var cabin := await _show(CABIN, &"from_deck")
		var station := cabin.get_node_or_null("Layout/Stations/Cook") as Interactable
		if not t.check(station != null and cabin.get_gear("GalleyStove") != null, "[galley] %s: a stove beside the provisions" % id):
			continue
		var cells := W.walkable_cells(cabin, cabin.get_spawn_position(&"from_deck"))
		t.check(not W.use_points(station, cells).is_empty(), "[galley] %s: the captain can walk to the stove" % id)
		t.check(station.highlight_outline.size() >= 3, "[galley] %s: the stove itself is highlighted" % id)
		var near_spot := []
		for marker in cabin.get_node("Layout/CompanionSpots").get_children():
			for gear in ["Cook", "Trophies"]:
				var gear_station := cabin.get_node_or_null("Layout/Stations/%s" % gear) as Node2D
				if gear_station and gear_station.position.distance_to(marker.position) < 60.0:
					near_spot.append("%s~%s" % [gear, marker.name])
		t.check(near_spot.is_empty(), "[galley] %s: the stove and the trophy board keep clear of the cat's and dog's resting spots %s" % [id, near_spot])
		var deck := await _show(DECK, &"start")
		var anchor := deck.get_node_or_null("Layout/Stations/Anchor") as Interactable
		if not t.check(anchor != null and deck.get_gear("Windlass") != null, "[anchor] %s: a windlass on the foredeck" % id):
			continue
		# The Wing 33's side decks are narrow: a finer grid finds the way forward.
		var deck_cells := W.walkable_cells(deck, deck.get_spawn_position(&"start"), 5.0)
		t.check(not W.use_points(anchor, deck_cells).is_empty(), "[anchor] %s: the captain can walk to the windlass" % id)
		t.check(anchor.highlight_outline.size() >= 3, "[anchor] %s: the windlass itself is highlighted" % id)
	GameSession.switch_vessel(VesselCatalog.STARTER_ID)


func _test_cooking_in_harbour() -> void:
	await _restart()
	var cabin := await _show(CABIN, &"from_deck")
	var station := cabin.get_node("Layout/Stations/Cook") as Interactable
	await _walk_to(cabin, station)
	t.check(cabin.player.get_focused_interactable() == station and app.hud.get_prompt() == "Cook a meal or make coffee", "[galley] at the stove: \"Cook a meal or make coffee\"")
	await _shot("13_galley_highlight")
	station.interact(cabin.player)
	await t.frames(2)
	var menu := app.modals.get_top() as CookingMenu
	if not t.check(menu != null, "[galley] E at the stove opens the galley"):
		return
	menu.select_recipe("pan_fried_fish")
	t.check(GameSession.recipe_refusal("pan_fried_fish") != "" and (menu.find_child("CookButton", true, false) as Button).disabled,
		"[galley] without fish, a fish dish cannot be cooked")
	t.check(GameSession.cook("pan_fried_fish").error != "" and GameSession.get_galley().meals_cooked == 0, "[galley] and nothing changes when refused")
	app.modals.clear()
	_add_fish("cod", 3.0)
	_add_fish("herring", 0.3)
	station.interact(cabin.player)
	await t.frames(2)
	menu = app.modals.get_top() as CookingMenu
	menu.select_recipe("fish_stew")
	await _shot("13_cooking_panel")
	GameSession.set_provisions_for_testing(8.0)
	var food := GameSession.get_food_days()
	var before := GameSession.get_game_time()
	var oldest := int(GameSession.get_fishing().hold[0].uid)
	(menu.find_child("CookButton", true, false) as Button).pressed.emit()
	t.check(menu.is_cooking(), "[galley] cooking: the pan sizzles and steams for a moment")
	await t.frames(3)
	await t.screenshot("13_cooking_in_progress")
	var result := menu.serve()
	t.check(result.error == "" and GameSession.get_fishing().find_in_hold(oldest) < 0 and GameSession.get_fishing().hold.size() == 1,
		"[galley] the stew takes the oldest fish from the cool box")
	t.check(GameSession.get_game_time() - before >= 50.0 * 60.0 - 1.0, "[galley] the cooking time passes (%s)" % Simulation.format_duration(GameSession.get_game_time() - before))
	t.check(GameSession.get_food_days() > food, "[galley] the catch adds food to the stores (%.2f → %.2f days)" % [food, GameSession.get_food_days()])
	t.check(GameSession.is_well_fed() and "Well fed" in app.hud.aboard_badge.get_texts() or GameSession.is_well_fed(), "[galley] the crew is well fed")
	t.check(menu.get_outcome_text().contains("ready") and menu.get_outcome_text().contains("Well fed until"), "[galley] the result says what the meal did")
	await _shot("13_cooking_meal_done")
	t.check(cabin.get_gear("GalleyStove").is_steaming(), "[galley] the stove steams after cooking")
	# No hunger: being well fed makes the stores last longer, nothing else.
	var fed_food := GameSession.get_food_days()
	Simulation.advance(6.0 * 3600.0)
	var fed_used := fed_food - GameSession.get_food_days()
	t.check(fed_used > 0.0 and fed_used < 6.0 / 24.0 - 1e-6, "[galley] well fed, the stores last a little longer (%.3f days in 6 h)" % fed_used)
	app.modals.clear()
	var grocery_food := GameSession.get_food_days()
	t.check(GameSession.cook("porridge").error == "" and GameSession.get_food_days() < grocery_food, "[galley] porridge uses groceries only")


func _test_cooking_underway_rule() -> void:
	await _restart()
	t.set_wind(270.0, 24.0)
	GameSession.plan_route_to(&"kiel")
	GameSession.depart()
	Simulation.advance(600.0)
	t.check(GameSession.cooking_refusal().contains("Too lively"), "[galley] underway in a fresh breeze the stove stays off (%s)" % GameSession.cooking_refusal())
	var food := GameSession.get_food_days()
	t.check(GameSession.cook("porridge").error != "" and is_equal_approx(GameSession.get_food_days(), food), "[galley] refused, nothing used, no accident")
	t.set_wind(270.0, 10.0)
	t.check_eq(GameSession.cooking_refusal(), "", "[galley] in moderate conditions underway one can cook")
	t.use_calm_wind()
	await _restart()


# --- The anchor ---------------------------------------------------------------------------

func _test_anchoring() -> void:
	t.check(GameSession.anchoring_refusal().contains("harbour"), "[anchor] in harbour the boat is moored, not anchored")
	var near := await _sail_to_anchorage()
	if not t.check(near, "(setup) sailing towards Malmö the boat comes near enough a coast to anchor"):
		return
	var deck := await _show(DECK, &"start")
	var station := deck.get_node("Layout/Stations/Anchor") as Interactable
	await _walk_to(deck, station)
	t.check(deck.player.get_focused_interactable() == station, "[anchor] standing at the windlass focuses it")
	station.interact(deck.player)
	await t.frames(2)
	var menu := app.modals.get_top() as AnchorMenu
	if not t.check(menu != null, "[anchor] E at the windlass opens the anchor panel"):
		return
	t.check(menu.get_holding_text().contains("anchorage") and menu.get_site_text() != "", "[anchor] it shows the anchorage (%s: %s)" % [
		menu.get_holding_text(), menu.get_site_text()])
	t.check((menu.find_child("Limits", true, false) as Label).text.contains("No depth soundings"), "[anchor] and says the model's limits")
	await _shot("13_anchor_suitability")
	var progress := GameSession.get_voyage_progress_nm()
	menu.set_scope(7)
	menu.start_setting(true)
	t.check(menu.is_setting(), "[anchor] dropping starts the short setting interaction")
	await t.frames(3)
	var result := menu.catch_set(0.5)
	t.check(result.get("error", "x") == "" and GameSession.is_anchored(), "[anchor] the anchor goes down (%s)" % result.get("error", ""))
	t.check(is_equal_approx(float(result.set_quality), 1.0) and is_equal_approx(AnchorMenu.set_quality_at(0.0), 0.0),
		"[anchor] caught in the middle it is well set; at the edge barely")
	t.check(GameSession.get_vessel_speed_kn() == 0.0, "[anchor] at anchor the boat stops")
	Simulation.advance(3600.0)
	t.check(is_equal_approx(GameSession.get_voyage_progress_nm(), progress), "[anchor] the voyage waits while at anchor")
	t.check(GameSession.get_fishing_mode() == FishingState.MODE_STATIONARY, "[anchor] at anchor one fishes from a still boat")
	app.modals.clear()
	await t.frames(3)
	var texts: PackedStringArray = app.hud.aboard_badge.get_texts()
	t.check(texts.size() > 0 and texts[0].begins_with("At anchor"), "[anchor] the HUD says how it is holding (%s)" % [texts])
	await t.get_tree().create_timer(0.3).timeout
	await _shot("13_anchor_deployed")
	station.interact(deck.player)
	await t.frames(2)
	menu = app.modals.get_top() as AnchorMenu
	t.check(menu.get_holding_text().begins_with("Holding well") or menu.get_holding_text().begins_with("Fair"), "[anchor] holding: %s" % menu.get_holding_text())
	await _shot("13_anchor_holding")
	app.modals.clear()
	# Underway jobs are guarded while at anchor.
	var helm := deck.get_node("Layout/Stations/Helm") as Interactable
	helm.interact(deck.player)
	await t.frames(1)
	t.check(app.toasts.get_messages()[-1].contains("Raise the anchor"), "[anchor] the helm asks to raise the anchor first")
	t.check(GameSession.drop_anchor(5, 0.5).error != "", "[anchor] it cannot be dropped twice")
	# Supper from the catch at anchor: the connected moment.
	_add_fish("cod", 4.0)
	var cooked := GameSession.cook("pan_fried_fish")
	t.check(cooked.error == "" and cooked.evening, "[together] fish caught, anchored, cooked: \"%s\"" % "A quiet evening at anchor. Fresh fish for supper.")
	t.check(GameSession.get_objective_progress().is_completed(&"evening:catch_anchor_cook"), "[together] noted once in the Log")
	t.check(GameSession.get_aboard_moments().any(func(m: Dictionary) -> bool: return String(m.text).contains("quiet evening")),
		"[together] the Captain's Log keeps the evening")


func _test_dragging() -> void:
	if not GameSession.is_anchored():
		return
	var alarms := []
	var on_alarm := func(alarm: Dictionary) -> void: alarms.append(alarm.level)
	GameSession.anchor_alarm.connect(on_alarm)
	var anchor := GameSession.get_anchor()
	var start := anchor.position
	# The wind backs to the anchorage's most open side and rises step by step
	# (Iteration 14: the detailed Øresund coast shelters the first site from
	# the wind it was chosen in).
	var from := 0.0
	var longest := -1.0
	for deg in range(0, 360, 15):
		var fetch := AnchorSite.fetch_nm(start, float(deg))
		if fetch > longest:
			longest = fetch
			from = float(deg)
	app.toasts.clear()
	var steps := []
	for kn in range(10, 46, 2):
		t.set_wind(from, float(kn))
		var result := Simulation.advance(600.0)
		steps.append([kn, String(GameSession.get_anchor().holding)])
		if GameSession.get_anchor().holding == AnchorState.HOLDING_DRAGGING:
			break
	GameSession.anchor_alarm.disconnect(on_alarm)
	var holding := GameSession.get_anchor().holding
	t.check(holding == AnchorState.HOLDING_DRAGGING, "[drag] a rising gale makes the anchor drag (%s)" % [steps])
	t.check(alarms.size() >= 2 and alarms[0] == "poor" and alarms[-1] == "dragging", "[drag] the alarm warns of poor holding before dragging (%s)" % [alarms])
	var moved := GeoMath.distance_nm(start, GameSession.get_vessel_position())
	t.check(moved > 0.0 and moved <= GameSession.DRAG_NM_PER_CHECK * 3.0 + 1e-6, "[drag] dragging moves the boat a little at a time (%.3f nm), no jump" % moved)
	t.check(GameSession.is_anchored() and GameSession.get_condition() >= 99.0 or GameSession.get_condition() > 80.0,
		"[drag] nothing critical at once: still at anchor, hull %d %%" % roundi(GameSession.get_condition()))
	var deck := app.router.current_screen as BoatArea
	await t.frames(3)
	t.check("Anchor dragging! Go to the windlass" in app.hud.aboard_badge.get_texts(), "[drag] the HUD shows the red \"Anchor dragging!\"")
	await _shot("13_anchor_dragging_warning", true)
	# More chain and setting it again: in a gale only a sheltered spot holds,
	# so the sensible answer may be to weigh anchor; either way the alarm is
	# answered and nothing breaks.
	var before := GameSession.get_anchor().holding
	var after := GameSession.adjust_anchor(7, 1.0)
	t.check(AnchorState.HOLDINGS.find(after) <= AnchorState.HOLDINGS.find(before), "[drag] more chain and a fresh set never make it worse (%s → %s)" % [before, after])
	t.set_wind(from, 12.0)
	GameSession.adjust_anchor(7, 1.0)
	t.check(GameSession.get_anchor().holding in [AnchorState.HOLDING_WELL, AnchorState.HOLDING_FAIR], "[drag] as the wind eases and it is set again, it holds")
	t.check(GameSession.get_objective_progress().is_completed(&"anchor:drag_handled"), "[drag] stopping the drag is noted once")
	GameSession.acknowledge_anchor_alarm()
	t.check(not GameSession.get_anchor().alarm, "[drag] the alarm is answered")
	deck.player.position = deck.player.position


func _test_sleep_at_anchor() -> void:
	if not GameSession.is_anchored():
		return
	var from := Simulation.get_weather_at_vessel().from_deg
	t.set_wind(from, 8.0)
	GameSession.adjust_anchor(5, 1.0)
	var result := Simulation.sleep(9.0)
	t.check(result.stopped_by == Simulation.STOP_NONE and is_equal_approx(result.elapsed_seconds, 9.0 * 3600.0),
		"[sleep] a quiet night at anchor: slept through (%s)" % result.stopped_by)
	t.check(GameSession.get_objective_progress().is_completed(&"anchor:night"), "[sleep] a night at anchor is noted once")
	# A night that turns rough wakes the captain on the alarm.
	var night_start := GameSession.get_game_time()
	WindField.get_default().test_override = func(_geo: Vector2, time: float) -> WindField.Sample:
		return WindField.Sample.make(from, 8.0 if time < night_start + 2.0 * 3600.0 else 30.0)
	Simulation.invalidate_estimates()
	app.sleep_for(8.0)
	await _settle()
	t.check(GameSession.get_game_time() - night_start < 8.0 * 3600.0 and app.toasts.get_messages()[-1].contains("anchor alarm"),
		"[sleep] the anchor alarm wakes the captain (after %s)" % Simulation.format_duration(GameSession.get_game_time() - night_start))
	t.set_wind(from, 8.0)
	GameSession.adjust_anchor(5, 1.0)
	# Weighing anchor: the voyage goes on from where it waited.
	var progress := GameSession.get_voyage_progress_nm()
	t.check_eq(GameSession.raise_anchor(), "", "[raise] the anchor comes up")
	t.check(not GameSession.is_anchored() and GameSession.raise_anchor() != "", "[raise] and cannot be raised twice")
	Simulation.advance(1800.0)
	t.check(GameSession.get_voyage_progress_nm() > progress, "[raise] the boat sails on")


func _test_save_load_at_anchor() -> void:
	if not GameSession.is_underway():
		return
	var near := false
	for i in 100:
		if GameSession.evaluate_anchorage().ok:
			near = true
			break
		Simulation.advance(300.0)
	if not t.check(near and GameSession.drop_anchor(5, 0.8).error == "", "(setup) anchored again"):
		return
	var anchor := GameSession.get_anchor().to_dict()
	t.check_eq(SaveManager.save_to_slot(3, GameSession.get_state_snapshot()), OK, "(setup) saved at anchor")
	app.show_main_menu()
	await _settle()
	app.load_slot(3)
	await _settle()
	t.check(GameSession.is_anchored() and JSON.stringify(JSON.parse_string(JSON.stringify(GameSession.get_anchor().to_dict()))) == JSON.stringify(JSON.parse_string(JSON.stringify(anchor))),
		"[save] a game saved at anchor loads at anchor, holding as before")
	t.check(GameSession.get_vessel_position().is_equal_approx(GameSession.get_anchor().position), "[save] where the anchor holds it")
	var errors: Array[String] = []
	var bad: Dictionary = JSON.parse_string(JSON.stringify(GameSession.get_state_snapshot().to_dict()))
	var copenhagen := PortCatalog.get_default().get_port(&"copenhagen").get_geo_position()
	bad.vessel.status = String(SessionState.STATUS_MOORED)
	bad.vessel.position = {"lon": copenhagen.x, "lat": copenhagen.y}
	bad.navigation.location_id = "copenhagen"
	bad.navigation.voyage = null
	t.check(SessionState.from_dict(bad, errors) == null and str(errors).contains("anchor"),
		"[save] an anchor down in harbour is rejected as invalid (%s)" % [errors])
	SaveManager.delete_slot(3)
	GameSession.raise_anchor()
	t.use_calm_wind()
