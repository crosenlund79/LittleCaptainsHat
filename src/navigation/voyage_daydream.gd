class_name VoyageDaydream
extends RefCounted
## The Captain's voyage daydreams (Iteration 17): from the cabin's world map,
## "Imagine this voyage" plans a real route with the one worldwide router,
## picks up to three real harbours along it and turns them into a few lines
## of thought. Read-only: it never changes the course, the boat, the clock,
## the money or the stores (the router, the harbour catalogue and Passage
## Readiness are only asked, never changed). Results are cached per
## destination, boat position and boat.
##
## The words come from a small set of authored templates; the tone (curious,
## hopeful, cautious, excited, thoughtful) is chosen from the destination so
## the same harbour always reads the same. Harbours along the way are only
## real catalogue harbours near the route; there may be fewer than three, or
## none, and then the text says so instead of inventing any.

const TONES := ["curious", "hopeful", "cautious", "excited", "thoughtful"]
const OPENINGS := {
	"curious": "%s. I wonder what it's like there. About %s nautical miles by sea.",
	"hopeful": "%s... quite a distance from here, about %s nautical miles.",
	"cautious": "%s. That's a long way: about %s nautical miles of sea.",
	"excited": "%s! About %s nautical miles. Imagine sailing in there.",
	"thoughtful": "%s... about %s nautical miles. Plenty of time to think on the way.",
}
const NEAR_OPENINGS := {
	"curious": "%s. Only about %s nautical miles. I wonder what it's like.",
	"hopeful": "%s, about %s nautical miles away. Not far at all.",
	"cautious": "%s, about %s nautical miles. An easy hop, if the weather is kind.",
	"excited": "%s! Just %s nautical miles from here.",
	"thoughtful": "%s, about %s nautical miles. A gentle sail.",
}
const CLOSINGS := {
	"curious": "Perhaps one day...",
	"hopeful": "One day, maybe.",
	"cautious": "Not today. But one day.",
	"excited": "Now there's a thought!",
	"thoughtful": "Someday.",
}
## A harbour counts as "along the way" within this distance of the route (nm).
const NEAR_ROUTE_NM := 60.0
const NEAR_ROUTE_SHORT_NM := 20.0
## Routes shorter than this get at most one stop (nm).
const SHORT_ROUTE_NM := 150.0
## The route is looked at every this many nautical miles.
const SAMPLE_NM := 25.0

static var _cache := {}


## The daydream about sailing to `destination_id` from where the boat is:
## {"ok", "text", "nm", "stops": Array[StringName], "hours", "path"}.
static func imagine(destination_id: StringName) -> Dictionary:
	var catalog := PortCatalog.get_default()
	var destination := catalog.get_port(destination_id)
	if destination == null:
		return {"ok": false, "text": "", "nm": 0.0, "stops": [] as Array[StringName], "hours": 0.0, "path": PackedVector2Array()}
	var here := GameSession.get_vessel_position()
	var origin_port: StringName = GameSession.get_location_id() if not GameSession.is_underway() else &""
	var key := "%s|%.2f|%.2f|%s|%s" % [destination_id, here.x, here.y, origin_port, GameSession.get_vessel_id()]
	if _cache.has(key):
		return _cache[key]
	var tone: String = TONES[posmod(hash(String(destination_id)), TONES.size())]
	var result := {"ok": true, "text": "", "nm": 0.0, "stops": [] as Array[StringName], "hours": 0.0,
		"path": PackedVector2Array(), "tone": tone}
	if destination_id == origin_port:
		result.text = Loc.t("%s. I'm already here, and it's lovely.") % destination.display_name
		return _remember(key, result)
	var planned := SeaRouter.get_default().plan_route(origin_port, here, [] as Array[Vector2], destination_id)
	if not planned.is_ok():
		result.ok = false
		result.text = Loc.t("%s... I can't see a way there by sea from here.") % destination.display_name
		return _remember(key, result)
	var path: PackedVector2Array = planned.route.path
	var nm := GeoMath.path_length_nm(path)
	var stops := stops_along(path, [origin_port, destination_id], nm)
	var readiness := PassageReadiness.assess(path)
	result.nm = nm
	result.path = path
	result.stops = stops
	result.hours = float(readiness.hours)
	result.text = compose(destination, nm, stops, readiness, tone)
	return _remember(key, result)


static func _remember(key: String, result: Dictionary) -> Dictionary:
	if _cache.size() > 64:
		_cache.clear()
	_cache[key] = result
	return result


static func clear_cache() -> void:
	_cache.clear()


