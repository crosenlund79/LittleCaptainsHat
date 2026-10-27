class_name SeaRouter
extends RefCounted
## Calculates sea routes that never cross land, and validates routes.
##
## Method (see docs/technical/ARCHITECTURE.md, "Route calculation"):
## 1. A precomputed sparse graph of open-water points (europe_route_graph.json)
##    covers the chart; every edge is a straight line through navigable cells.
##    It is searched with Godot's native AStar2D.
## 2. The route's end points are connected to nearby graph nodes they can "see"
##    (clear straight line). Ports first reach open water through a bounded
##    harbour approach (see find_port_approach()).
## 3. The node path is shortened by "string pulling": a point is skipped
##    whenever a straight line past it is still clear.
## 4. Waypoints split a route into legs; each leg is routed independently, so
##    waypoints act as constraints and moving one only recalculates its legs.
## Every segment of a result is a rhumb line checked against the NavGrid, and
## validate_route() re-checks complete routes before they are used.
##
## The world (Iteration 16): the default router covers the whole planet. The
## world graph (data/navigation/world/graph.json) is the root; Europe's graph
## replaces its nodes inside Europe and Denmark's replaces Europe's inside
## Denmark, joined by seam edges (_merge()). A* runs in 3D on the sphere, so
## distances are right everywhere and the Date Line is no edge at all. Paths
## keep normalized longitudes; every line and distance takes the short way
## round (GeoMath.wrap_delta), and the chart draws them continuously.
##
## Ship canals (Cozy Polish injection): the Kiel and Suez canals are narrower
## than any chart cell, so they are navigable links (data/navigation/canals.json):
## a chain of graph points along approximate real centreline points, joined
## to the sea graph at an open-water entrance at each end. Routes may follow
## them; validate_route() accepts their segments and a boat in a canal is
## afloat. Nothing else may cross land. (Panama is carved into the world chart.)

const DEFAULT_GRAPH := "res://data/navigation/europe_route_graph.json"
const WORLD_GRAPH := "res://data/navigation/world/graph.json"
const WORLD_EUROPE_LINK := "res://data/navigation/world/europe_link.json"
const CANALS := "res://data/navigation/canals.json"
## How far (nm) a position may lie from a canal's centreline and still be in it.
const CANAL_WIDTH_NM := 0.3

## A port's coordinate may lie on (generalised) land. Its "berth link" may
## start anywhere within this distance of the port, in approach-class water.
const BERTH_RADIUS_NM := 2.0
## Harbour approaches may use approach-class water within this distance of the port.
const MAX_APPROACH_NM := 10.0
## Size of the search window around a port for its approach (cells each side).
const APPROACH_WINDOW_CELLS := 30
## Search radii (cells) used to connect a point to the graph.
const CONNECT_RADII: Array[int] = [16, 48, 128]
const CONNECT_CANDIDATES := 8
## Spatial buckets (root grid cells) for finding nodes near a point.
const BUCKET_CELLS := 8
## Upper bound on the A* result; protects against pathological data.
const MAX_PATH_NODES := 20000
const LEG_CACHE_LIMIT := 256
## Harbour approaches must reach a graph component of at least this many nodes,
## so they never end in an enclosed pocket of water (e.g. a dock basin).
const MIN_SEA_COMPONENT_NODES := 50

## Graph positions are points on a sphere of the Earth's radius (nautical
## miles): A* costs and estimates are chord lengths, close to sailing
## distances for graph edges and never more than the true distance.

static var _default: SeaRouter

var grid: NavGrid
var catalog: PortCatalog
var _astar := AStar3D.new()
var _node_geo := PackedVector2Array()
var _node_cell := PackedVector2Array()
var _node_component := PackedInt32Array()
var _component_size := {}
var _buckets := {}
var _bucket_columns := 0
var _next_temp_id := 0
var _approach_cache := {}
var _leg_cache := {}
## Loaded canals: [{"id", "name", "points": PackedVector2Array, "nodes": PackedInt32Array}].
var canals: Array[Dictionary] = []


## One route leg between two stops, or the reason it failed.
class Leg:
	var path := PackedVector2Array()
	var ok := false
	var error := ""


