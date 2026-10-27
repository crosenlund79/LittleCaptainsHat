class_name WeatherModel
extends RefCounted
## The game's weather: the one authoritative answer to "what is the weather
## here, now?" for the simulation, propulsion, warnings, chart, HUD and sound.
##
##   sample(geo, time, seed)   -> WeatherSample (sustained wind, gusts, hazard,
##                                classification, responsible event, ...)
##   sample_wind(geo, time, seed) -> Vector2(from_deg, speed_kn) only (the chart)
##   active_events(time, seed) -> the weather events existing at that time
##
## Layers:
## 1. Background wind: WindField (the Iteration 003 climatology with slow
##    deterministic weather waves), unchanged.
## 2. Weather events (WeatherEvent), formed from data/weather/weather_events.json:
##    - strong-wind / gale areas in the European sea areas, more in winter
##      (Iteration 16: and in the open oceans' westerlies, by hemisphere);
##    - areas of thunderstorm risk (more in summer), inside which thunderstorm
##      cells form, live a few hours (developing, active, dissipating) and
##      bring outflow winds and episodes of squalls;
##    - tropical cyclones in their basins and seasons (none can reach the
##      European chart: they weaken and end before leaving the tropics).
##
## Determinism: an area's events are decided per time slot from a hash of
## (seed, kind, area, slot). An event, once formed, evolves as a pure function
## of game time (WeatherEvent). So sampling is a pure function of
## (position, time, seed): reading never changes the weather, opening the
## chart cannot alter a storm, and one big simulation step sees exactly what
## many small steps see. Only the slots that can still have a living event are
## looked at (a bounded look-back), never the whole history. A save therefore
## needs only the seed (and the model version) to continue the same weather.
##
## Units: knots, nautical miles, game seconds (UTC), degrees; wind directions
## are where the wind blows FROM (WindField convention).

const DEFAULT_PATH := "res://data/weather/weather_events.json"

const HAZARD_NORMAL := 0
const HAZARD_CAUTION := 1
const HAZARD_DANGEROUS := 2
const HAZARD_SEVERE := 3
## Sustained wind (knots) at which each hazard level starts (Beaufort 6, 8, 10).
const SUSTAINED_LIMITS := [22.0, 34.0, 48.0]
## Gusts (knots) at which each hazard level starts.
const GUST_LIMITS := [30.0, 41.0, 56.0]
## A thunderstorm is severe (squalls, dangerous at its core) when its outflow
## and gusts together reach this many knots.
const SEVERE_STORM_KN := 40.0
## Gusts relative to the sustained wind outside thunderstorms.
const GUST_FACTOR := 1.25
const GALE_GUST_FACTOR := 1.35

const CLASS_CALM := &"calm"
const CLASS_FAIR := &"fair"
const CLASS_STRONG_WIND := &"strong_wind"
const CLASS_GALE := &"gale"
const CLASS_STORM := &"storm"
const CLASS_THUNDER_RISK := &"thunderstorm_risk"
const CLASS_THUNDERSTORM := &"thunderstorm"
const CLASS_SQUALL := &"squall"
const CLASS_TROPICAL_STORM := &"tropical_storm"
const CLASS_HURRICANE := &"hurricane"

## Slot lengths: how often each kind of area may form a new event.
const GALE_SLOT := 12.0 * 3600.0
const RISK_SLOT := 12.0 * 3600.0
const CYCLONE_SLOT := 24.0 * 3600.0
## Events are collected per 15 minutes of game time (cache granularity).
const BUCKET := 900.0
const MAX_CACHE := 4096

static var _default: WeatherModel

## Extra events always present (tests and development demonstrations).
var fixture_events: Array[WeatherEvent] = []
## Generated events on/off. Also off while WindField.test_override is set
## (tests that force one wind everywhere stay exactly as before).
var generated_enabled := true

