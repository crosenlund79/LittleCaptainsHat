extends RefCounted
## Iteration 004b: the Halcyon 40's refined cabin. The visible saloon door to
## the deck, reaching both hulls, berth proportions, art matching collision,
## the nav station, sleeping and waking, and the companion's spots.

const APP_SCENE := preload("res://src/app/app.tscn")
const W := preload("res://tests/helpers/walkability.gd")
const VESSEL := &"halcyon_40"

var t: Node
var app: Node


func run(runner: Node) -> void:
	t = runner
	app = APP_SCENE.instantiate()
	t.add_child(app)
	app.router.fade_duration = 0.05
	await _settle()
	Simulation.auto_advance = false
	app.start_new_game()
	await _settle()
	t.check_eq(GameSession.switch_vessel(VESSEL), "", "(setup) aboard the Halcyon 40")
	await _show(SessionState.AREA_INTERIOR, &"from_deck")

	await _test_door_to_deck()
	await _test_layout()
	await _test_walking()
	await _test_nav_station()
	await _test_sleep()
	await _test_companion_spots()

	Simulation.auto_advance = true
	app.queue_free()
	await t.frames(2)
	GameSession.end_session()


func _cabin() -> BoatArea:
	return app.router.current_screen as BoatArea


func _test_door_to_deck() -> void:
	var cabin := _cabin()
	t.check(cabin != null and cabin.scene_file_path.contains(VESSEL), "[cat cabin] the cabin scene loads")
	var furniture := cabin.get_node("Visual/FurnitureVisual")
	var door := cabin.get_node("Layout/Stations/Companionway") as Interactable
	var parts := ["CockpitBeyond", "SlidingDoor", "DoorStep", "DoorPost0", "DoorPost1", "Chevron0"]
	var missing := parts.filter(func(n: String) -> bool: return furniture.get_node_or_null(n) == null)
	t.check(missing.is_empty(), "[cat cabin] the saloon door to the deck is drawn %s" % (missing if missing else ""))
	var step := furniture.get_node("DoorStep") as Node2D
	t.check(absf(step.position.y - door.position.y) < 1.0 and absf(step.position.x - door.position.x) < 20.0,
		"[cat cabin] the drawn door and step are where the companionway interaction is")
	var doorway := cabin.get_node("Visual/CabinDetails/Labels/Door") as Label
	t.check(doorway.text == "TO DECK" and doorway.visible, "[cat cabin] it is labelled TO DECK")
	# Walking up to it shows the prompt; E leads on deck.
	await _move_player_to(cabin.get_spawn_position(&"from_deck"))
	t.check(cabin.player.get_focused_interactable() == door, "[cat cabin] standing at the door focuses the companionway")
	t.check_eq(app.hud.get_prompt(), "Go on deck", "[cat cabin] the prompt says 'Go on deck'")
	await t.screenshot("50_catamaran_door_prompt")
	await t.press_action(&"interact")
	await _settle()
	var deck := app.router.current_screen as BoatArea
	t.check(deck != null and deck.area_id == SessionState.AREA_EXTERIOR and deck.scene_file_path.contains(VESSEL),
		"[cat cabin] E at the door goes on deck")
	t.check(deck.player.position.distance_to(deck.get_spawn_position(&"from_cabin")) < 1.0, "[cat cabin] arriving by the saloon door on deck")
	await _show(SessionState.AREA_INTERIOR, &"from_deck")


