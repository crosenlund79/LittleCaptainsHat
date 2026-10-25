extends RefCounted
## Iteration 005b: the price of the passage. Boat condition and weather
## damage, harbour repair, rescue at sea with its fee, money, food and water,
## restocking, determinism across ways of advancing time, persistence and
## save migration. Drives GameSession and Simulation directly (the UI is
## covered by test_upkeep_ui).

const START_DAY := 86400.0
const HOUR := 3600.0

var t: Node
var rescues: Array[Dictionary] = []
var warnings: Array[int] = []


func run(runner: Node) -> void:
	t = runner
	Simulation.auto_advance = false
	t.use_calm_wind()
	WeatherFixtures.clear()
	GameSession.rescued.connect(_on_rescued)
	GameSession.provisions_warning.connect(_on_provisions_warning)

	_test_starting_state()
	_test_provisions_consumption()
	_test_provisions_warnings_and_depletion()
	_test_damage_rates()
	_test_weather_damage()
	_test_damage_time_steps()
	_test_vessels_and_repair()
	_test_rescue()
	_test_rescue_while_advancing()
	_test_money_limits()
	_test_persistence_and_migration()

	GameSession.rescued.disconnect(_on_rescued)
	GameSession.provisions_warning.disconnect(_on_provisions_warning)
	WeatherFixtures.clear()
	Simulation.auto_advance = true
	GameSession.end_session()
	t.use_calm_wind()


func _on_rescued(info: Dictionary) -> void:
	rescues.append(info)


func _on_provisions_warning(level: int, _text: String) -> void:
	warnings.append(level)


func _new_game(vessel := &"starling_33") -> void:
	WeatherFixtures.use([])
	GameSession.start_new_session()
	if vessel != VesselCatalog.STARTER_ID:
		GameSession.switch_vessel(vessel)
	rescues.clear()
	warnings.clear()


func _depart() -> void:
	GameSession.plan_route_to(&"kiel")
	t.check_eq(GameSession.depart(), "", "(setup) underway to Kiel")


## A stationary gale or storm around the boat (whole voyage leg inside it).
func _weather_at_boat(peak: float, radius := 80.0, hours := 96.0) -> void:
	WeatherFixtures.use([WeatherFixtures.gale("fx_heavy", GameSession.get_vessel_position(), radius, peak,
		GameSession.get_game_time() - HOUR, hours, 0.0, 0.0, 250.0)])


# --- Starting state ------------------------------------------------------------------

func _test_starting_state() -> void:
	_new_game()
	t.check_eq(GameSession.get_funds(), 10000, "[start] a new game has €10,000")
	t.check_eq(GameSession.format_money(GameSession.get_funds()), "€10,000", "[start] shown as €10,000")
	t.check(is_equal_approx(GameSession.get_food_days(), 14.0) and is_equal_approx(GameSession.get_water_days(), 14.0),
		"[start] 14 days of food and 14 days of water")
	var all_full := VesselCatalog.get_default().get_ids().all(func(id: StringName) -> bool:
		return is_equal_approx(GameSession.get_vessel_condition(id), 100.0))
	t.check(all_full and is_equal_approx(GameSession.get_condition(), 100.0), "[start] every boat is in perfect condition (100 %)")
	t.check_eq(VesselCondition.describe(GameSession.get_condition()), "100 % · Sound", "[start] described as '100 % · Sound'")
	t.check_eq(GameSession.get_rescue_count(), 0, "[start] no rescues yet")


# --- Provisions ---------------------------------------------------------------------

