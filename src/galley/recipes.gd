class_name Recipes
extends RefCounted
## The galley's few simple dishes (Iteration 13).
##
## Ingredients are the boat's own: fish from the cool box (the oldest first)
## and groceries from the food stores (days of food). Fish dishes turn the
## catch into food for the stores; every warm meal also leaves the crew "well
## fed" for some hours (GameSession: the food stores last a little longer).
## Grocery-only dishes are comfort food: they use about what the crew would
## eat anyway.
##
## {"id", "name", "text", "fish": fish needed, "groceries": food days used,
##  "per_kg": food days gained per kg of fish, "bonus": food days added,
##  "minutes": cooking time, "well_fed_hours"}

const LIST: Array[Dictionary] = [
	{"id": "porridge", "name": "Warm porridge", "text": "Oats, a pinch of salt and something sweet on top.",
		"fish": 0, "groceries": 0.25, "per_kg": 0.0, "bonus": 0.0, "minutes": 15, "well_fed_hours": 10.0},
	{"id": "bread_soup", "name": "Bread and soup", "text": "A pot of vegetable soup and the last of the good bread.",
		"fish": 0, "groceries": 0.5, "per_kg": 0.0, "bonus": 0.0, "minutes": 35, "well_fed_hours": 16.0},
	{"id": "pan_fried_fish", "name": "Pan-fried fish", "text": "Fresh fillets in butter, a squeeze of lemon.",
		"fish": 1, "groceries": 0.0, "per_kg": 0.6, "bonus": 0.0, "minutes": 25, "well_fed_hours": 12.0},
	{"id": "fish_stew", "name": "Fish stew", "text": "Fish, potatoes and onions simmered slowly: it stretches a catch.",
		"fish": 1, "groceries": 0.3, "per_kg": 0.9, "bonus": 0.3, "minutes": 50, "well_fed_hours": 16.0},
	{"id": "sailors_supper", "name": "A sailor's supper", "text": "Two fish, bread, butter and a proper sit-down at the table.",
		"fish": 2, "groceries": 0.5, "per_kg": 1.0, "bonus": 0.5, "minutes": 60, "well_fed_hours": 20.0},
]
## Food days gained from fish: at most this per dish (one very big cod is
## still one meal's worth of cooking).
const MAX_FISH_DAYS := 3.0


static func get_recipe(id: String) -> Dictionary:
	for recipe in LIST:
		if recipe.id == id:
			return recipe
	return {}


## Food days a dish adds to the stores from `fish_kg` of fish.
static func food_gained(recipe: Dictionary, fish_kg: float) -> float:
	if int(recipe.fish) <= 0:
		return 0.0
	return minf(float(recipe.per_kg) * fish_kg + float(recipe.bonus), MAX_FISH_DAYS)
