extends Node
## Iteration 18 visual evidence (assignment section 27): renders the fishing
## scenes, the fish art, posed animation frames and a real animation strip,
## the kept catch, the trophies, the preferences and a dragged anchorage
## waypoint, into --out=DIR. (The anchoring, pet, lighting, sail trim, wind
## and route screenshots come from their suites: test_companion_deck,
## test_lighting, test_sail_trim, test_anchorage, test_wind_overlay,
## test_route_wrap.)
##   xvfb-run godot --path . --rendering-driver opengl3 --resolution 1600x900 \
##     res://tests/screenshots_18.tscn -- --out=DIR
## Uses the test save folder; never touches the player's saves.

const APP_SCENE := preload("res://src/app/app.tscn")
const Reel := preload("res://tests/helpers/reel.gd")
const SPECIES := ["herring", "mackerel", "flatfish", "cod", "perch", "garfish", "gilthead_bream", "sea_trout",
	"sea_bass", "bonito", "mahi_mahi", "skipjack", "snapper", "yellowfin", "blue_shark", "blacktip_reef_shark",
	"old_boot", "tangled_rope", "rusty_tin"]
var app: Node
var out := ""
var catalog: FishingCatalog


func _ready() -> void:
	SaveManager.save_dir = "user://test_saves"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(file_name: String) -> void:
	app.toasts.clear()
	await _frames(3)
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, file_name])
	print("SHOT %s" % file_name)


func _bite(species: String, kg: float) -> FishingMenu:
	GameSession.expire_bite()
	GameSession._pending_bite = {"species": species, "kg": kg, "time": GameSession.get_game_time(), "mode": "stationary",
		"lure": "spinner", "kind": String(catalog.kind_of(species)), "rarity": catalog.rarity_of(species)}
	app.modals.clear()
	var menu: FishingMenu = app.open_fishing()
	await _frames(4)
	return menu


## Moves the needle `degrees` past the target's middle, past the debounce.
func _needle(menu: FishingMenu, degrees: float) -> void:
	var reel := menu.get_reel()
	menu.step_reel(ReelTiming.DEBOUNCE + 0.01)
	reel.angle = fposmod(reel.target_deg + degrees, 360.0)


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(out)
	catalog = FishingCatalog.get_default()
	Simulation.auto_advance = false
	WindField.get_default().test_override = func(_geo: Vector2, _time: float) -> WindField.Sample:
		return WindField.Sample.make(200.0, 8.0)
	app = APP_SCENE.instantiate()
	add_child(app)
	await _frames(10)
	app.start_new_game()
	await _frames(10)
	app.modals.clear()
	GameSession.enter_boat_area(SessionState.AREA_EXTERIOR, &"start")
	app._show_current_boat_area()
	await _frames(20)
	await _reel_scenes()
	await _result_scenes()
	await _art_scenes()
	await _anchorage_drag()
	get_tree().quit()


func _reel_scenes() -> void:
	# 1: a common fish on the dial (one success needed).
	var menu := await _bite("herring", 0.25)
	_needle(menu, 70.0)
	await _shot("01_reel_common_fish")
	menu.let_go()
	# 2-4: a rare fish (three successes); a Perfect, then a miss.
	menu = await _bite("sea_trout", 4.8)
	_needle(menu, -55.0)
	await _shot("02_reel_rare_fish")
	_needle(menu, 0.0)
	menu.press_reel()
	await _frames(1)
	await _shot("03_reel_perfect_timing")
	_needle(menu, 180.0)
	menu.press_reel()
	await _frames(1)
	await _shot("04_reel_missed_timing")
	menu.let_go()


