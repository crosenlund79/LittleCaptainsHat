extends RefCounted
## Visual Identity V01, Checkpoint A: the captain's hat. One hat that belongs
## to the player: stored on its hook in the cabin, worn, carried under the arm
## or lost. Wind at the boat (the one WeatherModel) strains a worn hat on deck
## at fixed game-time checks, with a fair warning first; the result is the
## same at any time step and across save/load. Replacement hats are sold at
## the harbour grocery store. Core rules first, then the real application on
## all three boats.

const APP_SCENE := preload("res://src/app/app.tscn")
const W := preload("res://tests/helpers/walkability.gd")
const VESSELS: Array[StringName] = [&"arctic_wanderer_26", &"starling_33", &"halcyon_40", &"petrel_36"]
const HOUR := 3600.0
const DECK := SessionState.AREA_EXTERIOR
const CABIN := SessionState.AREA_INTERIOR

var t: Node
var app: Node


func run(runner: Node) -> void:
	t = runner
	Simulation.auto_advance = false
	WeatherFixtures.clear()
	t.use_calm_wind()
	_test_starting_state()
	_test_hook_and_key()
	_test_config_bands()
	_test_light_wind_is_safe()
	_test_warning_then_loss()
	_test_recovery_and_no_repeat()
	_test_step_independence_moored()
	_test_step_independence_underway()
	_test_save_load_mid_exposure()
	_test_sheltered_while_sleeping_and_working()
	_test_warning_drops_time_scale()
	_test_no_vessel_damage_from_hat()
	_test_rescue_keeps_hat()
	_test_vessel_switching()
	_test_purchase()
	_test_persistence_and_migration()
	_test_story_uses_real_places()
	GameSession.end_session()
	t.use_calm_wind()

	app = APP_SCENE.instantiate()
	t.add_child(app)
	app.router.fade_duration = 0.05
	await _settle()
	app.start_new_game()
	await _settle()
	await _test_hook_in_every_cabin()
	await _test_companion_compatibility()
	await _test_hat_key_and_player_visual()
	await _test_blow_away_on_deck()
	await _test_grocery_hat_row()
	Simulation.auto_advance = true
	app.queue_free()
	await t.frames(2)
	GameSession.end_session()
	t.use_calm_wind()


func _settle() -> void:
	await t.frames(2)
	await t.wait_until(func() -> bool: return not app.router.is_busy(), 5.0)
	await t.physics_frames(3)


func _replace(edit: Callable) -> void:
	var state := GameSession.get_state_snapshot()
	edit.call(state)
	GameSession.replace_state(state)


## A new game on deck in Copenhagen with the hat on, in a steady `wind_kn`
## from the west (the calm-wind fixture's mechanism; gusts are ×1.25).
func _new_game_hat_on_deck(wind_kn: float) -> void:
	GameSession.start_new_session()
	t.set_wind(270.0, wind_kn)
	GameSession.enter_boat_area(DECK, &"start")
	GameSession.use_hat_hook()


func _depart_to_kiel() -> void:
	GameSession.set_planned_route(t.make_route(&"copenhagen", &"kiel"))
	GameSession.depart()


func _lost_time() -> float:
	for entry in GameSession.get_hat().history:
		if entry.kind == String(HatState.EVENT_LOST):
			return float(entry.time)
	return -1.0


# --- State and interaction ------------------------------------------------------------

func _test_starting_state() -> void:
	GameSession.start_new_session()
	var hat := GameSession.get_hat()
	t.check_eq(hat.status, HatState.STORED, "[hat] a new game starts with the hat stored in the cabin")
	t.check(hat.is_owned() and hat.has_original() and hat.serial == 1, "[hat] it is the original hat, owned")
	t.check_eq(hat.checked_until, GameSession.get_game_time(), "[hat] hat checks start at the start of the game")
	t.check(hat.lost_count == 0 and hat.bought_count == 0 and hat.spent == 0 and hat.history.is_empty(),
		"[hat] nothing lost, bought or recorded yet")
	t.check(not GameSession.is_hat_exposed(), "[hat] a stored hat is not out in the wind")


