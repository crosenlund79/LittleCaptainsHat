extends RefCounted
## Iteration 17 (BOAT-1, SAVE-1..3): sailing correctness.
## - The deck turns with the heading while the captain is on deck, also when
##   the heading changes without a route edit (the autopilot passing a
##   waypoint), at the bow or stern, after the cabin and after a reload.
## - Saving underway and loading puts the captain back aboard where they
##   stood (positions are relative to the boat), in the deck or the cabin; a
##   position that is not aboard falls back to the spawn point.
## - Reloading reproduces the weather: the same save sailed on the same way
##   gives the same wind, position and condition (no rerolled storms).
## - F5 quicksaves (own file, never a manual slot), F9 loads it (asking when
##   progress would be lost); repeated presses do nothing more; refused while
##   a window is open.

const APP_SCENE := preload("res://src/app/app.tscn")
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
	SettingsManager.set_course_view(true)
	app.start_new_game()
	await _settle()
	_clear_saves()
	await _test_deck_turns_with_heading()
	await _test_save_load_underway()
	await _test_invalid_position_falls_back()
	_test_weather_reproduces()
	await _test_quicksave()
	_clear_saves()
	SettingsManager.set_course_view(SettingsManager.DEFAULT_COURSE_VIEW)
	Simulation.auto_advance = true
	app.queue_free()
	await t.frames(2)
	GameSession.end_session()
	t.use_calm_wind()


func _settle() -> void:
	await t.frames(2)
	await t.wait_until(func() -> bool: return not app.router.is_busy(), 5.0)
	await t.physics_frames(3)


func _clear_saves() -> void:
	for slot in [1, 2, 3, SaveManager.QUICKSAVE_SLOT]:
		SaveManager.delete_slot(slot)


func _show(area: StringName, spawn := &"start") -> BoatArea:
	app.modals.clear()
	GameSession.enter_boat_area(area, spawn)
	app._show_current_boat_area()
	await _settle()
	return app.router.current_screen as BoatArea


func _bow_on_screen(deck: BoatArea) -> Vector2:
	var canvas := deck.get_viewport().get_canvas_transform()
	return ((canvas * deck.to_global(Vector2(400, 0))) - (canvas * deck.to_global(Vector2.ZERO))).normalized()


## Where the deck's bow should point on screen for the current heading's octant.
func _expected_bow(deck: BoatArea) -> Vector2:
	var octant := deck.get_view_octant()
	return Vector2.from_angle(deg_to_rad(octant * 45.0 - 90.0))


func _turned_right(deck: BoatArea) -> bool:
	return _bow_on_screen(deck).dot(_expected_bow(deck)) > 0.99


## A long voyage with turns: Copenhagen round the Skaw and down to Las Palmas.
func _depart_with_turns() -> void:
	t.set_wind(270.0, 14.0)
	GameSession.plan_route_to(&"las_palmas")
	GameSession.depart()
	Simulation.advance(600.0)


## Sails on until the heading's octant changes (no route edit, no signal).
func _sail_to_next_octant(deck: BoatArea) -> bool:
	var start := BoatArea.octant_for(Simulation.get_current_heading())
	for i in 400:
		Simulation.advance(300.0)
		if not GameSession.is_underway():
			return false
		if BoatArea.octant_for(Simulation.get_current_heading(), start) != start:
			return true
	return false


