class_name FishPortrait
extends Control
## A catch shown large (Iteration 18): the illustrated fish, alive. Now and
## then it blinks (quick, at irregular intervals of a few seconds) and flicks
## its tail (a brief wiggle), and it bobs very gently. Junk just lies there.
##
## Lightweight: three textures on one canvas (FishArt), one _process that runs
## only while the portrait is visible, no timers or tweens. Each portrait
## draws its own irregular timings, so two fish never blink together.
## Reduce motion (Settings) keeps the tail and body still; the blink stays.
## Small static pictures for lists use FishArt.thumbnail() instead.

const BLINK_SECONDS := 0.13
const BLINK_EVERY := Vector2(2.4, 6.0)
const FLICK_SECONDS := 0.42
const FLICK_EVERY := Vector2(3.0, 7.5)
const FLICK_DEG := 13.0
const BOB_PX := 2.5
const BOB_SPEED := 1.4

var species_id := ""
## Off: still (tests and screenshots use force_* to pose it).
var animated := true

var _stage: Control
var _tail: TextureRect
var _body: TextureRect
var _lid: TextureRect
var _clock := 0.0
var _next_blink := 0.0
var _blink_left := 0.0
var _next_flick := 0.0
var _flick_left := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = false
	resized.connect(_fit)
	visibility_changed.connect(_update_processing)
	_update_processing()


## Shows `id` (a species or a piece of junk).
func set_species(id: String) -> void:
	species_id = id
	if _stage:
		_stage.queue_free()
	_stage = Control.new()
	_stage.name = "Stage"
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stage)
	var canvas := FishArt.get_canvas(id)
	_stage.size = canvas
	_tail = null
	_lid = null
	if FishArt.is_animated(id):
		_tail = _layer("Tail", FishArt.layer(id, "tail"), canvas)
		_tail.pivot_offset = FishArt.get_tail_pivot(id)
		_body = _layer("Body", FishArt.layer(id, "body"), canvas)
		_lid = _layer("Lid", FishArt.layer(id, "lid"), canvas)
		_lid.visible = false
	else:
		_body = _layer("Body", FishArt.layer(id, "art"), canvas)
	_rng.seed = hash("%s|%d" % [id, get_instance_id()])
	_clock = 0.0
	_next_blink = _rng.randf_range(0.8, BLINK_EVERY.y)
	_next_flick = _rng.randf_range(1.2, FLICK_EVERY.y)
	_blink_left = 0.0
	_flick_left = 0.0
	_fit()
	_update_processing()


func _layer(layer_name: String, texture: Texture2D, canvas: Vector2) -> TextureRect:
	var rect := TextureRect.new()
	rect.name = layer_name
	rect.texture = texture
	rect.size = canvas
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(rect)
	return rect


func _fit() -> void:
	if _stage == null:
		return
	var canvas := _stage.size
	var factor := minf(size.x / canvas.x, size.y / canvas.y) if size.x > 0.0 and size.y > 0.0 else 1.0
	_stage.scale = Vector2(factor, factor)
	_stage.position = (size - canvas * factor) / 2.0


func _update_processing() -> void:
	set_process(is_visible_in_tree() and _stage != null and FishArt.is_animated(species_id))


func _notification(what: int) -> void:
	if what == NOTIFICATION_ENTER_TREE or what == NOTIFICATION_EXIT_TREE:
		_update_processing()


func _process(delta: float) -> void:
	if not animated or _tail == null:
		return
	if not is_visible_in_tree():
		set_process(false)
		return
	advance(delta)


## One step of the little animations (tests call it directly).
func advance(delta: float) -> void:
	_clock += delta
	var still := SettingsManager.get_reduce_motion()
	# Blink.
	if _blink_left > 0.0:
		_blink_left -= delta
		if _blink_left <= 0.0:
			_lid.visible = false
			_next_blink = _clock + _rng.randf_range(BLINK_EVERY.x, BLINK_EVERY.y)
	elif _clock >= _next_blink:
		force_blink()
	# Tail flick (a damped wiggle).
	if still:
		_flick_left = 0.0
		_tail.rotation = 0.0
	elif _flick_left > 0.0:
		_flick_left = maxf(_flick_left - delta, 0.0)
		var f := 1.0 - _flick_left / FLICK_SECONDS
		_tail.rotation = deg_to_rad(FLICK_DEG * sin(f * TAU * 1.5) * (1.0 - f))
		if _flick_left <= 0.0:
			_tail.rotation = 0.0
			_next_flick = _clock + _rng.randf_range(FLICK_EVERY.x, FLICK_EVERY.y)
	elif _clock >= _next_flick:
		_flick_left = FLICK_SECONDS
	# A gentle bob.
	var bob := 0.0 if still else sin(_clock * BOB_SPEED) * BOB_PX
	_stage.position.y = (size.y - _stage.size.y * _stage.scale.y) / 2.0 + bob


func force_blink() -> void:
	if _lid:
		_lid.visible = true
		_blink_left = BLINK_SECONDS


## Poses the tail (degrees) and holds it (screenshots).
func pose_tail(degrees: float) -> void:
	if _tail:
		_flick_left = 0.0
		_tail.rotation = deg_to_rad(degrees)


func is_eye_closed() -> bool:
	return _lid != null and _lid.visible


func get_tail_degrees() -> float:
	return rad_to_deg(_tail.rotation) if _tail else 0.0


func is_animating() -> bool:
	return is_processing()
