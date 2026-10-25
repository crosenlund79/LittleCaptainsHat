class_name BoatCareState
extends RefCounted
## The care record of one boat (Iteration 14): how long since its bottom was
## last cleaned, how worn its rigging is, how many engine hours since the
## last service, which equipment is fitted, and a short service history.
##
## The boat's overall condition (hull and structure, weather damage) stays in
## SessionState.vessel_conditions, as before; this adds the slow, everyday
## wear on top of it (see BoatCare). Plain data in SessionState, written
## only by GameSession. Each boat keeps its own record.

## Game time of the last haul-out (bottom cleaned): fouling grows from here.
var hull_cleaned_at := 0.0
## Rigging and sail wear, 0 (fresh) to 100.
var rig_wear := 0.0
## Engine hours since the last service.
var engine_hours := 0.0
## Fitted equipment upgrade ids (BoatCare.UPGRADES), each at most once.
var upgrades: Array[String] = []
## The last services: [{"time", "kind", "port", "cost"}], newest last.
var history: Array[Dictionary] = []

const HISTORY_LIMIT := 12


static func create(now: float) -> BoatCareState:
	var care := BoatCareState.new()
	care.hull_cleaned_at = now
	return care


func duplicate_state() -> BoatCareState:
	var copy := BoatCareState.new()
	copy.hull_cleaned_at = hull_cleaned_at
	copy.rig_wear = rig_wear
	copy.engine_hours = engine_hours
	copy.upgrades = upgrades.duplicate()
	copy.history = history.duplicate(true)
	return copy


func has_upgrade(id: String) -> bool:
	return id in upgrades


func add_history(time: float, kind: String, port: String, cost: int) -> void:
	history.append({"time": time, "kind": kind, "port": port, "cost": cost})
	while history.size() > HISTORY_LIMIT:
		history.pop_front()


func to_dict() -> Dictionary:
	return {"hull_cleaned_at": hull_cleaned_at, "rig_wear": rig_wear, "engine_hours": engine_hours,
		"upgrades": upgrades.duplicate(), "history": history.duplicate(true)}


static func from_dict(data: Variant, errors: Array[String]) -> BoatCareState:
	if not data is Dictionary:
		errors.append("invalid boat care record")
		return null
	for key in ["hull_cleaned_at", "rig_wear", "engine_hours"]:
		var value: Variant = data.get(key)
		if not (value is int or value is float) or not is_finite(float(value)) or float(value) < 0.0 and key != "hull_cleaned_at":
			errors.append("invalid boat care record (%s)" % key)
			return null
	if not data.get("upgrades") is Array or not data.get("history") is Array:
		errors.append("invalid boat care record (lists)")
		return null
	var care := BoatCareState.new()
	care.hull_cleaned_at = float(data.hull_cleaned_at)
	care.rig_wear = clampf(float(data.rig_wear), 0.0, 100.0)
	care.engine_hours = float(data.engine_hours)
	for id: Variant in data.upgrades:
		if not id is String or BoatCare.get_upgrade(id).is_empty() or id in care.upgrades:
			errors.append("invalid or duplicated upgrade in the boat care record")
			return null
		care.upgrades.append(id)
	for entry: Variant in data.history:
		if entry is Dictionary:
			care.history.append(entry)
	while care.history.size() > HISTORY_LIMIT:
		care.history.pop_front()
	return care