func _test_deck_turns_with_heading() -> void:
	_depart_with_turns()
	var deck := await _show(DECK)
	await t.get_tree().create_timer(BoatArea.ZOOM_TRANSITION_S + 0.2).timeout
	t.check(deck.is_course_view() and _turned_right(deck), "[orientation] underway, the deck is drawn along the heading")
	var bounds := deck._boat_view_bounds()
	var turns := 0
	var spots := {"amidships": deck.get_spawn_position(&"start"), "bow": Vector2(bounds.end.x - 110.0, 0.0),
		"stern": Vector2(bounds.position.x + 90.0, 0.0)}
	for where: String in spots:
		deck.player.position = spots[where]
		if not await _sail_to_next_octant(deck):
			break
		await t.get_tree().create_timer(BoatArea.ZOOM_TRANSITION_S + 0.2).timeout
		turns += 1
		t.check(_turned_right(deck), "[orientation] the autopilot turns to %s at a waypoint: the deck turns with it, captain at the %s" % [
			BoatArea.OCTANT_NAMES[deck.get_view_octant()], where])
		t.check(deck.is_valid_player_position(deck.player.position) and deck.player.get_parent() == deck,
			"[orientation] the captain is still aboard at the %s after the turn" % where)
	t.check(turns >= 2, "[orientation] several turns in succession were sailed (%d)" % turns)
	await t.screenshot("17_deck_turned_with_heading")
	# A course change (a route edit) still turns it too, and the cabin round trip.
	var cabin := await _show(CABIN)
	t.check(cabin != null and cabin.area_id == CABIN, "[orientation] into the cabin underway")
	await _sail_to_next_octant(cabin)
	deck = await _show(DECK, &"from_cabin")
	await t.get_tree().create_timer(BoatArea.ZOOM_TRANSITION_S + 0.2).timeout
	t.check(_turned_right(deck), "[orientation] back on deck after the heading changed below: drawn along the new heading")


## Saves underway, loads, and compares everything (positions relative to the boat).
func _round_trip(label: String, area: StringName, position: Vector2) -> void:
	var here := await _show(area)
	here.player.position = position
	await t.physics_frames(20)  # settled against any fixture it was placed in
	var before := GameSession.get_state_snapshot().to_dict()
	t.check(SaveManager.save_to_slot(2, GameSession.get_state_snapshot()) == OK, "[save] %s: saved" % label)
	Simulation.advance(1800.0)  # the game moves on before the load
	app.load_slot(2)
	await _settle()
	var loaded := app.router.current_screen as BoatArea
	var after := GameSession.get_state_snapshot().to_dict()
	var stood: Vector2 = Vector2(before.player.position.x, before.player.position.y)
	t.check(loaded != null and loaded.area_id == area and loaded.player.position.is_equal_approx(stood)
		and loaded.is_valid_player_position(loaded.player.position),
		"[save] %s: loaded aboard, in the %s, where the captain stood (%s)" % [label, SessionState.get_area_display_name(area), loaded.player.position if loaded else "-"])
	_print_diff(before, after)
	t.check(_same(after, before), "[save] %s: time, position, heading, route, next waypoint, weather seed, condition, money, provisions, pets and progress restored" % label)


func _test_save_load_underway() -> void:
	t.check(GameSession.is_underway(), "(setup) underway")
	var deck := await _show(DECK)
	var bounds := deck._boat_view_bounds()
	var helm := deck.get_spawn_position(&"start")
	await _round_trip("at the helm", DECK, helm)
	await _round_trip("near the bow", DECK, Vector2(bounds.end.x - 110.0, 0.0))
	await _round_trip("near the stern", DECK, Vector2(bounds.position.x + 90.0, 0.0))
	var cabin := await _show(CABIN)
	var berth := cabin.get_spawn_position(&"start")
	await _round_trip("in the cabin", CABIN, berth)
	# Just after a course change at sea.
	var changed := GameSession.change_course(&"brest", [] as Array[Vector2])
	t.check(changed == "", "(setup) course changed at sea %s" % changed)
	await _round_trip("after a course change", DECK, helm)
	# At anchor (anchored where the boat is; the site rules are not the point here).
	var anchored := GameSession.get_state_snapshot()
	anchored.anchor.active = true
	anchored.anchor.position = anchored.vessel_position
	anchored.anchor.scope = 5
	anchored.anchor.anchored_at = anchored.game_time
	anchored.anchor.checked_until = anchored.game_time
	GameSession.replace_state(anchored)
	await _round_trip("at anchor", DECK, helm)
	t.check(GameSession.is_anchored(), "[save] still at anchor after loading")
	GameSession.raise_anchor()
	# In bad weather, at night: the same, with a gale over the boat.
	var night := floorf(GameSession.get_game_time() / 86400.0) * 86400.0 + 86400.0 + 23.0 * 3600.0
	Simulation.advance(night - GameSession.get_game_time())
	WeatherFixtures.use([WeatherFixtures.gale("test-gale", GameSession.get_vessel_position(), 150.0, 38.0,
		GameSession.get_game_time() - 3600.0, 72.0)], true)
	deck = await _show(DECK)
	await _round_trip("in a gale at night", DECK, deck.get_spawn_position(&"start") + Vector2(40.0, 0.0))
	WeatherFixtures.clear()
	await t.get_tree().create_timer(BoatArea.ZOOM_TRANSITION_S + 0.2).timeout
	var deck_now := app.router.current_screen as BoatArea
	t.check(deck_now != null and deck_now.is_course_view() and _turned_right(deck_now),
		"[save] after loading, the deck is drawn along the saved heading")


