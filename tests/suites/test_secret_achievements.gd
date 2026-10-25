extends RefCounted
## Visual Identity V01, Checkpoint B: secret hat achievements. They are
## ordinary objectives in data/progression/objectives.json marked "secret",
## paid in renown by the existing ObjectiveProgress (exactly once, saved), and
## the Captain's Log reveals nothing about them until they are found.

const APP_SCENE := preload("res://src/app/app.tscn")
const HOUR := 3600.0
const DECK := SessionState.AREA_EXTERIOR
const SECRETS := ["secret_captain_no_hat", "secret_hat_trick", "secret_hold_onto_your_hat", "secret_hat_tax",
	"secret_last_straw", "secret_captain_of_distinction", "secret_sea_wears_a_hat"]

var t: Node
var app: Node
var _awarded: Array = []


func run(runner: Node) -> void:
	t = runner
	Simulation.auto_advance = false
	WeatherFixtures.clear()
	t.use_calm_wind()
	GameSession.renown_awarded.connect(_on_awarded)
	_test_catalog()
	_test_captain_no_hat_and_hat_trick()
	_test_exactly_once_after_reload()
	_test_hat_tax()
	_test_last_straw()
	_test_hold_onto_your_hat()
	_test_captain_of_distinction()
	_test_sea_wears_a_hat()
	_test_no_farming()
	GameSession.renown_awarded.disconnect(_on_awarded)
	GameSession.end_session()
	t.use_calm_wind()

	app = APP_SCENE.instantiate()
	t.add_child(app)
	app.router.fade_duration = 0.05
	await _settle()
	app.start_new_game()
	await _settle()
	await _test_log_hides_then_reveals()
	Simulation.auto_advance = true
	app.queue_free()
	await t.frames(2)
	GameSession.end_session()
	t.use_calm_wind()


func _settle() -> void:
	await t.frames(2)
	await t.wait_until(func() -> bool: return not app.router.is_busy(), 5.0)
	await t.physics_frames(3)


func _on_awarded(awards: Array) -> void:
	for award: Dictionary in awards:
		_awarded.append(award)


func _secret_awards() -> Array[String]:
	var ids: Array[String] = []
	for award: Dictionary in _awarded:
		if award.get("secret", false):
			ids.append(String(award.id))
	return ids


func _replace(edit: Callable) -> void:
	var state := GameSession.get_state_snapshot()
	edit.call(state)
	GameSession.replace_state(state)


## Keeps the hat on deck in the wind until it blows away (at most `minutes`).
func _lose_hat_on_deck(minutes := 240) -> bool:
	GameSession.enter_boat_area(DECK, &"start")
	if GameSession.get_hat_status() == HatState.STORED:
		GameSession.use_hat_hook()
	elif GameSession.get_hat_status() == HatState.CARRIED:
		GameSession.toggle_hat()
	for i in minutes:
		Simulation.advance(60.0)
		if GameSession.get_hat_status() == HatState.LOST:
			return true
	return false


func _test_catalog() -> void:
	var catalog := ObjectiveCatalog.get_default()
	var secrets := catalog.objectives.filter(func(o: Dictionary) -> bool: return o.secret)
	t.check_eq(secrets.size(), 7, "[secrets] all seven hat achievements are in the objectives data")
	for id in SECRETS:
		var o := catalog.get_objective(StringName(id))
		t.check(not o.is_empty() and o.secret and not o.repeatable and int(o.reward) > 0 and int(o.reward) <= 40,
			"[secrets] %s: secret, once only, a modest reward (%d renown)" % [o.get("title", id), int(o.get("reward", 0))])
	t.check_eq(catalog.get_objective(&"secret_captain_no_hat").text, "The sea has claimed its most important trophy.",
		"[secrets] Captain No-Hat has the owner's description")
	var regular := catalog.objectives.filter(func(o: Dictionary) -> bool: return not o.secret)
	t.check_eq(regular.size(), 16, "[secrets] the 16 regular objectives are unchanged")
	var problem := ObjectiveCatalog.validate({"id": "x", "type": "hat_weather_voyage", "reward": 5, "hazard": 7}, PortCatalog.get_default())
	t.check(not problem.is_empty(), "[secrets] an invalid hat objective is refused (%s)" % problem)


