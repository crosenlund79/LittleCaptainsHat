extends RefCounted
## Geographic routing: sea routes never cross land, straits work, waypoints are
## validated, distances follow the path, and impossible routes fail safely.
##
## Besides the router's own raster validation, every route segment is checked
## independently against the *vector* coastline polygons the chart draws.
##
## Iteration 16: the worldwide chart. Representative international passages
## (Atlantic stepping stones, the Panama passage, the Pacific, a Date Line
## crossing, the Denmark region boundary), every international harbour reached
## from Copenhagen, land crossings checked against the world land as drawn.

## Harbour regions outside Europe (Iteration 16).
const WORLD_REGIONS := ["atlantic_islands", "caribbean", "central_america", "pacific"]

## The Panama Canal as the chart abstracts it: a channel across the isthmus
## between Colón and Panama City (tools/navigation/build_world.py).
const PANAMA_PASSAGE := Rect2(-80.3, 8.5, 1.2, 1.3)

var t: Node
var router: SeaRouter
var catalog: PortCatalog
var _land_polygons: Array[PackedVector2Array] = []  # projected (Mercator) rings
var _land_boxes: Array[Rect2] = []
var _projection := MapProjection.new(160.0)
var _world_width := 360.0 * 160.0


func run(runner: Node) -> void:
	t = runner
	var started := Time.get_ticks_msec()
	router = SeaRouter.get_default()
	catalog = PortCatalog.get_default()
	t.check(router != null and router.get_node_count() > 1000, "router loads the worldwide sea graph (%d nodes, %d ms)" % [
		router.get_node_count() if router else 0, Time.get_ticks_msec() - started])
	_load_land()

	_test_graph_consistency()
	_test_ports()
	_test_copenhagen_kiel()
	_test_representative_routes()
	_test_straits()
	_test_all_port_pairs()
	_test_waypoints()
	_test_failures()
	_test_world_routes()
	_test_dateline()
	_test_world_failures()


func _test_graph_consistency() -> void:
	var edges := router.get_edges()
	var bad := 0
	for i in range(0, edges.size(), 2):
		if not router.is_segment_navigable(router.get_node_geo(edges[i]), router.get_node_geo(edges[i + 1])):
			bad += 1
	t.check_eq(bad, 0, "all %d precomputed graph edges pass the runtime land check" % (edges.size() / 2))


func _test_ports() -> void:
	t.check(catalog.ports.size() >= 150, "about 150 harbours in the catalogue (Iteration 006)")
	for port in catalog.ports:
		# The limit scales with the chart's resolution there (10 nm on the
		# European chart, six cells on the coarser world chart).
		var approach := router.find_port_approach(port)
		var limit := router.approach_radius_nm(port.get_geo_position())
		t.check(approach.size() >= 1 and GeoMath.path_length_nm(approach) <= limit,
			"%s has a bounded harbour approach (%.1f of %.0f nm)" % [port.display_name, GeoMath.path_length_nm(approach), limit])


func _test_copenhagen_kiel() -> void:
	var route := _plan(&"copenhagen", &"kiel")
	t.check(route != null, "Copenhagen -> Kiel route is found")
	if route == null:
		return
	t.check_eq(router.validate_route(route), "", "Copenhagen -> Kiel passes route validation")
	var zealand := _polygon_containing(Vector2(12.08, 55.64))  # Roskilde
	t.check(zealand >= 0, "Zealand is found in the coastline data")
	var crosses_zealand := false
	for i in range(1, route.path.size()):
		if _segment_hits_polygon(route.path[i - 1], route.path[i], zealand):
			crosses_zealand = true
	t.check(not crosses_zealand, "Copenhagen -> Kiel does not cross Zealand")
	t.check(route.path.size() > 3, "the route has several segments (%d)" % (route.path.size() - 1))
	var straight := GeoMath.distance_nm(catalog.get_port(&"copenhagen").get_geo_position(), catalog.get_port(&"kiel").get_geo_position())
	t.check(route.get_distance_nm() > straight + 10.0, "sailing distance (%d nm) exceeds the straight line (%d nm)" % [
		roundi(route.get_distance_nm()), roundi(straight)])
	t.check(absf(route.get_distance_nm() - GeoMath.path_length_nm(route.path)) < 1e-6, "distance is the sum of the path's rhumb segments")