func _test_provisions_consumption() -> void:
	_new_game()
	Simulation.advance(START_DAY)
	t.check(absf(GameSession.get_food_days() - 13.0) < 1e-6 and absf(GameSession.get_water_days() - 13.0) < 1e-6,
		"[provisions] moored, one game day uses one day of food and water (%.6f)" % GameSession.get_food_days())
	Simulation.advance(6.0 * HOUR)
	t.check(absf(GameSession.get_food_days() - 12.75) < 1e-6, "[provisions] 6 hours use 0.25 day (%.4f)" % GameSession.get_food_days())
	# Paused: frames pass, nothing is used.
	GameSession.set_paused(true)
	var before := GameSession.get_food_days()
	for i in 30:
		Simulation.tick(1.0)
	t.check_eq(GameSession.get_food_days(), before, "[provisions] while paused nothing is used")
	# Sleeping while paused moves time on, so it uses provisions.
	Simulation.sleep(12.0)
	t.check(absf(GameSession.get_food_days() - (before - 0.5)) < 1e-6 and GameSession.is_paused(),
		"[provisions] sleeping 12 h (while paused) uses half a day and stays paused")
	GameSession.set_paused(false)
	# Underway too.
	_depart()
	var underway := GameSession.get_food_days()
	Simulation.advance(12.0 * HOUR)
	t.check(absf(GameSession.get_food_days() - (underway - 0.5)) < 1e-6, "[provisions] underway, 12 hours use half a day")
	# The same game time at 1×, 20× and in one step uses the same amount.
	var results := []
	for mode in ["1x", "20x", "large"]:
		_new_game()
		_drive_for(6.0 * HOUR, mode)
		results.append(GameSession.get_food_days())
	t.check(absf(results[0] - 13.75) < 1e-6 and absf(results[1] - results[0]) < 1e-6 and absf(results[2] - results[0]) < 1e-6,
		"[provisions] 6 h at 1×, 20× or in one step all use 0.25 day (%s)" % [results])


func _test_provisions_warnings_and_depletion() -> void:
	_new_game()
	GameSession.set_provisions_for_testing(3.2)
	warnings.clear()
	Simulation.advance(0.3 * START_DAY)
	t.check_eq(warnings, [Provisions.WARN_LOW], "[provisions] at 3 days left a 'running low' warning is given")
	Simulation.advance(0.5 * START_DAY)
	t.check_eq(warnings, [Provisions.WARN_LOW], "[provisions] it is not repeated")
	Simulation.advance(1.5 * START_DAY)
	t.check_eq(warnings, [Provisions.WARN_LOW, Provisions.WARN_CRITICAL], "[provisions] below one day: 'critically low', once")
	Simulation.advance(2.0 * START_DAY)
	t.check_eq(warnings, [Provisions.WARN_LOW, Provisions.WARN_CRITICAL, Provisions.WARN_EMPTY], "[provisions] at zero: 'run out', once")
	Simulation.advance(5.0 * START_DAY)
	t.check(GameSession.get_food_days() == 0.0 and GameSession.get_water_days() == 0.0 and warnings.size() == 3,
		"[provisions] never below zero, no more warnings")
	t.check(is_equal_approx(GameSession.get_condition(), 100.0), "[provisions] running out does not damage the boat")
	# No departure without stores; buying in harbour fills them again
	# (Iteration 005c: at the grocery store, EUR 10 per missing day).
	GameSession.plan_route_to(&"kiel")
	t.check(GameSession.depart().contains("out of food or water"), "[provisions] no departure with empty stores")
	t.check(not GameSession.is_underway(), "[provisions] the boat stays in harbour")
	t.check_eq(GameSession.get_provisions_price(), 280, "[buy] 28 missing days (14 food + 14 water) cost €280")
	t.check_eq(GameSession.buy_provisions(), "", "[buy] buying provisions in harbour works")
	t.check(is_equal_approx(GameSession.get_food_days(), 14.0) and is_equal_approx(GameSession.get_water_days(), 14.0),
		"[buy] food and water are full again (14 days)")
	t.check(GameSession.buy_provisions().contains("already full"), "[buy] buying when full is refused")
	t.check_eq(GameSession.get_funds(), 9720, "[buy] paid €280: €9,720 left")
	t.check_eq(GameSession.depart(), "", "[provisions] then the boat can sail")
	t.check(GameSession.buy_provisions().contains("harbour"), "[buy] not possible underway")
	# Running out at sea: the voyage goes on to the harbour.
	GameSession.set_provisions_for_testing(0.0)
	var progress := GameSession.get_voyage_progress_nm()
	Simulation.advance(2.0 * HOUR)
	t.check(GameSession.is_underway() and GameSession.get_voyage_progress_nm() > progress + 5.0 and rescues.is_empty(),
		"[provisions] out of stores at sea, the voyage continues (no rescue, no harm)")
	warnings.clear()
	GameSession.set_provisions_for_testing(0.2)
	t.check_eq(warnings, [Provisions.WARN_CRITICAL], "[provisions] warnings start again after the stores change")


