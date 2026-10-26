class_name CatchBadge
extends HBoxContainer
## Rarity and specimen grade at a glance (Iteration 18), never by colour
## alone: rarity as 1-4 filled pips with its name ("Rare"), the grade as a
## medal with its name ("Silver"). Sharks add "released"; junk shows neither.

const PIP := Color("#e8c27a")
const PIP_EMPTY := Color(0.86, 0.9, 0.9, 0.28)
const MEDALS := {&"bronze": Color("#c08552"), &"silver": Color("#c9d1d6"), &"gold": Color("#e8c25a")}

var _pips: Control
var _rarity_label: Label
var _grade_label: Label
var _medal: Control
var _rarity := ""
var _grade: StringName = &""


func _ready() -> void:
	add_theme_constant_override(&"separation", 8)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pips = Control.new()
	_pips.custom_minimum_size = Vector2(66, 20)
	_pips.draw.connect(_draw_pips)
	add_child(_pips)
	_rarity_label = Label.new()
	_rarity_label.name = "Rarity"
	add_child(_rarity_label)
	_medal = Control.new()
	_medal.custom_minimum_size = Vector2(22, 20)
	_medal.draw.connect(_draw_medal)
	add_child(_medal)
	_grade_label = Label.new()
	_grade_label.name = "Grade"
	add_child(_grade_label)
	_update()


## `rarity`: a FishingCatalog rarity id ("" for junk); `grade`: a grade or
## GRADE_NONE (shown as "Ordinary"); `show_grade` false before it is known.
func set_catch(rarity: String, grade: StringName, show_grade := true) -> void:
	_rarity = rarity
	_grade = grade if show_grade else &"?"
	_update()


func get_text() -> String:
	return "%s %s" % [_rarity_label.text, _grade_label.text] if _rarity_label else ""


func _update() -> void:
	if _rarity_label == null:
		return
	_pips.visible = _rarity != ""
	_rarity_label.visible = _rarity != ""
	_rarity_label.text = FishingCatalog.rarity_label(_rarity)
	var known := _grade != &"?" and _rarity != ""
	_medal.visible = known and _grade != FishingCatalog.GRADE_NONE
	_grade_label.visible = known
	_grade_label.text = ("· %s" % FishingCatalog.grade_label(_grade)) if known else ""
	_pips.queue_redraw()
	_medal.queue_redraw()


func _draw_pips() -> void:
	var count := FishingCatalog.rarity_index(_rarity) + 1
	for i in FishingCatalog.RARITY_ORDER.size():
		var c := Vector2(8 + i * 16, 10)
		var diamond := PackedVector2Array([c + Vector2(0, -7), c + Vector2(6, 0), c + Vector2(0, 7), c + Vector2(-6, 0)])
		_pips.draw_colored_polygon(diamond, PIP if i < count else PIP_EMPTY)


func _draw_medal() -> void:
	if not MEDALS.has(_grade):
		return
	var c := Vector2(11, 10)
	_medal.draw_circle(c, 8.0, MEDALS[_grade])
	_medal.draw_arc(c, 8.0, 0.0, TAU, 24, Color("#3a2f26"), 1.5, true)
	_medal.draw_arc(c, 4.5, 0.0, TAU, 16, Color(1, 1, 1, 0.55), 1.2, true)
