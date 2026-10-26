extends RefCounted
## Iteration 17 (MAP): the world chart never leaves a gap where land is in
## view. I016 baked wrap copies only for land within 40° of ±180°, so a
## whole-world view (~315° wide) panned toward Australia or the Pacific
## showed rectangular bands without land. Now each world layer is drawn in
## three copies; this suite sweeps the camera across the globe (several full
## turns, both ways, world and regional zoom) and checks that every on-screen
## copy of known land has a visible land tile under it, that geographic
## positions round-trip, and that harbours can still be picked.

const APP_SCENE := preload("res://src/app/app.tscn")
## Inland points of land that must always be drawn where they appear on screen.
const LAND := {"Australia": Vector2(134.2, -25.3), "New Zealand": Vector2(175.5, -39.5), "Japan": Vector2(138.5, 36.5),
	"Alaska": Vector2(-152.4, 64.3), "Argentina": Vector2(-64.5, -33.5), "New Guinea": Vector2(143.3, -5.7),
	"China": Vector2(105.3, 33.4), "Brazil": Vector2(-47.3, -11.7)}

var t: Node
var app: Node


func run(runner: Node) -> void:
	t = runner
	Simulation.auto_advance = false
	app = APP_SCENE.instantiate()
	t.add_child(app)
	app.router.fade_duration = 0.05
	await _idle()
	app.start_new_game()
	await _idle()
	app.open_chart()
	await t.wait_until(func() -> bool: return app.router.current_screen is WorldMap and not app.router.is_busy(), 10.0)
	var world := app.router.current_screen as WorldMap
	if t.check(world != null, "(setup) the chart is open"):
		var map := world.get_map_view()
		world.set_wind_shown(false)
		await _sweep(map, "whole world", 0.0, -1.0)
		await _sweep(map, "whole world", 0.0, 1.0)
		await _sweep(map, "regional, Australia latitude", 14.0, -1.0, -25.0)
		await _sweep(map, "regional, Pacific", 14.0, 1.0, -15.0)
		await _round_trip(map)
		await _pick_after_panning(world, map)
		map.center_on_geo(Vector2(152.0, -30.0), 40.0 / map.units_per_degree)
		await t.frames(3)
		await t.screenshot("17_map_australia_regional")
	Simulation.auto_advance = true
	app.queue_free()
	await t.frames(2)
	GameSession.end_session()


func _idle() -> void:
	await t.frames(2)
	await t.wait_until(func() -> bool: return not app.router.is_busy(), 5.0)
	await t.frames(2)


## Pans the camera 15° at a time through 2.2 turns of the globe, checking land
## coverage at every step.
func _sweep(map: MapView, label: String, px_per_degree: float, direction: float, lat := 10.0) -> void:
	if px_per_degree <= 0.0:
		map.reset_view()
	else:
		map.center_on_geo(Vector2(10.0, lat), px_per_degree / map.units_per_degree)
	await t.frames(2)
	var gaps := PackedStringArray()
	var checked := 0
	var free := Rect2(Vector2.ZERO, map._free_view_size())
	for step in 53:
		map.camera.position.x += direction * 15.0 * map.units_per_degree
		map._clamp_camera()
		await t.frames(1)
		for name: String in LAND:
			var base := map.projection.geo_to_map(LAND[name])
			for k in [-1, 0, 1]:
				var copy := base + Vector2(k * 360.0 * map.units_per_degree, 0.0)
				var screen := map.map_to_screen(copy)
				if not free.grow(-20.0).has_point(screen):
					continue
				checked += 1
				if not map.is_world_land_drawn_at(copy):
					gaps.append("%s at camera %.0f°" % [name, map.camera.position.x / map.units_per_degree])
	t.check(gaps.is_empty() and checked > 40,
		"[map] %s, panning %s through 2.2 turns: land drawn wherever it is on screen (%d checks)%s" % [label,
			"west" if direction < 0.0 else "east", checked, "" if gaps.is_empty() else ": gaps " + ", ".join(gaps.slice(0, 6))])
	t.check(absf(map.camera.position.x) <= 180.0 * map.units_per_degree + 1.0, "[map] the camera stays within one world after %s panning" % label)


## Screen ↔ geography stays consistent across the Date Line after panning.
func _round_trip(map: MapView) -> void:
	map.center_on_geo(Vector2(179.0, -17.0), 30.0 / map.units_per_degree)
	await t.frames(2)
	var worst := 0.0
	for geo in [Vector2(178.0, -18.0), Vector2(-179.0, -16.0), Vector2(175.0, -40.0), Vector2(-170.0, -20.0)]:
		var back: Vector2 = map.screen_to_geo(map.geo_to_screen(geo))
		worst = maxf(worst, Vector2(GeoMath.wrap_delta(geo.x, back.x), back.y - geo.y).length())
	t.check(worst < 0.01, "[map] screen and geographic positions round-trip across the Date Line (worst %.4f°)" % worst)


## After three turns of panning, harbours still sit where they are drawn.
func _pick_after_panning(world: WorldMap, map: MapView) -> void:
	map.center_on_geo(Vector2(-150.0, -17.0), 30.0 / map.units_per_degree)
	for i in 72:
		map.camera.position.x -= 15.0 * map.units_per_degree
		map._clamp_camera()
	await t.frames(3)
	var screen := map.get_port_screen_position(&"papeete")
	t.check(map.pick_port(screen) == &"papeete", "[map] after three turns of panning, Papeete is picked where it is drawn")
	world.select_port(&"auckland")
	await t.frames(2)
	t.check_eq(world.get_selected_port_id(), &"auckland", "[map] and Auckland can be selected")
