class_name HatConfig
extends RefCounted
## Balancing for the captain's hat, from data/hat/hat_config.json: the
## replacement price and how wind at the boat strains a worn hat.
##
## Pure data and pure functions; nothing here changes state. Simulation asks
## strain_per_minute() at its fixed hat checks and GameSession applies the
## result (see HatState).

const DEFAULT_PATH := "res://data/hat/hat_config.json"

static var _default: HatConfig

## Euros for a replacement hat (harbour grocery store).
var price_eur := 15
## Game seconds between two hat checks (an absolute grid on the game clock).
var check_interval_s := 60.0
## Gusts count as wind of (gust - this), so a gusty day counts even when the
## sustained wind is lighter.
var gust_allowance_kn := 10.0
## [{"from_kn", "strain_per_min"}] for the effective wind, ascending.
var bands: Array[Dictionary] = []
## [{"from_kn", "strain_per_min"}] added for strong gusts, ascending.
var gust_bands: Array[Dictionary] = []
## Strain is multiplied by this while moored (a harbour is sheltered).
var harbour_factor := 0.5
## Strain that recovers per game minute when the hat is not at risk.
var recovery_per_min := 2.0
## After a warning, another one comes only once the hat has recovered and
## at least this many game minutes have passed.
var warning_repeat_min := 30.0
## Each hat holds until its strain reaches a threshold in this range.
var threshold_min := 30.0
var threshold_max := 50.0


static func get_default() -> HatConfig:
	if _default == null:
		_default = load_from(DEFAULT_PATH)
	return _default


static func clear_default() -> void:
	_default = null


static func load_from(path: String) -> HatConfig:
	var config := HatConfig.new()
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary:
		push_error("Cannot read the hat settings from %s; using defaults." % path)
		config.bands = _default_bands()
		return config
	config.price_eur = maxi(int(data.get("price_eur", config.price_eur)), 0)
	config.check_interval_s = maxf(float(data.get("check_interval_s", config.check_interval_s)), 1.0)
	config.gust_allowance_kn = maxf(float(data.get("gust_allowance_kn", config.gust_allowance_kn)), 0.0)
	config.bands = _read_bands(data.get("bands"))
	if config.bands.is_empty():
		push_error("Hat settings have no wind bands; using defaults.")
		config.bands = _default_bands()
	config.gust_bands = _read_bands(data.get("gust_bands"))
	config.harbour_factor = clampf(float(data.get("harbour_factor", config.harbour_factor)), 0.0, 1.0)
	config.recovery_per_min = maxf(float(data.get("recovery_per_min", config.recovery_per_min)), 0.0)
	config.warning_repeat_min = maxf(float(data.get("warning_repeat_min", config.warning_repeat_min)), 0.0)
	config.threshold_min = maxf(float(data.get("threshold_min", config.threshold_min)), 1.0)
	config.threshold_max = maxf(float(data.get("threshold_max", config.threshold_max)), config.threshold_min)
	return config


static func _read_bands(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not value is Array:
		return result
	for entry: Variant in value:
		if entry is Dictionary and _is_number(entry.get("from_kn")) and _is_number(entry.get("strain_per_min")):
			result.append({"from_kn": float(entry.from_kn), "strain_per_min": maxf(float(entry.strain_per_min), 0.0)})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.from_kn < b.from_kn)
	return result


static func _default_bands() -> Array[Dictionary]:
	return [{"from_kn": 25.0, "strain_per_min": 0.25}, {"from_kn": 35.0, "strain_per_min": 1.0},
		{"from_kn": 45.0, "strain_per_min": 2.0}]


static func _is_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))


## The wind a worn hat feels: the sustained wind, or the gusts less the
## allowance when they are the stronger.
func effective_kn(sustained_kn: float, gust_kn: float) -> float:
	return maxf(sustained_kn, gust_kn - gust_allowance_kn)


## The lowest wind (effective) at which a worn hat is at any risk.
func risk_from_kn() -> float:
	return float(bands[0].from_kn)


## Strain a worn hat on deck gathers per game minute in this wind (0 = no
## risk). `in_harbour` applies the harbour's shelter.
func strain_per_minute(sustained_kn: float, gust_kn: float, in_harbour: bool) -> float:
	var wind := effective_kn(sustained_kn, gust_kn)
	var rate := 0.0
	for band in bands:
		if wind >= band.from_kn:
			rate = band.strain_per_min
	if rate <= 0.0:
		return 0.0
	# Gust bands are not cumulative: the strongest one reached applies.
	var gust_extra := 0.0
	for band in gust_bands:
		if gust_kn >= band.from_kn:
			gust_extra = band.strain_per_min
	rate += gust_extra
	return rate * (harbour_factor if in_harbour else 1.0)


## The strain hat number `serial` of a game with `seed` can take before it
## blows away: fixed for that hat, between threshold_min and threshold_max.
func threshold_for(seed: int, serial: int) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed, "captains_hat", serial])
	return lerpf(threshold_min, threshold_max, rng.randf())
