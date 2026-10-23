@tool
class_name BoatFixture
extends StaticBody2D
## Placeholder geometry for furniture and fittings: draws a filled shape with
## an outline and an optional label, and gives it matching collision.
##
## The shape is either a centred rectangle (`size`) or, when set, a custom
## `polygon` in local coordinates. Collision is created from the same shape so
## visuals and physics never drift apart. Set `solid` to false for things the
## player can walk over (hatches, floor panels).

const LABEL_FONT: Font = preload("res://assets/fonts/Barlow-SemiBold.ttf")

@export var size := Vector2(100, 60):
	set(value):
		size = value
		_rebuild()
@export var polygon := PackedVector2Array():
	set(value):
		polygon = value
		_rebuild()
@export var fill_color := Color("#7D6650"):
	set(value):
		fill_color = value
		queue_redraw()
@export var outline_color := Color(0.06, 0.12, 0.16, 0.6):
	set(value):
		outline_color = value
		queue_redraw()
@export var label := "":
	set(value):
		label = value
		queue_redraw()
@export var label_color := Color(0.94, 0.9, 0.8, 0.85)
@export var label_size := 15
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
	var points := get_points()
	draw_colored_polygon(points, fill_color)
	var outline := points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, outline_color, 2.0, true)
	if label.is_empty():
		return
	var text := label.to_upper()
	var text_size := LABEL_FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, label_size)
	var center := Vector2.ZERO
	for p in points:
		center += p
	center /= points.size()
	var origin := center + Vector2(-text_size.x / 2.0, label_size * 0.35)
	draw_string(LABEL_FONT, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1, label_size, label_color)