func _test_invalid_position_falls_back() -> void:
	var deck := app.router.current_screen as BoatArea
	var bounds := deck.walkable_bounds
	# A corner of the bounds beside the bow is water, not deck.
	var water := Vector2(bounds.end.x - 2.0, bounds.end.y - 2.0)
	t.check(not deck.is_valid_player_position(water), "[save] a position over the water beside the bow is not aboard")
	var state := GameSession.get_state_snapshot()
	state.player_position = water
	state.has_player_position = true
	state.boat_area = DECK
	SaveManager.save_to_slot(2, state)
	app.load_slot(2)
	await _settle()
	var loaded := app.router.current_screen as BoatArea
	t.check(loaded != null and loaded.is_valid_player_position(loaded.player.position) and not loaded.player.position.is_equal_approx(water),
		"[save] a saved position that is not aboard puts the captain at the spawn point instead (%s)" % (loaded.player.position if loaded else "-"))


## The same save, sailed on the same way twice, gives the same weather and result.
func _test_weather_reproduces() -> void:
	WindField.get_default().test_override = Callable()  # the real weather
	var saved := GameSession.get_state_snapshot().to_dict()
	var results := []
	for run in 2:
		var errors: Array[String] = []
		GameSession.replace_state(SessionState.from_dict(JSON.parse_string(JSON.stringify(saved)), errors))
		var winds := []
		for k in 24:
			Simulation.advance(1800.0)
			var w := Simulation.get_weather_at_vessel()
			winds.append("%.4f|%.4f|%s" % [w.speed_kn, w.from_deg, w.classification])
		results.append([winds, GameSession.get_vessel_position(), GameSession.get_condition(), GameSession.get_game_time()])
	t.check(results[0][0] == results[1][0], "[weather] reloading the same save gives the same wind for the next 12 hours (no reroll)")
	t.check(results[0][1].is_equal_approx(results[1][1]) and is_equal_approx(results[0][2], results[1][2]),
		"[weather] and the same position and boat condition")
	var other := Simulation.get_weather_at(GameSession.get_vessel_position(), GameSession.get_game_time() + 3600.0)
	t.check(other != null, "[weather] weather goes on changing after the load (not frozen)")
	t.set_wind(270.0, 14.0)


func _slot_bytes() -> String:
	var text := ""
	for slot in [1, 2, 3]:
		text += SaveManager.get_slot_bytes(slot).get_string_from_utf8()
	return text


