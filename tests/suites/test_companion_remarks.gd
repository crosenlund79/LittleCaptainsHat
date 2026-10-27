extends RefCounted
## A little companion love: the kind word when the Captain pets the ship's
## cat or dog. Lines fit the animal (and a name and gender, when the
## companion has them), rotate without repeating, follow the language, keep
## a name exactly as written, come at most once per cooldown, and change
## nothing else about petting (the reaction, the sound, the hands-full rule,
## saves).

const APP_SCENE := preload("res://src/app/app.tscn")

var t: Node
var app: Node


func run(runner: Node) -> void:
	t = runner
	Simulation.auto_advance = false
	_test_lines()
	_test_languages()
	app = APP_SCENE.instantiate()
	t.add_child(app)
	app.router.fade_duration = 0.05
	await _settle()
	app.start_new_game()
	await _settle()
	await _test_petting_in_the_cabin(CompanionState.KIND_CAT)
	await _test_petting_in_the_cabin(CompanionState.KIND_DOG)
	await _test_hands_full()
	_test_save_compatibility()
	Simulation.auto_advance = true
	app.queue_free()
	await t.frames(2)
	GameSession.end_session()


func _settle() -> void:
	await t.frames(2)
	await t.wait_until(func() -> bool: return not app.router.is_busy(), 5.0)
	await t.physics_frames(3)


static func _who(kind: StringName, name := "", gender: StringName = &"") -> Dictionary:
	return {"kind": kind, "name": name, "gender": gender}


func _test_lines() -> void:
	SettingsManager.set_language(&"en")
	var cat := CompanionRemarks.lines(_who(CompanionState.KIND_CAT))
	var dog := CompanionRemarks.lines(_who(CompanionState.KIND_DOG))
	t.check(cat.size() >= 3 and dog.size() >= 3 and not cat.any(func(l: String) -> bool: return l in dog),
		"[lines] cats and dogs each have their own few lines (%d, %d)" % [cat.size(), dog.size()])
	t.check(cat.all(func(l: String) -> bool: return not l.contains("%s")) and dog.all(func(l: String) -> bool: return not l.contains("Snøvs")),
		"[lines] without a name no line has a name in it (and none says Snøvs)")
	var repeats := 0
	for who in [_who(CompanionState.KIND_CAT), _who(CompanionState.KIND_DOG, "Bølle", CompanionRemarks.GENDER_MALE)]:
		for turn in 30:
			if CompanionRemarks.remark(who, turn) == CompanionRemarks.remark(who, turn + 1):
				repeats += 1
	t.check(repeats == 0, "[lines] the next remark is never the same line")
	var girl := CompanionRemarks.lines(_who(CompanionState.KIND_DOG, "Freja", CompanionRemarks.GENDER_FEMALE))
	var boy := CompanionRemarks.lines(_who(CompanionState.KIND_DOG, "Bølle", CompanionRemarks.GENDER_MALE))
	var other := CompanionRemarks.lines(_who(CompanionState.KIND_DOG, "Kaptajn Kiks", CompanionRemarks.GENDER_OTHER))
	t.check("Who's a good girl, %s?" in girl and not "There's my good boy, %s!" in girl and "There's my good boy, %s!" in boy
		and not other.any(func(l: String) -> bool: return l.contains("girl") or l.contains("boy")),
		"[gender] a named dog: \"good girl\" for her, \"good boy\" for him, neither for other")
	var tomcat := CompanionRemarks.lines(_who(CompanionState.KIND_CAT, "Mis", CompanionRemarks.GENDER_MALE))
	t.check("There's my handsome little sailor, %s." in tomcat and not "There's my lovely little sailor, %s." in tomcat,
		"[gender] a named tomcat is a handsome little sailor")
	var name := "Søs Æble-Ø'Brien!"
	var said := []
	for turn in 4:
		said.append(CompanionRemarks.remark(_who(CompanionState.KIND_CAT, name, CompanionRemarks.GENDER_FEMALE), turn))
	t.check(said.all(func(s: String) -> bool: return s.contains(name)), "[name] the name goes in exactly as chosen: %s" % said[0])


