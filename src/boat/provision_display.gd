@tool
class_name ProvisionDisplay
extends Node2D
## The food and water stores in the cabin, drawn from the real quantities:
## four food crates and four water cans, each standing for 3.5 days. Full
## items are filled, used ones are outlines, so full, moderate, low and empty
## stores look different at a glance; low stores turn amber and empty ones
## red. Presentation only (no collision); the provisions station next to it
## opens the numbers (ProvisionsMenu).
##
## Drawn art can replace it: a PNG at <art_folder>/cabin/provisions_<level>.png
## (level = full, moderate, low or empty, of the scarcer supply) is shown
## centred on this node instead of the drawing.

const ITEMS := 4
const DAYS_PER_ITEM := Provisions.CAPACITY_DAYS / ITEMS
const FOOD := Color("#C9A46A")
const FOOD_DARK := Color("#7A5C3A")
const WATER := Color("#5FA3B5")
const WATER_DARK := Color("#2E5A66")
const EMPTY := Color(0.94, 0.9, 0.8, 0.35)
const LOW := Color("#E0A84E")
const OUT := Color("#E06A4E")
const LABEL_FONT: Font = preload("res://assets/fonts/Barlow-SemiBold.ttf")

## Rotation-free layout: crates in the top row, cans in the bottom row.
@export var item_spacing := 17.0

var food_days := Provisions.CAPACITY_DAYS
var water_days := Provisions.CAPACITY_DAYS

var _sprite: Sprite2D


func _ready() -> void:
	z_index = 3
	if Engine.is_editor_hint():
		return
	GameSession.provisions_changed.connect(refresh)
	GameSession.state_replaced.connect(refresh)
	refresh()


func _process(_delta: float) -> void:
	if Engine.is_editor_hint() or not GameSession.is_active():
		return
	# Consumption is continuous; redraw only when an item changes.
	if filled_items(GameSession.get_food_days()) != filled_items(food_days) \
			or filled_items(GameSession.get_water_days()) != filled_items(water_days) \
			or Provisions.level_of(GameSession.get_food_days()) != Provisions.level_of(food_days):
		refresh()


func refresh() -> void:
	if not GameSession.is_active():
		return
	food_days = GameSession.get_food_days()
	water_days = GameSession.get_water_days()
	var texture := _art_for(get_level())
	if texture:
		if _sprite == null:
			_sprite = Sprite2D.new()
			add_child(_sprite)
		_sprite.texture = texture
		_sprite.visible = true
	elif _sprite:
		_sprite.visible = false
	queue_redraw()


## Items drawn full for `days` (rounded up: a started crate still counts).
static func filled_items(days: float) -> int:
	return clampi(ceili(days / DAYS_PER_ITEM - 1e-6), 0, ITEMS)


## The level shown: that of the scarcer supply.
func get_level() -> StringName:
	return Provisions.level_of(minf(food_days, water_days))


func get_filled() -> Vector2i:
	return Vector2i(filled_items(food_days), filled_items(water_days))


func _draw() -> void:
	if _sprite and _sprite.visible:
		return
	var width := item_spacing * ITEMS
	var tray := Rect2(-width / 2.0 - 6.0, -22.0, width + 12.0, 44.0)
	draw_rect(tray, Color(0.12, 0.09, 0.07, 0.55))
	draw_rect(tray, _tint(minf(food_days, water_days), Color(0.06, 0.12, 0.16, 0.7)), false, 1.5)
	var food_filled := filled_items(food_days)
	var water_filled := filled_items(water_days)
	for i in ITEMS:
		var x := -width / 2.0 + item_spacing * (i + 0.5)
		var crate := Rect2(x - 7.0, -19.0, 14.0, 12.0)
		if i < food_filled:
			draw_rect(crate, _tint(food_days, FOOD))
			draw_line(crate.position + Vector2(0, 6), crate.position + Vector2(14, 6), FOOD_DARK, 1.0)
		else:
			draw_rect(crate, EMPTY, false, 1.0)
		var can := Rect2(x - 5.0, -3.0, 10.0, 15.0)
		if i < water_filled:
			draw_rect(can, _tint(water_days, WATER))
			draw_rect(Rect2(x - 2.0, -6.0, 4.0, 3.0), WATER_DARK)
		else:
			draw_rect(can, EMPTY, false, 1.0)
	draw_string(LABEL_FONT, Vector2(-width / 2.0 - 4.0, 21.0), "FOOD · WATER", HORIZONTAL_ALIGNMENT_LEFT, width + 8.0, 8,
		Color(0.94, 0.9, 0.8, 0.7))


static func _tint(days: float, normal: Color) -> Color:
	match Provisions.level_of(days):
		Provisions.LEVEL_EMPTY:
			return OUT
		Provisions.LEVEL_LOW:
			return LOW
	return normal


func _art_for(level: StringName) -> Texture2D:
	var profile := GameSession.get_vessel_definition().visual_profile
	if profile == null or profile.procedural_only or profile.art_folder.is_empty():
		return null
	var path := profile.art_folder.path_join("cabin").path_join("provisions_%s.png" % level)
	return load(path) as Texture2D if ResourceLoader.exists(path) else null