# --- Damage -------------------------------------------------------------------------

func _test_damage_rates() -> void:
	t.check_eq(WeatherDamage.rate_per_hour(18.0, 24.0), 0.0, "[damage] an ordinary breeze does no damage")
	t.check_eq(WeatherDamage.rate_per_hour(28.0, 37.0), 0.0, "[damage] strong winds (caution) do no damage")
	var gale := WeatherDamage.rate_per_hour(34.0, 46.0)
	var forty := WeatherDamage.rate_per_hour(40.0, 54.0)
	var storm := WeatherDamage.rate_per_hour(48.0, 65.0)
	t.check(gale > 0.5 and gale < 2.0, "[damage] a gale costs about 1 %% an hour (%.2f)" % gale)
	t.check(forty > 3.5 and forty < 6.5, "[damage] 40 kn costs about 5 %% an hour (%.2f)" % forty)
	t.check(storm > 9.0 and storm < 14.0, "[damage] a storm costs about 11 %% an hour (%.2f)" % storm)
	t.check(WeatherDamage.rate_per_hour(22.0, 55.0) > 1.5, "[damage] squall gusts alone do damage")
	t.check(is_equal_approx(WeatherDamage.rate_per_hour(40.0, 54.0, 0.85), forty * 0.85), "[damage] scaled by the boat's resilience")


func _test_weather_damage() -> void:
	# Ordinary generated weather on a whole passage: no unreasonable damage.
	WindField.get_default().test_override = Callable()
	GameSession.start_new_session()
	WeatherFixtures.clear()
	_depart()
	for i in 6:
		if GameSession.is_underway():
			Simulation.sleep(12.0)
	t.check(GameSession.get_condition() >= 90.0, "[damage] a passage in ordinary weather leaves the boat sound (%.1f %%)" % GameSession.get_condition())
	t.use_calm_wind()

	# Caution: survivable.
	_new_game()
	_depart()
	_weather_at_boat(29.0)
	Simulation.advance(6.0 * HOUR)
	t.check(GameSession.get_condition() > 97.0, "[damage] six hours of strong winds (caution) cost little (%.1f %%)" % GameSession.get_condition())

	# Dangerous: a real cost that grows with exposure.
	_new_game()
	_depart()
	_weather_at_boat(42.0)
	Simulation.advance(2.0 * HOUR)
	var two := 100.0 - GameSession.get_condition()
	Simulation.advance(2.0 * HOUR)
	var four := 100.0 - GameSession.get_condition()
	t.check(two > 3.0 and two < 25.0, "[damage] two hours in a 42 kn gale cost %.1f %%" % two)
	t.check(four > two * 1.6 and four < two * 2.4, "[damage] damage grows with the time in it (2 h %.1f, 4 h %.1f)" % [two, four])
	t.check(GameSession.get_condition() > 0.0 and rescues.is_empty(), "[damage] a gale is not instantly fatal")
	var exposure := GameSession.get_weather_exposure()
	t.check(exposure.level >= WeatherModel.HAZARD_DANGEROUS, "[damage] the exposure record shows the dangerous weather")

	# Severe gusts contribute: a squall cell whose sustained wind alone is harmless.
	_new_game()
	_depart()
	var here := GameSession.get_vessel_position()
	WeatherFixtures.use([WeatherFixtures.thunderstorm("fx_gusty", here, 25.0, 20.0, 40.0, GameSession.get_game_time() - HOUR, 60.0, 0.0, 0.0)])
	var sustained_max := 0.0
	var gust_max := 0.0
	for i in 24:
		Simulation.advance(300.0)
		var w := Simulation.get_weather_at_vessel()
		sustained_max = maxf(sustained_max, w.speed_kn)
		gust_max = maxf(gust_max, w.gust_kn)
	t.check(sustained_max < WeatherDamage.SUSTAINED_FROM_KN and gust_max > 45.0,
		"[damage] (setup) squall: sustained up to %.0f kn, gusts to %.0f kn" % [sustained_max, gust_max])
	t.check(GameSession.get_condition() < 100.0, "[damage] the gust bursts do damage (%.2f %%)" % (100.0 - GameSession.get_condition()))

	# Moored: no voyage weather damage, however bad.
	_new_game()
	_weather_at_boat(60.0)
	Simulation.advance(24.0 * HOUR)
	t.check(is_equal_approx(GameSession.get_condition(), 100.0), "[damage] moored in harbour the weather does no damage")


