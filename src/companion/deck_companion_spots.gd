class_name DeckCompanionSpots
extends Node2D
## Where the companion may rest on deck (Iteration 18), worked out from each
## boat's own layout so every vessel gets safe places without hand-placed
## markers: three resting places (deck_0 aft, deck_1 amidships, deck_2
## forward) and the way up (deck_entry, at the companionway).
##
## A place is safe when the animal's whole body (a disc of BODY_RADIUS) is
## inside the lifeline - never over the water or beyond the rail - clear of
## every solid fitting (coachroof, benches, mast, wheel: it does not clip
## through them), and well away from the helm and the other stations so it
## never blocks the captain. Walks between places follow straight lines that
## stay aboard (path()). Computed once when the deck is built.

const BODY_RADIUS := 16.0
const STEP := 8.0
const STATION_CLEARANCE := 55.0
const HELM_CLEARANCE := 85.0
const FIXTURE_MARGIN := 10.0
## Places and walks are planned this much further inside than is_safe()
## demands, so a step between two checked points never grazes the rail.
const PLAN_MARGIN := 3.0
## The deck's thirds where the three places are looked for (fractions of the
## boat's length, stern to bow).
const BANDS := [[0.08, 0.38], [0.38, 0.62], [0.62, 0.9]]

var area: BoatArea
var _fixtures: Array[PackedVector2Array] = []
## Inside the lifeline only (never the pontoon or the quay, even when moored).
var _aboard := PackedVector2Array()


## Builds the markers for `boat_area` (deck only).
func setup(boat_area: BoatArea) -> void:
	area = boat_area
	name = "DeckCompanionSpots"
	var lifeline := area.get_node_or_null(^"Layout/Collision/Lifeline/CollisionPolygon2D") as CollisionPolygon2D
	if lifeline:
		_aboard = (area.global_transform.affine_inverse() * lifeline.global_transform) * lifeline.polygon
	_collect_fixtures()
	var entry := _entry_point()
	_marker("deck_entry", entry)
	var spots := compute_spots()
	for i in spots.size():
		_marker("deck_%d" % i, spots[i])


func _marker(marker_name: String, at: Vector2) -> void:
	var marker := Marker2D.new()
	marker.name = marker_name
	marker.position = at
	add_child(marker)


func _collect_fixtures() -> void:
	var collision := area.get_node_or_null(^"Layout/Collision")
	if collision == null:
		return
	for child in collision.get_children():
		var fixture := child as BoatFixture
		if fixture == null or not fixture.solid:
			continue
		var outline := fixture.transform * fixture.get_points()
		var grown := Geometry2D.offset_polygon(outline, FIXTURE_MARGIN)
		_fixtures.append(grown[0] if not grown.is_empty() else outline)


func _stations() -> Array[Vector2]:
	var points: Array[Vector2] = []
	for station in area.find_children("*", "Interactable", true, false):
		if (station as Node).get_parent().name == &"Stations" or (station as Interactable).interaction_id in [&"helm", &"companionway"]:
			points.append(area.to_local((station as Node2D).global_position))
	return points


func _helm() -> Vector2:
	var helm := area.get_node_or_null(^"Layout/Stations/Helm") as Node2D
	return helm.position if helm else Vector2.INF


func _entry_point() -> Vector2:
	var way := area.get_node_or_null(^"Layout/Stations/Companionway") as Node2D
	var at := way.position if way else area.walkable_bounds.get_center()
	# Just beside the opening, on deck.
	return nearest_safe(at, false)


## Whether the animal can stand at `p` (see the class notes); with
## `resting`, also clear of the stations and the helm; `margin` widens the
## body (used when planning).
func is_safe(p: Vector2, resting := true, margin := 0.0) -> bool:
	var radius := BODY_RADIUS + margin
	if not is_aboard(p) or not area.walkable_bounds.grow(-radius).has_point(p):
		return false
	# The whole body inside the lifeline: the centre is in, and no edge of the
	# lifeline comes closer than the body's radius.
	var n := _aboard.size()
	if n >= 3:
		for i in n:
			var a := _aboard[i]
			var b := _aboard[(i + 1) % n]
			if p.distance_squared_to(Geometry2D.get_closest_point_to_segment(p, a, b)) < radius * radius:
				return false
	for outline in _fixtures:
		if Geometry2D.is_point_in_polygon(p, outline):
			return false
	if resting:
		var helm := _helm()
		if helm != Vector2.INF and p.distance_to(helm) < HELM_CLEARANCE:
			return false
		for station in _stations():
			if p.distance_to(station) < STATION_CLEARANCE:
				return false
	return true


## Inside the boat's lifeline (not over the water, not on the pontoon).
func is_aboard(p: Vector2) -> bool:
	if not area.walkable_bounds.has_point(p):
		return false
	return _aboard.size() < 3 or Geometry2D.is_point_in_polygon(p, _aboard)


