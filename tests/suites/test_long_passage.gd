extends RefCounted
## Iteration 16: Long Passage time, passage stores, ocean readiness, the
## Captain's Log firsts and saving across the Date Line. Long Passage must
## give exactly the voyage that normal time gives, stop when something needs
## the captain, and never touch the save format.

const APP_SCENE := preload("res://src/app/app.tscn")

var t: Node


func run(runner: Node) -> void:
	t = runner
	Simulation.auto_advance = false
	_test_same_voyage_at_any_speed()
	_test_interruptions()
	_test_passage_stores()
	_test_readiness()
	_test_dateline_save()
	_test_world_firsts()
	await _test_panel()
	Simulation.auto_advance = true
	GameSession.end_session()
	t.use_calm_wind()


func _new_game(seed := 7) -> void:
	GameSession.start_new_session()
	var state := GameSession.get_state_snapshot()
	state.wind_seed = seed
	GameSession.replace_state(state)


## Long Passage ticks of `tick` real seconds until arrival (or a guard).
func _sail_in_passage_time(rate: float, tick := 0.1) -> int:
	var guard := 0
	while GameSession.is_underway() and guard < 100000:
		guard += 1
		if not Simulation.is_passage_running():
			Simulation.start_passage(rate)
		Simulation.tick(tick)
	return guard


func _test_same_voyage_at_any_speed() -> void:
	WindField.get_default().test_override = Callable()  # the real wind and weather
	var results := []
	for mode in ["normal", "passage"]:
		_new_game()
		GameSession.plan_route_to(&"gothenburg")
		GameSession.depart()
		if mode == "normal":
			var guard := 0
			while GameSession.is_underway() and guard < 100000:
				guard += 1
				Simulation.advance(20.0 * 60.0)  # twenty-minute frames
		else:
			_sail_in_passage_time(Simulation.PASSAGE_RATES[2])
		# The Captain's Log record of the voyage: when it ended, the miles, the
		# weather met and the damage (twenty-minute steps run on in harbour
		# after arriving; the record does not).
		var record: Dictionary = GameSession.get_captains_log().voyages.back()
		results.append({"time": float(record.ended), "nm": float(record.nm), "hazard": int(record.worst_hazard),
			"condition": GameSession.get_condition(), "where": GameSession.get_location_id()})
	t.check(results[0].where == &"gothenburg" and results[1].where == &"gothenburg"
		and absf(results[0].time - results[1].time) < 1.0 and absf(results[0].nm - results[1].nm) < 1e-6
		and results[0].hazard == results[1].hazard and absf(results[0].condition - results[1].condition) < 1e-6,
		"[long passage] the same voyage at 12 hours a second as in twenty-minute steps: arrival %s vs %s" % [
			Simulation.format_game_time(results[0].time), Simulation.format_game_time(results[1].time)])
	t.use_calm_wind()


func _test_interruptions() -> void:
	var stops := []
	var record := func(reason: StringName, _text: String) -> void: stops.append(reason)
	Simulation.passage_interrupted.connect(record)
	_new_game()
	t.check(Simulation.start_passage(Simulation.PASSAGE_RATES[0]) != "", "[long passage] refused in harbour (it is for voyages)")
	t.set_wind(270.0, 12.0)
	GameSession.plan_route_to(&"lisbon")
	GameSession.depart()
	t.check(Simulation.start_passage(5000.0) != "", "[long passage] only the offered speeds")
	t.check_eq(Simulation.start_passage(Simulation.PASSAGE_RATES[1]), "", "[long passage] starts underway")
	GameSession.set_provisions_for_testing(3.4)
	var guard := 0
	while Simulation.is_passage_running() and guard < 1000:
		guard += 1
		Simulation.tick(0.1)
	t.check(stops.has(Simulation.STOP_STORES) and not Simulation.is_passage_running() and GameSession.get_time_scale() == 1,
		"[long passage] stops for low stores, back to normal time (%s)" % [stops])
	GameSession.set_provisions_for_testing(30.0)
	GameSession.set_line(true, GameSession.get_fishing().lure)
	stops.clear()
	Simulation.start_passage(Simulation.PASSAGE_RATES[2])
	guard = 0
	while Simulation.is_passage_running() and guard < 5000:
		guard += 1
		Simulation.tick(0.1)
	t.check(stops.has(Simulation.STOP_BITE) and not GameSession.get_pending_bite().is_empty(), "[long passage] stops for a bite (%s)" % [stops])
	GameSession.expire_bite()
	GameSession.set_line(false)
	stops.clear()
	_sail_in_passage_time(Simulation.PASSAGE_RATES[2])
	t.check(stops.has(Simulation.STOP_ARRIVAL) and GameSession.get_location_id() == &"lisbon", "[long passage] stops on arrival in Lisbon")
	# Pausing holds Long Passage time too; the player's stop ends it.
	GameSession.plan_route_to(&"gibraltar")
	GameSession.depart()
	Simulation.start_passage(Simulation.PASSAGE_RATES[0])
	GameSession.set_paused(true)
	var before := GameSession.get_game_time()
	Simulation.tick(0.1)
	t.check(GameSession.get_game_time() == before, "[long passage] paused: the clock stands still")
	GameSession.set_paused(false)
	Simulation.stop_passage()
	Simulation.tick(0.1)
	t.check(not Simulation.is_passage_running() and GameSession.get_game_time() - before < 3600.0, "[long passage] stopped: normal time again")
	# Loading a game always returns to normal time (Long Passage is not saved).
	Simulation.start_passage(Simulation.PASSAGE_RATES[0])
	GameSession.replace_state(GameSession.get_state_snapshot())
	t.check(not Simulation.is_passage_running(), "[long passage] loading a game returns to normal time")
	Simulation.passage_interrupted.disconnect(record)
	t.use_calm_wind()