## Drives the game for `seconds` of game time in one of several ways.
func _drive_for(seconds: float, mode: String) -> void:
	var target := GameSession.get_game_time() + seconds
	match mode:
		"1x", "5x", "20x":
			var scale := int(mode.trim_suffix("x"))
			var guard := 100000
			while GameSession.get_game_time() < target - 1e-6 and guard > 0:
				guard -= 1
				GameSession.set_time_scale(scale)
				var left := target - GameSession.get_game_time()
				Simulation.tick(minf(1.0, left / (Simulation.game_seconds_per_real_second * scale)))
				if rescues.size() > 0:
					break
		"large":
			Simulation.advance(seconds)
		"sleep":
			var guard := 100
			while GameSession.get_game_time() < target - 1e-6 and guard > 0 and rescues.is_empty():
				guard -= 1
				var result := Simulation.sleep(minf(12.0, (target - GameSession.get_game_time()) / HOUR))
				if result.stopped_by == Simulation.STOP_RESCUE:
					break
		"save":
			Simulation.advance(seconds / 2.0)
			var errors: Array[String] = []
			var copy := SessionState.from_dict(JSON.parse_string(JSON.stringify(GameSession.get_state_snapshot().to_dict(), "", true, true)), errors)
			GameSession.replace_state(copy)
			Simulation.advance(target - GameSession.get_game_time())


func _test_damage_time_steps() -> void:
	var outcomes := {}
	for mode in ["1x", "5x", "20x", "large", "sleep", "save"]:
		_new_game()
		_depart()
		WeatherFixtures.use([
			WeatherFixtures.gale("fx_moving", GameSession.get_vessel_position() + Vector2(0.2, -0.3), 40.0, 44.0,
				GameSession.get_game_time() + 1800.0, 10.0, 200.0, 6.0, 260.0, true),
			WeatherFixtures.thunderstorm("fx_cell", GameSession.get_vessel_position() + Vector2(-0.1, -0.4), 14.0, 24.0, 30.0,
				GameSession.get_game_time() + 2.0 * HOUR, 4.0, 180.0, 10.0),
		])
		_drive_for(6.0 * HOUR, mode)
		outcomes[mode] = {"condition": GameSession.get_condition(), "progress": GameSession.get_voyage_progress_nm(),
			"food": GameSession.get_food_days(), "time": GameSession.get_game_time(),
			"exposure": GameSession.get_weather_exposure().to_dict()}
	var reference: Dictionary = outcomes["1x"]
	t.check(reference.condition < 99.0, "[time] (setup) the reference voyage takes weather damage (%.2f %%)" % (100.0 - reference.condition))
	for mode: String in outcomes:
		if mode == "1x":
			continue
		var o: Dictionary = outcomes[mode]
		var same: bool = absf(o.condition - reference.condition) < 1e-6 and absf(o.progress - reference.progress) < 1e-6 \
			and absf(o.food - reference.food) < 1e-6 and absf(o.time - reference.time) < 1e-6
		same = same and o.exposure == reference.exposure
		t.check(same, "[time] %s gives the same damage, position, stores and exposure as 1× (%.6f vs %.6f %%)" % [mode, o.condition, reference.condition])


