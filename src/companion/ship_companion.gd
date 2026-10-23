class_name ShipCompanion
extends Node2D
## The ship's cat or dog, resting in the cabin. Presentation only: the kind
## and resting spot come from GameSession (CompanionState), so the companion
## is the same after loading, sleeping or coming back from the deck or chart.
## Exactly one exists, because it is part of the cabin scene.
##
## Where it rests comes from the cabin's layout: the marker named after the
## spot under `spots_path` (Layout/CompanionSpots), so every vessel places its
## own spots. The look is procedural unless a sprite exists at
## res://assets/companions/<kind>.png (drawn facing +x, centred on the
## animal); then that is shown instead, with the same breathing and reactions.
##
## It moves instantly between its resting spots when the schedule says so
## (no walking, no pathfinding, no collision, so it never blocks the player).
## Petting it (E, via its Interactable) plays a short sound on the SFX bus and
## a small reaction: the cat purrs, settles and shows a few hearts; the dog
## pants softly and wags its tail.

signal petted(kind: StringName)

const REACTION_SECONDS := 1.6
const INTERACT_RADIUS := 34.0
## Drawn in a flat top-down style matching the boat fixtures.
const CAT_FUR := Color("#5E6A72")
const CAT_DARK := Color("#3E474D")
const CAT_LIGHT := Color("#D9CFB8")
const DOG_FUR := Color("#9C6B45")
const DOG_DARK := Color("#6E4A30")
const DOG_LIGHT := Color("#E3D2B4")
const OUTLINE := Color(0.06, 0.1, 0.12, 0.55)
const HEART := Color("#E07A6A")

@export var purr_sound: AudioStream = preload("res://assets/audio/placeholder/companion_purr.wav")
@export var dog_sound: AudioStream = preload("res://assets/audio/placeholder/companion_dog_pant.wav")

## A preview (e.g. in the New Game dialog): just the drawing, no
## interaction and no session state.
@export var preview := false
## The cabin's resting-spot markers (one Marker2D per CompanionState spot id).
@export var spots_path := ^"../Layout/CompanionSpots"

var kind: StringName = CompanionState.DEFAULT_KIND
var spot: StringName = &""
var interactable: Interactable

var _textures := {}
var _time := 0.0
var _reaction := 0.0


func _ready() -> void:
	z_index = 5
	if preview:
		return
	interactable = Interactable.new()
	interactable.name = "Pet"
	interactable.interaction_id = &"pet"
	interactable.highlight_target = ^".."
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = INTERACT_RADIUS
	shape.shape = circle
	interactable.add_child(shape)
	add_child(interactable)
	_sync()
	GameSession.companion_moved.connect(_on_companion_moved)
	GameSession.state_replaced.connect(_sync)


func _process(delta: float) -> void:
	_time += delta
	_reaction = maxf(_reaction - delta, 0.0)
	queue_redraw()


## Called when the player pets the companion (E).
func pet() -> void:
	_reaction = REACTION_SECONDS
	AudioManager.play_sfx(purr_sound if kind == CompanionState.KIND_CAT else dog_sound)
	petted.emit(kind)


## Preview only: shows the given kind.
func show_kind(companion_kind: StringName) -> void:
	kind = companion_kind
	queue_redraw()


func _on_companion_moved(_spot: StringName) -> void:
	_sync()


func is_reacting() -> bool:
	return _reaction > 0.0


func get_sound() -> AudioStream:
	return purr_sound if kind == CompanionState.KIND_CAT else dog_sound


## Shows the companion from the session state (kind and resting spot).
func _sync() -> void:
	var companion := GameSession.get_companion()
	if companion == null:
		visible = false
		return
	visible = true
	kind = companion.kind
	spot = companion.spot
	position = get_spot_position(spot)
	# Each spot has its own (fixed) lying direction.
	rotation = deg_to_rad(float(absi(hash(String(spot))) % 360))
	interactable.prompt = "Pet %s" % CompanionState.display_name(kind)


## The resting position of `spot_id` in this cabin (its marker), or the
## current position when the cabin has no such marker.
func get_spot_position(spot_id: StringName) -> Vector2:
	var spots := get_node_or_null(spots_path)
	var marker := spots.get_node_or_null(NodePath(String(spot_id))) as Node2D if spots else null
	if marker == null:
		push_warning("ShipCompanion: no resting spot marker '%s'" % spot_id)
		return position
	return marker.position


## The optional sprite for `companion_kind` (null: draw procedurally).
func get_texture(companion_kind: StringName) -> Texture2D:
	if not _textures.has(companion_kind):
		var path := "res://assets/companions/%s.png" % companion_kind
		_textures[companion_kind] = load(path) as Texture2D if ResourceLoader.exists(path) else null
	return _textures[companion_kind]