func _test_layout() -> void:
	var cabin := _cabin()
	var collision := cabin.get_node("Layout/Collision")
	var furniture := cabin.get_node("Visual/FurnitureVisual")
	# The art matches the collision exactly (both come from the same layout).
	var mismatched := []
	for fixture in collision.get_children():
		if not fixture is BoatFixture:
			continue
		var art := furniture.get_node_or_null(NodePath(String(fixture.name))) as ProceduralShape
		if art == null or not art.position.is_equal_approx(fixture.position) or art.get_points() != (fixture as BoatFixture).get_points():
			mismatched.append(fixture.name)
	t.check(mismatched.is_empty(), "[cat cabin] every piece of furniture is drawn where its collision is %s" % (mismatched if mismatched else ""))
	# A coherent arrangement: saloon (galley, settee, table, nav desk), owner's
	# hull (berth, wardrobe, desk, ensuite), guest hull (berth, heads, shower, bunk).
	var expected := ["GalleyAft", "GalleySide", "Settee", "SaloonTable", "NavDesk", "OwnerBerth", "Wardrobe", "Desk",
		"Ensuite", "GuestBerth", "Heads", "Shower", "Bunk"]
	var absent := expected.filter(func(n: String) -> bool: return collision.get_node_or_null(n) == null)
	t.check(absent.is_empty(), "[cat cabin] saloon, galley, nav station, owner's cabin, guest cabin and heads are all there %s" % (absent if absent else ""))
	# Berths in proportion: the owner's berth is a real double berth (at least
	# 3.5 player widths long and 2.2 wide), filling the hull's width.
	var owner := collision.get_node("OwnerBerth") as BoatFixture
	var guest := collision.get_node("GuestBerth") as BoatFixture
	var player_width := 2.0 * W.PLAYER_RADIUS
	var owner_size := _size_of(owner)
	var guest_size := _size_of(guest)
	t.check(owner_size.x >= 3.5 * player_width and owner_size.y >= 2.2 * player_width,
		"[cat cabin] the owner's berth is a proper double berth (%d × %d)" % [owner_size.x, owner_size.y])
	t.check(owner_size.y >= 0.9 * 100.0, "[cat cabin] it spans the hull's width (%d of 100)" % owner_size.y)
	t.check(guest_size.x >= 3.0 * player_width and guest_size.y >= 2.2 * player_width,
		"[cat cabin] the guest berth is a double berth too (%d × %d)" % [guest_size.x, guest_size.y])
	t.check(owner_size.x * owner_size.y >= guest_size.x * guest_size.y, "[cat cabin] the owner's berth is the largest")
	t.check((cabin.get_node("Layout/Stations/Berth") as Node2D).position.y < 0.0, "[cat cabin] the sleeping station is in the owner's (port) hull")
	await t.screenshot("51_catamaran_cabin")


func _size_of(fixture: BoatFixture) -> Vector2:
	var points := fixture.get_points()
	var box := Rect2(points[0], Vector2.ZERO)
	for p in points:
		box = box.expand(p)
	return box.size


func _test_walking() -> void:
	var cabin := _cabin()
	var cells := W.walkable_cells(cabin, cabin.get_spawn_position(&"start"))
	t.check(cells.size() > 300, "[cat cabin] the player can move around (%d places)" % cells.size())
	var collision := cabin.get_node("Layout/Collision")
	for place in ["OwnerBerth", "Wardrobe", "Ensuite", "GuestBerth", "Heads", "Shower", "Bunk", "GalleySide", "SaloonTable", "NavDesk"]:
		var fixture := collision.get_node(place) as BoatFixture
		var best := INF
		for c in cells:
			best = minf(best, W.distance_to_fixture(fixture, c) - W.PLAYER_RADIUS)
		t.check(best <= 12.0, "[cat cabin] the player can walk up to the %s (gap %.0f)" % [place, best])
	var port := cells.filter(func(c: Vector2) -> bool: return c.y < -175.0)
	var starboard := cells.filter(func(c: Vector2) -> bool: return c.y > 175.0)
	t.check(port.size() > 100 and starboard.size() > 100, "[cat cabin] both hulls are reachable from the saloon (%d / %d places)" % [port.size(), starboard.size()])
	# Down into each hull and back, really walking (input held).
	for target in [Vector2(-20, -215), Vector2(82, 215)]:
		await _walk_to(target)
		var reached := cabin.player.position.distance_to(target) < 30.0
		t.check(reached, "[cat cabin] walking from the saloon into the %s hull" % ("port" if target.y < 0 else "starboard"))
		await _walk_to(Vector2(-40, 0))
		t.check(cabin.player.position.distance_to(Vector2(-40, 0)) < 30.0, "[cat cabin] and back into the saloon")
	var room := true
	for c in cells:
		room = room and cabin.walkable_bounds.grow(W.PLAYER_RADIUS).has_point(c)
	t.check(room, "[cat cabin] all walkable places are inside the cabin bounds")


## Walks the player to `target` with the movement keys: through the opening
## into a hull when the target or start is in one (x -20 port, 82 starboard).
func _walk_to(target: Vector2) -> void:
	var cabin := _cabin()
	var from := cabin.player.position
	var route: Array[Vector2] = []
	if absf(from.y) > 170.0:
		var x_from := -20.0 if from.y < 0.0 else 82.0
		route.append_array([Vector2(x_from, from.y), Vector2(x_from, 0.0)])
	if absf(target.y) > 170.0:
		var x_to := -20.0 if target.y < 0.0 else 82.0
		route.append_array([Vector2(x_to, 0.0), Vector2(x_to, target.y)])
	route.append(target)
	for waypoint in route:
		for i in 300:
			var delta := waypoint - cabin.player.position
			if delta.length() < 6.0:
				break
			_hold_towards(delta)
			await t.physics_frames(1)
		_release_movement()
	await t.physics_frames(2)