## Result of planning a complete route (all legs).
class RouteResult:
	## The validated route, or null when any leg failed.
	var route: PlannedRoute
	var legs: Array[Leg] = []
	var error := ""

	func is_ok() -> bool:
		return route != null


## Drops the shared instance. Called on shutdown: a script holding an instance
## of itself in a static variable would otherwise never be released.
static func clear_default() -> void:
	_default = null


## The default router if it has been loaded already, else null (never loads:
## for cheap questions such as diagnostics).
static func get_loaded() -> SeaRouter:
	return _default


static func get_default() -> SeaRouter:
	if _default == null:
		_default = SeaRouter.load_world()
		if _default == null:
			_default = SeaRouter.load_from(NavGrid.DEFAULT_MASK, NavGrid.DEFAULT_META, DEFAULT_GRAPH)
	return _default


## The worldwide router: world, Europe and its regions (Iteration 16).
static func load_world() -> SeaRouter:
	var router := SeaRouter.new()
	router.catalog = PortCatalog.get_default()
	router.grid = NavGrid.load_world()
	if router.grid == null:
		return null
	var graph: Variant = JSON.parse_string(FileAccess.get_file_as_string(WORLD_GRAPH))
	if not graph is Dictionary:
		push_error("World route graph missing: %s" % WORLD_GRAPH)
		return null
	router._load_graph(graph.nodes, graph.edges)
	router._add_canals()
	return router


static func load_from(mask_path: String, meta_path: String, graph_path: String) -> SeaRouter:
	var router := SeaRouter.new()
	router.catalog = PortCatalog.get_default()
	router.grid = NavGrid.load_from(mask_path, meta_path)
	if router.grid == null:
		return null
	var graph: Variant = JSON.parse_string(FileAccess.get_file_as_string(graph_path))
	if not graph is Dictionary:
		push_error("Route graph missing: %s" % graph_path)
		return null
	if mask_path == NavGrid.DEFAULT_MASK:
		router.grid.load_regions()
	router._load_graph(graph.nodes, graph.edges)
	router._add_canals()
	return router


func get_node_count() -> int:
	return _node_geo.size()


func get_node_geo(index: int) -> Vector2:
	return _node_geo[index]


## Raw graph edges as pairs of node indices (used by consistency tests).
func get_edges() -> PackedInt32Array:
	var result := PackedInt32Array()
	for id in _node_geo.size():
		for other in _astar.get_point_connections(id):
			if other > id:
				result.append(id)
				result.append(other)
	return result


# --- Point and segment checks --------------------------------------------------------

## True if a vessel may be at this position in open water.
func is_point_navigable(geo: Vector2) -> bool:
	return grid.is_navigable(geo)


func is_segment_navigable(from: Vector2, to: Vector2) -> bool:
	return grid.is_geo_line_clear(from, to, NavGrid.NAVIGABLE)


## A point a course may use (0.105b): routing water, or near-shore clear water
## with a checked approach from it (CoastalGeography.approach) - e.g. an
## anchorage the coarse world chart cannot express.
func is_point_reachable(geo: Vector2) -> bool:
	return is_point_navigable(geo) or not CoastalGeography.get_default().approach(geo).is_empty()


## A position a boat may lie at (0.105b): routing water or water on the fine
## coastal raster (where an approach brought it).
func is_afloat(geo: Vector2) -> bool:
	return is_point_navigable(geo) or CoastalGeography.get_default().is_water(geo) or not canal_at(geo).is_empty()


## Checks every segment of a route. Returns "" when valid, otherwise the reason.
## Allowed segments: navigable water everywhere; harbour approaches near the
## route's origin/destination port in approach-class water; and the short berth
## link that starts or ends exactly at a port coordinate.
func validate_route(route: PlannedRoute) -> String:
	if route == null:
		return Loc.t("There is no route.")
	var path := route.path
	if path.size() < 2:
		return Loc.t("The route has no course.")
	var destination := catalog.get_port(route.destination_port_id)
	if destination == null:
		return Loc.t("The destination is unknown.")
	if not GeoMath.same_position(path[0], route.origin_position):
		return Loc.t("The route does not start at the vessel's position.")
	if not GeoMath.same_position(path[path.size() - 1], destination.get_geo_position()):
		return Loc.t("The route does not end at the destination.")
	var ports: Array[Vector2] = [destination.get_geo_position()]
	var origin := catalog.get_port(route.origin_port_id)
	if origin:
		ports.append(origin.get_geo_position())
	for waypoint in route.waypoints:
		if not is_point_reachable(waypoint):
			return Loc.t("A waypoint is on land or too close to the coast.")
	for i in range(1, path.size()):
		if not _is_segment_allowed(path[i - 1], path[i], ports):
			return Loc.t("Leg %d of the course crosses land.") % i
	return ""


