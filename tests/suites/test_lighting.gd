extends RefCounted
## Iteration 17 (LGT): day and night by the game clock and the boat's place.
## - Daylight: local solar time from longitude, sun elevation with latitude
##   and season (midnight sun in the Arctic summer), phases night → dawn →
##   day → dusk → night, and smooth colours (no jumps).
## - Every boat's cabin has warm lamps at its own fixtures, lit at night and
##   off in bright daylight, with daylight through the hatches by day; the
##   deck has instrument, companionway and navigation lights at night; the
##   harbour's lamps are lit at night while moored; soft shadows and contact
##   shadows are present.
## - The light jumps to the right hour after a load and follows fast time
##   (Long Passage) gently; highlights stay as bright at night.

const APP_SCENE := preload("res://src/app/app.tscn")
const BOATS: Array[StringName] = [&"arctic_wanderer_26", &"starling_33", &"petrel_36", &"halcyon_40"]
const COPENHAGEN := Vector2(12.6, 55.7)

var t: Node
var app: Node


func run(runner: Node) -> void:
	t = runner
	_test_daylight_model()
	Simulation.auto_advance = false
	app = APP_SCENE.instantiate()
	t.add_child(app)
	app.router.fade_duration = 0.05
	await _settle()
	app.start_new_game()
	await _settle()
	await _test_cabins()
	await _test_deck_and_harbour()
	await _test_fast_time_and_load()
	Simulation.auto_advance = true
	app.queue_free()
	await t.frames(2)
	GameSession.end_session()


func _settle() -> void:
	await t.frames(2)
	await t.wait_until(func() -> bool: return not app.router.is_busy(), 5.0)
	await t.physics_frames(3)


## The next game time from `start` when the sun at `geo` is at `elevation`
## (rising when `rising`), searched in 5-minute steps.
static func time_at_elevation(geo: Vector2, start: float, elevation: float, rising: bool) -> float:
	var previous := Daylight.sun_elevation(geo, start)
	for i in range(1, 600):
		var time := start + i * 300.0
		var e := Daylight.sun_elevation(geo, time)
		if (rising and previous < elevation and e >= elevation) or (not rising and previous > elevation and e <= elevation):
			return time
		previous = e
	return start


func _test_daylight_model() -> void:
	var may := 1777593600.0  # Fri 1 May 2026, 00:00 UTC
	var june := may + 51.0 * 86400.0  # 21 June
	var noon_cph := may + (12.0 - COPENHAGEN.x / 15.0) * 3600.0
	t.check(Daylight.sun_elevation(COPENHAGEN, noon_cph) > 45.0 and Daylight.sun_elevation(COPENHAGEN, noon_cph + 12.0 * 3600.0) < -6.0,
		"[sun] Copenhagen in May: high at local noon (%.0f°), night at local midnight (%.0f°)" % [
			Daylight.sun_elevation(COPENHAGEN, noon_cph), Daylight.sun_elevation(COPENHAGEN, noon_cph + 12.0 * 3600.0)])
	var tromso := Vector2(18.96, 69.65)
	var midnight := june + (24.0 - tromso.x / 15.0) * 3600.0
	t.check(Daylight.sun_elevation(tromso, midnight) > 0.0, "[sun] Tromsø at midsummer midnight: the midnight sun (%.1f°)" % Daylight.sun_elevation(tromso, midnight))
	# Longitude: the same UTC instant is day in Copenhagen and night in Papeete.
	var papeete := Vector2(-149.57, -17.54)
	var utc := may + 12.0 * 3600.0
	t.check(Daylight.phase(COPENHAGEN, utc) == Daylight.DAY and Daylight.phase(papeete, utc) == Daylight.NIGHT,
		"[sun] 12:00 UTC: day in Copenhagen, night in Papeete (local solar time by longitude)")
	# The day's phases in order, and the highest sun at local noon.
	var order := []
	var best := -INF
	var best_hour := 0.0
	for i in 288:
		var time := may + i * 300.0
		var phase := Daylight.phase(COPENHAGEN, time)
		if order.is_empty() or order.back() != phase:
			order.append(phase)
		var e := Daylight.sun_elevation(COPENHAGEN, time)
		if e > best:
			best = e
			best_hour = Daylight.local_solar_hours(COPENHAGEN.x, time)
	t.check(order.slice(0, 5) == [Daylight.NIGHT, Daylight.DAWN, Daylight.DAY, Daylight.DUSK, Daylight.NIGHT],
		"[sun] a day goes night → dawn → day → dusk → night (%s)" % ", ".join(order))
	t.check(absf(best_hour - 12.0) < 0.2, "[sun] the sun is highest at local solar noon (%.2f h)" % best_hour)
	# Smooth: no jumps between 5-minute steps, outside or in the cabin.
	var worst := 0.0
	var before := Daylight.outside_colour(Daylight.sun_elevation(COPENHAGEN, may))
	var before_in := Daylight.inside_colour(Daylight.sun_elevation(COPENHAGEN, may))
	for i in range(1, 288):
		var e := Daylight.sun_elevation(COPENHAGEN, may + i * 300.0)
		var c := Daylight.outside_colour(e)
		var c_in := Daylight.inside_colour(e)
		worst = maxf(worst, maxf(maxf(absf(c.r - before.r), absf(c.g - before.g)), absf(c.b - before.b)))
		worst = maxf(worst, maxf(maxf(absf(c_in.r - before_in.r), absf(c_in.g - before_in.g)), absf(c_in.b - before_in.b)))
		before = c
		before_in = c_in
	t.check(worst < 0.06, "[sun] light changes gradually (largest step in 5 minutes: %.3f)" % worst)