func _hold_towards(delta: Vector2) -> void:
	for pair in [[&"move_right", delta.x > 3.0], [&"move_left", delta.x < -3.0], [&"move_down", delta.y > 3.0], [&"move_up", delta.y < -3.0]]:
		if pair[1]:
			Input.action_press(pair[0])
		else:
			Input.action_release(pair[0])


func _release_movement() -> void:
	for action in [&"move_right", &"move_left", &"move_down", &"move_up"]:
		Input.action_release(action)


func _test_nav_station() -> void:
	var cabin := _cabin()
	t.check(await _use_station(cabin, &"nav_table"), "[cat cabin] the nav station can be used")
	await _settle()
	t.check(app.router.current_screen is WorldMap, "[cat cabin] it opens the chart")
	app.close_chart()
	await _settle()
	t.check(_cabin() != null and _cabin().scene_file_path.contains(VESSEL), "[cat cabin] back in the catamaran's cabin")


func _test_sleep() -> void:
	var cabin := _cabin()
	t.check(await _use_station(cabin, &"bed"), "[cat cabin] the owner's berth offers sleep")
	t.check(app.modals.get_top() is SleepMenu, "[cat cabin] the sleep dialog opens")
	var before := GameSession.get_game_time()
	app.sleep_for(1.0)
	await _settle()
	cabin = _cabin()
	var wake := cabin.get_spawn_position(&"v_berth")
	t.check(is_equal_approx(GameSession.get_game_time() - before, 3600.0) and cabin.player.position.distance_to(wake) < 1.0,
		"[cat cabin] an hour later the player wakes beside the owner's berth")
	var berth := cabin.get_node("Layout/Collision/OwnerBerth") as BoatFixture
	t.check(W.distance_to_fixture(berth, wake) - W.PLAYER_RADIUS < 25.0, "[cat cabin] right next to it")
	var cells := W.walkable_cells(cabin, wake)
	t.check(not cells.is_empty() and W.nearest(cells, cabin.get_spawn_position(&"start")).distance_to(cabin.get_spawn_position(&"start")) <= W.GRID,
		"[cat cabin] the wake-up spot is clear and connected to the saloon")
	await t.screenshot("52_catamaran_woke_at_berth")


func _test_companion_spots() -> void:
	var cabin := _cabin()
	var cells := W.walkable_cells(cabin, cabin.get_spawn_position(&"start"))
	for spot in CompanionState.ALL_SPOT_IDS:
		var at := (cabin.get_node("Layout/CompanionSpots/%s" % spot) as Node2D).position
		var near := W.nearest(cells, at)
		t.check(near.distance_to(at) <= ShipCompanion.INTERACT_RADIUS + 40.0, "[cat cabin] the companion can be petted at '%s'" % spot)
		t.check(cabin.walkable_bounds.has_point(at), "[cat cabin] '%s' is inside the cabin" % spot)


# --- Helpers ------------------------------------------------------------------------

func _use_station(area: BoatArea, interaction_id: StringName) -> bool:
	var station: Interactable = null
	for node: Interactable in area.get_node("Layout/Stations").get_children():
		if node.interaction_id == interaction_id:
			station = node
	if station == null:
		return false
	var cells := W.walkable_cells(area, area.get_spawn_position(&"start"))
	var tries := 0
	for p in W.use_points(station, cells):
		area.player.position = p
		await t.physics_frames(3)
		if area.player.get_focused_interactable() == station:
			await t.press_action(&"interact")
			await t.frames(2)
			return true
		tries += 1
		if tries > 12:
			break
	return false


func _move_player_to(position: Vector2) -> void:
	_cabin().player.position = position
	await t.physics_frames(3)


func _show(area: StringName, spawn: StringName) -> void:
	app.modals.clear()
	GameSession.enter_boat_area(area, spawn)
	app._show_current_boat_area()
	await _settle()


func _settle() -> void:
	await t.frames(2)
	await t.wait_until(func() -> bool: return not app.router.is_busy(), 5.0)
	await t.physics_frames(3)
