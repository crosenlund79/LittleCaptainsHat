class_name WindField
extends RefCounted
## The game's wind: one central, deterministic query for any position and time.
##
## A synthetic climatology (data/weather/wind_climate.json) gives a typical
## wind at ~40 anchor places across Europe (westerlies in the north-west,
## Portuguese trades, Mistral, Meltemi, a changeable Baltic, …). A position's
## wind is the Gaussian-weighted blend of nearby anchors, so it changes
## smoothly in space: there are no region borders. (The blend is computed once
## on a 0.5° lattice and interpolated bilinearly: fast, still continuous.)
## Slow, deterministic
## "weather" is added on top: a few travelling waves veer/back the direction,
## strengthen/weaken the wind and occasionally sweep a light-air patch across a
## sea area. Everything is a pure function of (position, game time, seed), so
## the simulation, chart, HUD and sails always see the same wind, and saves
## stay consistent.
##
## Iteration 16: beyond the European anchors a synthetic global climatology
## takes over (latitude belts — trades, westerlies, doldrums, horse latitudes —
## plus a few regional anchors), on a coarser wrapping lattice; the European
## lattice blends into it near its edge. The weather waves are cross-faded
## near the Date Line so the wind is continuous all the way round.
##
## Convention (meteorological): `from_deg` is where the wind blows FROM,
## 0 = north, 90 = east, 180 = south, 270 = west. Arrows on the chart show
## where it blows TO (`to_deg()`).
##
## This is not real weather and not a forecast.

const DEFAULT_PATH := "res://data/weather/wind_climate.json"
const SECONDS_PER_DAY := 86400.0
const MIN_SPEED_FACTOR := 0.15
## Climatology lattice: covers the chart region with a margin.
const LATTICE_WEST := -27.0
const LATTICE_SOUTH := 31.0
const LATTICE_STEP := 0.5
const LATTICE_COLUMNS := 133  # -27 .. 39 °E
const LATTICE_ROWS := 85      # 31 .. 73 °N
## Global lattice (Iteration 16): the whole world, wrapping in longitude.
const GLOBAL_STEP := 2.5
const GLOBAL_SOUTH := -85.0
const GLOBAL_COLUMNS := 144  # -180 .. 177.5 °E, wrapping
const GLOBAL_ROWS := 69      # -85 .. 85 °N
## Longitudes over which the weather waves cross-fade towards the Date Line.
const DATELINE_FADE_DEG := 30.0

static var _default: WindField

## Tests may set this to a Callable(geo: Vector2, time: float) -> Sample to
## force known wind. Never set in normal play.
var test_override: Callable

var _anchors: Array[Dictionary] = []
var _influence := 4.0
var _direction_waves: Array = []
var _speed_waves: Array = []
var _lull := {}
## Per lattice point: direction vector x, y, mean speed, variability.
var _lattice := PackedFloat32Array()
var _global_lattice := PackedFloat32Array()
var _belts: Array[Dictionary] = []
var _global_anchors: Array[Dictionary] = []
var _global_influence := 8.0
var _belt_weight := 0.6
var _europe_blend := 4.0


## The wind at one place and time.
class Sample:
	## Where the wind comes FROM, degrees (0 = north, 90 = east).
	var from_deg := 0.0
	var speed_kn := 0.0

	static func make(from: float, speed: float) -> Sample:
		var sample := Sample.new()
		sample.from_deg = fposmod(from, 360.0)
		sample.speed_kn = maxf(speed, 0.0)
		return sample

	## Where the wind blows TO (the direction an arrow points).
	func to_deg() -> float:
		return WindField.from_to_to(from_deg)

	## Air movement as Vector2(east, north) in knots.
	func to_vector() -> Vector2:
		var to := deg_to_rad(to_deg())
		return Vector2(sin(to), cos(to)) * speed_kn


static func get_default() -> WindField:
	if _default == null:
		_default = WindField.load_from(DEFAULT_PATH)
	return _default


