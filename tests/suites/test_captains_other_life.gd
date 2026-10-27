extends RefCounted
## I022, The Captain's Other Life: boats with prices (bought once, kept for
## good, never below zero money, old saves keep every boat), the three
## difficulty levels (what they change, saves, changing during a game), and
## the new game and pause menus that offer them.

const APP_SCENE := preload("res://src/app/app.tscn")

var t: Node
var app: Node


func run(runner: Node) -> void:
	t = runner
	_test_prices_and_new_games()
	_test_old_saves()
	_test_buying()
	_test_difficulty_factors()
	Simulation.auto_advance = false
	app = APP_SCENE.instantiate()
	t.add_child(app)
	app.router.fade_duration = 0.05
	await _settle()
	await _test_menus()
	app.queue_free()
	await t.frames(2)
	GameSession.test_all_boats_owned = true


func _settle() -> void:
	await t.frames(2)
	await t.wait_until(func() -> bool: return not app.router.is_busy(), 5.0)
	await t.physics_frames(3)


func _moor_in(port_id: StringName) -> void:
	var state := GameSession.get_state_snapshot()
	state.location_id = port_id
	state.vessel_status = SessionState.STATUS_MOORED
	state.vessel_position = PortCatalog.get_default().get_port(port_id).get_geo_position()
	state.voyage = null
	GameSession.replace_state(state)


func _round_trip() -> SessionState:
	var errors: Array[String] = []
	var data: Dictionary = JSON.parse_string(JSON.stringify(GameSession.get_state_snapshot().to_dict()))
	return SessionState.from_dict(data, errors)


# --- Boats and prices ------------------------------------------------------------------------------

func _test_prices_and_new_games() -> void:
	var catalog := VesselCatalog.get_default()
	var priced := catalog.vessels.all(func(v: VesselDefinition) -> bool: return v.price > 0)
	var starter := catalog.get_starter()
	var others := catalog.vessels.filter(func(v: VesselDefinition) -> bool: return v.id != starter.id)
	t.check(priced and others.all(func(v: VesselDefinition) -> bool: return v.price > starter.price),
		"[boats] every boat has a price, the starter the lowest (%s)" % [catalog.vessels.map(func(v: VesselDefinition) -> String: return "%s %d" % [v.id, v.price])])
	for level in Difficulty.LEVELS:
		GameSession.start_new_session(CompanionState.DEFAULT_KIND, level)
		t.check(GameSession.get_owned_vessels() == ([starter.id] as Array[StringName]) and GameSession.get_vessel_id() == starter.id
			and GameSession.get_funds() == Difficulty.starting_funds(level) and GameSession.get_difficulty() == level,
			"[new game] %s: aboard the starter, which is yours, with %s" % [level, GameSession.format_money(GameSession.get_funds())])
	t.check(Difficulty.starting_funds(Difficulty.RELAXED) > Difficulty.starting_funds(Difficulty.STANDARD)
		and Difficulty.starting_funds(Difficulty.STANDARD) == SessionState.STARTING_FUNDS
		and Difficulty.starting_funds(Difficulty.SEASONED) < Difficulty.starting_funds(Difficulty.STANDARD), "[new game] more money when relaxed, less when seasoned")
	GameSession.start_new_session(CompanionState.DEFAULT_KIND, Difficulty.SEASONED)
	var back := _round_trip()
	t.check(back != null and back.difficulty == Difficulty.SEASONED and back.owned_vessels == ([starter.id] as Array[StringName]),
		"[saves] the difficulty and the owned boats are saved")