var model_version := 1
## Point queries answered so far (sample() and sample_wind()); for profiling.
var sample_count := 0
var _gale_zones: Array = []
var _convective_zones: Array = []
var _convective := {}
var _basins: Array = []
var _cyclone := {}
var _names: Array = []
var _slot_cache := {}
var _bucket_cache := {}
## Per bucket, for each of its events: where it can reach during the bucket,
## as PackedFloat32Array(centre lon, centre lat, half width, half height) in
## degrees (Iteration 16: lets a sample skip the oceans' far-away weather).
var _bucket_reach := {}
var _cell_cache := {}


static func get_default() -> WeatherModel:
	if _default == null:
		_default = WeatherModel.load_from(DEFAULT_PATH)
	return _default


static func clear_default() -> void:
	_default = null


static func load_from(path: String) -> WeatherModel:
	var model := WeatherModel.new()
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary:
		push_error("Weather event data missing: %s" % path)
		return model
	model.model_version = int(data.get("model_version", 1))
	model._gale_zones = data.get("gale_zones", [])
	model._convective_zones = data.get("convective_zones", [])
	model._convective = data.get("convective", {})
	model._basins = data.get("cyclone_basins", [])
	model._cyclone = data.get("cyclone", {})
	model._names = data.get("cyclone_names", ["Unnamed"])
	return model


# --- Names --------------------------------------------------------------------------

static func hazard_name(level: int) -> String:
	return ["Normal", "Caution", "Dangerous", "Severe"][clampi(level, 0, 3)]


static func class_label(classification: StringName) -> String:
	match classification:
		CLASS_CALM:
			return "Calm"
		CLASS_STRONG_WIND:
			return "Strong winds"
		CLASS_GALE:
			return "Gale"
		CLASS_STORM:
			return "Storm"
		CLASS_THUNDER_RISK:
			return "Thunderstorm risk"
		CLASS_THUNDERSTORM:
			return "Thunderstorm"
		CLASS_SQUALL:
			return "Severe squalls"
		CLASS_TROPICAL_STORM:
			return "Tropical storm"
		CLASS_HURRICANE:
			return "Hurricane"
	return "Fair"


## The hazard level for a sustained wind and gust (knots).
static func wind_hazard(sustained_kn: float, gust_kn: float) -> int:
	var level := HAZARD_NORMAL
	for i in 3:
		if sustained_kn >= SUSTAINED_LIMITS[i] or gust_kn >= GUST_LIMITS[i]:
			level = i + 1
	return level


# --- Sampling -----------------------------------------------------------------------

## The weather at `geo` at `time`. With `known_at` only events that have
## already formed by then are included (a forecast made at `known_at`: storms
## that form later cannot be foreseen).
func sample(geo: Vector2, time: float, seed := 1, known_at := INF) -> WeatherSample:
	sample_count += 1
	geo = GeoMath.normalize(geo)  # paths continuous across the Date Line may pass |lon| > 180
	var background := WindField.get_default().sample(geo, time, seed)
	var result := WeatherSample.new()
	result.geo = geo
	result.time = time
	result.background_from_deg = background.from_deg
	result.background_kn = background.speed_kn
	var parts := _compose(geo, time, seed, known_at, background, result)
	var wind: Vector2 = parts[0]
	var dominant: WeatherEvent = parts[3]
	result.speed_kn = wind.length()
	result.from_deg = _from_deg(wind, background.from_deg)
	result.gust_kn = result.speed_kn * float(parts[1]) + float(parts[2])
	result.hazard = wind_hazard(result.speed_kn, result.gust_kn)
	if result.thunder_possible:
		result.hazard = maxi(result.hazard, HAZARD_CAUTION)
	if parts[4] and dominant and dominant.peak_kn + dominant.gust_kn >= SEVERE_STORM_KN:
		result.hazard = maxi(result.hazard, HAZARD_DANGEROUS)
	if dominant:
		result.event_id = dominant.id
		result.event_kind = dominant.kind
		result.event_name = dominant.display_name
	result.classification = _classify(result, dominant, time)
	var risk := cyclone_risk(geo, time)
	result.cyclone_risk = risk.risk
	result.cyclone_basin = risk.basin
	return result


