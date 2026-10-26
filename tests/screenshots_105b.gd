extends Node
## Revision 0.105b rendered evidence not already produced by the focused
## suites (QA-3): an international ordinary anchorage (Antigua), an
## international Magic Anchor anchorage on a deep coast (Madeira), a boat at
## anchor at night, the fallback when a replacement is removed, and the
## validation message for a wrongly shaped replacement. Rendered:
##   xvfb-run godot --path . --rendering-driver opengl3 --resolution 1600x900 \
##     res://tests/screenshots_105b.tscn -- --out=DIR
## Prints "SHOTS105B ok|FAIL <text>" per check; exits 0 when all hold.
## The validation message is the text the game prints to Godot's Output
## panel; this harness shows it on a small overlay so it can be photographed.

const APP_SCENE := preload("res://src/app/app.tscn")
const F := preload("res://tests/helpers/art_fixtures.gd")

var app: Node
var out := ""
var failures := PackedStringArray()


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
	SaveManager.save_dir = "user://test_saves"
	Simulation.auto_advance = false
	WindField.get_default().test_override = func(_geo: Vector2, _time: float) -> WindField.Sample:
		return WindField.Sample.make(200.0, 9.0)
	app = APP_SCENE.instantiate()
	add_child(app)
	app.router.fade_duration = 0.05
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _idle() -> void:
	var guard := 0
	while app.router.is_busy() and guard < 2000:
		guard += 1
		await get_tree().process_frame
	await _frames(6)


func _shot(name: String) -> void:
	await _frames(4)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("SHOTS105B shot %s" % name)


func _check(ok: bool, text: String) -> void:
	print("SHOTS105B %s %s" % ["ok  " if ok else "FAIL", text])
	if not ok:
		failures.append(text)


func _show(area: StringName, heading := 120.0) -> BoatArea:
	app.modals.clear()
	GameSession.enter_boat_area(area, &"start")
	app._show_current_boat_area()
	await _idle()
	var screen := app.router.current_screen as BoatArea
	if area == SessionState.AREA_EXTERIOR:
		screen.view_heading_override = heading
		screen._update_camera()
		await get_tree().create_timer(BoatArea.ZOOM_TRANSITION_S + 0.4).timeout
	var lighting := screen.get_node_or_null("Lighting")
	if lighting:
		lighting.update_now()
	app.toasts.clear()
	app.hud.hide_warning()
	return screen


func _underway_at(geo: Vector2) -> void:
	var state := GameSession.get_state_snapshot()
	var route := PlannedRoute.new()
	route.origin_port_id = &"copenhagen"
	route.origin_position = geo
	route.destination_port_id = &"copenhagen"
	route.path = PackedVector2Array([geo, geo + Vector2(0.0, -0.05)])
	state.voyage = Voyage.create(route, state.game_time)
	state.vessel_status = SessionState.STATUS_UNDERWAY
	state.location_id = &""
	state.vessel_position = geo
	state.planned_route = null
	state.anchor.active = false
	GameSession.replace_state(state)


func _set_time(local_hour: float) -> void:
	var state := GameSession.get_state_snapshot()
	var geo := GameSession.get_vessel_position()
	state.game_time = 1777593600.0 + fposmod(local_hour - geo.x / 15.0, 24.0) * 3600.0
	GameSession.replace_state(state)


