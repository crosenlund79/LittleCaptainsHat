class_name BoatCareView
extends VBoxContainer
## The boat's condition at a glance (Iteration 14): one row per care area
## (hull and bottom, rigging and sails, engine, equipment) with its level in
## words and colour (good / cosmetic wear / service recommended / needs
## attention), a one-line description and, when it matters, what to do about
## it. Shared by the Captain's Log (Boat tab) and the boatyard's Boat care
## panel. It only reads GameSession.

var _rows := {}


func _ready() -> void:
	add_theme_constant_override(&"separation", 10)
	var grid := GridContainer.new()
	grid.name = "Areas"
	grid.columns = 3
	grid.add_theme_constant_override(&"h_separation", 18)
	grid.add_theme_constant_override(&"v_separation", 8)
	add_child(grid)
	for area in BoatCare.AREAS:
		var name := _label(BoatCare.AREA_NAMES[area], &"MutedLabel")
		var level := _label("", &"HeaderLabel")
		level.name = "%sLevel" % String(area).capitalize()
		level.custom_minimum_size = Vector2(230, 0)
		var text := _label("")
		text.name = "%sText" % String(area).capitalize()
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.custom_minimum_size = Vector2(320, 0)
		grid.add_child(name)
		grid.add_child(level)
		grid.add_child(text)
		_rows[area] = [level, text]
	refresh()


## Re-reads the active boat's care record.
func refresh() -> void:
	if _rows.is_empty():
		return
	var care := GameSession.get_boat_care()
	var condition := GameSession.get_condition()
	var now := GameSession.get_game_time()
	for area: StringName in _rows:
		var level := BoatCare.area_level(area, care, condition, now)
		var level_label := _rows[area][0] as Label
		var text_label := _rows[area][1] as Label
		if area == BoatCare.AREA_EQUIPMENT:
			level_label.text = Loc.t("%d fitted") % care.upgrades.size() if not care.upgrades.is_empty() else Loc.t("Standard")
			UiTheme.tint(level_label, &"")
		else:
			level_label.text = BoatCare.LEVEL_NAMES[level]
			UiTheme.tint(level_label, BoatCare.LEVEL_ROLES[level])
		var advice := BoatCare.advice(area, level)
		text_label.text = BoatCare.describe_area(area, care, condition, now) + ("\n" + advice if advice != "" else "")


## The level text shown for `area` (tests).
func get_level_text(area: StringName) -> String:
	return (_rows[area][0] as Label).text if _rows.has(area) else ""


static func _label(text: String, variation: StringName = &"") -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = variation
	return label
