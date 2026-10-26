extends Node
## Iteration 18 (SAVE): saving and loading in a new process - three scenarios.
## Run twice, as two separate processes (the game quits in between):
##   godot --headless --path . res://tests/restart_18.tscn -- --phase=write
##   godot --headless --path . res://tests/restart_18.tscn -- --phase=read
##
## A - Fishing (slot 1): keep preferences set (Uncommon or better, Silver or
##     better); a cod landed through the reel dial and kept; a herring landed
##     and let go by the preferences; a sea trout landed, kept, then released
##     by hand. Read: the hold, the trophies, the preferences and the counts
##     exactly as saved.
## B - Anchorage (slot 2): a course to Gothenburg with an anchorage waypoint
##     marked on the chart; sailed to it; anchored there; the companion up on
##     deck. Read: position, anchor, the anchorage done, the course, the
##     companion on deck (shown there); then the anchor comes up and the
##     voyage goes on to Gothenburg exactly as it did in the first process.
## C - Sailing (slot 3): the sails trimmed by hand; under way for Las Palmas;
##     six hours sailed. Read: trim, trim factor, weather, course, progress and
##     stores as saved; six more hours lead where they did in the first
##     process, in the same weather, with the same stores.
## Exits 0 only if everything holds.

const APP_SCENE := preload("res://src/app/app.tscn")
const Reel := preload("res://tests/helpers/reel.gd")
const SAVE_DIR := "user://test_restart18_saves"
const EXPECT_PATH := "user://test_restart18_expect.json"
const SIX_HOURS := 6.0 * 3600.0

var app: Node
var failures := PackedStringArray()


func _ready() -> void:
	var phase := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--phase="):
			phase = arg.trim_prefix("--phase=")
	SaveManager.save_dir = SAVE_DIR
	SessionLog.log_dir = "user://test_restart18_diagnostics"
	Simulation.auto_advance = false
	# Fair, steady wind in both processes (the same everywhere and always), so
	# the scenarios do not depend on the season's weather.
	WindField.get_default().test_override = func(_geo: Vector2, _time: float) -> WindField.Sample:
		return WindField.Sample.make(200.0, 10.0)
	app = APP_SCENE.instantiate()
	add_child(app)
	app.router.fade_duration = 0.05
	if phase == "write":
		_write.call_deferred()
	elif phase == "read":
		_read.call_deferred()
	else:
		push_error("Use --phase=write or --phase=read")
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
	for i in 4:
		await get_tree().physics_frame


func _show(area: StringName) -> BoatArea:
	app.modals.clear()
	GameSession.enter_boat_area(area, &"start")
	app._show_current_boat_area()
	await _idle()
	return app.router.current_screen as BoatArea


func _weather_text() -> String:
	var w := Simulation.get_weather_at_vessel()
	return "%.4f|%.4f|%.4f|%s" % [w.speed_kn, w.from_deg, w.gust_kn, w.classification]


func _json(value: Variant) -> String:
	return JSON.stringify(value, "", true)


func _fishing_view() -> Dictionary:
	var f := GameSession.get_fishing().to_dict()
	return {"hold": f.get("hold"), "trophies": f.get("trophies"), "records": f.get("records"),
		"keep_min_rarity": f.get("keep_min_rarity"), "keep_min_grade": f.get("keep_min_grade"),
		"released": f.get("released"), "total_caught": f.get("total_caught")}


func _stores() -> Array:
	var p := GameSession.get_provisions()
	return [snappedf(p.food_days, 1e-6), snappedf(p.water_days, 1e-6)]


## A bite of `species` (as the fishing tests force one), reeled in through
## the dial; returns the result.
func _catch(species: String, kg: float) -> Dictionary:
	var catalog := FishingCatalog.get_default()
	GameSession.expire_bite()
	GameSession._pending_bite = {"species": species, "kg": kg, "time": GameSession.get_game_time(), "mode": "stationary",
		"lure": "spinner", "kind": String(catalog.kind_of(species)), "rarity": catalog.rarity_of(species)}
	var menu: FishingMenu = app.open_fishing()
	await _frames(3)
	if menu == null or not menu.is_reeling():
		return {}
	Reel.land(menu)
	var result := menu.get_last_result()
	app.modals.clear()
	await _frames(2)
	return result


# --- Write -----------------------------------------------------------------------

func _write() -> void:
	for slot in [1, 2, 3]:
		SaveManager.delete_slot(slot)
	await _idle()
	var expect := {}
	expect["A"] = await _write_fishing()
	expect["B"] = await _write_anchorage()
	expect["C"] = await _write_sailing()
	var file := FileAccess.open(EXPECT_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(expect, "", true, true))
	file.close()
	print("RESTART18 write phase done (%s)" % ("all set up" if failures.is_empty() else "; ".join(failures)))
	get_tree().quit(0 if failures.is_empty() else 1)