func _set_time(time: float) -> void:
	var state := GameSession.get_state_snapshot()
	state.game_time = time
	GameSession.replace_state(state)


func _board(id: StringName) -> void:
	var state := GameSession.get_state_snapshot()
	state.vessel_id = id
	GameSession.replace_state(state)


func _show(area: StringName) -> BoatArea:
	app.modals.clear()
	GameSession.enter_boat_area(area, &"start")
	app._show_current_boat_area()
	await _settle()
	return app.router.current_screen as BoatArea


func _test_cabins() -> void:
	var may := 1777593600.0
	var night := time_at_elevation(COPENHAGEN, may + 12.0 * 3600.0, -12.0, false)
	var noon := may + (12.0 - COPENHAGEN.x / 15.0) * 3600.0
	for id in BOATS:
		_board(id)
		_set_time(night)
		var cabin := await _show(SessionState.AREA_INTERIOR)
		var lighting := cabin.get_lighting()
		if not t.check(lighting != null, "[cabin] %s: lighting is set up" % id):
			continue
		var night_colour := lighting.get_ambient_colour()
		t.check(lighting.get_light_count("dark") >= 3 and lighting.get_light_energy("dark") > 1.0,
			"[cabin] %s: %d warm lamps at its own fixtures are lit at night" % [id, lighting.get_light_count("dark")])
		t.check(night_colour.get_luminance() < 0.6 and night_colour.get_luminance() > 0.35,
			"[cabin] %s: the night is dim but not black (%.2f)" % [id, night_colour.get_luminance()])
		t.check(Interactable.light_compensation.r > 1.4, "[cabin] %s: highlights are brightened to stay readable at night" % id)
		var shadows := cabin.get_node_or_null(^"FixtureShadows")
		t.check(shadows != null and shadows.outlines.size() >= 3 and cabin.player.has_node(^"ContactShadow"),
			"[cabin] %s: soft shadows beside %d fixtures, and under the captain" % [id, shadows.outlines.size() if shadows else 0])
		await t.screenshot("17_cabin_night_%s" % id)
		_set_time(noon)
		await t.frames(2)
		var day_colour := lighting.get_ambient_colour()
		t.check(day_colour.get_luminance() > 0.85 and lighting.get_light_energy("dark") < 0.05 and lighting.get_light_energy("day") > 0.1,
			"[cabin] %s: by day the ports and hatches light it, the lamps are off" % id)
	_board(&"arctic_wanderer_26")


func _test_deck_and_harbour() -> void:
	var may := 1777593600.0
	var night := time_at_elevation(COPENHAGEN, may + 12.0 * 3600.0, -12.0, false)
	_set_time(night)
	var deck := await _show(SessionState.AREA_EXTERIOR)
	var lighting := deck.get_lighting()
	t.check(lighting.get_ambient_colour().b > lighting.get_ambient_colour().r and lighting.get_ambient_colour().get_luminance() < 0.5,
		"[deck] at night the deck is in cool, dim light")
	t.check(lighting.get_light_count("harbour") >= 2 and lighting.get_light_energy("harbour") > 0.5,
		"[harbour] moored at night: %d harbour lights are lit (from the shared harbour dressing)" % lighting.get_light_count("harbour"))
	t.check(lighting.get_light_energy("night") > 0.5, "[deck] the helm glow, companionway spill and navigation lights are on")
	await t.screenshot("17_harbour_night")
	var dusk := time_at_elevation(COPENHAGEN, may + 12.0 * 3600.0, 0.0, false)
	_set_time(dusk)
	await t.frames(2)
	t.check(Daylight.phase(COPENHAGEN, dusk) == Daylight.DUSK and lighting.get_ambient_colour().r > lighting.get_ambient_colour().b,
		"[deck] dusk is warm")
	await t.screenshot("17_harbour_dusk")
	# Underway at night: no harbour lights.
	_set_time(night)
	t.set_wind(270.0, 14.0)
	GameSession.plan_route_to(&"kiel")
	GameSession.depart()
	Simulation.advance(1800.0)
	deck = await _show(SessionState.AREA_EXTERIOR)
	lighting = deck.get_lighting()
	await t.frames(2)
	t.check(lighting.get_light_energy("harbour") < 0.01 and lighting.get_light_energy("night") > 0.5,
		"[deck] underway at night: navigation lights on, no harbour lights")
	await t.screenshot("17_deck_night_underway")


func _test_fast_time_and_load() -> void:
	var deck := app.router.current_screen as BoatArea
	var lighting := deck.get_lighting()
	# Long Passage pace (12 game hours a second, simulated frame by frame).
	var worst := 0.0
	var previous := lighting.get_ambient_colour()
	for i in 60:
		Simulation.advance(43200.0 / 60.0)
		await t.frames(1)
		var c := lighting.get_ambient_colour()
		worst = maxf(worst, maxf(maxf(absf(c.r - previous.r), absf(c.g - previous.g)), absf(c.b - previous.b)))
		previous = c
	t.check(worst < 0.12, "[fast] at Long Passage pace the light swells gently, no strobe (largest frame step %.3f)" % worst)
	# After a load at another hour: straight to that hour's light.
	var may := 1777593600.0
	var noon := may + 2.0 * 86400.0 + (12.0 - GameSession.get_vessel_position().x / 15.0) * 3600.0
	var loaded := GameSession.get_state_snapshot()
	loaded.game_time = noon
	GameSession.replace_state(loaded)
	await t.frames(1)
	t.check(lighting.get_ambient_colour().get_luminance() > 0.85, "[load] after loading a noon save the light is noon's at once")
	t.use_calm_wind()