func _is_segment_allowed(a: Vector2, b: Vector2, ports: Array[Vector2]) -> bool:
	if grid.is_geo_line_clear(a, b, NavGrid.NAVIGABLE):
		return true
	if is_canal_segment(a, b):
		return true
	# A near-shore approach (0.105b): short, and clear water all the way on the
	# fine coastal raster (never over land, never through a narrow entrance).
	if GeoMath.rhumb_distance_nm(a, b) <= CoastalGeography.approach_max_nm(a) + 0.01 \
			and CoastalGeography.get_default().is_line_clear(a, b):
		return true
	for port in ports:
		var reach := approach_radius_nm(port)
		var near_a := GeoMath.rhumb_distance_nm(port, a) <= reach
		var near_b := GeoMath.rhumb_distance_nm(port, b) <= reach
		if not (near_a and near_b):
			continue
		if grid.is_geo_line_clear(a, b, NavGrid.APPROACH):
			return true
		# Berth link: from the port coordinate itself to approach water nearby.
		var berth := a if GeoMath.same_position(a, port) else (b if GeoMath.same_position(b, port) else Vector2.INF)
		var other := b if berth == a else a
		if berth != Vector2.INF and GeoMath.rhumb_distance_nm(berth, other) <= berth_radius_nm(port) \
				and grid.cell_class_at_geo(other) >= NavGrid.APPROACH:
			return true
	return false


## The nearest open-water position to `geo` (itself when already navigable),
## searched outward cell by cell in the finest chart covering it, up to
## `max_nm`. Prefers water connected to the open sea. Returns Vector2.INF when
## none is found. Used to recover a saved position that a more detailed chart
## now places on land.
func nearest_navigable(geo: Vector2, max_nm := 15.0) -> Vector2:
	if is_point_navigable(geo) and _reaches_open_sea(geo):
		return geo
	var cells := grid.grid_at(geo)
	var centre := cells.geo_to_cell(geo)
	var cx := floori(centre.x)
	var cy := floori(centre.y)
	var cell_nm := 60.0 / cells.cells_per_degree * maxf(cos(deg_to_rad(geo.y)), 0.1)
	var radius := mini(ceili(max_nm / cell_nm), 400)
	var fallback := Vector2.INF
	for r in range(1, radius + 1):
		var best := Vector2.INF
		var best_nm := INF
		for dy in range(-r, r + 1):
			var step := 1 if absi(dy) == r else 2 * r
			for dx in range(-r, r + 1, step):
				if cells.get_class_at(cx + dx, cy + dy) != NavGrid.NAVIGABLE:
					continue
				var candidate := cells.cell_center_geo(cx + dx, cy + dy)
				if not is_point_navigable(candidate):
					continue
				var nm := GeoMath.rhumb_distance_nm(geo, candidate)
				if nm < best_nm and nm <= max_nm:
					if not _reaches_open_sea(candidate):
						if fallback == Vector2.INF:
							fallback = candidate
						continue
					best = candidate
					best_nm = nm
		if best != Vector2.INF:
			return best
	return fallback


## Harbour approach limits at `port`: the fixed distances on the European
## and Danish charts, scaled up on the coarser world chart (Iteration 16),
## where a harbour may lie more than a cell (~5 nm) from water the raster keeps.
func berth_radius_nm(port: Vector2) -> float:
	return maxf(BERTH_RADIUS_NM, 1.5 * _cell_nm(grid.grid_at(port)))


func approach_radius_nm(port: Vector2) -> float:
	return maxf(MAX_APPROACH_NM, 6.0 * _cell_nm(grid.grid_at(port)))


static func _cell_nm(cells: NavGrid) -> float:
	return 60.0 / cells.cells_per_degree


# --- Planning ----------------------------------------------------------------------------

