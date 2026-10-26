class_name ProvisionsMenu
extends ModalPanel
## The provisions locker: how much food and fresh water is aboard and how
## long it lasts. Opened from the provisions station in every cabin. Reads
## GameSession. In harbour it leads to the grocery store (GroceryMenu), where
## provisions are bought.

## The player wants the grocery store (App opens it on top of this panel).
signal grocery_requested

@onready var _intro: Label = %Intro
@onready var _food: Label = %FoodValue
@onready var _food_level: Label = %FoodLevel
@onready var _water: Label = %WaterValue
@onready var _water_level: Label = %WaterLevel
@onready var _endurance: Label = %EnduranceValue
@onready var _note: Label = %Note
@onready var _grocery: Button = %GroceryButton


func _ready() -> void:
	_grocery.pressed.connect(grocery_requested.emit)
	%CloseButton.pressed.connect(close)
	refresh()


func _process(_delta: float) -> void:
	if is_visible_in_tree():
		refresh()


func refresh() -> void:
	var provisions := GameSession.get_provisions()
	_intro.text = "Food and fresh water aboard the %s. One day of each is used per day, at sea and in harbour." % \
		GameSession.get_vessel_definition().display_name
	_food.text = Provisions.format_days(provisions.food_days)
	_water.text = Provisions.format_days(provisions.water_days)
	_food_level.text = String(Provisions.level_of(provisions.food_days)).capitalize()
	_water_level.text = String(Provisions.level_of(provisions.water_days)).capitalize()
	_endurance.text = Provisions.format_days(provisions.endurance_days())
	var harbour := GameSession.is_moored_in_harbour()
	var store := GameSession.has_facility(HarbourFacilities.GROCERY)
	_grocery.disabled = not store or provisions.is_full(GameSession.get_passage_store_days())
	_grocery.visible = not harbour or store
	_grocery.text = "Grocery store (%s)…" % GameSession.format_money(GameSession.get_provisions_price()) \
		if not provisions.is_full() else "Grocery store…"
	if not harbour:
		_note.text = "Underway: buy food and water at the grocery store in the next harbour."
	elif not store:
		_note.text = "There is no grocery store in %s." % GameSession.get_location().display_name
	elif provisions.is_full():
		_note.text = "Food and water are full."
	else:
		_note.text = "Moored in %s: the grocery store fills both for %s." % [GameSession.get_location().display_name,
			GameSession.format_money(GameSession.get_provisions_price())]
	if provisions.is_empty():
		_note.text += " You are out of supplies: you cannot set sail until you buy more."


func get_values() -> Dictionary:
	return {"food": _food.text, "water": _water.text, "endurance": _endurance.text,
		"food_level": _food_level.text, "water_level": _water_level.text}


func focus_default() -> void:
	if _grocery.disabled:
		%CloseButton.grab_focus()
	else:
		_grocery.grab_focus()
