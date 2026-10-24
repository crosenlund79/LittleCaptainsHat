extends RefCounted
## I005a: the weather model as the player meets it, through the real
## application: the chart overlay (the model's own outlines, no legacy
## circles), the Weather tab and its legend, the HUD, weather sounds, and a
## sleep woken by a storm that forms on the course.

const APP_SCENE := preload("res://src/app/app.tscn")

var t: Node
var app: Node
var copenhagen := Vector2.ZERO


func run(runner: Node) -> void:
	t = runner
	app = APP_SCENE.instantiate()
	t.add_child(app)
	app.router.fade_duration = 0.05
	await _settle()
	Simulation.auto_advance = false
	app.start_new_game()
	await _settle()
	copenhagen = PortCatalog.get_default().get_port(&"copenhagen").get_geo_position()

	await _test_chart_overlay()
	await _test_weather_tab()
	await _test_hud_and_audio()
	await _test_sleep_woken_by_storm()

	WeatherFixtures.clear()
	GameSession.set_paused(false)
	Simulation.auto_advance = true
	app.queue_free()
	await t.frames(2)
	GameSession.end_session()
	t.use_calm_wind()


func _course_point(nm_ahead: float) -> Vector2:
	var path := GameSession.get_planned_route().path if not GameSession.is_underway() else GameSession.get_voyage().route.path
	var from_nm := GameSession.get_voyage_progress_nm() if GameSession.is_underway() else 0.0
	return GeoMath.point_along(path, GeoMath.cumulative_distances(path), from_nm + nm_ahead)


func _use_scene_weather() -> void:
	var now := GameSession.get_game_time()
	WeatherFixtures.use([
		WeatherFixtures.gale("ui_gale", _course_point(25.0), 11.0, 38.0, now - 3600.0, 24.0 * 365.0, 70.0, 0.0, 250.0, true),
		WeatherFixtures.thunder_risk("ui_risk", Vector2(13.4, 55.15), 28.0, now - 3600.0, 24.0 * 365.0),
		WeatherFixtures.thunderstorm("ui_storm", Vector2(13.3, 55.2), 7.0, 22.0, 20.0, now - 3600.0, 4.0, 90.0, 8.0),
	])


# --- Chart overlay ---------------------------------------------------------------------------