## A coastal (not offshore) spot near `centre` where only the Magic Anchor
## reaches the bottom, reachable from open water.
func _magic_coast_spot(centre: Vector2) -> Vector2:
	var calm := WindField.Sample.make(200.0, 9.0)
	var router := SeaRouter.get_default()
	for r in range(1, 30):
		for k in 24:
			var geo := centre + Vector2.from_angle(TAU * k / 24.0) * r * 0.01
			var site := AnchorSite.evaluate(geo, calm, true, false)
			if site.ok and site.kind == AnchorSite.KIND_MAGIC and not site.offshore and router.is_point_reachable(geo):
				return geo
	return Vector2.INF


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(out)
	await _idle()
	app.start_new_game()
	await _idle()
	# 9. An international ordinary anchorage: off Antigua, the normal anchor.
	var spot := GameSession.nearest_anchorage_spot(Vector2(-61.85, 17.0), 6.0)
	_underway_at(spot)
	_set_time(10.0)
	var result := GameSession.drop_anchor(5, 0.85)
	_check(result.error == "" and GameSession.get_anchor().kind == AnchorState.KIND_NORMAL,
		"9: the normal anchor down off Antigua (%s, %s)" % [DepthService.describe_depth(GameSession.get_anchor().depth_m), GameSession.get_anchor().depth_source])
	await _show(SessionState.AREA_EXTERIOR)
	app.open_anchor()
	await _frames(6)
	await _shot("rb_22_international_normal_anchorage_antigua")
	app.modals.clear()
	GameSession.raise_anchor()
	# 10. An international Magic Anchor anchorage on a deep coast (Madeira).
	GameSession.fit_magic_anchor()
	var deep := _magic_coast_spot(Vector2(-16.92, 32.63))
	_check(deep != Vector2.INF, "10: a deep coastal spot off Madeira where only the Magic Anchor reaches (%s)" % deep)
	if deep != Vector2.INF:
		_underway_at(deep)
		_set_time(15.0)
		result = GameSession.drop_magic_anchor(5, 0.9, 1)
		var site: Dictionary = result.site
		_check(result.error == "" and not bool(site.get("offshore", true)) and float(site.depth_m) > AnchorSite.NORMAL_MAX_DEPTH_M,
			"10: the Magic Anchor holds on the steep coast (%s, %.1f nm from land)" % [DepthService.describe_depth(float(site.get("depth_m", 0))), float(site.get("land_nm", 0))])
		await _show(SessionState.AREA_EXTERIOR, 300.0)
		app.open_anchor()
		await _frames(6)
		await _shot("rb_23_international_magic_anchorage_madeira")
		app.modals.clear()
		# 16. At anchor at night (the Magic Anchor's brass, the anchor light).
		_set_time(23.5)
		await _show(SessionState.AREA_EXTERIOR, 300.0)
		_check(GameSession.is_anchored(), "16: still at anchor after nightfall")
		await _shot("rb_24_anchored_at_night")
		GameSession.raise_anchor()
	# 23-24. Replacement removed (fallback) and a wrongly shaped one (message).
	var entry := ArtworkResolver.get_entry(&"equipment.anchor.buoy")
	spot = GameSession.nearest_anchorage_spot(Vector2(10.95, 55.35), 6.0)
	_underway_at(spot)
	_set_time(11.0)
	GameSession.drop_anchor(5, 0.85)
	F.install(entry)
	ArtworkResolver.reload()
	var deck := await _show(SessionState.AREA_EXTERIOR, 90.0)
	_check(deck.get_anchor_signals().uses_buoy_replacement(), "23: (before removal) the replacement buoy is in use")
	F.remove(entry)
	ArtworkResolver.reload()
	deck = await _show(SessionState.AREA_EXTERIOR, 90.0)
	_check(not deck.get_anchor_signals().uses_buoy_replacement(), "23: the PNG removed: the original buoy is drawn again")
	await _shot("rb_25_replacement_removed_fallback")
	F.install(entry, Vector2i(48, 96))
	ArtworkResolver.reload()
	deck = await _show(SessionState.AREA_EXTERIOR, 90.0)
	var warnings := ArtworkResolver.get_warnings()
	_check(not deck.get_anchor_signals().uses_buoy_replacement() and warnings.size() == 1, "24: a wrongly shaped PNG is refused; one warning")
	var layer := CanvasLayer.new()
	layer.layer = 120
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"HudPanel"
	panel.position = Vector2(40, 640)
	var label := Label.new()
	label.text = "Godot Output panel:\nSprite Workshop: %s" % (warnings[0] if warnings.size() > 0 else "")
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(1500, 0)
	panel.add_child(label)
	layer.add_child(panel)
	add_child(layer)
	await _shot("rb_26_incorrect_replacement_message")
	layer.queue_free()
	F.remove(entry)
	ArtworkResolver.reload()
	_check(F.installed_pngs().is_empty(), "nothing left installed")
	print("SHOTS105B %s" % ("PASS" if failures.is_empty() else "FAIL: " + "; ".join(failures)))
	get_tree().quit(0 if failures.is_empty() else 1)