func nearest_safe(at: Vector2, resting := true) -> Vector2:
	var best := at
	var best_d := INF
	var bounds := area.walkable_bounds
	var y := bounds.position.y
	while y <= bounds.end.y:
		var x := bounds.position.x
		while x <= bounds.end.x:
			var p := Vector2(x, y)
			var d := p.distance_squared_to(at)
			if d < best_d and is_safe(p, resting, PLAN_MARGIN):
				best = p
				best_d = d
			x += STEP
		y += STEP
	return best


## The three resting places, aft to forward.
func compute_spots() -> Array[Vector2]:
	var bounds := area.walkable_bounds
	var result: Array[Vector2] = []
	for band: Array in BANDS:
		var target := Vector2(lerpf(bounds.position.x, bounds.end.x, (float(band[0]) + float(band[1])) / 2.0), bounds.get_center().y)
		var best := Vector2.INF
		var best_d := INF
		var y := bounds.position.y
		while y <= bounds.end.y:
			var x := lerpf(bounds.position.x, bounds.end.x, float(band[0]))
			while x <= lerpf(bounds.position.x, bounds.end.x, float(band[1])):
				var p := Vector2(x, y)
				var d := p.distance_squared_to(target)
				if d < best_d and is_safe(p, true, PLAN_MARGIN):
					best = p
					best_d = d
				x += STEP
			y += STEP
		result.append(best if best != Vector2.INF else nearest_safe(target))
	return result


func get_spot(index: int) -> Vector2:
	var marker := get_node_or_null(NodePath("deck_%d" % clampi(index, 0, 2))) as Node2D
	return marker.position if marker else Vector2.ZERO


func get_entry() -> Vector2:
	var marker := get_node_or_null(^"deck_entry") as Node2D
	return marker.position if marker else Vector2.ZERO


## A walk from `from` to `to` that stays aboard and clear of fittings: straight
## when it can, otherwise along the safe grid (a breadth-first search over
## STEP-sized cells, eight ways), then pulled tight so it walks in a few
## straight legs rather than a staircase.
func path(from: Vector2, to: Vector2) -> PackedVector2Array:
	if _line_ok(from, to):
		return PackedVector2Array([from, to])
	_build_grid()
	var start := _anchor_cell(from)
	var goal := _anchor_cell(to)
	var came := {start: start}
	var queue: Array[Vector2i] = [start]
	var head := 0
	while head < queue.size():
		var cell := queue[head]
		head += 1
		if cell == goal:
			break
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
			var next := cell + d
			# Diagonals only where both sides are clear (no cutting corners).
			if not came.has(next) and _cell_safe(next) and _cell_safe(cell + Vector2i(d.x, 0)) and _cell_safe(cell + Vector2i(0, d.y)):
				came[next] = cell
				queue.append(next)
	if not came.has(goal):
		return PackedVector2Array([from, to])
	var cells: Array[Vector2] = [to]
	var at := goal
	while at != start:
		at = came[at]
		cells.push_front(_cell_centre(at))
	cells.push_front(from)
	# Pull tight: from each corner, go as far ahead as a straight line allows.
	var result := PackedVector2Array([from])
	var i := 0
	while i < cells.size() - 1:
		var j := cells.size() - 1
		while j > i + 1 and not _line_ok(cells[i], cells[j]):
			j -= 1
		result.append(cells[j])
		i = j
	return result


var _grid := PackedByteArray()
var _grid_size := Vector2i.ZERO


func _build_grid() -> void:
	if not _grid.is_empty():
		return
	var bounds := area.walkable_bounds
	_grid_size = Vector2i(int(bounds.size.x / STEP) + 1, int(bounds.size.y / STEP) + 1)
	_grid.resize(_grid_size.x * _grid_size.y)
	for y in _grid_size.y:
		for x in _grid_size.x:
			_grid[y * _grid_size.x + x] = 1 if is_safe(_cell_centre(Vector2i(x, y)), false, PLAN_MARGIN) else 0


## A safe cell next to `p` that a straight line from `p` reaches.
func _anchor_cell(p: Vector2) -> Vector2i:
	var centre := _cell_of(p)
	var best := _cell_of(nearest_safe(p, false))
	var best_d := INF
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var cell := centre + Vector2i(dx, dy)
			var d := _cell_centre(cell).distance_squared_to(p)
			if d < best_d and _cell_safe(cell) and _line_ok(p, _cell_centre(cell)):
				best = cell
				best_d = d
	return best


func _cell_of(p: Vector2) -> Vector2i:
	var local := (p - area.walkable_bounds.position) / STEP
	return Vector2i(roundi(local.x), roundi(local.y))


func _cell_centre(cell: Vector2i) -> Vector2:
	return area.walkable_bounds.position + Vector2(cell) * STEP


func _cell_safe(cell: Vector2i) -> bool:
	if cell.x < 0 or cell.y < 0 or cell.x >= _grid_size.x or cell.y >= _grid_size.y:
		return false
	return _grid[cell.y * _grid_size.x + cell.x] == 1


func _line_ok(a: Vector2, b: Vector2) -> bool:
	var n := maxi(int(a.distance_to(b) / 3.0), 1)
	for i in n + 1:
		if not is_safe(a.lerp(b, float(i) / n), false, PLAN_MARGIN):
			return false
	return true
