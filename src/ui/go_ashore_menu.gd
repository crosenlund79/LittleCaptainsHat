class_name GoAshoreMenu
extends SimplePanel
## Go Ashore (Iteration 12): one small harbour moment. A title, a little drawn
## picture, a short text and one or two choices, each with its cost and the
## time it takes, plus Return to the boat. After a choice the panel tells what
## happened and offers only Return. GameSession does the bookkeeping; the App
## spends the time (choice_made).

signal choice_made(event_id: String, choice_index: int)

const ICON_INK := Color("#342c26")

var _offer := {}
var _icon: Control
var _icon_id := ""
var _text: Label
var _choices: VBoxContainer
var _time := 0.0


func _ready() -> void:
	var place := GameSession.get_location()
	_build("Ashore in %s" % (place.display_name if place else "harbour"), 660.0)
	var row := HBoxContainer.new()
	row.name = "EventRow"
	row.add_theme_constant_override(&"separation", 18)
	_box.add_child(row)
	_icon = Control.new()
	_icon.name = "Icon"
	_icon.custom_minimum_size = Vector2(96, 96)
	_icon.draw.connect(_draw_icon)
	row.add_child(_icon)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(column)
	var heading := Label.new()
	heading.name = "EventTitle"
	heading.theme_type_variation = &"DisplayName"
	column.add_child(heading)
	_text = Label.new()
	_text.name = "EventText"
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(500, 0)
	column.add_child(_text)
	_choices = VBoxContainer.new()
	_choices.name = "Choices"
	_choices.add_theme_constant_override(&"separation", 8)
	_box.add_child(_choices)
	_button("ReturnButton", "Return to the boat", close, 220.0)
	_offer = GameSession.get_shore_event()
	if _offer.get("resting", false):
		heading.text = "A pleasant stroll"
		_icon_id = "bench"
		_text.text = "You have had a good look around %s for now. Come back in a few hours, or see what the next harbour holds." % \
			(place.display_name if place else "the harbour")
	elif _offer.has("event"):
		var event: Dictionary = _offer.event
		heading.text = event.title
		_icon_id = event.icon
		_text.text = ShoreEvents.fill(event.text, place.display_name)
		for i in event.choices.size():
			var choice: Dictionary = event.choices[i]
			var button := Button.new()
			button.name = "Choice%d" % i
			button.text = _describe_choice(choice)
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.disabled = int(choice.cost) > GameSession.get_funds()
			button.pressed.connect(choice_made.emit.bind(String(event.id), i))
			_choices.add_child(button)
		if _offer.get("seen", false):
			_label("Seen", "You have enjoyed everything %s has to offer before. It is still lovely." % place.display_name, &"MutedLabel")
	else:
		heading.text = "Nothing ashore"
		_text.text = GameSession.facility_refusal(HarbourFacilities.GO_ASHORE)


func focus_default() -> void:
	var first := _choices.get_child(0) as Button if _choices.get_child_count() > 0 else null
	if first and not first.disabled:
		first.grab_focus()
	else:
		(find_child("ReturnButton", true, false) as Button).grab_focus()


func _process(delta: float) -> void:
	_time += delta
	_icon.queue_redraw()


## "Coffee and a pastry  ·  €6  ·  40 min" (free choices say so).
static func _describe_choice(choice: Dictionary) -> String:
	var cost := int(choice.cost)
	return "%s  ·  %s  ·  %d min" % [choice.label, GameSession.format_money(cost) if cost > 0 else "free", int(choice.minutes)]


## Shows what happened; only Return remains.
func show_outcome(result: Dictionary) -> void:
	for child in _choices.get_children():
		child.queue_free()
	var seen := find_child("Seen", true, false)
	if seen:
		seen.queue_free()
	if String(result.error) != "":
		_text.text = result.error
		return
	var lines := [String(result.outcome)]
	var details := PackedStringArray()
	if int(result.cost) > 0:
		details.append("−%s" % GameSession.format_money(int(result.cost)))
	details.append("%d min" % int(result.minutes))
	if int(result.renown) > 0:
		details.append("+%d renown · a notable moment in the Captain's Log" % int(result.renown))
	lines.append("  ·  ".join(details))
	_text.text = "\n\n".join(lines)
	(find_child("ReturnButton", true, false) as Button).grab_focus()


func get_event_id() -> String:
	return String(_offer.event.id) if _offer.has("event") else ""


func get_choice_buttons() -> Array[Button]:
	var buttons: Array[Button] = []
	for child in _choices.get_children():
		if child is Button and not child.is_queued_for_deletion():
			buttons.append(child)
	return buttons


func get_text() -> String:
	return _text.text


# --- The little picture ----------------------------------------------------------

