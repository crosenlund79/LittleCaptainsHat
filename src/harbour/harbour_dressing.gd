class_name HarbourDressing
extends Node2D
## The illustrated harbour around a moored boat (Visual Identity V01
## prototype): a hand-drawn guest pontoon with mooring lines and cleats, a
## stone quay beyond it, gentle variation in the water, wooden signs for the
## services the harbour has (the grocery store; the boatyard with repairs) and
## the harbour's illustration beyond the quay: its own landmarks (HarbourArt)
## or the illustration of its look (HarbourLooks, I021).
##
## Art only. BoatArea adds it to the deck's Surroundings/Mooring, so it is
## shown only in port, above the water and below the boat. It reads the
## mooring's existing nodes (Pontoon, *Line, Cleat*, the sign labels) and the
## deck's stations for its positions, so it fits every boat's deck without
## changing any collision, station, spawn point or the mooring itself. While
## the Artwork setting is Classic it hides itself and the original pontoon
## drawing shows instead. A harbour with neither its own art nor a look gets
## the generic harbour, without an illustration.

const INK := Color("#342c26")
const PLANK := Color("#a98b62")
const PLANK_DARK := Color("#7c6243")
const STONE := Color("#b9ae9a")
const STONE_DARK := Color("#8d8473")
const ROPE := Color("#d6c49c")
const WATER_LIGHT := Color(0.62, 0.82, 0.84, 0.12)
const WAVE := Color(0.82, 0.92, 0.93, 0.35)
const SIGN_BOARD := Color("#8a6a4a")
const SIGN_TEXT := Color("#f3ede0")
const LAMP := Color("#2b2d30")
const BRASS := Color("#c79f6d")
## Depth of the quay drawn beyond the pontoon (scene units).
const QUAY_DEPTH := 130.0
## Facilities shown as signs: station id -> [sign text, icon, the label node
## of the classic pontoon drawing whose place the sign takes].
const FACILITIES := {&"grocery": ["Groceries", &"basket", "GrocerySign"],
	&"boatyard": ["Boatyard · Repairs", &"wrench", "BoatyardSign"],
	&"go_ashore": ["Go Ashore", &"compass", "GoAshoreSign"]}
## Original mooring nodes the illustration replaces while it is shown (the
## sign labels stay: they get the sign's text and the display font).
const REPLACED_PREFIXES := ["Plank", "Cleat"]

var _area: BoatArea
var _mooring: Node2D
var _pontoon := Rect2()
var _lines: Array[PackedVector2Array] = []
var _cleats: Array[Vector2] = []
var _signs: Array[Dictionary] = []
var _landmarks: Array[HarbourLandmark] = []
var _art: HarbourArt
var _font: Font
var _label_settings_classic: LabelSettings
var _label_settings_sign: LabelSettings
var _port_id: StringName = &""
## The classic sign labels' text and settings, to restore under Classic.
var _sign_classic := {}


## Reads the deck's mooring and stations. Call once, after adding to the tree.
func setup(area: BoatArea, mooring: Node2D) -> void:
	_area = area
	_mooring = mooring
	z_index = 0
	var pontoon := mooring.get_node_or_null(^"Pontoon") as Polygon2D
	if pontoon:
		var bounds := Rect2(pontoon.polygon[0], Vector2.ZERO)
		for p in pontoon.polygon:
			bounds = bounds.expand(p)
		_pontoon = bounds
	for child in mooring.get_children():
		if child is Line2D and String(child.name).ends_with("Line"):
			_lines.append((child as Line2D).points)
		elif child is Polygon2D and String(child.name).begins_with("Cleat"):
			var poly := (child as Polygon2D).polygon
			var c := Vector2.ZERO
			for p in poly:
				c += p
			_cleats.append(c / maxf(poly.size(), 1))
	var theme := ThemeDB.get_project_theme()
	_font = theme.get_font(&"font", &"DisplayHeader") if theme else ThemeDB.fallback_font
	var label := area.mooring_label
	if label:
		_label_settings_classic = label.label_settings
		_label_settings_sign = LabelSettings.new()
		_label_settings_sign.font = _font
		_label_settings_sign.font_size = 26
		_label_settings_sign.font_color = SIGN_TEXT
		_label_settings_sign.outline_size = 6
		_label_settings_sign.outline_color = Color(INK, 0.85)
	refresh()