## Plans a complete route: origin (a port id, or "" for a position at sea),
## optional waypoints in order, and a destination port. Each leg is routed
## separately; the result lists every leg so invalid ones can be shown.
func plan_route(origin_port_id: StringName, origin_position: Vector2, waypoints: Array[Vector2],
		destination_port_id: StringName) -> RouteResult:
	var result := RouteResult.new()
	var destination := catalog.get_port(destination_port_id)
	if destination == null:
		result.error = Loc.t("Choose a destination port.")
		return result
	if origin_port_id == destination_port_id and waypoints.is_empty():
		result.error = Loc.t("The vessel is already in %s.") % destination.display_name
		return result
	var stops: Array[Vector2] = [origin_position]
	stops.append_array(waypoints)
	stops.append(destination.get_geo_position())
	var path := PackedVector2Array([origin_position])
	var indices := PackedInt32Array()
	for i in range(1, stops.size()):
		var from_port := origin_port_id if i == 1 else &""
		var to_port := destination_port_id if i == stops.size() - 1 else &""
		var leg := find_leg(stops[i - 1], stops[i], from_port, to_port)
		result.legs.append(leg)
		if not leg.ok:
			if result.error.is_empty():
				result.error = _describe_leg_failure(i, stops.size() - 1, leg.error)
			continue
		if result.error.is_empty():
			for j in range(1, leg.path.size()):
				path.append(leg.path[j])
			if i < stops.size() - 1:
				indices.append(path.size() - 1)
	if not result.error.is_empty():
		return result
	var route := PlannedRoute.new()
	route.origin_port_id = origin_port_id
	route.origin_position = origin_position
	route.destination_port_id = destination_port_id
	route.waypoints = waypoints.duplicate()
	route.path = path
	route.waypoint_path_indices = indices
	var problem := validate_route(route)
	if not problem.is_empty():
		result.error = problem  # Defensive: should never happen for a fresh plan.
		return result
	result.route = route
	return result


## Routes one leg. Ports (by id) get a harbour approach at that end.
func find_leg(from: Vector2, to: Vector2, from_port_id: StringName, to_port_id: StringName) -> Leg:
	var key := "%s|%s|%s|%s" % [from, to, from_port_id, to_port_id]
	if _leg_cache.has(key):
		return _leg_cache[key]
	var leg := _compute_leg(from, to, from_port_id, to_port_id)
	if _leg_cache.size() >= LEG_CACHE_LIMIT:
		_leg_cache.clear()
	_leg_cache[key] = leg
	return leg


func _compute_leg(from: Vector2, to: Vector2, from_port_id: StringName, to_port_id: StringName) -> Leg:
	var leg := Leg.new()
	var head := _endpoint_path(from, from_port_id).duplicate()
	if head.is_empty():
		leg.error = "start_blocked" if from_port_id.is_empty() else "start_port"
		return leg
	var tail := _endpoint_path(to, to_port_id).duplicate()
	if tail.is_empty():
		leg.error = "end_blocked" if to_port_id.is_empty() else "end_port"
		return leg
	tail.reverse()
	var start: Vector2 = head[head.size() - 1]
	var finish: Vector2 = tail[0]
	var middle := PackedVector2Array()
	if GeoMath.same_position(start, finish) or is_segment_navigable(start, finish):
		middle = PackedVector2Array([start, finish])
	else:
		middle = _graph_path(start, finish)
		if middle.is_empty():
			leg.error = "no_route"
			return leg
	var path := head.duplicate()
	for i in range(1, middle.size()):
		path.append(middle[i])
	for i in range(1, tail.size()):
		path.append(tail[i])
	leg.path = path
	leg.ok = true
	return leg


## The fixed part of a leg at one end: [point] for open water, the near-shore
## approach [point, ..., open-water point] for a spot the routing chart cannot
## express (0.105b, CoastalGeography.approach), or the harbour approach
## [port, ..., open-water point] for a port. Empty if unreachable.
func _endpoint_path(point: Vector2, port_id: StringName) -> PackedVector2Array:
	if port_id.is_empty():
		if is_point_navigable(point):
			return PackedVector2Array([point])
		return CoastalGeography.get_default().approach(point)
	var port := catalog.get_port(port_id)
	return find_port_approach(port) if port else PackedVector2Array()


