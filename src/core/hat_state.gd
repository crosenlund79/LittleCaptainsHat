class_name HatState
extends RefCounted
## The player's captain's hat (Visual Identity V01). Plain data kept in
## SessionState and saved as the "hat" section; only GameSession writes it.
##
## There is exactly one hat at a time and it belongs to the player, not to a
## boat: switching boats, rescue and loading never copy, reset or restore it.
## Stored means on its hook in the cabin (every cabin has one), worn means on
## the player's head, carried means taken off and tucked under the arm (safe
## from the wind), lost means blown away until a replacement is bought.
##
## Wind strain is checked on an absolute game-time grid (Simulation), so the
## result is the same at any time acceleration, in one long step and across
## save/load: strain, the warning and the last checked time are saved.

const STORED := &"stored"
const WORN := &"worn"
const CARRIED := &"carried"
const LOST := &"lost"
const STATUSES: Array[StringName] = [STORED, WORN, CARRIED, LOST]

## Memorable hat moments kept for the Captain's Log (oldest are dropped).
const MAX_HISTORY := 30
const EVENT_LOST := &"lost"
const EVENT_BOUGHT := &"bought"

var status: StringName = STORED
## Wind strain on the worn hat (see HatConfig); it blows away at its threshold.
var strain := 0.0
## The player was warned about the wind in the current exposure (reset once
## the strain has fully recovered), so the warning is never repeated.
var warned := false
## When that warning was given (game time).
var warned_at := 0.0
## Hat checks have been made up to this game time (absolute grid).
var checked_until := 0.0
## Which hat this is: 1 is the hat the game started with; each replacement
## bought adds one.
var serial := 1
var lost_count := 0
var bought_count := 0
## Euros spent on replacement hats in all.
var spent := 0
## Game time the current hat was bought, or -1 for the original hat.
var bought_at := -1.0
## On the voyage under way: the worst weather hazard met while the hat was
## worn on deck, and whether a hat was lost (for the hat achievements).
var voyage_worn_hazard := 0
var voyage_lost := false
## Memorable moments, oldest first: {"time", "kind", "text"}.
var history: Array[Dictionary] = []


static func create(time: float) -> HatState:
	var hat := HatState.new()
	hat.checked_until = time
	return hat


func duplicate_hat() -> HatState:
	var copy := HatState.new()
	copy.status = status
	copy.strain = strain
	copy.warned = warned
	copy.warned_at = warned_at
	copy.checked_until = checked_until
	copy.serial = serial
	copy.lost_count = lost_count
	copy.bought_count = bought_count
	copy.spent = spent
	copy.bought_at = bought_at
	copy.voyage_worn_hazard = voyage_worn_hazard
	copy.voyage_lost = voyage_lost
	for entry in history:
		copy.history.append(entry.duplicate())
	return copy


## The player has a hat (stored, worn or carried).
func is_owned() -> bool:
	return status != LOST


## The hat the game started with has never been lost.
func has_original() -> bool:
	return lost_count == 0


func add_history(time: float, kind: StringName, text: String) -> void:
	history.append({"time": time, "kind": String(kind), "text": text})
	while history.size() > MAX_HISTORY:
		history.remove_at(0)


func to_dict() -> Dictionary:
	return {
		"status": String(status),
		"strain": strain,
		"warned": warned,
		"warned_at": warned_at,
		"checked_until": checked_until,
		"serial": serial,
		"lost_count": lost_count,
		"bought_count": bought_count,
		"spent": spent,
		"bought_at": bought_at,
		"voyage_worn_hazard": voyage_worn_hazard,
		"voyage_lost": voyage_lost,
		"history": history.duplicate(true),
	}


static func from_dict(data: Variant, errors: Array[String]) -> HatState:
	if not data is Dictionary:
		errors.append("missing captain's hat")
		return null
	var hat := HatState.new()
	if not data.get("status") is String or StringName(data.status) not in STATUSES:
		errors.append("invalid captain's hat state")
		return null
	hat.status = StringName(data.status)
	for key in ["strain", "warned_at", "checked_until", "serial", "lost_count", "bought_count", "spent", "bought_at", "voyage_worn_hazard"]:
		if not _is_number(data.get(key)):
			errors.append("invalid captain's hat record (%s)" % key)
			return null
	if not data.get("warned") is bool or not data.get("voyage_lost") is bool or not data.get("history", []) is Array:
		errors.append("invalid captain's hat record")
		return null
	hat.strain = maxf(float(data.strain), 0.0)
	hat.warned = data.warned
	hat.warned_at = float(data.warned_at)
	hat.checked_until = float(data.checked_until)
	hat.serial = maxi(int(data.serial), 1)
	hat.lost_count = maxi(int(data.lost_count), 0)
	hat.bought_count = maxi(int(data.bought_count), 0)
	hat.spent = maxi(int(data.spent), 0)
	hat.bought_at = float(data.bought_at)
	hat.voyage_worn_hazard = clampi(int(data.voyage_worn_hazard), 0, WeatherModel.HAZARD_SEVERE)
	hat.voyage_lost = data.voyage_lost
	if hat.status == LOST and hat.lost_count == 0:
		errors.append("a lost captain's hat must have been lost at least once")
		return null
	for entry: Variant in data.get("history", []):
		if not entry is Dictionary or not _is_number(entry.get("time")) or not entry.get("kind") is String \
				or not entry.get("text") is String:
			errors.append("invalid captain's hat history")
			return null
		hat.history.append({"time": float(entry.time), "kind": String(entry.kind), "text": String(entry.text)})
	while hat.history.size() > MAX_HISTORY:
		hat.history.remove_at(0)
	return hat


static func _is_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))
