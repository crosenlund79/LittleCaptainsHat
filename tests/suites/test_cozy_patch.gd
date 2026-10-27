extends RefCounted
## Quick patch after 0.105b: a cat, some fish and a greener world.
##   - Snøvs can be petted while walking (in, out, across the deck) and just
##     after arriving: the walk pauses for the moment, the reaction plays once,
##     the walk goes on, and she still ends where she was going;
##   - the cabin trophy board shows each trophy's own fish picture (Sprite2D
##     slots; drawn in _draw they came out as white rectangles), empty slots
##     are deliberate recessed frames, saved trophies still show, and a new
##     trophy is recorded once;
##   - the Dreamer's Map has its illustrated colours (green land, snowy north
##     and Antarctica, sandy deserts, deeper sea) and the navigation chart
##     does not.

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
	app.start_new_game()
	await _settle()
	await _test_petting()
	await _test_trophies()
	await _test_dream_map()
	Simulation.auto_advance = true
	app.queue_free()
	await t.frames(2)
	GameSession.end_session()


func _settle() -> void:
	await t.frames(2)
	await t.wait_until(func() -> bool: return not app.router.is_busy(), 5.0)
	await t.physics_frames(3)


func _show(area: StringName) -> BoatArea:
	app.modals.clear()
	GameSession.enter_boat_area(area, &"start")
	app._show_current_boat_area()
	await _settle()
	return app.router.current_screen as BoatArea


## The captain steps next to the companion, faces it and presses E (the real
## sensor path). Returns whether the companion was the one interacted with.
func _pet_by_hand(area: BoatArea, companion: ShipCompanion) -> bool:
	var to_cat := Vector2(-40.0, 0.0)
	area.player.position = companion.position + to_cat
	area.player.set_facing(-to_cat)
	await t.physics_frames(3)
	if area.player.get_focused_interactable() != companion.interactable:
		return false
	area.player._sensor.interact(area.player)
	return true


## Lets the companion finish her walk in simulated time, at 60 steps a
## second, with no frames in between (at most a minute of walking). Waiting
## real frames instead let the game's follow-the-captain timer (a random
## 2.5-5 s) call her back up on deck halfway out, so the result depended on
## the machine's speed.
static func _walk_on(companion: ShipCompanion) -> void:
	for i in 3600:
		if not companion.is_walking():
			return
		companion._process(1.0 / 60.0)

# --- Petting while walking --------------------------------------------------------------------

func _test_petting() -> void:
	if GameSession.get_companion().kind != CompanionState.KIND_CAT:
		var state := GameSession.get_state_snapshot()
		state.companion = CompanionState.create(CompanionState.KIND_CAT, state.game_time)
		GameSession.replace_state(state)
	var deck := await _show(DECK)
	var cat := deck.get_deck_companion()
	if not t.check(cat != null, "(setup) the deck companion exists"):
		return
	var pets := [0]
	cat.petted.connect(func(_k: StringName) -> void: pets[0] += 1)
	# Resting (the cabin): the ordinary case still works.
	GameSession.set_companion_area(CompanionState.AREA_DECK)
	await t.frames(2)
	t.check(cat.is_walking() and cat.interactable.enabled, "[pet] walking onto the deck she can be petted")
	await t.get_tree().create_timer(0.4).timeout
	var ok := await _pet_by_hand(deck, cat)
	t.check(ok and pets[0] == 1 and cat.is_reacting(), "[pet] petted while walking: focused, one reaction (%d)" % pets[0])
	var at := cat.position
	await t.get_tree().create_timer(0.6).timeout
	t.check(cat.is_walking() and cat.position.is_equal_approx(at), "[pet] the walk pauses while she enjoys it")
	await t.get_tree().create_timer(ShipCompanion.REACTION_SECONDS).timeout
	t.check(not cat.position.is_equal_approx(at) or not cat.is_walking(), "[pet] then she walks on")
	_walk_on(cat)
	var spots := deck.get_node("Layout/DeckCompanionSpots") as DeckCompanionSpots
	t.check(not cat.is_walking() and cat.position.distance_to(spots.get_spot(GameSession.get_companion().deck_spot)) < 1.0,
		"[pet] and still arrives at her resting place")
	# Just arrived: pet at once; the reaction is not cut short by settling.
	pets[0] = 0
	ok = await _pet_by_hand(deck, cat)
	t.check(ok and pets[0] == 1 and cat.is_reacting() and cat.pose == CompanionVisualSet.POSE_ALERT,
		"[pet] just arrived: petted, she looks up (once)")
	await t.get_tree().create_timer(ShipCompanion.REACTION_SECONDS + 0.6).timeout
	t.check(pets[0] == 1 and not cat.is_reacting(), "[pet] the reaction plays once and ends")
	# Walking out (following the captain below): still pettable, then gone.
	# The captain stays on deck here, so the game's follow timer would call
	# her back up after a few seconds; it is held still while she walks out.
	app.set_process(false)
	GameSession.set_companion_area(CompanionState.AREA_CABIN)
	await t.frames(2)
	t.check(cat.is_walking() and cat.interactable.enabled, "[pet] on her way out she can still be petted")
	pets[0] = 0
	await t.get_tree().create_timer(0.3).timeout
	ok = await _pet_by_hand(deck, cat)
	t.check(ok and pets[0] == 1, "[pet] petted on the way out")
	_walk_on(cat)
	t.check(not cat.visible and not cat.interactable.enabled and GameSession.get_companion().area == CompanionState.AREA_CABIN,
		"[pet] then she goes below as before (hidden, not pettable on deck)")
	app.set_process(true)