## The wind, gusts and hazard at `geo` at `time`, exactly as sample() gives
## them (the same code), without building a WeatherSample: no
## classification, names or cyclone risk. [from_deg, speed_kn, gust_kn,
## hazard] in 64-bit floats (a Vector4 would round them to 32 bits, and the
## results would no longer be exactly sample()'s). For scans that only keep the few samples that matter
## (Turbocharge: the route-ahead hazard scan and the weather damage grid,
## the bulk of a night's sleep underway); they ask sample() for those.
func sample_hazard(geo: Vector2, time: float, seed := 1, known_at := INF) -> PackedFloat64Array:
	sample_count += 1
	geo = GeoMath.normalize(geo)
	var background := WindField.get_default().sample(geo, time, seed)
	_scratch.thunder_possible = false
	_scratch.thunder_active = false
	var parts := _compose(geo, time, seed, known_at, background, _scratch)
	var wind: Vector2 = parts[0]
	var dominant: WeatherEvent = parts[3]
	var speed := wind.length()
	var gust := speed * float(parts[1]) + float(parts[2])
	var hazard := wind_hazard(speed, gust)
	if _scratch.thunder_possible:
		hazard = maxi(hazard, HAZARD_CAUTION)
	if parts[4] and dominant and dominant.peak_kn + dominant.gust_kn >= SEVERE_STORM_KN:
		hazard = maxi(hazard, HAZARD_DANGEROUS)
	return PackedFloat64Array([_from_deg(wind, background.from_deg), speed, gust, hazard])


## Reused by sample_hazard() for the thunder flags _compose() sets.
var _scratch := WeatherSample.new()


## Only the sustained wind at `geo` at `time`: Vector2(from_deg, speed_kn).
## Exactly the speed and direction sample() gives (same code), without the
## gusts, hazard, classification and cyclone risk: the chart's wind overlay
## (Iteration 17) needs nothing else. A pure query, like sample().
func sample_wind(geo: Vector2, time: float, seed := 1, known_at := INF) -> Vector2:
	sample_count += 1
	geo = GeoMath.normalize(geo)
	var background := WindField.get_default().sample(geo, time, seed)
	var wind: Vector2 = _compose(geo, time, seed, known_at, background, null)[0]
	return Vector2(_from_deg(wind, background.from_deg), wind.length())


static func _from_deg(wind: Vector2, fallback_deg: float) -> float:
	var from := rad_to_deg(atan2(-wind.x, -wind.y)) if wind.length() > 1e-4 else fallback_deg
	return fposmod(from, 360.0)


## The background wind changed by the events that reach `geo`:
## [wind vector, gust factor, extra gust kn, dominant event or null, at a cell core].
## Sets the thunder flags on `result` when one is given.
func _compose(geo: Vector2, time: float, seed: int, known_at: float, background: WindField.Sample,
		result: WeatherSample) -> Array:
	var wind := _vector(background.from_deg, background.speed_kn)
	var gust_factor := GUST_FACTOR
	var gust_extra := 0.0
	var dominant: WeatherEvent = null
	var dominant_score := 0.0
	var cell_core := false
	for event in _events_near(geo, time, seed, known_at):
		var weight := 0.0
		match event.kind:
			WeatherEvent.KIND_GALE:
				var d := event.normalized_distance(geo, time)
				if d >= 1.0:
					continue
				weight = (1.0 - smoothstep(0.3, 1.0, d)) * event.life_factor(time)
				var speed := wind.length()
				var target := lerpf(speed, maxf(speed, event.peak_kn), weight)
				var direction := _blend_direction(wind, _vector(event.flow_from_deg, 1.0), weight * 0.6)
				wind = direction * target
				gust_factor = lerpf(gust_factor, GALE_GUST_FACTOR, weight)
				weight *= event.peak_kn
			WeatherEvent.KIND_THUNDER_RISK:
				var d := event.normalized_distance(geo, time)
				if d >= 1.0 or event.life_factor(time) < 0.2:
					continue
				if result:
					result.thunder_possible = true
				weight = 1.0  # noted, but any real wind event dominates it
			WeatherEvent.KIND_THUNDERSTORM:
				var d := event.normalized_distance(geo, time)
				if d >= 1.0:
					continue
				var strength := event.life_factor(time)
				weight = (1.0 - smoothstep(0.25, 1.0, d)) * strength
				# Outflow: wind blowing out of the storm (from its centre).
				# At the very centre (no "away") the outflow follows the storm's track.
				var away := event.offset_nm(geo, time)
				var track := deg_to_rad(event.heading_at(time))
				var outflow := away.normalized() if away.length() > 0.01 else Vector2(sin(track), cos(track))
				var speed := wind.length() + event.peak_kn * weight
				wind = _blend_direction(wind, outflow, weight * 0.8) * speed
				gust_extra = maxf(gust_extra, event.gust_kn * weight * event.gust_envelope(time))
				if result:
					result.thunder_possible = true
					if d < 0.8 and strength > 0.3:
						result.thunder_active = true
				if d < 0.5 and strength > 0.5:
					cell_core = true
				weight *= 8.0 + event.peak_kn + event.gust_kn
			WeatherEvent.KIND_CYCLONE:
				var cyclone := event.cyclone_wind(geo, time)
				var speed: float = cyclone[0]
				if speed <= 0.5:
					continue
				var mix := speed / (speed + wind.length() + 0.001)
				var direction := _blend_direction(wind, _vector(cyclone[1], 1.0), mix)
				wind = direction * maxf(speed, wind.length())
				gust_factor = maxf(gust_factor, 1.3)
				weight = speed * 2.0
		if weight > dominant_score:
			dominant_score = weight
			dominant = event
	return [wind, gust_factor, gust_extra, dominant, cell_core]


