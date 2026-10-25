class_name HarbourFacilities
extends Resource
## Which services a harbour offers in the game (Iteration 12). Gameplay
## definitions, not claims about real businesses.
##
## A harbour without its own file gets the defaults (everything, which is how
## every harbour worked before). To change one harbour, add
## `data/harbours/facilities/<port_id>.tres` with the facilities it lacks
## switched off; nothing else is needed.

const DIRECTORY := "res://data/harbours/facilities"
## Facility ids are the shore stations' interaction ids.
const GROCERY := &"grocery"
const BOATYARD := &"boatyard"
const GO_ASHORE := &"go_ashore"
const ALL: Array[StringName] = [GROCERY, BOATYARD, GO_ASHORE]

## The grocery store (food, water, a replacement hat).
@export var grocery := true
## The boatyard: changing boats and repairs.
@export var boatyard := true
## Go Ashore: small harbour events.
@export var go_ashore := true

static var _cache := {}
static var _default: HarbourFacilities


## The facilities of `port_id` (the defaults when it has no file).
static func for_port(port_id: StringName) -> HarbourFacilities:
	if port_id == &"":
		return get_default()
	if not _cache.has(port_id):
		var path := "%s/%s.tres" % [DIRECTORY, port_id]
		_cache[port_id] = load(path) as HarbourFacilities if ResourceLoader.exists(path) else null
	var found: HarbourFacilities = _cache[port_id]
	return found if found else get_default()


static func get_default() -> HarbourFacilities:
	if _default == null:
		_default = HarbourFacilities.new()
	return _default


static func clear_cache() -> void:
	_cache.clear()


func has(facility: StringName) -> bool:
	match facility:
		GROCERY:
			return grocery
		BOATYARD:
			return boatyard
		GO_ASHORE:
			return go_ashore
	return false


## The available facilities, in shore order.
func get_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for id in ALL:
		if has(id):
			ids.append(id)
	return ids


## A player-facing name for refusals: "the boatyard".
static func describe(facility: StringName) -> String:
	return {GROCERY: "grocery store", BOATYARD: "boatyard", GO_ASHORE: "place to go ashore"}.get(facility, String(facility))
