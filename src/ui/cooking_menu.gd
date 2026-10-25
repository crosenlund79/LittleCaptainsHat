class_name CookingMenu
extends SimplePanel
## The galley (Iteration 13): choose a dish, see what it takes (fish from the
## cool box, groceries from the stores) and what it gives, then cook it. The
## pan sizzles and steams for a moment, the cooking time passes (App) and the
## result says what the meal did. GameSession.cook() is the one transaction;
## nothing changes when a dish is refused.
##
## The rule for the stove is simple: in harbour and at a holding anchor
## always; underway only in moderate conditions (GameSession.cooking_refusal).

## The App spends the cooking time (game minutes) when a dish is done.
signal cooked(result: Dictionary)

## Real seconds the little cooking animation runs before the meal is served.
const COOK_SECONDS := 1.6

var _recipes: ItemList
var _detail: Label
var _rule: Label
var _cook_button: Button
var _outcome: Label
var _pan: Control
var _cooking := 0.0
var _time := 0.0
var _last_result := {}
## Until when (this panel's clock) the served dish still steams.
var _steam_until := -1.0


func _ready() -> void:
	_build("Galley", 700.0)
	_rule = _label("Rule", "", &"MutedLabel")
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 16)
	_box.add_child(row)
	_recipes = ItemList.new()
	_recipes.name = "Recipes"
	_recipes.custom_minimum_size = Vector2(300, 210)
	_recipes.item_selected.connect(func(_index: int) -> void: _refresh_detail())
	row.add_child(_recipes)
	var right := VBoxContainer.new()
	right.add_theme_constant_override(&"separation", 10)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right)
	_pan = Control.new()
	_pan.name = "Pan"
	_pan.custom_minimum_size = Vector2(320, 90)
	_pan.draw.connect(_draw_pan)
	right.add_child(_pan)
	_detail = Label.new()
	_detail.name = "Detail"
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.custom_minimum_size = Vector2(320, 0)
	right.add_child(_detail)
	_outcome = _label("Outcome", "", &"HeaderLabel")
	_outcome.visible = false
	_button("CloseButton", "Close", close)
	_cook_button = _button("CookButton", "Cook", _on_cook, 200.0)
	for recipe in Recipes.LIST:
		_recipes.add_item(String(recipe.name))
	_recipes.select(_best_index())
	refresh()


## The first dish that can be cooked now (fish dishes first when there is fish).
func _best_index() -> int:
	var order := [2, 3, 4, 0, 1] if not GameSession.get_fishing().hold.is_empty() else [0, 1, 2, 3, 4]
	for i: int in order:
		if GameSession.recipe_refusal(Recipes.LIST[i].id) == "":
			return i
	return 0


func refresh() -> void:
	var refusal := GameSession.cooking_refusal()
	var fishing := GameSession.get_fishing()
	_rule.text = refusal if refusal != "" else "Fish in the cool box: %d  ·  Food in the stores: %s" % [fishing.hold.size(),
		Provisions.format_days(GameSession.get_food_days())]
	_rule.modulate = Color(1.0, 0.72, 0.55) if refusal != "" else Color.WHITE
	for i in Recipes.LIST.size():
		var ok := GameSession.recipe_refusal(Recipes.LIST[i].id) == ""
		_recipes.set_item_custom_fg_color(i, Color.WHITE if ok else Color(1, 1, 1, 0.45))
	_refresh_detail()


func get_selected_recipe() -> Dictionary:
	var selected := _recipes.get_selected_items()
	return Recipes.LIST[selected[0]] if not selected.is_empty() else Recipes.LIST[0]


func select_recipe(id: String) -> void:
	for i in Recipes.LIST.size():
		if Recipes.LIST[i].id == id:
			_recipes.select(i)
	_refresh_detail()


func _refresh_detail() -> void:
	var recipe := get_selected_recipe()
	var needs := PackedStringArray()
	if int(recipe.fish) > 0:
		needs.append("%d fish from the cool box (the oldest first)" % int(recipe.fish))
	if float(recipe.groceries) > 0.0:
		needs.append("%s of groceries" % Provisions.format_days(float(recipe.groceries)))
	var gives := "Well fed for %d hours: the stores last a little longer." % roundi(float(recipe.well_fed_hours))
	if int(recipe.fish) > 0:
		gives = "Turns the catch into food for the stores (up to %s). " % Provisions.format_days(Recipes.MAX_FISH_DAYS) + gives
	var refusal := GameSession.recipe_refusal(recipe.id)
	_detail.text = "%s\n\nNeeds: %s.\nTakes %d minutes.\n%s%s" % [recipe.text, ", ".join(needs) if not needs.is_empty() else "nothing special",
		int(recipe.minutes), gives, ("\n\n" + refusal) if refusal != "" else ""]
	_cook_button.disabled = _cooking > 0.0 or refusal != "" or GameSession.cooking_refusal() != ""
	_cook_button.text = "Cook %s" % String(recipe.name).to_lower()