func _test_representative_routes() -> void:
	var pairs := [
		[&"kiel", &"gothenburg"], [&"copenhagen", &"helsinki"], [&"gothenburg", &"bergen"],
		[&"bergen", &"reykjavik"], [&"kiel", &"portsmouth"], [&"dublin", &"brest"],
		[&"portsmouth", &"lisbon"], [&"lisbon", &"gibraltar"], [&"gibraltar", &"barcelona"],
		[&"barcelona", &"naples"], [&"marseille", &"piraeus"], [&"naples", &"piraeus"],
		[&"helsinki", &"piraeus"],
	]
	for pair: Array in pairs:
		var started := Time.get_ticks_msec()
		var route := _plan(pair[0], pair[1])
		var elapsed := Time.get_ticks_msec() - started
		var name := "%s -> %s" % [pair[0], pair[1]]
		if not t.check(route != null, "%s: route found" % name):
			continue
		t.check_eq(router.validate_route(route), "", "%s: passes route validation" % name)
		var crossing := _first_land_crossing(route)
		t.check(crossing < 0, "%s: no segment crosses the drawn coastline%s" % [name, "" if crossing < 0 else " (segment %d)" % crossing])
		t.check(elapsed < 1500, "%s: calculated in %d ms" % [name, elapsed])


func _test_straits() -> void:
	# Each route must pass through its strait (crossing a line of longitude or
	# latitude inside a narrow window).
	_check_crossing(_plan(&"lisbon", &"barcelona"), "x", -5.6, 35.85, 36.10, "Lisbon -> Barcelona uses the Strait of Gibraltar")
	_check_crossing(_plan(&"portsmouth", &"kiel"), "x", 1.45, 50.75, 51.25, "Portsmouth -> Kiel uses the Strait of Dover")
	_check_crossing(_plan(&"copenhagen", &"gothenburg"), "y", 56.03, 12.45, 12.80, "Copenhagen -> Gothenburg uses the Øresund")
	_check_crossing(_plan(&"barcelona", &"naples"), "x", 9.25, 41.15, 41.45, "Barcelona -> Naples uses the Strait of Bonifacio")
	var great_belt := _plan(&"kiel", &"gothenburg")
	_check_crossing(great_belt, "y", 55.35, 10.75, 11.25, "Kiel -> Gothenburg uses the Great Belt")


## Every pair of European harbours, and every international harbour from
## Copenhagen (all pairs worldwide would be ~25,000 long routes).
func _test_all_port_pairs() -> void:
	var failures := PackedStringArray()
	var count := 0
	var started := Time.get_ticks_msec()
	var europe := catalog.ports.filter(func(p: PortData) -> bool: return p.region not in WORLD_REGIONS)
	for a: PortData in europe:
		for b: PortData in europe:
			if a.id >= b.id:
				continue
			count += 1
			var route := _plan(a.id, b.id)
			if route == null or not router.validate_route(route).is_empty():
				failures.append("%s-%s" % [a.id, b.id])
	t.check(failures.is_empty(), "all %d European port pairs have a valid sea route (%d ms)%s" % [count, Time.get_ticks_msec() - started,
		"" if failures.is_empty() else ": failed " + ", ".join(failures)])
	failures.clear()
	started = Time.get_ticks_msec()
	var world := catalog.ports.filter(func(p: PortData) -> bool: return p.region in WORLD_REGIONS)
	for port: PortData in world:
		var route := _plan(&"copenhagen", port.id)
		if route == null or not router.validate_route(route).is_empty():
			failures.append(String(port.id))
	t.check(world.size() >= 30 and failures.is_empty(), "all %d international harbours have a valid sea route from Copenhagen (%d ms)%s" % [
		world.size(), Time.get_ticks_msec() - started, "" if failures.is_empty() else ": failed " + ", ".join(failures)])


