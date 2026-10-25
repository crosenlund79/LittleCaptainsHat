class_name SeaRouter
extends RefCounted
## Calculates sea routes that never cross land, and validates routes.
##
## Method (see ARCHITECTURE.md, "Route calculation"):
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

const DEFAULT_GRAPH := "res://data/navigation/europe_route_graph.json"

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
const BUCKET_CELLS := 32
## Upper bound on the A* result; protects against pathological data.
const MAX_PATH_NODES := 20000
const LEG_CACHE_LIMIT := 256
## Harbour approaches must reach a graph component of at least this many nodes,
## so they never end in an enclosed pocket of water (e.g. a dock basin).
const MIN_SEA_COMPONENT_NODES := 50

## Graph positions use an azimuthal equidistant projection centred on Europe,
## so A* costs and estimates approximate distances in nautical miles.
const PROJECTION_CENTER := Vector2(10.0, 52.0)

static var _default: SeaRouter

var grid: NavGrid
var catalog: PortCatalog
var _astar := AStar2D.new()
var _node_geo := PackedVector2Array()
var _node_cell := PackedVector2Array()
var _node_component := PackedInt32Array()
var _component_size := {}
var _buckets := {}
var _bucket_columns := 0
var _next_temp_id := 0
var _approach_cache := {}
var _leg_cache := {}


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


static func get_default() -> SeaRouter:
	if _default == null:
		_default = SeaRouter.load_from(NavGrid.DEFAULT_MASK, NavGrid.DEFAULT_META, DEFAULT_GRAPH)
	return _default


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


## Checks every segment of a route. Returns "" when valid, otherwise the reason.
## Allowed segments: navigable water everywhere; harbour approaches near the
## route's origin/destination port in approach-class water; and the short berth
## link that starts or ends exactly at a port coordinate.
func validate_route(route: PlannedRoute) -> String:
	if route == null:
		return "There is no route."
	var path := route.path
	if path.size() < 2:
		return "The route has no course."
	var destination := catalog.get_port(route.destination_port_id)
	if destination == null:
		return "The destination is unknown."
	if not path[0].is_equal_approx(route.origin_position):
		return "The route does not start at the vessel's position."
	if not path[path.size() - 1].is_equal_approx(destination.get_geo_position()):
		return "The route does not end at the destination."
	var ports: Array[Vector2] = [destination.get_geo_position()]
	var origin := catalog.get_port(route.origin_port_id)
	if origin:
		ports.append(origin.get_geo_position())
	for waypoint in route.waypoints:
		if not is_point_navigable(waypoint):
			return "A waypoint is on land or too close to the coast."
	for i in range(1, path.size()):
		if not _is_segment_allowed(path[i - 1], path[i], ports):
			return "Leg %d of the course crosses land." % i
	return ""


func _is_segment_allowed(a: Vector2, b: Vector2, ports: Array[Vector2]) -> bool:
	if grid.is_geo_line_clear(a, b, NavGrid.NAVIGABLE):
		return true
	for port in ports:
		var near_a := GeoMath.rhumb_distance_nm(port, a) <= MAX_APPROACH_NM
		var near_b := GeoMath.rhumb_distance_nm(port, b) <= MAX_APPROACH_NM
		if not (near_a and near_b):
			continue
		if grid.is_geo_line_clear(a, b, NavGrid.APPROACH):
			return true
		# Berth link: from the port coordinate itself to approach water nearby.
		var berth := a if a.is_equal_approx(port) else (b if b.is_equal_approx(port) else Vector2.INF)
		var other := b if berth == a else a
		if berth != Vector2.INF and GeoMath.rhumb_distance_nm(berth, other) <= BERTH_RADIUS_NM \
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


# --- Planning ----------------------------------------------------------------------------

## Plans a complete route: origin (a port id, or "" for a position at sea),
## optional waypoints in order, and a destination port. Each leg is routed
## separately; the result lists every leg so invalid ones can be shown.
func plan_route(origin_port_id: StringName, origin_position: Vector2, waypoints: Array[Vector2],
		destination_port_id: StringName) -> RouteResult:
	var result := RouteResult.new()
	var destination := catalog.get_port(destination_port_id)
	if destination == null:
		result.error = "Choose a destination port."
		return result
	if origin_port_id == destination_port_id and waypoints.is_empty():
		result.error = "The vessel is already in %s." % destination.display_name
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
	if start.is_equal_approx(finish) or is_segment_navigable(start, finish):
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


## The fixed part of a leg at one end: [point] for open water, or the harbour
## approach [port, ..., open-water point] for a port. Empty if unreachable.
func _endpoint_path(point: Vector2, port_id: StringName) -> PackedVector2Array:
	if port_id.is_empty():
		return PackedVector2Array([point]) if is_point_navigable(point) else PackedVector2Array()
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
	var window := APPROACH_WINDOW_CELLS * cells_grid.factor
	var center := cells_grid.geo_to_cell(origin)
	var cx := floori(center.x)
	var cy := floori(center.y)
	var previous := {}
	var queue: Array[Vector2i] = []
	# Berth: all approach water within the berth radius may serve as a start.
	var berth_cells := (ceili(BERTH_RADIUS_NM * 2.0) + 2) * cells_grid.factor
	for y in range(cy - berth_cells, cy + berth_cells + 1):
		for x in range(cx - berth_cells, cx + berth_cells + 1):
			if cells_grid.get_class_at(x, y) >= NavGrid.APPROACH \
					and GeoMath.rhumb_distance_nm(origin, cells_grid.cell_center_geo(x, y)) <= BERTH_RADIUS_NM:
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
					and GeoMath.rhumb_distance_nm(origin, cells_grid.cell_center_geo(next.x, next.y)) <= MAX_APPROACH_NM:
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
	for radius in CONNECT_RADII:
		var candidates := _nodes_near(cell, radius)
		var visible := PackedInt32Array()
		for id in candidates:
			if is_segment_navigable(point, _node_geo[id]):
				visible.append(id)
				if visible.size() >= CONNECT_CANDIDATES:
					break
		if not visible.is_empty():
			return visible
	return PackedInt32Array()