func _classify(sample: WeatherSample, dominant: WeatherEvent, time: float) -> StringName:
	if dominant and dominant.kind == WeatherEvent.KIND_CYCLONE and sample.speed_kn >= 34.0:
		return CLASS_HURRICANE if sample.speed_kn >= 64.0 else CLASS_TROPICAL_STORM
	if sample.thunder_active or (dominant and dominant.kind == WeatherEvent.KIND_THUNDERSTORM):
		var severe := dominant != null and dominant.kind == WeatherEvent.KIND_THUNDERSTORM \
			and dominant.peak_kn + dominant.gust_kn >= SEVERE_STORM_KN
		return CLASS_SQUALL if sample.hazard >= HAZARD_DANGEROUS or severe else CLASS_THUNDERSTORM
	if sample.speed_kn >= SUSTAINED_LIMITS[2]:
		return CLASS_STORM
	if sample.speed_kn >= SUSTAINED_LIMITS[1]:
		return CLASS_GALE
	if sample.speed_kn >= SUSTAINED_LIMITS[0] or sample.gust_kn >= GUST_LIMITS[0]:
		return CLASS_STRONG_WIND
	if sample.thunder_possible:
		return CLASS_THUNDER_RISK
	return CLASS_CALM if sample.speed_kn < 1.0 else CLASS_FAIR


## Air movement vector (where it blows TO) for a FROM direction and speed.
static func _vector(from_deg: float, speed: float) -> Vector2:
	var from := deg_to_rad(from_deg)
	return Vector2(-sin(from), -cos(from)) * speed


## Direction (unit vector) between two wind directions; `weight` 0 = a, 1 = b.
static func _blend_direction(a: Vector2, b: Vector2, weight: float) -> Vector2:
	if a.length() < 1e-6:
		return b.normalized()
	var mixed := a.normalized() * (1.0 - weight) + b.normalized() * weight
	if mixed.length() < 1e-4:
		return b.normalized() if weight >= 0.5 else a.normalized()
	return mixed.normalized()


## What an event brings at its core at `time` on top of `background_kn`:
## [sustained_kn, gust_kn] (an estimate for warnings and the chart; sampling
## remains the authority).
static func event_strength(event: WeatherEvent, time: float, background_kn := 0.0) -> Array:
	var life := event.life_factor(time)
	match event.kind:
		WeatherEvent.KIND_GALE:
			var gale := maxf(background_kn, event.peak_kn * life)
			return [gale, gale * GALE_GUST_FACTOR]
		WeatherEvent.KIND_THUNDERSTORM:
			var outflow := background_kn + event.peak_kn * life
			return [outflow, outflow * GUST_FACTOR + event.gust_kn * life]
		WeatherEvent.KIND_CYCLONE:
			var vmax := event.peak_kn * life
			return [vmax, vmax * 1.3]
	return [background_kn, background_kn * GUST_FACTOR]


