extends RefCounted
## Revision 0.105b (§14A B): decorative solar panels on all four boats.
##   - every deck has them, sized for the boat (one small panel on the Arctic
##     Wanderer 26, a pair on the Wing 33 and Frogleap 36, three on the Clam 40);
##   - part of the boat's art: they turn with it (two headings), and show
##     moored, underway and at anchor, and in the boatyard preview;
##   - aft of the walkable deck: no walkable cell, station or Snøvs resting
##     spot is under them; collisions unchanged (no physics node);
##   - visual only: no processing, nothing in the save, no equipment entry;
##   - drawn by the Sprite Workshop replacement when there is one (READY id
##     boat.shared.solar_panel), procedurally otherwise.

const APP_SCENE := preload("res://src/app/app.tscn")
const DECK := SessionState.AREA_EXTERIOR
## Boat id -> (display name for screenshots, panels expected).
const BOATS := {
	&"arctic_wanderer_26": ["arctic_wanderer_26", 1],
	&"starling_33": ["wing_33", 2],
	&"petrel_36": ["frogleap_36", 2],
	&"halcyon_40": ["clam_40", 3],
}

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
	var areas := {}
	for id: StringName in BOATS:
		areas[id] = await _test_boat(id)
	t.check(areas[&"arctic_wanderer_26"] < areas[&"starling_33"] and areas[&"starling_33"] < areas[&"halcyon_40"],
		"[solar] sized for the boat: the 26-footer has the least panel (%d / %d / %d / %d units²)" % [
			roundi(areas[&"arctic_wanderer_26"]), roundi(areas[&"starling_33"]), roundi(areas[&"petrel_36"]), roundi(areas[&"halcyon_40"])])
	await _test_moored_and_preview()
	await _test_anchored()
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


func _show_deck() -> BoatArea:
	app.modals.clear()
	GameSession.enter_boat_area(DECK, &"start")
	app._show_current_boat_area()
	await _settle()
	app.toasts.clear()
	app.hud.hide_warning()
	return app.router.current_screen as BoatArea


## A new game aboard `id` (in Copenhagen; underway towards Kiel if `sail`).
func _aboard(id: StringName, sail := true) -> BoatArea:
	GameSession.end_session()
	app.start_new_game()
	await _settle()
	var state := GameSession.get_state_snapshot()
	state.vessel_id = id
	GameSession.replace_state(state)
	if sail:
		t.set_wind(270.0, 14.0)
		GameSession.plan_route_to(&"kiel")
		GameSession.depart()
		Simulation.advance(600.0)
	return await _show_deck()


func _view(deck: BoatArea, heading: float) -> void:
	deck.view_heading_override = heading
	deck._update_camera()
	await t.get_tree().create_timer(BoatArea.ZOOM_TRANSITION_S + 0.4).timeout


## The panels' rectangles in the deck area's own coordinates.
func _panel_rects(deck: BoatArea, panels: SolarPanels) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	for rect in panels.get_panels():
		var a := deck.to_local(panels.to_global(rect.position))
		var b := deck.to_local(panels.to_global(rect.end))
		rects.append(Rect2(a, Vector2.ZERO).expand(b))
	return rects


