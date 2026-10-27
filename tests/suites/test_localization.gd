extends RefCounted
## I019 localization: English and Dansk. The first launch asks (and only
## once), the Settings switch applies at once and is kept, the Danish
## catalogue is complete and keeps every placeholder, numbers, dates, money,
## compass points and plurals take the language's own form, the primary
## screens fit in Danish, and saves do not depend on the language.

const APP_SCENE := preload("res://src/app/app.tscn")
const PLACEHOLDER := "%(?:[-+ 0#]*\\d*(?:\\.\\d+)?[sdifxXc]|%)"

var t: Node
var app: Node


func run(runner: Node) -> void:
	t = runner
	Simulation.auto_advance = false
	_test_catalogue()
	_test_formats()
	await _test_first_launch(&"da")
	await _test_first_launch(&"en")
	await _test_settings_switch()
	await _test_danish_screens_fit()
	_test_save_is_language_neutral()
	SettingsManager.set_language(&"en")
	Simulation.auto_advance = true
	GameSession.end_session()


func _settle() -> void:
	await t.frames(2)
	await t.wait_until(func() -> bool: return app == null or not app.router.is_busy(), 5.0)
	await t.frames(2)


func _open_app() -> void:
	app = APP_SCENE.instantiate()
	t.add_child(app)
	app.router.fade_duration = 0.05
	await t.wait_until(func() -> bool: return app.router.current_screen is MainMenu, 20.0)
	await _settle()


func _close_app() -> void:
	app.queue_free()
	await t.frames(2)
	app = null
	GameSession.end_session()


## The template's messages: [[context, msgid, plural], ...].
static func _template() -> Array:
	var out := []
	var text := FileAccess.get_file_as_string("res://locale/messages.pot")
	for block in text.split("\n\n"):
		var context := ""
		var msgid := ""
		var plural := ""
		var field := ""
		for line in block.split("\n"):
			var m := RegEx.create_from_string("^(msgctxt|msgid_plural|msgid|msgstr\\S*) \"(.*)\"$").search(line)
			if m:
				field = m.get_string(1)
				var value := m.get_string(2).c_unescape()
				match field:
					"msgctxt": context = value
					"msgid": msgid = value
					"msgid_plural": plural = value
			elif line.begins_with("\"") and field == "msgid":
				msgid += line.substr(1, line.length() - 2).c_unescape()
		if msgid != "":
			out.append([context, msgid, plural])
	return out


static func _placeholders(text: String) -> Array:
	return RegEx.create_from_string(PLACEHOLDER).search_all(text).map(func(m: RegExMatch) -> String: return m.get_string())


func _test_catalogue() -> void:
	var messages := _template()
	SettingsManager.set_language(&"da")
	var missing := []
	var broken := []
	for entry in messages:
		var danish := Loc.t(entry[1], entry[0]) if entry[2] == "" else Loc.n(entry[1], entry[2], 1, entry[0])
		if danish == entry[1] and not _is_in_catalogue(entry):
			missing.append(entry[1])
		elif _placeholders(danish) != _placeholders(entry[1]):
			broken.append([entry[1], danish])
		if entry[2] != "":
			var many := Loc.n(entry[1], entry[2], 5, entry[0])
			if _placeholders(many) != _placeholders(entry[2]):
				broken.append([entry[2], many])
	t.check(messages.size() > 2000 and missing.is_empty(), "[catalogue] every one of %d messages has a Danish translation (%d missing: %s)" % [
		messages.size(), missing.size(), missing.slice(0, 5)])
	t.check(broken.is_empty(), "[catalogue] every translation keeps its placeholders, in order (%d differ: %s)" % [broken.size(), broken.slice(0, 3)])
	t.check(Loc.n("%d hour", "%d hours", 1) % 1 == "1 time" and Loc.n("%d hour", "%d hours", 3) % 3 == "3 timer", "[plural] 1 time, 3 timer (%s, %s)" % [
		Loc.n("%d hour", "%d hours", 1) % 1, Loc.n("%d hour", "%d hours", 3) % 3])
	SettingsManager.set_language(&"en")
	t.check(Loc.n("%d hour", "%d hours", 1) % 1 == "1 hour" and Loc.n("%d hour", "%d hours", 3) % 3 == "3 hours", "[plural] 1 hour, 3 hours")


