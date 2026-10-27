class_name ArtworkResolver
extends RefCounted
## The Sprite Workshop's replacement loader (Revision 0.105b).
##
## The artist draws a PNG, saves it under the filename a folder's
## `manifest.csv` names (in `art_replacements/...`), runs the game, and it is
## used wherever that asset is drawn. Absent, the game keeps its own art.
##
##   ArtworkResolver.get_artwork(&"pet.snovs.cabin", fallback) -> Texture2D
##
## The manifests are read once, on first use (one small CSV per folder; never
## per frame). Each READY entry's file is looked up once and the result cached
## (texture or "none"). A replacement is used only when it is valid: a PNG
## Godot can read, with the manifest's aspect ratio (within ASPECT_TOLERANCE)
## and a size between MIN_SCALE and MAX_SCALE times the documented 2x source
## size. Anything else is reported once (push_warning and get_warnings()) and
## the original art is kept - a bad or missing optional PNG never stops the
## game.
##
## Loading: a PNG Godot has imported (the editor imports new files when the
## project is opened or the editor regains focus) loads as a normal resource;
## a PNG not yet imported (just copied in) is read from the file directly, so
## the editor-run workflow (download ZIP, extract, open, run) picks it up
## either way. A running game sees a new or changed PNG after it is restarted
## (no hot reloading).
##
## Only entries whose integration_status is READY are resolved: the others
## are catalogue entries for art planning (ADAPTER_REQUIRED, REFERENCE_ONLY).

const ROOT := "res://art_replacements"
const MANIFEST := "manifest.csv"
const STATUS_READY := "READY"
const STATUS_ADAPTER := "ADAPTER_REQUIRED"
const STATUS_REFERENCE := "REFERENCE_ONLY"
const STATUSES := [STATUS_READY, STATUS_ADAPTER, STATUS_REFERENCE]
const REQUIRED_FIELDS := ["asset_id", "filename", "display_name", "description", "category", "current_source",
	"display_width", "display_height", "source_width_2x", "source_height_2x", "complexity", "hand_draw_priority",
	"priority_rank", "view_direction", "view_count", "transparent_background", "pivot_or_origin",
	"replacement_mode", "integration_status", "notes"]
const ASPECT_TOLERANCE := 0.02
const MIN_SCALE := 0.5
const MAX_SCALE := 4.0

## Where the manifests are read from (tests may point it elsewhere).
static var root := ROOT
static var _entries: Dictionary = {}
static var _indexed := false
## asset_id -> Texture2D, or null when there is no usable replacement.
static var _cache: Dictionary = {}
static var _warnings: PackedStringArray = []
static var _warned: Dictionary = {}
## How many times a file was actually loaded (tests: never per frame).
static var loads := 0


## The replacement for `asset_id` if the artist has provided a valid one,
## otherwise `fallback` (which may be null: then the caller keeps drawing its
## own procedural art).
static func get_artwork(asset_id: StringName, fallback: Texture2D = null) -> Texture2D:
	if not _cache.has(asset_id):
		_cache[asset_id] = _resolve(asset_id)
	var texture: Texture2D = _cache[asset_id]
	return texture if texture else fallback


static func has_replacement(asset_id: StringName) -> bool:
	return get_artwork(asset_id) != null


## The manifest row for `asset_id` (with "path" and "folder" added), or {}.
static func get_entry(asset_id: StringName) -> Dictionary:
	_ensure_index()
	return _entries.get(asset_id, {})


static func get_entries() -> Dictionary:
	_ensure_index()
	return _entries


static func get_warnings() -> PackedStringArray:
	return _warnings


## Forgets the index and every cached texture (tests; a running game does not
## need it - restart to see new art).
static func reload() -> void:
	_entries = {}
	_indexed = false
	_cache = {}
	_warnings = []
	_warned = {}


static func _ensure_index() -> void:
	if _indexed:
		return
	_indexed = true
	var paths := {}
	for manifest in find_manifests(root):
		for row in read_manifest(manifest):
			var id := StringName(row.asset_id)
			if _entries.has(id):
				_warn(id, Loc.t("Duplicate asset_id %s in %s (first kept: %s).") % [id, manifest, _entries[id].path])
				continue
			if paths.has(row.path):
				_warn(id, Loc.t("Duplicate output file %s for %s and %s.") % [row.path, paths[row.path], id])
				continue
			paths[row.path] = id
			_entries[id] = row