# --- Events -------------------------------------------------------------------------

## Every event existing at `time` (forming, mature or dissipating), sorted by
## start time then id. With `known_at`, only those formed by then.
func active_events(time: float, seed := 1, known_at := INF) -> Array[WeatherEvent]:
	var result: Array[WeatherEvent] = []
	for event in _bucket_events(time, seed):
		if event.is_active_at(time) and event.start_time <= known_at:
			result.append(event)
	for event in fixture_events:
		if event.is_active_at(time) and event.start_time <= known_at:
			result.append(event)
	return result


## Events of a kind at `time`.
func events_of_kind(time: float, kind: StringName, seed := 1) -> Array[WeatherEvent]:
	return active_events(time, seed).filter(func(e: WeatherEvent) -> bool: return e.kind == kind)


## The event with this id if it exists at `time` (generated or fixture).
func find_event(id: StringName, time: float, seed := 1) -> WeatherEvent:
	for event in active_events(time, seed):
		if event.id == id:
			return event
	return null


func is_generating() -> bool:
	return generated_enabled and not WindField.get_default().test_override.is_valid()


## Forgets cached events (after changing fixtures or switches; never needed
## for correctness in play, events are pure functions of the seed).
func clear_cache() -> void:
	_slot_cache.clear()
	_bucket_cache.clear()
	_bucket_reach.clear()
	_cell_cache.clear()


func _bucket_events(time: float, seed: int) -> Array[WeatherEvent]:
	var empty: Array[WeatherEvent] = []
	if not is_generating():
		return empty
	var bucket := floori(time / BUCKET)
	var key := "%d|%d" % [seed, bucket]
	if _bucket_cache.has(key):
		return _bucket_cache[key]
	if _bucket_cache.size() > MAX_CACHE:
		_bucket_cache.clear()
		_bucket_reach.clear()
	var t0 := bucket * BUCKET
	var t1 := t0 + BUCKET
	var events: Array[WeatherEvent] = []
	for i in _gale_zones.size():
		var zone: Dictionary = _gale_zones[i]
		var longest := float(zone.life_h[1]) * 3600.0
		for slot in range(floori((t0 - longest) / GALE_SLOT), floori(t1 / GALE_SLOT) + 1):
			var event := _slot_event("gale", i, slot, seed)
			if event and event.start_time < t1 and event.end_time() > t0:
				events.append(event)
	var risk_longest := float(_convective.get("life_h", [10, 24])[1]) * 3600.0
	for i in _convective_zones.size():
		for slot in range(floori((t0 - risk_longest) / RISK_SLOT), floori(t1 / RISK_SLOT) + 1):
			var risk := _slot_event("risk", i, slot, seed)
			if risk == null or risk.start_time >= t1 or risk.end_time() + 6.0 * 3600.0 <= t0:
				continue
			if risk.end_time() > t0:
				events.append(risk)
			for cell in _cells_of(risk):
				if cell.start_time < t1 and cell.end_time() > t0:
					events.append(cell)
	var cyclone_longest := float(_cyclone.get("life_h", [96, 264])[1]) * 3600.0
	for i in _basins.size():
		for slot in range(floori((t0 - cyclone_longest) / CYCLONE_SLOT), floori(t1 / CYCLONE_SLOT) + 1):
			var event := _slot_event("cyclone", i, slot, seed)
			if event and event.start_time < t1 and event.end_time() > t0:
				events.append(event)
	events.sort_custom(func(a: WeatherEvent, b: WeatherEvent) -> bool:
		return a.start_time < b.start_time or (a.start_time == b.start_time and String(a.id) < String(b.id)))
	_bucket_cache[key] = events
	_bucket_reach[key] = _reach_boxes(events, t0, t1)
	return events


