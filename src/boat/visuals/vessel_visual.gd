class_name VesselVisual
extends Node2D
## Root of a vessel's deck or cabin artwork (the `deck_visual.tscn` /
## `cabin_visual.tscn` scenes). Holds only presentation: its VisualSlot
## children draw the procedural placeholder art or show a sprite. It contains
## no collision and no interactions, so replacing art cannot change gameplay.
##
## All sprites of one scene share one logical canvas (`canvas`, in scene
## units, origin = boat centre, bow towards +x): every PNG is drawn on the
## full canvas, like layers of one drawing, and placed at the canvas'
## top-left corner. See ART_PIPELINE.md.

## Logical drawing area in scene units (x forward, y to starboard).
@export var canvas := Rect2(-560, -200, 1120, 400)

var profile: VesselVisualProfile


## Shows sprites where the profile has them and procedural art elsewhere.
func apply(visual_profile: VesselVisualProfile) -> void:
	profile = visual_profile
	for slot in get_slots():
		var texture := visual_profile.get_texture(slot.slot) if visual_profile else null
		if texture:
			slot.show_sprite(texture, canvas)
		else:
			slot.show_procedural()


func get_slots() -> Array[VisualSlot]:
	var slots: Array[VisualSlot] = []
	for child in get_children():
		if child is VisualSlot:
			slots.append(child)
	return slots


func get_slot(slot_name: StringName) -> VisualSlot:
	for slot in get_slots():
		if slot.slot == slot_name:
			return slot
	return null