func _test_hook_and_key() -> void:
	GameSession.start_new_session()
	var changes: Array[StringName] = []
	var on_change := func(status: StringName) -> void: changes.append(status)
	GameSession.hat_changed.connect(on_change)
	t.check(GameSession.toggle_hat().contains("hook"), "[hat] H with the hat on its hook says where it is")
	t.check_eq(GameSession.get_hat_status(), HatState.STORED, "[hat] ...and leaves it there")
	t.check(GameSession.use_hat_hook().contains("put on"), "[hat] the hook puts the hat on")
	t.check_eq(GameSession.get_hat_status(), HatState.WORN, "[hat] the hat is worn")
	t.check(not GameSession.is_hat_exposed(), "[hat] worn in the cabin it is not out in the wind")
	GameSession.enter_boat_area(DECK, &"start")
	t.check(GameSession.is_hat_exposed(), "[hat] worn on deck it is out in the wind")
	t.check(GameSession.toggle_hat().contains("take off"), "[hat] H takes the hat off")
	t.check_eq(GameSession.get_hat_status(), HatState.CARRIED, "[hat] ...tucked under the arm")
	t.check(not GameSession.is_hat_exposed(), "[hat] a carried hat is not at risk")
	GameSession.toggle_hat()
	t.check_eq(GameSession.get_hat_status(), HatState.WORN, "[hat] H puts it back on")
	t.check(GameSession.use_hat_hook().contains("hang"), "[hat] the hook hangs a worn hat up")
	t.check_eq(GameSession.get_hat_status(), HatState.STORED, "[hat] the hat is stored again")
	GameSession.use_hat_hook()
	GameSession.toggle_hat()
	GameSession.use_hat_hook()
	t.check_eq(GameSession.get_hat_status(), HatState.STORED, "[hat] a carried hat can be hung up too")
	t.check_eq(changes, [HatState.WORN, HatState.CARRIED, HatState.WORN, HatState.STORED, HatState.WORN, HatState.CARRIED,
		HatState.STORED], "[hat] every change is announced once")
	GameSession.hat_changed.disconnect(on_change)
	_replace(func(state: SessionState) -> void:
		state.hat.status = HatState.LOST
		state.hat.lost_count = 1)
	t.check(GameSession.use_hat_hook().contains("empty hat hook"), "[hat] without a hat the hook is empty and says where to buy one")
	t.check(GameSession.toggle_hat().contains("no captain's hat"), "[hat] H without a hat says so")
	t.check_eq(GameSession.get_hat_status(), HatState.LOST, "[hat] neither brings a lost hat back")


func _test_config_bands() -> void:
	var c := HatConfig.get_default()
	t.check_eq(c.price_eur, 15, "[hat config] a replacement costs EUR 15")
	t.check_eq(c.check_interval_s, 60.0, "[hat config] the hat is checked once per game minute")
	t.check_eq(c.strain_per_minute(24.0, 29.0, false), 0.0, "[hat config] below 25 kn there is no risk")
	t.check_eq(c.strain_per_minute(18.0, 34.9, false), 0.0, "[hat config] light wind with gusts under 35 kn: no risk")
	t.check_eq(c.strain_per_minute(18.0, 36.0, false), 0.25, "[hat config] gusts count (as gust - 10 kn): 36 kn gusts are 26 kn")
	t.check_eq(c.strain_per_minute(30.0, 37.5, false), 0.25, "[hat config] 25-35 kn: very low risk")
	t.check_eq(c.strain_per_minute(40.0, 44.0, false), 1.0, "[hat config] 35-45 kn: meaningful risk")
	t.check_eq(c.strain_per_minute(40.0, 50.0, false), 1.5, "[hat config] strong gusts (45+) add risk")
	t.check_eq(c.strain_per_minute(48.0, 60.0, false), 6.0, "[hat config] above 45 kn with 55+ kn gusts: highest risk")
	t.check_eq(c.strain_per_minute(40.0, 55.0, false), 6.0, "[hat config] a 55+ kn gust can snatch a hat: a gale with squall gusts")
	t.check_eq(c.strain_per_minute(40.0, 50.0, true), 0.75, "[hat config] a harbour halves the risk")
	var a := c.threshold_for(1, 1)
	t.check(a >= c.threshold_min and a <= c.threshold_max, "[hat config] each hat's threshold is within the range (%.1f)" % a)
	t.check_eq(c.threshold_for(1, 1), a, "[hat config] the threshold is fixed for a hat")
	t.check(not is_equal_approx(c.threshold_for(1, 2), a), "[hat config] the next hat has its own threshold")
	var minutes := c.threshold_min / 1.5
	t.check(minutes >= 13.0, "[hat config] in a 40 kn gale at sea a hat lasts at least %d game minutes on deck" % roundi(minutes))
	t.check(c.threshold_min / 0.25 >= 80.0, "[hat config] in 30 kn it lasts at least %d minutes (very low risk)" % roundi(c.threshold_min / 0.25))


func _test_light_wind_is_safe() -> void:
	_new_game_hat_on_deck(24.0)
	var warnings := [0]
	var on_warning := func(_text: String) -> void: warnings[0] += 1
	GameSession.hat_warning.connect(on_warning)
	var start := GameSession.get_game_time()
	for i in 24:
		Simulation.advance(HOUR)
	GameSession.hat_warning.disconnect(on_warning)
	t.check_eq(GameSession.get_hat_status(), HatState.WORN, "[hat wind] 24 kn (gusts 30) for a whole day on deck: the hat stays on")
	t.check_eq(warnings[0], 0, "[hat wind] ...and no warning")
	t.check_eq(GameSession.get_hat().strain, 0.0, "[hat wind] ...and no strain")
	t.check_eq(GameSession.get_hat_checked_until(), start + 24 * HOUR, "[hat wind] the checks kept up with the clock")


