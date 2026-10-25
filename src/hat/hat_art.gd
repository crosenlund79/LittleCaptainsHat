@tool
class_name HatArt
extends Resource
## The captain's hat's artwork: three replaceable slots, the hat on its hook
## in the cabin ("stored"), on the player's head ("worn") and tumbling away in
## the wind ("blowing"). Art only: nothing here affects the hat's state, the
## player's collision or any interaction.
##
## Each slot is resolved in a fixed order: the texture assigned here, then
## `<art_folder>/hat_<slot>.png`, then the procedural drawing (HatDrawing). A
## missing file therefore never breaks anything; dropping a PNG with the
## right name into the folder replaces the drawing without touching code.
## Images are drawn centred, scaled so their larger side is `size` pixels;
## worn and blowing images should show the hat from above with its peak
## pointing right (+x), which is rotated to the way the player faces.

const DEFAULT_PATH := "res://data/hat/hat_art.tres"
const SLOT_STORED := &"stored"
const SLOT_WORN := &"worn"
const SLOT_BLOWING := &"blowing"
const SLOTS: Array[StringName] = [SLOT_STORED, SLOT_WORN, SLOT_BLOWING]

static var _default: HatArt

@export var art_folder := "res://assets/hat"
@export var stored_texture: Texture2D
@export var worn_texture: Texture2D
@export var blowing_texture: Texture2D
## Drawn size (larger side, pixels in the boat scene) per slot.
@export var stored_size := 46.0
@export var worn_size := 36.0
@export var blowing_size := 40.0
## Forces the procedural drawings (to compare, or while art is unfinished).
@export var procedural_only := false


static func get_default() -> HatArt:
	if _default == null:
		_default = load(DEFAULT_PATH) as HatArt if ResourceLoader.exists(DEFAULT_PATH) else HatArt.new()
	return _default


static func clear_default() -> void:
	_default = null


## The texture for `slot`, or null when the procedural drawing is used.
func get_texture(slot: StringName) -> Texture2D:
	if procedural_only:
		return null
	var assigned: Texture2D = {SLOT_STORED: stored_texture, SLOT_WORN: worn_texture, SLOT_BLOWING: blowing_texture}.get(slot)
	if assigned:
		return assigned
	var path := "%s/hat_%s.png" % [art_folder, slot]
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


func get_size(slot: StringName) -> float:
	return {SLOT_STORED: stored_size, SLOT_WORN: worn_size, SLOT_BLOWING: blowing_size}.get(slot, worn_size)


## Draws `slot` on `canvas` centred at `center`, rotated by `angle` (the
## peak's direction), with `alpha`: the texture if there is one, otherwise
## the procedural drawing.
func draw_slot(canvas: CanvasItem, slot: StringName, center: Vector2, angle := 0.0, alpha := 1.0, scale := 1.0) -> void:
	var size := get_size(slot) * scale
	var texture := get_texture(slot)
	if texture == null:
		HatDrawing.draw_hat(canvas, center, size * 0.5, angle, alpha)
		return
	var tex_size := texture.get_size()
	var factor := size / maxf(tex_size.x, tex_size.y)
	canvas.draw_set_transform(center, angle, Vector2(factor, factor))
	canvas.draw_texture(texture, -tex_size * 0.5, Color(1, 1, 1, alpha))
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