static func clear_default() -> void:
	if _default:
		_default.test_override = Callable()
	_default = null


static func load_from(path: String) -> WindField:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	var field := WindField.new()
	if not data is Dictionary:
		push_error("Wind climate data missing: %s" % path)
		return field
	field._influence = float(data.get("influence_deg", 4.0))
	for anchor: Dictionary in data.get("anchors", []):
		field._anchors.append(_anchor_from(anchor))
	for anchor: Dictionary in data.get("global_anchors", []):
		field._global_anchors.append(_anchor_from(anchor))
	for belt: Dictionary in data.get("global_belts", []):
		field._belts.append(_anchor_from(belt))
	field._belts.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.lat < b.lat)
	field._global_influence = float(data.get("global_influence_deg", 8.0))
	field._belt_weight = float(data.get("global_belt_weight", 0.6))
	field._europe_blend = float(data.get("europe_blend_deg", 4.0))
	field._direction_waves = data.get("direction_waves", [])
	field._speed_waves = data.get("speed_waves", [])
	field._lull = data.get("lull_wave", {})
	return field


static func _anchor_from(anchor: Dictionary) -> Dictionary:
	var from_rad := deg_to_rad(float(anchor.from))
	return {
		"lon": float(anchor.get("lon", 0.0)), "lat": float(anchor.lat),
		"dir": Vector2(sin(from_rad), cos(from_rad)),
		"kn": float(anchor.kn), "var": float(anchor.get("var", 0.4)),
	}


## Converts a FROM direction to the TO direction (and back).
static func from_to_to(degrees: float) -> float:
	return fposmod(degrees + 180.0, 360.0)


## Signed angle from the vessel's heading to the wind's FROM direction, in
## (-180, 180]: 0 = wind from dead ahead, ±180 = from astern, positive = from
## starboard (the right side), negative = from port.
static func relative_angle(heading_deg: float, wind_from_deg: float) -> float:
	var angle := fposmod(wind_from_deg - heading_deg + 180.0, 360.0) - 180.0
	return 180.0 if is_equal_approx(angle, -180.0) else angle


## 16-point compass name for a direction ("WSW"; Danish "VSV").
static func compass_name(degrees: float) -> String:
	const NAMES := ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE", "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"]
	return Loc.t(NAMES[roundi(fposmod(degrees, 360.0) / 22.5) % 16], "compass")


## The wind at `geo` (Vector2(lon, lat)) at `game_time` (UTC seconds).
func sample(geo: Vector2, game_time: float, seed := 1) -> Sample:
	if test_override.is_valid():
		return test_override.call(geo, game_time)
	geo = GeoMath.normalize(geo)
	var base := climatology(geo)
	var direction := Vector2(base[0], base[1])
	var speed: float = base[2]
	var variability: float = base[3]
	var from := rad_to_deg(atan2(direction.x, direction.y))

	# Slow deterministic weather on top of the climatology.
	var days := game_time / SECONDS_PER_DAY
	var strength := variability / 0.45
	var veer := 0.0
	for i in _direction_waves.size():
		var wave: Dictionary = _direction_waves[i]
		veer += float(wave.amplitude_deg) * _wave(wave, geo, days, seed, i)
	var factor := 0.0
	for i in _speed_waves.size():
		var wave: Dictionary = _speed_waves[i]
		factor += float(wave.amplitude) * _wave(wave, geo, days, seed, i + 7)
	factor = maxf(1.0 + strength * factor, MIN_SPEED_FACTOR)
	if not _lull.is_empty():
		var lull := _wave(_lull, geo, days, seed, 13)
		factor *= 1.0 - float(_lull.depth) * smoothstep(float(_lull.threshold), 1.0, lull)
	return Sample.make(from + strength * veer, speed * factor)