# --- Boats and repair ----------------------------------------------------------------

func _test_vessels_and_repair() -> void:
	# Each boat keeps its own condition; funds and stores stay with the player.
	_new_game()
	_depart()
	_weather_at_boat(46.0)
	Simulation.advance(3.0 * HOUR)
	var damaged := GameSession.get_condition()
	t.check(damaged < 85.0, "[boats] the Starling is damaged by a storm (%.1f %%)" % damaged)
	t.check(GameSession.repair_vessel().contains("harbour"), "[repair] no repairs at sea")
	t.check(GameSession.switch_vessel(&"halcyon_40").contains("harbour"), "[boats] no boat change at sea")
	# Back in harbour (arrive by sailing on in calm weather).
	WeatherFixtures.use([])
	for i in 10:
		if GameSession.is_underway():
			Simulation.sleep(12.0)
	t.check(not GameSession.is_underway() and GameSession.get_location_id() == &"kiel", "[boats] (setup) arrived in Kiel")
	var funds := GameSession.get_funds()
	var food := GameSession.get_food_days()
	t.check_eq(GameSession.switch_vessel(&"halcyon_40"), "", "[boats] change to the Halcyon 40")
	t.check(is_equal_approx(GameSession.get_condition(), 100.0), "[boats] the Halcyon has its own condition (100 %)")
	t.check(is_equal_approx(GameSession.get_vessel_condition(&"starling_33"), damaged), "[boats] the Starling keeps its damage")
	t.check(GameSession.get_funds() == funds and GameSession.get_food_days() == food, "[boats] money and stores are not reset by changing boats")
	GameSession.switch_vessel(&"starling_33")
	t.check(is_equal_approx(GameSession.get_condition(), damaged), "[boats] back aboard the Starling, its damage is still there")
	t.check_eq(GameSession.repair_vessel(), "", "[repair] repairing in harbour works")
	t.check(is_equal_approx(GameSession.get_condition(), 100.0) and GameSession.get_funds() == funds, "[repair] back to 100 %, free")
	t.check(GameSession.repair_vessel().contains("already"), "[repair] a sound boat needs no repair")
	# Bounds.
	GameSession.set_condition_for_testing(150.0)
	t.check_eq(GameSession.get_condition(), 100.0, "[condition] never above 100 %")
	GameSession.set_condition_for_testing(-5.0)
	t.check(GameSession.get_condition() > 0.0, "[condition] the test control never sets zero (that is left to the real weather)")
	# Every boat takes damage, according to its resilience.
	var loss := {}
	for id in VesselCatalog.get_default().get_ids():
		_new_game(id)
		_depart()
		_weather_at_boat(44.0)
		Simulation.advance(2.0 * HOUR)
		loss[id] = 100.0 - GameSession.get_condition()
	t.check(loss.values().all(func(v: float) -> bool: return v > 1.0), "[boats] every boat takes storm damage (%s)" % [loss])
	t.check(loss[&"halcyon_40"] < loss[&"starling_33"] and loss[&"starling_33"] < loss[&"petrel_36"],
		"[boats] the catamaran takes heavy weather best, the light trimaran worst")


# --- Rescue -----------------------------------------------------------------------------

