class_name DamageOverlay
extends Node2D
## Wear and damage drawn over a vessel's art, following the boat's condition
## (VesselCondition bands): nothing when sound, scuffs and worn fittings when
## worn, cracks and damaged planking when damaged, many cracks, broken
## planking and (below deck) water on the sole when critical.
##
## Purely cosmetic and separate from the art: it never touches the slot
## sprites or procedural shapes, and has no collision. The marks are placed
## once, deterministically per boat and area, inside the boat's own outline
## (the base slots' shapes), so they look the same every time. A drawn
## replacement can be supplied per band as a PNG on the art canvas
## (VesselVisualProfile.get_damage_texture: <art>/<deck|cabin>/damage_<band>.png);
## it is then shown instead of the procedural marks.

const MARKS_PER_BAND := {
	VesselCondition.BAND_SOUND: 0,
	VesselCondition.BAND_WORN: 14,
	VesselCondition.BAND_DAMAGED: 34,
	VesselCondition.BAND_CRITICAL: 60,
}
const SCUFF := Color(0.18, 0.16, 0.14, 0.42)
const RUST := Color(0.55, 0.32, 0.16, 0.5)
const CRACK := Color(0.08, 0.06, 0.05, 0.8)
const PATCH := Color(0.22, 0.17, 0.12, 0.55)
const WATER := Color(0.36, 0.55, 0.62, 0.42)

var condition := VesselCondition.FULL
var band: StringName = VesselCondition.BAND_SOUND
## "deck" or "cabin".
var area := "deck"

var _canvas := Rect2()
var _outlines: Array[PackedVector2Array] = []
var _marks: Array[Dictionary] = []
var _profile: VesselVisualProfile
var _sprite: Sprite2D


## Reads the boat's outline from `visual`'s base slots and places the marks.
func setup(visual: VesselVisual, area_name: String, key: String) -> void:
	area = area_name
	_canvas = visual.canvas
	_profile = visual.profile
	_outlines.clear()
	var slots := [&"CabinBase"] if area == "cabin" else [&"HullBase", &"DeckBase"]
	for slot_name in slots:
		var slot := visual.get_slot(slot_name)
		if slot:
			_collect_outlines(slot, visual)
	_place_marks(key)


## Shows the damage for `percent` (0-100).
func set_condition(percent: float) -> void:
	condition = percent
	band = VesselCondition.band_of(percent)
	var texture := _profile.get_damage_texture(area, band) if _profile else null
	if texture:
		if _sprite == null:
			_sprite = Sprite2D.new()
			_sprite.centered = false
			add_child(_sprite)
		_sprite.texture = texture
		_sprite.position = _canvas.position
		_sprite.scale = Vector2.ONE * (_canvas.size.x / float(texture.get_width()))
		_sprite.visible = true
	elif _sprite:
		_sprite.visible = false
	queue_redraw()


## Number of procedural marks shown now (0 when sound or a sprite is used).
func get_visible_mark_count() -> int:
	if _sprite and _sprite.visible:
		return 0
	return mini(MARKS_PER_BAND[band], _marks.size())


func uses_sprite() -> bool:
	return _sprite != null and _sprite.visible


func _draw() -> void:
	for i in get_visible_mark_count():
		var mark := _marks[i]
		var at: Vector2 = mark.at
		var size: float = mark.size
		var angle: float = mark.angle
		var dir := Vector2.from_angle(angle)
		match mark.kind:
			"scuff":
				draw_line(at - dir * size, at + dir * size, SCUFF, 2.0, true)
				draw_line(at - dir * size * 0.6 + dir.orthogonal() * 3.0, at + dir * size * 0.5 + dir.orthogonal() * 3.0, SCUFF, 1.5, true)
			"rust":
				draw_circle(at, size * 0.35, RUST)
				draw_circle(at + dir * size * 0.3, size * 0.2, RUST)
			"crack":
				var points := PackedVector2Array([at])
				var p := at
				for k in 5:
					var bend := sin(float(mark.seed + k) * 2.3) * 0.7
					p += Vector2.from_angle(angle + bend) * size * 0.45
					points.append(p)
				draw_polyline(points, CRACK, 2.0, true)
				draw_line(points[2], points[2] + Vector2.from_angle(angle + 1.1) * size * 0.4, CRACK, 1.5, true)
			"patch":
				var poly := PackedVector2Array()
				for k in 7:
					var r := size * (0.7 + 0.3 * sin(float(mark.seed) + k * 1.9))
					poly.append(at + Vector2.from_angle(angle + k * TAU / 7.0) * r)
				draw_colored_polygon(poly, WATER if area == "cabin" and mark.seed % 2 == 0 else PATCH)


func _place_marks(key: String) -> void:
	_marks.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key)
	var bounds := _bounds()
	var scale := clampf(_canvas.size.x / 1100.0, 0.6, 1.6)
	var kinds := ["scuff", "scuff", "rust", "scuff", "rust", "crack", "patch", "crack", "scuff", "crack"]
	var attempts := 0
	while _marks.size() < MARKS_PER_BAND[VesselCondition.BAND_CRITICAL] and attempts < 4000:
		attempts += 1
		var at := Vector2(rng.randf_range(bounds.position.x, bounds.end.x), rng.randf_range(bounds.position.y, bounds.end.y))
		if not _inside(at):
			continue
		# The first marks are the mildest (scuffs, worn fittings); cracks and
		# damaged planking only appear as the condition gets worse.
		var index := _marks.size()
		var kind: String = kinds[index % kinds.size()] if index >= MARKS_PER_BAND[VesselCondition.BAND_WORN] \
			else ("rust" if index % 3 == 2 else "scuff")
		var size := rng.randf_range(10.0, 22.0) * scale
		if kind == "patch":
			size *= 1.4
		_marks.append({"kind": kind, "at": at, "size": size, "angle": rng.randf_range(0.0, TAU), "seed": rng.randi_range(0, 1000)})


func _collect_outlines(node: Node, visual: VesselVisual) -> void:
	for child in node.get_children():
		var item := child as Node2D
		if item == null or child is Sprite2D or child is Label:
			continue
		var transform := Transform2D.IDENTITY
		var walk: Node = item
		while walk != null and walk != visual:
			if walk is Node2D:
				transform = (walk as Node2D).transform * transform
			walk = walk.get_parent()
		var points := PackedVector2Array()
		if child is Polygon2D:
			points = (child as Polygon2D).polygon
		elif child is ProceduralShape:
			points = (child as ProceduralShape).get_points()
		if points.size() >= 3:
			_outlines.append(transform * points)


func _bounds() -> Rect2:
	if _outlines.is_empty():
		return _canvas.grow(-_canvas.size.y * 0.25)
	var box := Rect2(_outlines[0][0], Vector2.ZERO)
	for outline in _outlines:
		for p in outline:
			box = box.expand(p)
	return box


func _inside(point: Vector2) -> bool:
	if _outlines.is_empty():
		return true
	for outline in _outlines:
		if Geometry2D.is_point_in_polygon(point, outline):
			return true
	return false
