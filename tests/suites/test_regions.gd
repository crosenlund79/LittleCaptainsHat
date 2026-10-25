extends RefCounted
## Iteration 14: detailed regional charts (Denmark). The region package loads
## and is merged into navigation; Danish waters route around the detailed
## coast; every Danish harbour has an approach; the chart switches between the
## overview and the detailed layer by zoom; a saved position that the detailed
## chart places on land is moved to the nearest open water and re-planned,
## never stranded or erased; and the cost of all this is measured.
##
## Inland test points are GeoNames town positions (cities.json, CC BY 4.0),
## the same gazetteer the harbour positions came from; they are towns far from
## any coast, so they are land on every chart.

const APP_SCENE := preload("res://src/app/app.tscn")
const ODENSE := Vector2(10.38831, 55.39594)
const RINGSTED := Vector2(11.79011, 55.4426)
const HERNING := Vector2(8.97662, 56.13615)
const HILLEROD := Vector2(12.30081, 55.92791)
## Harbours added for the detailed Danish chart (tools/navigation/add_danish_harbours.py).
const DANISH: Array[StringName] = [&"helsingor", &"gilleleje", &"dragor", &"rodvig", &"stege", &"vordingborg", &"nysted",
	&"korsor", &"kalundborg", &"nyborg", &"kerteminde", &"svendborg", &"faaborg", &"aeroskobing", &"marstal", &"rudkobing",
	&"middelfart", &"juelsminde", &"ebeltoft", &"grenaa", &"skagen", &"ronne", &"sonderborg", &"lohals", &"copenhagen"]
## Voyages through Danish waters: [from, to, what it exercises].
const VOYAGES := [
	[&"copenhagen", &"svendborg", "around Zealand into the South Funen Archipelago"],
	[&"lohals", &"copenhagen", "from Langeland through the Great Belt or the Baltic"],
	[&"middelfart", &"sonderborg", "down the Little Belt"],
	[&"helsingor", &"kalundborg", "round the top of Zealand"],
	[&"skagen", &"ronne", "Kattegat, Øresund and the Baltic to Bornholm"],
	[&"korsor", &"nyborg", "across the Great Belt"],
	[&"marstal", &"faaborg", "among the islands south of Funen"],
	[&"copenhagen", &"kiel", "out of the region's waters to Germany"],
]

var t: Node
var router: SeaRouter
var catalog: PortCatalog
## Measurements for the report: [label, value text].
var measurements: Array = []


func run(runner: Node) -> void:
	t = runner
	router = SeaRouter.get_default()
	catalog = PortCatalog.get_default()
	_test_region_loaded()
	_test_detail()
	_test_harbours()
	_test_voyages()
	_test_recovery()
	_test_performance()
	await _test_chart()
	print("    Iteration 14 measurements:")
	for row: Array in measurements:
		print("      %-44s %s" % row)


func _test_region_loaded() -> void:
	t.check(router.grid.regions.size() >= 1, "[region] the regional charts are loaded (%d)" % router.grid.regions.size())
	var denmark: NavGrid = null
	for region in router.grid.regions:
		if region.region_id == "denmark":
			denmark = region
	if not t.check(denmark != null, "[region] Denmark is one of them"):
		return
	t.check(denmark.factor == 6 and denmark.cells_per_degree == 360.0,
		"[region] six times finer than the base chart (%d, %.0f cells per degree)" % [denmark.factor, denmark.cells_per_degree])
	t.check_eq(router.grid.region_id_at(catalog.get_port(&"copenhagen").get_geo_position()), "denmark", "[region] Copenhagen lies in it")
	t.check_eq(router.grid.region_id_at(catalog.get_port(&"bergen").get_geo_position()), "", "[region] Bergen does not (base chart)")
	t.check(router.grid.grid_at(ODENSE) == denmark and router.grid.grid_at(catalog.get_port(&"lisbon").get_geo_position()) == router.grid,
		"[region] grid_at() picks the finest chart for a position")
	var meta: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/navigation/regions/denmark/region.json"))
	t.check(meta is Dictionary and String(meta.get("licence", "")).contains("ODbL") and meta.has("source") and meta.has("crs"),
		"[region] region.json documents its sources, licence and CRS")


func _test_detail() -> void:
	for town: Vector2 in [ODENSE, RINGSTED, HERNING, HILLEROD]:
		t.check(router.grid.cell_class_at_geo(town) == NavGrid.LAND, "[detail] inland town %s is land" % town)
	# Between harbours on opposite shores of a strait, the water is open.
	var straits := [[&"korsor", &"nyborg", "the Great Belt"], [&"helsingor", &"copenhagen", "the Øresund"]]
	for strait: Array in straits:
		var a := catalog.get_port(strait[0]).get_geo_position()
		var b := catalog.get_port(strait[1]).get_geo_position()
		t.check(router.is_point_navigable(GeoMath.rhumb_interpolate(a, b, 0.5)), "[detail] %s is open water" % strait[2])
	# Straight across Zealand or Funen is land in the detailed chart.
	t.check(not router.is_segment_navigable(catalog.get_port(&"copenhagen").get_geo_position(), catalog.get_port(&"korsor").get_geo_position()),
		"[detail] a straight line Copenhagen → Korsør crosses Zealand")
	t.check(not router.is_segment_navigable(catalog.get_port(&"middelfart").get_geo_position(), catalog.get_port(&"nyborg").get_geo_position()),
		"[detail] a straight line Middelfart → Nyborg crosses Funen")