# --- Trophy board -----------------------------------------------------------------------------

func _test_trophies() -> void:
	var state := GameSession.get_state_snapshot()
	state.fishing.trophies.clear()
	var i := 0
	for s in ["cod", "mackerel"]:
		i += 1
		# The shape a 0.105a save stores (no prev_best_kg).
		state.fishing.trophies.append({"uid": 900 + i, "species": s, "kg": 2.0 + i, "caught_at": state.game_time, "where": "Copenhagen", "score": 50.0 - i})
	var errors: Array[String] = []
	var copy := FishingState.from_dict(state.fishing.to_dict(), errors)
	t.check(copy != null and copy.trophies.size() == 2, "[trophy] saved trophies load as they were")
	GameSession.replace_state(state)
	var cabin := await _show(CABIN)
	var board := cabin.get_gear("TrophyBoard") as TrophyBoard
	if not t.check(board != null, "(setup) the trophy board is in the cabin"):
		return
	t.check(board.get_picture(0) == FishArt.thumbnail("cod") and board.get_picture(1) == FishArt.thumbnail("mackerel"),
		"[trophy] each trophy shows its own fish picture (cod, mackerel)")
	t.check(board.get_picture(2) == null and board.get_picture(4) == null, "[trophy] empty slots show no picture (a recessed frame instead)")
	var sprite := board.get_node("Fish0") as Sprite2D
	t.check(sprite.visible and absf(sprite.texture.get_width() * sprite.scale.x - TrophyBoard.PICTURE.x) < 0.5,
		"[trophy] drawn %d units wide on its plaque" % roundi(TrophyBoard.PICTURE.x))
	# A new eligible catch: recorded once, shown at once.
	var count := GameSession.get_fishing().trophies.size()
	var catalog := FishingCatalog.get_default()
	GameSession._pending_bite = {"species": "garfish", "kg": 1.2, "time": GameSession.get_game_time(), "mode": "stationary",
		"lure": "spinner", "kind": String(catalog.kind_of("garfish")), "rarity": catalog.rarity_of("garfish")}
	var result := GameSession.finish_fight(true, false, 0)
	await t.frames(2)
	var trophies := GameSession.get_fishing().trophies
	var garfish := trophies.filter(func(f: Dictionary) -> bool: return f.species == "garfish").size()
	t.check(result.kept and trophies.size() == count + 1 and garfish == 1, "[trophy] a new kept catch becomes one trophy (%d → %d)" % [count, trophies.size()])
	var shown := false
	for slot in FishingState.TROPHY_COUNT:
		shown = shown or board.get_picture(slot) == FishArt.thumbnail("garfish")
	t.check(shown, "[trophy] and its picture appears on the board straight away")
	await t.screenshot("patch_trophy_board")


# --- Dreamer's Map ----------------------------------------------------------------------------

func _test_dream_map() -> void:
	app.modals.clear()
	app.open_dream_map()
	await t.wait_until(func() -> bool: return app.router.current_screen is WorldMap and not app.router.is_busy(), 10.0)
	await t.frames(3)
	var dream := app.router.current_screen as WorldMap
	var view := dream.get_map_view()
	t.check(dream.mode == WorldMap.MODE_DREAM and view.is_dream_style(), "[dream] the Dreamer's Map has its illustrated colours")
	view.reset_view()
	await t.frames(6)
	await t.screenshot("patch_dream_world")
	view.center_on_geo(Vector2(8.0, 50.0), 40.0 / view.units_per_degree)
	await t.frames(6)
	await t.screenshot("patch_dream_europe")
	app.close_chart()
	await _settle()
	app.open_chart()
	await t.wait_until(func() -> bool: return app.router.current_screen is WorldMap and not app.router.is_busy(), 10.0)
	await t.frames(3)
	var chart := app.router.current_screen as WorldMap
	t.check(chart.mode != WorldMap.MODE_DREAM and not chart.get_map_view().is_dream_style(), "[dream] the navigation chart keeps its own colours")
	chart.get_map_view().reset_view()
	await t.frames(6)
	await t.screenshot("patch_nav_chart_world")
	app.close_chart()
	await _settle()
