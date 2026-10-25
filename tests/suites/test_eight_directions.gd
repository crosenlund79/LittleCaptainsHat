extends RefCounted
## Iteration 13: the sailing view in eight directions. The deck is drawn in
## the octant nearest the course (N, NE, E, … NW) with hysteresis, turning
## smoothly between them; the simulation keeps the full heading; the movement
## keys follow the screen; the camera follows the captain along the turned
## boat so nothing they stand on is cropped away; the fixed view setting
## still works.

const APP_SCENE := preload("res://src/app/app.tscn")
const DECK := SessionState.AREA_EXTERIOR
const NAMES := ["north", "north-east", "east", "south-east", "south", "south-west", "west", "north-west"]
## The boats' display names (screenshots) by id.
const BOATS := {&"arctic_wanderer_26": "arctic_wanderer_26", &"starling_33": "wing_33", &"halcyon_40": "clam_40", &"petrel_36": "frogleap_36"}

var t: Node
var app: Node


func run(runner: Node) -> void:
	t = runner
	Simulation.auto_advance = false
	_test_octant_rule()
	app = APP_SCENE.instantiate()
	t.add_child(app)
	app.router.fade_duration = 0.05
	await _settle()
	SettingsManager.set_course_view(true)
	app.start_new_game()
	await _settle()
	await _test_all_octants()
	await _test_keys_follow_the_screen()
	await _test_framing_follows_the_captain()
	await _test_every_boat()
	await _test_fixed_view_setting()
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
	return app.router.current_screen as BoatArea


func _depart() -> void:
	t.set_wind(270.0, 14.0)
	GameSession.plan_route_to(&"kiel")
	GameSession.depart()
	Simulation.advance(600.0)


## Turns the deck to `heading` (presentation only) and waits for the turn.
func _view(deck: BoatArea, heading: float) -> void:
	deck.view_heading_override = heading
	deck._update_camera()
	await t.get_tree().create_timer(BoatArea.ZOOM_TRANSITION_S + 0.4).timeout


## The bow's direction on screen (unit vector, screen y down).
func _bow_on_screen(deck: BoatArea) -> Vector2:
	var canvas := deck.get_viewport().get_canvas_transform()
	return ((canvas * deck.to_global(Vector2(400, 0))) - (canvas * deck.to_global(Vector2.ZERO))).normalized()


func _test_octant_rule() -> void:
	var centres_ok := true
	for k in 8:
		centres_ok = centres_ok and BoatArea.octant_for(k * 45.0) == k and BoatArea.octant_for(k * 45.0 + 10.0) == k \
			and BoatArea.octant_for(k * 45.0 - 10.0) == k
	t.check(centres_ok, "[octants] each of the eight directions owns 45° around it")
	t.check(BoatArea.octant_for(22.4) == 0 and BoatArea.octant_for(22.6) == 1, "[octants] the boundary between N and NE is at 22.5°")
	t.check(BoatArea.octant_for(337.4) == 7 and BoatArea.octant_for(337.6) == 0 and BoatArea.octant_for(-10.0) == 0 and BoatArea.octant_for(719.0) == 0,
		"[octants] around north the octants wrap (337.5°, -10°, 719°)")
	t.check(BoatArea.octant_for(28.0, 0) == 0 and BoatArea.octant_for(30.0, 0) == 0, "[hysteresis] a course drifting to 30° keeps the north view")
	t.check(BoatArea.octant_for(31.0, 0) == 1, "[hysteresis] past 30.5° it turns to north-east")
	t.check(BoatArea.octant_for(16.0, 1) == 1 and BoatArea.octant_for(14.0, 1) == 0, "[hysteresis] and back again only below 14.5°")
	t.check(BoatArea.octant_for(345.0, 0) == 0 and BoatArea.octant_for(328.0, 0) == 7, "[hysteresis] also across north")
	var flips := 0
	var octant := BoatArea.octant_for(22.0)
	for i in 200:
		var wobble := 22.5 + 5.0 * sin(i * 0.7)
		var next := BoatArea.octant_for(wobble, octant)
		flips += 1 if next != octant else 0
		octant = next
	t.check(flips <= 1, "[hysteresis] a course wavering ±5° around a boundary does not flip the view (%d changes)" % flips)


