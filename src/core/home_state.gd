class_name HomeState
extends RefCounted
## A boat of your own (I020): the small things the Captain owns for the
## cabins, and how each boat is made a home.
##
##   owned_decor  ids of cabin things bought (HarbourTrades decor); they are
##                the Captain's and can go aboard any boat.
##   vessels      by vessel id (String): {"decor": [ids shown in its cabin],
##                "sails": cloth id, "cloths": [cloth ids cut for it]}.
##                Every boat keeps its own; changing boats never touches
##                another boat's choices.
##
## Stable ids only (no scene paths). Optional in saves: an older save, or a
## boat with no entry, has a plain cabin and the classic cream sails. Ids the
## catalogue no longer knows are dropped quietly on load (never a refused
## save).

var owned_decor: Array[String] = []
var vessels := {}


func duplicate_home() -> HomeState:
	var copy := HomeState.new()
	copy.owned_decor = owned_decor.duplicate()
	copy.vessels = vessels.duplicate(true)
	return copy


func owns_decor(id: String) -> bool:
	return id in owned_decor


func get_decor(vessel_id: StringName) -> Array[String]:
	var out: Array[String] = []
	for id: Variant in (vessels.get(String(vessel_id), {}) as Dictionary).get("decor", []):
		out.append(String(id))
	return out


func set_decor_shown(vessel_id: StringName, id: String, shown: bool) -> void:
	var record := _record(vessel_id)
	var decor: Array = record.get("decor", [])
	if shown and not id in decor:
		decor.append(id)
	elif not shown:
		decor.erase(id)
	record["decor"] = decor


func get_sails(vessel_id: StringName) -> String:
	return String((vessels.get(String(vessel_id), {}) as Dictionary).get("sails", HarbourTrades.CLASSIC_CLOTH))


func has_cloth(vessel_id: StringName, cloth: String) -> bool:
	return cloth == HarbourTrades.CLASSIC_CLOTH or cloth in (vessels.get(String(vessel_id), {}) as Dictionary).get("cloths", [])


func set_sails(vessel_id: StringName, cloth: String) -> void:
	var record := _record(vessel_id)
	record["sails"] = cloth
	var cloths: Array = record.get("cloths", [])
	if cloth != HarbourTrades.CLASSIC_CLOTH and not cloth in cloths:
		cloths.append(cloth)
	record["cloths"] = cloths


func _record(vessel_id: StringName) -> Dictionary:
	if not vessels.has(String(vessel_id)):
		vessels[String(vessel_id)] = {"decor": [], "sails": HarbourTrades.CLASSIC_CLOTH, "cloths": []}
	return vessels[String(vessel_id)]


func is_empty() -> bool:
	return owned_decor.is_empty() and vessels.is_empty()


func to_dict() -> Dictionary:
	return {"owned_decor": owned_decor.duplicate(), "vessels": vessels.duplicate(true)}


## Never fails: unknown or malformed parts are left out.
static func from_dict(data: Variant) -> HomeState:
	var home := HomeState.new()
	if not data is Dictionary:
		return home
	var owned: Variant = data.get("owned_decor", [])
	if owned is Array:
		for id: Variant in owned:
			if id is String and not HarbourTrades.get_decor_item(id).is_empty() and not id in home.owned_decor:
				home.owned_decor.append(id)
	var boats: Variant = data.get("vessels", {})
	if boats is Dictionary:
		for vessel_id: Variant in boats:
			var entry: Variant = boats[vessel_id]
			if not vessel_id is String or not entry is Dictionary:
				continue
			var record := {"decor": [], "sails": HarbourTrades.CLASSIC_CLOTH, "cloths": []}
			for id: Variant in entry.get("decor", []) if entry.get("decor") is Array else []:
				if id is String and id in home.owned_decor and not id in record.decor:
					record.decor.append(id)
			for cloth: Variant in entry.get("cloths", []) if entry.get("cloths") is Array else []:
				if cloth is String and not HarbourTrades.get_sail_cloth(cloth).is_empty() and not cloth in record.cloths:
					record.cloths.append(cloth)
			var sails: Variant = entry.get("sails")
			if sails is String and (sails == HarbourTrades.CLASSIC_CLOTH or sails in record.cloths):
				record.sails = sails
			home.vessels[vessel_id] = record
	return home
