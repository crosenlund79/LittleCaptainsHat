class_name HaulOutScene
extends Control
## A small illustration of the haul-out (Iteration 14): the boat in the slings
## of the yard's travel lift, lifted clear of the water (`lift` 0..1), weed on
## the bottom until it is scrubbed (`fouled` 0..1). Drawn in code, in the
## chart's quiet palette; catamarans hang as two hulls under a bridge deck.

const SKY_TOP := Color(0.62, 0.78, 0.86)
const SKY_BOTTOM := Color(0.86, 0.91, 0.9)
const WATER := Color(0.16, 0.42, 0.5)
const WATER_LINE := Color(0.5, 0.72, 0.76)
const QUAY := Color(0.52, 0.48, 0.42)
const LIFT := Color(0.2, 0.27, 0.33)
const SLING := Color(0.86, 0.62, 0.2)
const HULL := Color(0.96, 0.95, 0.91)
const HULL_SHADE := Color(0.82, 0.8, 0.74)
const BOTTOM := Color(0.62, 0.18, 0.16)
const WEED := Color(0.34, 0.45, 0.2)
const MAST := Color(0.75, 0.76, 0.74)

## 0: afloat, 1: lifted clear of the water.
var lift := 0.0:
	set(value):
		lift = clampf(value, 0.0, 1.0)
		queue_redraw()
## 0: a clean bottom, 1: well fouled.
var fouled := 0.0:
	set(value):
		fouled = clampf(value, 0.0, 1.0)
		queue_redraw()
var catamaran := false
var _drips := 0.0


func _ready() -> void:
	custom_minimum_size = Vector2(620, 240)
	clip_contents = true


func _process(delta: float) -> void:
	if lift > 0.05 and lift < 1.0 or lift >= 1.0 and _drips < 3.0:
		_drips += delta
		queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	var water_y := h * 0.66
	# Sky and water.
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(w, 0), Vector2(w, water_y), Vector2(0, water_y)]),
		PackedColorArray([SKY_TOP, SKY_TOP, SKY_BOTTOM, SKY_BOTTOM]))
	# Quays either side of the lifting dock.
	draw_rect(Rect2(0, water_y - 6.0, w * 0.17, h - water_y + 6.0), QUAY)
	draw_rect(Rect2(w * 0.83, water_y - 6.0, w * 0.17, h - water_y + 6.0), QUAY)
	# The boat: waterline at the surface when afloat, clear of it when lifted.
	var hull_w := w * 0.5
	var cx := w * 0.5
	var depth := h * 0.2
	var freeboard := h * 0.1
	var waterline := water_y - lift * (depth + 10.0)
	var deck := waterline - freeboard
	var mast_top := maxf(deck - h * 0.5, 0.0)
	draw_line(Vector2(cx - hull_w * 0.05, deck), Vector2(cx - hull_w * 0.05, mast_top), MAST, 3.0)
	if catamaran:
		draw_rect(Rect2(cx - hull_w * 0.5, deck, hull_w, freeboard * 0.55), HULL)
		for side in [-1.0, 1.0]:
			_draw_hull(Vector2(cx + side * hull_w * 0.33, deck), hull_w * 0.34, freeboard, depth * 0.7, waterline, false)
	else:
		_draw_hull(Vector2(cx, deck), hull_w, freeboard, depth, waterline, true)
	# Water in front of the hull while afloat.
	var front := PackedVector2Array([Vector2(w * 0.17, water_y), Vector2(w * 0.83, water_y), Vector2(w * 0.83, h), Vector2(w * 0.17, h)])
	draw_colored_polygon(front, Color(WATER, 0.92))
	draw_line(Vector2(w * 0.17, water_y), Vector2(w * 0.83, water_y), WATER_LINE, 2.0)
	# Drips while she comes up.
	if lift > 0.05:
		for i in 7:
			var x := cx - hull_w * 0.35 + hull_w * 0.7 * float(i) / 6.0
			var fall := fmod(_drips * 90.0 + i * 23.0, maxf(water_y - waterline - depth * 0.5, 1.0))
			draw_circle(Vector2(x, waterline + depth * 0.5 + fall), 1.6, Color(WATER_LINE, 0.8))
	# The travel lift: two frames and a beam, slings under the hull.
	var beam_y := h * 0.1
	for x in [w * 0.19, w * 0.81]:
		draw_line(Vector2(x, water_y - 6.0), Vector2(x, beam_y), LIFT, 7.0)
		draw_line(Vector2(x - 14.0, water_y - 6.0), Vector2(x + 14.0, water_y - 6.0), LIFT, 5.0)
	draw_line(Vector2(w * 0.19, beam_y), Vector2(w * 0.81, beam_y), LIFT, 8.0)
	for x in [cx - hull_w * 0.28, cx + hull_w * 0.28]:
		var bottom_y := waterline + depth * 0.55
		draw_line(Vector2(x - 10.0, beam_y), Vector2(x - 10.0, bottom_y), SLING, 2.5)
		draw_line(Vector2(x + 10.0, beam_y), Vector2(x + 10.0, bottom_y), SLING, 2.5)
		draw_line(Vector2(x - 10.0, bottom_y), Vector2(x + 10.0, bottom_y), SLING, 2.5)


## One hull seen from the side: topsides above the waterline, antifouling
## below, weed along the bottom when fouled; a keel fin on a monohull.
func _draw_hull(deck_mid: Vector2, length: float, freeboard: float, depth: float, waterline: float, keel: bool) -> void:
	var l := deck_mid.x - length * 0.5
	var r := deck_mid.x + length * 0.5
	var bottom := waterline + depth * 0.45
	var outline := PackedVector2Array([Vector2(l, deck_mid.y), Vector2(r, deck_mid.y - 4.0), Vector2(r - length * 0.06, waterline),
		Vector2(r - length * 0.22, bottom), Vector2(l + length * 0.12, bottom), Vector2(l + length * 0.02, waterline)])
	draw_colored_polygon(outline, HULL)
	draw_line(Vector2(l, deck_mid.y + 5.0), Vector2(r, deck_mid.y + 1.0), HULL_SHADE, 3.0)
	var under := PackedVector2Array([Vector2(r - length * 0.06, waterline), Vector2(r - length * 0.22, bottom),
		Vector2(l + length * 0.12, bottom), Vector2(l + length * 0.02, waterline)])
	draw_colored_polygon(under, BOTTOM.lerp(WEED, fouled * 0.85))
	if keel:
		var fin := PackedVector2Array([Vector2(deck_mid.x - length * 0.02, bottom), Vector2(deck_mid.x + length * 0.12, bottom),
			Vector2(deck_mid.x + length * 0.08, bottom + depth * 0.55), Vector2(deck_mid.x, bottom + depth * 0.55)])
		draw_colored_polygon(fin, BOTTOM.lerp(WEED, fouled * 0.85))
	if fouled > 0.2:
		for i in 9:
			var x := l + length * (0.16 + 0.07 * i)
			draw_line(Vector2(x, bottom), Vector2(x + 3.0, bottom + 4.0 + fouled * 6.0), WEED, 2.0)
