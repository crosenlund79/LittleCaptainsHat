class_name ProvisionsMenu
extends ModalPanel
## The provisions locker: how much food and fresh water is aboard, how long it
## lasts, and (moored in harbour) restocking. Opened from the provisions
## station in every cabin. Reads GameSession; restocking itself is
## GameSession.restock_provisions().

@onready var _intro: Label = %Intro
@onready var _food: Label = %FoodValue
@onready var _food_level: Label = %FoodLevel
@onready var _water: Label = %WaterValue
@onready var _water_level: Label = %WaterLevel
@onready var _endurance: Label = %EnduranceValue
@onready var _note: Label = %Note
@onready var _restock: Button = %RestockButton


func _ready() -> void:
	_restock.pressed.connect(_on_restock)
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
	_restock.disabled = not harbour or provisions.is_full()
	if not harbour:
		_note.text = "Underway: you can restock in the next harbour."
	elif provisions.is_full():
		_note.text = "Food and water are full. Restocking in harbour is free."
	else:
		_note.text = "Moored in %s: restocking here is free." % GameSession.get_location().display_name
	if provisions.is_empty():
		_note.text += " You are out of supplies: you cannot set sail until you restock."


func get_values() -> Dictionary:
	return {"food": _food.text, "water": _water.text, "endurance": _endurance.text,
		"food_level": _food_level.text, "water_level": _water_level.text}


func _on_restock() -> void:
	var error := GameSession.restock_provisions()
	notify(error if not error.is_empty() else "Provisions restocked: %s of food and water." % Provisions.format_days(Provisions.CAPACITY_DAYS))
	refresh()


func focus_default() -> void:
	if _restock.disabled:
		%CloseButton.grab_focus()
	else:
		_restock.grab_focus()
