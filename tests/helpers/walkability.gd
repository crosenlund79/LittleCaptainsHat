class_name TestWalkability
extends RefCounted
## Test helper: where the player can actually walk in a boat area, found by a
## flood fill with the player's real collision circle against the real
## collision (grid of GRID units), and where stations can be used from.

const PLAYER_RADIUS := 20.0
## A station is usable when the player's centre gets this close to its shape
## (the player's reach circle has a radius of 46).
const USE_DISTANCE := 40.0
const GRID := 10.0


## Reachable player positions (local to the area) from `from`.
static func walkable_cells(area: BoatArea, from: Vector2) -> Array[Vector2]:
	var space := area.get_world_2d().direct_space_state
	var query := PhysicsShapeQueryParameters2D.new()
	var circle := CircleShape2D.new()
	circle.radius = PLAYER_RADIUS
	query.shape = circle
	query.collision_mask = area.player.collision_mask
	query.exclude = [area.player.get_rid()]
	var free := func(p: Vector2) -> bool:
		query.transform = Transform2D(0.0, area.to_global(p))
		return space.intersect_shape(query, 1).is_empty()
	var cells: Array[Vector2] = []
	if not free.call(from):
		return cells
	var seen := {from: true}
	var queue: Array[Vector2] = [from]
	var bounds := area.walkable_bounds.grow(60.0)
	while not queue.is_empty():
		var p: Vector2 = queue.pop_back()
		cells.append(p)
		for step in [Vector2(GRID, 0), Vector2(-GRID, 0), Vector2(0, GRID), Vector2(0, -GRID)]:
			var q: Vector2 = p + step
			if seen.has(q) or not bounds.has_point(q):
				continue
			seen[q] = true
			if free.call(q):
				queue.append(q)
	return cells


## Distance from `p` to the station's shape (0 inside).
static func distance_to_station(station: Interactable, p: Vector2) -> float:
	var shape := (station.get_node("CollisionShape2D") as CollisionShape2D).shape
	var local := p - station.position
	if shape is CircleShape2D:
		return maxf(local.length() - (shape as CircleShape2D).radius, 0.0)
	var half := (shape as RectangleShape2D).size / 2.0
	return (local.abs() - half).max(Vector2.ZERO).length()


## Places from which the station is in reach, nearest first.
static func use_points(station: Interactable, cells: Array[Vector2]) -> Array[Vector2]:
	var points: Array[Vector2] = []
	for c in cells:
		if distance_to_station(station, c) <= USE_DISTANCE:
			points.append(c)
	points.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.distance_to(station.position) < b.distance_to(station.position))
	return points


## The nearest reachable cell to `target` (Vector2.INF when there are none).
static func nearest(cells: Array[Vector2], target: Vector2) -> Vector2:
	var best := Vector2.INF
	for c in cells:
		if best == Vector2.INF or c.distance_to(target) < best.distance_to(target):
			best = c
	return best


## Distance from `p` to a BoatFixture's shape (0 inside).
static func distance_to_fixture(fixture: BoatFixture, p: Vector2) -> float:
	var points := fixture.get_points()
	var local := p - fixture.position
	if Geometry2D.is_point_in_polygon(local, points):
		return 0.0
	var best := INF
	for i in points.size():
		var closest := Geometry2D.get_closest_point_to_segment(local, points[i], points[(i + 1) % points.size()])
		best = minf(best, closest.distance_to(local))
	return best