func _test_warning_then_loss() -> void:
	_new_game_hat_on_deck(40.0)
	var events: Array[String] = []
	var on_warning := func(text: String) -> void: events.append("warning:" + text)
	var on_lost := func(info: Dictionary) -> void: events.append("lost:" + String(info.text))
	GameSession.hat_warning.connect(on_warning)
	GameSession.hat_lost.connect(on_lost)
	var result := Simulation.advance(60.0)
	t.check(result.hat_warned and events.size() == 1 and events[0].begins_with("warning:Better hold onto your hat!"),
		"[hat wind] the first minute in 40 kn warns: \"Better hold onto your hat!\"")
	t.check(events[0].contains("40 kn") and events[0].contains("H"), "[hat wind] the warning gives the real wind and what to do (%s)" % events[0])
	t.check_eq(GameSession.get_hat().strain, 0.0, "[hat wind] the warning minute itself costs nothing")
	t.check_eq(GameSession.get_hat_status(), HatState.WORN, "[hat wind] the hat is still on after the warning")
	Simulation.advance(20.0 * 60.0)
	t.check_eq(GameSession.get_hat_status(), HatState.WORN, "[hat wind] 20 more minutes in a harbour gale: still on (sheltered harbour)")
	t.check_eq(events.size(), 1, "[hat wind] the warning is not repeated")
	var funds := GameSession.get_funds()
	var condition := GameSession.get_condition()
	result = Simulation.advance(2.0 * HOUR)
	t.check(result.hat_lost and GameSession.get_hat_status() == HatState.LOST, "[hat wind] staying on deck, the hat blows away")
	t.check(events.size() == 2 and events[1] == "lost:" + HatStory.loss_message(1),
		"[hat wind] the loss is announced: \"%s\"" % HatStory.loss_message(1))
	var hat := GameSession.get_hat()
	var lost_after := (_lost_time() - SessionState.get_start_time()) / 60.0
	var expected := HatConfig.get_default().threshold_for(1, 1) / 0.75 + 1.0
	t.check(absf(lost_after - ceilf(expected - 1e-6)) <= 1.0,
		"[hat wind] it went after %d game minutes, as the hat's threshold says (~%d)" % [roundi(lost_after), roundi(expected)])
	t.check(hat.lost_count == 1 and not hat.has_original() and hat.strain == 0.0 and not hat.warned,
		"[hat wind] one hat lost, the original; strain and warning reset")
	t.check(hat.history.size() == 1 and String(hat.history[0].text).contains("in Copenhagen harbour")
		and String(hat.history[0].text).contains("Wind 40 kn, gusting 50"),
		"[hat wind] the log line names the real place and wind: %s" % hat.history[0].text)
	t.check(GameSession.get_funds() == funds and GameSession.get_condition() == condition,
		"[hat wind] losing the hat costs no money and does no damage")
	Simulation.advance(HOUR)
	t.check(events.size() == 2 and GameSession.get_hat().lost_count == 1, "[hat wind] a lost hat cannot be lost again")
	GameSession.hat_warning.disconnect(on_warning)
	GameSession.hat_lost.disconnect(on_lost)


func _test_recovery_and_no_repeat() -> void:
	_new_game_hat_on_deck(40.0)
	var warnings := [0]
	var on_warning := func(_text: String) -> void: warnings[0] += 1
	GameSession.hat_warning.connect(on_warning)
	Simulation.advance(11.0 * 60.0)
	var strain := GameSession.get_hat().strain
	t.check(warnings[0] == 1 and strain > 7.0, "[hat recovery] warned, then strain builds (%.2f)" % strain)
	GameSession.enter_boat_area(CABIN, &"from_deck")
	Simulation.advance(2.0 * 60.0)
	t.check(is_equal_approx(GameSession.get_hat().strain, strain - 4.0), "[hat recovery] below deck the hat recovers (2 per minute)")
	GameSession.enter_boat_area(DECK, &"start")
	Simulation.advance(60.0)
	t.check_eq(warnings[0], 1, "[hat recovery] stepping back on deck soon after: no second warning")
	GameSession.toggle_hat()
	Simulation.advance(10.0 * 60.0)
	t.check_eq(GameSession.get_hat().strain, 0.0, "[hat recovery] with the hat off it recovers fully")
	t.check(GameSession.get_hat().warned, "[hat recovery] the warning is remembered for a while")
	Simulation.advance(30.0 * 60.0)
	t.check(not GameSession.get_hat().warned, "[hat recovery] after 30 quiet minutes a new exposure will warn again")
	GameSession.toggle_hat()
	Simulation.advance(60.0)
	t.check_eq(warnings[0], 2, "[hat recovery] ...and it does")
	GameSession.hat_warning.disconnect(on_warning)


## Plays the same scenario with time chopped into steps of `step` seconds;
## returns [status, lost time, strain, history].
func _run_moored(step: float, total: float) -> Array:
	_new_game_hat_on_deck(40.0)
	var done := 0.0
	while done < total - 1e-6:
		var s := minf(step, total - done)
		Simulation.advance(s)
		done += s
	var hat := GameSession.get_hat()
	# The last check may fall into the next call when the clock's float
	# rounding lands a hair before a grid point; it is the same check either way.
	return [hat.status, _lost_time(), hat.strain, floorf(hat.checked_until / 60.0 + 0.5) >= floorf(GameSession.get_game_time() / 60.0)]