func _write_fishing() -> Dictionary:
	app.start_new_game()
	await _idle()
	await _show(SessionState.AREA_EXTERIOR)
	GameSession.set_keep_preferences("uncommon", FishingCatalog.GRADE_SILVER)
	var cod := await _catch("cod", 9.0)
	var herring := await _catch("herring", 0.2)
	var trout := await _catch("sea_trout", 5.6)
	_check(bool(cod.get("landed")) and bool(cod.get("kept")), "A (setup): the cod is landed and kept (%s)" % [cod])
	_check(bool(herring.get("landed")) and not bool(herring.get("kept")), "A (setup): the herring is landed and let go by the preferences (%s)" % [herring])
	var uid := int((trout.get("fish", {}) as Dictionary).get("uid", -1))
	_check(bool(trout.get("kept")) and GameSession.release_fish(uid), "A (setup): the sea trout is kept, then released by hand (%s)" % [trout])
	SaveManager.save_to_slot(1, GameSession.get_state_snapshot())
	var view := _fishing_view()
	print("RESTART18 A wrote: %s" % _json(view))
	return {"fishing": _json(view), "hold_size": (view.hold as Array).size(), "time": GameSession.get_game_time()}


func _write_anchorage() -> Dictionary:
	app.start_new_game()
	await _idle()
	app.open_chart()
	await _idle()
	var world := app.router.current_screen as WorldMap
	if world == null:
		_check(false, "B (setup): the chart opens")
		return {}
	world.set_wind_shown(false)
	world.plot_course_to(&"gothenburg")
	await _frames(1)
	# A point on the course far from land; the chart's own suggestion moves it
	# to the nearest place one can anchor, and it is marked as an anchorage.
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
	await _frames(1)
	var spot: Vector2 = world.get_draft_waypoints()[index]
	_check(world.is_anchorage(index) and world.apply_course() == "", "B (setup): a course to Gothenburg with an anchorage at %s" % GeoMath.format_position(spot))
	app.close_chart()
	await _idle()
	_check(GameSession.depart() == "", "B (setup): cast off")
	var guard := 0
	while not GameSession.is_holding_at_anchorage() and GameSession.is_underway() and guard < 400:
		Simulation.advance(600.0, true)
		guard += 1
	_check(GameSession.is_holding_at_anchorage(), "B (setup): the boat reaches the anchorage and waits there")
	var dropped := GameSession.drop_anchor(5, 0.9)
	_check(dropped.error == "" and GameSession.is_anchored(), "B (setup): anchored at the anchorage (%s)" % dropped.error)
	var deck := await _show(SessionState.AREA_EXTERIOR)
	for i in 40:
		app._update_companion_follow(0.25)
		await _frames(1)
	_check(GameSession.get_companion().area == CompanionState.AREA_DECK, "B (setup): the companion has come up on deck")
	var walk := 0
	while deck.get_deck_companion().is_walking() and walk < 2000:
		walk += 1
		await _frames(1)
	SaveManager.save_to_slot(2, GameSession.get_state_snapshot())
	var voyage := GameSession.get_voyage()
	var anchor := GameSession.get_anchor()
	var e := {"vessel": [GameSession.get_vessel_position().x, GameSession.get_vessel_position().y], "spot": [spot.x, spot.y],
		"time": GameSession.get_game_time(), "anchor": _json(anchor.to_dict()), "anchorages_done": _json(voyage.anchorages_done),
		"route": _json(voyage.route.to_dict()), "remaining": _json(voyage.get_remaining_path()),
		"progress": GameSession.get_voyage_progress_nm(), "companion": GameSession.get_companion().area,
		"deck_spot": GameSession.get_companion().deck_spot}
	# The voyage goes on: anchor up, sail to Gothenburg.
	e["arrival"] = _sail_on_to_harbour()
	print("RESTART18 B wrote: %s" % _json(e))
	return e


## Weighs anchor and sails on until the voyage ends: [where, game time].
func _sail_on_to_harbour() -> Array:
	GameSession.raise_anchor()
	for i in 400:
		Simulation.advance(1800.0, true)
		if not GameSession.is_underway():
			break
	return [String(GameSession.get_location_id()), GameSession.get_game_time()]


func _write_sailing() -> Dictionary:
	app.start_new_game()
	await _idle()
	GameSession.set_sail_trim(false, 0.6)
	GameSession.plan_route_to(&"las_palmas")
	_check(GameSession.depart() == "", "C (setup): cast off for Las Palmas")
	Simulation.advance(SIX_HOURS)
	await _show(SessionState.AREA_EXTERIOR)
	SaveManager.save_to_slot(3, GameSession.get_state_snapshot())
	var e := {"trim": _json(GameSession.get_sail_trim()), "factor": GameSession.get_trim_factor(),
		"speed": GameSession.get_vessel_speed_kn(), "weather": _weather_text(),
		"vessel": [GameSession.get_vessel_position().x, GameSession.get_vessel_position().y], "time": GameSession.get_game_time(),
		"route": _json(GameSession.get_voyage().route.to_dict()), "progress": GameSession.get_voyage_progress_nm(), "stores": _stores()}
	Simulation.advance(SIX_HOURS)
	e["after_vessel"] = [GameSession.get_vessel_position().x, GameSession.get_vessel_position().y]
	e["after_weather"] = _weather_text()
	e["after_stores"] = _stores()
	e["after_progress"] = GameSession.get_voyage_progress_nm()
	print("RESTART18 C wrote: %s" % _json(e))
	return e