func _test_waypoints() -> void:
	var cph := catalog.get_port(&"copenhagen")
	# A waypoint on land (central Zealand) is rejected with an explanation.
	var on_land := Vector2(11.9, 55.45)
	t.check(not router.is_point_navigable(on_land), "central Zealand is not navigable")
	var result := router.plan_route(&"copenhagen", cph.get_geo_position(), [on_land] as Array[Vector2], &"kiel")
	t.check(not result.is_ok() and "Waypoint 1" in result.error, "a waypoint on land is rejected: %s" % result.error)
	t.check(result.legs.size() == 2 and not result.legs[0].ok, "the leg to the land waypoint is reported as blocked")

	# A valid waypoint becomes a vertex of the path; the route is recalculated around it.
	var waypoint := Vector2(12.62, 54.55)
	var with_waypoint := router.plan_route(&"copenhagen", cph.get_geo_position(), [waypoint] as Array[Vector2], &"kiel")
	t.check(with_waypoint.is_ok(), "route via a sea waypoint is found")
	if with_waypoint.is_ok():
		var route := with_waypoint.route
		t.check(route.path[route.waypoint_path_indices[0]].is_equal_approx(waypoint), "the waypoint is a point of the path")
		t.check_eq(router.validate_route(route), "", "route via waypoint passes validation")
		t.check(not is_equal_approx(route.get_distance_nm(), _plan(&"copenhagen", &"kiel").get_distance_nm()),
			"moving the course through a waypoint changes the distance")

	# Manually built routes that cross land can never be activated.
	GameSession.start_new_session()
	var direct := PlannedRoute.new()
	direct.origin_port_id = &"copenhagen"
	direct.origin_position = cph.get_geo_position()
	direct.destination_port_id = &"kiel"
	direct.path = PackedVector2Array([cph.get_geo_position(), catalog.get_port(&"kiel").get_geo_position()])
	t.check(not router.validate_route(direct).is_empty(), "a straight Copenhagen -> Kiel line fails validation")
	t.check(not GameSession.set_planned_route(direct).is_empty(), "GameSession refuses a land-crossing route")
	t.check(GameSession.get_planned_route() == null, "no planned route was created from the invalid one")
	t.check(not GameSession.depart().is_empty(), "departure is impossible without a valid route")
	t.check(not GameSession.is_underway(), "the boat stays moored")
	GameSession.end_session()


func _test_failures() -> void:
	var started := Time.get_ticks_msec()
	var black_sea := router.plan_route(&"", Vector2(33.0, 43.3), [] as Array[Vector2], &"piraeus")
	t.check(not black_sea.is_ok() and not black_sea.error.is_empty(),
		"Black Sea -> Piraeus fails safely (water not connected in the chart data): %s" % black_sea.error)
	var inland := router.plan_route(&"", Vector2(10.0, 50.0), [] as Array[Vector2], &"kiel")
	t.check(not inland.is_ok(), "a start position inland fails: %s" % inland.error)
	var unknown := router.plan_route(&"copenhagen", catalog.get_port(&"copenhagen").get_geo_position(), [] as Array[Vector2], &"atlantis")
	t.check(not unknown.is_ok(), "an unknown destination fails")
	t.check(Time.get_ticks_msec() - started < 3000, "failed routes return quickly (%d ms)" % (Time.get_ticks_msec() - started))


## The passages a voyage from Denmark to the South Pacific is made of.
func _test_world_routes() -> void:
	var legs := [
		[&"copenhagen", &"portsmouth", "Copenhagen -> Britain"], [&"copenhagen", &"lisbon", "Copenhagen -> Iberia"],
		[&"lisbon", &"las_palmas", "Iberia -> Canaries"], [&"lisbon", &"funchal", "Iberia -> Madeira"],
		[&"las_palmas", &"castries", "Canaries -> Caribbean (Atlantic crossing)"], [&"las_palmas", &"mindelo", "Canaries -> Cape Verde"],
		[&"castries", &"panama_city", "Caribbean -> Pacific (Panama)"], [&"panama_city", &"puerto_ayora", "Panama -> Galapagos"],
		[&"puerto_ayora", &"taiohae", "Galapagos -> Marquesas (Pacific crossing)"], [&"taiohae", &"papeete", "Marquesas -> Tahiti"],
		[&"papeete", &"auckland", "French Polynesia -> New Zealand"], [&"svendborg", &"las_palmas", "detailed Denmark -> the world chart"],
		[&"ponta_delgada", &"st_george_bermuda", "Azores -> Bermuda"], [&"honolulu", &"papeete", "Hawaii -> Tahiti"],
	]
	for leg: Array in legs:
		var started := Time.get_ticks_msec()
		var route := _plan(leg[0], leg[1])
		var elapsed := Time.get_ticks_msec() - started
		var name: String = leg[2]
		if not t.check(route != null, "%s: route found" % name):
			continue
		t.check_eq(router.validate_route(route), "", "%s: passes route validation" % name)
		var crossing := _first_land_crossing(route)
		t.check(crossing < 0, "%s: no segment crosses the drawn coastline%s" % [name, "" if crossing < 0 else " (segment %d at %s)" % [
			crossing, route.path[crossing]]])
		var straight := GeoMath.distance_nm(catalog.get_port(leg[0]).get_geo_position(), catalog.get_port(leg[1]).get_geo_position())
		var distance := route.get_distance_nm()
		t.check(distance >= straight * 0.98 and distance <= straight * 1.6 + 60.0,
			"%s: %d nm, a sensible distance for %d nm as the crow flies" % [name, roundi(distance), roundi(straight)])
		t.check(elapsed < 1500, "%s: calculated in %d ms" % [name, elapsed])
	# The Caribbean -> Pacific route uses the Panama passage (it crosses the
	# isthmus between Colón and Panama City, nowhere else).
	_check_crossing(_plan(&"castries", &"panama_city"), "y", 9.1, -80.1, -79.3, "Caribbean -> Pacific uses the Panama passage")
	var long_way := _plan(&"copenhagen", &"papeete")
	var started := Time.get_ticks_msec()
	long_way = _plan(&"copenhagen", &"papeete")
	t.check(long_way != null and router.validate_route(long_way).is_empty(),
		"Copenhagen -> Papeete in one go: %d nm, %d ms" % [roundi(long_way.get_distance_nm()) if long_way else 0, Time.get_ticks_msec() - started])


