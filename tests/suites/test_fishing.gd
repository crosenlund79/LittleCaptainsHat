extends RefCounted
## Iteration 13, "The Catch": the rod, the lures, regional fish from data,
## bites on a fixed grid (stationary and trolling), keep / release / sell,
## milestones paid once, the trophy board, and the rod and trophy stations
## on every boat. Iteration 18 replaced the tension fight with the reel-in
## dial: its fairness is tested in test_fishing2 (as the fight's was here),
## and the panel here lands its fish through the dial. Only kept fish are
## trophies now (a fish that goes back because the cool box is full is not).

const APP_SCENE := preload("res://src/app/app.tscn")
const W := preload("res://tests/helpers/walkability.gd")
const Reel := preload("res://tests/helpers/reel.gd")
const DECK := SessionState.AREA_EXTERIOR
const CABIN := SessionState.AREA_INTERIOR

var t: Node
var app: Node


func run(runner: Node) -> void:
	t = runner
	Simulation.auto_advance = false
	t.use_calm_wind()
	_test_catalog()
	app = APP_SCENE.instantiate()
	t.add_child(app)
	app.router.fade_duration = 0.05
	await _settle()
	app.start_new_game()
	await _settle()
	_test_line_and_bites()
	_test_landing_and_records()
	_test_cool_box_and_sales()
	_test_fishing_save_load()
	await _test_stations_on_every_boat()
	await _test_fishing_panel()
	await _test_unattended_bite()
	await _test_trolling_underway()
	await _test_trophy_board()
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


## Lets time pass with the line out until a fish bites (at most `hours`).
func _wait_for_bite(hours := 24.0) -> bool:
	var waited := 0.0
	while waited < hours * 3600.0 and GameSession.get_pending_bite().is_empty():
		Simulation.advance(600.0)
		waited += 600.0
	return not GameSession.get_pending_bite().is_empty()


func _restart() -> void:
	GameSession.end_session()
	app.start_new_game()
	await _settle()


# --- Data -----------------------------------------------------------------------------

func _test_catalog() -> void:
	var catalog := FishingCatalog.get_default()
	t.check_eq(catalog.lures.size(), 4, "[data] four lure families")
	var ids := catalog.lures.map(func(l: Dictionary) -> String: return l.id)
	t.check(ids == ["spinner", "spoon", "soft", "jig"], "[data] spinner, spoon, soft bait and jig (%s)" % [ids])
	t.check(catalog.species.size() >= 8, "[data] regional fish species from data (%d)" % catalog.species.size())
	var regions := {}
	for port in PortCatalog.get_default().ports:
		regions[port.region] = true
	var unknown := []
	for fish in catalog.species:
		for region: String in fish.regions:
			if not regions.has(region):
				unknown.append("%s:%s" % [fish.id, region])
	t.check(unknown.is_empty(), "[data] every species lives in regions the chart knows (%s)" % [unknown])
	var empty := []
	for region: String in regions:
		var found := 0
		for fish in catalog.species:
			if region in fish.regions and not fish.get("coastal", false):
				found += 1
		if found == 0:
			empty.append(region)
	t.check(empty.is_empty() or empty.size() <= 2, "[data] almost every sea area has fish away from the coast too (without: %s)" % [empty])
	var copenhagen := PortCatalog.get_default().get_port(&"copenhagen").get_geo_position()
	t.check_eq(FishingCatalog.region_at(copenhagen), "baltic", "[data] Copenhagen's waters are the Baltic's")
	var spreads := []
	for lure in ids:
		spreads.append(catalog.suitability(copenhagen, FishingState.MODE_STATIONARY, lure))
	t.check(spreads.min() > 0.5 and spreads.max() < 1.4 and spreads.max() - spreads.min() > 0.05,
		"[lures] the lures differ, modestly (fit %.2f to %.2f)" % [spreads.min(), spreads.max()])
	t.check(catalog.bite_chance(copenhagen, FishingState.MODE_TROLLING, "spoon", catalog.max_trolling_kn + 0.5, 10.0) == 0.0,
		"[trolling] faster than %d kn a trolled lure gets no bites" % roundi(catalog.max_trolling_kn))
	var a := RandomNumberGenerator.new()
	a.seed = 42
	var b := RandomNumberGenerator.new()
	b.seed = 42
	t.check(catalog.pick(a, copenhagen, FishingState.MODE_STATIONARY, "jig") == catalog.pick(b, copenhagen, FishingState.MODE_STATIONARY, "jig"),
		"[data] the same moment always gives the same fish")
	t.check(catalog.score("bonito", 1.0) > catalog.score("herring", 0.45), "[trophies] a rare fish outranks a big common one")
	t.check(catalog.score("cod", 10.0) > catalog.score("cod", 2.0), "[trophies] within a species, bigger ranks higher")