func _test_step_independence_moored() -> void:
	var total := 90.0 * 60.0
	var big := _run_moored(total, total)
	var frames_1x := _run_moored(1.0, total)
	var frames_20x := _run_moored(20.0, total)
	var odd := _run_moored(137.3, total)
	t.check(big[0] == HatState.LOST and big[1] > 0.0, "[hat steps] in 90 minutes on deck in a harbour gale the hat is lost")
	t.check(frames_1x == big, "[hat steps] 1x frames (1 s) and one 90-minute step give the same loss time %s" % [str(big[1])])
	t.check(frames_20x == big, "[hat steps] 20x frames (20 s) give the same result")
	t.check(odd == big, "[hat steps] uneven steps (137.3 s) give the same result")


func _run_underway(step: float, total: float) -> Array:
	GameSession.start_new_session()
	t.set_wind(270.0, 40.0)
	_depart_to_kiel()
	GameSession.enter_boat_area(DECK, &"start")
	GameSession.use_hat_hook()
	var done := 0.0
	while done < total - 1e-6:
		var s := minf(step, total - done)
		Simulation.advance(s)
		done += s
	var hat := GameSession.get_hat()
	var where := ""
	if not hat.history.is_empty():
		where = hat.history[0].text
	return [hat.status, _lost_time(), snappedf(hat.strain, 1e-6), where, GameSession.get_vessel_position(), hat.voyage_lost]


func _test_step_independence_underway() -> void:
	var total := 60.0 * 60.0
	var big := _run_underway(total, total)
	var small := _run_underway(3.0, total)
	var odd := _run_underway(77.7, total)
	t.check(big[0] == HatState.LOST and big[5], "[hat steps] underway in 40 kn the hat is lost within the hour, and the voyage knows")
	t.check(small[1] == big[1] and odd[1] == big[1], "[hat steps] underway: the same loss time in 3 s steps, 77.7 s steps and one step")
	t.check(small[3] == big[3] and odd[3] == big[3], "[hat steps] underway: the same place in the log (%s)" % big[3])
	t.check(String(big[3]).contains("off Copenhagen, Denmark"), "[hat steps] lost at sea, the log names the nearby harbour")
	t.check(small[4].distance_to(big[4]) < 1e-6, "[hat steps] the boat is in the same place either way")


func _test_save_load_mid_exposure() -> void:
	var total := 3.0 * HOUR
	var straight := _run_moored(total, total)
	_new_game_hat_on_deck(40.0)
	Simulation.advance(17.5 * 60.0)
	var before := GameSession.get_hat()
	var errors: Array[String] = []
	var json := JSON.stringify(GameSession.get_state_snapshot().to_dict(), "", false, true)
	var loaded := SessionState.from_dict(JSON.parse_string(json), errors)
	t.check(loaded != null and errors.is_empty(), "[hat save] a game saved mid-exposure loads")
	GameSession.end_session()
	GameSession.replace_state(loaded)
	var after := GameSession.get_hat()
	t.check(after.status == before.status and after.strain == before.strain and after.warned == before.warned
		and after.checked_until == before.checked_until, "[hat save] strain, warning and checks are restored exactly")
	Simulation.advance(total - 17.5 * 60.0)
	var hat := GameSession.get_hat()
	t.check(hat.status == straight[0] and _lost_time() == straight[1] and hat.lost_count == 1,
		"[hat save] the hat is lost at the same moment as without saving, and only once")


func _test_sheltered_while_sleeping_and_working() -> void:
	_new_game_hat_on_deck(40.0)
	Simulation.sleep(8.0)
	t.check_eq(GameSession.get_hat_status(), HatState.WORN, "[hat shelter] sleeping 8 h in a gale (from the deck): the hat is safe")
	t.check_eq(GameSession.get_hat_checked_until(), SessionState.get_start_time() + 8.0 * HOUR, "[hat shelter] the checks still kept up")
	var result := Simulation.work(4)
	t.check(String(result.error).is_empty() and GameSession.get_hat_status() == HatState.WORN,
		"[hat shelter] working 4 h at the desk: the hat is safe")
	t.check(Simulation.is_hat_at_risk(), "[hat shelter] afterwards, still on deck, it is at risk again")


func _test_warning_drops_time_scale() -> void:
	_new_game_hat_on_deck(40.0)
	GameSession.set_time_scale(20)
	Simulation.tick(0.5)  # 600 game seconds at 20x
	t.check(GameSession.get_hat().warned, "[hat warning] at 20x the warning comes on time")
	t.check_eq(GameSession.get_time_scale(), 1, "[hat warning] time drops to 1x so the player can react")
	t.check_eq(GameSession.get_hat_status(), HatState.WORN, "[hat warning] the hat is still on")