## Conservative boxes around where each event can affect the wind during
## [t0, t1]: its centre's movement plus its reach (WeatherEvent.reach_nm).
static func _reach_boxes(events: Array[WeatherEvent], t0: float, t1: float) -> PackedFloat32Array:
	var boxes := PackedFloat32Array()
	boxes.resize(events.size() * 4)
	for i in events.size():
		var event := events[i]
		var a := event.center_at(t0)
		var b := event.center_at(t1)
		var dx := GeoMath.wrap_delta(a.x, b.x)
		var reach := event.reach_nm() / 60.0 + 0.1
		var half_y := absf(b.y - a.y) / 2.0 + reach
		var center_y := (a.y + b.y) / 2.0
		var lat := minf(absf(center_y) + half_y, 89.0)
		boxes[i * 4] = GeoMath.normalize_lon(a.x + dx / 2.0)
		boxes[i * 4 + 1] = center_y
		boxes[i * 4 + 2] = absf(dx) / 2.0 + reach / maxf(cos(deg_to_rad(lat)), 0.05)
		boxes[i * 4 + 3] = half_y
	return boxes


## The active events at `time` that can reach `geo` (for sample()).
func _events_near(geo: Vector2, time: float, seed: int, known_at: float) -> Array[WeatherEvent]:
	var result: Array[WeatherEvent] = []
	var events := _bucket_events(time, seed)
	var boxes: PackedFloat32Array = _bucket_reach.get("%d|%d" % [seed, floori(time / BUCKET)], PackedFloat32Array())
	for i in events.size():
		var event := events[i]
		if boxes.size() == events.size() * 4 and (absf(geo.y - boxes[i * 4 + 1]) > boxes[i * 4 + 3]
				or absf(GeoMath.wrap_delta(boxes[i * 4], geo.x)) > boxes[i * 4 + 2]):
			continue
		if event.is_active_at(time) and event.start_time <= known_at:
			result.append(event)
	for event in fixture_events:
		if event.is_active_at(time) and event.start_time <= known_at:
			result.append(event)
	return result


## The event (or null) an area forms in one slot. Cached; a pure function of
## (kind, area, slot, seed).
func _slot_event(kind: String, zone_index: int, slot: int, seed: int) -> WeatherEvent:
	var key := "%s|%d|%d|%d" % [kind, zone_index, slot, seed]
	if _slot_cache.has(key):
		return _slot_cache[key]
	if _slot_cache.size() > MAX_CACHE:
		_slot_cache.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d|%s|%d|%d" % [seed, kind, zone_index, slot])
	var event: WeatherEvent = null
	match kind:
		"gale":
			event = _make_gale(_gale_zones[zone_index], zone_index, slot, rng)
		"risk":
			event = _make_risk(_convective_zones[zone_index], zone_index, slot, rng)
		"cyclone":
			event = _make_cyclone(_basins[zone_index], zone_index, slot, rng)
	if event:
		event.seed = hash("%d|%s" % [seed, event.id])
	_slot_cache[key] = event
	return event


static func _month_factor(zone: Dictionary, time: float) -> float:
	var month: int = Time.get_datetime_dict_from_unix_time(int(time)).month
	var season: Array = zone.get("season", [])
	return float(season[month - 1]) if season.size() == 12 else 1.0


static func _range(rng: RandomNumberGenerator, values: Array) -> float:
	return rng.randf_range(float(values[0]), float(values[1]))


static func _point_in(rng: RandomNumberGenerator, area: Array) -> Vector2:
	return Vector2(rng.randf_range(float(area[0]), float(area[1])), rng.randf_range(float(area[2]), float(area[3])))


static func _random_shape(rng: RandomNumberGenerator, amount: float) -> PackedFloat32Array:
	var shape := PackedFloat32Array()
	for k in 3:
		shape.append(rng.randf_range(0.3, 1.0) * amount / (k + 1))
		shape.append(rng.randf() * TAU)
	return shape


