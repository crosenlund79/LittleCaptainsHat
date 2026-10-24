class_name Player
extends CharacterBody2D
## The player's token on board: keyboard movement with collision, plus an
## InteractionSensor for nearby objects. It reads input only while the game is
## unpaused, so open menus automatically block movement and interaction.

signal focus_changed(interactable: Interactable)

@export var speed := 250.0

const RADIUS := 21.0
const BODY_COLOR := Color("#EFE5CC")
const RIM_COLOR := Color("#102D3B")
const FACING_COLOR := Color("#C79F6D")

var input_enabled := true
var _facing := Vector2.RIGHT

@onready var _sensor: InteractionSensor = $InteractionSensor


func _ready() -> void:
	add_to_group(&"player")
	_sensor.focus_changed.connect(focus_changed.emit)


func _physics_process(_delta: float) -> void:
	var direction := Vector2.ZERO
	if input_enabled:
		# get_vector() limits the length to 1, so diagonals are not faster.
		direction = Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	velocity = direction * speed
	move_and_slide()
	if direction != Vector2.ZERO and not direction.is_equal_approx(_facing):
		_facing = direction.normalized()
		queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if input_enabled and event.is_action_pressed(&"interact") and not event.is_echo():
		if _sensor.interact(self):
			get_viewport().set_input_as_handled()


## The direction the player faces (unit vector; the last direction moved).
func get_facing() -> Vector2:
	return _facing


## Turns the player to face `direction` (used when placing the player).
func set_facing(direction: Vector2) -> void:
	if direction != Vector2.ZERO:
		_facing = direction.normalized()
		queue_redraw()


func get_focused_interactable() -> Interactable:
	return _sensor.focused


func set_input_enabled(enabled: bool) -> void:
	input_enabled = enabled
	if not enabled:
		velocity = Vector2.ZERO
		_sensor.clear_focus()


func _draw() -> void:
	draw_circle(Vector2(2, 3), RADIUS, Color(0, 0, 0, 0.25))
	draw_circle(Vector2.ZERO, RADIUS, RIM_COLOR)
	draw_circle(Vector2.ZERO, RADIUS - 4.0, BODY_COLOR)
	# A small brass wedge shows which way the player last moved.
	var tip := _facing * (RADIUS - 6.0)
	var side := _facing.orthogonal() * 7.0
	var base := _facing * 4.0
	draw_colored_polygon(PackedVector2Array([tip, base + side, base - side]), FACING_COLOR)
