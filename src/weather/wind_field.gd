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
		var from_rad := deg_to_rad(float(anchor.from))
		field._anchors.append({
			"lon": float(anchor.lon), "lat": float(anchor.lat),
			"dir": Vector2(sin(from_rad), cos(from_rad)),
			"kn": float(anchor.kn), "var": float(anchor.get("var", 0.4)),
		})
	field._direction_waves = data.get("direction_waves", [])
	field._speed_waves = data.get("speed_waves", [])
	field._lull = data.get("lull_wave", {})
	return field


## Converts a FROM direction to the TO direction (and back).
static func from_to_to(degrees: float) -> float:
	return fposmod(degrees + 180.0, 360.0)


## Signed angle from the vessel's heading to the wind's FROM direction, in
## (-180, 180]: 0 = wind from dead ahead, ±180 = from astern, positive = from
## starboard (the right side), negative = from port.
static func relative_angle(heading_deg: float, wind_from_deg: float) -> float:
	var angle := fposmod(wind_from_deg - heading_deg + 180.0, 360.0) - 180.0
	return 180.0 if is_equal_approx(angle, -180.0) else angle


## 16-point compass name for a direction ("WSW").
static func compass_name(degrees: float) -> String:
	const NAMES := ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE", "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"]
	return NAMES[roundi(fposmod(degrees, 360.0) / 22.5) % 16]


## The wind at `geo` (Vector2(lon, lat)) at `game_time` (UTC seconds).
func sample(geo: Vector2, game_time: float, seed := 1) -> Sample:
	if test_override.is_valid():
		return test_override.call(geo, game_time)
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
		veer += float(wave.amplitude_deg) * sin(_wave_phase(wave, geo, days, seed, i))
	var factor := 0.0
	for i in _speed_waves.size():
		var wave: Dictionary = _speed_waves[i]
		factor += float(wave.amplitude) * sin(_wave_phase(wave, geo, days, seed, i + 7))
	factor = maxf(1.0 + strength * factor, MIN_SPEED_FACTOR)
	if not _lull.is_empty():
		var lull := sin(_wave_phase(_lull, geo, days, seed, 13))
		factor *= 1.0 - float(_lull.depth) * smoothstep(float(_lull.threshold), 1.0, lull)
	return Sample.make(from + strength * veer, speed * factor)


## Typical (undisturbed) wind at `geo`: [dir_x, dir_y, speed_kn, variability],
## bilinearly interpolated from the precomputed lattice.
func climatology(geo: Vector2) -> Array:
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


func _wave_phase(wave: Dictionary, geo: Vector2, days: float, seed: int, index: int) -> float:
	var angle := deg_to_rad(float(wave.angle_deg))
	var along := geo.x * cos(deg_to_rad(geo.y)) * cos(angle) + geo.y * sin(angle)
	var seed_offset := float(seed) * 0.6180339887 * TAU * (index + 1)
	return TAU * (along / float(wave.wavelength_deg) - days / float(wave.period_days)) + float(wave.phase) + seed_offset