## Harbour approach: the shortest way (breadth-first over raster cells) from a
## port coordinate to navigable water that connects to the route graph. It may
## start in approach-class water up to BERTH_RADIUS_NM from the coordinate and
## must stay within APPROACH_WINDOW_CELLS / MAX_APPROACH_NM. Bounded, so it
## always finishes quickly. Returns [port, ..., open-water point] or empty.
func find_port_approach(port: PortData) -> PackedVector2Array:
	if _approach_cache.has(port.id):
		return _approach_cache[port.id]
	var origin := port.get_geo_position()
	var result := PackedVector2Array()
	if is_point_navigable(origin) and _reaches_open_sea(origin):
		result = PackedVector2Array([origin])
		_approach_cache[port.id] = result
		return result
	# In a detail region the search runs on its finer raster (Iteration 14).
	var cells_grid := grid.grid_at(origin)
	var scale := cells_grid.cells_per_degree / 60.0  # cells per nautical mile (north-south, roughly)
	var berth_nm := berth_radius_nm(origin)
	var reach_nm := approach_radius_nm(origin)
	var window := maxi(roundi(APPROACH_WINDOW_CELLS * scale), ceili(reach_nm * scale) + 2)
	var center := cells_grid.geo_to_cell(origin)
	var cx := floori(center.x)
	var cy := floori(center.y)
	var previous := {}
	var queue: Array[Vector2i] = []
	# Berth: all approach water within the berth radius may serve as a start.
	var berth_cells := ceili((ceili(berth_nm * 2.0) + 2) * scale)
	for y in range(cy - berth_cells, cy + berth_cells + 1):
		for x in range(cx - berth_cells, cx + berth_cells + 1):
			if cells_grid.get_class_at(x, y) >= NavGrid.APPROACH \
					and GeoMath.rhumb_distance_nm(origin, cells_grid.cell_center_geo(x, y)) <= berth_nm:
				var cell := Vector2i(x, y)
				previous[cell] = null
				queue.append(cell)
	var head := 0
	var found := Vector2i(-1, -1)
	while head < queue.size():
		var cell := queue[head]
		head += 1
		if cells_grid.get_class_at(cell.x, cell.y) == NavGrid.NAVIGABLE:
			var geo := cells_grid.cell_center_geo(cell.x, cell.y)
			if _reaches_open_sea(geo):
				found = cell
				break
		for offset: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var next := cell + offset
			if previous.has(next) or absi(next.x - cx) > window or absi(next.y - cy) > window:
				continue
			if cells_grid.get_class_at(next.x, next.y) >= NavGrid.APPROACH \
					and GeoMath.rhumb_distance_nm(origin, cells_grid.cell_center_geo(next.x, next.y)) <= reach_nm:
				previous[next] = cell
				queue.append(next)
	if found.x >= 0:
		var cells: Array[Vector2] = []
		var cell: Variant = found
		while cell != null:
			cells.append(cells_grid.cell_center_geo(cell.x, cell.y))
			cell = previous[cell]
		cells.reverse()  # berth ... open water
		# Berth link to the first cell, then the chain shortened within approach water.
		result = PackedVector2Array([origin, cells[0]])
		var anchor := 0
		while anchor < cells.size() - 1:
			var reach := anchor + 1
			while reach + 1 < cells.size() and grid.is_geo_line_clear(cells[anchor], cells[reach + 1], NavGrid.APPROACH):
				reach += 1
			result.append(cells[reach])
			anchor = reach
		result = _dedupe(result)
	_approach_cache[port.id] = result
	return result


func _reaches_open_sea(point: Vector2) -> bool:
	for id in _visible_nodes(point):
		if _component_size[_node_component[id]] >= MIN_SEA_COMPONENT_NODES:
			return true
	return false


func _graph_path(start: Vector2, finish: Vector2) -> PackedVector2Array:
	var start_nodes := _visible_nodes(start)
	var finish_nodes := _visible_nodes(finish)
	if start_nodes.is_empty() or finish_nodes.is_empty():
		return PackedVector2Array()
	var start_id := _add_temp_point(start, start_nodes)
	var finish_id := _add_temp_point(finish, finish_nodes)
	var ids := _astar.get_id_path(start_id, finish_id)
	_astar.remove_point(start_id)
	_astar.remove_point(finish_id)
	if ids.is_empty() or ids.size() > MAX_PATH_NODES:
		return PackedVector2Array()
	var points := PackedVector2Array([start])
	for i in range(1, ids.size() - 1):
		points.append(_node_geo[ids[i]])
	points.append(finish)
	return _string_pull(points)


