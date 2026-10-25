class_name HighlightResolver
extends RefCounted
## Finds what the player should see highlighted for a station (Iteration 12):
## the actual object in the illustrated world, not a ring around an invisible
## area. Works from each boat's own layout, so no per-boat offsets:
##   1. a node in the "interaction_highlight" group that names this
##      interaction id (meta "highlight_for") and offers
##      get_highlight_outline() (global points): the hat hook, shore signs,
##      the gangplank, the Go Ashore board;
##   2. otherwise the nearest furniture fixture (BoatFixture in
##      Layout/Collision) with one of the names listed for the interaction
##      (the chart table for "nav_table", the berth for "bed", …);
##   3. otherwise the station's own area, drawn as a small soft outline.
## Interaction ranges are not changed: only what is drawn.

const GROUP := &"interaction_highlight"
const META_FOR := &"highlight_for"

## Fixture names that are the visible object for an interaction (first match
## by distance wins).
const FIXTURES := {
	&"nav_table": ["NavTable", "NavDesk", "ChartTable"],
	&"bed": ["VBerth", "OwnerBerth", "Berth", "GuestBerth"],
	&"provisions": ["Galley", "GalleySide", "GalleyAft"],
	&"work": ["SaloonTable", "Desk", "Table"],
	&"helm": ["Wheel", "Tiller", "Pedestal"],
	&"companionway": ["CompanionwaySteps"],
}
## A fixture farther than this from the station is not "its" object.
const MAX_FIXTURE_DISTANCE := 90.0


## Global outline points for `station` in `area`, or an empty array when the
## station should use its own area (see 3. above).
static func resolve(area: Node, station: Interactable) -> PackedVector2Array:
	for node in area.get_tree().get_nodes_in_group(GROUP):
		if area.is_ancestor_of(node) and StringName(node.get_meta(META_FOR, &"")) == station.interaction_id \
				and node.has_method("get_highlight_outline"):
			var outline: PackedVector2Array = node.get_highlight_outline()
			if outline.size() >= 3:
				return outline
	var names: Array = FIXTURES.get(station.interaction_id, [])
	var collision := area.get_node_or_null(^"Layout/Collision")
	if names.is_empty() or collision == null:
		return PackedVector2Array()
	var best := PackedVector2Array()
	var best_distance := MAX_FIXTURE_DISTANCE
	for child in collision.get_children():
		var fixture := child as BoatFixture
		if fixture == null or not String(fixture.name) in names:
			continue
		var outline := PackedVector2Array()
		for p in fixture.get_points():
			outline.append(fixture.to_global(p))
		var distance := _distance_to_polygon(station.global_position, outline)
		if distance < best_distance:
			best_distance = distance
			best = outline
	return best


static func _distance_to_polygon(p: Vector2, polygon: PackedVector2Array) -> float:
	if Geometry2D.is_point_in_polygon(p, polygon):
		return 0.0
	var nearest := INF
	for i in polygon.size():
		var closest := Geometry2D.get_closest_point_to_segment(p, polygon[i], polygon[(i + 1) % polygon.size()])
		nearest = minf(nearest, p.distance_to(closest))
	return nearest


## A rounded rectangle outline (local points) for highlight providers.
static func rounded_rect(rect: Rect2, radius := 8.0, steps := 4) -> PackedVector2Array:
	var points := PackedVector2Array()
	var r := minf(radius, minf(rect.size.x, rect.size.y) / 2.0)
	var corners := [rect.position + Vector2(rect.size.x - r, r), rect.end - Vector2(r, r),
		Vector2(rect.position.x + r, rect.end.y - r), rect.position + Vector2(r, r)]
	for c in 4:
		for k in steps + 1:
			var angle := -PI / 2.0 + (c + float(k) / steps) * PI / 2.0
			points.append(corners[c] + Vector2.from_angle(angle) * r)
	return points


## A circle outline (local points).
static func circle(center: Vector2, radius: float, steps := 24) -> PackedVector2Array:
	var points := PackedVector2Array()
	for k in steps:
		points.append(center + Vector2.from_angle(TAU * k / steps) * radius)
	return points