func _draw() -> void:
	var texture := get_texture(kind)
	if texture:
		var swell := 1.0 + 0.025 * sin(_time * TAU * 0.25) + (0.03 * sin(_time * TAU * 1.8) if is_reacting() else 0.0)
		var size := texture.get_size() * swell
		draw_texture_rect(texture, Rect2(-size / 2.0, size), false)
		if is_reacting() and kind == CompanionState.KIND_CAT:
			_draw_hearts()
		return
	# Breathing: a slow, very small swell; a little deeper while reacting.
	var breath := 1.0 + 0.025 * sin(_time * TAU * 0.25) + (0.03 * sin(_time * TAU * 1.8) if is_reacting() else 0.0)
	if kind == CompanionState.KIND_DOG:
		_draw_dog(breath)
	else:
		_draw_cat(breath)
	if is_reacting() and kind == CompanionState.KIND_CAT:
		_draw_hearts()


func _draw_cat(breath: float) -> void:
	# Curled up: round body, tail wrapped around, head tucked in.
	var body := _ellipse(Vector2.ZERO, Vector2(17, 14) * breath)
	draw_colored_polygon(_ellipse(Vector2(1, 2), Vector2(18, 15) * breath), OUTLINE)
	draw_colored_polygon(body, CAT_FUR)
	for i in 3:  # stripes
		var x := -8.0 + i * 6.0
		draw_line(Vector2(x, -12 * breath), Vector2(x + 2, -6 * breath), CAT_DARK, 2.0, true)
	var tail := PackedVector2Array()
	for i in 13:
		var a := deg_to_rad(110.0 + i * 13.0)
		tail.append(Vector2(cos(a), sin(a)) * Vector2(19, 16) * breath)
	draw_polyline(tail, CAT_DARK, 5.0, true)
	var head := Vector2(10, 6)
	draw_colored_polygon(_ellipse(head, Vector2(8.5, 8)), CAT_FUR)
	for side in [-1.0, 1.0]:
		var ear := PackedVector2Array([head + Vector2(3, -6 * side), head + Vector2(10, -6 * side), head + Vector2(6, -11 * side)])
		draw_colored_polygon(ear, CAT_DARK)
	draw_colored_polygon(_ellipse(head + Vector2(4, 0), Vector2(3.5, 3)), CAT_LIGHT)


func _draw_dog(breath: float) -> void:
	# Lying stretched out: long body, head with floppy ears, wagging tail.
	var wag := sin(_time * TAU * (5.0 if is_reacting() else 0.4)) * (0.6 if is_reacting() else 0.12)
	var tail_end := Vector2(-24, 0) + Vector2(-12, 0).rotated(wag)
	draw_line(Vector2(-22, 0), tail_end, DOG_DARK, 5.0, true)
	draw_colored_polygon(_ellipse(Vector2(1, 2), Vector2(25, 15) * breath), OUTLINE)
	draw_colored_polygon(_ellipse(Vector2.ZERO, Vector2(24, 14) * breath), DOG_FUR)
	draw_colored_polygon(_ellipse(Vector2(-4, 0), Vector2(12, 7) * breath), DOG_LIGHT.lerp(DOG_FUR, 0.55))
	for paw in [Vector2(18, -11), Vector2(18, 11)]:
		draw_colored_polygon(_ellipse(paw + Vector2(6, 0), Vector2(6, 3.5)), DOG_FUR)
	var head := Vector2(26, 0)
	draw_colored_polygon(_ellipse(head, Vector2(11, 10)), DOG_FUR)
	draw_colored_polygon(_ellipse(head + Vector2(9, 0), Vector2(6, 5)), DOG_LIGHT)
	draw_circle(head + Vector2(14, 0), 2.2, DOG_DARK)
	var droop := 1.0 + (0.15 * sin(_time * TAU * 3.0) if is_reacting() else 0.0)
	for side in [-1.0, 1.0]:
		draw_colored_polygon(_ellipse(head + Vector2(-3, 9 * side * droop), Vector2(6, 4)), DOG_DARK)


func _draw_hearts() -> void:
	var t := 1.0 - _reaction / REACTION_SECONDS
	for i in 2:
		var at := Vector2(8 + i * 12, -22 - t * 22 - i * 6).rotated(-rotation)
		var alpha := clampf(1.0 - t, 0.0, 1.0)
		var size := 4.0
		draw_circle(at + Vector2(-size * 0.5, 0), size * 0.6, Color(HEART, alpha))
		draw_circle(at + Vector2(size * 0.5, 0), size * 0.6, Color(HEART, alpha))
		draw_colored_polygon(PackedVector2Array([at + Vector2(-size * 1.05, 0.8), at + Vector2(size * 1.05, 0.8), at + Vector2(0, size * 1.4)]),
			Color(HEART, alpha))


static func _ellipse(center: Vector2, radii: Vector2, steps := 20) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in steps:
		var a := TAU * i / steps
		points.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	return points
