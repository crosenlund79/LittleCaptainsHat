class_name GalleyState
extends RefCounted
## The galley (Iteration 13): when a warm meal was last cooked and its small
## lasting benefit. A warm meal makes the crew "well fed" until
## well_fed_until: the food stores are used up a little more slowly
## (GameSession.WELL_FED_FOOD_FACTOR). Plain data in SessionState.

var well_fed_until := 0.0
var meals_cooked := 0
var last_meal := ""
var last_meal_at := 0.0


func duplicate_state() -> GalleyState:
	var copy := GalleyState.new()
	copy.well_fed_until = well_fed_until
	copy.meals_cooked = meals_cooked
	copy.last_meal = last_meal
	copy.last_meal_at = last_meal_at
	return copy


func to_dict() -> Dictionary:
	return {"well_fed_until": well_fed_until, "meals_cooked": meals_cooked, "last_meal": last_meal, "last_meal_at": last_meal_at}


static func from_dict(data: Variant, errors: Array[String]) -> GalleyState:
	if not data is Dictionary or not data.get("last_meal") is String:
		errors.append("missing or invalid galley record")
		return null
	for key in ["well_fed_until", "meals_cooked", "last_meal_at"]:
		var value: Variant = data.get(key)
		if not ((value is int or value is float) and is_finite(float(value))):
			errors.append("invalid galley record (%s)" % key)
			return null
	var state := GalleyState.new()
	state.well_fed_until = float(data.well_fed_until)
	state.meals_cooked = maxi(int(data.meals_cooked), 0)
	state.last_meal = data.last_meal
	state.last_meal_at = float(data.last_meal_at)
	return state
