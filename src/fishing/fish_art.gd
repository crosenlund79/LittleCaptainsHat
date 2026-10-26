class_name FishArt
extends RefCounted
## The illustrated fish, sharks and junk (Iteration 18): one place that finds
## a catch's pictures, for every screen that shows one (the reel-in, the
## catch, the cool box, the trophy board, and later a fishmonger).
##
## Each fish is painted as layers on one canvas (tools/fishing/paint_fish.py):
## body, tail (turns about its pivot) and lid (the closed eye); junk is one
## picture. Every catch has a small static thumbnail for lists.

const ART_DIR := "res://assets/fishing"
const META_PATH := "res://data/fishing/fish_art.json"

static var _meta := {}
static var _loaded := false


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(META_PATH))
	if data is Dictionary and data.get("art") is Dictionary:
		_meta = data.art
	else:
		push_error("Fish art data %s is missing or invalid." % META_PATH)


static func has_art(id: String) -> bool:
	_ensure_loaded()
	return _meta.has(id)


## {"canvas": [w, h], "kind", "tail_pivot": [x, y], "eye": [x, y, r]} or {}.
static func get_info(id: String) -> Dictionary:
	_ensure_loaded()
	return _meta.get(id, {})


static func get_canvas(id: String) -> Vector2:
	var canvas: Array = get_info(id).get("canvas", [512, 256])
	return Vector2(float(canvas[0]), float(canvas[1]))


static func get_tail_pivot(id: String) -> Vector2:
	var pivot: Array = get_info(id).get("tail_pivot", [0, 0])
	return Vector2(float(pivot[0]), float(pivot[1]))


## Junk is a single picture and never blinks.
static func is_animated(id: String) -> bool:
	return String(get_info(id).get("kind", "junk")) != "junk"


## A layer ("body", "tail", "lid"; "art" for junk), or null.
static func layer(id: String, layer_name: String) -> Texture2D:
	var path := "%s/%s/%s.png" % [ART_DIR, id, layer_name]
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


## The small static picture for lists and trophies.
static func thumbnail(id: String) -> Texture2D:
	return layer(id, "thumb")