func _test_captain_no_hat_and_hat_trick() -> void:
	GameSession.start_new_session()
	_awarded.clear()
	t.set_wind(270.0, 48.0)
	t.check(_lose_hat_on_deck(), "[secrets] the first hat blows away in a harbour storm")
	t.check_eq(_secret_awards(), ["secret_captain_no_hat"], "[secrets] Captain No-Hat is found on the first loss")
	var award: Dictionary = _awarded[0]
	t.check(award.tone == ObjectiveCatalog.TONE_COMIC and String(award.text).begins_with("The sea"), "[secrets] it comes with its comic tone and text")
	var progress := GameSession.get_objective_progress()
	t.check(progress.lifetime_renown == 10 and progress.unpublished_renown == 10, "[secrets] +10 renown, lifetime and unpublished")
	t.check_eq(float(progress.completed["secret_captain_no_hat"].first), GameSession.get_hat().history[0].time,
		"[secrets] the completion date is the moment of the loss")
	for n in [2, 3]:
		GameSession.buy_hat()
		t.check(_lose_hat_on_deck(), "[secrets] hat number %d blows away too" % n)
	t.check_eq(_secret_awards(), ["secret_captain_no_hat", "secret_hat_trick"], "[secrets] Hat Trick on the third loss, and nothing else")
	t.check_eq(GameSession.get_lifetime_renown(), 25, "[secrets] renown 10 + 15")
	t.check_eq(GameSession.get_objective_progress().get_count(&"secret_captain_no_hat"), 1, "[secrets] Captain No-Hat paid once only")


func _test_exactly_once_after_reload() -> void:
	var errors: Array[String] = []
	var loaded := SessionState.from_dict(JSON.parse_string(JSON.stringify(GameSession.get_state_snapshot().to_dict())), errors)
	t.check(loaded != null and loaded.progress.is_completed(&"secret_hat_trick"), "[secrets] found achievements are saved")
	GameSession.replace_state(loaded)
	_awarded.clear()
	GameSession.buy_hat()
	_lose_hat_on_deck()
	t.check(_secret_awards().is_empty() and GameSession.get_lifetime_renown() == 25,
		"[secrets] after loading, a fourth loss pays nothing again")
	t.check_eq(GameSession.get_hat().lost_count, 4, "[secrets] the hats are still counted")


func _test_hat_tax() -> void:
	GameSession.start_new_session()
	_awarded.clear()
	_replace(func(state: SessionState) -> void:
		state.hat.status = HatState.LOST
		state.hat.lost_count = 6
		state.hat.bought_count = 6
		state.hat.serial = 7
		state.hat.spent = 90)
	GameSession.buy_hat()
	t.check(GameSession.get_hat().spent == 105 and _secret_awards() == ["secret_hat_tax"],
		"[secrets] The Hat Tax: found when replacement hats reach €100 (€105)")
	t.check_eq(GameSession.get_lifetime_renown(), 10, "[secrets] +10 renown")


func _test_last_straw() -> void:
	# Logic: a replacement lost within five game minutes of buying it.
	var straw := ObjectiveCatalog.get_default().get_objective(&"secret_last_straw")
	var hat := HatState.new()
	hat.lost_count = 2
	var event := {"kind": ObjectiveCatalog.HAT_EVENT_LOST, "time": 1000.0 + 300.0, "bought_at": 1000.0}
	t.check(ObjectiveCatalog.is_met_by_hat_event(straw, event, null, hat), "[secrets] The Last Straw: lost 5 minutes after buying counts")
	event.time = 1000.0 + 301.0
	t.check(not ObjectiveCatalog.is_met_by_hat_event(straw, event, null, hat), "[secrets] ...5 minutes and 1 second does not")
	event.bought_at = -1.0
	event.time = 10.0
	t.check(not ObjectiveCatalog.is_met_by_hat_event(straw, event, null, hat), "[secrets] ...and the original hat never counts")
	# In the game: a severe storm (48 kn, gusts 60) right outside the harbour.
	# Pick a game seed whose second hat is a loose fit (threshold <= 24).
	var seed := 1
	while HatConfig.get_default().threshold_for(seed, 2) > 24.0 and seed < 500:
		seed += 1
	GameSession.start_new_session()
	_awarded.clear()
	t.set_wind(270.0, 48.0)
	_replace(func(state: SessionState) -> void:
		state.wind_seed = seed
		state.hat.status = HatState.LOST
		state.hat.lost_count = 1)
	GameSession.buy_hat()
	GameSession.set_planned_route(t.make_route(&"copenhagen", &"kiel"))
	GameSession.depart()
	t.check(_lose_hat_on_deck(5), "[secrets] the brand-new hat blows away within five minutes at sea in a storm")
	t.check(_secret_awards().has("secret_last_straw"), "[secrets] The Last Straw is found (seed %d)" % seed)