func _test_languages() -> void:
	var who := _who(CompanionState.KIND_DOG, "Frøkén Ålborg", CompanionRemarks.GENDER_FEMALE)
	var english := CompanionRemarks.lines(who)
	var girl_turn := english.find("Who's a good girl, %s?")
	SettingsManager.set_language(&"da")
	var dansk := CompanionRemarks.remark(who, girl_turn)
	var unnamed_cat := CompanionRemarks.remark(_who(CompanionState.KIND_CAT), 1)
	var full := CompanionRemarks.hands_full(_who(CompanionState.KIND_DOG))
	SettingsManager.set_language(&"en")
	var english_again := CompanionRemarks.remark(who, girl_turn)
	t.check_eq(dansk, "Hvem er en dygtig pige, Frøkén Ålborg?", "[dansk] in Danish, with the name unchanged")
	t.check(unnamed_cat == "Sikke en dejlig lille spinden." and full.begins_with("Hunden får et venligt blik"), "[dansk] \"%s\" · \"%s\"" % [unnamed_cat, full])
	t.check_eq(english_again, "Who's a good girl, Frøkén Ålborg?", "[language] switching back: the next remark is in English again")
	for line in CompanionRemarks.UNNAMED[CompanionState.KIND_CAT] + CompanionRemarks.UNNAMED[CompanionState.KIND_DOG]:
		SettingsManager.set_language(&"da")
		var translated := Loc.t(line)
		SettingsManager.set_language(&"en")
		if translated == line:
			t.check(false, "[dansk] translated: %s" % line)
			return
	t.check(true, "[dansk] every remark has its Danish line")


func _show_cabin() -> BoatArea:
	app.modals.clear()
	GameSession.enter_boat_area(SessionState.AREA_INTERIOR, &"start")
	app._show_current_boat_area()
	await _settle()
	return app.router.current_screen as BoatArea


func _test_petting_in_the_cabin(kind: StringName) -> void:
	var state := GameSession.get_state_snapshot()
	state.companion = CompanionState.create(kind, state.game_time)
	GameSession.replace_state(state)
	var area := await _show_cabin()
	var pet := area.find_child("Companion", true, false) as ShipCompanion
	if not t.check(pet != null and pet.kind == kind, "(setup) the %s is in the cabin" % kind):
		return
	var said: Array[String] = []
	var listener := func(text: String) -> void: said.append(text)
	area.message_requested.connect(listener)
	ShipCompanion.reset_remark_cooldown()
	area._on_interacted(pet.interactable, area.player)
	await t.frames(2)
	t.check(pet.is_reacting(), "[%s] petting still brings its reaction (hearts and the alert pose)" % kind)
	var lines := CompanionRemarks.lines(CompanionRemarks.identity(GameSession.get_companion()))
	t.check(said.size() == 1 and lines.has(said[0]), "[%s] and a kind word: \"%s\"" % [kind, said[0] if not said.is_empty() else ""])
	area._on_interacted(pet.interactable, area.player)
	await t.frames(2)
	t.check(said.size() == 1, "[%s] petted again at once: the reaction, but no second note (rare, not constant)" % kind)
	ShipCompanion.reset_remark_cooldown()
	area._on_interacted(pet.interactable, area.player)
	await t.frames(2)
	t.check(said.size() == 2 and said[1] != said[0], "[%s] after the pause, a different line: \"%s\"" % [kind, said[1] if said.size() > 1 else ""])
	area.message_requested.disconnect(listener)


func _test_hands_full() -> void:
	var state := GameSession.get_state_snapshot()
	state.hat.status = HatState.CARRIED
	state.galley.coffee = GameSession.COFFEE_CARRIED
	GameSession.replace_state(state)
	var area := await _show_cabin()
	var pet := area.find_child("Companion", true, false) as ShipCompanion
	var said: Array[String] = []
	var listener := func(text: String) -> void: said.append(text)
	area.message_requested.connect(listener)
	ShipCompanion.reset_remark_cooldown()
	area._on_interacted(pet.interactable, area.player)
	await t.frames(2)
	area.message_requested.disconnect(listener)
	t.check(GameSession.free_hands() == 0 and not pet.is_reacting() and said.size() == 1 and said[0].contains("hands are full")
		and not said[0].contains("Snøvs"), "[hands full] hat and coffee in hand: a friendly look, no petting (\"%s\")" % (said[0] if not said.is_empty() else ""))
	state.hat.status = HatState.WORN
	state.galley.coffee = GameSession.COFFEE_NONE
	GameSession.replace_state(state)


func _test_save_compatibility() -> void:
	var errors: Array[String] = []
	var data: Dictionary = JSON.parse_string(JSON.stringify(GameSession.get_state_snapshot().to_dict()))
	var loaded := SessionState.from_dict(data, errors)
	t.check(errors.is_empty() and loaded != null and loaded.companion.kind == GameSession.get_companion().kind
		and not (data.companion as Dictionary).has("remark"), "[save] nothing new is saved: the companion loads as it was (save format %d)" % SaveManager.SAVE_VERSION)
	t.check(CompanionRemarks.identity(loaded.companion).name == "" and CompanionRemarks.lines(CompanionRemarks.identity(loaded.companion)).size() >= 3,
		"[save] a companion from any save has its remarks")