func _rescue_setup(vessel := &"starling_33", companion := CompanionState.KIND_CAT) -> void:
	WeatherFixtures.use([])
	GameSession.start_new_session(companion)
	if vessel != VesselCatalog.STARTER_ID:
		GameSession.switch_vessel(vessel)
	rescues.clear()
	_depart()
	Simulation.advance(1.0 * HOUR)
	GameSession.set_condition_for_testing(1.0)
	_weather_at_boat(52.0)


func _test_rescue() -> void:
	_rescue_setup(&"halcyon_40", CompanionState.KIND_DOG)
	var food := GameSession.get_food_days()
	var start := GameSession.get_game_time()
	var result := Simulation.advance(2.0 * HOUR)
	t.check(result.rescued and result.stopped_by == Simulation.STOP_RESCUE, "[rescue] zero condition triggers a rescue")
	t.check(result.elapsed_seconds <= Simulation.EVALUATION_INTERVAL + 1e-6,
		"[rescue] at the next evaluation point (%.0f s); the rest of the advance is not sailed" % result.elapsed_seconds)
	t.check_eq(rescues.size(), 1, "[rescue] exactly one rescue")
	t.check(not GameSession.is_underway() and GameSession.get_voyage() == null and GameSession.get_planned_route() == null,
		"[rescue] the voyage is over and the course cleared")
	t.check(GameSession.get_location_id() == &"copenhagen" and GameSession.get_vessel_status() == SessionState.STATUS_MOORED,
		"[rescue] the boat is moored in Copenhagen")
	t.check(GameSession.get_vessel_position().is_equal_approx(PortCatalog.get_default().get_port(&"copenhagen").get_geo_position()),
		"[rescue] at Copenhagen's position")
	t.check_eq(GameSession.get_vessel_id(), &"halcyon_40", "[rescue] the same boat (the Halcyon 40)")
	t.check_eq(GameSession.get_companion().kind, CompanionState.KIND_DOG, "[rescue] the companion is kept")
	t.check(is_equal_approx(GameSession.get_condition(), 100.0), "[rescue] the boat is repaired (100 %)")
	t.check_eq(GameSession.get_funds(), 9000, "[rescue] €1,000 fee: €9,000 left")
	t.check(not rescues.is_empty() and rescues[0].fee == 1000 and rescues[0].funds_after == 9000 and rescues[0].port_id == "copenhagen",
		"[rescue] the report names the fee, the funds left and Copenhagen")
	t.check(absf(GameSession.get_food_days() - (food - (GameSession.get_game_time() - start) / START_DAY)) < 1e-6,
		"[rescue] the stores are kept (only the elapsed time is used)")
	t.check(GameSession.get_boat_area() == SessionState.AREA_INTERIOR and GameSession.get_spawn_point() == GameSession.RESCUE_SPAWN,
		"[rescue] the player is put aboard in the cabin")
	t.check_eq(GameSession.get_time_scale(), 1, "[rescue] time runs at 1× afterwards")
	t.check_eq(GameSession.get_rescue_count(), 1, "[rescue] recorded once")
	# The test weather is still there, but in harbour it does nothing more.
	Simulation.advance(6.0 * HOUR)
	t.check(rescues.size() == 1 and GameSession.get_funds() == 9000, "[rescue] nothing more happens afterwards")
	GameSession.rescue()
	t.check(rescues.size() == 1 and GameSession.get_funds() == 9000, "[rescue] a rescue in harbour is impossible (no double charge)")
	# Playable at once: a new voyage, a second rescue.
	_depart()
	Simulation.advance(1.0 * HOUR)
	GameSession.set_condition_for_testing(1.0)
	_weather_at_boat(52.0)
	Simulation.advance(1.0 * HOUR)
	t.check(rescues.size() == 2 and GameSession.get_funds() == 8000, "[rescue] a second rescue: €8,000 left")


