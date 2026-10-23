class_name PauseMenu
extends ModalPanel
## In-game pause menu. It only reports what the player chose; the
## application flow performs the actions.

signal save_requested
signal load_requested
signal settings_requested
signal main_menu_requested

@onready var _resume: Button = %ResumeButton


func _ready() -> void:
	_resume.pressed.connect(close)
	%SaveButton.pressed.connect(save_requested.emit)
	%LoadButton.pressed.connect(load_requested.emit)
	%SettingsButton.pressed.connect(settings_requested.emit)
	%MainMenuButton.pressed.connect(main_menu_requested.emit)


func focus_default() -> void:
	_resume.grab_focus()