## Typical (undisturbed) wind at `geo`: [dir_x, dir_y, speed_kn, variability],
## bilinearly interpolated from the precomputed lattices: the European one
## inside its box (unchanged), the global one further out, blended over
## `europe_blend_deg` just outside the box.
func climatology(geo: Vector2) -> Array:
	geo = GeoMath.normalize(geo)
	var inside := minf(minf(geo.x - LATTICE_WEST, LATTICE_WEST + (LATTICE_COLUMNS - 1) * LATTICE_STEP - geo.x),
		minf(geo.y - LATTICE_SOUTH, LATTICE_SOUTH + (LATTICE_ROWS - 1) * LATTICE_STEP - geo.y))
	var europe_weight := 1.0 if _global_anchors.is_empty() and _belts.is_empty() else smoothstep(-_europe_blend, 0.0, inside)
	if europe_weight >= 1.0:
		return _europe_climatology(geo)
	var world := _global_climatology(geo)
	if europe_weight <= 0.0:
		return world
	var europe := _europe_climatology(geo)
	for k in 4:
		world[k] = lerpf(world[k], europe[k], europe_weight)
	return world


func _europe_climatology(geo: Vector2) -> Array:
	if _lattice.is_empty():
		_build_lattice()
	var fx := clampf((geo.x - LATTICE_WEST) / LATTICE_STEP, 0.0, LATTICE_COLUMNS - 1.001)
	var fy := clampf((geo.y - LATTICE_SOUTH) / LATTICE_STEP, 0.0, LATTICE_ROWS - 1.001)
	var x0 := floori(fx)
	var y0 := floori(fy)
	var tx := fx - x0
	var ty := fy - y0
	var i00 := (y0 * LATTICE_COLUMNS + x0) * 4
	var i10 := i00 + 4
	var i01 := i00 + LATTICE_COLUMNS * 4
	var i11 := i01 + 4
	var result := [0.0, 0.0, 0.0, 0.0]
	for k in 4:
		result[k] = lerpf(lerpf(_lattice[i00 + k], _lattice[i10 + k], tx), lerpf(_lattice[i01 + k], _lattice[i11 + k], tx), ty)
	return result


## The global lattice, bilinear, wrapping in longitude (built on first use).
func _global_climatology(geo: Vector2) -> Array:
	if _global_lattice.is_empty():
		_build_global_lattice()
	var fx := fposmod((geo.x + 180.0) / GLOBAL_STEP, float(GLOBAL_COLUMNS))
	var fy := clampf((geo.y - GLOBAL_SOUTH) / GLOBAL_STEP, 0.0, GLOBAL_ROWS - 1.001)
	var x0 := floori(fx) % GLOBAL_COLUMNS
	var x1 := (x0 + 1) % GLOBAL_COLUMNS
	var y0 := floori(fy)
	var tx := fx - floorf(fx)
	var ty := fy - y0
	var i00 := (y0 * GLOBAL_COLUMNS + x0) * 4
	var i10 := (y0 * GLOBAL_COLUMNS + x1) * 4
	var i01 := i00 + GLOBAL_COLUMNS * 4
	var i11 := i10 + GLOBAL_COLUMNS * 4
	var result := [0.0, 0.0, 0.0, 0.0]
	for k in 4:
		result[k] = lerpf(lerpf(_global_lattice[i00 + k], _global_lattice[i10 + k], tx),
			lerpf(_global_lattice[i01 + k], _global_lattice[i11 + k], tx), ty)
	return result


