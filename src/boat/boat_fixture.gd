@tool
class_name BoatFixture
extends StaticBody2D
## Gameplay layout: the collision of a piece of furniture or a fitting.
##
## The shape is either a centred rectangle (`size`) or, when set, a custom
## `polygon` in local coordinates; collision is created from it. Set `solid`
## to false for things the player can walk over (hatches, floor panels).
##
## Fixtures draw nothing in the game: what the player sees comes from the
## scene's Visual (procedural art or sprites, see VesselVisual). In the editor
## a translucent outline is drawn so the layout can be seen and edited.

const EDITOR_FILL := Color(0.9, 0.35, 0.3, 0.18)
const EDITOR_OUTLINE := Color(0.9, 0.35, 0.3, 0.8)
const EDITOR_WALKABLE := Color(0.3, 0.8, 0.5, 0.7)

@export var size := Vector2(100, 60):
	set(value):
		size = value
		_rebuild()
@export var polygon := PackedVector2Array():
	set(value):
		polygon = value
		_rebuild()
@export var solid := true:
	set(value):
		solid = value
		_rebuild()

var _shape_owner := -1


func _ready() -> void:
	_rebuild()


func get_points() -> PackedVector2Array:
	if polygon.size() >= 3:
		return polygon
	var half := size / 2.0
	return PackedVector2Array([
		Vector2(-half.x, -half.y), Vector2(half.x, -half.y),
		Vector2(half.x, half.y), Vector2(-half.x, half.y)])


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _shape_owner == -1:
		_shape_owner = create_shape_owner(self)
	shape_owner_clear_shapes(_shape_owner)
	if solid:
		var shape := ConvexPolygonShape2D.new()
		shape.points = get_points()
		shape_owner_add_shape(_shape_owner, shape)
	queue_redraw()


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var points := get_points()
	if solid:
		draw_colored_polygon(points, EDITOR_FILL)
	var outline := points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, EDITOR_OUTLINE if solid else EDITOR_WALKABLE, 2.0)