# --- Rules ----------------------------------------------------------------------------

func _test_line_and_bites() -> void:
	t.check(GameSession.get_fishing().rod and GameSession.get_fishing().get_lure_count("spinner") > 0,
		"[rod] a new game has the basic rod and a couple of spinners")
	t.check(GameSession.fishing_refusal("jig") != "", "[rod] without jigs a jig cannot go out (%s)" % GameSession.fishing_refusal("jig"))
	t.check_eq(GameSession.get_fishing_mode(), FishingState.MODE_STATIONARY, "[rod] moored, one fishes from a still boat")
	t.check_eq(GameSession.set_line(true, "spinner"), "", "[rod] the line goes out with a spinner")
	t.check(GameSession.is_line_out(), "[rod] the line is out")
	var state := GameSession.get_state_snapshot()
	var bite := _wait_for_bite(24.0)
	t.check(bite, "[bites] in harbour a fish bites within a day of fishing")
	var first := GameSession.get_pending_bite()
	var first_time := float(first.get("time", -1.0))
	t.check(first_time > 0.0 and fmod(first_time, FishingCatalog.get_default().check_interval_s) < 1e-3,
		"[bites] bites come on the fixed check grid (t=%d)" % roundi(first_time))
	# Chop-independence: the same game, advanced in other steps, bites at the same moment.
	GameSession.replace_state(state)
	GameSession.expire_bite()
	var guard := 0
	while GameSession.get_pending_bite().is_empty() and guard < 3000:
		Simulation.advance(37.0)
		guard += 1
	t.check(is_equal_approx(float(GameSession.get_pending_bite().get("time", -2.0)), first_time)
		and GameSession.get_pending_bite().species == first.species,
		"[bites] the same bite (%s at t=%d) whatever the time steps" % [first.get("species", "?"), roundi(first_time)])
	var before := GameSession.get_game_time()
	Simulation.advance(3600.0)
	t.check(GameSession.get_pending_bite().get("time") == first_time, "[bites] while a fish is on, no second bite piles up")
	t.check(GameSession.get_game_time() > before, "(setup) time went on")


