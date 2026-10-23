extends Node
## Renders the art templates for every vessel into
## assets/vessels/<id>/templates/ (a folder Godot does not import):
##
##   <area>_reference.png  the current (procedural) art with the gameplay
##                         landmarks drawn over it
##   <area>_guide.png      the landmarks alone on a transparent canvas, to use
##                         as a layer in a painting program
##
## <area> is "deck" or "cabin". Both images cover the vessel's canvas
## (VesselVisual.canvas) at SCALE pixels per scene unit, which is the size
## sprites should be drawn at (see ART_PIPELINE.md). Run with a display:
##
##   godot --path . --rendering-driver opengl3 res://tools/vessels/render_art_templates.tscn
##
## Landmark colours: red = solid collision, green = walkable fixture,
## teal = interaction station, blue = player spawn, orange = companion
## resting spot, magenta = sail attachment marker, grey grid = 50 units.

const SCALE := 2.0
const GRID := 50.0
const COLLISION := Color(0.9, 0.25, 0.2, 0.9)
const COLLISION_FILL := Color(0.9, 0.25, 0.2, 0.16)
const WALKABLE := Color(0.25, 0.8, 0.45, 0.9)
const STATION := Color(0.1, 0.75, 0.8, 0.9)
const SPAWN := Color(0.25, 0.45, 0.95, 1.0)
const SPOT := Color(0.95, 0.55, 0.15, 1.0)
const SAIL := Color(0.85, 0.2, 0.75, 1.0)
const GRID_COLOR := Color(0.5, 0.5, 0.5, 0.25)
const AXIS_COLOR := Color(0.2, 0.2, 0.2, 0.6)


class Overlay extends Node2D:
	var items: Array = []  # [kind, data...] drawn in scene units
	var canvas: Rect2
	var title := ""
	var font: Font

	func _draw() -> void:
		var s := 1.0 / SCALE  # one output pixel in scene units
		var x := floorf(canvas.position.x / GRID) * GRID
		while x <= canvas.end.x:
			draw_line(Vector2(x, canvas.position.y), Vector2(x, canvas.end.y), AXIS_COLOR if is_zero_approx(x) else GRID_COLOR, s * (2.0 if is_zero_approx(x) else 1.0))
			if int(x) % 100 == 0:
				draw_string(font, Vector2(x + 3, canvas.end.y - 6), str(int(x)), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, AXIS_COLOR)
			x += GRID
		var y := floorf(canvas.position.y / GRID) * GRID
		while y <= canvas.end.y:
			draw_line(Vector2(canvas.position.x, y), Vector2(canvas.end.x, y), AXIS_COLOR if is_zero_approx(y) else GRID_COLOR, s * (2.0 if is_zero_approx(y) else 1.0))
			if int(y) % 100 == 0:
				draw_string(font, Vector2(canvas.position.x + 4, y - 3), str(int(y)), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, AXIS_COLOR)
			y += GRID
		draw_rect(canvas, AXIS_COLOR, false, s * 3.0)
		draw_string(font, canvas.position + Vector2(8, 18), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.1, 0.1, 0.1, 0.9))
		for item: Array in items:
			match item[0]:
				"poly":
					var points: PackedVector2Array = item[1]
					if item[2]:
						draw_colored_polygon(points, COLLISION_FILL)
					var loop := points.duplicate()
					loop.append(points[0])
					draw_polyline(loop, COLLISION if item[2] else WALKABLE, s * 3.0, true)
				"segments":  # segment mode closes the loop
					var outline: PackedVector2Array = item[1].duplicate()
					outline.append(outline[0])
					draw_polyline(outline, COLLISION, s * 4.0, true)
				"station_rect":
					var r: Rect2 = item[1]
					draw_rect(r, Color(STATION, 0.2))
					draw_rect(r, STATION, false, s * 3.0)
					_label(item[2], r.get_center(), STATION)
				"station_circle":
					draw_circle(item[1], item[2], Color(STATION, 0.2))
					draw_arc(item[1], item[2], 0, TAU, 32, STATION, s * 3.0)
					_label(item[3], item[1], STATION)
				"spawn":
					var p: Vector2 = item[1]
					draw_circle(p, 20.0, Color(SPAWN, 0.18))  # the player's body
					draw_line(p - Vector2(8, 0), p + Vector2(8, 0), SPAWN, s * 3.0)
					draw_line(p - Vector2(0, 8), p + Vector2(0, 8), SPAWN, s * 3.0)
					_label(item[2], p + Vector2(0, 14), SPAWN)
				"spot":
					draw_circle(item[1], 6.0, SPOT)
					_label(item[2], item[1] + Vector2(0, -12), SPOT)
				"sail":
					var q: Vector2 = item[1]
					draw_colored_polygon(PackedVector2Array([q + Vector2(0, -7), q + Vector2(7, 0), q + Vector2(0, 7), q + Vector2(-7, 0)]), SAIL)
					_label(item[2], q + Vector2(0, -12), SAIL)

	func _label(text: String, at: Vector2, col: Color) -> void:
		var size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, 11)
		draw_string_outline(font, at + Vector2(-size.x / 2.0, 4), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, 3, Color(1, 1, 1, 0.85))
		draw_string(font, at + Vector2(-size.x / 2.0, 4), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, col)