func _test_rescue_while_advancing() -> void:
	# Sleeping: woken by the rescue, no further sailing on the abandoned voyage.
	_rescue_setup()
	var before := GameSession.get_game_time()
	var result := Simulation.sleep(10.0)
	t.check(result.stopped_by == Simulation.STOP_RESCUE and GameSession.get_game_time() - before <= Simulation.EVALUATION_INTERVAL + 1e-6,
		"[rescue] during sleep: the sleep ends at the rescue (%.0f s)" % (GameSession.get_game_time() - before))
	t.check(rescues.size() == 1 and GameSession.get_location_id() == &"copenhagen", "[rescue] during sleep: back in Copenhagen, once")
	# 20×: one frame covers 20 game minutes; the rescue happens in it, once.
	_rescue_setup(&"petrel_36")
	GameSession.set_time_scale(20)
	for i in 5:
		Simulation.tick(1.0)
	t.check(rescues.size() == 1 and not GameSession.is_underway() and GameSession.get_vessel_id() == &"petrel_36",
		"[rescue] at 20×: one rescue, the Petrel is back in Copenhagen")
	# The starter boat too: still the Arctic Wanderer 26 afterwards, the hat untouched.
	_rescue_setup(&"arctic_wanderer_26")
	var hat_before := GameSession.get_hat().to_dict()
	Simulation.sleep(10.0)
	t.check(rescues.size() == 1 and not GameSession.is_underway() and GameSession.get_vessel_id() == &"arctic_wanderer_26"
		and GameSession.get_hat().to_dict() == hat_before, "[rescue] the Arctic Wanderer 26 is rescued as itself, its hat on the hook")
	# A long advance stops there too.
	_rescue_setup()
	var long := Simulation.advance(48.0 * HOUR)
	t.check(long.rescued and long.elapsed_seconds < HOUR and rescues.size() == 1, "[rescue] a 48 h advance stops at the rescue")
	# Close to arrival: either the boat arrives or it is rescued, never both.
	_new_game()
	_depart()
	WeatherFixtures.use([])
	var guard := 400
	while GameSession.get_voyage_remaining_nm() > 0.3 and guard > 0:
		guard -= 1
		Simulation.advance(60.0)
	GameSession.set_condition_for_testing(1.0)
	_weather_at_boat(52.0)
	var arrived := []
	var on_arrived := func(port: StringName) -> void: arrived.append(port)
	Simulation.arrived.connect(on_arrived)
	Simulation.advance(HOUR)
	Simulation.arrived.disconnect(on_arrived)
	t.check(arrived.size() + rescues.size() == 1 and not GameSession.is_underway(),
		"[rescue] shortly before arrival: arrived or rescued, exactly one (%d arrival, %d rescue)" % [arrived.size(), rescues.size()])


func _test_money_limits() -> void:
	_rescue_setup()
	var state := GameSession.get_state_snapshot()
	state.funds = 600
	GameSession.replace_state(state)
	Simulation.advance(HOUR)
	t.check(rescues.size() == 1 and GameSession.get_funds() == 0 and int(rescues[0].fee) == 600,
		"[money] with €600 the rescue still happens and takes what there is (€600)")
	_depart()
	Simulation.advance(HOUR)
	GameSession.set_condition_for_testing(1.0)
	_weather_at_boat(52.0)
	Simulation.advance(HOUR)
	t.check(rescues.size() == 2 and GameSession.get_funds() == 0 and int(rescues[1].fee) == 0,
		"[money] with nothing left: rescued for free, funds stay at €0 (never negative)")
	# Nothing else costs money in this version.
	_new_game()
	_depart()
	_weather_at_boat(46.0)
	Simulation.advance(2.0 * HOUR)
	WeatherFixtures.use([])
	for i in 10:
		if GameSession.is_underway():
			Simulation.sleep(12.0)
	GameSession.repair_vessel()
	GameSession.switch_vessel(&"petrel_36")
	t.check_eq(GameSession.get_funds(), 10000, "[money] voyages, repairs and changing boats cost nothing")


