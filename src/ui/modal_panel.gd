class_name ModalPanel
extends Control
## Base for dialogs shown on the ModalStack (pause, settings, save/load,
## confirmations). The stack hides the modal below the top one and restores
## it, with keyboard focus, when the top one closes.

signal closed
## Asks the application to show a short notification.
signal notification_requested(text: String)

## Set by the ModalStack when the modal is pushed.
var stack: ModalStack


## Called when Esc is pressed while this modal is on top.
func handle_back() -> void:
	close()


## Gives keyboard focus to the most sensible control.
func focus_default() -> void:
	pass


func close() -> void:
	closed.emit()


func notify(text: String) -> void:
	notification_requested.emit(text)
