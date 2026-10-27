class_name ReelDial
extends Control
## The reel-in dial (Iteration 18): a ring with the target arc and, inside it,
## the smaller Perfect zone; a needle that goes round at a constant speed; the
## checks done and still needed (hooks along the bottom) and the grip left on
## the line (three knots). Clicking the dial is the same as the action key.
## Draws a ReelTiming; the menu steps it.

signal pressed

const RING := Color("#284a57")
const RING_EDGE := Color("#16323c")
const ARC := Color("#7ba05b")
const PERFECT := Color("#f1d27a")
const NEEDLE := Color("#f2eee3")
const MISS := Color("#c8553d")
const PIP_DONE := Color("#e8c27a")
const PIP_TODO := Color(0.86, 0.9, 0.9, 0.35)
const FLASH_SECONDS := 0.3

var timing: TimingCheck
var _flash := 0.0
var _flash_colour := Color.TRANSPARENT


func _ready() -> void:
	custom_minimum_size = Vector2(280, 330)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tooltip_text = Loc.t("Click (or press E / Space) when the needle is in the green arc.")


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit()
		accept_event()


## A short ring flash for a press's outcome (gentle with Reduce flashing).
func flash(outcome: StringName) -> void:
	match outcome:
		ReelTiming.PRESS_PERFECT:
			_flash_colour = PERFECT
		ReelTiming.PRESS_HIT:
			_flash_colour = ARC
		ReelTiming.PRESS_MISS:
			_flash_colour = MISS
		_:
			return
	_flash = FLASH_SECONDS


func _process(delta: float) -> void:
	_flash = maxf(_flash - delta, 0.0)
	queue_redraw()


func _draw() -> void:
	if timing == null:
		return
	var radius := minf(size.x, size.y - 70.0) / 2.0 - 12.0
	var center := Vector2(size.x / 2.0, radius + 12.0)
	var width := 22.0
	draw_circle(center, radius + width / 2.0 + 3.0, RING_EDGE)
	draw_circle(center, radius - width / 2.0 - 3.0, Color(0.06, 0.13, 0.16))
	draw_arc(center, radius, 0.0, TAU, 96, RING, width, true)
	# The target arc and its Perfect zone (angles: 0 = top, clockwise).
	var mid := deg_to_rad(timing.target_deg - 90.0)
	var half := deg_to_rad(timing.arc_deg / 2.0)
	draw_arc(center, radius, mid - half, mid + half, 32, ARC, width, true)
	var perfect_half := deg_to_rad(timing.get_perfect_deg() / 2.0)
	draw_arc(center, radius, mid - perfect_half, mid + perfect_half, 16, PERFECT, width - 6.0, true)
	# The outcome flash around the ring.
	if _flash > 0.0:
		var strength := _flash / FLASH_SECONDS * (0.45 if SettingsManager.get_reduce_flashing() else 0.9)
		draw_arc(center, radius + width / 2.0 + 6.0, 0.0, TAU, 96, Color(_flash_colour, strength), 6.0, true)
	# The needle.
	var a := deg_to_rad(timing.angle - 90.0)
	var tip := center + Vector2(cos(a), sin(a)) * (radius + width / 2.0)
	draw_line(center, tip, RING_EDGE, 9.0, true)
	draw_line(center, tip, NEEDLE, 5.0, true)
	draw_circle(center, 11.0, NEEDLE)
	draw_circle(center, 6.0, RING_EDGE)
	# Checks (hooks) along the bottom, and the line's grip (knots).
	var base_y := center.y + radius + width / 2.0 + 30.0
	var n := timing.checks_needed
	for i in n:
		var x := size.x / 2.0 + (i - (n - 1) / 2.0) * 34.0
		var done := i < timing.hits
		draw_circle(Vector2(x, base_y), 11.0, PIP_DONE if done else PIP_TODO)
		draw_arc(Vector2(x, base_y), 11.0, 0.0, TAU, 24, RING_EDGE, 2.0, true)
		if done:
			draw_line(Vector2(x - 5, base_y), Vector2(x - 1, base_y + 5), RING_EDGE, 3.0, true)
			draw_line(Vector2(x - 1, base_y + 5), Vector2(x + 6, base_y - 5), RING_EDGE, 3.0, true)
	for i in timing.line_control:
		var x := size.x / 2.0 + (i - (timing.line_control - 1) / 2.0) * 26.0
		var left := i < timing.get_line_control()
		var knot := Vector2(x, base_y + 32.0)
		draw_line(knot - Vector2(13, 0), knot + Vector2(13, 0), Color(0.86, 0.8, 0.66, 0.8), 3.0, true)
		draw_circle(knot, 7.0, Color("#d9c49a") if left else Color(0.3, 0.3, 0.3, 0.6))
		if not left:
			draw_line(knot + Vector2(-5, -5), knot + Vector2(5, 5), MISS, 2.5, true)