func _result_scenes() -> void:
	GameSession.set_keep_preferences("uncommon", FishingCatalog.GRADE_SILVER)
	# 15: a kept catch with weight and grade.
	var menu := await _bite("cod", 9.0)
	Reel.land(menu)
	await _shot("15_catch_result_weight_grade")
	# 16: let go by the preferences.
	menu = await _bite("herring", 0.2)
	Reel.land(menu)
	await _shot("16_automatic_release_by_preferences")
	# 17: kept, then released by hand.
	menu = await _bite("sea_bass", 3.4)
	Reel.land(menu)
	(menu.find_child("ReleaseCatch", true, false) as Button).pressed.emit()
	await _shot("17_manual_release")
	# A shark: always released.
	menu = await _bite("blue_shark", 62.0)
	Reel.land(menu)
	await _shot("09b_shark_landed_and_released")
	# 18 and 20: the rod with the cool box and the preferences.
	menu = await _bite("mackerel", 0.9)
	Reel.land(menu)
	menu = await _bite("garfish", 1.1)
	Reel.land(menu)
	(menu.find_child("BackToRod", true, false) as Button).pressed.emit()
	await _shot("18_kept_catch_inventory")
	(menu.find_child("KeepRarity", true, false) as OptionButton).show_popup()
	await _shot("20_fishing_preferences")
	app.modals.clear()
	await _frames(2)
	# 19: the trophies.
	app.open_trophies()
	await _frames(4)
	await _shot("19_trophy_presentation")
	app.modals.clear()


## A plain stage for the fish art: a dark sea-blue backdrop, the fish large.
func _stage() -> Array:
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	var back := ColorRect.new()
	back.color = Color("#17323d")
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(back)
	var portrait := FishPortrait.new()
	portrait.animated = false
	portrait.position = Vector2(360, 230)
	portrait.size = Vector2(1200, 560)
	portrait.custom_minimum_size = portrait.size
	layer.add_child(portrait)
	var label := Label.new()
	label.position = Vector2(360, 120)
	label.add_theme_font_size_override(&"font_size", 48)
	layer.add_child(label)
	return [layer, portrait, label]


func _art_scenes() -> void:
	var stage := _stage()
	var layer: CanvasLayer = stage[0]
	var portrait: FishPortrait = stage[1]
	var label: Label = stage[2]
	var named := {"cod": "05_illustrated_cod", "mackerel": "06_illustrated_mackerel", "garfish": "07_illustrated_garfish",
		"flatfish": "08_illustrated_flatfish", "blue_shark": "09_illustrated_shark", "old_boot": "10_junk_catch_artwork"}
	for id: String in named:
		portrait.set_species(id)
		label.text = catalog.get_species_name(id)
		await _frames(2)
		portrait.pose_tail(0.0)
		await _shot(named[id])
	# 11-14: posed (the cod).
	portrait.set_species("cod")
	label.text = "Cod: eyes open, tail neutral"
	await _frames(2)
	portrait.pose_tail(0.0)
	await _shot("11_fish_eyes_open")
	await _shot("13_tail_neutral")
	label.text = "Cod: blinking"
	portrait.force_blink()
	await _shot("12_fish_eyes_closed")
	portrait.advance(FishPortrait.BLINK_SECONDS + 0.01)
	label.text = "Cod: tail flick"
	portrait.pose_tail(FishPortrait.FLICK_DEG)
	await _shot("14_tail_flick_pose")
	# The real animation, not posed: 48 frames, 0.15 s apart, as the game runs
	# it (the portrait's own clock), cut from the screen into one strip.
	portrait.set_species("mackerel")
	label.text = "Mackerel: 48 frames, 0.15 s apart"
	portrait.animated = false
	await _frames(2)
	var region := Rect2i(Vector2i(360, 230), Vector2i(1200, 560))
	var scale := Vector2(get_viewport().get_texture().get_image().get_size()) / get_viewport().get_visible_rect().size
	region = Rect2i(Vector2i(Vector2(region.position) * scale), Vector2i(Vector2(region.size) * scale))
	var cell := Vector2i(region.size / 3)
	var strip := Image.create(cell.x * 8, cell.y * 6, false, Image.FORMAT_RGBA8)
	var blinks := 0
	var flicks := 0
	for i in 48:
		portrait.advance(0.15)
		await _frames(1)
		blinks += int(portrait.is_eye_closed())
		flicks += int(absf(portrait.get_tail_degrees()) > 1.0)
		var frame := get_viewport().get_texture().get_image().get_region(region)
		frame.resize(cell.x, cell.y)
		strip.blit_rect(frame, Rect2i(Vector2i.ZERO, cell), Vector2i((i % 8) * cell.x, int(i / 8.0) * cell.y))
	strip.save_png("%s/fish_animation_frames_mackerel.png" % out)
	print("SHOT fish_animation_frames_mackerel (frames with the eye closed %d, with the tail turned %d)" % [blinks, flicks])
	# The whole set: every species and junk item.
	layer.queue_free()
	await _frames(2)
	await _art_sheet()


