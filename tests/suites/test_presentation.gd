extends RefCounted
## Iteration 17 (BOAT-2, BOAT-3, PORT-1, PORT-3): presentation.
## - Rigging, boom and sails are drawn above the captain; the rig turns
##   see-through while the captain is under the sail or boom.
## - The white objects on the starboard side are fenders in the deck art:
##   out in harbour, stowed underway (on every boat), back out on arrival
##   and after loading a game in harbour; the art files are untouched.
## - The destination preview lists the harbour's services from its data.
## - Arriving plays a short docking presentation: deck, captain at the helm,
##   harbour gliding in, engine on; skippable; one arrival only, nothing
##   consumed or rewarded twice.

const APP_SCENE := preload("res://src/app/app.tscn")
const BOATS: Array[StringName] = [&"arctic_wanderer_26", &"starling_33", &"petrel_36", &"halcyon_40"]
const DECK := SessionState.AREA_EXTERIOR

var t: Node
var app: Node


func run(runner: Node) -> void:
	t = runner
	Simulation.auto_advance = false
	app = APP_SCENE.instantiate()
	t.add_child(app)
	app.router.fade_duration = 0.05
	await _settle()
	app.start_new_game()
	await _settle()
	await _test_fenders()
	await _test_overhead_rig()
	_test_facilities_preview()
	await _test_docking_arrival()
	Simulation.auto_advance = true
	app.queue_free()
	await t.frames(2)
	GameSession.end_session()
	t.use_calm_wind()


func _settle() -> void:
	await t.frames(2)
	await t.wait_until(func() -> bool: return not app.router.is_busy(), 5.0)
	await t.physics_frames(3)


func _show(area: StringName, spawn := &"start") -> BoatArea:
	app.modals.clear()
	GameSession.enter_boat_area(area, spawn)
	app._show_current_boat_area()
	await _settle()
	return app.router.current_screen as BoatArea


func _board(id: StringName) -> void:
	var state := GameSession.get_state_snapshot()
	state.vessel_id = id
	GameSession.replace_state(state)


## The deck art texture that carries the fenders, and whether its fenders show.
func _fender_state(deck: BoatArea) -> Array:
	var visual := deck.get_node("Visual") as VesselVisual
	for slot_name in FenderStowage.SLOTS:
		var slot := visual.get_slot(slot_name)
		if slot and slot.is_sprite() and slot.get_sprite().has_meta(&"art_texture"):
			var art: Texture2D = slot.get_sprite().get_meta(&"art_texture")
			if not FenderStowage.find_fenders(art).is_empty():
				return [FenderStowage.find_fenders(art).size(), slot.get_sprite().texture == art]
	return [0, false]


func _test_fenders() -> void:
	for id in BOATS:
		_board(id)
		var deck := await _show(DECK)
		var state := _fender_state(deck)
		t.check(int(state[0]) >= 2 and state[1], "[fenders] %s: %d fenders hang over the side in harbour" % [id, state[0]])
	# Underway they are stowed; arriving puts them out again.
	_board(&"starling_33")
	t.set_wind(270.0, 14.0)
	GameSession.plan_route_to(&"helsingor")
	GameSession.depart()
	Simulation.advance(600.0)
	var deck := await _show(DECK)
	var underway := _fender_state(deck)
	t.check(int(underway[0]) >= 2 and not underway[1], "[fenders] underway the fenders are stowed")
	await t.screenshot("17_fenders_stowed_underway")
	var art_file := FileAccess.get_md5("res://assets/vessels/starling_33/illustrated/deck/deck_details.png")
	Simulation.advance(6.0 * 3600.0)
	await _settle()
	await t.get_tree().create_timer(BoatArea.DOCKING_SECONDS + 0.5).timeout
	deck = app.router.current_screen as BoatArea
	t.check(GameSession.is_moored_in_harbour() and _fender_state(deck)[1], "[fenders] arriving in harbour puts them out again")
	t.check(FileAccess.get_md5("res://assets/vessels/starling_33/illustrated/deck/deck_details.png") == art_file,
		"[fenders] the art file itself is never changed")
	# After loading a harbour save.
	SaveManager.save_to_slot(3, GameSession.get_state_snapshot())
	app.load_slot(3)
	await _settle()
	t.check(_fender_state(app.router.current_screen as BoatArea)[1], "[fenders] out after loading a game in harbour")
	SaveManager.delete_slot(3)