func _test_landing_and_records() -> void:
	var renown := GameSession.get_lifetime_renown()
	var bite := GameSession.get_pending_bite()
	var result := GameSession.finish_fight(true)
	t.check(result.landed and result.kept and result.first and result.new_species, "[catch] the first fish: landed, kept, a new species")
	var fishing := GameSession.get_fishing()
	t.check(fishing.hold.size() == 1 and fishing.hold[0].species == bite.species, "[catch] it is in the cool box")
	t.check(GameSession.get_lifetime_renown() - renown >= 5, "[progression] the first fish and a new species earn renown (+%d)" % (
		GameSession.get_lifetime_renown() - renown))
	t.check(fishing.trophies.size() == 1, "[trophies] the first catch goes on the trophy board")
	var again := GameSession.finish_fight(true)
	t.check(not again.landed and GameSession.get_fishing().hold.size() == 1 and GameSession.get_fishing().total_caught == 1,
		"[catch] no duplication: finishing again without a bite lands nothing")
	# More fish: milestones are paid once only.
	var paid := GameSession.get_lifetime_renown()
	var uids := {}
	for i in 7:
		_force_bite(String(bite.species), float(bite.kg) * 0.5)
		GameSession.finish_fight(true)
	t.check(GameSession.get_lifetime_renown() == paid, "[progression] more of the same species earns no more renown")
	fishing = GameSession.get_fishing()
	for fish in fishing.hold:
		uids[int(fish.uid)] = true
	t.check(uids.size() == fishing.hold.size() and fishing.hold.size() == FishingState.HOLD_CAPACITY,
		"[catch] the cool box holds %d fish, each one once" % FishingState.HOLD_CAPACITY)
	t.check(fishing.released >= 1, "[catch] with the cool box full the fish goes back (released %d)" % fishing.released)
	var kept := {}
	for fish in fishing.hold:
		kept[int(fish.uid)] = true
	t.check(fishing.trophies.all(func(trophy: Dictionary) -> bool: return kept.has(int(trophy.uid))),
		"[trophies] a fish that went back (cool box full) is not on the board")
	t.check(fishing.trophies.size() == FishingState.TROPHY_COUNT, "[trophies] the board shows the five most notable")
	var sorted := true
	for i in fishing.trophies.size() - 1:
		sorted = sorted and float(fishing.trophies[i].score) >= float(fishing.trophies[i + 1].score)
	t.check(sorted, "[trophies] ranked best first")
	# Room in the cool box for the next one.
	GameSession.release_fish(int(GameSession.get_fishing().hold.back().uid))
	_force_bite("bonito", 4.6)
	var rare := GameSession.finish_fight(true)
	t.check(rare.exceptional and GameSession.get_fishing().trophies[0].species == "bonito",
		"[trophies] an exceptional rare fish goes to the top of the board")
	t.check(GameSession.get_objective_progress().is_completed(&"fish:exceptional:bonito"), "[progression] noted once in the Log's ledger")
	var log_texts := GameSession.get_aboard_moments().map(func(m: Dictionary) -> String: return String(m.text))
	t.check(log_texts.any(func(text: String) -> bool: return text.contains("first fish")), "[log] the Captain's Log keeps the first fish (%s)" % [log_texts])
	_force_bite("cod", 5.0)
	var lures := GameSession.get_fishing().get_lure_count("spinner")
	var broke := GameSession.finish_fight(false, true)
	t.check(not broke.landed and GameSession.get_fishing().get_lure_count("spinner") == lures - 1, "[catch] a broken line costs the lure")


## `value` as the save file holds it (numbers as JSON numbers).
func _json(value: Variant) -> String:
	return JSON.stringify(JSON.parse_string(JSON.stringify(value)))


func _force_bite(species: String, kg: float) -> void:
	GameSession.expire_bite()
	GameSession._pending_bite = {"species": species, "kg": kg, "time": GameSession.get_game_time(), "mode": "stationary", "lure": "spinner"}


func _test_cool_box_and_sales() -> void:
	var fishing := GameSession.get_fishing()
	var uid := int(fishing.hold[0].uid)
	t.check(GameSession.release_fish(uid) and GameSession.get_fishing().find_in_hold(uid) < 0, "[cool box] release puts a fish back")
	t.check(not GameSession.release_fish(uid), "[cool box] the same fish cannot be released twice")
	var funds := GameSession.get_funds()
	var sold_uid := int(GameSession.get_fishing().hold[0].uid)
	var sale := GameSession.sell_fish(sold_uid)
	t.check(sale.error == "" and GameSession.get_funds() == funds + int(sale.price) and int(sale.price) >= 1,
		"[cool box] in harbour the grocery store buys a fish (%s)" % GameSession.format_money(int(sale.price)))
	t.check(GameSession.sell_fish(sold_uid).error != "", "[cool box] and cannot buy it twice")
	t.check(GameSession.buy_lure("jig") == "" and GameSession.get_fishing().get_lure_count("jig") == 1, "[tackle] the grocery store sells lures")


func _test_fishing_save_load() -> void:
	var before := GameSession.get_fishing().to_dict()
	var state := GameSession.get_state_snapshot()
	var errors: Array[String] = []
	var restored := SessionState.from_dict(JSON.parse_string(JSON.stringify(state.to_dict())), errors)
	t.check(restored != null and _json(restored.fishing.to_dict()) == _json(before), "[save] the rod, lures, cool box, records and trophies round-trip")
	var bad := state.to_dict()
	if not bad.fishing.hold.is_empty():
		bad.fishing.hold.append(bad.fishing.hold[0].duplicate())
	t.check(SessionState.from_dict(bad, errors) == null, "[save] a cool box with a duplicated fish is rejected")


# --- Stations ---------------------------------------------------------------------------

