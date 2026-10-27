class_name LanguagePicker
extends SimplePanel
## The first launch (I019): the game asks once which language to speak,
## English or Dansk, before anything else. The choice is kept in the settings
## (never in a save) and can be changed at any time under Settings. Both
## lines are shown in both languages, since the player cannot read the other.

signal chosen(locale: StringName)


func _ready() -> void:
	_build("Language  ·  Sprog", 640.0)
	var intro := _label("Intro", "Choose the game's language. You can change it later in Settings.\n"
		+ "Vælg spillets sprog. Du kan ændre det senere under Indstillinger.", &"MutedLabel")
	intro.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	for language: Array in Loc.LANGUAGES:
		var button := _button("Language_%s" % language[0], language[1], _choose.bind(StringName(language[0])), 200.0)
		button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	(_box.get_node("Title") as Label).auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED


## Only a choice closes it (Esc does nothing: there is no "no language").
func handle_back() -> void:
	pass


func _choose(locale: StringName) -> void:
	SettingsManager.set_language(locale)
	SettingsManager.save()
	close()
	chosen.emit(locale)


func focus_default() -> void:
	var button := find_child("Language_%s" % (&"da" if OS.get_locale_language() == "da" else &"en"), true, false) as Button
	if button:
		button.grab_focus()
