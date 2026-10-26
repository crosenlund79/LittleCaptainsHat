class_name SolarPanels
extends Node2D
## Decorative solar panels (Revision 0.105b): visual only - no power, no
## batteries, no charging, nothing saved. Each boat's deck visual lists where
## its panels are (VesselVisual.solar_panels, boat coordinates: x towards the
## bow, y to starboard, seen from above), sized for the boat: one small panel
## on the Arctic Wanderer's stern rail, a pair on a stern arch for the Wing 33
## and the Frogleap 36, three across the Clam 40's davit arch. They sit aft of
## the walkable deck, so they never change walkability, collisions or where
## the Captain and Snøvs can go, and they are drawn under the characters.
## Part of the boat's art, so they turn with it in every heading.
##
## Art: procedural (a dark blue-black cell grid in a slim frame, a soft
## shadow, two mounting struts) unless the Sprite Workshop has a replacement
## for SPRITE_ID, which is then drawn into each panel's rectangle (its long
## side athwartships, like the procedural one).

const SPRITE_ID := &"boat.shared.solar_panel"
const FRAME := Color("#b9bcb8")
const FRAME_DARK := Color("#6d7270")
const CELL := Color("#1b2a44")
const CELL_LINE := Color("#3c5577")
const GLINT := Color(1.0, 1.0, 1.0, 0.10)
const STRUT := Color("#9a9d99")
const SHADOW := Color(0.0, 0.0, 0.0, 0.22)
## Cell size in scene units (about).
const CELL_SIZE := 9.0
## A row of two or more panels sits on an arch: a tube under their forward
## edge, reaching this far past the outer panels (to the rail or the hulls).
const ARCH_OVERHANG := 12.0

var panels: Array[Rect2] = []
var _texture: Texture2D


func setup(rects: Array[Rect2]) -> void:
	name = "SolarPanels"
	panels = rects.duplicate()
	_texture = ArtworkResolver.get_artwork(SPRITE_ID)
	queue_redraw()


func uses_replacement() -> bool:
	return _texture != null


## Panel rectangles in the boat's coordinates (tests).
func get_panels() -> Array[Rect2]:
	return panels


func _draw() -> void:
	if panels.size() >= 2:
		var top := INF
		var bottom := -INF
		var x := 0.0
		for rect in panels:
			top = minf(top, rect.position.y)
			bottom = maxf(bottom, rect.end.y)
			x = rect.position.x + rect.size.x * 0.75
		draw_line(Vector2(x + 3.0, top - ARCH_OVERHANG + 4.0), Vector2(x + 3.0, bottom + ARCH_OVERHANG + 4.0), SHADOW, 4.0, true)
		draw_line(Vector2(x, top - ARCH_OVERHANG), Vector2(x, bottom + ARCH_OVERHANG), STRUT, 4.0, true)
	for rect in panels:
		# Struts from the panel's forward edge to the rail or arch.
		var fwd := rect.position.x + rect.size.x
		for f: float in [0.2, 0.8]:
			var y := rect.position.y + rect.size.y * f
			draw_line(Vector2(fwd - 2.0, y), Vector2(fwd + 10.0, y), STRUT, 2.4, true)
		draw_rect(Rect2(rect.position + Vector2(4.0, 5.0), rect.size), SHADOW)
		if _texture:
			draw_texture_rect(_texture, rect, false)
			continue
		draw_rect(rect, FRAME)
		var inner := rect.grow(-2.5)
		draw_rect(inner, CELL)
		var cols := maxi(roundi(inner.size.x / CELL_SIZE), 2)
		var rows := maxi(roundi(inner.size.y / CELL_SIZE), 2)
		for c in range(1, cols):
			var x := inner.position.x + inner.size.x * c / cols
			draw_line(Vector2(x, inner.position.y), Vector2(x, inner.end.y), CELL_LINE, 1.0)
		for r in range(1, rows):
			var y := inner.position.y + inner.size.y * r / rows
			draw_line(Vector2(inner.position.x, y), Vector2(inner.end.x, y), CELL_LINE, 1.0)
		# A soft diagonal glint and the frame's darker edge.
		draw_colored_polygon(PackedVector2Array([inner.position, inner.position + Vector2(inner.size.x * 0.45, 0),
			inner.position + Vector2(0, inner.size.y * 0.45)]), GLINT)
		draw_rect(rect, FRAME_DARK, false, 1.2)
