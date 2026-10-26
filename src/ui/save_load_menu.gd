class_name SaveLoadMenu
extends ModalPanel
## Lists the manual save slots with their metadata. In SAVE mode it writes the
## current session to the chosen slot (asking before overwriting); in LOAD
## mode it reports the chosen slot and lets the application flow load it.

signal load_requested(slot: int)

enum Mode { SAVE, LOAD }

var mode := Mode.LOAD

@onready var _title: Label = %Title
@onready var _slots: VBoxContainer = %Slots
@onready var _back: Button = %BackButton


func setup(menu_mode: Mode) -> void:
	mode = menu_mode


func _ready() -> void:
	_title.text = "Save Game" if mode == Mode.SAVE else "Load Game"
	%Hint.text = "Choose a slot to save to." if mode == Mode.SAVE else "Choose a saved game to load."
	_back.pressed.connect(close)
	SaveManager.slots_changed.connect(_refresh)
	_refresh()


func focus_default() -> void:
	for button in _slots.get_children():
		if not (button as Button).disabled:
			(button as Button).grab_focus()
			return
	_back.grab_focus()


func _refresh() -> void:
	for child in _slots.get_children():
		_slots.remove_child(child)
		child.queue_free()
	for info in SaveManager.get_all_slot_info():
		_slots.add_child(_create_slot_entry(info))
	# The quicksave (F5) can be loaded here too; it is never saved to from here.
	var quick := SaveManager.get_slot_info(SaveManager.QUICKSAVE_SLOT)
	if mode == Mode.LOAD and quick.status != SaveManager.Status.EMPTY:
		_slots.add_child(_create_slot_entry(quick))


func _create_slot_entry(info: SaveManager.SlotInfo) -> Button:
	var button := Button.new()
	button.name = "Slot%d" % info.slot
	button.theme_type_variation = &"SlotButton"
	button.custom_minimum_size = Vector2(700, 92)
	button.disabled = mode == Mode.LOAD and not info.is_loadable()
	button.pressed.connect(_on_slot_pressed.bind(info))

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 22)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var title := Label.new()
	title.theme_type_variation = &"HeaderLabel"
	title.text = "Quicksave (F5)" if info.slot == SaveManager.QUICKSAVE_SLOT else "Slot %d" % info.slot
	var details := Label.new()
	details.theme_type_variation = &"MutedLabel"
	details.text = describe_slot(info)
	details.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	for label: Label in [title, details]:
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(label)
	margin.add_child(box)
	button.add_child(margin)
	return button


## One-line, human-readable summary of a slot.
static func describe_slot(info: SaveManager.SlotInfo) -> String:
	match info.status:
		SaveManager.Status.EMPTY:
			return "Empty slot"
		SaveManager.Status.CORRUPTED:
			return "Damaged save — cannot be loaded. %s" % info.problem
		SaveManager.Status.UNSUPPORTED:
			return "Unsupported save — %s" % info.problem
	var parts := [format_timestamp(info.saved_at_unix), info.area_name, info.location_name]
	if not info.destination_name.is_empty():
		parts.append("Route to %s" % info.destination_name)
	return "  ·  ".join(parts)


static func format_timestamp(unix_time: float) -> String:
	var bias_minutes: int = Time.get_time_zone_from_system().get("bias", 0)
	var local := Time.get_datetime_dict_from_unix_time(int(unix_time) + bias_minutes * 60)
	return "%04d-%02d-%02d %02d:%02d" % [local.year, local.month, local.day, local.hour, local.minute]


func _on_slot_pressed(info: SaveManager.SlotInfo) -> void:
	if mode == Mode.LOAD:
		load_requested.emit(info.slot)
		return
	if info.status != SaveManager.Status.EMPTY:
		var overwrite: bool = await stack.confirm("Overwrite slot %d?" % info.slot,
			"The saved game in slot %d will be replaced by your current game." % info.slot, "Overwrite")
		if not overwrite:
			return
	var err := SaveManager.save_to_slot(info.slot, GameSession.get_state_snapshot())
	if err == OK:
		GameSession.mark_saved()
		notify("Game saved to slot %d." % info.slot)
		close()
	else:
		notify("Saving failed (%s). Your previous save was kept." % error_string(err))