func _test_harbours() -> void:
	var missing: Array[String] = []
	var no_approach: Array[String] = []
	for id in DANISH:
		var port := catalog.get_port(id)
		if port == null:
			missing.append(String(id))
			continue
		if router.find_port_approach(port).is_empty():
			no_approach.append(String(id))
	t.check(missing.is_empty(), "[harbours] every Danish harbour is in the catalogue (missing: %s)" % [missing])
	t.check(no_approach.is_empty(), "[harbours] every Danish harbour has an approach to open water (%s)" % [no_approach])


func _test_voyages() -> void:
	for voyage: Array in VOYAGES:
		var from := catalog.get_port(voyage[0])
		var to := catalog.get_port(voyage[1])
		var start := Time.get_ticks_usec()
		var result := router.plan_route(from.id, from.get_geo_position(), [], to.id)
		var ms := (Time.get_ticks_usec() - start) / 1000.0
		var ok := result.is_ok() and router.validate_route(result.route).is_empty()
		var direct := GeoMath.rhumb_distance_nm(from.get_geo_position(), to.get_geo_position())
		var nm := result.route.get_distance_nm() if result.is_ok() else 0.0
		t.check(ok and nm >= direct and nm < direct * 3.0 + 10.0, "[route] %s → %s, %s: %.0f nm (direct %.0f), %.0f ms" % [
			from.display_name, to.display_name, voyage[2], nm, direct, ms])
		measurements.append(["route %s → %s" % [from.display_name, to.display_name], "%.0f ms, %.0f nm" % [ms, nm]])


# --- Recovery of saved positions ------------------------------------------------------

func _test_recovery() -> void:
	# A voyage saved under the old chart, now on land (Odense, on Funen).
	GameSession.start_new_session()
	var state := GameSession.get_state_snapshot()
	var svendborg := catalog.get_port(&"svendborg").get_geo_position()
	var route := PlannedRoute.new()
	route.origin_port_id = &"copenhagen"
	route.origin_position = ODENSE
	route.destination_port_id = &"svendborg"
	route.path = PackedVector2Array([ODENSE, svendborg])
	state.voyage = Voyage.create(route, state.game_time)
	state.vessel_status = SessionState.STATUS_UNDERWAY
	state.location_id = &""
	state.vessel_position = ODENSE
	state.planned_route = null
	var funds := state.funds
	GameSession.replace_state(state)
	var info := GameSession.get_last_location_recovery()
	var position := GameSession.get_vessel_position()
	t.check(GameSession.is_underway() and GameSession.get_voyage() != null, "[recovery] the vessel is still at sea on its voyage, not erased")
	t.check(router.is_point_navigable(position), "[recovery] it has been moved to open water (%s)" % position)
	t.check(info.get("kind") == "voyage" and float(info.get("moved_nm", 0.0)) > 0.0 and float(info.get("moved_nm", 99.0)) < 15.0,
		"[recovery] to the nearest open water, not far away (%s)" % [info])
	t.check(info.get("replanned", false) and router.validate_route(GameSession.get_voyage().route).is_empty()
		and GameSession.get_voyage_destination_id() == &"svendborg", "[recovery] the course to Svendborg is re-planned from there")
	t.check(GameSession.get_funds() == funds, "[recovery] nothing else changes")

	# Anchored on what is now land (Hillerød): the anchor and the boat move.
	GameSession.start_new_session()
	state = GameSession.get_state_snapshot()
	var cph := catalog.get_port(&"copenhagen").get_geo_position()
	var planned := router.plan_route(&"copenhagen", cph, [], &"malmo")
	state.voyage = Voyage.create(planned.route, state.game_time)
	state.vessel_status = SessionState.STATUS_UNDERWAY
	state.location_id = &""
	state.anchor.active = true
	state.anchor.position = HILLEROD
	state.vessel_position = HILLEROD
	state.planned_route = null
	GameSession.replace_state(state)
	info = GameSession.get_last_location_recovery()
	t.check(GameSession.is_anchored() and router.is_point_navigable(GameSession.get_anchor().position)
		and GameSession.get_vessel_position() == GameSession.get_anchor().position,
		"[recovery] an anchor saved on land is moved to open water, still at anchor (%s)" % [info])

	# A planned course in harbour that now crosses land is re-planned.
	GameSession.start_new_session()
	state = GameSession.get_state_snapshot()
	var straight := PlannedRoute.new()
	straight.origin_port_id = &"copenhagen"
	straight.origin_position = cph
	straight.destination_port_id = &"korsor"
	straight.path = PackedVector2Array([cph, catalog.get_port(&"korsor").get_geo_position()])
	state.planned_route = straight
	GameSession.replace_state(state)
	info = GameSession.get_last_location_recovery()
	var fixed := GameSession.get_planned_route()
	t.check(info.get("kind") == "planned_route" and fixed != null and router.validate_route(fixed).is_empty()
		and fixed.destination_port_id == &"korsor", "[recovery] a saved course across Zealand is re-planned around it")

	# A valid voyage is left exactly as it was.
	GameSession.start_new_session()
	state = GameSession.get_state_snapshot()
	state.voyage = Voyage.create(planned.route, state.game_time)
	state.voyage.progress_nm = 3.0
	state.vessel_status = SessionState.STATUS_UNDERWAY
	state.location_id = &""
	state.vessel_position = state.voyage.get_position()
	state.planned_route = null
	GameSession.replace_state(state)
	t.check(GameSession.get_last_location_recovery().is_empty() and is_equal_approx(GameSession.get_voyage_progress_nm(), 3.0),
		"[recovery] a valid voyage is not touched")
	GameSession.end_session()