func _test_hold_onto_your_hat() -> void:
	for case in ["kept", "lost", "never_worn"]:
		GameSession.start_new_session()
		_awarded.clear()
		t.set_wind(270.0, 36.0)  # gusts 45: dangerous
		GameSession.set_planned_route(t.make_route(&"copenhagen", &"malmo"))
		GameSession.depart()
		GameSession.enter_boat_area(DECK, &"start")
		if case != "never_worn":
			GameSession.use_hat_hook()
			Simulation.advance(5.0 * 60.0)
			if case == "kept":
				GameSession.toggle_hat()  # off and under the arm before it goes
			else:
				_lose_hat_on_deck()
		var arrived := false
		for i in 48:
			Simulation.advance(HOUR)
			if not GameSession.is_underway():
				arrived = true
				break
		var found := _secret_awards().has("secret_hold_onto_your_hat")
		match case:
			"kept":
				t.check(arrived and found, "[secrets] Hold Onto Your Hat: worn on deck in dangerous weather, kept, arrived")
			"lost":
				t.check(arrived and not found, "[secrets] ...not when the hat was lost on the voyage")
			_:
				t.check(arrived and not found, "[secrets] ...not when the hat stayed below")


func _test_captain_of_distinction() -> void:
	for original in [true, false]:
		GameSession.start_new_session()
		_awarded.clear()
		t.use_calm_wind()
		_replace(func(state: SessionState) -> void:
			state.captains_log.voyages_completed = 9
			state.captains_log.arrivals = 9
			if not original:
				state.hat.lost_count = 1
				state.hat.serial = 2
				state.hat.status = HatState.STORED)
		GameSession.set_planned_route(t.make_route(&"copenhagen", &"malmo"))
		GameSession.depart()
		for i in 24:
			Simulation.advance(HOUR)
			if not GameSession.is_underway():
				break
		var found := _secret_awards().has("secret_captain_of_distinction")
		if original:
			t.check(found and GameSession.get_captains_log().voyages_completed == 10,
				"[secrets] A Captain of Distinction: the tenth voyage with the original hat")
		else:
			t.check(not found, "[secrets] ...not once the original hat has been lost")


func _test_sea_wears_a_hat() -> void:
	var middle := HatStory.open_water_nm(Vector2(2.0, 57.5), 30.0)
	var harbour := HatStory.open_water_nm(PortCatalog.get_default().get_port(&"copenhagen").get_geo_position(), 30.0)
	t.check(middle >= 29.0, "[secrets] the middle of the North Sea is open water (%.1f nm)" % middle)
	t.check(harbour < 2.0, "[secrets] Copenhagen harbour is not (%.1f nm)" % harbour)
	var near_island := HatStory.open_water_nm(Vector2(14.45, 55.1), 30.0)  # about 8 nm west of Bornholm
	t.check(near_island < 20.0, "[secrets] small islands count as land (off Bornholm: %.1f nm)" % near_island)
	GameSession.start_new_session()
	_awarded.clear()
	t.use_calm_wind()
	_replace(func(state: SessionState) -> void:
		state.location_id = &"aberdeen"
		state.vessel_position = PortCatalog.get_default().get_port(&"aberdeen").get_geo_position())
	GameSession.set_planned_route(t.make_route(&"aberdeen", &"stavanger"))
	GameSession.depart()
	Simulation.advance(28.0 * HOUR)  # about 140 nm out, mid North Sea
	t.check(GameSession.is_underway() and HatStory.open_water_nm(GameSession.get_vessel_position(), 30.0) >= 20.0,
		"[secrets] mid-crossing, there is no land within 20 nm")
	t.set_wind(270.0, 48.0)
	t.check(_lose_hat_on_deck(), "[secrets] the hat blows away far out at sea")
	var line := String(GameSession.get_hat().history[0].text)
	t.check(line.contains("far out at sea") and line.contains("nm from the nearest harbour"),
		"[secrets] the log says where, from real data: %s" % line)
	t.check(_secret_awards().has("secret_sea_wears_a_hat"), "[secrets] The Sea Wears a Hat Now is found")
	# And not in harbour.
	GameSession.start_new_session()
	_awarded.clear()
	_lose_hat_on_deck()
	t.check(not _secret_awards().has("secret_sea_wears_a_hat"), "[secrets] ...but not for a hat lost in harbour")


