class_name HatHook
extends Node2D
## The hat's place in the cabin: a brass hook, with the captain's hat on it
## while it is stored. Every cabin marks the spot with Layout/HatSpot (art
## only, no collision); BoatArea places this node there. The interaction
## (put on / hang up) is the cabin's `hat` station.

const HOOK := Color("#b08a4e")
const HOOK_DARK := Color("#5c4526")

var _stored := false


func _ready() -> void:
	GameSession.hat_changed.connect(func(_status: StringName) -> void: refresh())
	GameSession.state_replaced.connect(refresh)
	refresh()


func refresh() -> void:
	_stored = GameSession.is_active() and GameSession.get_hat_status() == HatState.STORED
	queue_redraw()


## True while the hat hangs here.
func is_showing_hat() -> bool:
	return _stored


func _draw() -> void:
	# The hook: a small brass plate with a peg.
	draw_rect(Rect2(-9, -4, 18, 8), HOOK_DARK)
	draw_rect(Rect2(-7, -3, 14, 6), HOOK)
	draw_circle(Vector2.ZERO, 3.0, HOOK_DARK)
	if _stored:
		HatArt.get_default().draw_slot(self, HatArt.SLOT_STORED, Vector2(0, 4), PI * 0.5)
