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
## Decorative solar panels on deck (0.105b, SolarPanels), boat coordinates.
@export var solar_panels: Array[Rect2] = []

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
	_apply_solar_panels()


func _apply_solar_panels() -> void:
	var existing := get_node_or_null(^"SolarPanels")
	if existing:
		existing.free()
	if solar_panels.is_empty():
		return
	var panels := SolarPanels.new()
	add_child(panels)
	panels.setup(solar_panels)
	# Above the deck art, below the rigging (and the characters, drawn later).
	var details := get_node_or_null(^"DeckDetails")
	if details:
		move_child(panels, details.get_index() + 1)


func get_solar_panels() -> SolarPanels:
	return get_node_or_null(^"SolarPanels") as SolarPanels


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


## Shows wear and damage for `percent` (0-100) over the art (DamageOverlay,
## created on first use). `key` makes the marks this boat's own.
func set_condition(percent: float, key: String) -> void:
	var overlay := get_damage_overlay()
	if overlay == null:
		overlay = DamageOverlay.new()
		overlay.name = "DamageOverlay"
		add_child(overlay)
		overlay.setup(self, "cabin" if get_slot(&"CabinBase") != null else "deck", key)
	overlay.set_condition(percent)


func get_damage_overlay() -> DamageOverlay:
	return get_node_or_null("DamageOverlay") as DamageOverlay