func _test_chart_overlay() -> void:
	GameSession.plan_route_to(&"kiel")
	_use_scene_weather()
	app.open_chart()
	await _settle()
	var map := app.router.current_screen as WorldMap
	if not t.check(map != null, "(setup) the chart is open"):
		return
	var view := map.get_map_view()
	view.center_on_geo(Vector2(12.6, 55.2), 2.5)
	await t.frames(3)
	var now := GameSession.get_game_time()
	t.check(view.weather_time == floorf(now / MapView.WEATHER_REFRESH_SECONDS) * MapView.WEATHER_REFRESH_SECONDS,
		"[overlay] the chart shows the weather at the current game time (5-minute steps)")
	var shapes := view.get_weather_shapes()
	var ids := {}
	for shape in shapes:
		ids[String(shape.event.id)] = shape
	t.check(ids.has("ui_gale") and ids.has("ui_risk") and ids.has("ui_storm") and shapes.size() == 3,
		"[overlay] exactly the model's active events are drawn (%s)" % ", ".join(ids.keys()))
	var same_outline := true
	for shape in shapes:
		var event: WeatherEvent = shape.event
		var outline := event.outline(view.weather_time)
		same_outline = same_outline and outline.size() == shape.outline.size() \
			and shape.outline[0].distance_to(view.projection.geo_to_map(outline[0])) < 0.01
	t.check(same_outline, "[overlay] each area is drawn with its event's real outline, not a circle")
	var gale_outline: PackedVector2Array = ids.ui_gale.outline if ids.has("ui_gale") else PackedVector2Array()
	var radii := PackedFloat32Array()
	for p in gale_outline:
		radii.append(p.distance_to(ids.ui_gale.center))
	t.check(radii.size() > 8 and _spread(radii) > 0.15, "[overlay] the gale area is irregular (radius spread %.2f)" % _spread(radii))
	t.check(ids.has("ui_gale") and ids.ui_gale.label == "GALE" and ids.has("ui_storm") and ids.ui_storm.label in ["THUNDERSTORM", "SEVERE SQUALLS"],
		"[overlay] areas are labelled by kind, not only coloured")
	t.check(ids.has("ui_gale") and ids.ui_gale.has("core") and ids.has("ui_risk") and not ids.ui_risk.has("core"),
		"[overlay] the gale shows its core; the risk area has none")
	await t.screenshot("61_weather_chart_copenhagen")

	# Pan and zoom do not change what is drawn (shapes are in map space).
	var before: Vector2 = ids.ui_storm.center if ids.has("ui_storm") else Vector2.ZERO
	view.zoom_by(1.6)
	view.center_on_geo(Vector2(13.0, 55.0))
	await t.frames(3)
	var after_pan := view.get_weather_shapes()
	t.check(after_pan.size() == 3 and _shape(after_pan, "ui_storm").center.distance_to(before) < 0.01,
		"[overlay] panning and zooming keep the same weather shapes")

	# Paused with the chart open: no time passes and the weather stands still.
	GameSession.set_paused(true)
	var paused_time := GameSession.get_game_time()
	Simulation.auto_advance = true
	await t.frames(30)
	Simulation.auto_advance = false
	t.check(GameSession.get_game_time() == paused_time and _shape(view.get_weather_shapes(), "ui_storm").center.distance_to(before) < 0.01,
		"[overlay] paused with the chart open, the clock and the storms stand still")
	GameSession.set_paused(false)

	# The storm moves with time; the overlay follows at its refresh step.
	Simulation.advance(3600.0)
	await t.frames(3)
	var moved := _shape(view.get_weather_shapes(), "ui_storm")
	t.check(not moved.is_empty() and moved.center.distance_to(before) > 0.5,
		"[overlay] an hour later the thunderstorm has moved east on the chart")
	Simulation.advance(MapView.WEATHER_REFRESH_SECONDS)
	await t.frames(3)
	t.check(view.weather_time == floorf(GameSession.get_game_time() / MapView.WEATHER_REFRESH_SECONDS) * MapView.WEATHER_REFRESH_SECONDS
		and _shape(view.get_weather_shapes(), "ui_storm").center.distance_to(moved.center) > 0.01,
		"[overlay] the overlay follows every 5 game minutes")


func _shape(shapes: Array[Dictionary], id: String) -> Dictionary:
	for shape in shapes:
		if String(shape.event.id) == id:
			return shape
	return {}


func _spread(values: PackedFloat32Array) -> float:
	if values.is_empty():
		return 0.0
	var low := values[0]
	var high := values[0]
	for v in values:
		low = minf(low, v)
		high = maxf(high, v)
	return (high - low) / maxf(high, 0.001)


# --- Weather tab ------------------------------------------------------------------------------

func _test_weather_tab() -> void:
	var map := app.router.current_screen as WorldMap
	if map == null:
		return
	map.show_tab(WorldMap.TAB_WEATHER)
	map._refresh()
	await t.frames(3)
	var tabs := map.find_child("Tabs", true, false) as TabContainer
	var count := map.get_route_hazards().size()
	t.check(count >= 1 and tabs.get_tab_title(WorldMap.TAB_WEATHER) == "Weather (%d)" % count,
		"[tab] the tab title counts the hazards on the course (%s)" % tabs.get_tab_title(WorldMap.TAB_WEATHER))
	var weather := (map.find_child("WeatherLabel", true, false) as Label).text
	t.check(weather.contains("Gale") and weather.contains("dangerous") and weather.contains("nm ahead"),
		"[tab] the gale on the course is listed with its hazard level and distance")
	t.check(weather.contains("Thunderstorms may form") and not weather.contains("Wind to 0 kn"),
		"[tab] the thunderstorm-risk area is described as a risk, not as wind")
	var legend := map.find_child("WeatherLegend", true, false) as WeatherLegend
	t.check(legend != null and legend.is_visible_in_tree() and legend.size.y >= WeatherLegend.ROW * 4.0,
		"[tab] the legend explains all four kinds of weather")
	var styles := {}
	for kind in WeatherLegend.KINDS:
		styles["%s|%s|%s" % [WeatherStyle.style(kind).outline, WeatherStyle.style(kind).core, WeatherStyle.style(kind).label]] = true
	t.check(styles.size() == 4 and WeatherStyle.style(WeatherEvent.KIND_THUNDER_RISK).outline == "dashed",
		"[tab] each kind has its own label, glyph and outline style, not only a colour")
	await t.screenshot("62_weather_tab")
	map.show_tab(WorldMap.TAB_COURSE)


