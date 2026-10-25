class_name HatBlowAway
extends Node2D
## The short "your hat is gone" effect on deck: the hat tumbles downwind,
## lifts a little and fades out over DURATION seconds, then removes itself.
## Cosmetic only (real time, not saved); the loss itself is GameSession's.

const DURATION := 1.8
const DISTANCE := 520.0

var direction := Vector2.LEFT
var _elapsed := 0.0
var _start := Vector2.ZERO


## Starts the effect at `from` (this node's parent coordinates), blowing
## along `towards` (any length).
func setup(from: Vector2, towards: Vector2) -> void:
	_start = from
	position = from
	if towards.length() > 0.001:
		direction = towards.normalized()


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= DURATION:
		queue_free()
		return
	var t := _elapsed / DURATION
	# Accelerates away with a little sideways flutter.
	position = _start + direction * DISTANCE * t * t + direction.orthogonal() * sin(t * TAU * 1.5) * 18.0 * t
	queue_redraw()


func get_progress() -> float:
	return clampf(_elapsed / DURATION, 0.0, 1.0)


func _draw() -> void:
	var t := get_progress()
	var alpha := 1.0 - smoothstep(0.55, 1.0, t)
	HatArt.get_default().draw_slot(self, HatArt.SLOT_BLOWING, Vector2.ZERO, direction.angle() + t * TAU * 2.2, alpha, 1.0 + 0.35 * sin(t * PI))