## Removes intermediate points while the straight line past them stays clear.
func _string_pull(points: PackedVector2Array) -> PackedVector2Array:
	var result := PackedVector2Array([points[0]])
	var anchor := 0
	while anchor < points.size() - 1:
		var reach := anchor + 1
		while reach + 1 < points.size() and is_segment_navigable(points[anchor], points[reach + 1]):
			reach += 1
		result.append(points[reach])
		anchor = reach
	return result


## Graph nodes with a clear line from `point`, nearest first (at most CONNECT_CANDIDATES).
func _visible_nodes(point: Vector2) -> PackedInt32Array:
	var cell := grid.geo_to_cell(point)
	if grid.wraps:
		cell.x = fposmod(cell.x, grid.columns)
	# The radii are in cells of the first level below the root where there is
	# one (Europe): the same physical reach as before inside Europe.
	var scale := grid.cells_per_degree / grid.child_at(point).cells_per_degree
	for radius in CONNECT_RADII:
		var candidates := _nodes_near(cell, radius * scale)
		var visible := PackedInt32Array()
		for id in candidates:
			if is_segment_navigable(point, _node_geo[id]):
				visible.append(id)
				if visible.size() >= CONNECT_CANDIDATES:
					break
		if not visible.is_empty():
			return visible
	return PackedInt32Array()


func _nodes_near(cell: Vector2, radius: float) -> PackedInt32Array:
	var found: Array = []
	var b0 := Vector2i(floori((cell.x - radius) / BUCKET_CELLS), floori((cell.y - radius) / BUCKET_CELLS))
	var b1 := Vector2i(floori((cell.x + radius) / BUCKET_CELLS), floori((cell.y + radius) / BUCKET_CELLS))
	var columns := float(grid.columns)
	var seen := {}
	for by in range(b0.y, b1.y + 1):
		for bx in range(b0.x, b1.x + 1):
			var key := _bucket_key(bx, by)
			if seen.has(key):
				continue
			seen[key] = true
			for id: int in _buckets.get(key, []):
				var d := _node_cell[id] - cell
				if grid.wraps:
					d.x = fposmod(d.x + columns * 0.5, columns) - columns * 0.5
				var d2 := d.length_squared()
				if d2 <= radius * radius:
					found.append([d2, id])
	found.sort()
	var ids := PackedInt32Array()
	for entry: Array in found:
		ids.append(entry[1])
	return ids


func _add_temp_point(point: Vector2, neighbours: PackedInt32Array) -> int:
	var id := _node_geo.size() + 1 + (_next_temp_id % 2)
	_next_temp_id += 1
	if _astar.has_point(id):
		_astar.remove_point(id)
	_astar.add_point(id, _project(point))
	for node in neighbours:
		_astar.connect_points(id, node)
	return id


# --- Canals --------------------------------------------------------------------------------

## Adds the canals as chains of graph points, joined to the sea graph at both
## entrances. A canal whose entrance is not open water here is left out.
func _add_canals() -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(CANALS))
	if not data is Dictionary:
		return
	for entry: Dictionary in data.get("canals", []):
		var points := PackedVector2Array()
		for p: Array in entry.points:
			points.append(Vector2(float(p[0]), float(p[1])))
		if points.size() < 2 or not is_point_navigable(points[0]) or not is_point_navigable(points[points.size() - 1]):
			continue
		var head := _visible_nodes(points[0])
		var tail := _visible_nodes(points[points.size() - 1])
		if head.is_empty() or tail.is_empty():
			push_warning("Canal %s: an entrance does not reach the sea graph." % entry.id)
			continue
		var ids := PackedInt32Array()
		for p in points:
			var id := _node_geo.size()
			_node_geo.append(p)
			_node_cell.append(grid.geo_to_cell(p))
			_node_component.append(_node_component[head[0]])
			_astar.add_point(id, _project(p))
			if not ids.is_empty():
				_astar.connect_points(ids[ids.size() - 1], id)
			ids.append(id)
		for node in head:
			_astar.connect_points(ids[0], node)
		for node in tail:
			_astar.connect_points(ids[ids.size() - 1], node)
		# The two seas are one piece of water now.
		var a := _node_component[head[0]]
		var b := _node_component[tail[0]]
		if a != b:
			var merged: int = _component_size.get(a, 0) + _component_size.get(b, 0)
			_component_size[a] = merged
			_component_size[b] = merged
		canals.append({"id": StringName(entry.id), "name": String(entry.name), "points": points, "nodes": ids})