## Up to three real harbours near the route, in sailing order, spread along
## it: one from each third of the passage (the most important there), and at
## most one on a short route. Never the start or the destination.
static func stops_along(path: PackedVector2Array, exclude: Array, nm: float) -> Array[StringName]:
	var stops: Array[StringName] = []
	if path.size() < 2 or nm <= 0.0:
		return stops
	var samples := _resample(path, SAMPLE_NM)
	var limit := NEAR_ROUTE_SHORT_NM if nm < SHORT_ROUTE_NM else NEAR_ROUTE_NM
	var sections := 1 if nm < SHORT_ROUTE_NM else 3
	var best: Array = []
	best.resize(sections)
	for port in PortCatalog.get_default().ports:
		if port.id in exclude:
			continue
		var geo := port.get_geo_position()
		var nearest := INF
		var along := 0.0
		for sample: Vector3 in samples:
			var d := GeoMath.distance_nm(geo, Vector2(sample.x, sample.y))
			if d < nearest:
				nearest = d
				along = sample.z
		var fraction := along / nm
		if nearest > limit or fraction < 0.08 or fraction > 0.92:
			continue
		var section := clampi(floori((fraction - 0.08) / 0.84 * sections), 0, sections - 1)
		var centre := (section + 0.5) / sections
		var score := port.importance * 10.0 - absf(fraction - 0.08 - centre * 0.84) * 5.0 - nearest / limit
		if best[section] == null or score > best[section][0]:
			best[section] = [score, port.id]
	for entry: Variant in best:
		if entry != null:
			stops.append(entry[1])
	return stops


## Points every `step` nm along `path`: Vector3(lon, lat, distance along).
static func _resample(path: PackedVector2Array, step: float) -> Array[Vector3]:
	var points: Array[Vector3] = []
	var cumulative := GeoMath.cumulative_distances(path)
	var total := cumulative[cumulative.size() - 1]
	var d := 0.0
	while d <= total:
		var p := GeoMath.point_along(path, cumulative, d)
		points.append(Vector3(p.x, p.y, d))
		d += step
	return points


static func _place(id: StringName) -> String:
	var port := PortCatalog.get_default().get_port(id)
	if port == null:
		return String(id)
	var home := PortCatalog.get_default().get_port(GameSession.get_location_id())
	var country := port.country
	if home and home.country == country:
		return port.display_name
	return Loc.t("%s in %s") % [port.display_name, country] if not country.is_empty() else port.display_name


## The few lines of thought (authored templates; see the class notes).
static func compose(destination: PortData, nm: float, stops: Array[StringName], readiness: Dictionary, tone: String) -> String:
	var distance := _round_nm(nm)
	var lines := PackedStringArray()
	lines.append((NEAR_OPENINGS if nm < SHORT_ROUTE_NM else OPENINGS)[tone] % [destination.display_name, distance])
	var names := PackedStringArray()
	for id in stops:
		names.append(_place(id))
	match names.size():
		0:
			lines.append(Loc.t("Mostly open water the whole way.") if nm >= SHORT_ROUTE_NM else Loc.t("A straightforward sail."))
		1:
			lines.append(Loc.t("I could stop at %s on the way.") % names[0])
		2:
			lines.append(Loc.t("I could make my way toward %s, then stop at %s.") % [names[0], names[1]])
		_:
			lines.append(Loc.t("I could make my way toward %s, stop at %s, and rest a while in %s before the last stretch.") % [names[0], names[1], names[2]])
	var hours := float(readiness.get("hours", 0.0))
	if hours > PassageReadiness.OCEAN_PASSAGE_HOURS:
		lines.append(Loc.t("Weeks at sea, by the look of it."))
	elif hours > PassageReadiness.LONG_PASSAGE_HOURS:
		lines.append(Loc.t("Several days at sea."))
	elif hours > PassageReadiness.OVERNIGHT_HOURS:
		lines.append(Loc.t("An overnight sail."))
	# A gentle word from Passage Readiness, only about things the game knows.
	for item: Dictionary in readiness.get("items", []):
		if int(item.level) != PassageReadiness.CONSIDER:
			continue
		if String(item.topic) in ["stores", "stores_capacity"]:
			lines.append(Loc.t("I'd want to stock up properly first."))
			break
		if String(item.topic) == "hull":
			lines.append(Loc.t("And the boat would want some care before a trip like that."))
			break
	lines.append(CLOSINGS[tone])
	return " ".join(lines)


static func _round_nm(nm: float) -> String:
	if nm < 100.0:
		return str(roundi(nm))
	if nm < 1000.0:
		return str(roundi(nm / 10.0) * 10)
	var rounded := roundi(nm / 100.0) * 100
	return "%d,%03d" % [rounded / 1000, rounded % 1000] if rounded >= 1000 else str(rounded)