func _test_passage_stores() -> void:
	_new_game()
	var catalog := VesselCatalog.get_default()
	var stores := {}
	for id in catalog.get_ids():
		stores[id] = catalog.get_vessel(id).passage_stores_days
	t.check(stores.values().all(func(days: float) -> bool: return days >= 30.0 and days <= Provisions.MAX_STORE_DAYS)
		and stores[&"arctic_wanderer_26"] < stores[&"halcyon_40"],
		"[stores] every boat can stow passage stores; small boats less (%s)" % [stores])
	var price := GameSession.get_provisions_price(GameSession.get_passage_store_days())
	var funds := GameSession.get_funds()
	t.check_eq(GameSession.buy_provisions(GameSession.get_passage_store_days()), "", "[stores] stock up for a long passage")
	t.check(is_equal_approx(GameSession.get_provisions().endurance_days(), GameSession.get_passage_store_days())
		and GameSession.get_funds() == funds - price, "[stores] filled to the boat's passage stores (%s) for %s" % [
			Provisions.format_days(GameSession.get_provisions().endurance_days()), GameSession.format_money(price)])
	t.check(GameSession.buy_provisions() != "", "[stores] above the everyday stores nothing more to buy for them")
	var errors: Array[String] = []
	var copy := Provisions.from_dict(GameSession.get_provisions().to_dict(), errors)
	t.check(errors.is_empty() and is_equal_approx(copy.food_days, GameSession.get_passage_store_days()),
		"[stores] saved and loaded as before (the same two numbers, save format 12)")


func _test_readiness() -> void:
	_new_game()
	var long: PlannedRoute = t.make_route(&"copenhagen", &"las_palmas")
	var result := PassageReadiness.assess(long.path)
	var text := PassageReadiness.describe(result, 8)
	t.check(result.items.any(func(item: Dictionary) -> bool: return item.topic == "forecast") and text.contains("not yet known"),
		"[readiness] an ocean passage: the forecast does not reach its end, and it says so")
	t.check(result.items.any(func(item: Dictionary) -> bool: return item.topic == "stores_capacity"),
		"[readiness] it suggests stocking up for the passage (%s)" % text.replace("\n", " "))
	t.check(result.level <= PassageReadiness.CONSIDER and GameSession.plan_route_to(&"las_palmas") == "" and GameSession.depart() == "",
		"[readiness] advisory only: the departure is never blocked")
	var short := PassageReadiness.assess(t.make_route(&"copenhagen", &"malmo").path)
	t.check(not short.items.any(func(item: Dictionary) -> bool: return item.topic == "forecast"), "[readiness] a short hop: no forecast note")


## Saves underway just past the Date Line and loads it again.
func _test_dateline_save() -> void:
	t.set_wind(90.0, 14.0)
	_new_game()
	var state := GameSession.get_state_snapshot()
	state.location_id = &"suva"
	state.vessel_position = PortCatalog.get_default().get_port(&"suva").get_geo_position()
	GameSession.replace_state(state)
	t.check_eq(GameSession.plan_route_to(&"avarua"), "", "[date line] Suva -> Avarua planned")
	GameSession.depart()
	var guard := 0
	while GameSession.is_underway() and GameSession.get_vessel_position().x > 0.0 and guard < 10000:
		guard += 1
		Simulation.advance(1800.0)
	var position := GameSession.get_vessel_position()
	var progress := GameSession.get_voyage_progress_nm()
	t.check(GameSession.is_underway() and position.x < 0.0 and position.x > -180.0, "[date line] underway just east of the Date Line at %s" % GeoMath.format_position(position))
	t.check_eq(SaveManager.save_to_slot(3, GameSession.get_state_snapshot()), OK, "[date line] saved")
	var loaded := SaveManager.load_from_slot(3)
	if t.check(loaded.is_ok(), "[date line] loaded (%s)" % loaded.error):
		GameSession.replace_state(loaded.state)
		t.check(GameSession.get_vessel_position().distance_to(position) < 1e-4 and absf(GameSession.get_voyage_progress_nm() - progress) < 1e-6
			and GameSession.get_last_location_recovery().is_empty(),
			"[date line] the same position and progress after loading, no recovery needed (%s → %s, %.3f → %.3f nm, %s)" % [
				position, GameSession.get_vessel_position(), progress, GameSession.get_voyage_progress_nm(), GameSession.get_last_location_recovery()])
		guard = 0
		while GameSession.is_underway() and guard < 10000:
			guard += 1
			Simulation.advance(3600.0)
		t.check_eq(GameSession.get_location_id(), &"avarua", "[date line] and the voyage ends in Avarua")
	SaveManager.delete_slot(3)
	t.use_calm_wind()