## Crossing the Date Line: the short way, never round the world.
func _test_dateline() -> void:
	for pair: Array in [[&"suva", &"avarua"], [&"papeete", &"auckland"], [&"nukualofa", &"lautoka"]]:
		var route := _plan(pair[0], pair[1])
		var name := "%s -> %s" % pair
		if not t.check(route != null, "%s (across the Date Line): route found" % name):
			continue
		var longest := 0.0
		var crossed := false
		for i in range(1, route.path.size()):
			# Paths keep longitudes within ±180°: a segment across the Date Line
			# jumps sign, and is sailed the short way (GeoMath.wrap_delta).
			var a := route.path[i - 1]
			var b := route.path[i]
			longest = maxf(longest, absf(GeoMath.wrap_delta(a.x, b.x)))
			crossed = crossed or absf(a.x - b.x) > 180.0
		var straight := GeoMath.distance_nm(catalog.get_port(pair[0]).get_geo_position(), catalog.get_port(pair[1]).get_geo_position())
		t.check(crossed and longest < 90.0 and route.get_distance_nm() < straight * 1.5 + 60.0,
			"%s crosses the Date Line the short way: %d nm (%d as the crow flies), no segment longer than %.1f° of longitude" % [
				name, roundi(route.get_distance_nm()), roundi(straight), longest])
		t.check_eq(router.validate_route(route), "", "%s: passes route validation" % name)
		t.check(_first_land_crossing(route) < 0, "%s: no segment crosses the drawn coastline" % name)


func _test_world_failures() -> void:
	var started := Time.get_ticks_msec()
	var papeete := catalog.get_port(&"papeete").get_geo_position()
	var caspian := router.plan_route(&"", Vector2(50.5, 42.0), [] as Array[Vector2], &"papeete")
	t.check(not caspian.is_ok() and not caspian.error.is_empty(),
		"Caspian Sea -> Papeete fails safely (water not connected to the ocean): %s" % caspian.error)
	var sahara := Vector2(10.0, 22.0)
	t.check(not router.is_point_navigable(sahara), "the Sahara is not navigable")
	var through := router.plan_route(&"las_palmas", catalog.get_port(&"las_palmas").get_geo_position(), [sahara] as Array[Vector2], &"castries")
	t.check(not through.is_ok() and "Waypoint 1" in through.error, "a waypoint in the Sahara is rejected: %s" % through.error)
	var straight := PlannedRoute.new()
	straight.origin_port_id = &"castries"
	straight.origin_position = catalog.get_port(&"castries").get_geo_position()
	straight.destination_port_id = &"papeete"
	straight.path = PackedVector2Array([straight.origin_position, papeete])
	t.check(not router.validate_route(straight).is_empty(), "a straight line from the Caribbean to Tahiti (across Central America) fails validation")
	t.check(Time.get_ticks_msec() - started < 3000, "failed world routes return quickly (%d ms)" % (Time.get_ticks_msec() - started))


# --- Helpers ------------------------------------------------------------------------------

func _plan(origin_id: StringName, destination_id: StringName) -> PlannedRoute:
	return t.make_route(origin_id, destination_id)


func _check_crossing(route: PlannedRoute, axis: String, value: float, low: float, high: float, description: String) -> void:
	var found := false
	if route:
		for i in range(1, route.path.size()):
			var a := route.path[i - 1]
			var b := route.path[i]
			var av := a.x if axis == "x" else a.y
			var bv := b.x if axis == "x" else b.y
			if (av - value) * (bv - value) <= 0.0 and av != bv:
				var f := (value - av) / (bv - av)
				var other := lerpf(a.y, b.y, f) if axis == "x" else lerpf(a.x, b.x, f)
				if other >= low and other <= high:
					found = true
	t.check(found, description)