func focus_default() -> void:
	_recipes.grab_focus()


func _on_cook() -> void:
	var recipe := get_selected_recipe()
	var refusal := GameSession.cooking_refusal()
	if refusal == "":
		refusal = GameSession.recipe_refusal(recipe.id)
	if refusal != "":
		notify(refusal)
		return
	_cooking = COOK_SECONDS
	_cook_button.disabled = true
	_outcome.visible = false
	AudioManager.play_sfx(FishingSounds.sizzle(), FishingSounds.DB)


func _process(delta: float) -> void:
	_time += delta
	if _cooking > 0.0:
		_cooking = maxf(_cooking - delta, 0.0)
		if _cooking <= 0.0:
			serve()
	_pan.queue_redraw()


func is_cooking() -> bool:
	return _cooking > 0.0


## Serves the dish now (the animation's end; tests call it directly).
func serve() -> Dictionary:
	_cooking = 0.0
	var recipe := get_selected_recipe()
	var result := GameSession.cook(recipe.id)
	_last_result = result
	SessionLog.write("cooking", {"recipe": recipe.id, "error": result.error, "minutes": result.minutes,
		"food_added": snappedf(float(result.food_added), 0.01), "fish": result.fish.size(), "evening": result.evening})
	if result.error != "":
		notify(result.error)
		refresh()
		return result
	cooked.emit(result)
	var lines := ["%s is ready." % String(recipe.name)]
	if float(result.food_added) > 0.0:
		lines.append("The catch adds %s of food to the stores." % Provisions.format_days(float(result.food_added)))
	lines.append("Well fed until %s." % Simulation.format_game_time(float(result.well_fed_until)))
	if result.evening:
		lines.append("A quiet evening at anchor. Fresh fish for supper.")
	_outcome.text = "\n".join(lines)
	_outcome.visible = true
	_steam_until = _time + 6.0
	refresh()
	return result


func get_last_result() -> Dictionary:
	return _last_result


func get_outcome_text() -> String:
	return _outcome.text if _outcome.visible else ""


## The pan on the stove: it sizzles while cooking and steams afterwards.
func _draw_pan() -> void:
	var c := Vector2(_pan.size.x / 2.0, _pan.size.y - 26.0)
	_pan.draw_rect(Rect2(c + Vector2(-90, 14), Vector2(180, 10)), Color("#2c3436"))
	var flame := _cooking > 0.0
	if flame:
		for k in 5:
			var x := -40.0 + k * 20.0
			var h := 6.0 + 3.0 * sin(_time * 18.0 + k)
			_pan.draw_colored_polygon(PackedVector2Array([c + Vector2(x - 5, 14), c + Vector2(x, 14 - h), c + Vector2(x + 5, 14)]),
				Color("#e0a84e"))
	_pan.draw_rect(Rect2(c + Vector2(-56, -6), Vector2(112, 18)), Color("#1f2a2e"))
	_pan.draw_rect(Rect2(c + Vector2(-52, -4), Vector2(104, 12)), Color("#55605f"))
	_pan.draw_line(c + Vector2(56, 0), c + Vector2(110, -8), Color("#1f2a2e"), 5.0, true)
	var food := Color("#c9a46a") if int(get_selected_recipe().fish) == 0 else Color("#e8d6b0")
	_pan.draw_rect(Rect2(c + Vector2(-40, -9), Vector2(80, 6)), food)
	var steam := 1.0 if flame else clampf((_steam_until - _time) / 2.0, 0.0, 1.0)
	if steam > 0.0:
		for k in 5:
			var phase := fmod(_time * 0.7 + k / 5.0, 1.0)
			var p := c + Vector2(-30 + k * 15 + 6.0 * sin(_time * 2.0 + k), -12 - phase * 46.0)
			_pan.draw_circle(p, 4.0 + phase * 7.0, Color(1, 1, 1, 0.3 * (1.0 - phase) * steam))