func _draw_icon() -> void:
	var c := _icon.size / 2.0
	_icon.draw_circle(c, 44.0, Color("#efe5cc"))
	_icon.draw_arc(c, 44.0, 0, TAU, 40, ICON_INK, 2.0, true)
	var bob := sin(_time * 2.0) * 1.5
	match _icon_id:
		"cup":
			_icon.draw_rect(Rect2(c + Vector2(-16, -6), Vector2(26, 24)), Color("#c8553d"))
			_icon.draw_rect(Rect2(c + Vector2(-16, -6), Vector2(26, 24)), ICON_INK, false, 2.0)
			_icon.draw_arc(c + Vector2(12, 6), 7.0, -PI / 2, PI / 2, 10, ICON_INK, 3.0, true)
			for i in 3:
				var x := c.x - 10 + i * 7
				_icon.draw_line(Vector2(x, c.y - 12 + bob), Vector2(x + 2, c.y - 22 + bob), Color(ICON_INK, 0.5), 2.0, true)
		"bench":
			_icon.draw_rect(Rect2(c + Vector2(-26, -4), Vector2(52, 8)), Color("#8a6a4a"))
			_icon.draw_rect(Rect2(c + Vector2(-26, -16), Vector2(52, 6)), Color("#8a6a4a"))
			for x in [-22.0, 18.0]:
				_icon.draw_rect(Rect2(c + Vector2(x, 4), Vector2(4, 14)), ICON_INK)
		"sailor":
			_icon.draw_circle(c + Vector2(0, -12), 10.0, Color("#e8c4a0"))
			_icon.draw_rect(Rect2(c + Vector2(-14, 0), Vector2(28, 24)), Color("#efe5cc"))
			for i in 3:
				_icon.draw_line(c + Vector2(-14, 4 + i * 7), c + Vector2(14, 4 + i * 7), Color("#2e4a6b"), 3.0)
			_icon.draw_arc(c + Vector2(0, -12), 10.0, 0, TAU, 20, ICON_INK, 1.5, true)
		"basket":
			_icon.draw_colored_polygon(PackedVector2Array([c + Vector2(-20, -2), c + Vector2(20, -2), c + Vector2(14, 20), c + Vector2(-14, 20)]), Color("#e3c27a"))
			_icon.draw_arc(c + Vector2(0, -2), 16.0, PI, TAU, 16, ICON_INK, 3.0, true)
			_icon.draw_circle(c + Vector2(-7, -6), 6.0, Color("#c8553d"))
			_icon.draw_circle(c + Vector2(7, -7), 5.5, Color("#7ba05b"))
		"view":
			_icon.draw_colored_polygon(PackedVector2Array([c + Vector2(-34, 18), c + Vector2(-8, -18), c + Vector2(10, 6), c + Vector2(20, -6), c + Vector2(34, 18)]), Color("#7ba05b"))
			_icon.draw_rect(Rect2(c + Vector2(-34, 18), Vector2(68, 10)), Color("#3f7880"))
			_icon.draw_circle(c + Vector2(18, -22), 6.0, Color("#f2d58a"))
		"board":
			_icon.draw_rect(Rect2(c + Vector2(-24, -20), Vector2(48, 34)), Color("#8a6a4a"))
			for i in 4:
				var at := c + Vector2(-18 + (i % 2) * 20, -16 + (i / 2) * 15)
				_icon.draw_rect(Rect2(at, Vector2(15, 11)), Color("#efe5cc").darkened(0.05 * i))
			_icon.draw_rect(Rect2(c + Vector2(-3, 14), Vector2(6, 14)), ICON_INK)
		"gull":
			for i in 3:
				var at := c + Vector2(-18 + i * 18, -4 + (i % 2) * 10 + bob * (1 if i % 2 else -1))
				_icon.draw_arc(at + Vector2(-5, 0), 5.0, PI, TAU, 8, ICON_INK, 2.5, true)
				_icon.draw_arc(at + Vector2(5, 0), 5.0, PI, TAU, 8, ICON_INK, 2.5, true)
		"boat":
			_icon.draw_colored_polygon(PackedVector2Array([c + Vector2(-28, 6), c + Vector2(28, 6), c + Vector2(18, 20), c + Vector2(-18, 20)]), Color("#8a6a4a"))
			_icon.draw_line(c + Vector2(0, 6), c + Vector2(0, -26), ICON_INK, 2.5)
			_icon.draw_colored_polygon(PackedVector2Array([c + Vector2(2, -24), c + Vector2(22, 2), c + Vector2(2, 2)]), Color("#efe5cc").darkened(0.08))
		"houses":
			var colours := [Color("#d9a441"), Color("#c8553d"), Color("#3f6f8a"), Color("#7ba05b")]
			for i in 4:
				var x := c.x - 30 + i * 15
				_icon.draw_rect(Rect2(x, c.y - 14 + (i % 2) * 4, 14, 32 - (i % 2) * 4), colours[i])
				_icon.draw_rect(Rect2(x + 4, c.y - 6, 5, 5), Color("#efe5cc"))
		_:
			_icon.draw_circle(c, 10.0, ICON_INK)