func _test_no_vessel_damage_from_hat() -> void:
	var results := []
	for wear in [false, true]:
		GameSession.start_new_session()
		t.set_wind(270.0, 40.0)
		_depart_to_kiel()
		GameSession.enter_boat_area(DECK, &"start")
		if wear:
			GameSession.use_hat_hook()
		Simulation.advance(2.0 * HOUR)
		results.append([GameSession.get_condition(), GameSession.get_vessel_position(), GameSession.get_funds(), GameSession.get_hat_status()])
	t.check(results[1][3] == HatState.LOST and results[0][3] == HatState.STORED, "[hat damage] one voyage lost its hat, the other kept it stored")
	t.check(results[0][0] == results[1][0] and results[0][2] == results[1][2], "[hat damage] same boat condition and funds with or without the hat")
	t.check(results[0][1].distance_to(results[1][1]) < 1e-9, "[hat damage] the boat sails exactly the same")


func _test_rescue_keeps_hat() -> void:
	for status in [HatState.STORED, HatState.WORN, HatState.CARRIED, HatState.LOST]:
		GameSession.start_new_session()
		t.use_calm_wind()
		_replace(func(state: SessionState) -> void:
			state.hat.status = status
			state.hat.lost_count = 1 if status == HatState.LOST else 0
			state.hat.strain = 3.0)
		_depart_to_kiel()
		GameSession.rescue()
		var hat := GameSession.get_hat()
		t.check(GameSession.get_location_id() == &"copenhagen" and hat.status == status and hat.strain == 3.0,
			"[hat rescue] a %s hat is still %s after a rescue" % [status, status])
	t.check_eq(GameSession.get_hat().lost_count, 1, "[hat rescue] a lost hat does not reappear")


func _test_vessel_switching() -> void:
	for status in [HatState.STORED, HatState.WORN, HatState.CARRIED, HatState.LOST]:
		GameSession.start_new_session()
		_replace(func(state: SessionState) -> void:
			state.hat.status = status
			state.hat.lost_count = 1 if status == HatState.LOST else 0
			state.hat.serial = 1 if status != HatState.LOST else 1)
		for id in [&"halcyon_40", &"petrel_36", &"starling_33", &"arctic_wanderer_26"]:
			GameSession.switch_vessel(id)
			var hat := GameSession.get_hat()
			t.check(hat.status == status and hat.serial == 1, "[hat switch] %s hat, aboard the %s: still %s, the same hat" % [status, id, status])


func _test_purchase() -> void:
	GameSession.start_new_session()
	t.check(GameSession.buy_hat().contains("already"), "[hat shop] no second hat while you have one")
	t.check_eq(GameSession.get_funds(), SessionState.STARTING_FUNDS, "[hat shop] ...and nothing is charged")
	_replace(func(state: SessionState) -> void:
		state.hat.status = HatState.LOST
		state.hat.lost_count = 1)
	_depart_to_kiel()
	t.check(GameSession.buy_hat().contains("harbour"), "[hat shop] at sea no hat can be bought")
	GameSession.start_new_session()
	_replace(func(state: SessionState) -> void:
		state.hat.status = HatState.LOST
		state.hat.lost_count = 1
		state.funds = 14)
	t.check(GameSession.buy_hat().begins_with("Not enough money"), "[hat shop] with EUR 14 the EUR 15 hat is refused")
	t.check(GameSession.get_funds() == 14 and GameSession.get_hat_status() == HatState.LOST, "[hat shop] ...and nothing changes")
	_replace(func(state: SessionState) -> void: state.funds = 100)
	var funds_events := [0]
	var bought := []
	var on_funds := func(_f: int) -> void: funds_events[0] += 1
	var on_bought := func(info: Dictionary) -> void: bought.append(info)
	GameSession.funds_changed.connect(on_funds)
	GameSession.hat_bought.connect(on_bought)
	t.check_eq(GameSession.buy_hat(), "", "[hat shop] moored with enough money, a replacement is bought")
	t.check_eq(GameSession.buy_hat(), "You already have your captain's hat.", "[hat shop] buying twice is refused")
	GameSession.funds_changed.disconnect(on_funds)
	GameSession.hat_bought.disconnect(on_bought)
	var hat := GameSession.get_hat()
	t.check_eq(GameSession.get_funds(), 85, "[hat shop] EUR 15 was charged exactly once (EUR 100 -> 85)")
	t.check(funds_events[0] == 1 and bought.size() == 1 and int(bought[0].price) == 15, "[hat shop] one payment, one purchase announced")
	t.check(hat.status == HatState.CARRIED and hat.serial == 2 and hat.bought_count == 1 and hat.spent == 15,
		"[hat shop] the new hat (number 2) is in hand, ready to put on")
	t.check_eq(hat.bought_at, GameSession.get_game_time(), "[hat shop] the purchase time is recorded")
	t.check(String(hat.history[hat.history.size() - 1].text).contains("Copenhagen"), "[hat shop] the purchase is noted with the harbour")
	var errors: Array[String] = []
	var loaded := SessionState.from_dict(JSON.parse_string(JSON.stringify(GameSession.get_state_snapshot().to_dict())), errors)
	t.check(loaded != null and loaded.hat.status == HatState.CARRIED and loaded.hat.spent == 15 and loaded.funds == 85,
		"[hat shop] the purchase survives save/load")