func _art_sheet() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	var back := ColorRect.new()
	back.color = Color("#17323d")
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(back)
	var grid := GridContainer.new()
	grid.columns = 5
	grid.position = Vector2(30, 20)
	grid.add_theme_constant_override(&"h_separation", 12)
	grid.add_theme_constant_override(&"v_separation", 4)
	layer.add_child(grid)
	for id: String in SPECIES:
		var box := VBoxContainer.new()
		var portrait := FishPortrait.new()
		portrait.animated = false
		portrait.custom_minimum_size = Vector2(360, 190)
		box.add_child(portrait)
		var caption := Label.new()
		caption.text = "%s · %s" % [catalog.get_species_name(id), FishingCatalog.rarity_label(catalog.rarity_of(id)) if catalog.kind_of(id) != FishingCatalog.KIND_JUNK else "junk"]
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(caption)
		grid.add_child(box)
		portrait.set_species(id)
	await _frames(4)
	await _shot("fish_art_sheet_all_species")
	layer.queue_free()
	await _frames(2)


func _anchorage_drag() -> void:
	app.modals.clear()
	app.open_chart()
	for i in 300:
		if app.router.current_screen is WorldMap and not app.router.is_busy():
			break
		await get_tree().process_frame
	var world := app.router.current_screen as WorldMap
	world.set_wind_shown(false)
	world.plot_course_to(&"gothenburg")
	await _frames(2)
	var path := world.get_draft_route().path
	var offshore := Vector2.INF
	for i in range(path.size() - 1):
		for f in [0.25, 0.5, 0.75]:
			var p: Vector2 = path[i].lerp(path[i + 1], f)
			if offshore == Vector2.INF and SeaRouter.get_default().is_point_navigable(p) and float(GameSession.anchorage_spot(p).land_nm) > AnchorSite.MAX_LAND_NM:
				offshore = p
	var index := world.insert_waypoint(world.get_draft_legs().size() - 1, offshore)
	world.toggle_anchorage(index)
	world.use_anchorage_suggestion()
	await _frames(2)
	var spot: Vector2 = world.get_draft_waypoints()[index]
	var map := world.get_map_view()
	map.center_on_geo(spot, 600.0 / map.units_per_degree)
	await _frames(4)
	await _shot("23_anchorage_waypoint_icon")
	# Mid-drag to another good spot nearby: the marker follows the pointer;
	# the legs follow (throttled).
	var moved := spot
	for offset: Vector2 in [Vector2(-0.06, 0.03), Vector2(0.0, 0.06), Vector2(-0.06, -0.03), Vector2(0.0, -0.06), Vector2(0.06, 0.0)]:
		if moved == spot and GameSession.anchorage_spot(spot + offset).ok:
			moved = spot + offset
	map.waypoint_dragged.emit(index, moved)
	await _frames(20)
	await _shot("24_dragging_anchorage_waypoint")
	# Dragged onto land: the chart says so and the course is blocked.
	map.waypoint_dragged.emit(index, spot + Vector2(0.18, 0.08))
	await _frames(20)
	await _shot("24b_anchorage_dragged_onto_land_refused")