## The firsts of the voyage abroad, each once.
func _test_world_firsts() -> void:
	t.set_wind(100.0, 14.0)
	_new_game()
	var state := GameSession.get_state_snapshot()
	state.location_id = &"taiohae"
	state.vessel_position = PortCatalog.get_default().get_port(&"taiohae").get_geo_position()
	GameSession.replace_state(state)
	var progress := GameSession.get_objective_progress()
	for leg in [&"papeete", &"raiatea", &"papeete"]:
		GameSession.plan_route_to(leg)
		GameSession.depart()
		var guard := 0
		while GameSession.is_underway() and guard < 10000:
			guard += 1
			Simulation.advance(3600.0)
	progress = GameSession.get_objective_progress()
	for id in ["world:beyond_denmark", "world:first_international", "world:offshore_crossing", "world:pacific_arrival", "world:french_polynesia"]:
		t.check(progress.is_completed(StringName(id)), "[log] %s is in the Captain's Log" % id)
	t.check(not progress.is_completed(&"world:new_zealand") and not progress.is_completed(&"world:atlantic_crossing"),
		"[log] the firsts not yet earned are not given")
	var renown := GameSession.get_lifetime_renown()
	GameSession.plan_route_to(&"raiatea")
	GameSession.depart()
	var guard := 0
	while GameSession.is_underway() and guard < 10000:
		guard += 1
		Simulation.advance(3600.0)
	t.check(GameSession.get_lifetime_renown() - renown < 8, "[log] sailing on pays no first twice (%d renown)" % (GameSession.get_lifetime_renown() - renown))
	t.check(GameSession._is_atlantic_crossing(Vector2(-15.4, 28.1), Vector2(-61.0, 14.0))
		and not GameSession._is_atlantic_crossing(Vector2(12.6, 55.7), Vector2(-9.1, 38.7)),
		"[log] the Canaries to the Caribbean is an Atlantic crossing; Copenhagen to Lisbon is not")
	t.use_calm_wind()


## The panel on deck: shown underway on a long voyage, its speeds and
## buttons work, the chart and saving stop Long Passage time.
func _test_panel() -> void:
	var app := APP_SCENE.instantiate()
	t.add_child(app)
	app.router.fade_duration = 0.05
	await t.frames(2)
	await t.wait_until(func() -> bool: return not app.router.is_busy(), 5.0)
	app.start_new_game()
	await t.wait_until(func() -> bool: return not app.router.is_busy(), 5.0)
	await t.frames(3)
	t.set_wind(30.0, 14.0)
	var panel := (app.hud as Hud).passage_panel
	t.check(panel != null and not panel.visible, "[panel] moored: no Long Passage panel")
	GameSession.plan_route_to(&"las_palmas")
	GameSession.depart()
	Simulation.advance(600.0)
	await t.frames(3)
	t.check(panel.visible and panel.get_line("distance").contains("nm to go") and panel.get_line("stores").contains("Stores")
		and panel.get_line("outlook").contains("not yet known"),
		"[panel] underway to Las Palmas: position, distance and ETA, wind, outlook, stores and boat (%s)" % panel.get_line("distance"))
	(panel.find_child("Rate2", true, false) as Button).pressed.emit()
	t.check(Simulation.is_passage_running() and is_equal_approx(Simulation.passage_rate, Simulation.PASSAGE_RATES[2]), "[panel] 12 h/s starts Long Passage time")
	var before := GameSession.get_game_time()
	Simulation.tick(0.05)
	t.check(GameSession.get_game_time() - before > 1800.0, "[panel] hours pass in a moment (%.1f h in 0.05 s)" % ((GameSession.get_game_time() - before) / 3600.0))
	await t.screenshot("16_long_passage_panel")
	(panel.find_child("Save", true, false) as Button).pressed.emit()
	await t.frames(2)
	t.check(not Simulation.is_passage_running() and app.modals.get_top() is SaveLoadMenu, "[panel] Save stops Long Passage time and opens saving")
	app.modals.clear()
	(panel.find_child("Normal", true, false) as Button).pressed.emit()
	t.check(not Simulation.is_passage_running(), "[panel] Normal returns to normal time")
	Simulation.auto_advance = false
	app.queue_free()
	await t.frames(2)
	t.use_calm_wind()
