class_name Provisions
extends RefCounted
## Food and fresh water aboard, in days (fractional). Plain data owned by
## SessionState and changed only through GameSession: one day of each is
## consumed per 24 hours of game time, wherever the boat is (GameSession.
## apply_simulation_step), so pausing stops consumption and sleeping consumes.
## Running out does not hurt anyone; it only blocks the next departure.

## Full stores (a new game starts with these).
const CAPACITY_DAYS := 14.0
## Warning thresholds (days left of the scarcer supply).
const LOW_DAYS := 3.0
const CRITICAL_DAYS := 1.0
const DAY_SECONDS := 86400.0

## Warning levels, in increasing urgency (0 = none given).
const WARN_NONE := 0
const WARN_LOW := 1
const WARN_CRITICAL := 2
const WARN_EMPTY := 3

## Supply levels for the cabin graphics and labels.
const LEVEL_FULL := &"full"
const LEVEL_MODERATE := &"moderate"
const LEVEL_LOW := &"low"
const LEVEL_EMPTY := &"empty"

var food_days := CAPACITY_DAYS
var water_days := CAPACITY_DAYS
## The most urgent warning already given since the last restock (so each
## warning is given once).
var warning_level := WARN_NONE


## Uses up `days` of food and water (never below zero). `food_factor` below 1
## makes the food last longer (a well-fed crew, Iteration 13).
func consume(days: float, food_factor := 1.0) -> void:
	if days <= 0.0:
		return
	food_days = maxf(food_days - days * food_factor, 0.0)
	water_days = maxf(water_days - days, 0.0)


## Takes `days` of food for cooking (Iteration 13). False, and nothing taken,
## when there is not that much.
func take_food(days: float) -> bool:
	if days < 0.0 or days > food_days + 1e-9:
		return false
	food_days = maxf(food_days - days, 0.0)
	return true


## Adds `days` of food (cooked catch), up to the capacity. Returns what fitted.
func add_food(days: float) -> float:
	var added := clampf(days, 0.0, CAPACITY_DAYS - food_days)
	food_days += added
	return added


func restock() -> void:
	food_days = CAPACITY_DAYS
	water_days = CAPACITY_DAYS
	warning_level = WARN_NONE


## How long the crew can last: the scarcer of food and water.
func endurance_days() -> float:
	return minf(food_days, water_days)


func is_empty() -> bool:
	return food_days <= 0.0 or water_days <= 0.0


func is_full() -> bool:
	return food_days >= CAPACITY_DAYS and water_days >= CAPACITY_DAYS


## The warning level the current stores call for.
func needed_warning() -> int:
	var left := endurance_days()
	if left <= 0.0:
		return WARN_EMPTY
	if left <= CRITICAL_DAYS:
		return WARN_CRITICAL
	if left <= LOW_DAYS:
		return WARN_LOW
	return WARN_NONE


## Full (more than three quarters), moderate (more than a third), low, empty.
static func level_of(days: float) -> StringName:
	if days <= 0.0:
		return LEVEL_EMPTY
	if days > CAPACITY_DAYS * 0.75:
		return LEVEL_FULL
	if days > CAPACITY_DAYS / 3.0:
		return LEVEL_MODERATE
	return LEVEL_LOW


## "12.5 days" (one decimal, never rounded up to look fuller than it is).
static func format_days(days: float) -> String:
	var shown := floorf(days * 10.0 + 1e-6) / 10.0
	return "%.1f day%s" % [shown, "" if is_equal_approx(shown, 1.0) else "s"]


func duplicate_provisions() -> Provisions:
	var copy := Provisions.new()
	copy.food_days = food_days
	copy.water_days = water_days
	copy.warning_level = warning_level
	return copy


func to_dict() -> Dictionary:
	return {"food_days": food_days, "water_days": water_days, "warning_level": warning_level}


static func from_dict(data: Variant, errors: Array[String]) -> Provisions:
	if not data is Dictionary:
		errors.append("missing provisions")
		return null
	var food: Variant = data.get("food_days")
	var water: Variant = data.get("water_days")
	var warned: Variant = data.get("warning_level", WARN_NONE)
	if not (_is_number(food) and _is_number(water) and _is_number(warned)):
		errors.append("invalid provisions")
		return null
	var provisions := Provisions.new()
	provisions.food_days = clampf(float(food), 0.0, CAPACITY_DAYS)
	provisions.water_days = clampf(float(water), 0.0, CAPACITY_DAYS)
	provisions.warning_level = clampi(int(warned), WARN_NONE, WARN_EMPTY)
	return provisions


static func _is_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))