func _test_overhead_rig() -> void:
	_board(&"arctic_wanderer_26")
	t.set_wind(270.0, 14.0)
	GameSession.plan_route_to(&"kiel")
	GameSession.depart()
	Simulation.advance(1800.0)
	var deck := await _show(DECK)
	var rig := deck.get_node("SailRig") as SailRig
	t.check(rig.z_index > deck.player.z_index and not rig.z_as_relative, "[rig] the sails and boom are drawn above the captain")
	var rigging := deck.get_node_or_null(^"Visual/RiggingVisual") as CanvasItem
	t.check(rigging == null or rigging.z_index > deck.player.z_index, "[rig] the rigging too")
	# Under the boom: the rig turns see-through; away from it: solid.
	await t.get_tree().create_timer(1.0).timeout
	# A place on deck the captain can stand under the boom or sail (the
	# coachroof under the boom's middle is not walkable).
	var under := Vector2.INF
	for f in [0.95, 0.9, 0.85, 0.8, 0.7, 0.6, 0.5, 0.4]:
		var shape := rig.get_shape()
		var spot: Vector2 = rig.mast.lerp(shape.main.clew, f)
		deck.player.position = spot
		await t.physics_frames(4)
		if rig.covers(deck.player.position):
			under = deck.player.position
			break
	await t.get_tree().create_timer(0.6).timeout
	t.check(under != Vector2.INF and rig.modulate.a < 0.6, "[rig] with the captain under the boom the rig is see-through (%.2f at %s)" % [rig.modulate.a, under])
	await t.screenshot("17_captain_under_the_boom")
	deck.player.position = deck.get_spawn_position(&"start")
	await t.get_tree().create_timer(0.6).timeout
	t.check(rig.modulate.a > 0.95, "[rig] away from it, solid again")


func _test_facilities_preview() -> void:
	var catalog := PortCatalog.get_default()
	var mismatch := PackedStringArray()
	for port in catalog.ports:
		var text := HarbourFacilities.describe_services(port.id)
		var facilities := HarbourFacilities.for_port(port.id)
		for entry: Array in HarbourFacilities.PREVIEW:
			if facilities.has(entry[0]) != (String(entry[1]) in text):
				mismatch.append("%s/%s" % [port.id, entry[0]])
	t.check(mismatch.is_empty(), "[preview] all %d harbours list exactly the services in their data%s" % [catalog.ports.size(),
		"" if mismatch.is_empty() else ": " + mismatch[0]])
	t.check(not "Fuel" in HarbourFacilities.describe_services(&"copenhagen"), "[preview] no invented services (no fuel)")


func _test_docking_arrival() -> void:
	# Underway to Kiel in the cabin; arrival shows the deck and the docking.
	var log_before := GameSession.get_captains_log().to_dict()
	var arrivals_before := int(log_before.visited.get("kiel", {"arrivals": 0}).arrivals)
	await _show(SessionState.AREA_INTERIOR)
	var arrived := [0]
	var count := func(_port: StringName) -> void: arrived[0] += 1
	Simulation.arrived.connect(count)
	Simulation.advance(2.0 * 86400.0)
	await t.wait_until(func() -> bool:
		var area := app.router.current_screen as BoatArea
		return area != null and area.area_id == DECK and area.is_docking(), 5.0)
	var deck := app.router.current_screen as BoatArea
	t.check(deck != null and deck.area_id == DECK and deck.is_docking(), "[docking] arriving from the cabin shows the deck as the boat comes in")
	t.check(deck.player.position.is_equal_approx(deck.get_spawn_position(&"start")) and deck.is_valid_player_position(deck.player.position),
		"[docking] the captain is at the helm, aboard")
	t.check(AudioManager.is_loop_playing(app.ENGINE_LOOP), "[docking] the engine runs while coming alongside")
	var stores := GameSession.get_provisions().food_days
	await t.get_tree().create_timer(BoatArea.DOCKING_SECONDS * 0.4).timeout
	await t.screenshot("17_docking_arrival")
	await t.press_key(KEY_SPACE)  # skip
	await t.frames(3)
	t.check(not deck.is_docking() and deck.mooring.modulate.a == 1.0, "[docking] a key skips it; the harbour is in place")
	await t.get_tree().create_timer(0.3).timeout
	t.check(arrived[0] == 1 and GameSession.is_moored_in_harbour() and GameSession.get_location_id() == &"kiel",
		"[docking] one arrival, moored in Kiel")
	var arrivals_after := int(GameSession.get_captains_log().visited.get("kiel", {"arrivals": 0}).arrivals)
	t.check(arrivals_after == arrivals_before + 1 and is_equal_approx(GameSession.get_provisions().food_days, stores),
		"[docking] counted once in the log; nothing used up while it played")
	Simulation.arrived.disconnect(count)
	var before := deck.player.position
	await t.hold_actions([&"move_left"], 0.3)
	t.check(deck.player.position.distance_to(before) > 5.0, "[docking] then harbour play resumes (the captain can walk)")