# --- Performance ----------------------------------------------------------------------

func _test_performance() -> void:
	var memory_before := OS.get_static_memory_usage()
	var start := Time.get_ticks_usec()
	var fresh := SeaRouter.load_from(NavGrid.DEFAULT_MASK, NavGrid.DEFAULT_META, SeaRouter.DEFAULT_GRAPH)
	var load_ms := (Time.get_ticks_usec() - start) / 1000.0
	var memory_mb := (OS.get_static_memory_usage() - memory_before) / 1048576.0
	t.check(fresh != null and load_ms < 15000.0, "[perf] navigation with the Danish region loads in %.0f ms" % load_ms)
	measurements.append(["navigation load (base + Denmark)", "%.0f ms" % load_ms])
	measurements.append(["navigation memory (static, approx.)", "%.1f MB" % memory_mb])
	measurements.append(["graph nodes (base + region)", str(fresh.get_node_count())])
	# A cold route on the fresh router (no caches).
	var cph := catalog.get_port(&"copenhagen")
	start = Time.get_ticks_usec()
	var result := fresh.plan_route(cph.id, cph.get_geo_position(), [], &"svendborg")
	var cold_ms := (Time.get_ticks_usec() - start) / 1000.0
	t.check(result.is_ok() and cold_ms < 3000.0, "[perf] a cold Danish route plans in %.0f ms" % cold_ms)
	measurements.append(["cold route Copenhagen → Svendborg", "%.0f ms" % cold_ms])


func _test_chart() -> void:
	Simulation.auto_advance = false
	t.use_calm_wind()
	var app := APP_SCENE.instantiate()
	t.add_child(app)
	app.router.fade_duration = 0.05
	await t.frames(2)
	await t.wait_until(func() -> bool: return not app.router.is_busy(), 5.0)
	app.start_new_game()
	await t.frames(2)
	await t.wait_until(func() -> bool: return not app.router.is_busy(), 5.0)
	var start := Time.get_ticks_usec()
	app.open_chart()
	await t.wait_until(func() -> bool: return not app.router.is_busy() and app.router.current_screen is WorldMap, 10.0)
	var open_ms := (Time.get_ticks_usec() - start) / 1000.0
	var world := app.router.current_screen as WorldMap
	if t.check(world != null, "[chart] the chart opens (%.0f ms, including the fade)" % open_ms):
		measurements.append(["chart open (including fade)", "%.0f ms" % open_ms])
		var map := world.get_node("MapView") as MapView
		t.check("denmark" in map.get_region_ids(), "[chart] the chart knows the Danish region")
		map.reset_view()
		await t.frames(2)
		t.check(not map.is_region_detail_shown("denmark"), "[chart] zoomed out: the light overview outline is drawn")
		map.center_on_geo(Vector2(11.0, 55.4), 400.0 / map.units_per_degree)
		await t.frames(2)
		t.check(map.is_region_detail_shown("denmark"), "[chart] zoomed in: the detailed coastline is drawn")
		# Zoom cost: switching levels and redrawing.
		start = Time.get_ticks_usec()
		for i in 10:
			map.reset_view()
			map.center_on_geo(Vector2(11.0, 55.4), 400.0 / map.units_per_degree)
		var zoom_ms := (Time.get_ticks_usec() - start) / 20000.0
		measurements.append(["zoom change (level switch)", "%.2f ms" % zoom_ms])
		t.check(zoom_ms < 50.0, "[perf] a zoom change takes %.2f ms" % zoom_ms)
		var frame_start := Time.get_ticks_usec()
		await t.frames(10)
		var frame_ms := (Time.get_ticks_usec() - frame_start) / 10000.0
		measurements.append(["frame, detailed Danish chart (headless if so)", "%.1f ms" % frame_ms])
	Simulation.auto_advance = true
	app.queue_free()
	await t.frames(2)
	GameSession.end_session()