func _test_all_octants() -> void:
	_depart()
	var deck := await _show_deck()
	var camera := deck.get_node("Camera2D") as Camera2D
	var heading := Simulation.get_current_heading()
	t.check(deck.is_course_view() and absf(angle_difference(camera.rotation, deg_to_rad(90.0 - BoatArea.octant_for(heading) * 45.0))) < 0.01,
		"[view] underway the deck shows the course's octant (heading %.1f°)" % heading)
	t.check(not is_equal_approx(fmod(heading, 45.0), 0.0) and is_equal_approx(Simulation.get_current_heading(), heading),
		"[view] the simulation keeps the full heading (%.2f°), only the picture is in eighths" % heading)
	app.toasts.clear()
	app.hud.hide_warning()
	for k in 8:
		# A heading off the octant's centre: the picture still snaps to it.
		var h := k * 45.0 + 12.0
		await _view(deck, h)
		var expected := Vector2.from_angle(deg_to_rad(k * 45.0 - 90.0))
		var bow := _bow_on_screen(deck)
		t.check(deck.get_view_octant() == k and bow.dot(expected) > 0.995 and camera.zoom.x >= BoatArea.COURSE_MIN_ZOOM - 0.001,
			"[view] heading %d°: the bow points %s on screen (zoom %.2f)" % [roundi(h), NAMES[k], camera.zoom.x])
		var screen := deck.get_viewport_rect()
		var at := deck.get_viewport().get_canvas_transform() * deck.to_global(deck.player.position)
		t.check(screen.grow(-20.0).has_point(at), "[view] %s: the captain is on screen (%d, %d)" % [NAMES[k], roundi(at.x), roundi(at.y)])
		await t.screenshot("13_view_%d_%s" % [k * 45, NAMES[k].replace("-", "_")])
	# A smooth turn: halfway through, the camera is between the two octants.
	deck.view_heading_override = 90.0
	deck._update_camera()
	await t.get_tree().create_timer(BoatArea.ZOOM_TRANSITION_S * 0.5).timeout
	var mid := rad_to_deg(angle_difference(deg_to_rad(90.0 - 315.0), camera.rotation))
	t.check(absf(mid) > 10.0 and absf(mid) < 125.0, "[view] turning between octants is a smooth tween (%.0f° on the way)" % mid)
	await t.get_tree().create_timer(BoatArea.ZOOM_TRANSITION_S).timeout
	deck.view_heading_override = NAN


func _test_keys_follow_the_screen() -> void:
	var deck := app.router.current_screen as BoatArea
	for h: float in [45.0, 225.0]:
		await _view(deck, h)
		deck.player.position = deck.get_spawn_position(&"start") + Vector2(-20, 0)
		await t.physics_frames(2)
		var canvas := deck.get_viewport().get_canvas_transform()
		var before := canvas * deck.to_global(deck.player.position)
		await t.hold_actions([&"move_up"], 0.25)
		canvas = deck.get_viewport().get_canvas_transform()
		var after := canvas * deck.to_global(deck.player.position)
		var moved := (after - before).normalized()
		t.check(moved.dot(Vector2.UP) > 0.9, "[keys] heading %d°: W walks up the screen (%.2f, %.2f)" % [roundi(h), moved.x, moved.y])
	deck.view_heading_override = NAN


## A new game aboard `id`, underway, on deck.
func _aboard(id: StringName) -> BoatArea:
	GameSession.end_session()
	app.start_new_game()
	await _settle()
	var state := GameSession.get_state_snapshot()
	state.vessel_id = id
	GameSession.replace_state(state)
	_depart()
	var deck := await _show_deck()
	app.toasts.clear()
	app.hud.hide_warning()
	return deck


## On the large Frogleap 36 sailing north the whole hull does not fit at a
## readable zoom: the camera follows the captain instead.
func _test_framing_follows_the_captain() -> void:
	var deck := await _aboard(&"petrel_36")
	await _view(deck, 0.0)
	var camera := deck.get_node("Camera2D") as Camera2D
	var bounds := deck._boat_view_bounds()
	for end in [bounds.end.x - 60.0, bounds.position.x + 70.0]:
		var spot := Vector2(end, 0.0)
		deck.player.position = spot
		await t.get_tree().create_timer(1.6).timeout
		var at := deck.get_viewport().get_canvas_transform() * deck.to_global(deck.player.position)
		t.check(deck.get_viewport_rect().grow(-40.0).has_point(at),
			"[framing] sailing north, the captain at the %s stays in view (%d, %d)" % ["bow" if end > 0 else "stern", roundi(at.x), roundi(at.y)])
		await t.screenshot("13_view_north_frogleap_at_the_%s" % ("bow" if end > 0 else "stern"))
	var target := deck.get_course_camera_target(camera.zoom, camera.rotation)
	t.check(target.x >= bounds.position.x and target.x <= bounds.end.x, "[framing] the camera never aims past the boat's ends")
	deck.player.position = deck.get_spawn_position(&"start")
	deck.view_heading_override = NAN


func _test_every_boat() -> void:
	for id: StringName in BOATS:
		var deck := await _aboard(id)
		await _view(deck, 45.0)
		t.check(_bow_on_screen(deck).dot(Vector2.from_angle(deg_to_rad(-45.0))) > 0.995, "[boats] %s: drawn north-east like the others" % id)
		await t.screenshot("13_view_ne_%s" % BOATS[id])
		deck.view_heading_override = NAN


func _test_fixed_view_setting() -> void:
	SettingsManager.set_course_view(false)
	var deck := app.router.current_screen as BoatArea
	await t.get_tree().create_timer(BoatArea.ZOOM_TRANSITION_S + 0.3).timeout
	var camera := deck.get_node("Camera2D") as Camera2D
	t.check(not deck.is_course_view() and is_zero_approx(snappedf(camera.rotation, 0.001)), "[setting] Settings → Sailing view: fixed keeps the boat bow-right")
	SettingsManager.set_course_view(true)
	await t.get_tree().create_timer(BoatArea.ZOOM_TRANSITION_S + 0.3).timeout
	t.check(deck.is_course_view() and not is_zero_approx(snappedf(camera.rotation, 0.001)) or deck.get_view_octant() == 2,
		"[setting] and back to the course view")