func _make_gale(zone: Dictionary, index: int, slot: int, rng: RandomNumberGenerator) -> WeatherEvent:
	var slot_start := slot * GALE_SLOT
	var chance := float(zone.per_day) * GALE_SLOT / 86400.0 * _month_factor(zone, slot_start)
	if rng.randf() >= chance:
		return null
	var event := WeatherEvent.new()
	event.kind = WeatherEvent.KIND_GALE
	event.id = StringName("gale-%d-%d" % [index, slot])
	event.start_time = slot_start + rng.randf() * GALE_SLOT
	event.lifetime = _range(rng, zone.life_h) * 3600.0
	event.origin = _point_in(rng, zone.area)
	event.heading_deg = _range(rng, zone.heading)
	event.speed_kn = _range(rng, zone.speed_kn)
	event.turn_deg_per_day = rng.randf_range(-15.0, 15.0)
	event.radius_nm = _range(rng, zone.radius_nm)
	event.peak_kn = _range(rng, zone.peak_kn)
	var flow: Array = zone.flow_from
	event.flow_from_deg = fposmod(rng.randf_range(float(flow[0]), float(flow[1]) + (360.0 if float(flow[1]) < float(flow[0]) else 0.0)), 360.0)
	event.shape = _random_shape(rng, 0.22)
	event.shape_drift = rng.randf_range(-0.04, 0.04)
	event.display_name = "Gale" if event.peak_kn >= SUSTAINED_LIMITS[1] else "Strong winds"
	return event


func _make_risk(zone: Dictionary, index: int, slot: int, rng: RandomNumberGenerator) -> WeatherEvent:
	var slot_start := slot * RISK_SLOT
	var chance := float(zone.per_day) * RISK_SLOT / 86400.0 * _month_factor(zone, slot_start)
	if rng.randf() >= chance:
		return null
	var c := _convective
	var event := WeatherEvent.new()
	event.kind = WeatherEvent.KIND_THUNDER_RISK
	event.id = StringName("risk-%d-%d" % [index, slot])
	event.start_time = slot_start + rng.randf() * RISK_SLOT
	event.lifetime = _range(rng, c.life_h) * 3600.0
	event.origin = _point_in(rng, zone.area)
	event.heading_deg = _range(rng, zone.get("heading", c.heading))
	event.speed_kn = _range(rng, c.speed_kn)
	event.radius_nm = _range(rng, c.radius_nm)
	event.shape = _random_shape(rng, 0.28)
	event.shape_drift = rng.randf_range(-0.05, 0.05)
	event.display_name = "Thunderstorm risk"
	return event


## The thunderstorm cells a risk area produces (all of them, cached).
func _cells_of(risk: WeatherEvent) -> Array[WeatherEvent]:
	var key := "%s|%d" % [risk.id, risk.seed]
	if _cell_cache.has(key):
		return _cell_cache[key]
	if _cell_cache.size() > MAX_CACHE:
		_cell_cache.clear()
	var c := _convective
	var every := float(c.get("cell_every_h", 1.0)) * 3600.0
	var cells: Array[WeatherEvent] = []
	var slots := ceili(risk.lifetime / every)
	for k in slots:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("%d|cell|%d" % [risk.seed, k])
		var born := risk.start_time + (k + rng.randf()) * every
		var strength := risk.life_factor(born)
		if rng.randf() >= float(c.cell_chance) * strength:
			continue
		var cell := WeatherEvent.new()
		cell.kind = WeatherEvent.KIND_THUNDERSTORM
		cell.id = StringName("%s-cell-%d" % [risk.id, k])
		cell.parent_id = risk.id
		cell.start_time = born
		cell.lifetime = _range(rng, c.cell_life_h) * 3600.0
		# Somewhere inside the risk area as it is when the cell forms.
		var bearing := rng.randf() * TAU
		var distance := sqrt(rng.randf()) * 0.75 * risk.outline_radius(bearing, born)
		var center := risk.center_at(born)
		cell.origin = center + Vector2(sin(bearing) * distance / (60.0 * maxf(cos(deg_to_rad(center.y)), 0.05)), cos(bearing) * distance / 60.0)
		cell.heading_deg = risk.heading_deg + rng.randf_range(-25.0, 25.0)
		cell.speed_kn = risk.speed_kn * rng.randf_range(0.8, 1.3)
		cell.radius_nm = _range(rng, c.cell_radius_nm)
		# Most storms are moderate; a few are severe.
		var severity := pow(rng.randf(), float(c.get("cell_severity_skew", 1.6)))
		cell.peak_kn = lerpf(float(c.cell_peak_kn[0]), float(c.cell_peak_kn[1]), severity)
		cell.gust_kn = lerpf(float(c.cell_gust_kn[0]), float(c.cell_gust_kn[1]), severity)
		cell.shape = _random_shape(rng, 0.3)
		cell.shape_drift = rng.randf_range(-0.2, 0.2)
		cell.seed = hash("%d|%s" % [risk.seed, cell.id])
		cell.display_name = "Severe thunderstorm" if cell.peak_kn + cell.gust_kn >= SEVERE_STORM_KN else "Thunderstorm"
		cells.append(cell)
	_cell_cache[key] = cells
	return cells