## Every manifest.csv under `dir` (recursively), sorted.
static func find_manifests(dir: String) -> PackedStringArray:
	var found := PackedStringArray()
	var access := DirAccess.open(dir)
	if access == null:
		return found
	if access.file_exists(MANIFEST):
		found.append(dir.path_join(MANIFEST))
	var subdirs := access.get_directories()
	subdirs.sort()
	for sub in subdirs:
		found.append_array(find_manifests(dir.path_join(sub)))
	return found


## The rows of one manifest as Dictionaries (header names as keys), with
## "folder" and "path" (folder + filename) added. Malformed rows are reported
## and skipped.
static func read_manifest(path: String) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return rows
	var header := file.get_csv_line()
	for field: String in REQUIRED_FIELDS:
		if not field in header:
			_warn(&"", "%s lacks the column %s." % [path, field])
			return rows
	var line := 1
	while not file.eof_reached():
		var values := file.get_csv_line()
		line += 1
		if values.size() == 1 and values[0].strip_edges() == "":
			continue
		if values.size() != header.size():
			_warn(&"", "%s line %d has %d fields, the header %d: skipped." % [path, line, values.size(), header.size()])
			continue
		var row := {}
		for i in header.size():
			row[header[i]] = values[i].strip_edges()
		if String(row.asset_id) == "" or String(row.filename) == "":
			_warn(&"", "%s line %d has no asset_id or filename: skipped." % [path, line])
			continue
		if not String(row.integration_status) in STATUSES:
			_warn(StringName(row.asset_id), "%s line %d: unknown integration_status \"%s\"." % [path, line, row.integration_status])
		row["folder"] = path.get_base_dir()
		row["path"] = path.get_base_dir().path_join(String(row.filename))
		rows.append(row)
	return rows


static func _resolve(asset_id: StringName) -> Texture2D:
	var entry := get_entry(asset_id)
	if entry.is_empty() or entry.integration_status != STATUS_READY:
		return null
	var path := String(entry.path)
	if not path.to_lower().ends_with(".png"):
		_warn(asset_id, Loc.t("%s: replacements must be PNG files (%s).") % [asset_id, path.get_file()])
		return null
	var image: Image = null
	if ResourceLoader.exists(path):
		var texture := load(path) as Texture2D
		image = texture.get_image() if texture else null
		loads += 1
	elif FileAccess.file_exists(path):
		image = Image.load_from_file(ProjectSettings.globalize_path(path))
		loads += 1
	else:
		return null  # Not drawn yet: the original art stays, silently.
	if image == null or image.is_empty():
		_warn(asset_id, Loc.t("%s: %s could not be read as an image; the original art is kept.") % [asset_id, path.get_file()])
		return null
	var problem := validate_size(entry, image.get_width(), image.get_height())
	if problem != "":
		_warn(asset_id, Loc.t("%s: %s %s; the original art is kept.") % [asset_id, path.get_file(), problem])
		return null
	if image.is_compressed():
		image.decompress()
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)


## "" when a `width` x `height` image suits `entry`, else why not.
static func validate_size(entry: Dictionary, width: int, height: int) -> String:
	var want_w := float(entry.get("source_width_2x", "0"))
	var want_h := float(entry.get("source_height_2x", "0"))
	if want_w <= 0.0 or want_h <= 0.0:
		return ""
	var ratio := float(width) / float(maxi(height, 1))
	var want_ratio := want_w / want_h
	if absf(ratio - want_ratio) / want_ratio > ASPECT_TOLERANCE:
		return Loc.format("is %dx%d, but should have the shape of %dx%d (aspect %.3f, not %.3f)", [width, height, roundi(want_w), roundi(want_h), want_ratio, ratio])
	var scale := float(width) / want_w
	if scale < MIN_SCALE or scale > MAX_SCALE:
		return Loc.t("is %dx%d: draw it at about %dx%d (the 2x source size)") % [width, height, roundi(want_w), roundi(want_h)]
	return ""


static func _warn(asset_id: StringName, text: String) -> void:
	var key := "%s|%s" % [asset_id, text]
	if _warned.has(key):
		return
	_warned[key] = true
	_warnings.append(text)
	push_warning("Sprite Workshop: " + text)
