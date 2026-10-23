class_name ConfirmDialog
extends ModalPanel
## A yes/no question. Emits `answered` once, then closes itself.

signal answered(confirmed: bool)

var _answered := false

@onready var _title: Label = %Title
@onready var _message: Label = %Message
@onready var _confirm: Button = %ConfirmButton
@onready var _cancel: Button = %CancelButton

var _texts := ["", "", "Confirm", "Cancel"]


func setup(title: String, message: String, confirm_text: String, cancel_text: String) -> void:
	_texts = [title, message, confirm_text, cancel_text]


func _ready() -> void:
	_title.text = _texts[0]
	_message.text = _texts[1]
	_confirm.text = _texts[2]
	_cancel.text = _texts[3]
	_confirm.pressed.connect(_answer.bind(true))
	_cancel.pressed.connect(_answer.bind(false))


func focus_default() -> void:
	_cancel.grab_focus()


func handle_back() -> void:
	_answer(false)


func _answer(confirmed: bool) -> void:
	if _answered:
		return
	_answered = true
	answered.emit(confirmed)
	close()
