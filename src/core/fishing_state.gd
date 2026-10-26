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
##
## Iteration 18: only kept fish go on the trophy board (a released fish -
## by the keep preferences, a full cool box, by hand, or a shark - never
## does), and the captain's keep preferences and Long Passage fishing choice
## are kept here. They are optional in a save (format 12 unchanged): a save
## without them gets the defaults (keep everything; stop for every bite).

const MODE_STATIONARY := &"stationary"
const MODE_TROLLING := &"trolling"
const MODES: Array[StringName] = [MODE_STATIONARY, MODE_TROLLING]
## Fish kept aboard at most (a small cool box).
const HOLD_CAPACITY := 6
## With the large cool box fitted (Iteration 14 equipment).
const LARGE_HOLD_CAPACITY := 10
## The trophy board shows this many catches.
const TROPHY_COUNT := 5
## Long Passage fishing (Iteration 18): see passage_posture.
const PASSAGE_ALL := &"all"
const PASSAGE_KEEPERS := &"keepers"
const PASSAGE_POSTURES: Array[StringName] = [PASSAGE_ALL, PASSAGE_KEEPERS]

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
## Keep preferences (Iteration 18): a landed fish is kept only if its rarity is
## at least keep_min_rarity (FishingCatalog.RARITY_ORDER) and its specimen
## grade at least keep_min_grade (FishingCatalog.GRADES); else it goes back.
var keep_min_rarity := "common"
var keep_min_grade: StringName = &""
## During fast time (Long Passage or 20x): stop for every bite (PASSAGE_ALL),
## or only for fish of a rarity worth keeping (PASSAGE_KEEPERS; the others
## nibble and swim off without interrupting).
var passage_posture: StringName = PASSAGE_ALL
var sharks_released := 0
var junk_caught := 0


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
	copy.keep_min_rarity = keep_min_rarity
	copy.keep_min_grade = keep_min_grade
	copy.passage_posture = passage_posture
	copy.sharks_released = sharks_released
	copy.junk_caught = junk_caught
	return copy


func get_lure_count(lure_id: String) -> int:
	return int(lures.get(lure_id, 0))


## Whether a landed fish of this rarity and grade is one to keep.
func wants(rarity: String, grade: StringName) -> bool:
	return FishingCatalog.rarity_index(rarity) >= FishingCatalog.rarity_index(keep_min_rarity) \
		and FishingCatalog.grade_rank(grade) >= FishingCatalog.grade_rank(keep_min_grade)


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
		"keep_min_rarity": keep_min_rarity, "keep_min_grade": String(keep_min_grade), "passage_posture": String(passage_posture),
		"sharks_released": sharks_released, "junk_caught": junk_caught,
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
	# Iteration 18 fields: optional, defaults when absent or unknown.
	var rarity := str(data.get("keep_min_rarity", "common"))
	state.keep_min_rarity = rarity if rarity in FishingCatalog.RARITY_ORDER else "common"
	var grade := StringName(str(data.get("keep_min_grade", "")))
	state.keep_min_grade = grade if grade in FishingCatalog.GRADES else FishingCatalog.GRADE_NONE
	var posture := StringName(str(data.get("passage_posture", PASSAGE_ALL)))
	state.passage_posture = posture if posture in PASSAGE_POSTURES else PASSAGE_ALL
	state.sharks_released = maxi(int(data.get("sharks_released", 0)) if _is_number(data.get("sharks_released", 0)) else 0, 0)
	state.junk_caught = maxi(int(data.get("junk_caught", 0)) if _is_number(data.get("junk_caught", 0)) else 0, 0)
	return state


static func _is_fish(fish: Variant) -> bool:
	return fish is Dictionary and _is_number(fish.get("uid")) and fish.get("species") is String \
		and _is_number(fish.get("kg")) and float(fish.kg) > 0.0 and _is_number(fish.get("caught_at")) and fish.get("where") is String


static func _fish(fish: Dictionary) -> Dictionary:
	var entry := {"uid": int(fish.uid), "species": String(fish.species), "kg": float(fish.kg), "caught_at": float(fish.caught_at),
		"where": String(fish.where)}
	# Iteration 18 (optional): the species' best before this fish was kept, so
	# releasing it gives the record back (a released fish is no record).
	if _is_number(fish.get("prev_best_kg")):
		entry["prev_best_kg"] = maxf(float(fish.prev_best_kg), 0.0)
	return entry


static func _is_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))
