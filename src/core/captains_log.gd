class_name CaptainsLog
extends RefCounted
## The Captain's Log: the player's sailing history. Statistics, the harbours
## visited and the most recent voyages.
##
## Plain data kept in SessionState. Only GameSession writes it, and only from
## the authoritative voyage events: a voyage ends either in
## GameSession.complete_voyage() (arrival) or in GameSession.rescue() (the
## boat was lost). The distance comes from the voyage itself (Voyage.sailed_nm,
## advanced by the simulation), so the log never calculates a voyage again.
## The number of rescues is SessionState.rescue_count (not repeated here).

## At most this many voyages are kept (the oldest are dropped). The totals,
## the longest passage and the visited harbours are kept for ever.
const MAX_VOYAGES := 50
const OUTCOME_ARRIVED := &"arrived"
const OUTCOME_RESCUED := &"rescued"
## "first" of a harbour visited before the log existed (an older save).
const UNKNOWN_TIME := -1.0
## Where every game started before the log existed (save migration).
const LEGACY_START_PORT := &"copenhagen"

## Distance sailed on voyages that have ended (arrived or rescued), nm. The
## voyage under way is added by GameSession.get_total_nm_sailed().
var total_nm := 0.0
## Voyages that reached their destination.
var voyages_completed := 0
## Arrivals in a harbour at the end of a voyage (the start harbour of a new
## game and a rescue tow are not arrivals). Equal to voyages_completed in this
## version: every completed voyage ends with exactly one arrival.
var arrivals := 0
## The longest completed passage (a voyage record), or {}.
var longest := {}
## Harbours visited, by port id (String): {"first": game time (or
## UNKNOWN_TIME), "arrivals": int}. The start harbour of a new game is listed
## with 0 arrivals.
var visited := {}
## The most recent voyages, oldest first (see make_record()).
var voyages: Array[Dictionary] = []


static func create(start_port: StringName, time: float) -> CaptainsLog:
	var log := CaptainsLog.new()
	log.visited[String(start_port)] = {"first": time, "arrivals": 0}
	return log


func duplicate_log() -> CaptainsLog:
	var copy := CaptainsLog.new()
	copy.total_nm = total_nm
	copy.voyages_completed = voyages_completed
	copy.arrivals = arrivals
	copy.longest = longest.duplicate(true)
	copy.visited = visited.duplicate(true)
	for record in voyages:
		copy.voyages.append(record.duplicate(true))
	return copy


func get_distinct_harbours() -> int:
	return visited.size()


func has_visited(port_id: StringName) -> bool:
	return visited.has(String(port_id))


func get_longest_nm() -> float:
	return float(longest.get("nm", 0.0))


## Visited port ids, in the order they were first visited (unknown first).
func get_visited_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for id: String in visited:
		ids.append(StringName(id))
	ids.sort_custom(func(a: StringName, b: StringName) -> bool:
		var ta := float(visited[String(a)].first)
		var tb := float(visited[String(b)].first)
		return ta < tb or (ta == tb and String(a) < String(b)))
	return ids


## A voyage record for the log, from the voyage that just ended.
static func make_record(voyage: Voyage, ended_at: float, vessel_id: StringName, outcome: StringName) -> Dictionary:
	return {
		"from": String(voyage.departure_port_id),
		"from_position": {"lon": voyage.departure_position.x, "lat": voyage.departure_position.y},
		"to": String(voyage.route.destination_port_id),
		"departed": voyage.departed_at,
		"ended": ended_at,
		"nm": voyage.sailed_nm,
		"vessel": String(vessel_id),
		"outcome": String(outcome),
		"worst_hazard": voyage.worst_hazard,
		"damage": voyage.damage_percent,
		"complete": voyage.fully_recorded,
	}


## Records a voyage that ended (GameSession only). On arrival the harbour is
## visited; returns true if it was visited for the first time.
func record_voyage(record: Dictionary) -> bool:
	total_nm += float(record.nm)
	voyages.append(record.duplicate(true))
	while voyages.size() > MAX_VOYAGES:
		voyages.remove_at(0)
	if record.outcome != String(OUTCOME_ARRIVED):
		return false
	voyages_completed += 1
	arrivals += 1
	if float(record.nm) > get_longest_nm():
		longest = record.duplicate(true)
	var id := String(record.to)
	var first := not visited.has(id)
	if first:
		visited[id] = {"first": float(record.ended), "arrivals": 0}
	visited[id].arrivals = int(visited[id].arrivals) + 1
	return first


func to_dict() -> Dictionary:
	return {
		"total_nm": total_nm,
		"voyages_completed": voyages_completed,
		"arrivals": arrivals,
		"longest": longest.duplicate(true),
		"visited": visited.duplicate(true),
		"voyages": voyages.duplicate(true),
	}


## Validates saved log data. Returns null (with reasons in `errors`) if it is
## not usable.
static func from_dict(data: Variant, errors: Array[String]) -> CaptainsLog:
	if not data is Dictionary:
		errors.append("missing Captain's Log")
		return null
	var log := CaptainsLog.new()
	for key in ["total_nm", "voyages_completed", "arrivals"]:
		if not _is_number(data.get(key)) or float(data.get(key)) < 0.0:
			errors.append("invalid Captain's Log statistics")
			return null
	log.total_nm = float(data.total_nm)
	log.voyages_completed = int(data.voyages_completed)
	log.arrivals = int(data.arrivals)
	var longest: Variant = data.get("longest", {})
	var visited: Variant = data.get("visited")
	var voyages: Variant = data.get("voyages")
	if not longest is Dictionary or not visited is Dictionary or not voyages is Array:
		errors.append("invalid Captain's Log records")
		return null
	if not longest.is_empty() and not _is_record(longest):
		errors.append("invalid longest passage")
		return null
	log.longest = _normalized(longest) if not longest.is_empty() else {}
	for id: Variant in visited:
		var entry: Variant = visited[id]
		if not id is String or not entry is Dictionary or not _is_number(entry.get("first")) \
				or not _is_number(entry.get("arrivals")) or int(entry.arrivals) < 0:
			errors.append("invalid visited harbour")
			return null
		log.visited[id] = {"first": float(entry.first), "arrivals": int(entry.arrivals)}
	for record: Variant in voyages:
		if not _is_record(record):
			errors.append("invalid voyage record")
			return null
		log.voyages.append(_normalized(record))
	while log.voyages.size() > MAX_VOYAGES:
		log.voyages.remove_at(0)
	return log


## A loaded record with the types and key order make_record() gives (JSON
## turns whole numbers into floats).
static func _normalized(record: Dictionary) -> Dictionary:
	var position: Variant = record.get("from_position")
	return {
		"from": String(record.from),
		"from_position": {"lon": float(position.get("lon", 0.0)), "lat": float(position.get("lat", 0.0))} if position is Dictionary else {"lon": 0.0, "lat": 0.0},
		"to": String(record.to),
		"departed": float(record.departed),
		"ended": float(record.ended),
		"nm": float(record.nm),
		"vessel": String(record.vessel),
		"outcome": String(record.outcome),
		"worst_hazard": int(record.get("worst_hazard", 0)),
		"damage": float(record.get("damage", 0.0)),
		"complete": bool(record.get("complete", false)),
	}


static func _is_record(record: Variant) -> bool:
	if not record is Dictionary:
		return false
	for key in ["from", "to", "vessel", "outcome"]:
		if not record.get(key) is String:
			return false
	for key in ["departed", "ended", "nm"]:
		if not _is_number(record.get(key)):
			return false
	return true


static func _is_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))