func _test_boat(id: StringName) -> float:
	var deck := await _aboard(id)
	var visual := deck.get_node("Visual") as VesselVisual
	var panels := visual.get_solar_panels()
	var name: String = BOATS[id][0]
	if not t.check(panels != null and panels.visible, "[solar] %s: solar panels on deck" % name):
		return 0.0
	t.check_eq(panels.get_panels().size(), int(BOATS[id][1]), "[solar] %s: %d panel(s)" % [name, int(BOATS[id][1])])
	var rects := _panel_rects(deck, panels)
	var area := 0.0
	for r in rects:
		area += r.get_area()
	# Not in anyone's way: no walkable cell, station or resting spot under a panel.
	var cells := TestWalkability.walkable_cells(deck, deck.get_spawn_position(&"start"))
	var blocked := 0
	for c in cells:
		for r in rects:
			if r.has_point(c):
				blocked += 1
	t.check(cells.size() > 50 and blocked == 0, "[solar] %s: aft of the walkable deck (%d walkable cells, none under a panel)" % [name, cells.size()])
	var stations_clear := true
	for station in deck.get_node("Layout/Stations").get_children():
		for r in rects:
			if r.grow(10.0).has_point((station as Node2D).position):
				stations_clear = false
	var spots := deck.get_node_or_null("Layout/DeckCompanionSpots") as DeckCompanionSpots
	var spots_clear := true
	if spots:
		for p in spots.compute_spots():
			for r in rects:
				if r.grow(14.0).has_point(p):
					spots_clear = false
	t.check(stations_clear and spots_clear, "[solar] %s: clear of the helm, every station and Snøvs's resting spots" % name)
	t.check(panels.find_children("*", "CollisionObject2D", true, false).is_empty() and panels.find_children("*", "CollisionShape2D", true, false).is_empty(),
		"[solar] %s: no collision of their own (walkability and physics unchanged)" % name)
	t.check(panels.z_index == 0 and panels.z_as_relative and deck.player.z_index >= 0,
		"[solar] %s: drawn with the boat's art, under the Captain" % name)
	# Two headings: the panels stay at the stern, turning with the boat.
	var aft_ok := true
	for heading: float in [45.0, 200.0]:
		await _view(deck, heading)
		var canvas := deck.get_viewport().get_canvas_transform()
		var centre := canvas * deck.to_global(Vector2.ZERO)
		var bow := ((canvas * deck.to_global(Vector2(400, 0))) - centre).normalized()
		var rects_now := _panel_rects(deck, panels)
		for r in rects_now:
			var on_screen := (canvas * deck.to_global(r.get_center())) - centre
			aft_ok = aft_ok and on_screen.normalized().dot(bow) < -0.9
		aft_ok = aft_ok and rects_now == rects
		if heading == 45.0 or id in [&"arctic_wanderer_26", &"halcyon_40"]:
			await t.screenshot("rb_13_solar_%s_heading_%03d" % [name, roundi(heading)])
	t.check(aft_ok, "[solar] %s: attached at the stern through heading changes (45° and 200°)" % name)
	t.check(not panels.is_processing() and not panels.is_physics_processing(), "[solar] %s: nothing simulated (no per-frame work)" % name)
	deck.view_heading_override = NAN
	return area


func _test_moored_and_preview() -> void:
	var deck := await _aboard(&"starling_33", false)
	var panels := (deck.get_node("Visual") as VesselVisual).get_solar_panels()
	t.check(panels != null and panels.visible and GameSession.is_moored_in_harbour(), "[solar] moored in harbour, the panels are there")
	await t.screenshot("rb_14_solar_wing_33_moored")
	# Visual only: nothing in the save, no equipment entry, no power.
	var saved := JSON.stringify(GameSession.get_state_snapshot().to_dict()).to_lower()
	t.check(not saved.contains("solar") and not saved.contains("battery") and not saved.contains("charging"),
		"[solar] nothing about solar power, batteries or charging in the save")
	t.check(BoatCare.get_upgrades().all(func(u: Dictionary) -> bool: return not String(u.id).contains("solar")), "[solar] not an equipment item to buy or fit")
	app.open_boatyard()
	await t.frames(4)
	var menu := app.modals.get_top() as BoatyardMenu
	var preview := menu.get_preview_root() if menu else null
	t.check(preview != null and preview.find_children("SolarPanels", "SolarPanels", true, false).size() == 1, "[solar] the boatyard preview shows them too")
	app.modals.clear()


func _test_anchored() -> void:
	var deck := await _aboard(&"arctic_wanderer_26", false)
	var spot := GameSession.nearest_anchorage_spot(Vector2(10.95, 55.35), 6.0)
	var state := GameSession.get_state_snapshot()
	var route := PlannedRoute.new()
	route.origin_port_id = &"copenhagen"
	route.origin_position = spot
	route.destination_port_id = &"copenhagen"
	route.path = PackedVector2Array([spot, spot + Vector2(0.0, -0.05)])
	state.voyage = Voyage.create(route, state.game_time)
	state.vessel_status = SessionState.STATUS_UNDERWAY
	state.location_id = &""
	state.vessel_position = spot
	state.planned_route = null
	GameSession.replace_state(state)
	t.set_wind(200.0, 8.0)
	t.check(GameSession.drop_anchor(5, 0.9).error == "", "(setup) at anchor off Nyborg")
	deck = await _show_deck()
	await _view(deck, 120.0)
	var panels := (deck.get_node("Visual") as VesselVisual).get_solar_panels()
	t.check(panels != null and panels.visible and deck.get_anchor_signals().visible, "[solar] at anchor: panels, ball and rode together")
	await t.screenshot("rb_15_solar_arctic_wanderer_26_anchored")
	deck.view_heading_override = NAN
	GameSession.raise_anchor()