## The canal (its entry, see `canals`) a position lies in, or {} when none.
func canal_at(geo: Vector2) -> Dictionary:
	for canal in canals:
		var points: PackedVector2Array = canal.points
		for i in range(1, points.size()):
			if GeoMath.distance_to_segment_nm(geo, points[i - 1], points[i]) <= CANAL_WIDTH_NM:
				return canal
	return {}


## True for a straight piece of a course that runs along one canal: both ends
## on the same reach of its centreline (a reach joins two of its points).
func is_canal_segment(a: Vector2, b: Vector2) -> bool:
	for canal in canals:
		var points: PackedVector2Array = canal.points
		for i in range(1, points.size()):
			if GeoMath.distance_to_segment_nm(a, points[i - 1], points[i]) <= CANAL_WIDTH_NM \
					and GeoMath.distance_to_segment_nm(b, points[i - 1], points[i]) <= CANAL_WIDTH_NM:
				return true
	return false


func _load_graph(nodes: Array, edges: Array) -> void:
	var merged := _merge(grid, nodes, edges)
	var cells: PackedVector2Array = merged.cells
	var geos: PackedVector2Array = merged.geo
	var removed: Dictionary = merged.removed
	var all_edges: PackedInt32Array = merged.edges
	var count := cells.size()
	_node_geo = geos
	_node_cell = cells
	_astar.reserve_space(count + 4)
	_bucket_columns = grid.columns / BUCKET_CELLS + 1
	for i in count:
		_astar.add_point(i, _project(geos[i]))
		if removed.has(i):
			_astar.set_point_disabled(i, true)
			continue
		var bucket := _bucket_key(floori(cells[i].x / BUCKET_CELLS), floori(cells[i].y / BUCKET_CELLS))
		if not _buckets.has(bucket):
			_buckets[bucket] = []
		_buckets[bucket].append(i)
	# Union-find over the edges to know which connected piece each node is in.
	var parent := PackedInt32Array()
	parent.resize(count)
	for i in count:
		parent[i] = i
	for i in range(0, all_edges.size(), 2):
		var a := all_edges[i]
		var b := all_edges[i + 1]
		if removed.has(a) or removed.has(b):
			continue
		_astar.connect_points(a, b)
		var ra := _find(parent, a)
		var rb := _find(parent, b)
		if ra != rb:
			parent[ra] = rb
	_node_component.resize(count)
	for i in count:
		var root := _find(parent, i)
		_node_component[i] = root
		_component_size[root] = _component_size.get(root, 0) + 1


