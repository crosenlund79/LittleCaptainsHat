class_name HarbourFacilities
extends Resource
## Which services a harbour offers in the game (Iteration 12). Gameplay
## definitions, not claims about real businesses.
##
## A harbour without its own file gets the defaults (everything, which is how
## every harbour worked before). To change one harbour, add
## `data/harbours/facilities/<port_id>.tres` with the facilities it lacks
## switched off; nothing else is needed.
##
## Iteration 14 adds haul-outs: a boatyard that can lift a boat out of the
## water (cleaning the bottom, fitting a hard coating). Without a file, a
## harbour can haul out when it is one of the catalogue's major harbours
## (importance 1); a file decides it explicitly. Harbours fall into three
## gameplay tiers from their services: small (no boatyard), larger (a
## boatyard) and major service harbours (haul-outs). Gameplay abstractions,
## not claims about real yards.

const DIRECTORY := "res://data/harbours/facilities"
## Facility ids are the shore stations' interaction ids.
const GROCERY := &"grocery"
const BOATYARD := &"boatyard"
const GO_ASHORE := &"go_ashore"
## Shore stations, in shore order (haul-outs are a service of the boatyard).
const ALL: Array[StringName] = [GROCERY, BOATYARD, GO_ASHORE]
const HAUL_OUT := &"haul_out"

const TIER_SMALL := &"small"
const TIER_LARGER := &"larger"
const TIER_MAJOR := &"major"
const TIER_NAMES := {TIER_SMALL: "Small harbour", TIER_LARGER: "Larger harbour", TIER_MAJOR: "Major service harbour"}

## The grocery store (food, water, a replacement hat).
@export var grocery := true
## The boatyard: changing boats and repairs.
@export var boatyard := true
## Go Ashore: small harbour events.
@export var go_ashore := true
## The boatyard can haul boats out (only with a boatyard). Ignored in the
## shared default; see for_port().
@export var haul_out := false

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
	if found:
		return found
	# No file: every service, and a haul-out yard in the major harbours.
	var port := PortCatalog.get_default().get_port(port_id)
	if port and port.importance == 1:
		if not _cache.has(&"@major"):
			var major := HarbourFacilities.new()
			major.haul_out = true
			_cache[&"@major"] = major
		return _cache[&"@major"]
	return get_default()


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
		HAUL_OUT:
			return boatyard and haul_out
	return false


## The harbour's gameplay tier (TIER_*), from its services.
func get_tier() -> StringName:
	if has(HAUL_OUT):
		return TIER_MAJOR
	return TIER_LARGER if boatyard else TIER_SMALL


## The available facilities, in shore order.
func get_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for id in ALL:
		if has(id):
			ids.append(id)
	return ids


## A player-facing name for refusals: "the boatyard".
static func describe(facility: StringName) -> String:
	return {GROCERY: Loc.t("grocery store"), BOATYARD: "boatyard", GO_ASHORE: Loc.t("place to go ashore"),
		HAUL_OUT: Loc.t("yard that can haul boats out")}.get(facility, String(facility))


## How each service is shown in a destination preview (Iteration 17), in
## order. Only services the game has (no fuel: boats are not refuelled in
## the game). New services (I020's chandlery, sailmaker, fishmonger) are
## added here and in has(), and appear in every preview.
const PREVIEW := [
	[GROCERY, "Groceries", "food and water"],
	[BOATYARD, "Boatyard", "repairs, care, other boats"],
	[HAUL_OUT, "Haul-out", "bottom cleaning, hard coating"],
	[GO_ASHORE, "Go ashore", ""],
]


## "Major service harbour: Groceries (food and water) · Boatyard (…) · …",
## from the harbour's own data (Iteration 17: chart and Dreamer's Map).
## `brief` leaves out the explanations in brackets (the chart's compact
## destination summary; the full text is in its tooltip).
static func describe_services(port_id: StringName, brief := false) -> String:
	var facilities := for_port(port_id)
	var parts := PackedStringArray()
	for entry: Array in PREVIEW:
		if facilities.has(entry[0]):
			parts.append(entry[1] if brief or String(entry[2]).is_empty() else "%s (%s)" % [entry[1], entry[2]])
	var services := "  ·  ".join(parts) if not parts.is_empty() else Loc.t("no services")
	return "%s: %s" % [Loc.t(TIER_NAMES[facilities.get_tier()]), services]