## Whether the Danish catalogue has the message (a few are the same in both
## languages: "Radar", harbour names).
static func _is_in_catalogue(entry: Array) -> bool:
	for translation in TranslationServer.get_translations() if TranslationServer.has_method(&"get_translations") else []:
		if translation.locale.begins_with("da") and translation.get_message(entry[1], entry[0]) != &"":
			return true
	var po := load("res://locale/da.po") as Translation
	return po != null and po.get_message(entry[1], entry[0]) != &""


func _test_formats() -> void:
	SettingsManager.set_language(&"en")
	var time := Time.get_unix_time_from_datetime_string("2026-05-01T08:05:00")
	var english := [Loc.decimal(5.5), Loc.thousands(10000), GameSession.format_money(1200), Simulation.format_game_time(time),
		WindField.compass_name(45.0), Simulation.format_duration(4 * 3600 + 50 * 60), TimePassage.date_text(time)]
	SettingsManager.set_language(&"da")
	var danish := [Loc.decimal(5.5), Loc.thousands(10000), GameSession.format_money(1200), Simulation.format_game_time(time),
		WindField.compass_name(45.0), Simulation.format_duration(4 * 3600 + 50 * 60), TimePassage.date_text(time)]
	SettingsManager.set_language(&"en")
	t.check_eq(english, ["5.5", "10,000", "€1,200", "Fri 1 May 2026, 08:05 UTC", "NE", "4 h 50 min", "1 May 2026"], "[format] English: numbers, money, date, compass, duration")
	t.check_eq(danish, ["5,5", "10.000", "1.200 €", "fre. 1. maj 2026, 08:05 UTC", "NØ", "4 t 50 min", "1. maj 2026"], "[format] Danish: 5,5 · 10.000 · 1.200 € · fre. 1. maj · NØ · 4 t 50 min")


func _test_first_launch(choice: StringName) -> void:
	SettingsManager.restore_snapshot({"language": &""})
	SettingsManager.save()
	t.check(not SettingsManager.has_chosen_language(), "(setup) no language chosen yet")
	await _open_app()
	await t.wait_until(func() -> bool: return app.modals.get_top() is LanguagePicker, 3.0)
	var picker: LanguagePicker = app.modals.get_top() as LanguagePicker
	if not t.check(picker != null, "[first launch] the game first asks for the language (English or Dansk)"):
		await _close_app()
		return
	picker.handle_back()
	await t.frames(2)
	t.check(app.modals.get_top() == picker, "[first launch] Esc does not skip the choice")
	var button: Button = picker.find_child("Language_%s" % choice, true, false) as Button
	var button_text := button.text
	t.click(button)
	await t.frames(3)
	t.check(not app.modals.get_top() is LanguagePicker and TranslationServer.get_locale().begins_with(choice),
		"[first launch] choosing %s applies it at once (locale %s)" % [button_text, TranslationServer.get_locale()])
	var menu: MainMenu = app.router.current_screen as MainMenu
	var new_game: Button = menu.find_child("NewGameButton", true, false) as Button
	var shown := new_game.atr(new_game.text)
	t.check((shown != new_game.text) == (choice == &"da"), "[first launch] the main menu speaks it: \"%s\"" % shown)
	await _close_app()
	# Kept in the settings: the next launch does not ask again.
	SettingsManager.load_settings()
	t.check(SettingsManager.has_chosen_language() and SettingsManager.get_language() == choice, "[first launch] the choice is kept in the settings (%s)" % SettingsManager.get_language())
	await _open_app()
	await t.frames(5)
	t.check(not app.modals.get_top() is LanguagePicker, "[first launch] and the next launch does not ask again")
	await _close_app()


