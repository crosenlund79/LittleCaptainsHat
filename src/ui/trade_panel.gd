class_name TradePanel
extends SimplePanel
## The shared look of the harbour trades (I020): a title, a line about who
## is serving, a scrolling list of rows (name, a short description, and one
## button with the price), the Captain's funds, and Close. One pattern for
## the chandlery, the sailmaker, the fishmonger and the cabin, so each new
## trade is a few rows of data rather than a new screen.

const LIST_HEIGHT := 470.0
const ROW_TEXT_WIDTH := 430.0

var _list: VBoxContainer
var _funds: Label
var _rows := {}


func _build_trade(title: String, intro: String, width := 760.0) -> void:
	_build(title, width)
	_label("Intro", intro, &"MutedLabel")
	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.custom_minimum_size = Vector2(width - 40.0, LIST_HEIGHT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_box.add_child(scroll)
	_list = VBoxContainer.new()
	_list.name = "List"
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override(&"separation", 10)
	scroll.add_child(_list)
	_funds = _label("Funds", "", &"MutedLabel")
	_button("CloseButton", "Close", close)
	GameSession.funds_changed.connect(_on_funds_changed)
	GameSession.home_changed.connect(refresh)
	GameSession.boat_care_changed.connect(refresh)


## A section heading in the list.
func _heading(node_name: String, text: String) -> Label:
	var label := Label.new()
	label.name = node_name
	label.text = text
	label.theme_type_variation = &"HeaderLabel"
	_list.add_child(label)
	return label


## A row: name and description on the left, one button on the right.
func _row(id: String, title: String, text: String, action: Callable) -> Button:
	var row := HBoxContainer.new()
	row.name = "Row_%s" % id
	row.add_theme_constant_override(&"separation", 14)
	_list.add_child(row)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(words)
	var name_label := Label.new()
	name_label.name = "Name"
	name_label.text = title
	words.add_child(name_label)
	var text_label := Label.new()
	text_label.name = "Text"
	text_label.text = text
	text_label.theme_type_variation = &"MutedLabel"
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.custom_minimum_size = Vector2(ROW_TEXT_WIDTH, 0)
	text_label.add_theme_font_size_override(&"font_size", 15)
	words.add_child(text_label)
	var button := Button.new()
	button.name = "Button"
	button.custom_minimum_size = Vector2(200, 0)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(action)
	row.add_child(button)
	_rows[id] = button
	return button


func get_row_button(id: String) -> Button:
	return _rows.get(id)


func get_row_ids() -> Array:
	return _rows.keys()


func _on_funds_changed(_funds_now: int) -> void:
	refresh()


## Updates the buttons and the funds line (override; call super).
func refresh() -> void:
	if _funds:
		_funds.text = Loc.t("Your funds: %s") % GameSession.format_money(GameSession.get_funds())


func focus_default() -> void:
	for id: String in _rows:
		var button := _rows[id] as Button
		if not button.disabled:
			button.grab_focus()
			return
	var close_button := find_child("CloseButton", true, false) as Button
	if close_button:
		close_button.grab_focus()
