class_name UiScaleLayer
extends CanvasLayer
## A CanvasLayer whose contents follow the "UI scale" preference.
##
## The layer is scaled, and each direct Control child is resized to cover the
## viewport in scaled units, so anchors and containers inside keep laying out
## against the visible screen. The game world is not affected.

func _ready() -> void:
	SettingsManager.ui_scale_changed.connect(_apply_scale)
	get_viewport().size_changed.connect(_fit_children)
	child_entered_tree.connect(func(_node: Node) -> void: _fit_children.call_deferred())
	_apply_scale(SettingsManager.get_ui_scale())


func _apply_scale(ui_scale: float) -> void:
	scale = Vector2(ui_scale, ui_scale)
	_fit_children()


func _fit_children() -> void:
	if not is_inside_tree():
		return
	var area := get_viewport().get_visible_rect().size / scale.x
	for child in get_children():
		var control := child as Control
		if control:
			control.set_anchors_preset(Control.PRESET_TOP_LEFT)
			control.position = Vector2.ZERO
			control.size = area
