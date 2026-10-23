class_name ModalStack
extends Control
## Holds the open modal dialogs. Only the top one is visible and receives
## input; closing it reveals and refocuses the one underneath, so nested menus
## (pause -> settings -> back) always return to the correct parent.

signal stack_changed(depth: int)
signal notification_requested(text: String)

@export var confirm_dialog_scene: PackedScene

var _modals: Array[ModalPanel] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func push(modal: ModalPanel) -> void:
	if not _modals.is_empty():
		_modals.back().hide()
	modal.stack = self
	modal.closed.connect(_on_modal_closed.bind(modal), CONNECT_ONE_SHOT)
	modal.notification_requested.connect(notification_requested.emit)
	_modals.append(modal)
	add_child(modal)
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.focus_default.call_deferred()
	stack_changed.emit(_modals.size())


func clear() -> void:
	for modal in _modals:
		modal.queue_free()
	_modals.clear()
	stack_changed.emit(0)


func is_empty() -> bool:
	return _modals.is_empty()


func depth() -> int:
	return _modals.size()


func get_top() -> ModalPanel:
	return null if _modals.is_empty() else _modals.back()


func handle_back() -> void:
	if not _modals.is_empty():
		_modals.back().handle_back()


## Shows a confirmation dialog and waits for the answer.
##   if await stack.confirm("Overwrite?", "...", "Overwrite"): ...
func confirm(title: String, message: String, confirm_text := "Confirm", cancel_text := "Cancel") -> bool:
	var dialog := confirm_dialog_scene.instantiate() as ConfirmDialog
	dialog.setup(title, message, confirm_text, cancel_text)
	push(dialog)
	return await dialog.answered


func _on_modal_closed(modal: ModalPanel) -> void:
	var index := _modals.find(modal)
	if index == -1:
		return
	_modals.remove_at(index)
	modal.queue_free()
	if not _modals.is_empty() and index == _modals.size():
		var top: ModalPanel = _modals.back()
		top.show()
		top.focus_default.call_deferred()
	stack_changed.emit(_modals.size())