func _load_land() -> void:
	# The land as the chart draws it (Iteration 14): the base coastline outside
	# the detail regions, each region's detailed land inside it.
	var data: Dictionary = load("res://data/navigation/europe_land.json").data
	var rects: Array[PackedVector2Array] = []
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(NavGrid.REGIONS_INDEX))
	for entry: Dictionary in index.regions:
		var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(String(entry.folder).path_join("region.json")))
		var a := _projection.geo_to_map(Vector2(meta.bounds.west, meta.bounds.north))
		var b := _projection.geo_to_map(Vector2(meta.bounds.east, meta.bounds.south))
		rects.append(PackedVector2Array([a, Vector2(b.x, a.y), b, Vector2(a.x, b.y)]))
		var land: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(String(entry.folder).path_join("land.json")))
		for ring: Array in land.detail.fill_tiles:
			_add_land(_project(ring))
	for ring: Array in data.polygons:
		var pieces: Array[PackedVector2Array] = [_project(ring)]
		for rect in rects:
			var next: Array[PackedVector2Array] = []
			for piece in pieces:
				for clipped in Geometry2D.clip_polygons(piece, rect):
					if not Geometry2D.is_polygon_clockwise(clipped):
						next.append(clipped)
			pieces = next
		for piece in pieces:
			_add_land(piece)
	# The world's land outside Europe (Iteration 16), as the chart draws it at
	# regional zoom (the same map space: 160 units per degree).
	var world_land := load("res://data/navigation/world/land.res") as WorldLand
	if world_land:
		for ring in world_land.regional_fill:
			_add_land(ring)


func _project(ring: Array) -> PackedVector2Array:
	var points := PackedVector2Array()
	for p: Array in ring:
		points.append(_projection.geo_to_map(Vector2(p[0], p[1])))
	return points


func _add_land(points: PackedVector2Array) -> void:
	if points.size() < 3:
		return
	_land_polygons.append(points)
	var box := Rect2(points[0], Vector2.ZERO)
	for p in points:
		box = box.expand(p)
	_land_boxes.append(box)


func _polygon_containing(geo: Vector2) -> int:
	var point := _projection.geo_to_map(geo)
	for i in _land_polygons.size():
		if _land_boxes[i].has_point(point) and Geometry2D.is_point_in_polygon(point, _land_polygons[i]):
			return i
	return -1


func _segment_hits_polygon(a_geo: Vector2, b_geo: Vector2, index: int) -> bool:
	b_geo.x = a_geo.x + GeoMath.wrap_delta(a_geo.x, b_geo.x)  # the short way across the Date Line
	var a := _projection.geo_to_map(a_geo)
	var b := _projection.geo_to_map(b_geo)
	# A segment continuing past the Date Line is also checked one world round
	# back, where the land on the other side is.
	var past := maxf(absf(a_geo.x), absf(b_geo.x)) > 180.0
	if past and _segment_hits_map(a - Vector2(signf(a_geo.x + b_geo.x) * _world_width, 0.0),
			b - Vector2(signf(a_geo.x + b_geo.x) * _world_width, 0.0), index):
		return true
	return _segment_hits_map(a, b, index)


func _segment_hits_map(a: Vector2, b: Vector2, index: int) -> bool:
	if not _land_boxes[index].intersects(Rect2(a, Vector2.ZERO).expand(b).grow(0.01)):
		return false
	var polygon := _land_polygons[index]
	if Geometry2D.is_point_in_polygon((a + b) / 2.0, polygon):
		return true
	for i in polygon.size():
		if Geometry2D.segment_intersects_segment(a, b, polygon[i], polygon[(i + 1) % polygon.size()]) != null:
			return true
	return false


## Index of the first segment that touches a land polygon, ignoring harbour
## approach segments (within the approach radius of the route's ports), or -1.
func _first_land_crossing(route: PlannedRoute) -> int:
	var ports: Array[Vector2] = [catalog.get_port(route.destination_port_id).get_geo_position()]
	if not route.origin_port_id.is_empty():
		ports.append(catalog.get_port(route.origin_port_id).get_geo_position())
	for i in range(1, route.path.size()):
		var a := route.path[i - 1]
		var b := route.path[i]
		var near_port := false
		for port in ports:
			var limit := router.approach_radius_nm(port)
			if GeoMath.rhumb_distance_nm(port, a) <= limit and GeoMath.rhumb_distance_nm(port, b) <= limit:
				near_port = true
		if near_port or (PANAMA_PASSAGE.has_point(a) and PANAMA_PASSAGE.has_point(b)):
			continue  # harbour approaches; the Panama passage cuts through the isthmus by design
		for p in _land_polygons.size():
			if _segment_hits_polygon(a, b, p):
				return i
	return -1