# --- Read ------------------------------------------------------------------------

func _close(a: Array, b: Vector2, tolerance: float) -> bool:
	return Vector2(a[0], a[1]).distance_to(b) <= tolerance


func _read() -> void:
	var expect: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(EXPECT_PATH))
	await _idle()
	await _read_fishing(expect.A)
	await _read_anchorage(expect.B)
	await _read_sailing(expect.C)
	print("RESTART18 %s" % ("PASS" if failures.is_empty() else "FAIL: " + "; ".join(failures)))
	for slot in [1, 2, 3]:
		SaveManager.delete_slot(slot)
	get_tree().quit(0 if failures.is_empty() else 1)


func _read_fishing(e: Dictionary) -> void:
	app.load_slot(1)
	await _idle()
	var view := _fishing_view()
	_check(_json(view) == e.fishing, "A: the hold, trophies, records, preferences and counts are exactly as saved")
	var hold: Array = view.hold
	_check(hold.size() == int(e.hold_size) and hold.size() == 1 and String(hold[0].get("species")) == "cod",
		"A: in the hold, the kept cod only (the herring let go, the trout released)")
	_check(view.keep_min_rarity == "uncommon" and String(view.keep_min_grade) == "silver", "A: the preferences: Uncommon or better, Silver or better")
	var trophies: Array = view.trophies
	_check(trophies.all(func(t: Dictionary) -> bool: return String(t.get("species")) != "sea_trout" and String(t.get("species")) != "herring"),
		"A: no trophy for a fish that was let go (%d trophies)" % trophies.size())


func _read_anchorage(e: Dictionary) -> void:
	app.load_slot(2)
	await _idle()
	var area := app.router.current_screen as BoatArea
	var voyage := GameSession.get_voyage()
	_check(_close(e.vessel, GameSession.get_vessel_position(), 1e-6) and _close(e.spot, GameSession.get_vessel_position(), 1e-3)
		and absf(float(e.time) - GameSession.get_game_time()) < 0.01, "B: at the anchorage, at the saved time")
	_check(GameSession.is_anchored() and _json(GameSession.get_anchor().to_dict()) == e.anchor, "B: at anchor, as saved (scope, holding)")
	_check(voyage != null and _json(voyage.anchorages_done) == e.anchorages_done and voyage.holding_at == -1,
		"B: the anchorage is done, not waiting to be asked again")
	_check(_json(voyage.route.to_dict()) == e.route and _json(voyage.get_remaining_path()) == e.remaining
		and absf(float(e.progress) - GameSession.get_voyage_progress_nm()) < 1e-6, "B: the course and the way left are as saved")
	var companion := area.get_deck_companion() if area else null
	_check(GameSession.get_companion().area == e.companion and GameSession.get_companion().deck_spot == int(e.deck_spot)
		and area != null and area.area_id == SessionState.AREA_EXTERIOR and companion != null and companion.visible,
		"B: the companion is on deck, at its place, and shown there")
	_check(not app.is_anchorage_prompt_due(), "B: no arrival question after loading")
	var arrival := _sail_on_to_harbour()
	_check(arrival[0] == e.arrival[0] and absf(float(arrival[1]) - float(e.arrival[1])) < 0.01,
		"B: anchor up, the voyage continues to %s, arriving when it did in the first process (%s)" % [arrival[0], arrival])


func _read_sailing(e: Dictionary) -> void:
	app.load_slot(3)
	await _idle()
	_check(_json(GameSession.get_sail_trim()) == e.trim and is_equal_approx(GameSession.get_trim_factor(), float(e.factor)),
		"C: trimmed by hand as saved (factor %.3f)" % GameSession.get_trim_factor())
	_check(is_equal_approx(GameSession.get_vessel_speed_kn(), float(e.speed)), "C: the boat sails at the saved speed (%.2f kn)" % GameSession.get_vessel_speed_kn())
	_check(_weather_text() == e.weather, "C: the same weather at the boat")
	_check(_close(e.vessel, GameSession.get_vessel_position(), 1e-6) and absf(float(e.time) - GameSession.get_game_time()) < 0.01
		and _json(GameSession.get_voyage().route.to_dict()) == e.route and absf(float(e.progress) - GameSession.get_voyage_progress_nm()) < 1e-6,
		"C: position, time, course and progress as saved")
	_check(_stores() == e.stores, "C: the stores as saved (%s)" % [_stores()])
	Simulation.advance(SIX_HOURS)
	_check(_close(e.after_vessel, GameSession.get_vessel_position(), 1e-6) and _weather_text() == e.after_weather
		and _stores() == e.after_stores and absf(float(e.after_progress) - GameSession.get_voyage_progress_nm()) < 1e-6,
		"C: six hours later: where the first process got, same weather, same stores")


func _check(condition: bool, text: String) -> void:
	print("RESTART18 %s %s" % ["ok  " if condition else "FAIL", text])
	if not condition:
		failures.append(text)
