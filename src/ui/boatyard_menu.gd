class_name BoatyardMenu
extends ModalPanel
## The boatyard: browse the boats and move aboard another one. Opened from the
## boatyard station on deck, in harbour only (App checks; switching itself is
## GameSession.switch_vessel()). Changing boats is free and keeps everything
## else: the time, the harbour, the companion and the saved progress.
##
## The preview is the vessel's art-only deck scene (VesselVisual) in a
## SubViewport, so it shows exactly the art the game uses, sprites included,
## without any gameplay nodes. The comparison is computed from each boat's
## VesselProfile, so it always matches how the boats really sail.

signal vessel_chosen(vessel_id: StringName)

## Conditions used for the comparison table.
const COMPARE_WIND_KN := 12.0
const COMPARE_ANGLES: Array[float] = [45.0, 90.0, 150.0]
const PREVIEW_SIZE := Vector2i(560, 250)

var selected: VesselDefinition

var _buttons := {}
var _compare_cells := {}

@onready var _list: VBoxContainer = %VesselList
@onready var _viewport: SubViewport = %PreviewViewport
@onready var _name: Label = %NameLabel
@onready var _hull: Label = %HullLabel
@onready var _description: Label = %Description
@onready var _specs: GridContainer = %Specs
@onready var _compare: GridContainer = %Comparison
@onready var _choose: Button = %ChooseButton


func _ready() -> void:
	var group := ButtonGroup.new()
	var catalog := VesselCatalog.get_default()
	for vessel in catalog.vessels:
		var button := Button.new()
		button.name = String(vessel.id)
		button.toggle_mode = true
		button.button_group = group
		button.custom_minimum_size = Vector2(230, 64)
		button.text = vessel.display_name + "\n" + vessel.get_hull_type_name() \
			+ ("  (your boat)" if vessel.id == GameSession.get_vessel_id() else "")
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(select.bind(vessel.id))
		_list.add_child(button)
		_buttons[vessel.id] = button
	_build_comparison(catalog.vessels)
	_choose.pressed.connect(func() -> void: vessel_chosen.emit(selected.id))
	%CloseButton.pressed.connect(close)
	select(GameSession.get_vessel_id())


func _input(event: InputEvent) -> void:
	# Up/Down browse the boats (before GUI focus navigation takes them).
	if not is_visible_in_tree() or event.is_echo():
		return
	var step := 0
	if event.is_action_pressed(&"ui_up") or event.is_action_pressed(&"move_up"):
		step = -1
	elif event.is_action_pressed(&"ui_down") or event.is_action_pressed(&"move_down"):
		step = 1
	if step == 0:
		return
	var ids := VesselCatalog.get_default().get_ids()
	select(ids[wrapi(ids.find(selected.id) + step, 0, ids.size())])
	get_viewport().set_input_as_handled()


## Shows `vessel_id` in the preview and details.
func select(vessel_id: StringName) -> void:
	var vessel := VesselCatalog.get_default().get_vessel(vessel_id)
	if vessel == null:
		return
	selected = vessel
	for id: StringName in _buttons:
		(_buttons[id] as Button).set_pressed_no_signal(id == vessel_id)
	_name.text = vessel.display_name
	_hull.text = vessel.get_hull_type_name()
	_description.text = vessel.description
	for child in _specs.get_children():
		_specs.remove_child(child)
		child.queue_free()
	for key: String in vessel.specs:
		_specs.add_child(_label(key, &"MutedLabel"))
		_specs.add_child(_label(vessel.specs[key]))
	for key: Array in _compare_cells:
		var cell := _compare_cells[key] as Label
		cell.modulate = Color.WHITE if key[0] == vessel_id else Color(1, 1, 1, 0.55)
	var current := vessel_id == GameSession.get_vessel_id()
	_choose.disabled = current
	_choose.text = "This is your boat" if current else "Move aboard the %s" % vessel.display_name
	_show_preview(vessel)


## The comparison figures for one boat: [label, value text] rows.
static func compare_rows(vessel: VesselDefinition) -> Array:
	var profile := vessel.performance
	var rows := [["Top speed under sail", "%.1f kn" % profile.max_sail_speed_kn]]
	for angle in COMPARE_ANGLES:
		rows.append(["%d kn wind at %d°" % [COMPARE_WIND_KN, angle],
			"%.1f kn" % profile.sail_speed_kn(COMPARE_WIND_KN, angle)])
	rows.append(["Under engine", "%.1f kn" % profile.engine_speed_kn])
	return rows


func get_preview_root() -> Node:
	return _viewport.get_child(0) if _viewport.get_child_count() > 0 else null


func focus_default() -> void:
	if _choose.disabled:
		%CloseButton.grab_focus()
	else:
		_choose.grab_focus()


func _build_comparison(vessels: Array[VesselDefinition]) -> void:
	_compare.columns = vessels.size() + 1
	_compare.add_child(_label(""))
	for vessel in vessels:
		var head := _label(vessel.display_name, &"HeaderLabel")
		_compare_cells[[vessel.id, -1]] = head
		_compare.add_child(head)
	var rows := compare_rows(vessels[0]).size() if not vessels.is_empty() else 0
	for row in rows:
		_compare.add_child(_label(compare_rows(vessels[0])[row][0], &"MutedLabel"))
		for vessel in vessels:
			var cell := _label(compare_rows(vessel)[row][1])
			cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			_compare_cells[[vessel.id, row]] = cell
			_compare.add_child(cell)


func _show_preview(vessel: VesselDefinition) -> void:
	for child in _viewport.get_children():
		_viewport.remove_child(child)
		child.queue_free()
	if vessel.deck_visual_scene == null:
		return
	var visual := vessel.deck_visual_scene.instantiate() as VesselVisual
	var root := Node2D.new()
	root.name = "Preview"
	root.add_child(visual)
	visual.apply(vessel.visual_profile)
	var camera := Camera2D.new()
	var fit := minf(PREVIEW_SIZE.x / visual.canvas.size.x, PREVIEW_SIZE.y / visual.canvas.size.y) * 0.95
	camera.zoom = Vector2(fit, fit)
	camera.position = visual.canvas.get_center()
	root.add_child(camera)
	_viewport.add_child(root)
	camera.make_current()


static func _label(text: String, variation: StringName = &"") -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = variation
	return label