## Losing hat after hat never becomes a way to make money: each secret pays
## once, and the renown it can bring is worth less than the hats.
func _test_no_farming() -> void:
	GameSession.start_new_session()
	_awarded.clear()
	t.set_wind(270.0, 48.0)
	for i in 12:
		if GameSession.get_hat_status() == HatState.LOST:
			GameSession.buy_hat()
		_lose_hat_on_deck()
	var hat := GameSession.get_hat()
	var renown := GameSession.get_lifetime_renown()
	t.check(hat.lost_count == 12 and hat.spent == 11 * 15, "[secrets] twelve hats lost, eleven bought (€%d)" % hat.spent)
	t.check(renown == 10 + 15 + 10, "[secrets] only Captain No-Hat, Hat Trick and The Hat Tax paid, once each (%d renown)" % renown)
	var euros := renown * ObjectiveCatalog.get_default().euros_per_renown
	t.check(euros < hat.spent, "[secrets] publishing that renown (€%d) pays less than the hats cost (€%d)" % [euros, hat.spent])


func _labels_text(node: Node) -> String:
	var text := ""
	for label: Label in node.find_children("*", "Label", true, false):
		text += label.text + "\n"
	return text


func _test_log_hides_then_reveals() -> void:
	var catalog := ObjectiveCatalog.get_default()
	var menu: CaptainsLogMenu = app.open_captains_log()
	await t.frames(2)
	menu.show_tab(CaptainsLogMenu.TAB_OBJECTIVES)
	await t.frames(2)
	var text := _labels_text(menu)
	var leaked := []
	for id in SECRETS:
		var o := catalog.get_objective(StringName(id))
		if text.contains(o.title) or text.contains(o.text):
			leaked.append(o.title)
	t.check(leaked.is_empty(), "[secrets ui] before finding them, no secret title or description appears anywhere in the log %s" % [leaked if leaked else ""])
	t.check(text.contains("7 secret achievements are still to discover"), "[secrets ui] only a mystery line says how many remain")
	t.check(menu.find_child("Secret_secret_captain_no_hat", true, false) == null, "[secrets ui] no entry exists for a hidden one")
	await t.screenshot("125_log_secrets_hidden")
	app.modals.clear()
	await t.frames(2)
	t.set_wind(270.0, 48.0)
	_awarded.clear()
	_lose_hat_on_deck()
	var shown := false
	for message in app.toasts.get_messages():
		shown = shown or message.begins_with("Secret achievement: Captain No-Hat. The sea has claimed its most important trophy.")
	t.check(shown, "[secrets ui] finding it shows a short notification with its title and description")
	menu = app.open_captains_log()
	await t.frames(2)
	menu.show_tab(CaptainsLogMenu.TAB_OBJECTIVES)
	await t.frames(2)
	var entry := menu.find_child("Secret_secret_captain_no_hat", true, false)
	t.check(entry != null, "[secrets ui] after finding it, the log lists it")
	if entry:
		var line := _labels_text(entry)
		t.check(line.contains("Captain No-Hat") and line.contains("10 renown") and line.contains("found ")
			and line.contains("The sea has claimed its most important trophy."), "[secrets ui] with title, renown, date and description")
	text = _labels_text(menu)
	t.check(text.contains("6 secret achievements are still to discover") and not text.contains("Hat Trick"),
		"[secrets ui] the others stay hidden")
	await t.screenshot("126_log_secret_found")
	menu.show_tab(CaptainsLogMenu.TAB_LOG)
	await t.frames(2)
	var moments := menu.find_child("Moments", true, false)
	t.check(moments != null and _labels_text(moments).contains("Lost my captain's hat in Copenhagen harbour"),
		"[secrets ui] the Log tab's notable moments tell the story")
	t.check(menu.find_child("Passages", true, false) != null, "[secrets ui] the voyage records are still there, unchanged")
	await t.screenshot("127_log_notable_moments")
	app.modals.clear()
	await t.frames(2)
	t.use_calm_wind()