func _test_old_saves() -> void:
	GameSession.start_new_session()
	var data: Dictionary = JSON.parse_string(JSON.stringify(GameSession.get_state_snapshot().to_dict()))
	data.erase("fleet")
	data.erase("difficulty")
	data.vessel.id = "petrel_36"
	var errors: Array[String] = []
	var old := SessionState.from_dict(data, errors)
	t.check(old != null and errors.is_empty() and old.difficulty == Difficulty.STANDARD
		and old.owned_vessels.size() == VesselCatalog.get_default().vessels.size() and old.funds == GameSession.get_funds(),
		"[old saves] a save from before I022: every boat stays yours (they were all free to sail), Standard, the money unchanged (%s)" % [errors])
	var odd: Dictionary = data.duplicate(true)
	odd["fleet"] = {"owned": ["gold_yacht", 7, "starling_33"]}
	odd["difficulty"] = "nightmare"
	var tolerant := SessionState.from_dict(odd, errors)
	t.check(tolerant != null and tolerant.difficulty == Difficulty.STANDARD and tolerant.owned_vessels == ([&"starling_33", &"petrel_36"] as Array[StringName]),
		"[saves] unknown boats and levels are dropped; the boat aboard is always yours (%s)" % [tolerant.owned_vessels if tolerant else []])


func _test_buying() -> void:
	GameSession.test_all_boats_owned = false
	GameSession.start_new_session()
	_moor_in(&"copenhagen")
	var wing := VesselCatalog.get_default().get_vessel(&"starling_33")
	var funds := GameSession.get_funds()
	t.check(GameSession.switch_vessel(&"starling_33") != "" and GameSession.get_vessel_id() == VesselCatalog.STARTER_ID,
		"[buying] a boat that is not yours cannot be sailed away")
	t.check(GameSession.buy_vessel(&"starling_33") != "" and GameSession.get_funds() == funds and not GameSession.owns_vessel(&"starling_33"),
		"[buying] not enough money: refused, the money untouched (%s for %s)" % [GameSession.format_money(funds), GameSession.format_money(wing.price)])
	var state := GameSession.get_state_snapshot()
	state.funds = wing.price + 500
	GameSession.replace_state(state)
	var bought := []
	GameSession.fleet_changed.connect(func() -> void: bought.append(true), CONNECT_ONE_SHOT)
	t.check(GameSession.buy_vessel(&"starling_33") == "" and GameSession.get_funds() == 500 and GameSession.owns_vessel(&"starling_33")
		and not bought.is_empty(), "[buying] bought for %s: 500 left, the Wing 33 is yours" % GameSession.format_money(wing.price))
	t.check(GameSession.buy_vessel(&"starling_33") != "" and GameSession.get_funds() == 500, "[buying] never twice")
	t.check(GameSession.switch_vessel(&"starling_33") == "" and GameSession.get_vessel_id() == &"starling_33"
		and GameSession.switch_vessel(VesselCatalog.STARTER_ID) == "", "[buying] move aboard it, and back to the first boat (still yours, free)")
	var back := _round_trip()
	t.check(back != null and back.owned_vessels.has(&"starling_33") and back.owned_vessels.has(VesselCatalog.STARTER_ID) and back.funds == 500,
		"[saves] the bought boat stays yours after saving and loading")
	GameSession.plan_route_to(&"helsingor")
	GameSession.depart()
	state = GameSession.get_state_snapshot()
	state.funds = 99999
	GameSession.replace_state(state)
	t.check(GameSession.buy_vessel(&"halcyon_40") != "" and not GameSession.owns_vessel(&"halcyon_40"), "[buying] only at a boatyard in harbour")
	GameSession.test_all_boats_owned = true


# --- Difficulty -------------------------------------------------------------------------------------

