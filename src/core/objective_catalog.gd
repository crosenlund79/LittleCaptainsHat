class_name ObjectiveCatalog
extends RefCounted
## The sailing objectives and the renown balancing, from
## data/progression/objectives.json: handcrafted objectives plus a few
## generated from the harbour catalogue (distant harbours worth a visit).
##
## Objectives are evaluated only by GameSession, when a voyage has been
## written to the Captain's Log (see evaluate()). Nothing here changes state.

const DEFAULT_PATH := "res://data/progression/objectives.json"

const TYPE_VOYAGE_COUNT := &"voyage_count"
const TYPE_TOTAL_DISTANCE := &"total_distance"
const TYPE_VISIT_HARBOUR := &"visit_harbour"
const TYPE_VISIT_COUNT := &"visit_count"
const TYPE_PASSAGE_LENGTH := &"passage_length"
const TYPE_CLEAN_PASSAGE := &"clean_passage"
const TYPE_WEATHER_ARRIVAL := &"weather_arrival"
const TYPE_NEW_HARBOUR := &"new_harbour"
const TYPES: Array[StringName] = [TYPE_VOYAGE_COUNT, TYPE_TOTAL_DISTANCE, TYPE_VISIT_HARBOUR, TYPE_VISIT_COUNT,
	TYPE_PASSAGE_LENGTH, TYPE_CLEAN_PASSAGE, TYPE_WEATHER_ARRIVAL, TYPE_NEW_HARBOUR]

static var _default: ObjectiveCatalog

## Euros paid per renown point by a travel update (social media).
var euros_per_renown := 2
## Objectives in display order: {"id", "title", "text", "type", "target",
## "port", "hazard", "reward", "repeatable", "category", "generated"}.
var objectives: Array[Dictionary] = []
var _by_id := {}


static func get_default() -> ObjectiveCatalog:
	if _default == null:
		_default = load_from(DEFAULT_PATH, PortCatalog.get_default())
	return _default


static func clear_default() -> void:
	_default = null


## Reads the data file and builds the objectives. Invalid entries are left
## out with an error (so a typo never breaks a game).
static func load_from(path: String, ports: PortCatalog) -> ObjectiveCatalog:
	var catalog := ObjectiveCatalog.new()
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary:
		push_error("Cannot read objectives from %s" % path)
		return catalog
	var publishing: Variant = data.get("publishing", {})
	if publishing is Dictionary and (publishing.get("euros_per_renown") is float or publishing.get("euros_per_renown") is int):
		catalog.euros_per_renown = maxi(int(publishing.euros_per_renown), 0)
	for entry: Variant in data.get("objectives", []):
		catalog._add(entry, false, ports)
	var generated: Variant = data.get("generated")
	if generated is Dictionary:
		for entry in _generate_far_harbours(generated, ports):
			catalog._add(entry, true, ports)
	return catalog


func get_objective(id: StringName) -> Dictionary:
	return _by_id.get(String(id), {})


func has_objective(id: StringName) -> bool:
	return _by_id.has(String(id))


## Problems with an objective definition ("" when it is valid).
static func validate(entry: Dictionary, ports: PortCatalog) -> String:
	if not entry.get("id") is String or String(entry.id).is_empty():
		return "missing id"
	if StringName(entry.get("type", "")) not in TYPES:
		return "unknown type '%s'" % entry.get("type")
	if not (entry.get("reward") is int or entry.get("reward") is float) or int(entry.reward) <= 0:
		return "reward must be a positive number"
	match StringName(entry.type):
		TYPE_VISIT_HARBOUR:
			if not ports.has_port(StringName(str(entry.get("port", "")))):
				return "unknown harbour '%s'" % entry.get("port")
		TYPE_WEATHER_ARRIVAL:
			var hazard := int(entry.get("hazard", 0))
			if hazard < WeatherModel.HAZARD_CAUTION or hazard > WeatherModel.HAZARD_SEVERE:
				return "hazard must be 1-3"
		TYPE_NEW_HARBOUR:
			pass
		_:
			if not (entry.get("target") is int or entry.get("target") is float) or float(entry.target) <= 0.0:
				return "target must be a positive number"
	return ""


func _add(entry: Variant, generated: bool, ports: PortCatalog) -> void:
	if not entry is Dictionary:
		push_error("Objective entry is not an object")
		return
	var problem := validate(entry, ports)
	if problem.is_empty() and _by_id.has(String(entry.id)):
		problem = "duplicate id"
	if not problem.is_empty():
		push_error("Objective '%s' left out: %s" % [entry.get("id", "?"), problem])
		return
	var objective := {
		"id": String(entry.id),
		"title": str(entry.get("title", entry.id)),
		"text": str(entry.get("text", "")),
		"type": StringName(entry.type),
		"target": float(entry.get("target", 1.0)),
		"port": StringName(str(entry.get("port", ""))),
		"hazard": int(entry.get("hazard", 0)),
		"reward": int(entry.reward),
		"repeatable": bool(entry.get("repeatable", false)),
		"category": str(entry.get("category", "")),
		"generated": generated,
	}
	objectives.append(objective)
	_by_id[objective.id] = objective


