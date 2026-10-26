class_name FenderStowage
extends RefCounted
## The fenders (Iteration 17). The white objects hanging over the starboard
## side in every boat's illustrated deck art are fenders, painted into
## deck_base.png (deck_details.png on the Wing 33). Fenders belong out in
## harbour and on board underway, so underway the deck is drawn from a copy of
## that texture with the fenders taken out; in harbour the original art shows.
## The art files themselves are never changed.
##
## Finding them: near-white opaque blobs of fender size in the band below
## the hull (the bottom BAND of the image, outside the boat), found once per
## texture and cached for the run. Each is cleared with a margin that takes
## its line to the rail and its soft shadow too. The scan steps STEP pixels,
## so it costs a few tens of milliseconds once.

const SLOTS: Array[StringName] = [&"DeckBase", &"DeckDetails"]
const BAND := 0.16
const STEP := 2
const MIN_SIZE := Vector2i(12, 25)
const MAX_SIZE := Vector2i(60, 90)
## Margin cleared around a fender: [left, top, right, bottom] in pixels.
const MARGIN := [8, 26, 12, 16]

## texture -> {"rects": Array[Rect2i], "stowed": Texture2D}
static var _cache := {}


static func is_light(c: Color) -> bool:
	return c.a > 0.6 and c.r > 0.78 and c.g > 0.76 and c.b > 0.7


## The fenders painted on `texture` (pixel rectangles), cached.
static func find_fenders(texture: Texture2D) -> Array[Rect2i]:
	return _entry(texture).rects


static func stowed_texture(texture: Texture2D) -> Texture2D:
	return _entry(texture).stowed


static func _entry(texture: Texture2D) -> Dictionary:
	if _cache.has(texture):
		return _cache[texture]
	var entry := {"rects": [] as Array[Rect2i], "stowed": texture}
	_cache[texture] = entry
	var image := texture.get_image()
	if image == null:
		return entry
	if image.is_compressed():
		image.decompress()
	var w := image.get_width()
	var h := image.get_height()
	var top := int(h * (1.0 - BAND))
	# Coarse grid of light pixels, grouped into connected blobs.
	var cols := (w + STEP - 1) / STEP
	var light := {}
	for y in range(top, h, STEP):
		for x in range(0, w, STEP):
			if is_light(image.get_pixel(x, y)):
				light[Vector2i(x / STEP, (y - top) / STEP)] = true
	var seen := {}
	var rects: Array[Rect2i] = []
	for cell: Vector2i in light:
		if seen.has(cell):
			continue
		var stack: Array[Vector2i] = [cell]
		seen[cell] = true
		var lo := cell
		var hi := cell
		while not stack.is_empty():
			var c: Vector2i = stack.pop_back()
			lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.y))
			hi = Vector2i(maxi(hi.x, c.x), maxi(hi.y, c.y))
			for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var n: Vector2i = c + d
				if light.has(n) and not seen.has(n):
					seen[n] = true
					stack.append(n)
		var rect := Rect2i(lo.x * STEP, top + lo.y * STEP, (hi.x - lo.x + 1) * STEP, (hi.y - lo.y + 1) * STEP)
		if rect.size.x >= MIN_SIZE.x and rect.size.y >= MIN_SIZE.y and rect.size.x <= MAX_SIZE.x and rect.size.y <= MAX_SIZE.y:
			rects.append(rect)
	entry.rects = rects
	if rects.is_empty() or cols <= 0:
		return entry
	var stowed := image.duplicate() as Image
	for rect in rects:
		var clear := rect.grow_individual(MARGIN[0], MARGIN[1], MARGIN[2], MARGIN[3]).intersection(Rect2i(0, top - MARGIN[1], w, h))
		stowed.fill_rect(clear, Color(0, 0, 0, 0))
	entry.stowed = ImageTexture.create_from_image(stowed)
	return entry


## Shows the fenders out (in harbour) or stowed (underway) on `visual`.
static func apply(visual: VesselVisual, out: bool) -> int:
	var count := 0
	if visual == null:
		return count
	for slot_name in SLOTS:
		var slot := visual.get_slot(slot_name)
		if slot == null or not slot.is_sprite():
			continue
		var sprite := slot.get_sprite()
		if not sprite.has_meta(&"art_texture") or (sprite.texture != sprite.get_meta(&"art_texture") and sprite.texture != stowed_texture(sprite.get_meta(&"art_texture"))):
			sprite.set_meta(&"art_texture", sprite.texture)  # (re)loaded art
		var art: Texture2D = sprite.get_meta(&"art_texture")
		count += find_fenders(art).size()
		sprite.texture = art if out else stowed_texture(art)
	return count