func _test_difficulty_factors() -> void:
	var results := {}
	for level in Difficulty.LEVELS:
		GameSession.start_new_session(CompanionState.DEFAULT_KIND, level)
		_moor_in(&"copenhagen")
		var before := GameSession.get_provisions().food_days
		Simulation.advance(86400.0)
		var eaten := before - GameSession.get_provisions().food_days
		results[level] = {"eaten": eaten, "price": GameSession.get_provisions_price(), "repair": int(GameSession.service_quote(BoatCare.SERVICE_ENGINE).cost)}
	var s: Dictionary = results[Difficulty.STANDARD]
	var r: Dictionary = results[Difficulty.RELAXED]
	var h: Dictionary = results[Difficulty.SEASONED]
	t.check(absf(s.eaten - 1.0) < 1e-6, "[difficulty] Standard: one day's food a day, as before (%.3f)" % s.eaten)
	t.check(r.eaten < s.eaten and h.eaten > s.eaten, "[difficulty] food lasts longer when relaxed, shorter when seasoned (%.2f / %.2f / %.2f)" % [r.eaten, s.eaten, h.eaten])
	t.check(r.repair < s.repair and h.repair > s.repair and r.price < s.price and h.price > s.price,
		"[difficulty] boat care and provisions cost less when relaxed, more when seasoned (engine service %d / %d / %d)" % [r.repair, s.repair, h.repair])
	t.check(Difficulty.value_of(Difficulty.STANDARD, "wear") == 1.0 and Difficulty.value_of(Difficulty.SEASONED, "wear") > 1.0
		and Difficulty.value_of(Difficulty.RELAXED, "weather_damage") < 1.0, "[difficulty] wear and weather damage scale; the weather itself is the same")
	# Changing during a game: from now on, nothing taken back.
	GameSession.start_new_session()
	var funds := GameSession.get_funds()
	var heard := []
	GameSession.difficulty_changed.connect(func(level: StringName) -> void: heard.append(level), CONNECT_ONE_SHOT)
	GameSession.set_difficulty(Difficulty.RELAXED)
	t.check(GameSession.get_difficulty() == Difficulty.RELAXED and GameSession.get_funds() == funds and heard == [Difficulty.RELAXED],
		"[difficulty] changed during a game: it counts from now on, the money stays as it was")
	SettingsManager.set_language(&"da")
	var names := Difficulty.LEVELS.map(func(level: StringName) -> String: return Difficulty.display_name(level))
	var texts := Difficulty.LEVELS.all(func(level: StringName) -> bool: return Difficulty.describe(level) != "" and Loc.t(Difficulty.describe(level)) == Difficulty.describe(level))
	SettingsManager.set_language(&"en")
	t.check(names == ["Afslappet", "Standard", "Erfaren skipper"] and texts, "[dansk] %s" % [names])


# --- Menus -----------------------------------------------------------------------------------------

func _test_menus() -> void:
	app.open_new_game_menu()
	await t.frames(3)
	var menu := app.modals.get_top() as NewGameMenu
	if not t.check(menu != null and menu.difficulty != null and menu.difficulty.level == Difficulty.STANDARD,
			"[menus] New Game offers the difficulty, Standard chosen"):
		return
	await t.click(menu.difficulty.find_child("Seasoned", true, false))
	await t.click(menu.find_child("StartButton", true, false))
	await _settle()
	t.check(GameSession.get_difficulty() == Difficulty.SEASONED and GameSession.get_funds() == Difficulty.starting_funds(Difficulty.SEASONED),
		"[menus] starting a Seasoned Captain's game")
	app.open_pause_menu()
	await t.frames(3)
	var pause: Node = app.modals.get_top()
	var button := pause.find_child("DifficultyButton", true, false) as Button if pause else null
	if not t.check(button != null, "[menus] the pause menu offers Difficulty…"):
		return
	await t.click(button)
	await t.frames(3)
	var dialog := app.modals.get_top() as DifficultyMenu
	if not t.check(dialog != null and dialog.picker.level == Difficulty.SEASONED, "[menus] the Difficulty dialog shows the current level"):
		return
	await t.screenshot("i022_difficulty")
	await t.click(dialog.picker.find_child("Relaxed", true, false))
	await t.click(dialog.find_child("ApplyButton", true, false))
	await t.frames(2)
	t.check(GameSession.get_difficulty() == Difficulty.RELAXED and app.modals.get_top() == pause, "[menus] applied, and the dialog closes back to the pause menu")
	app.modals.clear()
	await t.frames(2)
	t.check(app.modals.is_empty(), "[menus] everything opened can be closed")