## One level of the graph hierarchy with its regions merged in, recursively:
## {"cells" (this level's cell units), "geo", "edges", "removed"}. A region's
## nodes replace this level's nodes inside it (those are "removed"); seam
## links join the two; this level's edges that cross a region without being
## clear on its finer raster are left out (Iterations 14 and 16).
func _merge(level: NavGrid, nodes: Array, edges: Array) -> Dictionary:
	var cells := PackedVector2Array()
	var geos := PackedVector2Array()
	var index := {}
	var removed := {}
	for i in nodes.size() / 2:
		var key := Vector2i(int(nodes[i * 2]), int(nodes[i * 2 + 1]))
		index[key] = i
		var cell := Vector2(key) + Vector2(0.5, 0.5)
		cells.append(cell)
		geos.append(level.cell_to_geo(cell))
		for region in level.regions:
			if region.get_base_rect().has_point(cell):
				removed[i] = true
	var all_edges := PackedInt32Array()
	for i in range(0, edges.size(), 2):
		all_edges.append(int(edges[i]))
		all_edges.append(int(edges[i + 1]))
	var blocked := {}
	for region in level.regions:
		var data := _child_graph(region)
		var child := _merge(region, data.get("nodes", []), data.get("edges", []))
		var offset := cells.size()
		var child_cells: PackedVector2Array = child.cells
		var child_geo: PackedVector2Array = child.geo
		for j in child_cells.size():
			cells.append(Vector2(region.base_cell) + child_cells[j] / region.factor)
			geos.append(child_geo[j])
		for e in child.edges:
			all_edges.append(offset + e)
		for r: int in child.removed:
			removed[offset + r] = true
		for link: Array in data.get("seam", []):
			var base_node: Variant = index.get(Vector2i(int(link[0]), int(link[1])))
			if base_node != null:
				all_edges.append(int(base_node))
				all_edges.append(offset + int(link[2]))
		for pair: Array in data.get("blocked_base_edges", []):
			var a: Variant = index.get(Vector2i(int(pair[0]), int(pair[1])))
			var b: Variant = index.get(Vector2i(int(pair[2]), int(pair[3])))
			if a != null and b != null:
				blocked[Vector2i(mini(a, b), maxi(a, b))] = true
	if not blocked.is_empty():
		var kept := PackedInt32Array()
		for i in range(0, all_edges.size(), 2):
			var a := all_edges[i]
			var b := all_edges[i + 1]
			if not blocked.has(Vector2i(mini(a, b), maxi(a, b))):
				kept.append(a)
				kept.append(b)
		all_edges = kept
	return {"cells": cells, "geo": geos, "edges": all_edges, "removed": removed}


## A region's graph data: Europe's own graph and its link to the world, or a
## detail region's graph.json (nodes, edges, seam, blocked_base_edges).
func _child_graph(region: NavGrid) -> Dictionary:
	if region.region_id == "europe":
		var graph: Variant = JSON.parse_string(FileAccess.get_file_as_string(DEFAULT_GRAPH))
		var link: Variant = JSON.parse_string(FileAccess.get_file_as_string(WORLD_EUROPE_LINK))
		var data: Dictionary = graph if graph is Dictionary else {}
		if link is Dictionary:
			data["seam"] = link.get("seam", [])
		return data
	return _region_graph(region)


func _bucket_key(bx: int, by: int) -> int:
	if grid.wraps:
		bx = posmod(bx, _bucket_columns)
	return by * _bucket_columns + bx


## A region's route graph (graph.json in its folder).
func _region_graph(region: NavGrid) -> Dictionary:
	var index: Variant = JSON.parse_string(FileAccess.get_file_as_string(NavGrid.REGIONS_INDEX))
	if index is Dictionary:
		for entry: Dictionary in index.get("regions", []):
			if entry.get("id", "") == region.region_id:
				var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(String(entry.folder).path_join("graph.json")))
				return data if data is Dictionary else {}
	return {}


static func _find(parent: PackedInt32Array, a: int) -> int:
	while parent[a] != a:
		parent[a] = parent[parent[a]]
		a = parent[a]
	return a


## A position as a point on a sphere of the Earth's radius (nautical miles).
func _project(geo: Vector2) -> Vector3:
	var lat := deg_to_rad(geo.y)
	var lon := deg_to_rad(geo.x)
	return Vector3(cos(lat) * cos(lon), cos(lat) * sin(lon), sin(lat)) * GeoMath.EARTH_RADIUS_NM


func _describe_leg_failure(leg_number: int, leg_count: int, code: String) -> String:
	var where := "" if leg_count == 1 else Loc.t(" (leg %d)") % leg_number
	match code:
		"start_blocked":
			return Loc.t("Waypoint %d is on land or too close to the coast.") % (leg_number - 1) if leg_number > 1 \
				else Loc.t("The vessel's position is not in navigable water.")
		"end_blocked":
			return Loc.t("Waypoint %d is on land or too close to the coast.") % leg_number
		"start_port":
			return Loc.t("The departure harbour has no water access in the chart data.")
		"end_port":
			return Loc.t("The destination harbour cannot be reached in the chart data.")
		_:
			return Loc.t("No sea route found%s. The waters may not be connected in the chart data.") % where


static func _dedupe(path: PackedVector2Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for p in path:
		if result.is_empty() or not GeoMath.same_position(result[result.size() - 1], p):
			result.append(p)
	return result
