class_name VisualSlot
extends Node2D
## One named piece of a vessel's artwork (HullBase, DeckBase, Coachroof, ...).
## Its children are the procedural placeholder drawing. When the visual profile
## provides a sprite for the slot, the children are hidden and the sprite is
## shown instead, covering the scene's whole art canvas (uniformly scaled, so
## PNGs may be drawn at any resolution with the canvas' aspect ratio).

## Slot name used by VesselVisualProfile (defaults to the node name).
@export var slot: StringName

var _sprite: Sprite2D


func _ready() -> void:
	if slot.is_empty():
		slot = StringName(name)


func show_sprite(texture: Texture2D, canvas: Rect2) -> void:
	for child in get_children():
		if child != _sprite and child is CanvasItem:
			(child as CanvasItem).visible = false
	if _sprite == null:
		_sprite = Sprite2D.new()
		_sprite.name = "Sprite"
		_sprite.centered = false
		_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		add_child(_sprite)
	_sprite.texture = texture
	_sprite.visible = true
	_sprite.position = canvas.position
	var scale_factor := canvas.size.x / float(texture.get_width())
	_sprite.scale = Vector2(scale_factor, scale_factor)
	var canvas_ratio := canvas.size.x / canvas.size.y
	var texture_ratio := float(texture.get_width()) / float(texture.get_height())
	if absf(canvas_ratio - texture_ratio) / canvas_ratio > 0.01:
		push_warning("Sprite for slot %s is %dx%d; the art canvas is %s (aspect %.3f vs %.3f). It is scaled to the canvas width." % [
			slot, texture.get_width(), texture.get_height(), canvas.size, texture_ratio, canvas_ratio])


func show_procedural() -> void:
	if _sprite:
		_sprite.queue_free()
		_sprite = null
	for child in get_children():
		if child is CanvasItem and child != _sprite:
			(child as CanvasItem).visible = true


func is_sprite() -> bool:
	return _sprite != null and _sprite.visible


func get_sprite() -> Sprite2D:
	return _sprite