func _test_quicksave() -> void:
	SaveManager.save_to_slot(1, GameSession.get_state_snapshot())
	var deck := await _show(DECK)
	app.toasts.clear()
	var manual := _slot_bytes()
	var writes := [0]
	var count := func() -> void: writes[0] += 1
	SaveManager.slots_changed.connect(count)
	app._last_quick_msec = -100000
	await t.press_key(KEY_F5)
	await t.press_key(KEY_F5)  # a second press straight away does nothing more
	await t.frames(2)
	t.check(writes[0] == 1 and SaveManager.get_slot_info(SaveManager.QUICKSAVE_SLOT).is_loadable(), "[quick] F5 quicksaves once (%d writes)" % writes[0])
	t.check(_slot_bytes() == manual, "[quick] the manual save slots are untouched")
	var quick_state := GameSession.get_state_snapshot().to_dict()
	t.check(not GameSession.has_unsaved_changes(), "[quick] the quicksave counts as saved")
	# Refused while a window is open.
	app._last_quick_msec = -100000
	app.open_pause_menu()
	await _settle()
	app.quicksave()
	t.check(writes[0] == 1, "[quick] no quicksave while a window is open")
	app.modals.clear()
	await _settle()
	SaveManager.slots_changed.disconnect(count)
	# The game moves on; F9 asks, then restores the quicksave.
	deck = app.router.current_screen as BoatArea
	deck.player.position += Vector2(30.0, 0.0)
	Simulation.advance(3600.0)
	await t.physics_frames(2)
	t.check(GameSession.has_unsaved_changes(), "(setup) progress since the quicksave")
	app._last_quick_msec = -100000
	await t.press_key(KEY_F9)
	await t.frames(3)
	var dialog: Node = app.modals.get_top()
	t.check(dialog != null, "[quick] F9 asks before losing progress")
	if dialog:
		var load_button := dialog.find_child("ConfirmButton", true, false) as Button
		if load_button == null:
			for b in dialog.find_children("*", "Button", true, false):
				if (b as Button).text == "Load":
					load_button = b
		if load_button:
			await t.click(load_button)
	await _settle()
	_print_diff(quick_state, GameSession.get_state_snapshot().to_dict())
	t.check(_same(GameSession.get_state_snapshot().to_dict(), quick_state), "[quick] F9 restores the quicksave exactly")
	t.check(GameSession.is_underway() and (app.router.current_screen as BoatArea) != null, "[quick] still aboard and underway after the quickload")
	await t.press_key(KEY_F9)  # straight away: nothing (no second load, no dialog)
	await t.frames(2)
	t.check(app.modals.is_empty(), "[quick] a repeated F9 does nothing more")
	SaveManager.delete_slot(SaveManager.QUICKSAVE_SLOT)
	app._last_quick_msec = -100000
	app.quickload()
	await t.frames(2)
	t.check(app.modals.is_empty(), "[quick] F9 without a quicksave only says so")


func _print_diff(before: Dictionary, after: Dictionary) -> void:
	for k in before:
		if not _same(before[k], after.get(k)):
			print("    differs: %s: %s -> %s" % [k, JSON.stringify(before[k]).left(300), JSON.stringify(after.get(k)).left(300)])


## Full precision, as the save file is written.
func _json(value: Variant) -> String:
	return JSON.stringify(value, "", true, true)


## Equal values, numbers to 1e-9 relative (the last bits of a double may
## differ after the text round trip; nothing a player could see).
func _same(a: Variant, b: Variant) -> bool:
	if (typeof(a) == TYPE_FLOAT or typeof(a) == TYPE_INT) and (typeof(b) == TYPE_FLOAT or typeof(b) == TYPE_INT):
		return absf(float(a) - float(b)) <= 1e-9 * maxf(1.0, absf(float(a)))
	if typeof(a) != typeof(b):
		return false
	if a is Dictionary:
		if a.size() != b.size():
			return false
		for k in a:
			if not b.has(k) or not _same(a[k], b[k]):
				return false
		return true
	if a is Array:
		if a.size() != b.size():
			return false
		for i in a.size():
			if not _same(a[i], b[i]):
				return false
		return true
	return a == b
