class_name Windlass
extends Node2D
## The anchor windlass on the foredeck (Iteration 13), drawn in the deck's
## coordinates (+x the bow). The anchor sits in its bow roller at `bow`; at
## anchor the chain runs out over the bow into the water. Presentation only:
## the station beside it opens the anchor (AnchorMenu).

const INK := Color("#1f2a2e")
const BODY := Color("#3d4b50")
const DRUM := Color("#9aa7ab")
const CHAIN := Color("#b8c0c2")
const ALARM := Color("#c8553d")

## The bow roller, relative to this node.
var bow := Vector2(60, 0)
var _time := 0.0


func _ready() -> void:
	z_index = 2
	GameSession.anchor_changed.connect(queue_redraw)
	GameSession.state_replaced.connect(queue_redraw)


func _process(delta: float) -> void:
	_time += delta
	if GameSession.is_anchored():
		queue_redraw()


static func outline() -> PackedVector2Array:
	return HighlightResolver.rounded_rect(Rect2(-17, -15, 34, 30), 7.0)


func _draw() -> void:
	var anchored := GameSession.is_anchored()
	# The chain from the gypsy to the bow roller (and on into the sea).
	var chain_end := bow + Vector2(46.0, 6.0 * sin(_time * 0.8)) if anchored else bow
	var links := int(Vector2.ZERO.distance_to(chain_end) / 6.0)
	for k in links:
		var p := Vector2.ZERO.lerp(chain_end, (k + 0.5) / links)
		var vertical := k % 2 == 0
		draw_rect(Rect2(p - (Vector2(3, 1.6) if vertical else Vector2(1.6, 3)), Vector2(6, 3.2) if vertical else Vector2(3.2, 6)),
			CHAIN, false, 1.2)
	if not anchored:
		# The anchor, stowed in the bow roller.
		draw_line(bow + Vector2(-8, 0), bow + Vector2(10, 0), INK, 4.0, true)
		draw_polyline(PackedVector2Array([bow + Vector2(4, -9), bow + Vector2(12, 0), bow + Vector2(4, 9)]), INK, 4.0, true)
		draw_polyline(PackedVector2Array([bow + Vector2(4, -8), bow + Vector2(11, 0), bow + Vector2(4, 8)]), DRUM, 2.0, true)
	elif GameSession.get_anchor().holding == AnchorState.HOLDING_DRAGGING:
		draw_arc(chain_end, 9.0 + 3.0 * sin(_time * 4.0), 0.0, TAU, 20, Color(ALARM, 0.6), 2.0, true)
	# The windlass: a low housing with the chain gypsy on top.
	draw_rect(Rect2(-14, -12, 28, 24), INK)
	draw_rect(Rect2(-12, -10, 24, 20), BODY)
	draw_circle(Vector2(2, 0), 7.5, INK)
	draw_circle(Vector2(2, 0), 6.0, DRUM)
	for k in 6:
		var a := TAU * k / 6.0 + (0.0 if not anchored else _time * 0.2)
		draw_line(Vector2(2, 0) + Vector2.from_angle(a) * 2.0, Vector2(2, 0) + Vector2.from_angle(a) * 6.0, INK, 1.0)
	draw_rect(Rect2(-11, -3, 5, 6), DRUM)