func _ready() -> void:
	await get_tree().process_frame
	for vessel in VesselCatalog.get_default().vessels:
		var folder := ProjectSettings.globalize_path(vessel.visual_profile.art_folder.path_join("templates"))
		DirAccess.make_dir_recursive_absolute(folder)
		var ignore := FileAccess.open(folder.path_join(".gdignore"), FileAccess.WRITE)
		ignore.store_string("")
		ignore.close()
		var cabin_visual: PackedScene = load(vessel.cabin_scene.resource_path.get_base_dir().path_join("cabin_visual.tscn"))
		for area in ["deck", "cabin"]:
			var gameplay: PackedScene = vessel.deck_scene if area == "deck" else vessel.cabin_scene
			var visual_scene: PackedScene = vessel.deck_visual_scene if area == "deck" else cabin_visual
			var title := "%s (%s) - %s - landmarks over the art; sprite canvas %s at %dx" % [
				vessel.display_name, vessel.get_hull_type_name(), area, "%s", int(SCALE)]
			for with_art in [true, false]:
				var image := await _render(gameplay, visual_scene, with_art, title)
				var path := folder.path_join("%s_%s.png" % [area, "reference" if with_art else "guide"])
				image.save_png(path)
				print("wrote ", path)
	get_tree().quit()


func _render(gameplay: PackedScene, visual_scene: PackedScene, with_art: bool, title: String) -> Image:
	var visual := visual_scene.instantiate() as VesselVisual
	var canvas := visual.canvas
	var viewport := SubViewport.new()
	viewport.size = Vector2i(canvas.size * SCALE)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	var root := Node2D.new()
	root.scale = Vector2(SCALE, SCALE)
	root.position = -canvas.position * SCALE
	viewport.add_child(root)
	if with_art:
		root.add_child(visual)
		visual.apply(null)
	else:
		visual.free()
	var overlay := Overlay.new()
	overlay.canvas = canvas
	overlay.font = ThemeDB.fallback_font
	overlay.title = title % [str(canvas)]
	overlay.z_index = 100
	overlay.items = _landmarks(gameplay)
	root.add_child(overlay)
	add_child(viewport)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	viewport.queue_free()
	return image


## The gameplay landmarks of a deck or cabin scene, read without running it.
func _landmarks(gameplay: PackedScene) -> Array:
	var scene := gameplay.instantiate()
	var items := []
	var layout := scene.get_node("Layout")
	for node in layout.find_children("*", "", true, false):
		var at := _local_position(node, scene)
		if node is BoatFixture:
			var fixture := node as BoatFixture
			var points := PackedVector2Array()
			for p in fixture.get_points():
				points.append(p + at)
			items.append(["poly", points, fixture.solid])
		elif node is CollisionPolygon2D and not (node.get_parent() is BoatFixture):
			var points := PackedVector2Array()
			for p in (node as CollisionPolygon2D).polygon:
				points.append(p + at)
			items.append(["segments", points])
		elif node is Interactable:
			var shape := (node.get_node("CollisionShape2D") as CollisionShape2D).shape
			var name := "%s (%s)" % [node.name, (node as Interactable).interaction_id]
			if shape is RectangleShape2D:
				items.append(["station_rect", Rect2(at - shape.size / 2.0, shape.size), name])
			elif shape is CircleShape2D:
				items.append(["station_circle", at, shape.radius, name])
		elif node is Marker2D:
			match String(node.get_parent().name):
				"SpawnPoints":
					items.append(["spawn", at, "spawn: " + node.name])
				"CompanionSpots":
					items.append(["spot", at, "pet: " + node.name])
				"SailMarkers":
					items.append(["sail", at, node.name])
	scene.free()
	return items


static func _local_position(node: Node, scene: Node) -> Vector2:
	var at := Vector2.ZERO
	var current := node
	while current != scene:
		if current is Node2D:
			at += (current as Node2D).position
		current = current.get_parent()
	return at
