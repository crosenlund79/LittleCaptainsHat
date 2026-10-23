class_name VesselVisualProfile
extends Resource
## Which artwork a vessel uses, slot by slot. Every slot falls back in the same
## explicit order:
##   1. the texture assigned here in the inspector;
##   2. a PNG at the conventional path  <art_folder>/<deck|cabin>/<file>.png
##      (see SLOT_FILES), so dropping a correctly named PNG into the vessel's
##      art folder is enough;
##   3. the procedural (placeholder) drawing already in the scene.
## A missing or unreadable file therefore never makes the boat disappear: the
## slot simply keeps its procedural art. See ART_PIPELINE.md.

## Deck (exterior) slots, in drawing order from bottom to top.
const DECK_SLOTS: Array[StringName] = [
	&"ShadowVisual", &"HullBase", &"DeckBase", &"Coachroof", &"DeckDetails", &"RiggingVisual", &"MastVisual",
	&"BoomVisual", &"MainSailVisual", &"HeadSailVisual", &"SpinnakerVisual",
]
## Cabin (interior) slots, bottom to top.
const CABIN_SLOTS: Array[StringName] = [&"CabinBase", &"FurnitureVisual", &"CabinDetails"]
## Slot -> [inspector property, file name].
const SLOT_FILES := {
	&"ShadowVisual": ["shadow", "shadow.png"],
	&"HullBase": ["hull_base", "hull_base.png"],
	&"DeckBase": ["deck_base", "deck_base.png"],
	&"Coachroof": ["coachroof", "coachroof.png"],
	&"DeckDetails": ["deck_details", "deck_details.png"],
	&"RiggingVisual": ["rigging", "rigging.png"],
	&"MastVisual": ["mast", "mast.png"],
	&"BoomVisual": ["boom", "boom.png"],
	&"MainSailVisual": ["main_sail", "main_sail.png"],
	&"HeadSailVisual": ["head_sail", "head_sail.png"],
	&"SpinnakerVisual": ["spinnaker", "spinnaker.png"],
	&"CabinBase": ["cabin_base", "cabin_base.png"],
	&"FurnitureVisual": ["furniture", "furniture.png"],
	&"CabinDetails": ["cabin_details", "cabin_details.png"],
}

## Folder with this vessel's art, e.g. res://assets/vessels/starling_33.
@export_dir var art_folder := ""
## Set to ignore every sprite and show the procedural art (for comparing).
@export var procedural_only := false

@export_group("Deck")
@export var shadow: Texture2D
@export var hull_base: Texture2D
@export var deck_base: Texture2D
@export var coachroof: Texture2D
@export var deck_details: Texture2D
@export var rigging: Texture2D
@export var mast: Texture2D
@export_group("Sails")
@export var boom: Texture2D
@export var main_sail: Texture2D
@export var head_sail: Texture2D
@export var spinnaker: Texture2D
@export_group("Cabin")
@export var cabin_base: Texture2D
@export var furniture: Texture2D
@export var cabin_details: Texture2D


## The sprite for `slot`, or null to keep the procedural art.
func get_texture(slot: StringName) -> Texture2D:
	if procedural_only or not SLOT_FILES.has(slot):
		return null
	var assigned: Texture2D = get(SLOT_FILES[slot][0])
	if assigned:
		return assigned
	var path := conventional_path(slot)
	if not path.is_empty() and ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null


## Where a drawn PNG for `slot` is picked up automatically.
func conventional_path(slot: StringName) -> String:
	if art_folder.is_empty() or not SLOT_FILES.has(slot):
		return ""
	var area := "cabin" if slot in CABIN_SLOTS else "deck"
	return art_folder.path_join(area).path_join(SLOT_FILES[slot][1])


## "profile", "file" or "procedural": where `slot`'s art comes from.
func get_source(slot: StringName) -> String:
	if procedural_only or not SLOT_FILES.has(slot):
		return "procedural"
	if get(SLOT_FILES[slot][0]):
		return "profile"
	var path := conventional_path(slot)
	return "file" if not path.is_empty() and ResourceLoader.exists(path) else "procedural"