func _make_cyclone(basin: Dictionary, index: int, slot: int, rng: RandomNumberGenerator) -> WeatherEvent:
	var slot_start := slot * CYCLONE_SLOT
	var chance := float(basin.per_day) * _month_factor(basin, slot_start)
	if rng.randf() >= chance:
		return null
	var event := WeatherEvent.new()
	event.kind = WeatherEvent.KIND_CYCLONE
	event.id = StringName("cyclone-%d-%d" % [index, slot])
	event.hemisphere = int(basin.get("hemisphere", 1))
	event.start_time = slot_start + rng.randf() * CYCLONE_SLOT
	event.lifetime = _range(rng, _cyclone.life_h) * 3600.0
	event.origin = _point_in(rng, basin.genesis)
	event.heading_deg = _range(rng, basin.heading)
	event.speed_kn = _range(rng, basin.speed_kn)
	event.turn_deg_per_day = _range(rng, basin.turn_deg_per_day)
	event.radius_nm = _range(rng, _cyclone.radius_nm)
	event.eye_radius_nm = _range(rng, _cyclone.eye_radius_nm)
	event.peak_kn = _range(rng, _cyclone.peak_kn)
	event.shape = _random_shape(rng, 0.08)
	event.display_name = String(_names[absi(hash("%s|%d" % [basin.name, slot])) % _names.size()])
	_limit_cyclone(event, basin.get("limit", {}))
	return event


## Tropical cyclones weaken and end once they leave the tropics (or cross a
## basin's limit): the lifetime is cut so it ends within half a day of the
## crossing. Keeps every cyclone away from the European chart.
static func _limit_cyclone(event: WeatherEvent, limit: Dictionary) -> void:
	var max_abs_lat := float(limit.get("max_abs_lat", 40.0))
	var east_of := float(limit.get("east_of", 999.0))
	var hours := 0.0
	while hours * 3600.0 < event.lifetime:
		var p := event.center_at(event.start_time + hours * 3600.0)
		if absf(p.y) > max_abs_lat or (east_of < 999.0 and p.x > east_of):
			event.lifetime = minf(event.lifetime, hours * 3600.0 + 12.0 * 3600.0)
			return
		hours += 3.0


# --- Seasonal tropical-cyclone risk -------------------------------------------------

## How likely tropical cyclones are at `geo` in the season of `time`:
## {"risk": 0..1, "basin": name or ""}. Risk, not an actual storm.
func cyclone_risk(geo: Vector2, time: float) -> Dictionary:
	var best := {"risk": 0.0, "basin": ""}
	for basin: Dictionary in _basins:
		var area: Array = basin.risk_area
		if geo.x < float(area[0]) or geo.x > float(area[1]) or geo.y < float(area[2]) or geo.y > float(area[3]):
			continue
		# Fades out over the last 3 degrees towards the area's edges.
		var edge := minf(minf(geo.x - float(area[0]), float(area[1]) - geo.x), minf(geo.y - float(area[2]), float(area[3]) - geo.y))
		var risk := clampf(_month_factor(basin, time) / 1.8, 0.0, 1.0) * smoothstep(0.0, 3.0, edge)
		if risk > best.risk:
			best = {"risk": risk, "basin": String(basin.name)}
	return best


## Basin names (for tests and documentation).
func get_basin_names() -> PackedStringArray:
	var names := PackedStringArray()
	for basin: Dictionary in _basins:
		names.append(String(basin.name))
	return names
