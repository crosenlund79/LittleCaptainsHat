class_name NewGameMenu
extends ModalPanel
## Starts a new game: the player picks the ship's companion (cat or dog).
## The cat is preselected. The choice only affects who lives in the cabin.

signal start_requested(companion_kind: StringName)

var companion_kind: StringName = CompanionState.DEFAULT_KIND

@onready var _cat: Button = %CatButton
@onready var _dog: Button = %DogButton
@onready var _preview: ShipCompanion = %Preview
@onready var _description: Label = %Description


func _ready() -> void:
	var group := ButtonGroup.new()
	_cat.button_group = group
	_dog.button_group = group
	_cat.pressed.connect(select.bind(CompanionState.KIND_CAT))
	_dog.pressed.connect(select.bind(CompanionState.KIND_DOG))
	%StartButton.pressed.connect(func() -> void: start_requested.emit(companion_kind))
	%CancelButton.pressed.connect(close)
	select(CompanionState.DEFAULT_KIND)


func select(kind: StringName) -> void:
	companion_kind = kind
	_cat.set_pressed_no_signal(kind == CompanionState.KIND_CAT)
	_dog.set_pressed_no_signal(kind == CompanionState.KIND_DOG)
	_preview.show_kind(kind)
	_description.text = "A ship's cat: likes the settee, the chart table and your berth. Purrs when petted." \
		if kind == CompanionState.KIND_CAT else \
		"A ship's dog: naps on the cabin sole, by the steps or next to the settee. Pants happily when petted."


func focus_default() -> void:
	%StartButton.grab_focus()
