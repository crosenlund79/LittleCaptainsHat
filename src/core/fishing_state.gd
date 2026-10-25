class_name FishingState
extends RefCounted
## Fishing aboard (Iteration 13): the rod, the lures, the line, the fish in
## the cool box and the catch records with the five-catch trophy board.
##
## Plain data kept in SessionState and written only by GameSession. Every
## landed fish gets a unique serial number (next_uid), so a fish can be
## kept, released, sold or cooked exactly once. A bite in progress and the
## fight with the fish are not saved: a game loaded then simply has the line
## out again, waiting.

const MODE_STATIONARY := &"stationary"
const MODE_TROLLING := &"trolling"
const MODES: Array[StringName] = [MODE_STATIONARY, MODE_TROLLING]
## Fish kept aboard at most (a small cool box).
const HOLD_CAPACITY := 6
## With the large cool box fitted (Iteration 14 equipment).
const LARGE_HOLD_CAPACITY := 10
## The trophy board shows this many catches.
const TROPHY_COUNT := 5

## The basic rod (every captain has one).
var rod := true
## Lures owned, by lure id (FishingCatalog): count.
var lures := {"spinner": 2}
## The lure on the line (or the one that will be used).
var lure := "spinner"
## The line is out (fishing): since when, in which mode.
var line_out := false
var line_mode: StringName = MODE_STATIONARY
var line_since := 0.0
## Bite checks have been made up to this game time (Simulation only).
var checked_until := 0.0
## Fish in the cool box: [{"uid", "species", "kg", "caught_at", "where"}].
var hold: Array[Dictionary] = []
## The next fish's serial number.
var next_uid := 1
## Per species: {"count", "best_kg"}.
var records := {}
## The five most notable catches, best first (FishingCatalog.score()).
var trophies: Array[Dictionary] = []
var total_caught := 0
var released := 0
var sold := 0


func duplicate_state() -> FishingState:
	var copy := FishingState.new()
	copy.rod = rod
	copy.lures = lures.duplicate()
	copy.lure = lure
	copy.line_out = line_out
	copy.line_mode = line_mode
	copy.line_since = line_since
	copy.checked_until = checked_until
	for fish in hold:
		copy.hold.append(fish.duplicate(true))
	copy.next_uid = next_uid
	copy.records = records.duplicate(true)
	for fish in trophies:
		copy.trophies.append(fish.duplicate(true))
	copy.total_caught = total_caught
	copy.released = released
	copy.sold = sold
	return copy


func get_lure_count(lure_id: String) -> int:
	return int(lures.get(lure_id, 0))


func find_in_hold(uid: int) -> int:
	for i in hold.size():
		if int(hold[i].uid) == uid:
			return i
	return -1


func to_dict() -> Dictionary:
	return {
		"rod": rod, "lures": lures.duplicate(), "lure": lure,
		"line_out": line_out, "line_mode": String(line_mode), "line_since": line_since, "checked_until": checked_until,
		"hold": hold.duplicate(true), "next_uid": next_uid, "records": records.duplicate(true),
		"trophies": trophies.duplicate(true), "total_caught": total_caught, "released": released, "sold": sold,
	}


static func from_dict(data: Variant, errors: Array[String]) -> FishingState:
	if not data is Dictionary:
		errors.append("missing fishing record")
		return null
	var state := FishingState.new()
	if not data.get("rod") is bool or not data.get("line_out") is bool or not data.get("lures") is Dictionary \
			or not data.get("lure") is String or not data.get("hold") is Array or not data.get("records") is Dictionary \
			or not data.get("trophies") is Array or not StringName(str(data.get("line_mode"))) in MODES:
		errors.append("invalid fishing record")
		return null
	for key in ["line_since", "checked_until", "next_uid", "total_caught", "released", "sold"]:
		if not _is_number(data.get(key)):
			errors.append("invalid fishing record (%s)" % key)
			return null
	state.rod = data.rod
	state.lures = {}
	for id: Variant in data.lures:
		if not id is String or not _is_number(data.lures[id]) or int(data.lures[id]) < 0:
			errors.append("invalid lure count")
			return null
		state.lures[id] = int(data.lures[id])
	state.lure = data.lure
	state.line_out = data.line_out
	state.line_mode = StringName(data.line_mode)
	state.line_since = float(data.line_since)
	state.checked_until = float(data.checked_until)
	state.next_uid = maxi(int(data.next_uid), 1)
	var seen := {}
	for fish: Variant in data.hold:
		if not _is_fish(fish) or seen.has(int(fish.uid)) or int(fish.uid) >= state.next_uid:
			errors.append("invalid fish in the cool box")
			return null
		seen[int(fish.uid)] = true
		state.hold.append(_fish(fish))
	if state.hold.size() > LARGE_HOLD_CAPACITY:
		errors.append("too many fish in the cool box")
		return null
	for species: Variant in data.records:
		var record: Variant = data.records[species]
		if not species is String or not record is Dictionary or not _is_number(record.get("count")) or not _is_number(record.get("best_kg")):
			errors.append("invalid catch record")
			return null
		state.records[species] = {"count": maxi(int(record.count), 0), "best_kg": maxf(float(record.best_kg), 0.0)}
	for fish: Variant in data.trophies:
		if not _is_fish(fish) or not _is_number(fish.get("score")):
			errors.append("invalid trophy")
			return null
		var trophy := _fish(fish)
		trophy["score"] = float(fish.score)
		state.trophies.append(trophy)
	state.trophies = state.trophies.slice(0, TROPHY_COUNT)
	state.total_caught = maxi(int(data.total_caught), 0)
	state.released = maxi(int(data.released), 0)
	state.sold = maxi(int(data.sold), 0)
	return state


static func _is_fish(fish: Variant) -> bool:
	return fish is Dictionary and _is_number(fish.get("uid")) and fish.get("species") is String \
		and _is_number(fish.get("kg")) and float(fish.kg) > 0.0 and _is_number(fish.get("caught_at")) and fish.get("where") is String


static func _fish(fish: Dictionary) -> Dictionary:
	return {"uid": int(fish.uid), "species": String(fish.species), "kg": float(fish.kg), "caught_at": float(fish.caught_at),
		"where": String(fish.where)}


static func _is_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))