## Follows the Artwork setting and the harbour the boat lies in.
func refresh() -> void:
	var illustrated := SettingsManager.get_art_style() == SettingsManager.ART_ILLUSTRATED
	visible = illustrated
	for child in _mooring.get_children():
		if child == self:
			continue
		for prefix: String in REPLACED_PREFIXES:
			if String(child.name).begins_with(prefix):
				(child as CanvasItem).visible = not illustrated
		if child is Line2D and String(child.name).ends_with("Line"):
			(child as CanvasItem).visible = not illustrated
	if _area.mooring_label:
		_area.mooring_label.label_settings = _label_settings_sign if illustrated else _label_settings_classic
	for facility: Array in FACILITIES.values():
		var sign_label := _mooring.get_node_or_null(NodePath(String(facility[2]))) as Label
		if sign_label == null:
			continue
		if not _sign_classic.has(sign_label.name):
			_sign_classic[sign_label.name] = [sign_label.text, sign_label.label_settings]
		var classic: Array = _sign_classic[sign_label.name]
		sign_label.text = facility[0] if illustrated else classic[0]
		sign_label.label_settings = _sign_text_settings() if illustrated else classic[1]
	_port_id = GameSession.get_location_id()
	# The harbour's own landmarks, else the illustration of its look (I021).
	_art = HarbourLooks.get_default().art_for(_port_id)
	_landmarks = _art.get_landmarks() if _art else ([] as Array[HarbourLandmark])
	_signs.clear()
	var stations := _area.get_node_or_null(^"Layout/Stations")
	if stations:
		for station: Interactable in stations.get_children():
			if FACILITIES.has(station.interaction_id) and station.enabled:
				var facility: Array = FACILITIES[station.interaction_id]
				var label := _mooring.get_node_or_null(NodePath(String(facility[2]))) as Control
				var at: Vector2
				if station.has_meta(&"sign_at"):  # the shore slot (Iteration 12)
					at = station.get_meta(&"sign_at")
				elif label:
					at = label.position + label.size / 2.0
				else:
					at = Vector2(station.position.x, _pontoon.position.y + 30.0)
				_signs.append({"id": station.interaction_id, "at": at, "text": facility[0], "icon": facility[1], "label": label != null})
	_update_sign_highlights()
	queue_redraw()


## Each sign board is what its station highlights (Iteration 12).
func _update_sign_highlights() -> void:
	for child in get_children():
		if child is HighlightProvider:
			remove_child(child)
			child.queue_free()
	for sign in _signs:
		add_child(HighlightProvider.create(sign.id, HighlightResolver.rounded_rect(sign_board(sign).grow(5.0), 9.0)))


