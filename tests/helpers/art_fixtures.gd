class_name TestArtFixtures
extends RefCounted
## Test fixtures for the Sprite Workshop (Revision 0.105b): replacement PNGs
## made in code at test time, written to the manifest's expected path, and
## removed again afterwards (nothing is left installed). The pictures are
## deliberately unmistakable (a bright diagonal check) so a screenshot shows
## at once whether the replacement is in use.

const TEST_COLOUR := Color("#ff2fb4")
const TEST_COLOUR_2 := Color("#ffd400")


## A valid replacement for `entry` (its 2x source size, times `scale`), or
## `size` if given. A 2-pixel transparent border keeps the pet loader from
## treating the check as a background to remove.
static func install(entry: Dictionary, size := Vector2i.ZERO, scale := 1.0) -> String:
	var w := size.x if size.x > 0 else roundi(int(entry.source_width_2x) * scale)
	var h := size.y if size.y > 0 else roundi(int(entry.source_height_2x) * scale)
	var image := Image.create(w, h, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var cell := maxi(mini(w, h) / 6, 2)
	for cy in range(0, h, cell):
		for cx in range(0, w, cell):
			var colour := TEST_COLOUR if ((cx / cell) + (cy / cell)) % 2 == 0 else TEST_COLOUR_2
			image.fill_rect(Rect2i(cx, cy, cell, cell).intersection(Rect2i(2, 2, w - 4, h - 4)), colour)
	var path := String(entry.path)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	image.save_png(path)
	return path


## True when `texture` shows the test check (its first cell is TEST_COLOUR).
static func is_fixture(texture: Texture2D) -> bool:
	if texture == null:
		return false
	var image := texture.get_image()
	if image == null:
		return false
	if image.is_compressed():
		image.decompress()
	var cell := maxi(mini(image.get_width(), image.get_height()) / 6, 2)
	var c := image.get_pixel(mini(cell / 2 + 2, image.get_width() - 1), mini(cell / 2 + 2, image.get_height() - 1))
	return c.r > 0.9 and c.g < 0.35 and c.b > 0.55


## A file with the expected name that is not a PNG at all.
static func install_garbage(entry: Dictionary) -> String:
	var path := String(entry.path)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("not a picture")
	file.close()
	return path


static func remove(entry: Dictionary) -> void:
	var path := String(entry.path)
	for p in [path, path + ".import"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))


## Every PNG under the art_replacements tree (should be none after tests).
static func installed_pngs(dir := ArtworkResolver.ROOT) -> PackedStringArray:
	var found := PackedStringArray()
	var access := DirAccess.open(dir)
	if access == null:
		return found
	for file in access.get_files():
		if file.to_lower().ends_with(".png"):
			found.append(dir.path_join(file))
	for sub in access.get_directories():
		found.append_array(installed_pngs(dir.path_join(sub)))
	return found
