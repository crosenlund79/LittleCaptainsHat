@tool
class_name ProceduralShape
extends Node2D
## Placeholder art: a filled shape with an outline and an optional label (the
## look of the original boat fixtures). Purely visual; the matching collision
## lives in the scene's Layout as a BoatFixture.

const LABEL_FONT: Font = preload("res://assets/fonts/Barlow-SemiBold.ttf")

@export var size := Vector2(100, 60):
	set(value):
		size = value
		queue_redraw()
@export var polygon := PackedVector2Array():
	set(value):
		polygon = value
		queue_redraw()
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


func get_points() -> PackedVector2Array:
	if polygon.size() >= 3:
		return polygon
	var half := size / 2.0
	return PackedVector2Array([
		Vector2(-half.x, -half.y), Vector2(half.x, -half.y),
		Vector2(half.x, half.y), Vector2(-half.x, half.y)])


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
	draw_string(LABEL_FONT, center + Vector2(-text_size.x / 2.0, label_size * 0.35), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, label_size, label_color)