func _test_persistence_and_migration() -> void:
	GameSession.start_new_session()
	_replace(func(state: SessionState) -> void:
		state.hat.status = HatState.WORN
		state.hat.strain = 4.5
		state.hat.warned = true
		state.hat.warned_at = state.game_time - 60.0
		state.hat.lost_count = 2
		state.hat.serial = 3
		state.hat.bought_count = 2
		state.hat.spent = 30
		state.hat.bought_at = state.game_time - 600.0
		state.hat.voyage_worn_hazard = 2
		state.hat.add_history(state.game_time, HatState.EVENT_LOST, "Lost another captain's hat in Copenhagen harbour."))
	t.check_eq(SaveManager.save_to_slot(1, GameSession.get_state_snapshot()), OK, "[hat save] a game with a hat history saves")
	var result := SaveManager.load_from_slot(1)
	t.check(result.is_ok(), "[hat save] ...and loads")
	if result.is_ok():
		t.check_eq(result.state.hat.to_dict(), GameSession.get_hat().to_dict(), "[hat save] every hat field is restored")
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SaveManager.save_dir.path_join("slot_1.json")))
	t.check_eq(int(raw.version), 10, "[hat save] saves are version 10")
	# A version 9 (Iteration 006) save has no hat: it gets the original, stored.
	var session: Dictionary = raw.session
	session.erase("hat")
	var v9 := {"format": "next_harbor_save", "version": 9, "game_version": "0.1.0", "saved_at_unix": 1790000000.0,
		"saved_at_utc": "2026-09-21T12:53:20Z", "session": session}
	var file := FileAccess.open(SaveManager.save_dir.path_join("slot_2.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(v9, "", true, true))
	file.close()
	var migrated := SaveManager.load_from_slot(2)
	t.check(migrated.is_ok(), "[hat save] an I006 (v9) save still loads")
	if migrated.is_ok():
		var hat: HatState = migrated.state.hat
		t.check(hat.status == HatState.STORED and hat.has_original() and hat.serial == 1 and hat.history.is_empty(),
			"[hat save] v9 -> v10: the original hat, on its hook")
		t.check_eq(hat.checked_until, migrated.state.game_time, "[hat save] no wind is charged for the time before the update")
		t.check_eq(migrated.state.funds, GameSession.get_funds(), "[hat save] the rest of the save is unchanged")
	SaveManager.delete_slot(1)
	SaveManager.delete_slot(2)
	t.check(not SaveManager.get_slot_info(1).is_loadable() and not SaveManager.get_slot_info(2).is_loadable(),
		"[hat save] the test slots are cleaned up")
	var errors: Array[String] = []
	var bad: Dictionary = GameSession.get_state_snapshot().to_dict()
	bad.hat.status = "on_the_cat"
	t.check(SessionState.from_dict(bad, errors) == null and not errors.is_empty(), "[hat save] an unknown hat state is rejected (%s)" % ", ".join(errors))
	errors.clear()
	bad = GameSession.get_state_snapshot().to_dict()
	bad.hat.status = "lost"
	bad.hat.lost_count = 0
	t.check(SessionState.from_dict(bad, errors) == null, "[hat save] a lost hat that was never lost is rejected")
	errors.clear()
	bad = GameSession.get_state_snapshot().to_dict()
	bad.erase("hat")
	t.check(SessionState.from_dict(bad, errors) == null, "[hat save] a v10 session without a hat is rejected")


func _test_story_uses_real_places() -> void:
	var kiel := PortCatalog.get_default().get_port(&"kiel")
	var harbour := HatStory.describe_place(kiel.get_geo_position(), &"kiel")
	t.check_eq(harbour.text, "in Kiel harbour", "[hat story] moored: the harbour by name")
	var near := HatStory.describe_place(kiel.get_geo_position() + Vector2(0.0, 0.2), &"")
	t.check(String(near.text).begins_with("about") and String(near.text).contains("nm off"), "[hat story] near a harbour: %s" % near.text)
	var far := HatStory.describe_place(Vector2(-12.0, 47.0), &"")
	t.check(String(far.text).begins_with("far out at sea"), "[hat story] far offshore it says so, with the nearest harbour: %s" % far.text)
	var calm := WeatherSample.new()
	calm.speed_kn = 20.0
	calm.gust_kn = 25.0
	calm.hazard = WeatherModel.HAZARD_NORMAL
	t.check(HatStory.loss_log_line(2, near, calm).begins_with("Lost another captain's hat about"),
		"[hat story] a second loss is 'another' hat")
	t.check(HatStory.loss_log_line(2, near, calm).ends_with("Weather otherwise pleasant."), "[hat story] gentle humour on a fair day")
	t.check(HatStory.loss_message(1) == "Your captain's hat has decided to explore the ocean without you.",
		"[hat story] the first loss message")


# --- In the game ------------------------------------------------------------------------------

func _station(area: BoatArea, interaction_id: StringName) -> Interactable:
	for node: Interactable in area.get_node("Layout/Stations").get_children():
		if node.interaction_id == interaction_id:
			return node
	return null


func _show(area: StringName, spawn: StringName) -> void:
	app.modals.clear()
	GameSession.enter_boat_area(area, spawn)
	app._show_current_boat_area()
	await _settle()


## Stands where `interaction_id` is focused and presses E.
func _use(interaction_id: StringName) -> bool:
	var area := app.router.current_screen as BoatArea
	var station := _station(area, interaction_id)
	if station == null or not station.enabled:
		return false
	var cells := W.walkable_cells(area, area.get_spawn_position(&"start"))
	var tries := 0
	for p in W.use_points(station, cells):
		area.player.position = p
		area.player.set_facing((station.global_position - p).normalized())
		await t.physics_frames(3)
		if area.player.get_focused_interactable() == station:
			await t.press_action(&"interact")
			await t.frames(2)
			return true
		tries += 1
		if tries > 40:
			break
	return false


func _test_hook_in_every_cabin() -> void:
	for id in VESSELS:
		GameSession.switch_vessel(id)
		await _show(CABIN, &"start")
		var area := app.router.current_screen as BoatArea
		var station := _station(area, &"hat")
		var hook := area.get_hat_hook()
		var spot := area.get_node_or_null("Layout/HatSpot") as Node2D
		t.check(station != null and hook != null and spot != null and hook.position == spot.position,
			"[hat aboard] the %s's cabin has a hat hook and a hat station" % id)
		if station == null or hook == null:
			continue
		t.check(hook.is_showing_hat() and station.prompt == "Put on captain's hat", "[hat aboard] %s: the stored hat hangs there" % id)
		t.check(hook.get_index() < area.get_node("Layout").get_index() and hook.get_child_count() == 0 and hook.get_class() == "Node2D",
			"[hat aboard] %s: the hook is art only, drawn under the stations" % id)
		var player_shape := (area.player.get_node("CollisionShape2D") as CollisionShape2D).shape as CircleShape2D
		await t.screenshot("120_hat_on_hook_%s" % id)
		t.check(await _use(&"hat"), "[hat aboard] %s: walking to the hook and pressing E works" % id)
		t.check(GameSession.get_hat_status() == HatState.WORN and not hook.is_showing_hat()
			and area.player.get_hat_visual().get_shown_status() == HatState.WORN,
			"[hat aboard] %s: the hat moves from the hook to the player's head" % id)
		t.check(station.prompt == "Hang up captain's hat" and app.hud.get_prompt().contains("Hang up captain's hat"),
			"[hat aboard] %s: the prompt now offers to hang it up" % id)
		t.check(player_shape.radius == 20.0 and area.player.get_node("PlayerHat").get_child_count() == 0,
			"[hat aboard] %s: the player's collision is unchanged" % id)
		await t.screenshot("121_hat_worn_%s" % id)
		await _use(&"hat")
		t.check(GameSession.get_hat_status() == HatState.STORED and hook.is_showing_hat(), "[hat aboard] %s: E again hangs it back up" % id)
	GameSession.switch_vessel(&"starling_33")


## The hat station never takes the focus from the ship's cat: no resting spot
## is near enough for both to be in reach, on any boat.
func _test_companion_compatibility() -> void:
	for id in VESSELS:
		GameSession.switch_vessel(id)
		await _show(CABIN, &"start")
		var area := app.router.current_screen as BoatArea
		var station := _station(area, &"hat")
		var closest := INF
		for spot: Node2D in area.get_node("Layout/CompanionSpots").get_children():
			closest = minf(closest, spot.position.distance_to(station.position))
		t.check(closest >= 110.0, "[hat aboard] %s: every companion spot is well away from the hat (closest %d px)" % [id, roundi(closest)])
		var others := 1e9
		for other: Interactable in area.get_node("Layout/Stations").get_children():
			if other != station:
				others = minf(others, other.position.distance_to(station.position))
		t.check(others >= 100.0, "[hat aboard] %s: the hat does not crowd another station (closest %d px)" % [id, roundi(others)])
		# Wherever the cat rests and the player can stand to pet it, the hat
		# station never changes which interaction is chosen.
		var companion := area.get_node("Companion") as ShipCompanion
		var unchanged := true
		var places := 0
		var cells := W.walkable_cells(area, area.get_spawn_position(&"start"))
		for spot_id in CompanionState.SPOTS[&"cat"]:
			_replace(func(state: SessionState) -> void: state.companion.spot = spot_id)
			await t.physics_frames(2)
			var pet := companion.interactable
			for c in cells:
				if c.distance_to(pet.global_position) - ShipCompanion.INTERACT_RADIUS > 46.0:
					continue
				var in_reach: Array[Interactable] = [pet]
				var without_hat: Array[Interactable] = [pet]
				for other: Interactable in area.get_node("Layout/Stations").get_children():
					if other.enabled and W.distance_to_station(other, c) <= 46.0:
						in_reach.append(other)
						if other != station:
							without_hat.append(other)
				var facing := (pet.global_position - c).normalized()
				if InteractionSensor.choose(in_reach, c, facing) != InteractionSensor.choose(without_hat, c, facing):
					unchanged = false
				places += 1
		t.check(unchanged and places > 0, "[hat aboard] %s: petting the cat is unaffected by the hat at all 3 spots (%d places checked)" % [id, places])
	GameSession.switch_vessel(&"starling_33")


func _test_hat_key_and_player_visual() -> void:
	await _show(DECK, &"start")
	var area := app.router.current_screen as BoatArea
	GameSession.use_hat_hook()
	await t.frames(1)
	var visual := area.player.get_hat_visual()
	t.check(visual != null and visual.get_shown_status() == HatState.WORN, "[hat key] the worn hat is drawn on the player on deck")
	await t.press_action(&"captains_hat")
	t.check(GameSession.get_hat_status() == HatState.CARRIED and visual.get_shown_status() == HatState.CARRIED,
		"[hat key] H takes it off; it is drawn under the arm")
	await t.screenshot("122_hat_carried_deck")
	await t.press_action(&"captains_hat")
	t.check_eq(GameSession.get_hat_status(), HatState.WORN, "[hat key] H puts it back on")
	app.open_pause_menu()
	await t.frames(2)
	await t.press_action(&"captains_hat")
	t.check_eq(GameSession.get_hat_status(), HatState.WORN, "[hat key] H does nothing while a menu is open")
	app.modals.clear()
	await t.frames(2)
	t.check(app.hud.find_child("Controls", true, false).text.contains("H  hat"), "[hat key] the controls line mentions H")


func _test_blow_away_on_deck() -> void:
	t.set_wind(270.0, 48.0)
	await _show(DECK, &"start")
	var area := app.router.current_screen as BoatArea
	if GameSession.get_hat_status() == HatState.STORED:
		GameSession.use_hat_hook()
	elif GameSession.get_hat_status() == HatState.CARRIED:
		GameSession.toggle_hat()
	Simulation.advance(60.0)
	var shown := false
	for message in app.toasts.get_messages():
		shown = shown or message.begins_with("Better hold onto your hat!")
	t.check(shown, "[hat effect] the warning is shown as a notification")
	var lost := false
	for i in 120:
		Simulation.advance(60.0)
		if GameSession.get_hat_status() == HatState.LOST:
			lost = true
			break
	await t.frames(3)
	var effect := area.get_node_or_null("HatBlowAway") as HatBlowAway
	t.check(lost and effect != null, "[hat effect] in a 48 kn storm on deck the hat blows away with a visible effect")
	t.check(area.player.get_hat_visual().get_shown_status() == &"", "[hat effect] the player no longer wears a hat")
	if effect:
		var direction := effect.direction
		var expected := area.wind_direction_on_deck()
		t.check(direction.dot(expected) > 0.99, "[hat effect] it tumbles downwind")
		await t.frames(20)
		await t.screenshot("123_hat_blowing_away")
		var ref: WeakRef = weakref(effect)
		await t.wait_until(func() -> bool: return ref.get_ref() == null, 4.0)
		t.check(ref.get_ref() == null, "[hat effect] the effect is brief and removes itself")
	await _show(CABIN, &"start")
	area = app.router.current_screen as BoatArea
	var station := _station(area, &"hat")
	t.check(not area.get_hat_hook().is_showing_hat() and station.prompt == "Look at the empty hat hook",
		"[hat effect] in the cabin the hook is empty")
	t.use_calm_wind()


func _test_grocery_hat_row() -> void:
	await _show(DECK, &"from_boatyard")
	app.open_grocery()
	await t.frames(2)
	var menu := app.modals.get_top() as GroceryMenu
	t.check(menu != null, "[hat shop ui] the grocery store opens in harbour")
	if menu == null:
		return
	var funds := GameSession.get_funds()
	var price_before: String = String(menu.find_child("Price", true, false).text).get_slice("  ·  ", 0)
	var stores_before: String = menu.find_child("Stores", true, false).text
	var button := menu.get_buy_hat_button()
	t.check(not button.disabled and button.text == "Buy captain's hat (€15)", "[hat shop ui] with the hat lost, the counter offers one for €15")
	await t.screenshot("124_grocery_hat_for_sale")
	await t.click(button)
	t.check(GameSession.get_funds() == funds - 15 and GameSession.get_hat_status() == HatState.CARRIED,
		"[hat shop ui] clicking it buys the hat: funds %s -> %s" % [GameSession.format_money(funds), GameSession.format_money(GameSession.get_funds())])
	t.check(button.disabled and String(menu.find_child("HatInfo", true, false).text).contains("already"),
		"[hat shop ui] then the button is disabled: you have your hat")
	await t.click(button)
	t.check_eq(GameSession.get_funds(), funds - 15, "[hat shop ui] a second click charges nothing")
	t.check(String(menu.find_child("Price", true, false).text).get_slice("  ·  ", 0) == price_before
		and menu.find_child("Stores", true, false).text == stores_before,
		"[hat shop ui] the provisions price and missing days are unchanged (%s)" % price_before)
	app.modals.clear()
	await t.frames(2)
