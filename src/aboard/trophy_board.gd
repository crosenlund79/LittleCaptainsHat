class_name TrophyBoard
extends Node2D
## The trophy board on the cabin wall (Iteration 13): five slots for the five
## most notable catches (FishingState.trophies, ranked by FishingCatalog.score).
## A filled slot shows a little painted fish in the species' colour; empty
## slots are faint outlines. Presentation only: the station beside it opens
## the list (TrophyMenu).

const WOOD := Color("#8a5a35")
const WOOD_DARK := Color("#5c3a22")
const BRASS := Color("#c9a46a")
const EMPTY := Color(0.94, 0.9, 0.8, 0.28)
const FISH_COLOURS := {
	"herring": Color("#9fb7c0"), "mackerel": Color("#4f8a8b"), "flatfish": Color("#a68b62"), "cod": Color("#9a8f6a"),
	"perch": Color("#7ba05b"), "garfish": Color("#6fa3a8"), "gilthead_bream": Color("#c0c4b8"), "sea_trout": Color("#b39a7a"),
	"sea_bass": Color("#a9b4b8"), "bonito": Color("#3f6f8f"),
	"mahi_mahi": Color("#9fbf4f"), "skipjack": Color("#4a6f99"), "snapper": Color("#c8705a"), "yellowfin": Color("#d9b84a"),
}
const SIZE := Vector2(132, 46)


func _ready() -> void:
	z_index = 3
	GameSession.fishing_changed.connect(queue_redraw)
	GameSession.state_replaced.connect(queue_redraw)


static func outline() -> PackedVector2Array:
	return HighlightResolver.rounded_rect(Rect2(-SIZE / 2.0 - Vector2(3, 3), SIZE + Vector2(6, 6)), 6.0)


func _draw() -> void:
	var rect := Rect2(-SIZE / 2.0, SIZE)
	draw_rect(rect.grow(2.0), WOOD_DARK)
	draw_rect(rect, WOOD)
	draw_line(rect.position + Vector2(4, 10), Vector2(rect.end.x - 4, rect.position.y + 10), Color(WOOD_DARK, 0.5), 1.0)
	draw_line(rect.position + Vector2(4, 34), Vector2(rect.end.x - 4, rect.position.y + 34), Color(WOOD_DARK, 0.5), 1.0)
	var trophies := GameSession.get_fishing().trophies
	for i in FishingState.TROPHY_COUNT:
		var center := Vector2(rect.position.x + SIZE.x * (i + 0.5) / FishingState.TROPHY_COUNT, 2.0)
		draw_circle(center + Vector2(0, -14), 1.6, BRASS)
		if i < trophies.size():
			_draw_fish(center, Color(FISH_COLOURS.get(trophies[i].species, Color("#9fb7c0"))), i == 0)
		else:
			_draw_fish(center, EMPTY, false, true)


func _draw_fish(center: Vector2, colour: Color, best: bool, outline_only := false) -> void:
	var body := PackedVector2Array()
	for k in 16:
		var a := TAU * k / 16.0
		body.append(center + Vector2(cos(a) * 9.0, sin(a) * 4.5) + Vector2(1, 0))
	var tail := PackedVector2Array([center + Vector2(-7, 0), center + Vector2(-13, -5), center + Vector2(-12, 0), center + Vector2(-13, 5)])
	if outline_only:
		var closed := body.duplicate()
		closed.append(body[0])
		draw_polyline(closed, colour, 1.0, true)
		draw_polyline(tail, colour, 1.0, true)
		return
	draw_colored_polygon(tail, colour.darkened(0.25))
	draw_colored_polygon(body, colour)
	draw_circle(center + Vector2(6, -1), 1.1, Color("#1f2a2e"))
	if best:
		draw_circle(center + Vector2(0, 12), 2.4, BRASS)