func _test_stations_on_every_boat() -> void:
	for id in VesselCatalog.get_default().get_ids():
		if id != GameSession.get_vessel_id():
			GameSession.switch_vessel(id)
		var deck := await _show(DECK, &"start")
		var station := deck.get_node_or_null("Layout/Stations/Fishing") as Interactable
		if not t.check(station != null and deck.get_gear("RodHolder") != null, "[station] %s: a rod holder on the stern rail" % id):
			continue
		var cells := W.walkable_cells(deck, deck.get_spawn_position(&"start"))
		t.check(not W.use_points(station, cells).is_empty(), "[station] %s: the captain can walk to the rod" % id)
		t.check(station.get_highlight_points().size() >= 3 and station.highlight_outline.size() >= 3,
			"[station] %s: the rod itself is highlighted (no circle)" % id)
		var helm := deck.get_node("Layout/Stations/Helm") as Interactable
		t.check(helm.global_position.distance_to(station.global_position) >= BoatArea.ROD_HELM_CLEARANCE - 0.1, "[station] %s: the rod is clear of the helm" % id)
		var cabin := await _show(CABIN, &"from_deck")
		var trophies := cabin.get_node_or_null("Layout/Stations/Trophies") as Interactable
		var hat := cabin.get_node("Layout/Stations/Hat") as Interactable
		t.check(trophies != null and cabin.get_gear("TrophyBoard") != null and trophies.global_position.distance_to(hat.global_position) >= 100.0,
			"[station] %s: the trophy board hangs in the cabin, clear of the hat hook" % id)
		var cabin_cells := W.walkable_cells(cabin, cabin.get_spawn_position(&"from_deck"))
		t.check(trophies != null and not W.use_points(trophies, cabin_cells).is_empty(), "[station] %s: and can be walked to" % id)
	GameSession.switch_vessel(VesselCatalog.STARTER_ID)


func _walk_to(area: BoatArea, station: Interactable) -> void:
	var cells := W.walkable_cells(area, area.player.position)
	var points := W.use_points(station, cells)
	if points.is_empty():
		return
	area.player.position = points[0]
	area.player.set_facing(station.position - points[0])  # walking up to it
	await t.physics_frames(4)


func _test_fishing_panel() -> void:
	await _restart()
	var deck := await _show(DECK, &"start")
	var station := deck.get_node("Layout/Stations/Fishing") as Interactable
	await _walk_to(deck, station)
	t.check(deck.player.get_focused_interactable() == station, "[panel] standing at the rod focuses it")
	t.check_eq(app.hud.get_prompt(), "Fishing rod", "[panel] the prompt names the rod")
	app.toasts.clear()
	await t.frames(1)
	await t.screenshot("13_fishing_rod_highlight")
	station.interact(deck.player)
	await t.frames(2)
	var menu := app.modals.get_top() as FishingMenu
	if not t.check(menu != null, "[panel] E at the rod opens the fishing panel"):
		return
	t.check(menu.get_info_text().contains("moored") and menu.get_info_text().contains("Baltic"), "[panel] it says how and where (%s)" % menu.get_info_text())
	(menu.find_child("LineButton", true, false) as Button).pressed.emit()
	t.check(GameSession.is_line_out(), "[panel] Let the line out")
	await t.frames(2)
	app.toasts.clear()
	await t.frames(1)
	await t.screenshot("13_fishing_panel")
	var tries := 0
	while GameSession.get_pending_bite().is_empty() and tries < 30:
		(menu.find_child("WaitButton", true, false) as Button).pressed.emit()
		tries += 1
		await t.frames(1)
	t.check(menu.is_reeling(), "[panel] waiting at the rod ends in a bite and the reel-in (%d waits)" % tries)
	var bite := GameSession.get_pending_bite()
	t.check((menu.find_child("ReelName", true, false) as Label).text == FishingCatalog.get_default().get_species_name(bite.species)
		and menu.get_reel_portrait().species_id == String(bite.species),
		"[panel] the reel-in shows what bit, by name and picture (%s)" % bite.species)
	await t.frames(1)
	app.toasts.clear()
	await t.frames(1)
	await t.screenshot("13_fishing_bite_tension")
	t.check(Reel.land(menu), "[panel] good presses on the dial land the catch")
	t.check(menu.get_outcome_text().contains("kg") and menu.get_outcome_text().contains("cool box"), "[panel] the catch result (%s)" % menu.get_outcome_text())
	await t.frames(2)
	app.toasts.clear()
	await t.frames(1)
	await t.screenshot("13_fishing_catch_result")
	menu.close()
	await t.frames(2)