# --- Persistence ------------------------------------------------------------------------

func _test_persistence_and_migration() -> void:
	_new_game()
	_depart()
	_weather_at_boat(46.0)
	Simulation.advance(3.0 * HOUR)
	var snapshot := GameSession.get_state_snapshot()
	t.check_eq(SaveManager.save_to_slot(2, snapshot), OK, "[saves] saved during a storm")
	var loaded := SaveManager.load_from_slot(2)
	t.check(loaded.is_ok(), "[saves] the save loads (%s)" % loaded.error)
	if loaded.is_ok():
		var s := loaded.state
		t.check(is_equal_approx(s.get_condition(&"starling_33"), GameSession.get_condition()) and s.funds == GameSession.get_funds()
			and is_equal_approx(s.provisions.food_days, GameSession.get_food_days())
			and is_equal_approx(s.damage_applied_until, GameSession.get_damage_applied_until()),
			"[saves] condition, money, stores and the damage bookkeeping are saved")
		# Continuing after loading gives the same as not having saved.
		Simulation.advance(2.0 * HOUR)
		var straight := GameSession.get_condition()
		GameSession.replace_state(s)
		Simulation.advance(2.0 * HOUR)
		t.check(absf(GameSession.get_condition() - straight) < 1e-6, "[saves] loading mid-storm continues the damage exactly")

	# After a rescue: saved and loaded, nothing is charged or rescued again.
	_rescue_setup()
	Simulation.advance(HOUR)
	SaveManager.save_to_slot(2, GameSession.get_state_snapshot())
	var after := SaveManager.load_from_slot(2)
	GameSession.replace_state(after.state)
	Simulation.advance(6.0 * HOUR)
	t.check(rescues.size() == 1 and GameSession.get_funds() == 9000 and GameSession.get_rescue_count() == 1
		and GameSession.get_location_id() == &"copenhagen" and is_equal_approx(GameSession.get_condition(), 100.0),
		"[saves] after loading a rescued game: no second rescue or fee")

	# Version 6 (Iteration 005a) saves: the new systems start as in a new game.
	_new_game(&"petrel_36")
	_depart()
	Simulation.advance(2.0 * HOUR)
	var v6: Dictionary = GameSession.get_state_snapshot().to_dict()
	for key in ["economy", "provisions", "rescue"]:
		v6.erase(key)
	v6.vessel.erase("conditions")
	v6.vessel.erase("damage_applied_until")
	var file := FileAccess.open(SaveManager.save_dir.path_join("slot_3.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"format": "next_harbor_save", "version": 6, "game_version": "0.5.0",
		"saved_at_unix": 1790000000.0, "saved_at_utc": "2026-09-21T12:53:20Z", "session": v6}, "", true, true))
	file.close()
	var migrated := SaveManager.load_from_slot(3)
	t.check(migrated.is_ok(), "[migration] a version 6 save loads (%s)" % migrated.error)
	if migrated.is_ok():
		var m := migrated.state
		t.check(m.funds == 10000 and is_equal_approx(m.provisions.food_days, 14.0) and is_equal_approx(m.provisions.water_days, 14.0)
			and is_equal_approx(m.get_condition(&"petrel_36"), 100.0) and m.rescue_count == 0,
			"[migration] €10,000, 14 days of stores, boats at 100 %, no rescues")
		t.check(m.vessel_status == SessionState.STATUS_UNDERWAY and absf(m.voyage.progress_nm - GameSession.get_voyage_progress_nm()) < 1e-6
			and m.vessel_id == &"petrel_36" and is_equal_approx(m.game_time, GameSession.get_game_time()),
			"[migration] the voyage underway, boat and time are kept")
		t.check(is_equal_approx(m.damage_applied_until, m.game_time), "[migration] weather damage counts from the saved time on")
	SaveManager.delete_slot(2)
	SaveManager.delete_slot(3)