## The sign's board rectangle (this node's coordinates).
func sign_board(sign: Dictionary) -> Rect2:
	var text_width := _font.get_string_size(String(sign.text), HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
	var center: Vector2 = sign.at
	return Rect2(center - Vector2(text_width / 2.0 + 36.0, 18), Vector2(text_width + 50.0, 36))


func _sign_text_settings() -> LabelSettings:
	var settings := LabelSettings.new()
	settings.font = _font
	settings.font_size = 24
	settings.font_color = SIGN_TEXT
	return settings


## The services shown as signs right now (station ids), for tests.
func get_sign_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for sign in _signs:
		ids.append(sign.id)
	return ids


func get_landmarks() -> Array[HarbourLandmark]:
	return _landmarks


## The quay's lamp posts (this node's coordinates), as _draw_quay places
## them: every third post along the quay edge (Iteration 17: lit at night).
func get_lamp_positions() -> PackedVector2Array:
	var lamps := PackedVector2Array()
	if _pontoon.size == Vector2.ZERO:
		return lamps
	var top := _pontoon.end.y + 6.0
	var left := _pontoon.position.x - 40.0
	var right := _pontoon.end.x + 40.0
	var bx := left + 80.0
	var i := 0
	while bx < right - 40.0:
		if i % 3 == 1:
			lamps.append(Vector2(bx, top + 8.0))
		bx += 190.0
		i += 1
	return lamps


## Soft walkway lights along the pontoon (this node's coordinates).
func get_pontoon_light_positions() -> PackedVector2Array:
	var spots := PackedVector2Array()
	if _pontoon.size == Vector2.ZERO:
		return spots
	var x := _pontoon.position.x + 120.0
	while x < _pontoon.end.x - 60.0:
		spots.append(Vector2(x, _pontoon.get_center().y))
		x += 320.0
	return spots


func get_quay_anchor() -> Vector2:
	return Vector2(_pontoon.get_center().x, _pontoon.end.y)


# --- Drawing ------------------------------------------------------------------------

func _draw() -> void:
	if _pontoon.size == Vector2.ZERO:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 17  # the same harbour every frame
	_draw_water(rng)
	_draw_quay(rng)
	for landmark in _landmarks:
		_draw_landmark(landmark)
	_draw_pontoon(rng)
	for line in _lines:
		_draw_rope(line)
	for cleat in _cleats:
		_draw_cleat(cleat)
	for sign in _signs:
		_draw_sign(sign)


func _draw_water(rng: RandomNumberGenerator) -> void:
	# Soft lighter patches and a few small wave strokes, kept away from the boat.
	for i in 14:
		var c := Vector2(rng.randf_range(-700, 700), rng.randf_range(-330, -190) if i % 2 == 0 else rng.randf_range(195, 235))
		var r := rng.randf_range(40, 110)
		draw_colored_polygon(_blob(c, Vector2(r, r * 0.35), rng.randi()), WATER_LIGHT)
	for i in 18:
		var c := Vector2(rng.randf_range(-720, 720), rng.randf_range(-320, -195) if i % 3 else rng.randf_range(196, 232))
		var w := rng.randf_range(14, 30)
		var pts := PackedVector2Array()
		for k in 7:
			var t := k / 6.0
			pts.append(c + Vector2(w * (t - 0.5) * 2.0, -sin(t * PI) * 3.0))
		draw_polyline(pts, WAVE, 2.0, true)


func _draw_quay(rng: RandomNumberGenerator) -> void:
	var top := _pontoon.end.y + 6.0
	var quay := Rect2(_pontoon.position.x - 40.0, top, _pontoon.size.x + 80.0, QUAY_DEPTH)
	draw_rect(Rect2(quay.position + Vector2(0, -6), Vector2(quay.size.x, 6)), Color(0.07, 0.17, 0.2, 0.9))  # gap of water
	draw_rect(quay, STONE)
	# Granite edging blocks, then cobbles.
	var x := quay.position.x
	while x < quay.end.x:
		var w := rng.randf_range(38, 62)
		var block := Rect2(x, top, minf(w, quay.end.x - x), 16)
		draw_rect(block, STONE.lerp(STONE_DARK, rng.randf_range(0.0, 0.4)))
		draw_polyline(_wobbly_rect(block, rng), Color(INK, 0.7), 1.4, true)
		x += w
	var y := top + 22.0
	while y < quay.end.y - 4.0:
		x = quay.position.x + rng.randf_range(0, 10)
		while x < quay.end.x - 4.0:
			var size := Vector2(rng.randf_range(12, 18), rng.randf_range(9, 12))
			draw_rect(Rect2(Vector2(x, y), size), STONE.lerp(STONE_DARK, rng.randf_range(0.05, 0.35)))
			x += size.x + 3.0
		y += 14.0
	# Bollards and lamp posts along the quay edge.
	var bx := quay.position.x + 80.0
	var i := 0
	while bx < quay.end.x - 40.0:
		var at := Vector2(bx, top + 8.0)
		if i % 3 == 1:
			draw_circle(at + Vector2(3, 4), 9.0, Color(0, 0, 0, 0.25))
			draw_circle(at, 9.0, LAMP)
			draw_circle(at, 4.5, Color("#f2d58a"))
			draw_arc(at, 9.0, 0, TAU, 20, INK, 1.4, true)
		else:
			draw_circle(at + Vector2(2, 3), 7.0, Color(0, 0, 0, 0.25))
			draw_circle(at, 7.0, Color("#3e4347"))
			draw_arc(at, 7.0, 0, TAU, 18, INK, 1.4, true)
		bx += 190.0
		i += 1


func _draw_landmark(landmark: HarbourLandmark) -> void:
	var size := landmark.texture.get_size()
	var scale := landmark.width / maxf(size.x, 1.0)
	var center := get_quay_anchor() + landmark.offset
	draw_texture_rect(landmark.texture, Rect2(center - size * scale / 2.0, size * scale), false)


func _draw_pontoon(rng: RandomNumberGenerator) -> void:
	var p := _pontoon
	draw_rect(Rect2(p.position + Vector2(6, 8), p.size), Color(0, 0, 0, 0.28))  # shadow on the water
	var x := p.position.x
	var board := 44.0
	while x < p.end.x - 0.5:
		var w := minf(board, p.end.x - x)
		var rect := Rect2(x, p.position.y, w, p.size.y)
		draw_rect(rect, PLANK.lerp(PLANK_DARK, rng.randf_range(0.0, 0.35)))
		for k in 2:  # grain
			var gx := x + rng.randf_range(0.2, 0.8) * w
			var pts := PackedVector2Array()
			var gy := p.position.y + 3.0
			var phase := rng.randf_range(0, TAU)
			while gy < p.end.y - 3.0:
				pts.append(Vector2(gx + sin(gy / 13.0 + phase) * 2.0, gy))
				gy += 6.0
			draw_polyline(pts, Color(PLANK_DARK, 0.45), 1.0, true)
		draw_line(Vector2(x, p.position.y), Vector2(x, p.end.y), Color(INK, 0.55), 1.2, true)
		if rng.randf() < 0.5:  # a nail or two
			draw_circle(Vector2(x + 6, p.position.y + 8), 1.4, Color(INK, 0.6))
			draw_circle(Vector2(x + 6, p.end.y - 8), 1.4, Color(INK, 0.6))
		x += board
	# The pontoon's float edge and a rub rail on the water side.
	draw_rect(Rect2(p.position, Vector2(p.size.x, 7)), Color("#5f4a33"))
	draw_polyline(_wobbly_rect(p, rng), INK, 2.2, true)


func _draw_rope(points: PackedVector2Array) -> void:
	if points.size() < 2:
		return
	# A gentle sag between the boat and the cleat.
	var a := points[0]
	var b := points[points.size() - 1]
	var pts := PackedVector2Array()
	var normal := (b - a).orthogonal().normalized()
	for k in 13:
		var t := k / 12.0
		pts.append(a.lerp(b, t) + normal * sin(t * PI) * 6.0)
	draw_polyline(pts, INK, 4.2, true)
	draw_polyline(pts, ROPE, 2.6, true)


func _draw_cleat(c: Vector2) -> void:
	var body := Rect2(c - Vector2(16, 4), Vector2(32, 8))
	draw_rect(Rect2(body.position + Vector2(2, 3), body.size), Color(0, 0, 0, 0.3))
	draw_rect(body, Color("#9aa0a4"))
	draw_rect(body, INK, false, 1.4)
	draw_circle(c, 3.0, Color("#6c7276"))


func _draw_sign(sign: Dictionary) -> void:
	# The board and its icon; the text is the sign's own Label (drawn on top).
	var text: String = sign.text
	var text_width := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
	var center: Vector2 = sign.at
	var board := sign_board(sign)
	draw_rect(Rect2(board.position + Vector2(4, 5), board.size), Color(0, 0, 0, 0.3))
	draw_rect(board, SIGN_BOARD)
	draw_rect(board.grow(-3), Color(SIGN_BOARD.lightened(0.12), 0.6), false, 1.0)
	draw_rect(board, INK, false, 2.0)
	_draw_icon(sign.icon, Vector2(board.position.x + 17, center.y))
	if not sign.label:
		draw_string(_font, Vector2(center.x - text_width / 2.0, center.y + 8), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, SIGN_TEXT)


func _draw_icon(icon: StringName, at: Vector2) -> void:
	match icon:
		&"basket":
			var basket := PackedVector2Array([at + Vector2(-9, -2), at + Vector2(9, -2), at + Vector2(6, 9), at + Vector2(-6, 9)])
			draw_colored_polygon(basket, Color("#e3c27a"))
			draw_polyline(basket + PackedVector2Array([basket[0]]), INK, 1.4, true)
			draw_arc(at + Vector2(0, -2), 7.0, PI, TAU, 12, INK, 1.6, true)
			draw_circle(at + Vector2(-3, -4), 2.6, Color("#c8553d"))
			draw_circle(at + Vector2(3, -5), 2.4, Color("#7ba05b"))
		&"compass":
			draw_circle(at, 8.0, Color("#efe5cc"))
			draw_arc(at, 8.0, 0, TAU, 18, INK, 1.4, true)
			draw_colored_polygon(PackedVector2Array([at + Vector2(0, -7), at + Vector2(2.5, 0), at + Vector2(-2.5, 0)]), Color("#c8553d"))
			draw_colored_polygon(PackedVector2Array([at + Vector2(0, 7), at + Vector2(2.5, 0), at + Vector2(-2.5, 0)]), Color("#3e4347"))
		&"wrench":
			draw_line(at + Vector2(-7, 7), at + Vector2(5, -5), Color("#d8dde0"), 3.0, true)
			draw_arc(at + Vector2(6, -6), 4.5, -PI * 0.25, PI * 1.25, 10, Color("#d8dde0"), 3.0, true)
			draw_line(at + Vector2(-7, 7), at + Vector2(5, -5), INK, 0.8, true)


static func _blob(center: Vector2, radii: Vector2, seed: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 20:
		var t := TAU * i / 20.0
		var w := 1.0 + 0.12 * sin(t * 3.0 + seed) + 0.08 * sin(t * 5.0 + seed * 0.7)
		pts.append(center + Vector2(cos(t) * radii.x, sin(t) * radii.y) * w)
	return pts


static func _wobbly_rect(rect: Rect2, rng: RandomNumberGenerator) -> PackedVector2Array:
	var corners := [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y), rect.position]
	var pts := PackedVector2Array()
	for i in 4:
		var a: Vector2 = corners[i]
		var b: Vector2 = corners[i + 1]
		var n := maxi(2, int(a.distance_to(b) / 40.0))
		for k in n:
			var p := a.lerp(b, float(k) / n)
			pts.append(p + Vector2(rng.randf_range(-0.8, 0.8), rng.randf_range(-0.8, 0.8)))
	pts.append(pts[0])
	return pts