func _nodes_near(cell: Vector2, radius: int) -> PackedInt32Array:
	var found: Array = []
	var b0 := Vector2i(floori((cell.x - radius) / BUCKET_CELLS), floori((cell.y - radius) / BUCKET_CELLS))
	var b1 := Vector2i(floori((cell.x + radius) / BUCKET_CELLS), floori((cell.y + radius) / BUCKET_CELLS))
	for by in range(b0.y, b1.y + 1):
		for bx in range(b0.x, b1.x + 1):
			for id: int in _buckets.get(by * _bucket_columns + bx, []):
				var d := _node_cell[id].distance_squared_to(cell)
				if d <= radius * radius:
					found.append([d, id])
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


func _load_graph(nodes: Array, edges: Array) -> void:
	# Regional detail (Iteration 14): base nodes inside a region are replaced
	# by the region's own nodes; seam links join the two, and base edges that
	# cross a region without being clear on its raster are left out.
	var cells := PackedVector2Array()
	var base_index := {}
	var removed := {}
	for i in nodes.size() / 2:
		var key := Vector2i(int(nodes[i * 2]), int(nodes[i * 2 + 1]))
		base_index[key] = i
		cells.append(Vector2(key) + Vector2(0.5, 0.5))
		for region in grid.regions:
			if region.get_base_rect().has_point(cells[i]):
				removed[i] = true
	var all_edges := PackedInt32Array()
	for i in range(0, edges.size(), 2):
		all_edges.append(int(edges[i]))
		all_edges.append(int(edges[i + 1]))
	var blocked := {}
	for region in grid.regions:
		var data := _region_graph(region)
		var offset := cells.size()
		var region_nodes: Array = data.get("nodes", [])
		for j in region_nodes.size() / 2:
			var fine := Vector2(region_nodes[j * 2] + 0.5, region_nodes[j * 2 + 1] + 0.5)
			cells.append(Vector2(region.base_cell) + fine / region.factor)
		var region_edges: Array = data.get("edges", [])
		for j in region_edges.size():
			all_edges.append(offset + int(region_edges[j]))
		for link: Array in data.get("seam", []):
			var base_node: Variant = base_index.get(Vector2i(int(link[0]), int(link[1])))
			if base_node != null:
				all_edges.append(int(base_node))
				all_edges.append(offset + int(link[2]))
		for pair: Array in data.get("blocked_base_edges", []):
			var a: Variant = base_index.get(Vector2i(int(pair[0]), int(pair[1])))
			var b: Variant = base_index.get(Vector2i(int(pair[2]), int(pair[3])))
			if a != null and b != null:
				blocked[Vector2i(mini(a, b), maxi(a, b))] = true
	var count := cells.size()
	_node_geo.resize(count)
	_node_cell.resize(count)
	_astar.reserve_space(count + 4)
	_bucket_columns = grid.columns / BUCKET_CELLS + 1
	for i in count:
		var cell := cells[i]
		var geo := grid.cell_to_geo(cell)
		_node_cell[i] = cell
		_node_geo[i] = geo
		_astar.add_point(i, _project(geo))
		if removed.has(i):
			_astar.set_point_disabled(i, true)
			continue
		var bucket := floori(cell.y / BUCKET_CELLS) * _bucket_columns + floori(cell.x / BUCKET_CELLS)
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
		if removed.has(a) or removed.has(b) or blocked.has(Vector2i(mini(a, b), maxi(a, b))):
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


## Azimuthal equidistant projection (nautical miles) around PROJECTION_CENTER.
func _project(geo: Vector2) -> Vector2:
	var lat0 := deg_to_rad(PROJECTION_CENTER.y)
	var lat := deg_to_rad(geo.y)
	var d_lon := deg_to_rad(geo.x - PROJECTION_CENTER.x)
	var cos_c := clampf(sin(lat0) * sin(lat) + cos(lat0) * cos(lat) * cos(d_lon), -1.0, 1.0)
	var c := acos(cos_c)
	var k := c / sin(c) if c > 1e-9 else 1.0
	return Vector2(k * cos(lat) * sin(d_lon),
		-k * (cos(lat0) * sin(lat) - sin(lat0) * cos(lat) * cos(d_lon))) * GeoMath.EARTH_RADIUS_NM


func _describe_leg_failure(leg_number: int, leg_count: int, code: String) -> String:
	var where := "" if leg_count == 1 else " (leg %d)" % leg_number
	match code:
		"start_blocked":
			return "Waypoint %d is on land or too close to the coast." % (leg_number - 1) if leg_number > 1 \
				else "The vessel's position is not in navigable water."
		"end_blocked":
			return "Waypoint %d is on land or too close to the coast." % leg_number
		"start_port":
			return "The departure harbour has no water access in the chart data."
		"end_port":
			return "The destination harbour cannot be reached in the chart data."
		_:
			return "No sea route found%s. The waters may not be connected in the chart data." % where


static func _dedupe(path: PackedVector2Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for p in path:
		if result.is_empty() or not result[result.size() - 1].is_equal_approx(p):
			result.append(p)
	return result