# --- HUD and sound -----------------------------------------------------------------------------

func _test_hud_and_audio() -> void:
	app.close_chart()
	await _settle()
	var now := GameSession.get_game_time()
	WeatherFixtures.use([WeatherFixtures.gale("ui_gale_here", copenhagen, 20.0, 40.0, now - 3600.0, 24.0 * 365.0)])
	var here := Simulation.get_weather_at_vessel()
	app.hud.refresh()
	await t.frames(2)
	var text := (app.hud.find_child("WindLabel", true, false) as Label).text
	t.check(text.contains("Gale") and text.contains("gusts"), "[hud] in a gale the HUD shows the wind, the gusts and 'Gale' (%s)" % text)
	t.check(here.hazard >= WeatherModel.HAZARD_DANGEROUS and here.gust_kn > here.speed_kn, "[hud] the gale is dangerous here, with gusts above the wind")
	await t.screenshot("63_hud_gale")

	app.update_weather_audio()
	t.check(app.is_storm_audio_playing(), "[audio] the storm-wind loop plays aboard in a gale")
	WeatherFixtures.use([])
	app.update_weather_audio()
	t.check(not app.is_storm_audio_playing(), "[audio] and fades out when the wind drops")
	app.show_main_menu()
	await _settle()
	app.update_weather_audio()
	t.check(not app.is_storm_audio_playing(), "[audio] no storm sound in the main menu")
	app.start_new_game()
	await _settle()


# --- Sleep woken by a forming storm -------------------------------------------------------------

func _test_sleep_woken_by_storm() -> void:
	if not GameSession.is_active():
		app.start_new_game()
		await _settle()
	WeatherFixtures.use([])
	GameSession.plan_route_to(&"kiel")
	GameSession.depart()
	await _settle()
	var start := GameSession.get_game_time()
	# A thunderstorm forms an hour from now on the course 20 nm ahead.
	WeatherFixtures.use([WeatherFixtures.thunderstorm("ui_forming", _course_point(20.0), 9.0, 28.0, 18.0,
		start + 3600.0, 6.0, 0.0, 0.0)])
	GameSession.set_paused(true)
	app.sleep_for(12.0)
	await _settle()
	var slept := GameSession.get_game_time() - start
	t.check(slept >= 3600.0 and slept < 12.0 * 3600.0, "[sleep] a storm forming on the course wakes the sleeper (after %.1f h)" % (slept / 3600.0))
	t.check(_toast_contains("woken") and _toast_contains("weather warning"), "[sleep] the reason is given")
	t.check(_toast_contains("Thunderstorm") or _toast_contains("Squalls") or _toast_contains("squalls"), "[sleep] the warning names the thunderstorm")
	t.check(app.hud.is_warning_visible(), "[sleep] the warning stays in the HUD")
	var area := app.router.current_screen as BoatArea
	t.check(area != null and area.area_id == SessionState.AREA_INTERIOR, "[sleep] the player wakes in the cabin")
	var voyage := GameSession.get_voyage()
	var expected := GeoMath.point_along(voyage.route.path, GeoMath.cumulative_distances(voyage.route.path), voyage.progress_nm)
	t.check(GameSession.get_vessel_position().distance_to(expected) < 1e-3, "[sleep] the boat is where the voyage says")
	t.check(GameSession.is_paused() and _toast_contains("still paused"), "[sleep] the pause stays as it was")
	var stopped := GameSession.get_game_time()
	app.sleep_for(1.0)
	await _settle()
	t.check(GameSession.get_game_time() - stopped >= 3599.0, "[sleep] the same warning does not wake the sleeper again")
	GameSession.set_paused(false)
	app.hud.hide_warning()


func _settle() -> void:
	await t.frames(2)
	await t.wait_until(func() -> bool: return not app.router.is_busy(), 5.0)
	await t.physics_frames(3)


func _toast_contains(text: String) -> bool:
	for message in app.toasts.get_messages():
		if text in message:
			return true
	return false