func _test_unattended_bite() -> void:
	var deck := await _show(DECK, &"start")
	t.check(GameSession.is_line_out(), "(setup) the line is still out")
	if not _wait_for_bite(24.0):
		t.check(false, "(setup) a fish bites")
		return
	t.check(app.get_bite_wait() > 40.0, "[bite] a bite away from the rod gives %d s to get there" % roundi(GameSession.BITE_WAIT_SECONDS))
	await t.frames(2)
	var texts: PackedStringArray = app.hud.aboard_badge.get_texts()
	t.check("Fish on! Reel in" in texts, "[bite] the HUD shows \"Fish on!\" (%s)" % [texts])
	app._update_bite_wait(GameSession.BITE_WAIT_SECONDS + 1.0)
	t.check(GameSession.get_pending_bite().is_empty() and GameSession.is_line_out(), "[bite] left too long, the fish gets away; the line stays out")
	await t.frames(1)
	t.check(not ("Fish on! Reel in" in app.hud.aboard_badge.get_texts()), "[bite] and the badge goes")
	deck.player.position = deck.player.position  # keep the deck in use


func _test_trolling_underway() -> void:
	GameSession.set_line(false)
	GameSession.plan_route_to(&"malmo")
	t.check_eq(GameSession.depart(), "", "(setup) the boat departs for Malmö")
	Simulation.advance(1200.0)
	t.check_eq(GameSession.get_fishing_mode(), FishingState.MODE_TROLLING, "[trolling] underway one trolls")
	t.check_eq(GameSession.set_line(true, "spinner"), "", "[trolling] the line goes out underway (%.1f kn)" % GameSession.get_vessel_speed_kn())
	var progress := GameSession.get_voyage_progress_nm()
	var got := false
	var guard := 0
	while not got and GameSession.is_underway() and guard < 200:
		var result := Simulation.advance(600.0)
		got = result.bite
		guard += 1
	t.check(got, "[trolling] a fish bites while trolling")
	t.check(GameSession.get_voyage_progress_nm() > progress, "[trolling] the boat sails on meanwhile (the helm keeps control)")
	var deck := await _show(DECK, &"start")
	var helm := deck.get_node("Layout/Stations/Helm") as Interactable
	t.check(helm.enabled, "[trolling] the helm stays usable while trolling")
	if got:
		var bite := GameSession.get_pending_bite()
		t.check(bite.mode == "trolling", "[trolling] the bite was a trolling bite")
		GameSession.finish_fight(true)
	GameSession.set_line(false)
	await _restart()


func _test_trophy_board() -> void:
	for pair in [["bonito", 4.2], ["sea_trout", 5.0], ["cod", 9.0], ["perch", 1.2], ["herring", 0.4]]:
		_force_bite(pair[0], pair[1])
		GameSession.finish_fight(true)
	var cabin := await _show(CABIN, &"from_deck")
	var station := cabin.get_node("Layout/Stations/Trophies") as Interactable
	await _walk_to(cabin, station)
	t.check(cabin.player.get_focused_interactable() == station, "[trophies] standing at the board focuses it")
	app.toasts.clear()
	await t.frames(1)
	await t.screenshot("13_trophy_board_highlight")
	station.interact(cabin.player)
	await t.frames(2)
	var menu := app.modals.get_top() as TrophyMenu
	t.check(menu != null and TrophyMenu.describe_trophies().begins_with("1.  Atlantic bonito"), "[trophies] the board lists the best catch first")
	app.toasts.clear()
	await t.frames(1)
	await t.screenshot("13_trophy_display")
	app.modals.clear()
	# The board persists: save and load.
	t.check_eq(SaveManager.save_to_slot(3, GameSession.get_state_snapshot()), OK, "(setup) saved")
	var trophies := GameSession.get_fishing().trophies.duplicate(true)
	app.load_slot(3)
	await _settle()
	t.check(_json(GameSession.get_fishing().trophies) == _json(trophies) and trophies.size() == FishingState.TROPHY_COUNT,
		"[trophies] the board survives saving and loading")
	SaveManager.delete_slot(3)