## "Visit <distant harbour>" objectives: harbours at least min_nm (great
## circle) from the start harbour, `count` of them evenly spread over the
## distance order, rewarded by distance. Deterministic for a catalogue.
static func _generate_far_harbours(settings: Dictionary, ports: PortCatalog) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var start := ports.get_port(StringName(str(settings.get("start_port", ""))))
	var count := int(settings.get("count", 0))
	if start == null or count <= 0:
		return result
	var min_nm := float(settings.get("min_nm", 0.0))
	var far: Array[Dictionary] = []
	for port in ports.ports:
		var nm := GeoMath.distance_nm(start.get_geo_position(), port.get_geo_position())
		if nm >= min_nm:
			far.append({"port": port, "nm": nm})
	if far.is_empty():
		return result
	far.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.nm < b.nm)
	var longest: float = far[far.size() - 1].nm
	var picked := {}
	for i in mini(count, far.size()):
		# Evenly spread from the nearest qualifying to the farthest.
		var index := roundi(float(i) * (far.size() - 1) / maxf(count - 1, 1)) if count > 1 else far.size() - 1
		picked[index] = true
	for index: int in picked.keys():
		var port: PortData = far[index].port
		var share := inverse_lerp(min_nm, maxf(longest, min_nm + 1.0), far[index].nm)
		var reward := roundi(lerpf(float(settings.get("min_reward", 30)), float(settings.get("max_reward", 50)), clampf(share, 0.0, 1.0)))
		result.append({"id": "visit_%s" % port.id, "title": "Far horizons: %s" % port.display_name, "type": String(TYPE_VISIT_HARBOUR),
			"port": String(port.id), "reward": reward, "category": "exploration",
			"text": "Sail to %s, %s (%d nm from %s as the gull flies) and moor there." % [port.display_name, port.country,
				roundi(far[index].nm), start.display_name]})
	return result


# --- Evaluation ---------------------------------------------------------------------

## The objectives a just-logged voyage completes: [{"id", "reward"}]. `log`
## already contains the voyage (`record`), `new_harbour` tells whether it
## was a first visit, `progress` is the ObjectiveProgress before this event.
## One-time objectives already completed and repeatable ones already paid for
## this voyage (see ObjectiveProgress.can_pay()) are not returned.
func evaluate(log: CaptainsLog, record: Dictionary, new_harbour: bool, progress: ObjectiveProgress) -> Array[Dictionary]:
	var awards: Array[Dictionary] = []
	var event := float(record.ended)
	for objective in objectives:
		if not progress.can_pay(objective, event):
			continue
		if is_met(objective, log, record, new_harbour):
			awards.append({"id": objective.id, "reward": objective.reward, "title": objective.title})
	return awards


## Whether `objective` is met by the log after the voyage `record`.
static func is_met(objective: Dictionary, log: CaptainsLog, record: Dictionary, new_harbour: bool) -> bool:
	var arrived: bool = record.outcome == String(CaptainsLog.OUTCOME_ARRIVED)
	match objective.type:
		TYPE_VOYAGE_COUNT:
			return log.voyages_completed >= int(objective.target)
		TYPE_TOTAL_DISTANCE:
			return log.total_nm >= objective.target
		TYPE_VISIT_HARBOUR:
			return log.has_visited(objective.port) and int(log.visited[String(objective.port)].arrivals) > 0
		TYPE_VISIT_COUNT:
			return log.get_distinct_harbours() >= int(objective.target)
		TYPE_PASSAGE_LENGTH:
			return arrived and float(record.nm) >= objective.target
		TYPE_CLEAN_PASSAGE:
			return arrived and bool(record.complete) and float(record.damage) <= 0.0 and float(record.nm) >= objective.target
		TYPE_WEATHER_ARRIVAL:
			return arrived and bool(record.complete) and int(record.worst_hazard) >= objective.hazard
		TYPE_NEW_HARBOUR:
			return arrived and new_harbour
	return false


## Progress towards `objective` for the Objectives view: [current, target].
static func get_progress(objective: Dictionary, log: CaptainsLog, total_nm: float) -> Array[float]:
	match objective.type:
		TYPE_VOYAGE_COUNT:
			return [float(log.voyages_completed), objective.target]
		TYPE_TOTAL_DISTANCE:
			return [total_nm, objective.target]
		TYPE_VISIT_COUNT:
			return [float(log.get_distinct_harbours()), objective.target]
		TYPE_VISIT_HARBOUR:
			var done := log.has_visited(objective.port) and int(log.visited[String(objective.port)].arrivals) > 0
			return [1.0 if done else 0.0, 1.0]
		TYPE_PASSAGE_LENGTH, TYPE_CLEAN_PASSAGE:
			return [log.get_longest_nm() if objective.type == TYPE_PASSAGE_LENGTH else 0.0, objective.target]
	return [0.0, 1.0]