func _test_settings_switch() -> void:
	SettingsManager.set_language(&"en")
	await _open_app()
	app.open_settings()
	await t.frames(3)
	var menu: Node = app.modals.get_top()
	var option: OptionButton = menu.find_child("Language", true, false) as OptionButton
	if not t.check(option != null and option.item_count == 2, "[settings] Settings has a Language choice (English, Dansk)"):
		await _close_app()
		return
	var label: Label = menu.find_child("LanguageLabel", true, false) as Label
	option.select(1)
	option.item_selected.emit(1)
	await t.frames(2)
	t.check(TranslationServer.get_locale().begins_with("da") and label.atr(label.text) == "Sprog", "[settings] switching to Dansk applies at once (\"%s\")" % label.atr(label.text))
	t.check(option.get_item_text(0) == "English" and option.get_item_text(1) == "Dansk", "[settings] each language is named in its own words")
	option.select(0)
	option.item_selected.emit(0)
	await t.frames(2)
	t.check(TranslationServer.get_locale().begins_with("en") and label.atr(label.text) == "Language", "[settings] and back to English")
	await _close_app()


## The primary screens in Danish: no control runs off the screen.
func _test_danish_screens_fit() -> void:
	SettingsManager.set_language(&"da")
	await _open_app()
	var screen := Rect2(Vector2.ZERO, app.get_viewport().get_visible_rect().size)
	var problems := []
	problems.append_array(_overflowing(app.router.current_screen, screen, "main menu"))
	app.open_settings()
	await t.frames(3)
	problems.append_array(_overflowing(app.modals.get_top(), screen, "settings"))
	app.modals.clear()
	app.start_new_game()
	await _settle()
	problems.append_array(_overflowing(app.hud, screen, "HUD"))
	var aboard := app.router.current_screen as BoatArea
	t.check(aboard != null and aboard.get_lighting() != null,
		"[dansk] aboard in Danish the boat's lighting is found (its node is not named in the language)")
	app.open_pause_menu()
	await t.frames(3)
	problems.append_array(_overflowing(app.modals.get_top(), screen, "pause menu"))
	app.modals.clear()
	t.check(problems.is_empty(), "[overflow] main menu, settings, HUD and pause menu fit the screen in Danish (%d problems: %s)" % [problems.size(), problems.slice(0, 4)])
	await _close_app()
	SettingsManager.set_language(&"en")


static func _overflowing(root: Node, screen: Rect2, where: String) -> Array:
	var out := []
	if root == null:
		return out
	for node in root.find_children("*", "Control", true, false):
		var control := node as Control
		if not control.is_visible_in_tree() or not (control is Label or control is Button):
			continue
		var text: String = control.text
		if text.strip_edges() == "":
			continue
		var rect := control.get_global_rect()
		if not screen.grow(2.0).encloses(rect):
			out.append("%s: %s \"%s\" off screen %s" % [where, control.name, control.atr(text).left(30), rect])
		elif control is Button and not (control as Button).clip_text and control.get_minimum_size().x > rect.size.x + 2.0:
			out.append("%s: %s \"%s\" wider than its button" % [where, control.name, control.atr(text).left(30)])
	return out


func _test_save_is_language_neutral() -> void:
	SettingsManager.set_language(&"da")
	GameSession.start_new_session()
	var danish := JSON.stringify(GameSession.get_state_snapshot().to_dict())
	t.check_eq(SaveManager.save_to_slot(3, GameSession.get_state_snapshot()), OK, "(setup) saved in Danish")
	SettingsManager.set_language(&"en")
	var state := SaveManager.load_from_slot(3).state
	t.check(state != null and JSON.stringify(state.to_dict()) == danish, "[save] a game saved in Danish loads in English, unchanged")
	t.check(not danish.contains("København") and not danish.contains("Havn"), "[save] the save holds ids, not Danish words")