## The belt wind at a latitude (linear between the belts) blended with the
## regional anchors by Gaussian weight, at every global lattice point.
func _build_global_lattice() -> void:
	_global_lattice.resize(GLOBAL_COLUMNS * GLOBAL_ROWS * 4)
	var two_sigma_sq := 2.0 * _global_influence * _global_influence
	for row in GLOBAL_ROWS:
		var lat := GLOBAL_SOUTH + row * GLOBAL_STEP
		var lat_scale := cos(deg_to_rad(lat))
		var belt := _belt_at(lat)
		for column in GLOBAL_COLUMNS:
			var lon := -180.0 + column * GLOBAL_STEP
			var direction: Vector2 = belt.dir * _belt_weight
			var speed: float = belt.kn * _belt_weight
			var variability: float = belt["var"] * _belt_weight
			var total := _belt_weight
			for anchor in _global_anchors:
				var dx: float = GeoMath.wrap_delta(lon, anchor.lon) * lat_scale
				var dy: float = lat - anchor.lat
				var weight := exp(-(dx * dx + dy * dy) / two_sigma_sq)
				direction += anchor.dir * weight
				speed += anchor.kn * weight
				variability += anchor["var"] * weight
				total += weight
			var i := (row * GLOBAL_COLUMNS + column) * 4
			_global_lattice[i] = direction.x / total
			_global_lattice[i + 1] = direction.y / total
			_global_lattice[i + 2] = speed / total
			_global_lattice[i + 3] = variability / total


func _belt_at(lat: float) -> Dictionary:
	if _belts.is_empty():
		return {"dir": Vector2(0.0, -1.0), "kn": 10.0, "var": 0.5}
	if lat <= _belts[0].lat:
		return _belts[0]
	for i in range(1, _belts.size()):
		var high: Dictionary = _belts[i]
		if lat <= high.lat:
			var low: Dictionary = _belts[i - 1]
			var t: float = (lat - low.lat) / (high.lat - low.lat)
			return {"dir": (low.dir as Vector2).lerp(high.dir, t), "kn": lerpf(low.kn, high.kn, t), "var": lerpf(low["var"], high["var"], t)}
	return _belts[_belts.size() - 1]


## Gaussian-weighted blend of the anchors at every lattice point (done once).
func _build_lattice() -> void:
	_lattice.resize(LATTICE_COLUMNS * LATTICE_ROWS * 4)
	var two_sigma_sq := 2.0 * _influence * _influence
	for row in LATTICE_ROWS:
		var lat := LATTICE_SOUTH + row * LATTICE_STEP
		var lat_scale := cos(deg_to_rad(lat))
		for column in LATTICE_COLUMNS:
			var lon := LATTICE_WEST + column * LATTICE_STEP
			var direction := Vector2.ZERO
			var speed := 0.0
			var variability := 0.0
			var total := 0.0
			for anchor in _anchors:
				var dx: float = (lon - anchor.lon) * lat_scale
				var dy: float = lat - anchor.lat
				var weight := exp(-(dx * dx + dy * dy) / two_sigma_sq) + 1e-9
				direction += anchor.dir * weight
				speed += anchor.kn * weight
				variability += anchor["var"] * weight
				total += weight
			var i := (row * LATTICE_COLUMNS + column) * 4
			_lattice[i] = direction.x / total
			_lattice[i + 1] = direction.y / total
			_lattice[i + 2] = speed / total
			_lattice[i + 3] = variability / total


## sin(phase) of a weather wave at `geo`. The phase depends on longitude, so
## towards the Date Line the wave is cross-faded with its copy one turn round
## the globe: at ±180° both sides then agree and the wind has no seam.
func _wave(wave: Dictionary, geo: Vector2, days: float, seed: int, index: int) -> float:
	var value := sin(_wave_phase(wave, geo, days, seed, index))
	var fade := 0.5 * smoothstep(180.0 - DATELINE_FADE_DEG, 180.0, absf(geo.x))
	if fade <= 0.0:
		return value
	var other := Vector2(geo.x - signf(geo.x) * 360.0, geo.y)
	return lerpf(value, sin(_wave_phase(wave, other, days, seed, index)), fade)


func _wave_phase(wave: Dictionary, geo: Vector2, days: float, seed: int, index: int) -> float:
	var angle := deg_to_rad(float(wave.angle_deg))
	var along := geo.x * cos(deg_to_rad(geo.y)) * cos(angle) + geo.y * sin(angle)
	var seed_offset := float(seed) * 0.6180339887 * TAU * (index + 1)
	return TAU * (along / float(wave.wavelength_deg) - days / float(wave.period_days)) + float(wave.phase) + seed_offset
